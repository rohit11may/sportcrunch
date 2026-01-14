//
//  VisualValidator.swift
//  SportCrunch
//
//  Validates audio-detected segments using visual motion analysis.
//  Port of Python prototype's video_validator.py using vImage framework.
//
//  OPTIMIZED: Batch frame extraction, parallel processing, vectorized operations

import Foundation
import AVFoundation
import Accelerate
import CoreGraphics

// MARK: - Segment Validation

struct SegmentValidation {
    let start: TimeInterval
    let end: TimeInterval
    let isValid: Bool
    let motionScore: Double
    
    // Enhanced debug data
    let debugData: SegmentValidationDebugData?
}

/// Detailed debug data for a segment validation (for comparing simulator vs device)
struct SegmentValidationDebugData {
    let framesRequested: Int
    let framesExtracted: Int
    let usedEarlyExit: Bool
    let framesProcessedBeforeDecision: Int
    let allFrameScores: [Double]
    let framePairDetails: [FramePairDebugData]
    
    /// Errors encountered during frame extraction (for debugging device issues)
    let extractionErrors: [String]
}

/// Debug data for a single frame pair comparison
struct FramePairDebugData {
    let pairIndex: Int
    let frameATime: Double
    let frameBTime: Double
    let frameAWidth: Int
    let frameAHeight: Int
    let frameBWidth: Int
    let frameBHeight: Int
    let frameAGrayscaleMean: Float
    let frameAGrayscaleStdDev: Float
    let frameBGrayscaleMean: Float
    let frameBGrayscaleStdDev: Float
    let rawDiffSum: Float
    let rawDiffMean: Float
    let rawDiffMax: Float
    let pixelsAboveThreshold: Int
    let motionScore: Double
}

// MARK: - Visual Validator Errors

enum VisualValidatorError: Error, LocalizedError {
    case cannotAccessFile
    case noVideoTrack
    case frameExtractionFailed
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cannotAccessFile:
            return "Cannot access the video file."
        case .noVideoTrack:
            return "No video track found in file."
        case .frameExtractionFailed:
            return "Failed to extract video frames."
        case .processingFailed(let reason):
            return "Visual validation failed: \(reason)"
        }
    }
}

// MARK: - Reusable Frame Buffers

/// Pre-allocated buffers for frame processing to avoid per-frame allocations.
/// Thread-safe via actor isolation.
private final class FrameBuffers {
    var grayscaleA: [UInt8]
    var grayscaleB: [UInt8]
    var floatA: [Float]
    var floatB: [Float]
    var diff: [Float]
    
    init(pixelCount: Int) {
        grayscaleA = [UInt8](repeating: 0, count: pixelCount)
        grayscaleB = [UInt8](repeating: 0, count: pixelCount)
        floatA = [Float](repeating: 0, count: pixelCount)
        floatB = [Float](repeating: 0, count: pixelCount)
        diff = [Float](repeating: 0, count: pixelCount)
    }
    
    func resize(to pixelCount: Int) {
        guard pixelCount != grayscaleA.count else { return }
        grayscaleA = [UInt8](repeating: 0, count: pixelCount)
        grayscaleB = [UInt8](repeating: 0, count: pixelCount)
        floatA = [Float](repeating: 0, count: pixelCount)
        floatB = [Float](repeating: 0, count: pixelCount)
        diff = [Float](repeating: 0, count: pixelCount)
    }
}

/// Result of motion computation with debug statistics
struct MotionComputationResult {
    let motionScore: Double
    let rawDiffSum: Float
    let rawDiffMean: Float
    let rawDiffMax: Float
    let pixelsAboveThreshold: Int
}

/// Statistics for a grayscale buffer
struct GrayscaleStats {
    let mean: Float
    let stdDev: Float
}

// MARK: - Visual Validator

