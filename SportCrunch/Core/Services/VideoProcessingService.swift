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
    private let audioAnalyzer = AudioAnalyzer()
    private let visualValidator = VisualValidator()
    private let videoExporter = VideoExporter()
    
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
        let debugReport = DebugReportService.shared
        
        // Start debug report for this processing run
        await debugReport.startReport(inputFileURL: sourceURL, sport: sport, sportMode: sportMode)
        
        // Track timing for each phase
        var audioExtractionTime: Double = 0
        var visualValidationTime: Double = 0
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
        print("⚙️ [VideoProcessor] 📊 Debug reporting: ENABLED")
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
            await debugReport.log(level: "error", component: "VideoProcessor", message: "File does not exist", data: ["path": sourceURL.path])
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
        // Phase 1: Audio Analysis (0-50% progress)
        // ═══════════════════════════════════════════════════════════════
        print("⚙️ [VideoProcessor] ┌─────────────────────────────────────────┐")
        print("⚙️ [VideoProcessor] │  PHASE 1/3: AUDIO ANALYSIS              │")
        print("⚙️ [VideoProcessor] └─────────────────────────────────────────┘")
        
        statusSubject.send(.analyzingAudio)
        progressSubject.send(0.05)
        
        let audioPhaseStart = Date()
        let audioResult: AudioAnalysisResult
        do {
            audioResult = try await audioAnalyzer.analyze(videoURL: sourceURL, sport: sport, sportMode: sportMode)
        } catch {
            print("⚙️ [VideoProcessor] ❌ Audio analysis failed: \(error.localizedDescription)")
            await MainActor.run {
                logger.error("Audio analysis failed: \(error.localizedDescription)")
            }
            await debugReport.log(level: "error", component: "AudioAnalyzer", message: "Audio analysis failed", data: ["error": error.localizedDescription])
            throw ProcessingError.audioExtractionFailed
        }
        audioExtractionTime = Date().timeIntervalSince(audioPhaseStart)
        
        // Record audio analysis debug data
        if let debugData = audioResult.debugData {
            let audioDetails = debugReport.createAudioAnalysisDetails(
                rawSamples: debugData.rawSamples,
                filteredSamples: debugData.filteredSamples,
                onsetStrength: debugData.onsetStrength,
                thresholds: debugData.thresholds,
                peakIndices: debugData.peakIndices,
                peakTimes: audioResult.peakTimes,
                clusters: debugData.clusters,
                candidateIntervals: audioResult.candidateIntervals,
                duration: audioResult.duration,
                framesPerSecond: debugData.framesPerSecond
            )
            await debugReport.recordAudioAnalysis(audioDetails)
        }
        
        guard !isCancelled else {
            print("⚙️ [VideoProcessor] ⚠️ Cancelled during audio analysis")
            await MainActor.run {
                logger.warning("Processing cancelled")
            }
            throw ProcessingError.cancelled
        }
        progressSubject.send(0.50)
        
        // Check if any candidates were found
        guard !audioResult.candidateIntervals.isEmpty else {
            print("⚙️ [VideoProcessor] ❌ No action detected in audio analysis")
            await MainActor.run {
                logger.error("No action detected in audio")
            }
            await debugReport.log(level: "error", component: "VideoProcessor", message: "No action detected in audio", data: nil)
            throw ProcessingError.noActionDetected
        }
        
        print("")
        
        // ═══════════════════════════════════════════════════════════════
        // Phase 2: Visual Validation (50-75% progress)
        // ═══════════════════════════════════════════════════════════════
        print("⚙️ [VideoProcessor] ┌─────────────────────────────────────────┐")
        print("⚙️ [VideoProcessor] │  PHASE 2/3: VISUAL VALIDATION           │")
        print("⚙️ [VideoProcessor] └─────────────────────────────────────────┘")
        
        statusSubject.send(.detectingAction)
        progressSubject.send(0.55)
        
        let finalIntervals: [(start: TimeInterval, end: TimeInterval)]
        let segments: [ActionSegment]
        
        // Check if visual validation should be skipped for this sport/mode
        if preset.skipVisualValidation {
            print("⚙️ [VideoProcessor] ✓ Skipping visual validation for \(sport.displayName) (audio-only mode)")
            await MainActor.run {
                logger.success("Using audio-only mode for \(sport.displayName) (visual validation skipped)")
            }
            
            // Use audio results directly with high confidence
            finalIntervals = audioResult.candidateIntervals
            segments = finalIntervals.map { interval in
                ActionSegment(
                    startTime: interval.start,
                    endTime: interval.end,
                    confidence: 0.9  // High confidence for audio-only tennis
                )
            }
            progressSubject.send(0.75)
        } else {
            // Perform visual validation for sports that need it
            let visualPhaseStart = Date()
            let validations: [SegmentValidation]
            do {
                // Progress during visual validation: 0.55 to 0.75 (range of 0.20)
                let visualProgressBase: Double = 0.55
                let visualProgressRange: Double = 0.20
                
                validations = try await visualValidator.validate(
                    videoURL: sourceURL,
                    candidates: audioResult.candidateIntervals,
                    sport: sport,
                    sportMode: sportMode,
                    progressHandler: { [weak self] batchProgress in
                        let overallProgress = visualProgressBase + (batchProgress * visualProgressRange)
                        self?.progressSubject.send(overallProgress)
                    }
                )
                visualValidationTime = Date().timeIntervalSince(visualPhaseStart)
                
                // Record detailed visual validation debug data
                await recordVisualValidationDebugData(
                    validations: validations,
                    preset: preset,
                    debugReport: debugReport
                )
                
            } catch {
                print("⚙️ [VideoProcessor] ⚠️ Visual validation failed, falling back to audio-only")
                print("⚙️ [VideoProcessor] Error: \(error.localizedDescription)")
                await MainActor.run {
                    logger.warning("Visual validation unavailable, using audio-only")
                }
                await debugReport.log(level: "warning", component: "VisualValidator", message: "Visual validation failed, using audio-only", data: ["error": error.localizedDescription])
                
                // If visual validation fails, fall back to using audio-only results
                let fallbackSegments = audioResult.candidateIntervals.map { interval in
                    ActionSegment(
                        startTime: interval.start,
                        endTime: interval.end,
                        confidence: 0.8
                    )
                }
                
                // Skip to export phase
                return try await exportSegments(
                    sourceURL: sourceURL,
                    intervals: audioResult.candidateIntervals,
                    segments: fallbackSegments,
                    pipelineStart: pipelineStart,
                    originalFileSize: originalFileSize,
                    audioExtractionTime: audioExtractionTime,
                    visualValidationTime: 0
                )
            }
            
            guard !isCancelled else {
                print("⚙️ [VideoProcessor] ⚠️ Cancelled during visual validation")
                await MainActor.run {
                    logger.warning("Processing cancelled")
                }
                throw ProcessingError.cancelled
            }
            progressSubject.send(0.75)
            
            // Filter to only valid (motion-confirmed) segments
            let validIntervals = validations
                .filter { $0.isValid }
                .map { (start: $0.start, end: $0.end) }
            
            // If no segments validated, try using all audio candidates with lower confidence
            if validIntervals.isEmpty {
                print("⚙️ [VideoProcessor] ⚠️ No segments passed visual validation, using audio-only results")
                await MainActor.run {
                    logger.warning("Low motion detected, using audio-only results")
                }
                finalIntervals = audioResult.candidateIntervals
                segments = audioResult.candidateIntervals.map { interval in
                    ActionSegment(
                        startTime: interval.start,
                        endTime: interval.end,
                        confidence: 0.6
                    )
                }
            } else {
                print("⚙️ [VideoProcessor] ✓ \(validIntervals.count) segments validated with motion")
                await MainActor.run {
                    logger.success("\(validIntervals.count) segments verified with motion")
                }
                finalIntervals = validIntervals
                segments = validations.filter { $0.isValid }.map { validation in
                    let normalizedScore = min(1.0, validation.motionScore / 2000.0)
                    let confidence = 0.7 + (normalizedScore * 0.3)
                    return ActionSegment(
                        startTime: validation.start,
                        endTime: validation.end,
                        confidence: confidence
                    )
                }
            }
        }
        
        guard !finalIntervals.isEmpty else {
            print("⚙️ [VideoProcessor] ❌ No action detected after validation")
            await MainActor.run {
                logger.error("No action detected after validation")
            }
            throw ProcessingError.noActionDetected
        }
        
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
            audioExtractionTime: audioExtractionTime,
            visualValidationTime: visualValidationTime
        )
    }
    
    // MARK: - Export Helper
    
    private func exportSegments(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        segments: [ActionSegment],
        pipelineStart: Date,
        originalFileSize: Int64,
        audioExtractionTime: Double = 0,
        visualValidationTime: Double = 0
    ) async throws -> ProcessingResult {
        let logger = ProcessingLogger.shared
        let debugReport = DebugReportService.shared
        
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
            await debugReport.log(level: "error", component: "VideoExporter", message: "Export failed", data: ["error": error.localizedDescription])
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
        
        // Record export details to debug report - convert from ExportDebugData to ExportDetails
        let exportDetails: ExportDetails
        if let debugData = exportResult.debugData {
            // Convert debug data to the report format
            let sourceProps: SourceVideoProperties? = {
                let src = debugData.sourceVideoProperties
                return SourceVideoProperties(
                    duration: src.duration,
                    durationCMTime: src.durationCMTime.debugString,
                    nominalFrameRate: src.nominalFrameRate,
                    minFrameDuration: src.minFrameDuration.debugString,
                    naturalTimeScale: src.naturalTimeScale,
                    videoTrackCount: src.videoTrackCount,
                    audioTrackCount: src.audioTrackCount,
                    naturalSize: "\(Int(src.naturalSize.width))x\(Int(src.naturalSize.height))",
                    preferredTransform: "a=\(src.preferredTransform.a),b=\(src.preferredTransform.b),c=\(src.preferredTransform.c),d=\(src.preferredTransform.d)",
                    isVideoPortrait: src.isVideoPortrait,
                    colorPrimaries: src.colorPrimaries,
                    transferFunction: src.transferFunction,
                    ycbcrMatrix: src.ycbcrMatrix,
                    videoCodecType: src.videoCodecType,
                    videoCodecName: src.videoCodecType,
                    hasVariableFrameRate: src.hasVariableFrameRate
                )
            }()
            
            let compConfig: CompositionConfig? = {
                let cfg = debugData.compositionConfig
                return CompositionConfig(
                    exportPreset: cfg.exportPreset,
                    outputFileType: cfg.outputFileType,
                    shouldOptimizeForNetworkUse: cfg.shouldOptimizeForNetworkUse,
                    usedVideoComposition: cfg.usedVideoComposition,
                    renderSize: cfg.renderSize != nil ? "\(Int(cfg.renderSize!.width))x\(Int(cfg.renderSize!.height))" : nil,
                    frameDuration: cfg.frameDuration?.debugString,
                    frameRate: cfg.frameRate,
                    colorPrimariesApplied: cfg.colorPrimariesApplied,
                    transferFunctionApplied: cfg.transferFunctionApplied,
                    ycbcrMatrixApplied: cfg.ycbcrMatrixApplied,
                    appliedTransform: cfg.appliedTransform != nil ? "a=\(cfg.appliedTransform!.a),b=\(cfg.appliedTransform!.b),c=\(cfg.appliedTransform!.c),d=\(cfg.appliedTransform!.d)" : nil
                )
            }()
            
            let segmentTimings: [SegmentTimingDetail]? = debugData.segmentTimingDetails.map { detail in
                SegmentTimingDetail(
                    segmentIndex: detail.segmentIndex,
                    requestedStartTime: detail.requestedStartTime,
                    requestedEndTime: detail.requestedEndTime,
                    requestedDuration: detail.requestedDuration,
                    startCMTime: detail.startCMTime.debugString,
                    endCMTime: detail.endCMTime.debugString,
                    durationCMTime: detail.durationCMTime.debugString,
                    insertionPosition: detail.insertionPosition.debugString,
                    insertedSuccessfully: detail.insertedSuccessfully,
                    errorMessage: detail.errorMessage,
                    timeRangeValid: detail.timeRangeValid,
                    clampedToVideoBounds: detail.clampedToVideoBounds
                )
            }
            
            let outputVerification: OutputVideoVerification? = {
                guard let ver = debugData.outputVerification else { return nil }
                return OutputVideoVerification(
                    duration: ver.duration,
                    durationCMTime: ver.durationCMTime.debugString,
                    expectedDuration: ver.expectedDuration,
                    durationMismatch: ver.durationMismatch,
                    durationMismatchPercent: ver.durationMismatchPercent,
                    nominalFrameRate: ver.nominalFrameRate,
                    frameRateMismatch: ver.frameRateMismatch,
                    sourceFrameRate: ver.sourceFrameRate,
                    naturalSize: ver.naturalSize != nil ? "\(Int(ver.naturalSize!.width))x\(Int(ver.naturalSize!.height))" : nil,
                    videoCodecType: ver.videoCodecType,
                    timingAccurate: ver.timingAccurate,
                    timingIssueDescription: ver.timingIssueDescription
                )
            }()
            
            exportDetails = debugReport.createExportDetails(
                outputFileName: exportResult.outputURL.lastPathComponent,
                outputFilePath: exportResult.outputURL.path,
                outputFileSizeBytes: highlightFileSize,
                outputDuration: exportResult.outputDuration,
                segmentsExported: segments.count,
                inputDuration: exportResult.inputDuration,
                sourceVideoProperties: sourceProps,
                compositionConfig: compConfig,
                segmentTimingDetails: segmentTimings,
                outputVideoVerification: outputVerification
            )
        } else {
            // No debug data - use basic export details
            exportDetails = ExportDetails(
                outputFileName: exportResult.outputURL.lastPathComponent,
                outputFilePath: exportResult.outputURL.path,
                outputFileSizeBytes: highlightFileSize,
                outputFileSizeMB: Double(highlightFileSize) / 1024 / 1024,
                outputDuration: exportResult.outputDuration,
                segmentsExported: segments.count,
                compressionRatio: exportResult.compressionRatio,
                sourceVideoProperties: nil,
                compositionConfig: nil,
                segmentTimingDetails: nil,
                outputVideoVerification: nil
            )
        }
        await debugReport.recordExport(exportDetails)
        
        // Record timing information
        let timing = TimingInfo(
            totalProcessingTime: totalElapsed,
            audioExtractionTime: audioExtractionTime,
            audioFilteringTime: 0,  // Included in audioExtractionTime
            onsetDetectionTime: 0,  // Included in audioExtractionTime
            peakDetectionTime: 0,   // Included in audioExtractionTime
            clusteringTime: 0,      // Included in audioExtractionTime
            visualValidationTime: visualValidationTime,
            exportTime: exportTime
        )
        await debugReport.recordTiming(timing)
        
        // Record final results
        let processingResults = ProcessingResults(
            success: true,
            errorMessage: nil,
            inputDuration: exportResult.inputDuration,
            outputDuration: exportResult.outputDuration,
            reductionPercent: exportResult.compressionRatio,
            segmentCount: segments.count,
            segments: segments.enumerated().map { index, segment in
                SegmentResult(
                    index: index,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    duration: segment.duration,
                    confidence: segment.confidence
                )
            }
        )
        await debugReport.recordResults(processingResults)
        
        // Finalize and save the debug report
        if let reportURL = try? await debugReport.finalizeReport() {
            print("📊 [VideoProcessor] Debug report saved: \(reportURL.lastPathComponent)")
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
    
    /// Record detailed visual validation debug data to the debug report.
    private func recordVisualValidationDebugData(
        validations: [SegmentValidation],
        preset: AnalysisPreset,
        debugReport: DebugReportService
    ) async {
        // Build frame processing info
        let frameProcessingInfo = FrameProcessingInfo(
            thumbnailWidth: preset.videoThumbSize.width,
            thumbnailHeight: preset.videoThumbSize.height,
            pixelCount: preset.videoThumbSize.width * preset.videoThumbSize.height,
            frameStride: preset.videoSampleStride,
            motionPixelThreshold: preset.motionPixelThreshold,
            motionAreaThreshold: preset.motionAreaThreshold,
            sourceVideoFPS: 0, // Will be updated from actual video
            sourceVideoResolution: "unknown"
        )
        
        // Build segment validation details from the debug data
        var segmentDetails: [SegmentValidationDetail] = []
        var allMotionScores: [Double] = []
        
        for (index, validation) in validations.enumerated() {
            // Collect all motion scores for aggregate stats
            if let debugData = validation.debugData {
                allMotionScores.append(contentsOf: debugData.allFrameScores)
                
                // Convert frame pair debug data to the report format
                var framePairDetails: [FramePairDetail]? = nil
                if !debugData.framePairDetails.isEmpty {
                    framePairDetails = debugData.framePairDetails.map { pair in
                        FramePairDetail(
                            pairIndex: pair.pairIndex,
                            frameATime: pair.frameATime,
                            frameBTime: pair.frameBTime,
                            frameAWidth: pair.frameAWidth,
                            frameAHeight: pair.frameAHeight,
                            frameBWidth: pair.frameBWidth,
                            frameBHeight: pair.frameBHeight,
                            frameAGrayscaleMean: pair.frameAGrayscaleMean,
                            frameAGrayscaleStdDev: pair.frameAGrayscaleStdDev,
                            frameBGrayscaleMean: pair.frameBGrayscaleMean,
                            frameBGrayscaleStdDev: pair.frameBGrayscaleStdDev,
                            rawDiffSum: pair.rawDiffSum,
                            rawDiffMean: pair.rawDiffMean,
                            rawDiffMax: pair.rawDiffMax,
                            pixelsAboveThreshold: pair.pixelsAboveThreshold,
                            motionScore: pair.motionScore
                        )
                    }
                }
                
                let detail = debugReport.createSegmentValidationDetail(
                    segmentIndex: index,
                    startTime: validation.start,
                    endTime: validation.end,
                    framesRequested: debugData.framesRequested,
                    framesExtracted: debugData.framesExtracted,
                    motionScore: validation.motionScore,
                    threshold: preset.motionAreaThreshold,
                    isValid: validation.isValid,
                    usedEarlyExit: debugData.usedEarlyExit,
                    framesProcessedBeforeDecision: debugData.framesProcessedBeforeDecision,
                    allFrameScores: debugData.allFrameScores,
                    framePairDetails: framePairDetails,
                    extractionErrors: debugData.extractionErrors.isEmpty ? nil : debugData.extractionErrors
                )
                segmentDetails.append(detail)
            } else {
                // No debug data available - create minimal entry
                let detail = debugReport.createSegmentValidationDetail(
                    segmentIndex: index,
                    startTime: validation.start,
                    endTime: validation.end,
                    framesRequested: 0,
                    framesExtracted: 0,
                    motionScore: validation.motionScore,
                    threshold: preset.motionAreaThreshold,
                    isValid: validation.isValid,
                    usedEarlyExit: false,
                    framesProcessedBeforeDecision: 0,
                    allFrameScores: [],
                    framePairDetails: nil,
                    extractionErrors: nil
                )
                segmentDetails.append(detail)
            }
        }
        
        // Create and record the visual validation details
        let visualDetails = debugReport.createVisualValidationDetails(
            segmentResults: segmentDetails,
            frameProcessingInfo: frameProcessingInfo,
            allMotionScores: allMotionScores
        )
        
        await debugReport.recordVisualValidation(visualDetails)
    }
    
    // MARK: - Cancellation
    
    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        statusSubject.send(.pending)
        progressSubject.send(0.0)
    }
}

