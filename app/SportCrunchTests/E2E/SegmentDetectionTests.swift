//
//  SegmentDetectionTests.swift
//  SportCrunchTests
//
//  Created by SportCrunch on 2026-01-11.
//

import XCTest
import AVFoundation
@testable import SportCrunch

/// End-to-end tests for segment detection
///
/// These tests validate the complete detection pipeline by processing test videos
/// through the real VideoProcessingService and comparing detected segments against
/// ground truth using fuzzy matching (IoU-based evaluation).
@MainActor
final class SegmentDetectionTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Set execution time allowance for video processing (test video is ~2 min)
        executionTimeAllowance = 180.0  // 3 minutes max
        continueAfterFailure = true  // Continue testing all cases even if one fails
    }

    // MARK: - Shot Detection Tests

    /// Tests tennis shot detection against ground truth using all available test cases.
    ///
    /// This test validates the full detection pipeline:
    /// 1. Dynamically discovers all tennis-shot test files
    /// 2. Processes each video through real VideoProcessingService
    /// 3. Evaluates detected segments using IoU-based fuzzy matching
    /// 4. Reports FPR/FNR metrics for each test case
    /// 5. Asserts against configured pass thresholds
    ///
    /// **Pass Criteria (per test case):**
    /// - At least one true positive (IoU ≥ 0.5)
    /// - FPR < 30%
    /// - FNR < 50%
    func testShotDetection_Tennis() async throws {
        // ═══════════════════════════════════════════════════════════════
        // Phase 1: Discover Test Cases
        // ═══════════════════════════════════════════════════════════════

        let testCases = try discoverTestCases(prefix: "tennis-shot")
        XCTAssertFalse(testCases.isEmpty, "No test cases found with prefix 'tennis-shot'")

        print("\n🎾 Running \(testCases.count) tennis shot detection tests...\n")

        // ═══════════════════════════════════════════════════════════════
        // Phase 2: Run Each Test Case
        // ═══════════════════════════════════════════════════════════════

        for testCase in testCases {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🧪 Testing: \(testCase)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            try await runShotDetectionTest(testCase: testCase)
        }

        print("\n✅ All \(testCases.count) test cases passed!\n")
    }

    /// Discovers all test cases with the given prefix in the GroundTruth folder
    private func discoverTestCases(prefix: String) throws -> [String] {
        let groundTruthURL = try TestResourceLoader.groundTruthDirectory()
        let fileManager = FileManager.default

        let files = try fileManager.contentsOfDirectory(
            at: groundTruthURL,
            includingPropertiesForKeys: nil
        )

        // Filter for JSON files matching the prefix and extract base names
        let testCases = files
            .filter { $0.pathExtension == "json" && $0.deletingPathExtension().lastPathComponent.hasPrefix(prefix) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()

        return testCases
    }

    /// Runs shot detection test for a specific test case
    private func runShotDetectionTest(testCase: String) async throws {
        // ═══════════════════════════════════════════════════════════════
        // Phase 1: Load Test Resources
        // ═══════════════════════════════════════════════════════════════

        let videoURL: URL
        let groundTruth: GroundTruth

        do {
            videoURL = try TestResourceLoader.loadTestVideo(named: "\(testCase).mp4")
            groundTruth = try TestResourceLoader.loadGroundTruth(named: "\(testCase).json")
        } catch {
            XCTFail("""
            [\(testCase)] Failed to load test resources: \(error.localizedDescription)

            Expected resources:
            - Video: SportCrunchTests/TestResources/Videos/\(testCase).mp4
            - Ground Truth: SportCrunchTests/TestResources/GroundTruth/\(testCase).json

            See SportCrunchTests/TEST_RESOURCES.md for troubleshooting.
            """)
            return
        }

        // ═══════════════════════════════════════════════════════════════
        // Phase 2: Process Video Through Detection Pipeline
        // ═══════════════════════════════════════════════════════════════

        let processingService = RealVideoProcessingService()
        let result: ProcessingResult

        do {
            result = try await processingService.processVideo(
                sourceURL: videoURL,
                sport: .tennis,
                sportMode: TennisMode.individual
            )
        } catch {
            XCTFail("[\(testCase)] Video processing failed: \(error.localizedDescription)")
            return
        }

        // Verify we got segments
        XCTAssertFalse(result.segments.isEmpty, "[\(testCase)] Processing should detect at least one segment")

        // ═══════════════════════════════════════════════════════════════
        // Phase 3: Convert to Evaluation Format
        // ═══════════════════════════════════════════════════════════════

        // Convert detected segments to TimeRange
        let detectedRanges = result.segments.map { segment in
            TimeRange(start: segment.startTime, end: segment.endTime)
        }

        // Convert ground truth to TimeRange
        let groundTruthRanges = groundTruth.segments.map { segment in
            TimeRange(start: segment.start, end: segment.end)
        }

        // ═══════════════════════════════════════════════════════════════
        // Phase 4: Evaluate with Fuzzy Matching
        // ═══════════════════════════════════════════════════════════════

        // Get video duration for FP rate calculation
        let asset = AVAsset(url: videoURL)
        let videoDuration = try await asset.load(.duration).seconds

        let evaluation = SegmentEvaluator.evaluate(
            detected: detectedRanges,
            groundTruth: groundTruthRanges,
            iouThreshold: 0.5
        )

        let rates = SegmentEvaluator.calculateRates(
            detected: detectedRanges,
            groundTruth: groundTruthRanges,
            videoDuration: videoDuration
        )

        // ═══════════════════════════════════════════════════════════════
        // Phase 5: Output Metrics (Always Display)
        // ═══════════════════════════════════════════════════════════════

        print("""

        📊 Shot Detection Evaluation Results [\(testCase)]:
           Ground truth segments: \(groundTruth.segments.count)
           Detected segments: \(result.segments.count)
           True positives: \(evaluation.tp)
           False positives: \(evaluation.fp) (FPR: \(String(format: "%.1f", rates.fpRate))%)
           False negatives: \(evaluation.fn) (FNR: \(String(format: "%.1f", rates.fnRate))%)

        """)

        // ═══════════════════════════════════════════════════════════════
        // Phase 6: Assert Evaluation Passes Thresholds
        // ═══════════════════════════════════════════════════════════════

        assertEvaluationPasses(
            testCase: testCase,
            evaluation,
            rates,
            fpThreshold: 30.0,
            fnThreshold: 50.0
        )
    }

    // MARK: - Helper Methods

    /// Assert that evaluation results meet specified thresholds
    ///
    /// This helper method enforces user-configured thresholds for test evaluation.
    ///
    /// - Parameters:
    ///   - testCase: Name of the test case being evaluated
    ///   - evaluation: Tuple of (tp, fp, fn) from fuzzy matching
    ///   - rates: Tuple of (fpRate, fnRate) as percentages
    ///   - fpThreshold: Maximum acceptable false positive rate (%)
    ///   - fnThreshold: Maximum acceptable false negative rate (%)
    private func assertEvaluationPasses(
        testCase: String,
        _ evaluation: (tp: Int, fp: Int, fn: Int),
        _ rates: (fpRate: Double, fnRate: Double),
        fpThreshold: Double,
        fnThreshold: Double,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(
            evaluation.tp,
            0,
            "[\(testCase)] No segments matched ground truth (IoU threshold: 0.5)",
            file: file,
            line: line
        )

        XCTAssertLessThan(
            rates.fpRate,
            fpThreshold,
            "[\(testCase)] False positive rate: \(String(format: "%.1f", rates.fpRate))% exceeds \(String(format: "%.1f", fpThreshold))% threshold",
            file: file,
            line: line
        )

        XCTAssertLessThan(
            rates.fnRate,
            fnThreshold,
            "[\(testCase)] False negative rate: \(String(format: "%.1f", rates.fnRate))% exceeds \(String(format: "%.1f", fnThreshold))% threshold",
            file: file,
            line: line
        )
    }
}
