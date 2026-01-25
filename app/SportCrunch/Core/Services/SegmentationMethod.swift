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
/// interchangeably in the video processing pipeline. Methods are "hydrated"
/// with their configuration at initialization and are ready to use.
///
/// The app layer (Sport.swift) provides factory methods that return configured
/// methods based on sport and mode selection.
///
/// Example implementations:
/// - SpectralFluxMethod: Audio + visual validation detection
/// - MLMethod: Machine learning-based detection (future)
protocol SegmentationMethod: Sendable {

    /// Human-readable name identifying this detection method.
    var name: String { get }

    /// Detect action segments in a video.
    ///
    /// - Parameter videoURL: URL to the source video file
    /// - Returns: Array of detected action segments
    /// - Throws: If video access fails or detection encounters an error
    func detectSegments(videoURL: URL) async throws -> [ActionSegment]
}
