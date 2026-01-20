"""
Evaluation infrastructure for tennis segment detection.

This module provides tools for evaluating detected segments against ground truth
using Intersection over Union (IoU) based matching.
"""

from .evaluator import SegmentEvaluator, TimeRange, EvaluationMetrics

__all__ = ["SegmentEvaluator", "TimeRange", "EvaluationMetrics"]
