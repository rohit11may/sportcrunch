//
//  HoughGPUTests.swift
//  SportCrunchTests
//
//  Tests for GPU-accelerated Hough line detection.
//

import XCTest
@testable import SportCrunch

final class HoughGPUTests: XCTestCase {

    var gpu: HoughGPU!

    override func setUpWithError() throws {
        gpu = try HoughGPU()
    }

    override func tearDown() {
        gpu = nil
    }

    // MARK: - Basic Functionality

    func testEmptyPointsReturnsNoLines() throws {
        let lines = try gpu.detectLines(
            points: [],
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 10
        )
        XCTAssertTrue(lines.isEmpty)
    }

    func testHorizontalLineDetection() throws {
        // Create points along y = 50 (horizontal line)
        var points: [MotionPoint] = []
        for x in stride(from: 10, to: 90, by: 1) {
            points.append(MotionPoint(x: Double(x), y: 50))
        }

        let lines = try gpu.detectLines(
            points: points,
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 20
        )

        XCTAssertFalse(lines.isEmpty, "Should detect horizontal line")

        // Horizontal line: theta should be ~90 degrees (pi/2)
        // rho should be ~50 (distance from origin to line)
        if let bestLine = lines.first {
            let thetaDegrees = bestLine.theta * 180 / Float.pi
            XCTAssertEqual(thetaDegrees, 90, accuracy: 5, "Theta should be ~90 degrees for horizontal line")
            XCTAssertEqual(bestLine.rho, 50, accuracy: 5, "Rho should be ~50 for y=50 line")
        }
    }

    func testVerticalLineDetection() throws {
        // Create points along x = 30 (vertical line)
        var points: [MotionPoint] = []
        for y in stride(from: 10, to: 90, by: 1) {
            points.append(MotionPoint(x: 30, y: Double(y)))
        }

        let lines = try gpu.detectLines(
            points: points,
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 20
        )

        XCTAssertFalse(lines.isEmpty, "Should detect vertical line")

        // Vertical line: theta should be ~0 degrees
        // rho should be ~30 (distance from origin to line)
        if let bestLine = lines.first {
            let thetaDegrees = bestLine.theta * 180 / Float.pi
            XCTAssertTrue(thetaDegrees < 10 || thetaDegrees > 170, "Theta should be ~0 or ~180 for vertical line")
            XCTAssertEqual(abs(bestLine.rho), 30, accuracy: 5, "Rho should be ~30 for x=30 line")
        }
    }

    func testDiagonalLineDetection() throws {
        // Create points along y = x (45 degree diagonal)
        var points: [MotionPoint] = []
        for i in stride(from: 10, to: 90, by: 1) {
            points.append(MotionPoint(x: Double(i), y: Double(i)))
        }

        let lines = try gpu.detectLines(
            points: points,
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 20
        )

        XCTAssertFalse(lines.isEmpty, "Should detect diagonal line")

        // 45 degree line through origin: theta should be ~135 degrees, rho ~0
        if let bestLine = lines.first {
            let thetaDegrees = bestLine.theta * 180 / Float.pi
            XCTAssertEqual(thetaDegrees, 135, accuracy: 10, "Theta should be ~135 degrees for y=x line")
        }
    }

    // MARK: - Performance

    func testPerformanceWith10kPoints() throws {
        // Simulate realistic motion point count
        var points: [MotionPoint] = []

        // Add some random noise
        for _ in 0..<9000 {
            points.append(MotionPoint(
                x: Double.random(in: 0..<1920),
                y: Double.random(in: 0..<1080)
            ))
        }

        // Add a clear line
        for x in stride(from: 100, to: 1800, by: 2) {
            points.append(MotionPoint(x: Double(x), y: Double(x) * 0.5 + 100))
        }

        measure {
            _ = try? gpu.detectLines(
                points: points,
                imageWidth: 1920,
                imageHeight: 1080,
                voteThreshold: 50
            )
        }
    }

    func testPerformanceWith50kPoints() throws {
        var points: [MotionPoint] = []

        for _ in 0..<50000 {
            points.append(MotionPoint(
                x: Double.random(in: 0..<1920),
                y: Double.random(in: 0..<1080)
            ))
        }

        measure {
            _ = try? gpu.detectLines(
                points: points,
                imageWidth: 1920,
                imageHeight: 1080,
                voteThreshold: 100
            )
        }
    }
}
