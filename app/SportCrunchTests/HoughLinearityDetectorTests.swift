//
//  HoughLinearityDetectorTests.swift
//  SportCrunchTests
//
//  Tests for the Hough linearity detector using TDD approach.
//

import XCTest
@testable import SportCrunch

final class HoughLinearityDetectorTests: XCTestCase {
    func testHorizontalLineDetection() {
        let detector = HoughLinearityDetector()
        let config = HoughMethodConfig(
            diffThreshold: 0, minMotionArea: 0, maxMotionPoints: 15000, // irrelevant for this test
            minStreakLength: 10,
            maxStreakGap: 5,
            lineTolerance: 2,
            minDensity: 0.5,
            rallyMaxGap: 0, rallyMinDuration: 0
        )

        // Create points for a horizontal line: (0, 10) -> (20, 10)
        var points: [MotionPoint] = []
        for x in stride(from: 0, through: 20, by: 2) {
            points.append(MotionPoint(x: Double(x), y: 10))
        }

        let lines = detector.detect(points: points, config: config)

        XCTAssertEqual(lines.count, 1)
        let line = lines.first!
        XCTAssertEqual(line.start.y, 10, accuracy: 0.1)
        XCTAssertEqual(line.end.y, 10, accuracy: 0.1)
        XCTAssertGreaterThan(line.length, 18)
    }

    func testLinearityDetectorPerformance() {
        let detector = HoughLinearityDetector()
        let config = HoughMethodConfig(
            diffThreshold: 0, minMotionArea: 0, maxMotionPoints: 15000,
            minStreakLength: 50,
            maxStreakGap: 20,
            lineTolerance: 5,
            minDensity: 0.3,
            rallyMaxGap: 0, rallyMinDuration: 0
        )

        // Generate 5000 random points simulating a large motion cloud
        let points = (0..<5000).map { _ in
            MotionPoint(
                x: Double.random(in: 0...1920),
                y: Double.random(in: 0...1080)
            )
        }

        measure {
            _ = detector.detect(points: points, config: config)
        }
    }

    // MARK: - GPU Comparison Tests

    func testGPUvsCPUProducesSimilarResults() throws {
        // Create a synthetic point cloud with a clear line
        var points: [MotionPoint] = []

        // Add a diagonal line
        for i in 0..<100 {
            let x = Double(i) * 2
            let y = Double(i) + 50
            points.append(MotionPoint(x: x, y: y))
            // Add some noise around the line
            points.append(MotionPoint(x: x + Double.random(in: -2...2), y: y + Double.random(in: -2...2)))
        }

        let config = HoughMethodConfig(
            diffThreshold: 25,
            minMotionArea: 50,
            maxMotionPoints: 15000,
            minStreakLength: 50.0,
            maxStreakGap: 10.0,
            lineTolerance: 5.0,
            minDensity: 0.5,
            rallyMaxGap: 4.0,
            rallyMinDuration: 2.0
        )

        // CPU detection
        let cpuDetector = HoughLinearityDetector()
        let cpuLines = cpuDetector.detect(points: points, config: config)

        // GPU detection
        guard let gpuDetector = try? HoughLinearityDetectorGPU() else {
            throw XCTSkip("Metal not available")
        }
        let gpuLines = try gpuDetector.detect(
            points: points,
            config: config,
            imageWidth: 300,
            imageHeight: 200
        )

        // Both should detect at least one line
        XCTAssertFalse(cpuLines.isEmpty, "CPU should detect lines")
        XCTAssertFalse(gpuLines.isEmpty, "GPU should detect lines")

        // The longest line from each should be similar in length
        if let cpuBest = cpuLines.max(by: { $0.length < $1.length }),
           let gpuBest = gpuLines.max(by: { $0.length < $1.length }) {
            XCTAssertEqual(cpuBest.length, gpuBest.length, accuracy: 20, "Line lengths should be similar")
        }
    }
}