/// Validates candidate segments by checking for sufficient motion.
///
/// Pipeline (OPTIMIZED):
/// 1. Process segments in controlled batches (12 at a time) to avoid decoder overload
/// 2. Batch extract frames using generateCGImagesAsynchronously
/// 3. Downscale to thumbnail size
/// 4. Compute frame differences with vectorized vDSP
/// 5. Early exit when motion threshold is confirmed
actor VisualValidator {
    
    // MARK: - Constants
    
    /// Number of segments to process in parallel.
    /// Limited to avoid overwhelming the HEVC hardware decoder on device.
    private let segmentBatchSize = 12
    
    // MARK: - Current Preset (set per validation call)
    
    private var currentPreset: AnalysisPreset?
    
    // MARK: - Public API
    
    /// Validate multiple segments for motion.
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - candidates: List of (start, end) intervals in seconds
    ///   - sport: Sport type for preset configuration
    ///   - sportMode: Optional sport-specific mode (e.g., TennisMode)
    ///   - progressHandler: Optional callback for granular progress updates (0.0 to 1.0)
    /// - Returns: Array of validation results for each segment
    func validate(
        videoURL: URL,
        candidates: [(start: TimeInterval, end: TimeInterval)],
        sport: Sport,
        sportMode: SportMode? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [SegmentValidation] {
        let preset = sport.preset(for: sportMode)
        currentPreset = preset
        let logger = ProcessingLogger.shared
        
        let thumbSize = CGSize(
            width: preset.videoThumbSize.width,
            height: preset.videoThumbSize.height
        )
        
        let startTime = Date()

        // Normal level: High-level progress
        logger.visualAsync("Starting motion validation for \(candidates.count) segments...")

        // Verbose level: Configuration details
        logger.visualVerboseAsync("═══════════════════════════════════════════")
        logger.visualVerboseAsync("Source: \(videoURL.lastPathComponent)")
        logger.visualVerboseAsync("Segments to validate: \(candidates.count)")
        logger.visualVerboseAsync("───────────────────────────────────────────")
        logger.visualVerboseAsync("Preset Configuration:")
        logger.visualVerboseAsync("  • Thumbnail size: \(preset.videoThumbSize.width)x\(preset.videoThumbSize.height)")
        logger.visualVerboseAsync("  • Frame stride: every \(preset.videoSampleStride) frames")
        logger.visualVerboseAsync("  • Pixel threshold: \(preset.motionPixelThreshold)")
        logger.visualVerboseAsync("  • Area threshold: \(Int(preset.motionAreaThreshold)) pixels")
        logger.visualVerboseAsync("  • Batch size: \(segmentBatchSize) segments")
        logger.visualVerboseAsync("───────────────────────────────────────────")
        logger.visualVerboseAsync("🚀 OPTIMIZED: Batched processing + controlled parallelism")
        
        let asset = AVURLAsset(url: videoURL)
        
        // Verify video track exists
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            logger.errorAsync("No video track found")
            throw VisualValidatorError.noVideoTrack
        }

        let fps = try await videoTrack.load(.nominalFrameRate)

        // Calculate time tolerance based on frame stride to avoid duplicate frames
        let frameInterval = Double(preset.videoSampleStride) / Double(fps)
        let timeTolerance = max(0.05, frameInterval * 0.4)

        // Verbose level: Video and timing details
        logger.visualVerboseAsync("Video FPS: \(String(format: "%.2f", fps))")
        logger.visualVerboseAsync("Frame interval: \(String(format: "%.3f", frameInterval))s (stride \(preset.videoSampleStride) @ \(String(format: "%.0f", fps))fps)")
        logger.visualVerboseAsync("Time tolerance: \(String(format: "%.3f", timeTolerance))s (40% of interval to avoid duplicates)")
        
        // Process segments in batches to avoid overwhelming the decoder
        var allValidations: [SegmentValidation] = []
        let totalBatches = (candidates.count + segmentBatchSize - 1) / segmentBatchSize
        
        for batchIndex in 0..<totalBatches {
            let batchStart = batchIndex * segmentBatchSize
            let batchEnd = min(batchStart + segmentBatchSize, candidates.count)
            let batchCandidates = Array(candidates[batchStart..<batchEnd])

            logger.visualVerboseAsync("Processing batch \(batchIndex + 1)/\(totalBatches): segments \(batchStart + 1)-\(batchEnd)")
            
            let batchValidations = try await withThrowingTaskGroup(of: (Int, SegmentValidation).self) { group in
                for (localIndex, candidate) in batchCandidates.enumerated() {
                    let globalIndex = batchStart + localIndex
                    
                    group.addTask { [self] in
                        // Create a separate generator for each parallel task
                        let taskGenerator = AVAssetImageGenerator(asset: asset)
                        taskGenerator.maximumSize = thumbSize
                        taskGenerator.appliesPreferredTrackTransform = true
                        
                        // Use adaptive time tolerance based on fps
                        taskGenerator.requestedTimeToleranceBefore = CMTime(seconds: timeTolerance, preferredTimescale: 600)
                        taskGenerator.requestedTimeToleranceAfter = CMTime(seconds: timeTolerance, preferredTimescale: 600)
                        
                        let validation = await self.validateSegmentBatch(
                            generator: taskGenerator,
                            start: candidate.start,
                            end: candidate.end,
                            fps: Double(fps),
                            preset: preset
                        )
                        
                        let status = validation.isValid ? "✅ VALID" : "⚪️ LOW MOTION"
                        ProcessingLogger.shared.visualVerboseAsync("  → Segment \(globalIndex + 1) motion score: \(Int(validation.motionScore)) \(status)")
                        
                        return (globalIndex, validation)
                    }
                }
                
                // Collect results and sort by original index to maintain order
                var results: [(Int, SegmentValidation)] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
            
            allValidations.append(contentsOf: batchValidations)
            
            // Report progress after each batch
            let batchProgress = Double(batchIndex + 1) / Double(totalBatches)
            progressHandler?(batchProgress)
            logger.visualVerboseAsync("Batch \(batchIndex + 1)/\(totalBatches) complete (\(Int(batchProgress * 100))%)")
            
            // Small delay between batches to let decoder recover
            if batchIndex < totalBatches - 1 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
        
        let validCount = allValidations.filter { $0.isValid }.count
        let elapsed = Date().timeIntervalSince(startTime)

        // Normal level: Final results summary
        logger.successAsync("Motion validation complete: \(validCount)/\(candidates.count) segments verified in \(String(format: "%.1f", elapsed))s")

        // Verbose level: Detailed results
        logger.visualVerboseAsync("═══════════════════════════════════════════")
        logger.visualVerboseAsync("✅ VALIDATION COMPLETE in \(String(format: "%.2f", elapsed))s")
        logger.visualVerboseAsync("📊 Results:")
        logger.visualVerboseAsync("   • Valid segments: \(validCount)/\(candidates.count)")
        logger.visualVerboseAsync("   • Rejected (low motion): \(candidates.count - validCount)")
        logger.visualVerboseAsync("   • Batches processed: \(totalBatches)")
        logger.visualVerboseAsync("═══════════════════════════════════════════")
        
        return allValidations
    }
    
    // MARK: - Formatting Helpers
    
    private nonisolated func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Batch Segment Validation
    
    /// Validates a segment using batch frame extraction for better performance.
    /// Now captures detailed debug data for comparing simulator vs device behavior.
    private nonisolated func validateSegmentBatch(
        generator: AVAssetImageGenerator,
        start: TimeInterval,
        end: TimeInterval,
        fps: Double,
        preset: AnalysisPreset
    ) async -> SegmentValidation {
        let startFrame = Int(start * fps)
        let endFrame = Int(end * fps)
        
        // Build list of times to extract
        var times: [NSValue] = []
        var frameTimes: [Double] = []  // Track actual times for debug
        var frameIndex = startFrame
        while frameIndex < endFrame {
            let timeSeconds = Double(frameIndex) / fps
            let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)
            times.append(NSValue(time: time))
            frameTimes.append(timeSeconds)
            frameIndex += preset.videoSampleStride
        }
        
        let framesRequested = times.count
        
        guard !times.isEmpty else {
            let debugData = SegmentValidationDebugData(
                framesRequested: 0,
                framesExtracted: 0,
                usedEarlyExit: false,
                framesProcessedBeforeDecision: 0,
                allFrameScores: [],
                framePairDetails: [],
                extractionErrors: []
            )
            return SegmentValidation(start: start, end: end, isValid: false, motionScore: 0, debugData: debugData)
        }
        
        // Use batch frame extraction with continuation
        let extractionResult = await extractFramesBatch(generator: generator, times: times)
        let extractedFrames = extractionResult.frames
        let extractionErrors = extractionResult.errors
        
        guard extractedFrames.count >= 2 else {
            let debugData = SegmentValidationDebugData(
                framesRequested: framesRequested,
                framesExtracted: extractedFrames.count,
                usedEarlyExit: false,
                framesProcessedBeforeDecision: 0,
                allFrameScores: [],
                framePairDetails: [],
                extractionErrors: extractionErrors
            )
            return SegmentValidation(start: start, end: end, isValid: false, motionScore: 0, debugData: debugData)
        }
        
        // Pre-allocate buffers based on first frame size
        let firstFrame = extractedFrames[0]
        let pixelCount = firstFrame.width * firstFrame.height
        let buffers = FrameBuffers(pixelCount: pixelCount)
        
        var frameScores: [Double] = []
        var framePairDetails: [FramePairDebugData] = []
        var runningTotal: Double = 0
        var framesProcessed = 0
        var usedEarlyExit = false
        
        // Process consecutive frame pairs
        for i in 1..<extractedFrames.count {
            let prevFrame = extractedFrames[i - 1]
            let currFrame = extractedFrames[i]
            
            // Extract grayscale into reusable buffers
            extractGrayscaleIntoBuffer(from: prevFrame, buffer: &buffers.grayscaleA)
            extractGrayscaleIntoBuffer(from: currFrame, buffer: &buffers.grayscaleB)
            
            // Calculate grayscale statistics for debug
            let statsA = computeGrayscaleStats(buffer: buffers.grayscaleA)
            let statsB = computeGrayscaleStats(buffer: buffers.grayscaleB)
            
            // Compute motion score with vectorized operations and get debug details
            let result = computeMotionScoreVectorizedWithDebug(
                buffers: buffers,
                pixelThreshold: preset.motionPixelThreshold
            )
            
            let score = result.motionScore
            frameScores.append(score)
            runningTotal += score
            framesProcessed += 1
            
            // Capture frame pair debug data (limit to first 10 pairs to avoid huge reports)
            if framePairDetails.count < 10 {
                let frameATime = i - 1 < frameTimes.count ? frameTimes[i - 1] : 0
                let frameBTime = i < frameTimes.count ? frameTimes[i] : 0
                
                let pairDebug = FramePairDebugData(
                    pairIndex: i - 1,
                    frameATime: frameATime,
                    frameBTime: frameBTime,
                    frameAWidth: prevFrame.width,
                    frameAHeight: prevFrame.height,
                    frameBWidth: currFrame.width,
                    frameBHeight: currFrame.height,
                    frameAGrayscaleMean: statsA.mean,
                    frameAGrayscaleStdDev: statsA.stdDev,
                    frameBGrayscaleMean: statsB.mean,
                    frameBGrayscaleStdDev: statsB.stdDev,
                    rawDiffSum: result.rawDiffSum,
                    rawDiffMean: result.rawDiffMean,
                    rawDiffMax: result.rawDiffMax,
                    pixelsAboveThreshold: result.pixelsAboveThreshold,
                    motionScore: score
                )
                framePairDetails.append(pairDebug)
            }
            
            // EARLY EXIT: If running average already exceeds threshold, we can stop
            let runningAverage = runningTotal / Double(framesProcessed)
            if runningAverage >= preset.motionAreaThreshold && framesProcessed >= 3 {
                usedEarlyExit = true
                
                let debugData = SegmentValidationDebugData(
                    framesRequested: framesRequested,
                    framesExtracted: extractedFrames.count,
                    usedEarlyExit: true,
                    framesProcessedBeforeDecision: framesProcessed,
                    allFrameScores: frameScores,
                    framePairDetails: framePairDetails,
                    extractionErrors: extractionErrors
                )
                
                return SegmentValidation(
                    start: start,
                    end: end,
                    isValid: true,
                    motionScore: runningAverage,
                    debugData: debugData
                )
            }
        }
        
        // Calculate final average motion score
        let motionScore: Double
        if frameScores.isEmpty {
            motionScore = 0
        } else {
            motionScore = frameScores.reduce(0, +) / Double(frameScores.count)
        }
        
        let isValid = motionScore >= preset.motionAreaThreshold
        
        let debugData = SegmentValidationDebugData(
            framesRequested: framesRequested,
            framesExtracted: extractedFrames.count,
            usedEarlyExit: usedEarlyExit,
            framesProcessedBeforeDecision: framesProcessed,
            allFrameScores: frameScores,
            framePairDetails: framePairDetails,
            extractionErrors: extractionErrors
        )
        
        return SegmentValidation(
            start: start,
            end: end,
            isValid: isValid,
            motionScore: motionScore,
            debugData: debugData
        )
    }
    
    /// Compute grayscale statistics for debug logging.
    private nonisolated func computeGrayscaleStats(buffer: [UInt8]) -> GrayscaleStats {
        guard !buffer.isEmpty else {
            return GrayscaleStats(mean: 0, stdDev: 0)
        }
        
        var sum: Float = 0
        for value in buffer {
            sum += Float(value)
        }
        let mean = sum / Float(buffer.count)
        
        var varianceSum: Float = 0
        for value in buffer {
            let diff = Float(value) - mean
            varianceSum += diff * diff
        }
        let stdDev = sqrt(varianceSum / Float(buffer.count))
        
        return GrayscaleStats(mean: mean, stdDev: stdDev)
    }
    
    // MARK: - Batch Frame Extraction
    
    /// Result of batch frame extraction including any errors encountered.
    private struct FrameExtractionResult {
        let frames: [CGImage]
        let errors: [String]
    }
    
    /// Extracts frames in batch using generateCGImagesAsynchronously for better I/O efficiency.
    /// Returns both extracted frames and any errors encountered for debug logging.
    private nonisolated func extractFramesBatch(
        generator: AVAssetImageGenerator,
        times: [NSValue]
    ) async -> FrameExtractionResult {
        await withCheckedContinuation { continuation in
            var frames: [CGImage] = []
            var errors: [String] = []
            var expectedCount = times.count
            var receivedCount = 0
            let lock = NSLock()
            
            generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
                lock.lock()
                defer { lock.unlock() }
                
                if let image = cgImage, result == .succeeded {
                    frames.append(image)
                } else {
                    // Capture error details for debug report (limit to first 10 to avoid huge reports)
                    if errors.count < 10 {
                        let resultDesc: String
                        switch result {
                        case .succeeded: resultDesc = "succeeded"
                        case .failed: resultDesc = "failed"
                        case .cancelled: resultDesc = "cancelled"
                        @unknown default: resultDesc = "unknown(\(result.rawValue))"
                        }
                        let timeStr = String(format: "%.3f", requestedTime.seconds)
                        let errorStr = "t=\(timeStr)s: \(resultDesc), \(error?.localizedDescription ?? "no error message")"
                        errors.append(errorStr)
                    }
                }
                
                receivedCount += 1
                
                if receivedCount >= expectedCount {
                    // Debug level: Log extraction stats if there were failures
                    if !errors.isEmpty {
                        let successRate = Double(frames.count) / Double(expectedCount) * 100
                        ProcessingLogger.shared.visualDebugAsync("⚠️ Frame extraction: \(frames.count)/\(expectedCount) succeeded (\(String(format: "%.0f", successRate))%)")
                        ProcessingLogger.shared.visualDebugAsync("  First failure: \(errors.first ?? "unknown")")
                    }
                    continuation.resume(returning: FrameExtractionResult(frames: frames, errors: errors))
                }
            }
        }
    }
    
    // MARK: - Image Processing (Optimized)
    
    /// Extract grayscale pixel values from a CGImage into a pre-allocated buffer.
    private nonisolated func extractGrayscaleIntoBuffer(from cgImage: CGImage, buffer: inout [UInt8]) {
        let width = cgImage.width
        let height = cgImage.height
        let pixelCount = width * height
        
        // Resize buffer if needed
        if buffer.count != pixelCount {
            buffer = [UInt8](repeating: 0, count: pixelCount)
        }
        
        // Create context for grayscale conversion
        buffer.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return
            }
            
            // Draw image into grayscale context
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
    
    /// Compute motion score between two grayscale frames using fully vectorized vDSP operations.
    /// Returns count of pixels with difference above threshold.
    private nonisolated func computeMotionScoreVectorized(
        buffers: FrameBuffers,
        pixelThreshold: Int
    ) -> Double {
        return computeMotionScoreVectorizedWithDebug(buffers: buffers, pixelThreshold: pixelThreshold).motionScore
    }
    
    /// Compute motion score with detailed debug statistics for platform comparison.
    private nonisolated func computeMotionScoreVectorizedWithDebug(
        buffers: FrameBuffers,
        pixelThreshold: Int
    ) -> MotionComputationResult {
        let count = buffers.grayscaleA.count
        guard count > 0, count == buffers.grayscaleB.count else {
            return MotionComputationResult(motionScore: 0, rawDiffSum: 0, rawDiffMean: 0, rawDiffMax: 0, pixelsAboveThreshold: 0)
        }
        
        let length = vDSP_Length(count)
        
        // Convert UInt8 to Float
        vDSP_vfltu8(buffers.grayscaleA, 1, &buffers.floatA, 1, length)
        vDSP_vfltu8(buffers.grayscaleB, 1, &buffers.floatB, 1, length)
        
        // Compute absolute difference: diff = |A - B|
        vDSP_vsub(buffers.floatB, 1, buffers.floatA, 1, &buffers.diff, 1, length)
        vDSP_vabs(buffers.diff, 1, &buffers.diff, 1, length)
        
        // DEBUG: Capture raw difference statistics BEFORE thresholding
        var rawDiffSum: Float = 0
        vDSP_sve(buffers.diff, 1, &rawDiffSum, length)
        let rawDiffMean = rawDiffSum / Float(count)
        
        var rawDiffMax: Float = 0
        vDSP_maxv(buffers.diff, 1, &rawDiffMax, length)
        
        // VECTORIZED THRESHOLDING:
        // 1. Subtract threshold from all values
        // 2. Clip negative values to 0, positive to 1
        // 3. Sum gives count of pixels above threshold
        
        var negThreshold = -Float(pixelThreshold)
        var zero: Float = 0
        var one: Float = 1
        
        // Subtract threshold: diff = diff - threshold (using negative value with vsadd)
        vDSP_vsadd(buffers.diff, 1, &negThreshold, &buffers.diff, 1, length)
        
        // Clip to [0, 1]: values <= 0 become 0, values > 0 become 1
        // vDSP_vthr zeros out values below threshold
        var smallThreshold: Float = 0.0001  // Just above zero
        vDSP_vthr(buffers.diff, 1, &smallThreshold, &buffers.diff, 1, length)
        
        // Clip to max 1.0 so we count pixels, not magnitudes
        vDSP_vclip(buffers.diff, 1, &zero, &one, &buffers.diff, 1, length)
        
        // Sum to get count of motion pixels
        var sum: Float = 0
        vDSP_sve(buffers.diff, 1, &sum, length)
        
        return MotionComputationResult(
            motionScore: Double(sum),
            rawDiffSum: rawDiffSum,
            rawDiffMean: rawDiffMean,
            rawDiffMax: rawDiffMax,
            pixelsAboveThreshold: Int(sum)
        )
    }
}
