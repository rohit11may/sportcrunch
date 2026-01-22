//
//  SpectralFluxMethod.swift
//  SportCrunch
//
//  Pure audio-only spectral flux detection method (v1).
//  No visual validation - faster processing.
//

import Foundation

// MARK: - Spectral Flux Method (Audio-Only)

/// Pure audio-only detection method using spectral flux onset detection.
///
/// Pipeline:
/// 1. Audio analysis via AudioAnalyzer (spectral flux onset detection)
/// 2. Direct conversion to ActionSegments (no visual validation)
///
/// This is the simpler, faster variant that relies purely on audio cues.
/// Use v2 (SpectralFluxVisualValidationMethod) if visual validation is needed.
///
/// Note: This is a final class (not an actor) to simplify protocol conformance.
/// The underlying AudioAnalyzer is an actor, providing thread safety.
final class SpectralFluxMethod: SegmentationMethod {

    // MARK: - Properties

    var name: String {
        "SpectralFlux"
    }

    // Components (actor provides thread safety)
    private let audioAnalyzer = AudioAnalyzer()

    // MARK: - Initialization

    init() {
        // Default initialization with standard components
    }

    // MARK: - Segmentation Method Protocol

    func detectSegments(
        videoURL: URL,
        sport: Sport,
        sportMode: SportMode?
    ) async throws -> [ActionSegment] {
        let logger = ProcessingLogger.shared

        // Audio Analysis Only
        await MainActor.run {
            logger.pipeline("Running audio-only analysis...")
        }

        let audioResult: AudioAnalysisResult
        do {
            audioResult = try await audioAnalyzer.analyze(
                videoURL: videoURL,
                sport: sport,
                sportMode: sportMode
            )
        } catch {
            print("⚙️ [SpectralFluxMethod] ❌ Audio analysis failed: \(error.localizedDescription)")
            throw error
        }

        guard !audioResult.candidateIntervals.isEmpty else {
            print("⚙️ [SpectralFluxMethod] ❌ No action detected in audio analysis")
            throw ProcessingError.noActionDetected
        }

        // Convert audio peaks directly to segments (no visual validation)
        print("⚙️ [SpectralFluxMethod] ✓ Detected \(audioResult.candidateIntervals.count) audio segments")
        await MainActor.run {
            logger.success("\(audioResult.candidateIntervals.count) segments detected (audio-only)")
        }

        let segments = audioResult.candidateIntervals.map { interval in
            ActionSegment(
                startTime: interval.start,
                endTime: interval.end,
                confidence: 0.85  // Good confidence for pure audio detection
            )
        }

        guard !segments.isEmpty else {
            print("⚙️ [SpectralFluxMethod] ❌ No action detected after processing")
            throw ProcessingError.noActionDetected
        }

        return segments
    }
}
