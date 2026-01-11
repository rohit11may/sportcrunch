//
//  VideoExporter.swift
//  SportCrunch
//
//  Extracts and concatenates video segments using AVFoundation.
//  Port of Python prototype's video_editor.py.
//

import Foundation
import AVFoundation
import CoreMedia

// MARK: - Export Result

struct ExportResult {
    let outputURL: URL
    let inputDuration: TimeInterval
    let outputDuration: TimeInterval
    let segmentCount: Int
    let compressionRatio: Double  // Percentage of video kept
    
    // Enhanced debug data for diagnosing timing/slow-mo issues
    let debugData: ExportDebugData?
}

/// Comprehensive debug data for export - critical for slow-mo diagnosis
struct ExportDebugData {
    let sourceVideoProperties: SourceVideoDebugProperties
    let compositionConfig: CompositionDebugConfig
    let segmentTimingDetails: [SegmentTimingDebugDetail]
    let outputVerification: OutputVerificationDebug?
}

/// Source video properties for debug
struct SourceVideoDebugProperties {
    let duration: Double
    let durationCMTime: CMTime
    let nominalFrameRate: Float
    let minFrameDuration: CMTime
    let naturalTimeScale: CMTimeScale
    let videoTrackCount: Int
    let audioTrackCount: Int
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let isVideoPortrait: Bool
    let colorPrimaries: String?
    let transferFunction: String?
    let ycbcrMatrix: String?
    let videoCodecType: String?
    let hasVariableFrameRate: Bool
}

/// Composition configuration for debug
struct CompositionDebugConfig {
    let exportPreset: String
    let outputFileType: String
    let shouldOptimizeForNetworkUse: Bool
    let usedVideoComposition: Bool
    let renderSize: CGSize?
    let frameDuration: CMTime?
    let frameRate: Double?
    let colorPrimariesApplied: String?
    let transferFunctionApplied: String?
    let ycbcrMatrixApplied: String?
    let appliedTransform: CGAffineTransform?
}

/// Per-segment timing details for debug
struct SegmentTimingDebugDetail {
    let segmentIndex: Int
    let requestedStartTime: Double
    let requestedEndTime: Double
    let requestedDuration: Double
    let startCMTime: CMTime
    let endCMTime: CMTime
    let durationCMTime: CMTime
    let insertionPosition: CMTime
    let insertedSuccessfully: Bool
    let errorMessage: String?
    let timeRangeValid: Bool
    let clampedToVideoBounds: Bool
}

/// Output video verification for debug
struct OutputVerificationDebug {
    let duration: Double
    let durationCMTime: CMTime
    let expectedDuration: Double
    let durationMismatch: Double
    let durationMismatchPercent: Double
    let nominalFrameRate: Float?
    let frameRateMismatch: Bool
    let sourceFrameRate: Float
    let naturalSize: CGSize?
    let videoCodecType: String?
    let timingAccurate: Bool
    let timingIssueDescription: String?
}

// MARK: - Video Export Preset

/// Encoding presets for video export, trading speed for quality.
/// Note: All presets now apply video composition for color space preservation,
/// which may trigger re-encoding even for the "fast" preset.
enum VideoExportPreset {
    /// Fast export - uses passthrough when possible.
    /// Note: Video composition is still applied for color preservation.
    case fast
    
    /// Balanced speed and quality - uses medium quality re-encoding.
    /// Good for most use cases.
    case balanced
    
    /// Highest quality - full re-encoding at maximum quality.
    /// Best color and quality preservation, recommended for final exports.
    case best
    
    var presetName: String {
        switch self {
        case .fast:
            return AVAssetExportPresetPassthrough
        case .balanced:
            return AVAssetExportPresetMediumQuality
        case .best:
            return AVAssetExportPresetHighestQuality
        }
    }
    
    var displayName: String {
        switch self {
        case .fast: return "Fast (Passthrough)"
        case .balanced: return "Balanced"
        case .best: return "Best Quality"
        }
    }
}

// MARK: - Export Error

enum VideoExporterError: Error, LocalizedError {
    case cannotAccessFile
    case noValidIntervals
    case compositionFailed
    case exportFailed(String)
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .cannotAccessFile:
            return "Cannot access the video file."
        case .noValidIntervals:
            return "No valid intervals to export."
        case .compositionFailed:
            return "Failed to create video composition."
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .exportCancelled:
            return "Export was cancelled."
        }
    }
}

