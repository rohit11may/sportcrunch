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
    func processVideo(sourceURL: URL, sport: Sport, sportMode: SportMode?) async throws -> ProcessingResult
    
    /// Cancel any ongoing processing
    func cancel()
}

// MARK: - Protocol Extension for Default Parameter

extension VideoProcessingServiceProtocol {
    /// Convenience method without sport mode (uses default)
    func processVideo(sourceURL: URL, sport: Sport) async throws -> ProcessingResult {
        try await processVideo(sourceURL: sourceURL, sport: sport, sportMode: nil)
    }
}

// MARK: - Dummy Implementation

/// Dummy implementation that simulates processing with delays.
/// Replace this with real implementation using Accelerate/Vision frameworks.
final class DummyVideoProcessingService: VideoProcessingServiceProtocol {
    
    private let statusSubject = CurrentValueSubject<ProcessingStatus, Never>(.pending)
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    private var isCancelled = false
    
    var statusPublisher: AnyPublisher<ProcessingStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    func processVideo(sourceURL: URL, sport: Sport, sportMode: SportMode?) async throws -> ProcessingResult {
        isCancelled = false
        
        // Simulate processing stages
        try await simulateStage(.analyzingAudio, duration: 1.5)
        try await simulateStage(.detectingAction, duration: 2.0)
        try await simulateStage(.creatingClips, duration: 1.5)
        try await simulateStage(.exporting, duration: 1.0)
        
        // Generate dummy segments based on mode
        let segments = generateDummySegments(sport: sport, sportMode: sportMode)
        
        // Calculate highlight duration (sum of all segments)
        let highlightDuration = segments.reduce(0) { $0 + $1.duration }
        
        // For dummy, just return the source URL as the highlight
        // In real implementation, this would be the exported file URL
        let highlightURL = sourceURL
        
        // Get original file size (or use dummy value)
        let originalFileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let size = attrs[.size] as? Int64 {
            originalFileSize = size
        } else {
            originalFileSize = 2_684_354_560 // Dummy: 2.5 GB
        }
        
        // Estimate highlight file size based on duration ratio
        let durationRatio = highlightDuration / 7200.0 // Assume 2 hour original
        let highlightFileSize = Int64(Double(originalFileSize) * min(durationRatio, 0.3))
        
        statusSubject.send(.completed)
        progressSubject.send(1.0)
        
        return ProcessingResult(
            segments: segments,
            highlightURL: highlightURL,
            highlightDuration: highlightDuration,
            originalFileSize: originalFileSize,
            highlightFileSize: highlightFileSize
        )
    }
    
    func cancel() {
        isCancelled = true
        statusSubject.send(.pending)
        progressSubject.send(0.0)
    }
    
    // MARK: - Private Helpers
    
    private func simulateStage(_ status: ProcessingStatus, duration: TimeInterval) async throws {
        guard !isCancelled else { throw ProcessingError.cancelled }
        
        statusSubject.send(status)
        
        let steps = 20
        let stepDuration = duration / Double(steps)
        let baseProgress = status.progress - 0.25
        
        for i in 0..<steps {
            guard !isCancelled else { throw ProcessingError.cancelled }
            
            try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            
            let stageProgress = Double(i + 1) / Double(steps) * 0.25
            progressSubject.send(baseProgress + stageProgress)
        }
    }
    
    private func generateDummySegments(sport: Sport, sportMode: SportMode?) -> [ActionSegment] {
        // Check if individual mode for tennis - generate more, shorter clips
        let isIndividualMode = (sportMode as? TennisMode) == .individual
        
        // Generate segments based on mode
        let segmentCount = isIndividualMode ? Int.random(in: 20...40) : Int.random(in: 8...15)
        var segments: [ActionSegment] = []
        var currentTime: TimeInterval = 10 // Start after 10 seconds
        
        for _ in 0..<segmentCount {
            // Individual mode: short 1-2s clips; Rally mode: 15-60s clips
            let duration = isIndividualMode
                ? TimeInterval.random(in: 1...2)
                : TimeInterval.random(in: 15...60)
            
            // Gap between segments
            let gap = isIndividualMode
                ? TimeInterval.random(in: 5...30)  // Shorter gaps in individual mode
                : TimeInterval.random(in: 30...180)
            
            let segment = ActionSegment(
                startTime: currentTime,
                endTime: currentTime + duration,
                confidence: Double.random(in: 0.7...1.0)
            )
            
            segments.append(segment)
            currentTime += duration + gap
        }
        
        return segments
    }
}

