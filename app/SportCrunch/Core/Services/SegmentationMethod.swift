//
//  SegmentationMethod.swift
//  SportCrunch
//
//  Protocol abstraction for swappable detection algorithms.
//  Enables algorithm experimentation without modifying the processing pipeline.
//

import Foundation

// MARK: - Method Configuration

/// Configuration parameters for method execution.
/// Maps to JSON config files in methods/{family}/{version}/configs/
///
/// This struct decouples methods from sport-specific logic. Methods only know about
/// config values - the app layer maps Sport/SportMode selections to configs.
struct MethodConfig: Sendable {
    // Audio parameters
    let audioThresholdMultiplier: Double
    let peakMinDistance: Double

    // Clustering parameters
    let clusterMaxGapSec: Double

    // Padding parameters
    let paddingPreSec: Double
    let paddingPostSec: Double

    // Visual validation parameters (optional, only for methods with visual validation)
    let motionThreshold: Double?

    /// Create config from JSON config parameters
    init(
        audioThresholdMultiplier: Double = 1.5,
        peakMinDistance: Double = 0.5,
        clusterMaxGapSec: Double = 2.0,
        paddingPreSec: Double = 1.5,
        paddingPostSec: Double = 1.0,
        motionThreshold: Double? = nil
    ) {
        self.audioThresholdMultiplier = audioThresholdMultiplier
        self.peakMinDistance = peakMinDistance
        self.clusterMaxGapSec = clusterMaxGapSec
        self.paddingPreSec = paddingPreSec
        self.paddingPostSec = paddingPostSec
        self.motionThreshold = motionThreshold
    }
}

// MARK: - Segmentation Method Protocol

/// Protocol for swappable segment detection algorithms.
///
/// Implementing this protocol allows different detection methods to be used
/// interchangeably in the video processing pipeline. Each method accepts a
/// config object and returns detected action segments.
///
/// Methods are config-driven and decoupled from app-specific sport selection logic.
/// The app layer (VideoProcessingService, RunExecutor) maps Sport/SportMode to
/// appropriate MethodConfig instances before calling methods.
///
/// Example implementations:
/// - SpectralFluxMethod (v1): Audio-only spectral flux detection
/// - SpectralFluxVisualValidationMethod (v2): Audio + visual validation
/// - MLMethod: Machine learning-based detection (future)
protocol SegmentationMethod: Sendable {

    /// Human-readable name identifying this detection method.
    /// Used for logging and debug reports.
    var name: String { get }

    /// Detect action segments in a video using the provided configuration.
    ///
    /// - Parameters:
    ///   - videoURL: URL to the source video file
    ///   - config: Method configuration parameters (matches JSON config structure)
    /// - Returns: Array of detected action segments
    /// - Throws: If video access fails or detection encounters an error
    func detectSegments(
        videoURL: URL,
        config: MethodConfig
    ) async throws -> [ActionSegment]
}
