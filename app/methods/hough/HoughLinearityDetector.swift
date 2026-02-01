//
//  HoughLinearityDetector.swift
//  SportCrunch
//
//  Custom linearity detector using RANSAC-inspired algorithm to detect
//  linear streaks in motion point clouds, robust to gaps.
//

import Foundation
import simd

/// A point in 2D space representing a motion pixel location.
/// Named MotionPoint to avoid collision with CGPoint or other Point types.
struct MotionPoint: Hashable, Sendable {
    let x: Double
    let y: Double

    @inline(__always)
    var simd: simd_double2 { simd_double2(x, y) }
}

struct LineSegment: Sendable {
    let start: MotionPoint
    let end: MotionPoint
    let length: Double
    let points: [MotionPoint]
}

/// Result of line detection including quality metrics.
struct LineDetectionResult: Sendable {
    let lines: [LineSegment]
    /// Ratio of points that fall on detected lines vs total points (0.0-1.0).
    let linearityScore: Double
}

/// Spatial hash grid for O(1) average-case neighbor lookups.
/// Cell size is set to maxStreakGap so neighbors are always in adjacent cells.
private struct SpatialHashGrid {
    private var cells: [Int: Set<MotionPoint>]
    private let cellSize: Double
    private var allPoints: Set<MotionPoint>

    init(points: [MotionPoint], cellSize: Double) {
        self.cellSize = cellSize
        self.cells = [:]
        self.allPoints = Set(points)

        for p in points {
            let key = cellKey(for: p)
            cells[key, default: []].insert(p)
        }
    }

    @inline(__always)
    private func cellKey(for p: MotionPoint) -> Int {
        let cx = Int(floor(p.x / cellSize))
        let cy = Int(floor(p.y / cellSize))
        // Use a large multiplier to avoid collisions for typical image sizes
        return cy * 100_000 + cx
    }

    /// Returns neighbors within maxDistanceSquared (excluding the point itself).
    /// Only checks the 3x3 cell neighborhood for O(1) average case.
    func neighbors(of point: MotionPoint, maxDistanceSquared: Double) -> [MotionPoint] {
        let cx = Int(floor(point.x / cellSize))
        let cy = Int(floor(point.y / cellSize))

        var result: [MotionPoint] = []

        // Check 3x3 neighborhood
        for dy in -1...1 {
            for dx in -1...1 {
                let key = (cy + dy) * 100_000 + (cx + dx)
                guard let cellPoints = cells[key] else { continue }
                for p in cellPoints {
                    if p != point {
                        let distSq = distanceSquared(point, p)
                        if distSq <= maxDistanceSquared {
                            result.append(p)
                        }
                    }
                }
            }
        }

        return result
    }

    /// Remove a point from the grid
    mutating func remove(_ point: MotionPoint) {
        allPoints.remove(point)
        let key = cellKey(for: point)
        cells[key]?.remove(point)
    }

    /// Check if the grid contains a point
    func contains(_ point: MotionPoint) -> Bool {
        return allPoints.contains(point)
    }

    /// Get a random point from the grid, or nil if empty
    func randomElement() -> MotionPoint? {
        return allPoints.randomElement()
    }

    /// Check if the grid is empty
    var isEmpty: Bool {
        return allPoints.isEmpty
    }

    /// Get all remaining points as a set
    var remainingPoints: Set<MotionPoint> {
        return allPoints
    }

    @inline(__always)
    private func distanceSquared(_ a: MotionPoint, _ b: MotionPoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}

struct HoughLinearityDetector: Sendable {

    func detect(points: [MotionPoint], config: HoughMethodConfig) -> LineDetectionResult {
        guard !points.isEmpty else {
            return LineDetectionResult(lines: [], linearityScore: 0)
        }

        // Build spatial hash grid for O(1) neighbor lookups
        var grid = SpatialHashGrid(points: points, cellSize: config.maxStreakGap)
        var segments: [LineSegment] = []
        var totalPointsOnLines = 0

        // Pre-compute squared thresholds to avoid sqrt in hot paths
        let maxStreakGapSquared = config.maxStreakGap * config.maxStreakGap
        let lineToleranceSquared = config.lineTolerance * config.lineTolerance

        // Max iterations to avoid infinite loops
        var iterations = 0
        let maxIterations = points.count * 2

        while !grid.isEmpty && iterations < maxIterations {
            iterations += 1
            // 1. Pick a random seed point
            guard let seed = grid.randomElement() else { break }

            // 2. Find local neighborhood using spatial hash (O(1) average case)
            let neighbors = grid.neighbors(of: seed, maxDistanceSquared: maxStreakGapSquared)

            if neighbors.isEmpty {
                grid.remove(seed)
                continue
            }

            // 3. Try to grow lines through each neighbor
            var bestLine: LineSegment?

            for neighbor in neighbors {
                let vectorSimd = neighbor.simd - seed.simd
                let lengthSquared = simd_length_squared(vectorSimd)
                if lengthSquared == 0 { continue }
                let direction = simd_normalize(vectorSimd)

                // Grow forward and backward
                let (linePoints, start, end) = growLine(
                    center: seed,
                    direction: direction,
                    candidates: grid.remainingPoints,
                    lineToleranceSquared: lineToleranceSquared
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
                totalPointsOnLines += found.points.count
                // Remove used points from spatial grid
                for p in found.points {
                    grid.remove(p)
                }
            } else {
                // If we couldn't form a line from this seed, remove it to prevent retry
                grid.remove(seed)
            }
        }

        let linearityScore = points.isEmpty ? 0 : Double(totalPointsOnLines) / Double(points.count)
        return LineDetectionResult(lines: segments, linearityScore: linearityScore)
    }

    // Helpers
    @inline(__always)
    private func distanceSquared(_ a: MotionPoint, _ b: MotionPoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private func distance(_ a: MotionPoint, _ b: MotionPoint) -> Double {
        return sqrt(distanceSquared(a, b))
    }

    private func growLine(center: MotionPoint, direction: simd_double2, candidates: Set<MotionPoint>, lineToleranceSquared: Double) -> ([MotionPoint], MotionPoint, MotionPoint) {
        var inliers: [MotionPoint] = []
        var minProj: Double = 0
        var maxProj: Double = 0
        var minP = center
        var maxP = center

        // Project all candidates onto the line defined by center + direction
        // Line equation: P = center + t * direction
        // t = (P - center) dot direction
        // Distance to line = |(P - center) - t * direction|

        let centerSimd = center.simd

        for p in candidates {
            let pSimd = p.simd
            let relative = pSimd - centerSimd
            let t = simd_dot(relative, direction)
            let projected = centerSimd + t * direction
            let distToLineSquared = simd_length_squared(pSimd - projected)

            if distToLineSquared <= lineToleranceSquared {
                inliers.append(p)
                if t < minProj {
                    minProj = t
                    minP = MotionPoint(x: projected.x, y: projected.y)
                }
                if t > maxProj {
                    maxProj = t
                    maxP = MotionPoint(x: projected.x, y: projected.y)
                }
            }
        }

        return (inliers, minP, maxP)
    }
}
