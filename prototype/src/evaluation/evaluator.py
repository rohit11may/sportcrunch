"""
Segment evaluation using IoU-based fuzzy matching.

This module ports the Swift SegmentEvaluator logic to Python, providing identical
evaluation metrics for comparing detected segments against ground truth.
"""

from dataclasses import dataclass
from typing import List, Tuple


@dataclass
class TimeRange:
    """Represents a temporal range with start and end times."""

    start: float
    end: float

    @property
    def duration(self) -> float:
        """Duration of the time range in seconds."""
        return self.end - self.start


@dataclass
class EvaluationMetrics:
    """Evaluation metrics for segment detection."""

    tp: int  # True positives
    fp: int  # False positives
    fn: int  # False negatives

    @property
    def precision(self) -> float:
        """Precision: TP / (TP + FP)."""
        if self.tp + self.fp == 0:
            return 0.0
        return self.tp / (self.tp + self.fp)

    @property
    def recall(self) -> float:
        """Recall: TP / (TP + FN)."""
        if self.tp + self.fn == 0:
            return 0.0
        return self.tp / (self.tp + self.fn)

    @property
    def f1(self) -> float:
        """F1 score: 2 * (precision * recall) / (precision + recall)."""
        if self.precision + self.recall == 0:
            return 0.0
        return 2 * (self.precision * self.recall) / (self.precision + self.recall)

    @property
    def fp_rate(self) -> float:
        """False positive rate (placeholder - use calculate_rates for actual FP rate)."""
        return 0.0

    @property
    def fn_rate(self) -> float:
        """False negative rate (placeholder - use calculate_rates for actual FN rate)."""
        return 0.0


class SegmentEvaluator:
    """
    Utility for evaluating segment detection accuracy using fuzzy matching.

    This evaluator uses Intersection over Union (IoU) to compare detected segments
    against ground truth, accounting for timing variations in the detection algorithm.
    """

    @staticmethod
    def iou(detected: TimeRange, ground_truth: TimeRange) -> float:
        """
        Calculate Intersection over Union for two temporal ranges.

        IoU measures the overlap between two time intervals as a ratio of their
        intersection to their union. A value of 1.0 indicates perfect overlap,
        while 0.0 indicates no overlap.

        Args:
            detected: The detected segment's time range
            ground_truth: The ground truth segment's time range

        Returns:
            IoU value between 0.0 and 1.0
        """
        # Calculate intersection
        intersection_start = max(detected.start, ground_truth.start)
        intersection_end = min(detected.end, ground_truth.end)
        intersection = max(0, intersection_end - intersection_start)

        # Calculate union
        union_start = min(detected.start, ground_truth.start)
        union_end = max(detected.end, ground_truth.end)
        union = union_end - union_start

        # Handle edge case: union = 0
        if union <= 0:
            return 0.0

        return intersection / union

    @staticmethod
    def evaluate(
        detected: List[TimeRange],
        ground_truth: List[TimeRange],
        iou_threshold: float = 0.5
    ) -> EvaluationMetrics:
        """
        Evaluate detected segments against ground truth using IoU-based matching.

        This function performs greedy matching: each detected segment is matched to the
        ground truth segment with the highest IoU above the threshold. Each ground truth
        segment can only be matched once.

        Args:
            detected: Array of detected segments
            ground_truth: Array of ground truth segments
            iou_threshold: Minimum IoU required for a match (default: 0.5)

        Returns:
            EvaluationMetrics with tp, fp, fn counts
        """
        matched_ground_truth_indices = set()
        true_positives = 0

        # For each detected segment, find best matching ground truth
        for detected_segment in detected:
            best_iou = 0.0
            best_index = None

            for index, gt_segment in enumerate(ground_truth):
                if index in matched_ground_truth_indices:
                    continue

                current_iou = SegmentEvaluator.iou(detected_segment, gt_segment)
                if current_iou > best_iou:
                    best_iou = current_iou
                    best_index = index

            # If best match exceeds threshold, count as true positive
            if best_index is not None and best_iou >= iou_threshold:
                true_positives += 1
                matched_ground_truth_indices.add(best_index)

        false_positives = len(detected) - true_positives
        false_negatives = len(ground_truth) - true_positives

        return EvaluationMetrics(tp=true_positives, fp=false_positives, fn=false_negatives)

    @staticmethod
    def calculate_rates(
        detected: List[TimeRange],
        ground_truth: List[TimeRange],
        video_duration: float
    ) -> Tuple[float, float]:
        """
        Calculate false positive and false negative rates as percentages.

        - FP Rate: Extra duration kept (not in ground truth) / total video duration × 100
        - FN Rate: Missed duration (in ground truth but not detected) / total ground truth duration × 100

        Args:
            detected: Array of detected segments
            ground_truth: Array of ground truth segments
            video_duration: Total duration of the original video in seconds

        Returns:
            Tuple of (false positive rate %, false negative rate %)
        """
        # Calculate total ground truth duration
        total_ground_truth_duration = sum(gt.duration for gt in ground_truth)

        # Handle edge cases
        if video_duration <= 0:
            return (0.0, 0.0)
        if total_ground_truth_duration <= 0:
            return (0.0, 0.0)

        # Calculate total detected duration
        total_detected_duration = sum(d.duration for d in detected)

        # Calculate overlapping duration using greedy matching
        total_overlap = 0.0
        matched_ground_truth_indices = set()

        for detected_segment in detected:
            for index, gt_segment in enumerate(ground_truth):
                if index in matched_ground_truth_indices:
                    continue

                # Calculate intersection
                intersection_start = max(detected_segment.start, gt_segment.start)
                intersection_end = min(detected_segment.end, gt_segment.end)
                intersection = max(0, intersection_end - intersection_start)

                if intersection > 0:
                    total_overlap += intersection
                    matched_ground_truth_indices.add(index)
                    break  # Greedy matching: move to next detected segment

        # False positive: extra duration kept (detected but not in ground truth)
        extra_duration = max(0, total_detected_duration - total_overlap)
        fp_rate = (extra_duration / video_duration) * 100

        # False negative: missed duration (in ground truth but not detected)
        missed_duration = max(0, total_ground_truth_duration - total_overlap)
        fn_rate = (missed_duration / total_ground_truth_duration) * 100

        return (fp_rate, fn_rate)
