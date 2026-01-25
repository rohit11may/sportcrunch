//
//  SpectralFluxMethod.swift
//  SportCrunch
//
//  Spectral flux + visual validation detection method.
//  Wraps AudioAnalyzer and VisualValidator into a pluggable method.
//

import Foundation

// MARK: - Spectral Flux Visual Validation Method

/// Detection method using spectral flux audio analysis and visual validation.
///
/// Pipeline:
/// 1. Audio analysis via AudioAnalyzer (spectral flux onset detection)
/// 2. Visual validation via VisualValidator (motion confirmation)
/// 3. Returns validated ActionSegments
///
/// Note: This is a final class (not an actor) to simplify protocol conformance.
/// The underlying AudioAnalyzer and VisualValidator are actors, providing
/// thread safety for the actual processing work.
final class SpectralFluxMethod: SegmentationMethod {

    // MARK: - Properties

    var name: String { "SpectralFlux" }

    private let config: SpectralFluxMethodConfig
    private let audioAnalyzer = SpectralFluxAudioAnalyzer()
    private let visualValidator = SpectralFluxVisualValidator()

    // MARK: - Initialization

    init(config: SpectralFluxMethodConfig) {
        self.config = config
    }

    // MARK: - Segmentation Method Protocol

    func detectSegments(videoURL: URL, observation: RunObservation?) async throws -> [ActionSegment] {
        // Phase 1: Audio Analysis

        let audioResult: AudioAnalysisResult
        do {
            audioResult = try await audioAnalyzer.analyze(
                videoURL: videoURL,
                config: self.config,
                observation: observation
            )
        } catch {
            print("⚙️ [SpectralFluxMethod] ❌ Audio analysis failed: \(error.localizedDescription)")
            throw error
        }

        guard !audioResult.candidateIntervals.isEmpty else {
            print("⚙️ [SpectralFluxMethod] ❌ No action detected in audio analysis")
            throw ProcessingError.noActionDetected
        }

        // Phase 2: Visual Validation (or skip if motion threshold not specified)
        let segments: [ActionSegment]

        if self.config.motionThreshold == nil {
            // Audio-only mode
            print("⚙️ [SpectralFluxMethod] ✓ Skipping visual validation (audio-only mode)")

            segments = audioResult.candidateIntervals.map { interval in
                ActionSegment(
                    startTime: interval.start,
                    endTime: interval.end
                )
            }
        } else {
            // Run visual validation

            let validations: [SegmentValidation]
            do {
                validations = try await visualValidator.validate(
                    videoURL: videoURL,
                    candidates: audioResult.candidateIntervals,
                    config: self.config,
                    observation: observation,
                    progressHandler: nil  // No progress reporting in method layer
                )
            } catch {
                // Fallback to audio-only if visual validation fails
                print("⚙️ [SpectralFluxMethod] ⚠️ Visual validation failed, using audio-only")
                print("⚙️ [SpectralFluxMethod] Error: \(error.localizedDescription)")

                segments = audioResult.candidateIntervals.map { interval in
                    ActionSegment(
                        startTime: interval.start,
                        endTime: interval.end
                    )
                }

                return segments
            }

            // Convert validations to segments
            let validIntervals = validations.filter { $0.isValid }

            if validIntervals.isEmpty {
                // No segments passed validation, use audio-only with lower confidence
                print("⚙️ [SpectralFluxMethod] ⚠️ No segments passed visual validation, using audio-only")

                segments = audioResult.candidateIntervals.map { interval in
                    ActionSegment(
                        startTime: interval.start,
                        endTime: interval.end
                    )
                }
            } else {
                // Use validated segments
                print("⚙️ [SpectralFluxMethod] ✓ \(validIntervals.count) segments validated with motion")

                segments = validations.filter { $0.isValid }.map { validation in
                    return ActionSegment(
                        startTime: validation.start,
                        endTime: validation.end
                    )
                }
            }
        }

        guard !segments.isEmpty else {
            print("⚙️ [SpectralFluxMethod] ❌ No action detected after processing")
            throw ProcessingError.noActionDetected
        }

        return segments
    }
}
