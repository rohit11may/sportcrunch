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
        
        statusSubject.send(.completed)
        progressSubject.send(1.0)
        
        return ProcessingResult(
            segments: segments,
            highlightURL: highlightURL,
            highlightDuration: highlightDuration
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
            throw ProcessingError.invalidVideoURL
        }
        
        // Get file size for display
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let fileSize = attrs[.size] as? Int64 {
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
        
        let audioResult: AudioAnalysisResult
        do {
            audioResult = try await audioAnalyzer.analyze(videoURL: sourceURL, sport: sport, sportMode: sportMode)
        } catch {
            print("⚙️ [VideoProcessor] ❌ Audio analysis failed: \(error.localizedDescription)")
            await MainActor.run {
                logger.error("Audio analysis failed: \(error.localizedDescription)")
            }
            throw ProcessingError.audioExtractionFailed
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
            let validations: [SegmentValidation]
            do {
                validations = try await visualValidator.validate(
                    videoURL: sourceURL,
                    candidates: audioResult.candidateIntervals,
                    sport: sport,
                    sportMode: sportMode
                )
            } catch {
                print("⚙️ [VideoProcessor] ⚠️ Visual validation failed, falling back to audio-only")
                print("⚙️ [VideoProcessor] Error: \(error.localizedDescription)")
                await MainActor.run {
                    logger.warning("Visual validation unavailable, using audio-only")
                }
                
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
                    pipelineStart: pipelineStart
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
            pipelineStart: pipelineStart
        )
    }
    
    // MARK: - Export Helper
    
    private func exportSegments(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        segments: [ActionSegment],
        pipelineStart: Date
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
            throw ProcessingError.exportFailed
        }
        
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
        
        return ProcessingResult(
            segments: segments,
            highlightURL: exportResult.outputURL,
            highlightDuration: exportResult.outputDuration
        )
    }
    
    // MARK: - Formatting
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Cancellation
    
    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        statusSubject.send(.pending)
        progressSubject.send(0.0)
    }
}

