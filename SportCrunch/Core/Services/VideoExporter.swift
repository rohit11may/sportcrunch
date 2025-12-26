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
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.load(.tracks)
        
        print("📼 [VideoExporter] Source duration: \(formatTime(duration))")
        
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
        
        // Apply the preferred transform to preserve orientation
        compositionVideoTrack.preferredTransform = preferredTransform
        
        print("📼 [VideoExporter] ✓ Video properties: \(Int(naturalSize.width))x\(Int(naturalSize.height)) @ \(String(format: "%.1f", nominalFrameRate))fps")
        
        // Add audio track if present
        let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
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
            let startTime = CMTime(seconds: interval.start, preferredTimescale: 600)
            let endTime = CMTime(seconds: interval.end, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            
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
                
                insertionTime = CMTimeAdd(insertionTime, timeRange.duration)
                insertedCount += 1
            } catch {
                print("📼 [VideoExporter] ⚠️ Failed to insert segment \(index + 1): \(error.localizedDescription)")
                logger.warningAsync("Skipped segment \(index + 1)")
                continue
            }
        }
        
        print("📼 [VideoExporter] ✓ Inserted \(insertedCount)/\(mergedIntervals.count) segments")
        logger.exportAsync("Assembling \(insertedCount) video clips...")
        
        // Create video composition only for non-fast presets (to avoid unnecessary work)
        var videoComposition: AVMutableVideoComposition? = nil
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
        
        logger.successAsync("Export complete! \(formatTime(duration)) → \(formatTime(outputDuration)) (\(String(format: "%.0f", compressionRatio))% removed)")
        
        return ExportResult(
            outputURL: outputURL,
            inputDuration: duration,
            outputDuration: outputDuration,
            segmentCount: mergedIntervals.count,
            compressionRatio: compressionRatio
        )
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

