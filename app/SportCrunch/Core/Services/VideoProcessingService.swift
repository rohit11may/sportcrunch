//
//  VideoProcessingService.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Processing Result

struct ProcessingResult {
    let segments: [ActionSegment]
    let highlightURL: URL
    let highlightDuration: TimeInterval
    let originalFileSize: Int64
    let highlightFileSize: Int64
}

// MARK: - Processing Error

enum ProcessingError: Error, LocalizedError {
    case invalidVideoURL
    case audioExtractionFailed
    case noActionDetected
    case exportFailed
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidVideoURL:
            return "The video file could not be accessed."
        case .audioExtractionFailed:
            return "Failed to extract audio from the video."
        case .noActionDetected:
            return "No action was detected in the video."
        case .exportFailed:
            return "Failed to export the highlight video."
        case .cancelled:
            return "Processing was cancelled."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Video Processing Service Protocol

/// Protocol defining the video processing service interface.
/// This allows for easy swapping between dummy and real implementations.
protocol VideoProcessingServiceProtocol {
    /// Current processing status
    var statusPublisher: AnyPublisher<ProcessingStatus, Never> { get }

    /// Current progress (0.0 to 1.0)
    var progressPublisher: AnyPublisher<Double, Never> { get }

    /// Process a video file to extract highlights
    /// - Parameters:
    ///   - sourceURL: URL to the source video file
    ///   - sport: The sport type for detection tuning
    ///   - sportMode: Optional sport-specific mode (e.g., TennisMode.rally)
    /// - Returns: Processing result with segments and highlight URL
    func processVideo(sourceURL: URL, sport: Sport, sportMode: (any SportMode)?) async throws -> ProcessingResult
}

// MARK: - Real Implementation

/// Real implementation using Accelerate and Vision frameworks.
/// Orchestrates AudioAnalyzer, VisualValidator, and VideoExporter.
final class RealVideoProcessingService: VideoProcessingServiceProtocol {

    // MARK: - Properties

    private let statusSubject = CurrentValueSubject<ProcessingStatus, Never>(.pending)
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    private var isCancelled = false

    // Components
    private let videoExporter = VideoExporter()

    // MARK: - Initialization

    init() {
    }

    var statusPublisher: AnyPublisher<ProcessingStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    // MARK: - Processing

    func processVideo(sourceURL: URL, sport: Sport, sportMode: (any SportMode)?) async throws -> ProcessingResult {
        isCancelled = false
        let pipelineStart = Date()

        let modeDescription = (sportMode as? TennisMode)?.displayName ?? "Default"

        print("")
        print("⚙️ [VideoProcessor] ╔═══════════════════════════════════════════════════════════╗")
        print("⚙️ [VideoProcessor] ║       SPORTCRUNCH HIGHLIGHT CREATION STARTED              ║")
        print("⚙️ [VideoProcessor] ╚═══════════════════════════════════════════════════════════╝")
        print("⚙️ [VideoProcessor] Sport: \(sport.displayName) \(sport.emoji)")
        print("⚙️ [VideoProcessor] Mode: \(modeDescription)")
        print("⚙️ [VideoProcessor] Source: \(sourceURL.lastPathComponent)")
        print("⚙️ [VideoProcessor] Path: \(sourceURL.path)")
        print("")

        // Verify file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("⚙️ [VideoProcessor] ❌ ERROR: File does not exist!")
            throw ProcessingError.invalidVideoURL
        }

        // Get file size for display and storage
        var originalFileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let fileSize = attrs[.size] as? Int64 {
            originalFileSize = fileSize
            let mb = Double(fileSize) / 1024 / 1024
            print("⚙️ [VideoProcessor] File size: \(String(format: "%.1f", mb)) MB")
        }
        print("")

        // ═══════════════════════════════════════════════════════════════
        // Phase 1-2: Segment Detection (0-75% progress)
        // ═══════════════════════════════════════════════════════════════
        let method = sport.segmentationMethod(for: sportMode)

        print("⚙️ [VideoProcessor] ┌─────────────────────────────────────────┐")
        print("⚙️ [VideoProcessor] │  PHASE 1-2/3: SEGMENT DETECTION         │")
        print("⚙️ [VideoProcessor] │  Method: \(method.name)                 │")
        print("⚙️ [VideoProcessor] └─────────────────────────────────────────┘")

        statusSubject.send(.analyzingAudio)
        progressSubject.send(0.05)

        let detectionPhaseStart = Date()
        let segments: [ActionSegment]

