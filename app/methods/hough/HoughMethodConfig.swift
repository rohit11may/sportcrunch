//
//  HoughMethodConfig.swift
//  SportCrunch
//
//  Configuration parameters for the Hough-based tennis ball tracking method.
//

import Foundation

struct HoughMethodConfig: Sendable {
    // MARK: - Motion Processing
    /// Threshold for pixel intensity difference (0-255)
    let diffThreshold: UInt8
    /// Minimum motion area to consider (noise filter)
    let minMotionArea: Int
    /// Maximum motion points to process per frame.
    /// Frames with more points are likely camera shake/scene changes, not ball motion.
    /// Default 15000 balances accuracy with performance.
    let maxMotionPoints: Int

    // MARK: - Linearity Detection
    /// Minimum length of a streak (pixels)
    let minStreakLength: Double
    /// Maximum gap between points in a streak (pixels)
    let maxStreakGap: Double
    /// Tolerance for line fitting (pixels distance from vector)
    let lineTolerance: Double
    /// Minimum density of points along the line (0.0-1.0)
    let minDensity: Double

    // MARK: - Temporal
    /// Max gap between frames to link a rally
    let rallyMaxGap: TimeInterval
    /// Min duration of a rally
    let rallyMinDuration: TimeInterval
}
