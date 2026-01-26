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
            diffThreshold: 0, minMotionArea: 0, // irrelevant for this test
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
}
