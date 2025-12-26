//
//  VideoExporter.swift
//  SportCrunch
//
//  Extracts and concatenates video segments using AVFoundation.
//  Port of Python prototype's video_editor.py.
//

import Foundation
import AVFoundation

// MARK: - Export Result

struct ExportResult {
    let outputURL: URL
    let inputDuration: TimeInterval
    let outputDuration: TimeInterval
    let segmentCount: Int
    let compressionRatio: Double  // Percentage of video kept
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
    /// - Returns: Export result with statistics
    func export(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        outputURL: URL
    ) async throws -> ExportResult {
        let asset = AVURLAsset(url: sourceURL)
        
        // Load asset properties
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.load(.tracks)
        
        guard !tracks.isEmpty else {
            throw VideoExporterError.cannotAccessFile
        }
        
        // Merge overlapping intervals
        let mergedIntervals = mergeIntervals(intervals, videoDuration: duration)
        
        guard !mergedIntervals.isEmpty else {
            throw VideoExporterError.noValidIntervals
        }
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.compositionFailed
        }
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExporterError.compositionFailed
        }
        
        // Add audio track if present
        let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
        var compositionAudioTrack: AVMutableCompositionTrack?
        
        if audioTrack != nil {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }
        
        // Insert each interval into the composition
        var insertionTime = CMTime.zero
        
        for interval in mergedIntervals {
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
            } catch {
                // Skip segments that fail to insert
                continue
            }
        }
        
        // Ensure output directory exists
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoExporterError.exportFailed("Could not create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Perform export
        await exportSession.export()
        
        // Check export status
        switch exportSession.status {
        case .completed:
            break
        case .cancelled:
            throw VideoExporterError.exportCancelled
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            throw VideoExporterError.exportFailed(errorMessage)
        default:
            throw VideoExporterError.exportFailed("Unexpected export status")
        }
        
        // Calculate statistics
        let outputDuration = mergedIntervals.reduce(0) { $0 + ($1.end - $1.start) }
        let compressionRatio = duration > 0 ? (1 - outputDuration / duration) * 100 : 0
        
        return ExportResult(
            outputURL: outputURL,
            inputDuration: duration,
            outputDuration: outputDuration,
            segmentCount: mergedIntervals.count,
            compressionRatio: compressionRatio
        )
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