// MARK: - Real Implementation

/// Real implementation using Accelerate and Vision frameworks.
/// Orchestrates AudioAnalyzer, VisualValidator, and VideoExporter.
final class RealVideoProcessingService: VideoProcessingServiceProtocol {

    // MARK: - Properties

    private let statusSubject = CurrentValueSubject<ProcessingStatus, Never>(.pending)
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    private var processingTask: Task<ProcessingResult, Error>?
    private var isCancelled = false

    // Components
    private let method: any SegmentationMethod
    private let videoExporter = VideoExporter()

    // Debug reporting
    private let reportManager: ProcessingReportManagerProtocol?

    // MARK: - Initialization

    init(
        method: (any SegmentationMethod)? = nil,
        reportManager: ProcessingReportManagerProtocol? = nil
    ) {
        self.method = method ?? SpectralFluxMethod()
        self.reportManager = reportManager
    }

    var statusPublisher: AnyPublisher<ProcessingStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Processing
    
    func processVideo(sourceURL: URL, sport: Sport, sportMode: SportMode?) async throws -> ProcessingResult {
        isCancelled = false
        let pipelineStart = Date()
        let logger = ProcessingLogger.shared

        // Start debug report for this processing run (if reporting enabled)
        var debugBuilder: DebugReportBuilder? = nil
        if let reportManager = reportManager {
            debugBuilder = await reportManager.startReport(for: nil, sourceURL: sourceURL, sport: sport, sportMode: sportMode)
        }

        // Track timing for each phase
        var detectionTime: Double = 0
        var exportTime: Double = 0
        
        // Get the preset for this sport/mode combination
        let preset = sport.preset(for: sportMode)
        let modeDescription = (sportMode as? TennisMode)?.displayName ?? "Default"
        
        print("")
        print("⚙️ [VideoProcessor] ╔═══════════════════════════════════════════════════════════╗")
        print("⚙️ [VideoProcessor] ║       SPORTCRUNCH HIGHLIGHT CREATION STARTED              ║")
        print("⚙️ [VideoProcessor] ╚═══════════════════════════════════════════════════════════╝")
        print("⚙️ [VideoProcessor] Sport: \(sport.displayName) \(sport.emoji)")
        print("⚙️ [VideoProcessor] Mode: \(modeDescription)")
        print("⚙️ [VideoProcessor] Source: \(sourceURL.lastPathComponent)")
        print("⚙️ [VideoProcessor] Path: \(sourceURL.path)")
        print("⚙️ [VideoProcessor] Preset: padding=\(preset.paddingPreSec)s/\(preset.paddingPostSec)s, maxGap=\(preset.clusterMaxGapSec)s")
        if reportManager != nil {
            print("⚙️ [VideoProcessor] 📊 Debug reporting: ENABLED")
        }
        print("")
        
        await MainActor.run {
            logger.pipeline("Starting highlight creation for \(sport.displayName) (\(modeDescription))...")
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("⚙️ [VideoProcessor] ❌ ERROR: File does not exist!")
            await MainActor.run {
                logger.error("Video file not found")
            }
            if let reportManager = reportManager {
                await reportManager.log(level: "error", component: "VideoProcessor", message: "File does not exist", data: ["path": sourceURL.path])
            }
            throw ProcessingError.invalidVideoURL
        }
        
        // Get file size for display and storage
        var originalFileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let fileSize = attrs[.size] as? Int64 {
            originalFileSize = fileSize
            let mb = Double(fileSize) / 1024 / 1024
            print("⚙️ [VideoProcessor] File size: \(String(format: "%.1f", mb)) MB")
            await MainActor.run {
                logger.pipeline("Processing \(String(format: "%.1f", mb)) MB video...")
            }
        }
        print("")

        // ═══════════════════════════════════════════════════════════════
        // Phase 1-2: Segment Detection (0-75% progress)
        // ═══════════════════════════════════════════════════════════════
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

            // Map sport/sportMode to method config
            let preset = sport.preset(for: sportMode)
            let config = MethodConfig(
                audioThresholdMultiplier: Double(preset.onsetThresholdLambda),
                peakMinDistance: preset.peakMinDistanceSec,
                clusterMaxGapSec: preset.clusterMaxGapSec,
                paddingPreSec: preset.paddingPreSec,
                paddingPostSec: preset.paddingPostSec,
                motionThreshold: preset.skipVisualValidation ? nil : Double(preset.motionAreaThreshold)
            )

            // Detect segments using method with config
            segments = try await method.detectSegments(
                videoURL: sourceURL,
                config: config
            )

            detectionTime = Date().timeIntervalSince(detectionPhaseStart)

            // Log detection results
            if let reportManager = reportManager {
                await reportManager.log(
                    level: "info",
                    component: "SegmentationMethod",
                    message: "Detection complete using \(method.name)",
                    data: ["segmentCount": "\(segments.count)", "duration": "\(detectionTime)"]
                )
            }

        } catch {
            print("⚙️ [VideoProcessor] ❌ Segment detection failed: \(error.localizedDescription)")
            await MainActor.run {
                logger.error("Segment detection failed: \(error.localizedDescription)")
            }
            if let reportManager = reportManager {
                await reportManager.log(
                    level: "error",
                    component: "SegmentationMethod",
                    message: "Detection failed",
                    data: ["error": error.localizedDescription, "method": method.name]
                )
            }
            throw error
        }

        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled during segment detection")
            await MainActor.run {
                logger.warning("Processing cancelled")
            }
            throw ProcessingError.cancelled
        }

        guard !segments.isEmpty else {
            print("⚙️ [VideoProcessor] ❌ No action detected")
            await MainActor.run {
                logger.error("No action detected")
            }
            throw ProcessingError.noActionDetected
        }

        progressSubject.send(0.75)
        print("⚙️ [VideoProcessor] ✓ Detected \(segments.count) segments using \(method.name)")
        await MainActor.run {
            logger.success("\(segments.count) segments detected")
        }

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
            originalFileSize: originalFileSize,
            detectionTime: detectionTime,
            debugBuilder: &debugBuilder
        )
    }
    
    // MARK: - Export Helper

    private func exportSegments(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        segments: [ActionSegment],
        pipelineStart: Date,
        originalFileSize: Int64,
        detectionTime: Double = 0,
        debugBuilder: inout DebugReportBuilder?
    ) async throws -> ProcessingResult {
        let logger = ProcessingLogger.shared
        
        print("⚙️ [VideoProcessor] ┌─────────────────────────────────────────┐")
        print("⚙️ [VideoProcessor] │  PHASE 3/3: VIDEO EXPORT                │")
        print("⚙️ [VideoProcessor] └─────────────────────────────────────────┘")
        
        statusSubject.send(.creatingClips)
        progressSubject.send(0.80)
        
        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled before export")
            await MainActor.run {
                logger.warning("Processing cancelled")
            }
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
            await MainActor.run {
                logger.error("Export failed: \(error.localizedDescription)")
            }
            if let reportManager = reportManager {
                await reportManager.log(level: "error", component: "VideoExporter", message: "Export failed", data: ["error": error.localizedDescription])
            }
            throw ProcessingError.exportFailed
        }
        let exportTime = Date().timeIntervalSince(exportPhaseStart)
        
        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled after export, cleaning up...")
            await MainActor.run {
                logger.warning("Cancelled, cleaning up...")
            }
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
        
        await MainActor.run {
            logger.success("Highlight created! \(formatTime(exportResult.inputDuration)) → \(formatTime(exportResult.outputDuration)) in \(String(format: "%.1f", totalElapsed))s")
        }
        
        // Get highlight file size
        var highlightFileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: exportResult.outputURL.path),
           let size = attrs[.size] as? Int64 {
            highlightFileSize = size
            let mb = Double(size) / 1024 / 1024
            print("⚙️ [VideoProcessor]    • Highlight size: \(String(format: "%.1f", mb)) MB")
        }

        // Record debug report data
        if let reportManager = reportManager, var builder = debugBuilder {
            // Record export details
            await reportManager.recordExport(exportResult, originalFileSize: originalFileSize, to: &builder)

            // Record timing information
            await reportManager.recordTiming(
                totalTime: totalElapsed,
                audioTime: detectionTime,  // Detection time (was audio + visual)
                visualTime: 0,  // No longer separated
                exportTime: exportTime,
                to: &builder
            )

            // Finalize report
            try? await reportManager.finalizeReport(
                builder,
                segments: segments,
                inputDuration: exportResult.inputDuration,
                outputDuration: exportResult.outputDuration
            )
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
    
    // MARK: - Debug Data Recording
    // MARK: - Cancellation
    
    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        statusSubject.send(.pending)
        progressSubject.send(0.0)
    }
}

