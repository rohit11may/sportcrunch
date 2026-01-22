//
//  SpectralFluxMethod.swift
//  SportCrunch
//
//  Spectral flux + visual validation detection method.
//  Wraps AudioAnalyzer and VisualValidator into a pluggable method.
//

import Foundation

// MARK: - Spectral Flux Method

/// Detection method using spectral flux audio analysis and visual validation.
///
/// Pipeline:
/// 1. Audio analysis via AudioAnalyzer (spectral flux onset detection)
/// 2. Visual validation via VisualValidator (motion confirmation)
/// 3. Returns validated ActionSegments
///
/// This is the current production detection method, extracted from the
/// VideoProcessingService for swappability.
///
/// Note: This is a final class (not an actor) to simplify protocol conformance.
/// The underlying AudioAnalyzer and VisualValidator are actors, providing
/// thread safety for the actual processing work.
final class SpectralFluxMethod: SegmentationMethod {

    // MARK: - Properties

    var name: String {
        "SpectralFlux+VisualValidation"
    }

    // Components (actors provide thread safety)
    private let audioAnalyzer = AudioAnalyzer()
    private let visualValidator = VisualValidator()

    // MARK: - Initialization

    init() {
        // Default initialization with standard components
    }

    // MARK: - Segmentation Method Protocol

    func detectSegments(
        videoURL: URL,
        config: MethodConfig
    ) async throws -> [ActionSegment] {
        let logger = ProcessingLogger.shared

        // Phase 1: Audio Analysis
        await MainActor.run {
            logger.pipeline("Running audio analysis...")
        }

        let audioResult: AudioAnalysisResult
        do {
            audioResult = try await audioAnalyzer.analyze(
                videoURL: videoURL,
                config: config
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

        if config.motionThreshold == nil {
            // Audio-only mode
            print("⚙️ [SpectralFluxMethod] ✓ Skipping visual validation (audio-only mode)")
            await MainActor.run {
                logger.success("Using audio-only mode (visual validation skipped)")
            }

            segments = audioResult.candidateIntervals.map { interval in
                ActionSegment(
                    startTime: interval.start,
                    endTime: interval.end,
                    confidence: 0.9  // High confidence for audio-only
                )
            }
        } else {
            // Run visual validation
            await MainActor.run {
                logger.pipeline("Running visual validation...")
            }

            let validations: [SegmentValidation]
            do {
                validations = try await visualValidator.validate(
                    videoURL: videoURL,
                    candidates: audioResult.candidateIntervals,
                    config: config,
                    progressHandler: nil  // No progress reporting in method layer
                )
            } catch {
                // Fallback to audio-only if visual validation fails
                print("⚙️ [SpectralFluxMethod] ⚠️ Visual validation failed, using audio-only")
                print("⚙️ [SpectralFluxMethod] Error: \(error.localizedDescription)")
                await MainActor.run {
                    logger.warning("Visual validation unavailable, using audio-only")
                }

                segments = audioResult.candidateIntervals.map { interval in
                    ActionSegment(
                        startTime: interval.start,
                        endTime: interval.end,
                        confidence: 0.8  // Lower confidence for fallback
                    )
                }

                return segments
            }

            // Convert validations to segments
            let validIntervals = validations.filter { $0.isValid }

            if validIntervals.isEmpty {
                // No segments passed validation, use audio-only with lower confidence
                print("⚙️ [SpectralFluxMethod] ⚠️ No segments passed visual validation, using audio-only")
                await MainActor.run {
                    logger.warning("Low motion detected, using audio-only results")
                }

                segments = audioResult.candidateIntervals.map { interval in
                    ActionSegment(
                        startTime: interval.start,
                        endTime: interval.end,
                        confidence: 0.6  // Lower confidence when no motion detected
                    )
                }
            } else {
                // Use validated segments
                print("⚙️ [SpectralFluxMethod] ✓ \(validIntervals.count) segments validated with motion")
                await MainActor.run {
                    logger.success("\(validIntervals.count) segments verified with motion")
                }

                segments = validations.filter { $0.isValid }.map { validation in
                    // Normalize motion score to confidence (0.7-1.0 range)
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

        guard !segments.isEmpty else {
            print("⚙️ [SpectralFluxMethod] ❌ No action detected after processing")
            throw ProcessingError.noActionDetected
        }

        return segments
    }
}
