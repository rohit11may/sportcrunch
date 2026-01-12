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
        continueAfterFailure = false
    }

    // MARK: - Shot Detection Tests

    /// Tests tennis shot detection against ground truth with 22 shot segments.
    ///
    /// This test validates the full detection pipeline:
    /// 1. Loads test resources (video and ground truth)
    /// 2. Processes video through real VideoProcessingService
    /// 3. Evaluates detected segments using IoU-based fuzzy matching
    /// 4. Reports FPR/FNR metrics for visibility
    /// 5. Asserts against configured pass thresholds
    ///
    /// **Pass Criteria:**
    /// - At least one true positive (IoU ≥ 0.5)
    /// - FPR < 90% (permissive threshold for early development)
    /// - FNR < 50% (permissive threshold for early development)
    ///
    /// **Test Resources:**
    /// - Video: test_shot_1.mp4 (~2 min tennis footage)
    /// - Ground Truth: test_shot_1.json (22 segments)
    ///
    /// **Current Baseline Performance:**
    /// - Detected: 38 segments, TP: 17, FP: 21 (FPR: 74.6%), FN: 5 (FNR: 41.4%)
    func testShotDetection_Tennis() async throws {
        // ═══════════════════════════════════════════════════════════════
        // Phase 1: Load Test Resources
        // ═══════════════════════════════════════════════════════════════

        let videoURL: URL
        let groundTruth: GroundTruth

        do {
            videoURL = try TestResourceLoader.loadTestVideo(named: "test_shot_1.mp4")
            groundTruth = try TestResourceLoader.loadGroundTruth(named: "test_shot_1.json")
        } catch {
            XCTFail("""
            Failed to load test resources: \(error.localizedDescription)

            Expected resources:
            - Video: SportCrunchTests/TestResources/Videos/test_shot_1.mp4
            - Ground Truth: SportCrunchTests/TestResources/GroundTruth/test_shot_1.json

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
            XCTFail("Video processing failed: \(error.localizedDescription)")
            return
        }

        // Verify we got segments
        XCTAssertFalse(result.segments.isEmpty, "Processing should detect at least one segment")

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

        let evaluation = SegmentEvaluator.evaluate(
            detected: detectedRanges,
            groundTruth: groundTruthRanges,
            iouThreshold: 0.5
        )

        let rates = SegmentEvaluator.calculateRates(
            detected: detectedRanges,
            groundTruth: groundTruthRanges
        )

        // ═══════════════════════════════════════════════════════════════
        // Phase 5: Output Metrics (Always Display)
        // ═══════════════════════════════════════════════════════════════

        print("""

        📊 Shot Detection Evaluation Results:
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
            evaluation,
            rates,
            fpThreshold: 90.0,
            fnThreshold: 50.0
        )
    }

    // MARK: - Helper Methods

    /// Assert that evaluation results meet specified thresholds
    ///
    /// This helper method will be used after Task 3 to enforce user-configured thresholds.
    ///
    /// - Parameters:
    ///   - evaluation: Tuple of (tp, fp, fn) from fuzzy matching
    ///   - rates: Tuple of (fpRate, fnRate) as percentages
    ///   - fpThreshold: Maximum acceptable false positive rate (%)
    ///   - fnThreshold: Maximum acceptable false negative rate (%)
    private func assertEvaluationPasses(
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
            "No segments matched ground truth (IoU threshold: 0.5)",
            file: file,
            line: line
        )

        XCTAssertLessThan(
            rates.fpRate,
            fpThreshold,
            "False positive rate: \(String(format: "%.1f", rates.fpRate))% exceeds \(String(format: "%.1f", fpThreshold))% threshold",
            file: file,
            line: line
        )

        XCTAssertLessThan(
            rates.fnRate,
            fnThreshold,
            "False negative rate: \(String(format: "%.1f", rates.fnRate))% exceeds \(String(format: "%.1f", fnThreshold))% threshold",
            file: file,
            line: line
        )
    }
}
