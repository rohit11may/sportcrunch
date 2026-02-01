//
//  HoughLinearityDetectorGPU.swift
//  SportCrunch
//
//  GPU-accelerated linearity detection using Metal Hough transform.
//  Replaces the CPU-bound RANSAC-like algorithm.
//

import Foundation
import simd

/// GPU-accelerated linearity detector using Hough transform.
/// Converts GPU Hough lines (rho, theta) to LineSegment format for compatibility.
final class HoughLinearityDetectorGPU: @unchecked Sendable {

    private let gpu: HoughGPU

    init() throws {
        self.gpu = try HoughGPU()
    }

    /// Detect linear streaks in motion points using GPU Hough transform.
    /// - Parameters:
    ///   - points: Motion points from frame differencing
    ///   - config: Detection configuration
    ///   - imageWidth: Width of source image
    ///   - imageHeight: Height of source image
    /// - Returns: Array of detected line segments
    func detect(
        points: [MotionPoint],
        config: HoughMethodConfig,
        imageWidth: Int,
        imageHeight: Int
    ) throws -> [LineSegment] {
        // Calculate vote threshold based on minimum streak length
        // A line of minStreakLength pixels should have roughly that many votes
        let voteThreshold = max(Int(config.minStreakLength / 2), 10)

        let gpuLines = try gpu.detectLines(
            points: points,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            voteThreshold: voteThreshold
        )

        // Convert Hough lines to LineSegments
        return gpuLines.compactMap { gpuLine in
            convertToLineSegment(
                gpuLine: gpuLine,
                points: points,
                config: config
            )
        }
    }

    // MARK: - Private Helpers

    /// Convert a Hough line (rho, theta) to a LineSegment by finding inlier points.
    private func convertToLineSegment(
        gpuLine: DetectedLineGPU,
        points: [MotionPoint],
        config: HoughMethodConfig
    ) -> LineSegment? {
        let rho = Double(gpuLine.rho)
        let theta = Double(gpuLine.theta)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)

        let tolerance = config.lineTolerance

        // Find all points that lie on this line within tolerance
        var inliers: [MotionPoint] = []
        var minProj: Double = .infinity
        var maxProj: Double = -.infinity

        for point in points {
            // Distance from point to line: |x*cos(theta) + y*sin(theta) - rho|
            let dist = abs(point.x * cosTheta + point.y * sinTheta - rho)

            if dist <= tolerance {
                inliers.append(point)

                // Project onto line direction (perpendicular to normal)
                // Line direction is (-sin(theta), cos(theta))
                let proj = -point.x * sinTheta + point.y * cosTheta
                minProj = min(minProj, proj)
                maxProj = max(maxProj, proj)
            }
        }

        // Check minimum length
        let length = maxProj - minProj
        guard length >= config.minStreakLength else { return nil }

        // Calculate start and end points on the line
        // Point on line closest to origin: (rho * cos(theta), rho * sin(theta))
        // Then move along line direction by minProj and maxProj
        let lineDir = simd_double2(-sinTheta, cosTheta)
        let basePoint = simd_double2(rho * cosTheta, rho * sinTheta)

        let startSimd = basePoint + minProj * lineDir
        let endSimd = basePoint + maxProj * lineDir

        let start = MotionPoint(x: startSimd.x, y: startSimd.y)
        let end = MotionPoint(x: endSimd.x, y: endSimd.y)

        return LineSegment(
            start: start,
            end: end,
            length: length,
            points: inliers
        )
    }
}
