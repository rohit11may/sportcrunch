//
//  SegmentationMethod.swift
//  SportCrunch
//
//  Protocol abstraction for swappable detection algorithms.
//  Enables algorithm experimentation without modifying the processing pipeline.
//

import Foundation

// MARK: - Segmentation Method Protocol

/// Protocol for swappable segment detection algorithms.
///
/// Implementing this protocol allows different detection methods to be used
/// interchangeably in the video processing pipeline. Each method takes a video
/// and returns detected action segments.
///
/// Example implementations:
/// - SpectralFluxMethod: Audio spectral flux + visual validation (current)
/// - AudioOnlyMethod: Spectral flux without visual validation (future)
/// - MLMethod: Machine learning-based detection (future)
protocol SegmentationMethod: Sendable {

    /// Human-readable name identifying this detection method.
    /// Used for logging and debug reports.
    var name: String { get }

    /// Detect action segments in a video.
    ///
    /// - Parameters:
    ///   - videoURL: URL to the source video file
    ///   - sport: Sport type for detection tuning
    ///   - sportMode: Optional sport-specific mode (e.g., TennisMode.rally)
    /// - Returns: Array of detected action segments
    /// - Throws: If video access fails or detection encounters an error
    func detectSegments(
        videoURL: URL,
        sport: Sport,
        sportMode: SportMode?
    ) async throws -> [ActionSegment]
}