// MARK: - Video Exporter

/// Extracts and concatenates video segments into a highlight reel.
///
/// Features:
/// - Merges overlapping intervals
/// - Handles edge cases (segments at video boundaries)
/// - Uses AVMutableComposition for efficient segment assembly
actor VideoExporter {
    
    // MARK: - Public API
    
    /// Export selected intervals from a video to a new file.
    /// - Parameters:
    ///   - sourceURL: URL to the source video
    ///   - intervals: List of (start, end) tuples in seconds
    ///   - outputURL: Destination URL for the output video
    ///   - preset: Export encoding preset (defaults to .fast for speed)
    /// - Returns: Export result with statistics
    func export(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        outputURL: URL,
        preset: VideoExportPreset = .fast
    ) async throws -> ExportResult {
        let startTime = Date()
        let logger = ProcessingLogger.shared
        
        print("📼 [VideoExporter] ═══════════════════════════════════════════")
        print("📼 [VideoExporter] Starting video export")
        print("📼 [VideoExporter] Source: \(sourceURL.lastPathComponent)")
        print("📼 [VideoExporter] Input segments: \(intervals.count)")
        
        logger.exportAsync("Starting video export with \(intervals.count) segments...")
        
        let asset = AVURLAsset(url: sourceURL)
        
        // Load asset properties
        let durationCMTime = try await asset.load(.duration)
        let duration = durationCMTime.seconds
        let tracks = try await asset.load(.tracks)
        
        print("📼 [VideoExporter] Source duration: \(formatTime(duration))")
        print("📼 [VideoExporter] Source duration CMTime: \(durationCMTime.value)/\(durationCMTime.timescale)")
        
        guard !tracks.isEmpty else {
            print("📼 [VideoExporter] ❌ ERROR: Cannot access file tracks")
            logger.errorAsync("Cannot access file tracks")
            throw VideoExporterError.cannotAccessFile
        }
        
        // Merge overlapping intervals
        print("📼 [VideoExporter] Merging overlapping intervals...")
        logger.exportAsync("Merging overlapping intervals...")
        let mergedIntervals = mergeIntervals(intervals, videoDuration: duration)
        
        guard !mergedIntervals.isEmpty else {
            print("📼 [VideoExporter] ❌ ERROR: No valid intervals after merge")
            logger.errorAsync("No valid intervals after merge")
            throw VideoExporterError.noValidIntervals
        }
        
        print("📼 [VideoExporter] Merged to \(mergedIntervals.count) segments:")
        for (i, interval) in mergedIntervals.enumerated() {
            let segDuration = interval.end - interval.start
            print("📼 [VideoExporter]   Segment \(i+1): \(formatTime(interval.start)) → \(formatTime(interval.end)) (\(String(format: "%.1f", segDuration))s)")
        }
        
        logger.exportAsync("Merged to \(mergedIntervals.count) segments")
        
        // Create composition
        print("📼 [VideoExporter] Building AVMutableComposition...")
        logger.exportAsync("Building video composition...")
        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            print("📼 [VideoExporter] ❌ ERROR: No video track found")
            logger.errorAsync("No video track found")
            throw VideoExporterError.compositionFailed
        }
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExporterError.compositionFailed
        }
        
        // Load and preserve the original video track's properties
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let minFrameDuration = try await videoTrack.load(.minFrameDuration)
        let naturalTimeScale = try await videoTrack.load(.naturalTimeScale)
        
        // Apply the preferred transform to preserve orientation
        compositionVideoTrack.preferredTransform = preferredTransform
        
        // Detect portrait video
        let isVideoPortrait = preferredTransform.a == 0 && abs(preferredTransform.b) == 1.0
        
        print("📼 [VideoExporter] ✓ Video properties: \(Int(naturalSize.width))x\(Int(naturalSize.height)) @ \(String(format: "%.1f", nominalFrameRate))fps")
        print("📼 [VideoExporter] ✓ MinFrameDuration: \(minFrameDuration.value)/\(minFrameDuration.timescale) = \(String(format: "%.4f", minFrameDuration.seconds))s")
        print("📼 [VideoExporter] ✓ NaturalTimeScale: \(naturalTimeScale)")
        print("📼 [VideoExporter] ✓ Portrait mode: \(isVideoPortrait)")
        print("📼 [VideoExporter] ✓ Transform: a=\(preferredTransform.a), b=\(preferredTransform.b), c=\(preferredTransform.c), d=\(preferredTransform.d)")
        
        // Load color space info for debug
        var colorPrimaries: String? = nil
        var transferFunction: String? = nil
        var ycbcrMatrix: String? = nil
        var videoCodecType: String? = nil
        var hasVariableFrameRate = false
        
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        if let formatDescription = formatDescriptions.first {
            let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [CFString: Any]
            colorPrimaries = extensions?[kCMFormatDescriptionExtension_ColorPrimaries] as? String
            transferFunction = extensions?[kCMFormatDescriptionExtension_TransferFunction] as? String
            ycbcrMatrix = extensions?[kCMFormatDescriptionExtension_YCbCrMatrix] as? String
            
            // Get codec type
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            videoCodecType = fourCharCodeToString(codecType)
            
            print("📼 [VideoExporter] ✓ Video codec: \(videoCodecType ?? "unknown")")
            print("📼 [VideoExporter] ✓ Color primaries: \(colorPrimaries ?? "default")")
            print("📼 [VideoExporter] ✓ Transfer function: \(transferFunction ?? "default")")
            print("📼 [VideoExporter] ✓ YCbCr matrix: \(ycbcrMatrix ?? "default")")
        }
        
        // Check for variable frame rate
        if minFrameDuration.seconds > 0 && nominalFrameRate > 0 {
            let expectedMinDuration = 1.0 / Double(nominalFrameRate)
            let variance = abs(minFrameDuration.seconds - expectedMinDuration) / expectedMinDuration
            hasVariableFrameRate = variance > 0.1  // More than 10% variance suggests VFR
            if hasVariableFrameRate {
                print("📼 [VideoExporter] ⚠️ VARIABLE FRAME RATE DETECTED - may cause timing issues!")
            }
        }
        
        // Add audio track if present
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let audioTrack = audioTracks.first
        var compositionAudioTrack: AVMutableCompositionTrack?
        
        if audioTrack != nil {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            print("📼 [VideoExporter] ✓ Video + Audio tracks configured")
        } else {
            print("📼 [VideoExporter] ✓ Video track configured (no audio)")
        }
        
        // DEBUG: Create source video properties for debug report
        let sourceVideoProperties = SourceVideoDebugProperties(
            duration: duration,
            durationCMTime: durationCMTime,
            nominalFrameRate: nominalFrameRate,
            minFrameDuration: minFrameDuration,
            naturalTimeScale: naturalTimeScale,
            videoTrackCount: 1,
            audioTrackCount: audioTracks.count,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            isVideoPortrait: isVideoPortrait,
            colorPrimaries: colorPrimaries,
            transferFunction: transferFunction,
            ycbcrMatrix: ycbcrMatrix,
            videoCodecType: videoCodecType,
            hasVariableFrameRate: hasVariableFrameRate
        )
        
        // Insert each interval into the composition - track timing details for debug
        var insertionTime = CMTime.zero
        var insertedCount = 0
        var segmentTimingDetails: [SegmentTimingDebugDetail] = []
        
        for (index, interval) in mergedIntervals.enumerated() {
            // Use the source video's natural time scale for better accuracy
            let preferredTimescale = naturalTimeScale > 0 ? naturalTimeScale : 600
            let segStartTime = CMTime(seconds: interval.start, preferredTimescale: preferredTimescale)
            let segEndTime = CMTime(seconds: interval.end, preferredTimescale: preferredTimescale)
            let timeRange = CMTimeRange(start: segStartTime, end: segEndTime)
            
            // Check if time range is valid and within bounds
            let timeRangeValid = timeRange.duration.seconds > 0
            let clampedToVideoBounds = interval.start < 0 || interval.end > duration
            
            print("📼 [VideoExporter] DEBUG Segment \(index): start=\(segStartTime.value)/\(segStartTime.timescale), end=\(segEndTime.value)/\(segEndTime.timescale), duration=\(timeRange.duration.value)/\(timeRange.duration.timescale)")
            
            var insertSuccess = false
            var errorMsg: String? = nil
            
            do {
                try compositionVideoTrack.insertTimeRange(
                    timeRange,
                    of: videoTrack,
                    at: insertionTime
                )
                
                if let audioTrack = audioTrack, let compAudioTrack = compositionAudioTrack {
                    try compAudioTrack.insertTimeRange(
                        timeRange,
                        of: audioTrack,
                        at: insertionTime
                    )
                }
                
                insertSuccess = true
                insertedCount += 1
            } catch {
                print("📼 [VideoExporter] ⚠️ Failed to insert segment \(index + 1): \(error.localizedDescription)")
                logger.warningAsync("Skipped segment \(index + 1)")
                errorMsg = error.localizedDescription
            }
            
            // Record timing detail for debug
            let timingDetail = SegmentTimingDebugDetail(
                segmentIndex: index,
                requestedStartTime: interval.start,
                requestedEndTime: interval.end,
                requestedDuration: interval.end - interval.start,
                startCMTime: segStartTime,
                endCMTime: segEndTime,
                durationCMTime: timeRange.duration,
                insertionPosition: insertionTime,
                insertedSuccessfully: insertSuccess,
                errorMessage: errorMsg,
                timeRangeValid: timeRangeValid,
                clampedToVideoBounds: clampedToVideoBounds
            )
            segmentTimingDetails.append(timingDetail)
            
            if insertSuccess {
                insertionTime = CMTimeAdd(insertionTime, timeRange.duration)
            }
        }
        
        print("📼 [VideoExporter] ✓ Inserted \(insertedCount)/\(mergedIntervals.count) segments")
        print("📼 [VideoExporter] ✓ Final composition duration: \(insertionTime.value)/\(insertionTime.timescale) = \(String(format: "%.3f", insertionTime.seconds))s")
        logger.exportAsync("Assembling \(insertedCount) video clips...")
        
        // Create video composition only for non-fast presets (to avoid unnecessary work)
        var videoComposition: AVMutableVideoComposition? = nil
        var compositionDebugConfig: CompositionDebugConfig
        
        if preset != .fast {
            videoComposition = try await createVideoComposition(
                for: composition,
                sourceVideoTrack: videoTrack,
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                nominalFrameRate: nominalFrameRate
            )
            
            let computedFrameRate: Double? = {
                guard let vc = videoComposition, vc.frameDuration.seconds > 0 else { return nil }
                return 1.0 / vc.frameDuration.seconds
            }()
            
            compositionDebugConfig = CompositionDebugConfig(
                exportPreset: preset.presetName,
                outputFileType: AVFileType.mp4.rawValue,
                shouldOptimizeForNetworkUse: true,
                usedVideoComposition: true,
                renderSize: videoComposition?.renderSize,
                frameDuration: videoComposition?.frameDuration,
                frameRate: computedFrameRate,
                colorPrimariesApplied: videoComposition?.colorPrimaries,
                transferFunctionApplied: videoComposition?.colorTransferFunction,
                ycbcrMatrixApplied: videoComposition?.colorYCbCrMatrix,
                appliedTransform: preferredTransform
            )
        } else {
            compositionDebugConfig = CompositionDebugConfig(
                exportPreset: preset.presetName,
                outputFileType: AVFileType.mp4.rawValue,
                shouldOptimizeForNetworkUse: false,
                usedVideoComposition: false,
                renderSize: nil,
                frameDuration: nil,
                frameRate: nil,
                colorPrimariesApplied: nil,
                transferFunctionApplied: nil,
                ycbcrMatrixApplied: nil,
                appliedTransform: nil
            )
        }
        
        // Ensure output directory exists
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create export session
        print("📼 [VideoExporter] Creating export session (\(preset.displayName) preset)...")
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset.presetName
        ) else {
            print("📼 [VideoExporter] ❌ ERROR: Could not create export session")
            logger.errorAsync("Could not create export session")
            throw VideoExporterError.exportFailed("Could not create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        // Only optimize for network use when re-encoding (adds overhead)
        exportSession.shouldOptimizeForNetworkUse = (preset != .fast)
        
        // Apply video composition only for non-fast presets
        // For fast preset, skip composition to enable true passthrough (much faster)
        // This trades color/orientation preservation for speed
        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
            print("📼 [VideoExporter] ✓ Applied video composition with color space preservation")
        } else {
            print("📼 [VideoExporter] ✓ Using fast passthrough mode (no re-encoding)")
        }
        
        print("📼 [VideoExporter] Output: \(outputURL.lastPathComponent)")
        print("📼 [VideoExporter] ⏳ Exporting... (this may take a while)")
        logger.exportAsync("Exporting highlight video (this may take a moment)...")
        
        // Start progress monitoring task
        let progressTask = Task {
            var lastReportedProgress: Float = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds
                let progress = exportSession.progress
                
                // Only log when progress increases by at least 5%
                if progress - lastReportedProgress >= 0.05 {
                    let percent = Int(progress * 100)
                    print("📼 [VideoExporter] Export progress: \(percent)%")
                    logger.exportAsync("Exporting... \(percent)%")
                    lastReportedProgress = progress
                }
                
                // Stop if export is no longer in progress
                if exportSession.status != .exporting && exportSession.status != .waiting {
                    break
                }
            }
        }
        
        // Perform export
        await exportSession.export()
        
        // Cancel progress monitoring
        progressTask.cancel()
        
        // Check export status
        switch exportSession.status {
        case .completed:
            print("📼 [VideoExporter] ✓ Export completed successfully")
        case .cancelled:
            print("📼 [VideoExporter] ❌ Export was cancelled")
            logger.errorAsync("Export was cancelled")
            throw VideoExporterError.exportCancelled
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("📼 [VideoExporter] ❌ Export failed: \(errorMessage)")
            logger.errorAsync("Export failed: \(errorMessage)")
            throw VideoExporterError.exportFailed(errorMessage)
        default:
            print("📼 [VideoExporter] ❌ Unexpected export status: \(exportSession.status.rawValue)")
            logger.errorAsync("Unexpected export status")
            throw VideoExporterError.exportFailed("Unexpected export status")
        }
        
        // Calculate statistics
        let outputDuration = mergedIntervals.reduce(0) { $0 + ($1.end - $1.start) }
        let compressionRatio = duration > 0 ? (1 - outputDuration / duration) * 100 : 0
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Verify output video properties
        let outputVerification = await verifyOutputVideo(
            outputURL: outputURL,
            expectedDuration: insertionTime.seconds,
            sourceFrameRate: nominalFrameRate
        )
        
        // Get file size
        var fileSizeStr = "unknown"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let fileSize = attrs[.size] as? Int64 {
            fileSizeStr = formatBytes(fileSize)
        }
        
        print("📼 [VideoExporter] ═══════════════════════════════════════════")
        print("📼 [VideoExporter] ✅ EXPORT COMPLETE in \(String(format: "%.2f", elapsed))s")
        print("📼 [VideoExporter] 📊 Results:")
        print("📼 [VideoExporter]    • Input duration: \(formatTime(duration))")
        print("📼 [VideoExporter]    • Output duration: \(formatTime(outputDuration))")
        print("📼 [VideoExporter]    • Dead space removed: \(String(format: "%.1f", compressionRatio))%")
        print("📼 [VideoExporter]    • Segments: \(mergedIntervals.count)")
        print("📼 [VideoExporter]    • File size: \(fileSizeStr)")
        
        // Print timing verification
        if let verification = outputVerification {
            print("📼 [VideoExporter] 🔍 Output Verification:")
            print("📼 [VideoExporter]    • Actual duration: \(String(format: "%.3f", verification.duration))s")
            print("📼 [VideoExporter]    • Expected duration: \(String(format: "%.3f", verification.expectedDuration))s")
            print("📼 [VideoExporter]    • Mismatch: \(String(format: "%.3f", verification.durationMismatch))s (\(String(format: "%.1f", verification.durationMismatchPercent))%)")
            if let outputFPS = verification.nominalFrameRate {
                print("📼 [VideoExporter]    • Output FPS: \(String(format: "%.2f", outputFPS)) (source: \(String(format: "%.2f", nominalFrameRate)))")
            }
            if !verification.timingAccurate {
                print("📼 [VideoExporter]    ⚠️ TIMING ISSUE: \(verification.timingIssueDescription ?? "Unknown")")
            }
        }
        
        print("📼 [VideoExporter] ═══════════════════════════════════════════")
        
        logger.successAsync("Export complete! \(formatTime(duration)) → \(formatTime(outputDuration)) (\(String(format: "%.0f", compressionRatio))% removed)")
        
        // Build debug data
        let debugData = ExportDebugData(
            sourceVideoProperties: sourceVideoProperties,
            compositionConfig: compositionDebugConfig,
            segmentTimingDetails: segmentTimingDetails,
            outputVerification: outputVerification
        )
        
        return ExportResult(
            outputURL: outputURL,
            inputDuration: duration,
            outputDuration: outputDuration,
            segmentCount: mergedIntervals.count,
            compressionRatio: compressionRatio,
            debugData: debugData
        )
    }
    
    // MARK: - Output Verification
    
    /// Verify output video properties to detect timing/frame rate issues.
    private func verifyOutputVideo(
        outputURL: URL,
        expectedDuration: TimeInterval,
        sourceFrameRate: Float
    ) async -> OutputVerificationDebug? {
        let outputAsset = AVURLAsset(url: outputURL)
        
        do {
            let outputDurationCMTime = try await outputAsset.load(.duration)
            let outputDuration = outputDurationCMTime.seconds
            
            let durationMismatch = outputDuration - expectedDuration
            let durationMismatchPercent = expectedDuration > 0 ? (abs(durationMismatch) / expectedDuration) * 100 : 0
            
            // Load output video track properties
            var outputFPS: Float? = nil
            var outputSize: CGSize? = nil
            var outputCodec: String? = nil
            
            if let outputVideoTrack = try await outputAsset.loadTracks(withMediaType: .video).first {
                outputFPS = try await outputVideoTrack.load(.nominalFrameRate)
                outputSize = try await outputVideoTrack.load(.naturalSize)
                
                let formatDescriptions = try await outputVideoTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    outputCodec = fourCharCodeToString(codecType)
                }
            }
            
            // Check for frame rate mismatch (could indicate slow-mo)
            let frameRateMismatch = outputFPS != nil && abs(outputFPS! - sourceFrameRate) > 1.0
            
            // Determine timing accuracy (within 1% tolerance or 0.5 seconds)
            let timingAccurate = durationMismatchPercent < 1.0 || abs(durationMismatch) < 0.5
            
            var timingIssueDescription: String? = nil
            if !timingAccurate {
                if durationMismatch > 0 {
                    timingIssueDescription = "Output \(String(format: "%.1f", durationMismatch))s LONGER than expected - possible SLOW-MO issue"
                } else {
                    timingIssueDescription = "Output \(String(format: "%.1f", abs(durationMismatch)))s SHORTER than expected - possible frame dropping"
                }
            }
            if frameRateMismatch {
                let fpsIssue = "Frame rate changed from \(String(format: "%.1f", sourceFrameRate)) to \(String(format: "%.1f", outputFPS ?? 0)) fps"
                timingIssueDescription = timingIssueDescription != nil ? "\(timingIssueDescription!); \(fpsIssue)" : fpsIssue
            }
            
            return OutputVerificationDebug(
                duration: outputDuration,
                durationCMTime: outputDurationCMTime,
                expectedDuration: expectedDuration,
                durationMismatch: durationMismatch,
                durationMismatchPercent: durationMismatchPercent,
                nominalFrameRate: outputFPS,
                frameRateMismatch: frameRateMismatch,
                sourceFrameRate: sourceFrameRate,
                naturalSize: outputSize,
                videoCodecType: outputCodec,
                timingAccurate: timingAccurate,
                timingIssueDescription: timingIssueDescription
            )
        } catch {
            print("📼 [VideoExporter] ⚠️ Could not verify output video: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Utility
    
    /// Convert FourCharCode to string for codec identification.
    private func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
    
    // MARK: - Video Composition Creation
    
    /// Creates a video composition that preserves the source video's color space and orientation.
    private func createVideoComposition(
        for composition: AVMutableComposition,
        sourceVideoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float
    ) async throws -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        
        // Calculate the correct render size based on the transform (handles rotation)
        let isVideoPortrait = preferredTransform.a == 0 && abs(preferredTransform.b) == 1.0
        if isVideoPortrait {
            videoComposition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            videoComposition.renderSize = naturalSize
        }
        
        // Set frame duration from source (fallback to 30fps if not available)
        let frameRate = nominalFrameRate > 0 ? nominalFrameRate : 30.0
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        // Load and preserve color properties from source video's format descriptions
        let formatDescriptions = try await sourceVideoTrack.load(.formatDescriptions)
        if let formatDescription = formatDescriptions.first {
            // Get color space properties from source video
            let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [CFString: Any]
            
            // Preserve color primaries (e.g., BT.709, P3, BT.2020)
            if let colorPrimaries = extensions?[kCMFormatDescriptionExtension_ColorPrimaries] as? String {
                videoComposition.colorPrimaries = colorPrimaries
                print("📼 [VideoExporter] ✓ Preserving color primaries: \(colorPrimaries)")
            }
            
            // Preserve transfer function (e.g., SDR, HLG, PQ for HDR)
            if let transferFunction = extensions?[kCMFormatDescriptionExtension_TransferFunction] as? String {
                videoComposition.colorTransferFunction = transferFunction
                print("📼 [VideoExporter] ✓ Preserving transfer function: \(transferFunction)")
            }
            
            // Preserve YCbCr matrix (e.g., BT.709, BT.601)
            if let ycbcrMatrix = extensions?[kCMFormatDescriptionExtension_YCbCrMatrix] as? String {
                videoComposition.colorYCbCrMatrix = ycbcrMatrix
                print("📼 [VideoExporter] ✓ Preserving YCbCr matrix: \(ycbcrMatrix)")
            }
        }
        
        // Create instruction for the entire composition
        guard let compositionVideoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.compositionFailed
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        // Create layer instruction that applies the transform
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        return videoComposition
    }
    
    // MARK: - Interval Merging
    
    /// Merge overlapping or adjacent intervals.
    /// - Parameters:
    ///   - intervals: List of (start, end) tuples
    ///   - videoDuration: Total video duration for clamping
    /// - Returns: Merged, non-overlapping intervals
    func mergeIntervals(
        _ intervals: [(start: TimeInterval, end: TimeInterval)],
        videoDuration: TimeInterval
    ) -> [(start: TimeInterval, end: TimeInterval)] {
        guard !intervals.isEmpty else { return [] }
        
        // Sort by start time
        let sorted = intervals.sorted { $0.start < $1.start }
        
        var merged: [(start: TimeInterval, end: TimeInterval)] = [sorted[0]]
        
        for i in 1..<sorted.count {
            let current = sorted[i]
            let lastIndex = merged.count - 1
            
            // Check for overlap or adjacency (within 0.5s)
            if current.start <= merged[lastIndex].end + 0.5 {
                // Merge by extending the end
                merged[lastIndex] = (
                    start: merged[lastIndex].start,
                    end: max(merged[lastIndex].end, current.end)
                )
            } else {
                merged.append(current)
            }
        }
        
        // Clamp to video duration and filter invalid
        let clamped = merged.compactMap { interval -> (start: TimeInterval, end: TimeInterval)? in
            let start = max(0, interval.start)
            let end = min(videoDuration, interval.end)
            
            guard end > start else { return nil }
            return (start: start, end: end)
        }
        
        return clamped
    }
    
    // MARK: - Preview
    
    /// Get preview statistics for intervals without exporting.
    /// - Parameters:
    ///   - sourceURL: URL to the source video
    ///   - intervals: List of (start, end) tuples in seconds
    /// - Returns: Dictionary with duration stats
    func previewExport(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)]
    ) async throws -> [String: Any] {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds
        
        let merged = mergeIntervals(intervals, videoDuration: duration)
        let outputDuration = merged.reduce(0) { $0 + ($1.end - $1.start) }
        let removedDuration = duration - outputDuration
        let compressionRatio = duration > 0 ? (1 - outputDuration / duration) * 100 : 0
        
        return [
            "inputDuration": duration,
            "outputDuration": outputDuration,
            "removedDuration": removedDuration,
            "compressionRatio": compressionRatio,
            "segmentCount": merged.count,
            "intervals": merged
        ]
    }
}

