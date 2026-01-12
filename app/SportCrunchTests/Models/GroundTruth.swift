//
//  GroundTruth.swift
//  SportCrunchTests
//
//  Created by SportCrunch on 2026-01-11.
//

import Foundation

/// Represents a single ground truth segment with start and end times
struct GroundTruthSegment: Codable {
    let start: Double
    let end: Double
}

/// Represents ground truth data for a test video
///
/// Ground truth files are JSON documents that specify the expected segments
/// that should be detected in a test video. They enable automated evaluation
/// of segment detection accuracy.
struct GroundTruth: Codable {
    /// Filename of the associated video file (e.g., "rally-tennis-01.mp4")
    let videoFilename: String

    /// Sport type (e.g., "tennis", "cricket")
    let sport: String

    /// Detection mode (e.g., "rally", "shot")
    let mode: String

    /// Array of expected segments with start/end times in seconds
    let segments: [GroundTruthSegment]
}
