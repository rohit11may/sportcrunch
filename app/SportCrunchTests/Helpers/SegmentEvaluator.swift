//
//  SegmentEvaluator.swift
//  SportCrunchTests
//
//  Created by SportCrunch on 2026-01-11.
//

import Foundation

/// Utility for evaluating segment detection accuracy using fuzzy matching
///
/// This evaluator uses Intersection over Union (IoU) to compare detected segments
/// against ground truth, accounting for timing variations in the detection algorithm.
struct SegmentEvaluator {

    // MARK: - IoU Calculation

    /// Calculate Intersection over Union for two temporal ranges
    ///
    /// IoU measures the overlap between two time intervals as a ratio of their
    /// intersection to their union. A value of 1.0 indicates perfect overlap,
    /// while 0.0 indicates no overlap.
    ///
    /// - Parameters:
    ///   - detected: The detected segment's time range
    ///   - groundTruth: The ground truth segment's time range
    /// - Returns: IoU value between 0.0 and 1.0
    static func iou(detected: TimeRange, groundTruth: TimeRange) -> Double {
        // Calculate intersection
        let intersectionStart = max(detected.start, groundTruth.start)
        let intersectionEnd = min(detected.end, groundTruth.end)
        let intersection = max(0, intersectionEnd - intersectionStart)

        // Calculate union
        let unionStart = min(detected.start, groundTruth.start)
        let unionEnd = max(detected.end, groundTruth.end)
        let union = unionEnd - unionStart

        // Handle edge case: union = 0
        guard union > 0 else { return 0.0 }

        return intersection / union
    }

    // MARK: - Segment Matching

    /// Evaluate detected segments against ground truth using IoU-based matching
    ///
    /// This function performs greedy matching: each detected segment is matched to the
    /// ground truth segment with the highest IoU above the threshold. Each ground truth
    /// segment can only be matched once.
    ///
    /// - Parameters:
    ///   - detected: Array of detected segments
    ///   - groundTruth: Array of ground truth segments
    ///   - iouThreshold: Minimum IoU required for a match (default: 0.5)
    /// - Returns: Tuple of (true positives, false positives, false negatives)
    static func evaluate(
        detected: [TimeRange],
        groundTruth: [TimeRange],
        iouThreshold: Double = 0.5
    ) -> (tp: Int, fp: Int, fn: Int) {
        var matchedGroundTruthIndices = Set<Int>()
        var truePositives = 0

        // For each detected segment, find best matching ground truth
        for detectedSegment in detected {
            var bestIoU = 0.0
            var bestIndex: Int?

            for (index, gtSegment) in groundTruth.enumerated() {
                guard !matchedGroundTruthIndices.contains(index) else { continue }

                let currentIoU = iou(detected: detectedSegment, groundTruth: gtSegment)
                if currentIoU > bestIoU {
                    bestIoU = currentIoU
                    bestIndex = index
                }
            }

            // If best match exceeds threshold, count as true positive
            if let index = bestIndex, bestIoU >= iouThreshold {
                truePositives += 1
                matchedGroundTruthIndices.insert(index)
            }
        }

        let falsePositives = detected.count - truePositives
        let falseNegatives = groundTruth.count - truePositives

        return (tp: truePositives, fp: falsePositives, fn: falseNegatives)
    }

    // MARK: - Rate Calculation

    /// Calculate false positive and false negative rates as percentages
    ///
    /// - FP Rate: Extra duration kept (not in ground truth) / total video duration × 100
    /// - FN Rate: Missed duration (in ground truth but not detected) / total ground truth duration × 100
    ///
    /// - Parameters:
    ///   - detected: Array of detected segments
    ///   - groundTruth: Array of ground truth segments
    ///   - videoDuration: Total duration of the original video in seconds
    /// - Returns: Tuple of (false positive rate %, false negative rate %)
    static func calculateRates(
        detected: [TimeRange],
        groundTruth: [TimeRange],
        videoDuration: Double
    ) -> (fpRate: Double, fnRate: Double) {
        // Calculate total ground truth duration
        let totalGroundTruthDuration = groundTruth.reduce(0.0) { $0 + $1.duration }

        // Handle edge cases
        guard videoDuration > 0 else { return (0.0, 0.0) }
        guard totalGroundTruthDuration > 0 else { return (0.0, 0.0) }

        // Calculate total detected duration
        let totalDetectedDuration = detected.reduce(0.0) { $0 + $1.duration }

        // Calculate overlapping duration using IoU-based matching
        var totalOverlap = 0.0
        var matchedGroundTruthIndices = Set<Int>()

        for detectedSegment in detected {
            for (index, gtSegment) in groundTruth.enumerated() {
                guard !matchedGroundTruthIndices.contains(index) else { continue }

                // Calculate intersection
                let intersectionStart = max(detectedSegment.start, gtSegment.start)
                let intersectionEnd = min(detectedSegment.end, gtSegment.end)
                let intersection = max(0, intersectionEnd - intersectionStart)

                if intersection > 0 {
                    totalOverlap += intersection
                    matchedGroundTruthIndices.insert(index)
                    break // Greedy matching: move to next detected segment
                }
            }
        }

        // False positive: extra duration kept (detected but not in ground truth)
        let extraDuration = max(0, totalDetectedDuration - totalOverlap)
        let fpRate = (extraDuration / videoDuration) * 100

        // False negative: missed duration (in ground truth but not detected)
        let missedDuration = max(0, totalGroundTruthDuration - totalOverlap)
        let fnRate = (missedDuration / totalGroundTruthDuration) * 100

        return (fpRate: fpRate, fnRate: fnRate)
    }
}

// MARK: - TimeRange Helper

/// Represents a temporal range with start and end times
struct TimeRange {
    let start: Double
    let end: Double

    var duration: Double {
        end - start
    }

    init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }
}
