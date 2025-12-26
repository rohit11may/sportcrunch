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
    /// - Returns: Processing result with segments and highlight URL
    func processVideo(sourceURL: URL, sport: Sport) async throws -> ProcessingResult
    
    /// Cancel any ongoing processing
    func cancel()
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
    
    func processVideo(sourceURL: URL, sport: Sport) async throws -> ProcessingResult {
        isCancelled = false
        
        // Simulate processing stages
        try await simulateStage(.analyzingAudio, duration: 1.5)
        try await simulateStage(.detectingAction, duration: 2.0)
        try await simulateStage(.creatingClips, duration: 1.5)
        try await simulateStage(.exporting, duration: 1.0)
        
        // Generate dummy segments
        let segments = generateDummySegments(sport: sport)
        
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
    
    private func generateDummySegments(sport: Sport) -> [ActionSegment] {
        // Generate 8-15 random segments to simulate detected action
        let segmentCount = Int.random(in: 8...15)
        var segments: [ActionSegment] = []
        var currentTime: TimeInterval = 10 // Start after 10 seconds
        
        for _ in 0..<segmentCount {
            // Each segment is 15-60 seconds
            let duration = TimeInterval.random(in: 15...60)
            
            // Gap between segments is 30-180 seconds (the "dead space")
            let gap = TimeInterval.random(in: 30...180)
            
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
    
    func processVideo(sourceURL: URL, sport: Sport) async throws -> ProcessingResult {
        isCancelled = false
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ProcessingError.invalidVideoURL
        }
        
        // Phase 1: Audio Analysis (0-50% progress)
        statusSubject.send(.analyzingAudio)
        progressSubject.send(0.05)
        
        let audioResult: AudioAnalysisResult
        do {
            audioResult = try await audioAnalyzer.analyze(videoURL: sourceURL, sport: sport)
        } catch {
            throw ProcessingError.audioExtractionFailed
        }
        
        guard !isCancelled else { throw ProcessingError.cancelled }
        progressSubject.send(0.50)
        
        // Check if any candidates were found
        guard !audioResult.candidateIntervals.isEmpty else {
            throw ProcessingError.noActionDetected
        }
        
        // Phase 2: Visual Validation (50-75% progress)
        statusSubject.send(.detectingAction)
        progressSubject.send(0.55)
        
        let validations: [SegmentValidation]
        do {
            validations = try await visualValidator.validate(
                videoURL: sourceURL,
                candidates: audioResult.candidateIntervals
            )
        } catch {
            // If visual validation fails, fall back to using audio-only results
            // This is acceptable as audio detection has high recall
            let segments = audioResult.candidateIntervals.map { interval in
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
                segments: segments
            )
        }
        
        guard !isCancelled else { throw ProcessingError.cancelled }
        progressSubject.send(0.75)
        
        // Filter to only valid (motion-confirmed) segments
        let validIntervals = validations
            .filter { $0.isValid }
            .map { (start: $0.start, end: $0.end) }
        
        // If no segments validated, try using all audio candidates with lower confidence
        let finalIntervals: [(start: TimeInterval, end: TimeInterval)]
        let segments: [ActionSegment]
        
        if validIntervals.isEmpty {
            // Fall back to audio-only detection
            finalIntervals = audioResult.candidateIntervals
            segments = finalIntervals.map { interval in
                ActionSegment(
                    startTime: interval.start,
                    endTime: interval.end,
                    confidence: 0.6  // Lower confidence since not visually validated
                )
            }
        } else {
            finalIntervals = validIntervals
            segments = validations.filter { $0.isValid }.map { validation in
                // Map motion score to confidence (normalize to 0.7-1.0 range)
                let normalizedScore = min(1.0, validation.motionScore / 2000.0)
                let confidence = 0.7 + (normalizedScore * 0.3)
                return ActionSegment(
                    startTime: validation.start,
                    endTime: validation.end,
                    confidence: confidence
                )
            }
        }
        
        guard !finalIntervals.isEmpty else {
            throw ProcessingError.noActionDetected
        }
        
        // Phase 3: Export (75-100% progress)
        return try await exportSegments(
            sourceURL: sourceURL,
            intervals: finalIntervals,
            segments: segments
        )
    }
    
    // MARK: - Export Helper
    
    private func exportSegments(
        sourceURL: URL,
        intervals: [(start: TimeInterval, end: TimeInterval)],
        segments: [ActionSegment]
    ) async throws -> ProcessingResult {
        statusSubject.send(.creatingClips)
        progressSubject.send(0.80)
        
        guard !isCancelled else { throw ProcessingError.cancelled }
        
        // Create output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
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
            throw ProcessingError.exportFailed
        }
        
        guard !isCancelled else {
            // Clean up exported file if cancelled
            try? FileManager.default.removeItem(at: outputURL)
            throw ProcessingError.cancelled
        }
        
        statusSubject.send(.completed)
        progressSubject.send(1.0)
        
        return ProcessingResult(
            segments: segments,
            highlightURL: exportResult.outputURL,
            highlightDuration: exportResult.outputDuration
        )
    }
    
    // MARK: - Cancellation
    
    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        statusSubject.send(.pending)
        progressSubject.send(0.0)
    }
}

