//
//  HoughLinearityDetector.swift
//  SportCrunch
//
//  Custom linearity detector using RANSAC-inspired algorithm to detect
//  linear streaks in motion point clouds, robust to gaps.
//

import Foundation

/// A point in 2D space representing a motion pixel location.
/// Named MotionPoint to avoid collision with CGPoint or other Point types.
struct MotionPoint: Hashable, Sendable {
    let x: Double
    let y: Double
}

struct LineSegment: Sendable {
    let start: MotionPoint
    let end: MotionPoint
    let length: Double
    let points: [MotionPoint]
}

struct HoughLinearityDetector: Sendable {

    func detect(points: [MotionPoint], config: HoughMethodConfig) -> [LineSegment] {
        var remainingPoints = Set(points)
        var segments: [LineSegment] = []

        // Max iterations to avoid infinite loops
        var iterations = 0
        let maxIterations = points.count * 2

        while !remainingPoints.isEmpty && iterations < maxIterations {
            iterations += 1
            // 1. Pick a random seed point
            guard let seed = remainingPoints.randomElement() else { break }

            // 2. Find local neighborhood (potential next points)
            // Optimization: In real image processing, we might use a grid.
            // For now, naive O(N) search is okay for sparse points (< 1000).
            let neighbors = remainingPoints.filter { p in
                p != seed && distance(seed, p) <= config.maxStreakGap
            }

            if neighbors.isEmpty {
                remainingPoints.remove(seed)
                continue
            }

            // 3. Try to grow lines through each neighbor
            var bestLine: LineSegment?

            for neighbor in neighbors {
                let vector = subtract(neighbor, seed)
                let length = magnitude(vector)
                if length == 0 { continue }
                let unitVector = MotionPoint(x: vector.x / length, y: vector.y / length)

                // Grow forward and backward
                let (linePoints, start, end) = growLine(
                    center: seed,
                    direction: unitVector,
                    candidates: remainingPoints,
                    config: config
                )

                let lineLength = distance(start, end)
                if lineLength >= config.minStreakLength {
                    // Check density
                    // Relaxed density check for gaps
                    // Simple check: is this line better than current best?
                    if lineLength > (bestLine?.length ?? 0) {
                         bestLine = LineSegment(start: start, end: end, length: lineLength, points: linePoints)
                    }
                }
            }

            if let found = bestLine {
                segments.append(found)
                // Remove used points
                for p in found.points {
                    remainingPoints.remove(p)
                }
            } else {
                // If we couldn't form a line from this seed, remove it to prevent retry
                remainingPoints.remove(seed)
            }
        }

        return segments
    }

    // Helpers
    private func distance(_ a: MotionPoint, _ b: MotionPoint) -> Double {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    private func subtract(_ a: MotionPoint, _ b: MotionPoint) -> MotionPoint {
        return MotionPoint(x: a.x - b.x, y: a.y - b.y)
    }

    private func magnitude(_ v: MotionPoint) -> Double {
        return sqrt(v.x * v.x + v.y * v.y)
    }

    private func growLine(center: MotionPoint, direction: MotionPoint, candidates: Set<MotionPoint>, config: HoughMethodConfig) -> ([MotionPoint], MotionPoint, MotionPoint) {
        var inliers: [MotionPoint] = []
        var minProj: Double = 0
        var maxProj: Double = 0
        var minP = center
        var maxP = center

        // Project all candidates onto the line defined by center + direction
        // Line equation: P = center + t * direction
        // t = (P - center) dot direction
        // Distance to line = |(P - center) - t * direction|

        for p in candidates {
            let relative = subtract(p, center)
            let t = relative.x * direction.x + relative.y * direction.y
            let projected = MotionPoint(x: center.x + t * direction.x, y: center.y + t * direction.y)
            let distToLine = distance(p, projected)

            if distToLine <= config.lineTolerance {
                inliers.append(p)
                if t < minProj {
                    minProj = t
                    minP = projected
                }
                if t > maxProj {
                    maxProj = t
                    maxP = projected
                }
            }
        }

        return (inliers, minP, maxP)
    }
}
