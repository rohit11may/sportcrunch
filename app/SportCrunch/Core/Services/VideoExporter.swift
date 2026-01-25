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
    let compressionRatio: Double  // Percentage of video kept
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

        print("📼 [VideoExporter] ═══════════════════════════════════════════")
        print("📼 [VideoExporter] Starting video export")
        print("📼 [VideoExporter] Source: \(sourceURL.lastPathComponent)")
        print("📼 [VideoExporter] Input segments: \(intervals.count)")

        let asset = AVURLAsset(url: sourceURL)

        // Load asset properties
        let durationCMTime = try await asset.load(.duration)
        let duration = durationCMTime.seconds
        let tracks = try await asset.load(.tracks)

        print("📼 [VideoExporter] Source duration: \(formatTime(duration))")
        print("📼 [VideoExporter] Source duration CMTime: \(durationCMTime.value)/\(durationCMTime.timescale)")

        guard !tracks.isEmpty else {
            print("📼 [VideoExporter] ❌ ERROR: Cannot access file tracks")
            throw VideoExporterError.cannotAccessFile
        }

        // Merge overlapping intervals
        print("📼 [VideoExporter] Merging overlapping intervals...")
        let mergedIntervals = mergeIntervals(intervals, videoDuration: duration)

        guard !mergedIntervals.isEmpty else {
            print("📼 [VideoExporter] ❌ ERROR: No valid intervals after merge")
            throw VideoExporterError.noValidIntervals
        }

        print("📼 [VideoExporter] Merged to \(mergedIntervals.count) segments:")
        for (i, interval) in mergedIntervals.enumerated() {
            let segDuration = interval.end - interval.start
            print("📼 [VideoExporter]   Segment \(i+1): \(formatTime(interval.start)) → \(formatTime(interval.end)) (\(String(format: "%.1f", segDuration))s)")
        }

        // Create composition
        print("📼 [VideoExporter] Building AVMutableComposition...")
        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            print("📼 [VideoExporter] ❌ ERROR: No video track found")
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
        var colorPrimaries: String?
        var transferFunction: String?
        var ycbcrMatrix: String?
        var videoCodecType: String?
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

        // Insert each interval into the composition
        var insertionTime = CMTime.zero
        var insertedCount = 0

        for (index, interval) in mergedIntervals.enumerated() {
            // Use the source video's natural time scale for better accuracy
            let preferredTimescale = naturalTimeScale > 0 ? naturalTimeScale : 600
            let segStartTime = CMTime(seconds: interval.start, preferredTimescale: preferredTimescale)
            let segEndTime = CMTime(seconds: interval.end, preferredTimescale: preferredTimescale)
            let timeRange = CMTimeRange(start: segStartTime, end: segEndTime)

            print("📼 [VideoExporter] DEBUG Segment \(index): start=\(segStartTime.value)/\(segStartTime.timescale), end=\(segEndTime.value)/\(segEndTime.timescale), duration=\(timeRange.duration.value)/\(timeRange.duration.timescale)")

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

                insertedCount += 1
                insertionTime = CMTimeAdd(insertionTime, timeRange.duration)
            } catch {
                print("📼 [VideoExporter] ⚠️ Failed to insert segment \(index + 1): \(error.localizedDescription)")
            }
        }

        print("📼 [VideoExporter] ✓ Inserted \(insertedCount)/\(mergedIntervals.count) segments")
        print("📼 [VideoExporter] ✓ Final composition duration: \(insertionTime.value)/\(insertionTime.timescale) = \(String(format: "%.3f", insertionTime.seconds))s")

        // Create video composition only for non-fast presets (to avoid unnecessary work)
        var videoComposition: AVMutableVideoComposition?

        if preset != .fast {
            videoComposition = try await createVideoComposition(
                for: composition,
                sourceVideoTrack: videoTrack,
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                nominalFrameRate: nominalFrameRate
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
            throw VideoExporterError.exportCancelled
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("📼 [VideoExporter] ❌ Export failed: \(errorMessage)")
            throw VideoExporterError.exportFailed(errorMessage)
        default:
            print("📼 [VideoExporter] ❌ Unexpected export status: \(exportSession.status.rawValue)")
            throw VideoExporterError.exportFailed("Unexpected export status")
        }

        // Calculate statistics
        let outputDuration = mergedIntervals.reduce(0) { $0 + ($1.end - $1.start) }
        let compressionRatio = duration > 0 ? (1 - outputDuration / duration) * 100 : 0
        let elapsed = Date().timeIntervalSince(startTime)

        // Verify output video properties
        await verifyOutputVideo(
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

        print("📼 [VideoExporter] ═══════════════════════════════════════════")

        return ExportResult(
            outputURL: outputURL,
            inputDuration: duration,
            outputDuration: outputDuration,
            compressionRatio: compressionRatio
        )
    }

    // MARK: - Output Verification

    /// Verify output video properties to detect timing/frame rate issues.
    private func verifyOutputVideo(
        outputURL: URL,
        expectedDuration: TimeInterval,
        sourceFrameRate: Float
    ) async {
        let outputAsset = AVURLAsset(url: outputURL)

        do {
            let outputDurationCMTime = try await outputAsset.load(.duration)
            let outputDuration = outputDurationCMTime.seconds

            let durationMismatch = outputDuration - expectedDuration
            let durationMismatchPercent = expectedDuration > 0 ? (abs(durationMismatch) / expectedDuration) * 100 : 0

            // Load output video track properties
            var outputFPS: Float?

            if let outputVideoTrack = try await outputAsset.loadTracks(withMediaType: .video).first {
                outputFPS = try await outputVideoTrack.load(.nominalFrameRate)
            }

            // Check for frame rate mismatch (could indicate slow-mo)
            let frameRateMismatch = outputFPS != nil && abs(outputFPS! - sourceFrameRate) > 1.0

            // Determine timing accuracy (within 1% tolerance or 0.5 seconds)
            let timingAccurate = durationMismatchPercent < 1.0 || abs(durationMismatch) < 0.5

            print("📼 [VideoExporter] 🔍 Output Verification:")
            print("📼 [VideoExporter]    • Actual duration: \(String(format: "%.3f", outputDuration))s")
            print("📼 [VideoExporter]    • Expected duration: \(String(format: "%.3f", expectedDuration))s")
            print("📼 [VideoExporter]    • Mismatch: \(String(format: "%.3f", durationMismatch))s (\(String(format: "%.1f", durationMismatchPercent))%)")
            if let outputFPS = outputFPS {
                print("📼 [VideoExporter]    • Output FPS: \(String(format: "%.2f", outputFPS)) (source: \(String(format: "%.2f", sourceFrameRate)))")
            }
            if !timingAccurate {
                if durationMismatch > 0 {
                    print("📼 [VideoExporter]    ⚠️ TIMING ISSUE: Output \(String(format: "%.1f", durationMismatch))s LONGER than expected - possible SLOW-MO issue")
                } else {
                    print("📼 [VideoExporter]    ⚠️ TIMING ISSUE: Output \(String(format: "%.1f", abs(durationMismatch)))s SHORTER than expected - possible frame dropping")
                }
            }
            if frameRateMismatch {
                print("📼 [VideoExporter]    ⚠️ Frame rate changed from \(String(format: "%.1f", sourceFrameRate)) to \(String(format: "%.1f", outputFPS ?? 0)) fps")
            }
        } catch {
            print("📼 [VideoExporter] ⚠️ Could not verify output video: \(error.localizedDescription)")
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

}
