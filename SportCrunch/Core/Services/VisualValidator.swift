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

// MARK: - Visual Validator

/// Validates candidate segments by checking for sufficient motion.
///
/// Pipeline (OPTIMIZED):
/// 1. Batch extract frames using generateCGImagesAsynchronously
/// 2. Process segments in parallel with TaskGroup
/// 3. Downscale to thumbnail size
/// 4. Compute frame differences with vectorized vDSP
/// 5. Early exit when motion threshold is confirmed
actor VisualValidator {
    
    // MARK: - Current Preset (set per validation call)
    
    private var currentPreset: AnalysisPreset?
    
    // MARK: - Public API
    
    /// Validate multiple segments for motion.
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - candidates: List of (start, end) intervals in seconds
    ///   - sport: Sport type for preset configuration
    ///   - sportMode: Optional sport-specific mode (e.g., TennisMode)
    /// - Returns: Array of validation results for each segment
    func validate(
        videoURL: URL,
        candidates: [(start: TimeInterval, end: TimeInterval)],
        sport: Sport,
        sportMode: SportMode? = nil
    ) async throws -> [SegmentValidation] {
        let preset = sport.preset(for: sportMode)
        currentPreset = preset
        let logger = ProcessingLogger.shared
        
        let thumbSize = CGSize(
            width: preset.videoThumbSize.width,
            height: preset.videoThumbSize.height
        )
        
        let startTime = Date()
        print("👁️ [VisualValidator] ═══════════════════════════════════════════")
        print("👁️ [VisualValidator] Starting visual validation for \(sport.displayName)")
        print("👁️ [VisualValidator] Source: \(videoURL.lastPathComponent)")
        print("👁️ [VisualValidator] Segments to validate: \(candidates.count)")
        print("👁️ [VisualValidator] ───────────────────────────────────────────")
        print("👁️ [VisualValidator] Preset Configuration:")
        print("👁️ [VisualValidator]   • Thumbnail size: \(preset.videoThumbSize.width)x\(preset.videoThumbSize.height)")
        print("👁️ [VisualValidator]   • Frame stride: every \(preset.videoSampleStride) frames")
        print("👁️ [VisualValidator]   • Pixel threshold: \(preset.motionPixelThreshold)")
        print("👁️ [VisualValidator]   • Area threshold: \(Int(preset.motionAreaThreshold)) pixels")
        print("👁️ [VisualValidator] ───────────────────────────────────────────")
        print("👁️ [VisualValidator] 🚀 OPTIMIZED: Batch extraction + parallel processing")
        
        logger.visualAsync("Starting motion validation for \(candidates.count) segments...")
        
        let asset = AVURLAsset(url: videoURL)
        
        // Verify video track exists
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            print("👁️ [VisualValidator] ❌ ERROR: No video track found")
            logger.errorAsync("No video track found")
            throw VisualValidatorError.noVideoTrack
        }
        
        let fps = try await videoTrack.load(.nominalFrameRate)
        print("👁️ [VisualValidator] Video FPS: \(String(format: "%.2f", fps))")
        
        // Process segments in parallel using TaskGroup
        // Each segment gets its own generator for thread safety
        let validations = try await withThrowingTaskGroup(of: (Int, SegmentValidation).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask { [self] in
                    print("👁️ [VisualValidator] Validating segment \(index + 1)/\(candidates.count): \(self.formatTime(candidate.start)) → \(self.formatTime(candidate.end))")
                    
                    // Create a separate generator for each parallel task
                    let taskGenerator = AVAssetImageGenerator(asset: asset)
                    taskGenerator.maximumSize = thumbSize
                    taskGenerator.appliesPreferredTrackTransform = true
                    // OPTIMIZATION: Relaxed tolerance for faster frame retrieval
                    taskGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
                    taskGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
                    
                    let validation = await self.validateSegmentBatch(
                        generator: taskGenerator,
                        start: candidate.start,
                        end: candidate.end,
                        fps: Double(fps),
                        preset: preset
                    )
                    
                    let status = validation.isValid ? "✅ VALID" : "⚪️ LOW MOTION"
                    print("👁️ [VisualValidator]   → Segment \(index + 1) motion score: \(Int(validation.motionScore)) \(status)")
                    
                    return (index, validation)
                }
            }
            
            // Collect results and sort by original index to maintain order
            var results: [(Int, SegmentValidation)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
        
        let validCount = validations.filter { $0.isValid }.count
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("👁️ [VisualValidator] ═══════════════════════════════════════════")
        print("👁️ [VisualValidator] ✅ VALIDATION COMPLETE in \(String(format: "%.2f", elapsed))s")
        print("👁️ [VisualValidator] 📊 Results:")
        print("👁️ [VisualValidator]    • Valid segments: \(validCount)/\(candidates.count)")
        print("👁️ [VisualValidator]    • Rejected (low motion): \(candidates.count - validCount)")
        print("👁️ [VisualValidator] ═══════════════════════════════════════════")
        
        logger.successAsync("Motion validation complete: \(validCount)/\(candidates.count) segments verified in \(String(format: "%.1f", elapsed))s")
        
        return validations
    }
    
    // MARK: - Formatting Helpers
    
    private nonisolated func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Batch Segment Validation
    
    /// Validates a segment using batch frame extraction for better performance.
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
        var frameIndex = startFrame
        while frameIndex < endFrame {
            let time = CMTime(seconds: Double(frameIndex) / fps, preferredTimescale: 600)
            times.append(NSValue(time: time))
            frameIndex += preset.videoSampleStride
        }
        
        guard !times.isEmpty else {
            return SegmentValidation(start: start, end: end, isValid: false, motionScore: 0)
        }
        
        // Use batch frame extraction with continuation
        let extractedFrames = await extractFramesBatch(generator: generator, times: times)
        
        guard extractedFrames.count >= 2 else {
            return SegmentValidation(start: start, end: end, isValid: false, motionScore: 0)
        }
        
        // Pre-allocate buffers based on first frame size
        let firstFrame = extractedFrames[0]
        let pixelCount = firstFrame.width * firstFrame.height
        let buffers = FrameBuffers(pixelCount: pixelCount)
        
        var frameScores: [Double] = []
        var runningTotal: Double = 0
        var framesProcessed = 0
        
        // Process consecutive frame pairs
        for i in 1..<extractedFrames.count {
            let prevFrame = extractedFrames[i - 1]
            let currFrame = extractedFrames[i]
            
            // Extract grayscale into reusable buffers
            extractGrayscaleIntoBuffer(from: prevFrame, buffer: &buffers.grayscaleA)
            extractGrayscaleIntoBuffer(from: currFrame, buffer: &buffers.grayscaleB)
            
            // Compute motion score with vectorized operations
            let score = computeMotionScoreVectorized(
                buffers: buffers,
                pixelThreshold: preset.motionPixelThreshold
            )
            frameScores.append(score)
            runningTotal += score
            framesProcessed += 1
            
            // EARLY EXIT: If running average already exceeds threshold, we can stop
            let runningAverage = runningTotal / Double(framesProcessed)
            if runningAverage >= preset.motionAreaThreshold && framesProcessed >= 3 {
                // Already confirmed motion - skip remaining frames for speed
                return SegmentValidation(
                    start: start,
                    end: end,
                    isValid: true,
                    motionScore: runningAverage
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
        
        return SegmentValidation(
            start: start,
            end: end,
            isValid: isValid,
            motionScore: motionScore
        )
    }
    
    // MARK: - Batch Frame Extraction
    
    /// Extracts frames in batch using generateCGImagesAsynchronously for better I/O efficiency.
    private nonisolated func extractFramesBatch(
        generator: AVAssetImageGenerator,
        times: [NSValue]
    ) async -> [CGImage] {
        await withCheckedContinuation { continuation in
            var frames: [CGImage] = []
            var expectedCount = times.count
            var receivedCount = 0
            let lock = NSLock()
            
            generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
                lock.lock()
                defer { lock.unlock() }
                
                if let image = cgImage, result == .succeeded {
                    frames.append(image)
                }
                
                receivedCount += 1
                
                if receivedCount >= expectedCount {
                    continuation.resume(returning: frames)
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
        let count = buffers.grayscaleA.count
        guard count > 0, count == buffers.grayscaleB.count else { return 0 }
        
        let length = vDSP_Length(count)
        
        // Convert UInt8 to Float
        vDSP_vfltu8(buffers.grayscaleA, 1, &buffers.floatA, 1, length)
        vDSP_vfltu8(buffers.grayscaleB, 1, &buffers.floatB, 1, length)
        
        // Compute absolute difference: diff = |A - B|
        vDSP_vsub(buffers.floatB, 1, buffers.floatA, 1, &buffers.diff, 1, length)
        vDSP_vabs(buffers.diff, 1, &buffers.diff, 1, length)
        
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
        
        return Double(sum)
    }
}