        do {
            // Update progress through detection phases
            statusSubject.send(.detectingAction)
            progressSubject.send(0.40)

            // Detect segments using configured method
            segments = try await method.detectSegments(videoURL: sourceURL)

        } catch {
            print("⚙️ [VideoProcessor] ❌ Segment detection failed: \(error.localizedDescription)")
            throw error
        }

        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled during segment detection")
            throw ProcessingError.cancelled
        }

        guard !segments.isEmpty else {
            print("⚙️ [VideoProcessor] ❌ No action detected")
            throw ProcessingError.noActionDetected
        }

        progressSubject.send(0.75)
        print("⚙️ [VideoProcessor] ✓ Detected \(segments.count) segments using \(method.name)")

        // Build intervals for export
        let finalIntervals = segments.map { (start: $0.startTime, end: $0.endTime) }

        print("")

        // ═══════════════════════════════════════════════════════════════
        // Phase 3: Export (75-100% progress)
        // ═══════════════════════════════════════════════════════════════
        return try await exportSegments(
            sourceURL: sourceURL,
            intervals: finalIntervals,
            segments: segments,
            pipelineStart: pipelineStart,
            originalFileSize: originalFileSize
        )
    }

    // MARK: - Export Helper

    private func exportSegments(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        segments: [ActionSegment],
        pipelineStart: Date,
        originalFileSize: Int64
    ) async throws -> ProcessingResult {
        print("⚙️ [VideoProcessor] ┌─────────────────────────────────────────┐")
        print("⚙️ [VideoProcessor] │  PHASE 3/3: VIDEO EXPORT                │")
        print("⚙️ [VideoProcessor] └─────────────────────────────────────────┘")

        statusSubject.send(.creatingClips)
        progressSubject.send(0.80)

        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled before export")
            throw ProcessingError.cancelled
        }

        // Create output URL in Documents directory for persistence
        // (temp directory gets cleaned up by the system)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let highlightsDir = documentsURL.appendingPathComponent("Highlights", isDirectory: true)

        // Create Highlights directory if it doesn't exist
        try? FileManager.default.createDirectory(at: highlightsDir, withIntermediateDirectories: true)

        let outputURL = highlightsDir
            .appendingPathComponent("SportCrunch_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        statusSubject.send(.exporting)
        progressSubject.send(0.85)

        let exportPhaseStart = Date()
        let exportResult: ExportResult
        do {
            exportResult = try await videoExporter.export(
                sourceURL: sourceURL,
                intervals: intervals,
                outputURL: outputURL
            )
        } catch {
            print("⚙️ [VideoProcessor] ❌ Export failed: \(error.localizedDescription)")
            throw ProcessingError.exportFailed
        }
        _ = Date().timeIntervalSince(exportPhaseStart)

        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled after export, cleaning up...")
            try? FileManager.default.removeItem(at: outputURL)
            throw ProcessingError.cancelled
        }

        statusSubject.send(.completed)
        progressSubject.send(1.0)

        let totalElapsed = Date().timeIntervalSince(pipelineStart)

        print("")
        print("⚙️ [VideoProcessor] ╔═══════════════════════════════════════════════════════════╗")
        print("⚙️ [VideoProcessor] ║       🎉 HIGHLIGHT CREATION COMPLETE! 🎉                  ║")
        print("⚙️ [VideoProcessor] ╚═══════════════════════════════════════════════════════════╝")
        print("⚙️ [VideoProcessor] ⏱️  Total processing time: \(String(format: "%.2f", totalElapsed)) seconds")
        print("⚙️ [VideoProcessor] 📊 Summary:")
        print("⚙️ [VideoProcessor]    • Input: \(formatTime(exportResult.inputDuration))")
        print("⚙️ [VideoProcessor]    • Output: \(formatTime(exportResult.outputDuration))")
        print("⚙️ [VideoProcessor]    • Reduction: \(String(format: "%.1f", exportResult.compressionRatio))%")
        print("⚙️ [VideoProcessor]    • Segments: \(segments.count)")
        print("⚙️ [VideoProcessor] 📁 Output: \(outputURL.lastPathComponent)")
        print("")

        // Get highlight file size
        var highlightFileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: exportResult.outputURL.path),
           let size = attrs[.size] as? Int64 {
            highlightFileSize = size
            let mb = Double(size) / 1024 / 1024
            print("⚙️ [VideoProcessor]    • Highlight size: \(String(format: "%.1f", mb)) MB")
        }

        return ProcessingResult(
            segments: segments,
            highlightURL: exportResult.outputURL,
            highlightDuration: exportResult.outputDuration,
            originalFileSize: originalFileSize,
            highlightFileSize: highlightFileSize
        )
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
