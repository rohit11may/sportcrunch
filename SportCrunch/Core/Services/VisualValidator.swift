//
//  VisualValidator.swift
//  SportCrunch
//
//  Validates audio-detected segments using visual motion analysis.
//  Port of Python prototype's video_validator.py using vImage framework.
//

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

// MARK: - Visual Validator

/// Validates candidate segments by checking for sufficient motion.
///
/// Pipeline:
/// 1. Seek to segment start
/// 2. Sample frames at stride interval
/// 3. Downscale to thumbnail size
/// 4. Compute frame differences
/// 5. Return true if motion exceeds threshold
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
        
        // Create image generator
        let generator = AVAssetImageGenerator(asset: asset)
        generator.maximumSize = thumbSize
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        var validations: [SegmentValidation] = []
        
        for (index, candidate) in candidates.enumerated() {
            print("👁️ [VisualValidator] Validating segment \(index + 1)/\(candidates.count): \(formatTime(candidate.start)) → \(formatTime(candidate.end))")
            logger.visualAsync("Validating segment \(index + 1)/\(candidates.count) (\(formatTime(candidate.start)) → \(formatTime(candidate.end)))")
            
            let validation = try await validateSegment(
                generator: generator,
                start: candidate.start,
                end: candidate.end,
                fps: Double(fps),
                preset: preset
            )
            validations.append(validation)
            
            let status = validation.isValid ? "✅ VALID" : "⚪️ LOW MOTION"
            print("👁️ [VisualValidator]   → Motion score: \(Int(validation.motionScore)) \(status)")
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
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Segment Validation
    
    private func validateSegment(
        generator: AVAssetImageGenerator,
        start: TimeInterval,
        end: TimeInterval,
        fps: Double,
        preset: AnalysisPreset
    ) async throws -> SegmentValidation {
        let startFrame = Int(start * fps)
        let endFrame = Int(end * fps)
        
        var frameScores: [Double] = []
        var previousGrayscale: [UInt8]? = nil
        
        // Sample frames at stride intervals
        var frameIndex = startFrame
        while frameIndex < endFrame {
            let time = CMTime(seconds: Double(frameIndex) / fps, preferredTimescale: 600)
            
            do {
                let (cgImage, _) = try await generator.image(at: time)
                
                // Convert to grayscale
                let grayscale = extractGrayscale(from: cgImage)
                
                // Compute motion score if we have a previous frame
                if let prev = previousGrayscale, prev.count == grayscale.count {
                    let score = computeMotionScore(
                        frameA: prev,
                        frameB: grayscale,
                        pixelThreshold: preset.motionPixelThreshold
                    )
                    frameScores.append(score)
                }
                
                previousGrayscale = grayscale
            } catch {
                // Skip frames that can't be extracted
            }
            
            frameIndex += preset.videoSampleStride
        }
        
        // Calculate average motion score
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
    
    // MARK: - Image Processing
    
    /// Extract grayscale pixel values from a CGImage.
    private func extractGrayscale(from cgImage: CGImage) -> [UInt8] {
        let width = cgImage.width
        let height = cgImage.height
        let pixelCount = width * height
        
        // Create grayscale buffer
        var grayscalePixels = [UInt8](repeating: 0, count: pixelCount)
        
        // Create context for grayscale conversion
        guard let context = CGContext(
            data: &grayscalePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return []
        }
        
        // Draw image into grayscale context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return grayscalePixels
    }
    
    /// Compute motion score between two grayscale frames.
    /// Returns count of pixels with difference above threshold.
    private func computeMotionScore(frameA: [UInt8], frameB: [UInt8], pixelThreshold: Int) -> Double {
        guard frameA.count == frameB.count, !frameA.isEmpty else { return 0 }
        
        var motionPixels = 0
        
        // Use vDSP for fast computation
        // Convert to Float for vDSP operations
        var floatA = [Float](repeating: 0, count: frameA.count)
        var floatB = [Float](repeating: 0, count: frameB.count)
        
        vDSP_vfltu8(frameA, 1, &floatA, 1, vDSP_Length(frameA.count))
        vDSP_vfltu8(frameB, 1, &floatB, 1, vDSP_Length(frameB.count))
        
        // Compute absolute difference
        var diff = [Float](repeating: 0, count: frameA.count)
        vDSP_vsub(floatB, 1, floatA, 1, &diff, 1, vDSP_Length(frameA.count))
        vDSP_vabs(diff, 1, &diff, 1, vDSP_Length(diff.count))
        
        // Count pixels above threshold
        let threshold = Float(pixelThreshold)
        for value in diff {
            if value > threshold {
                motionPixels += 1
            }
        }
        
        return Double(motionPixels)
    }
}

