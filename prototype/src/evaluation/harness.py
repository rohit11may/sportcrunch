"""
Test harness for automated method evaluation.

This module provides infrastructure for running all registered segmentation methods
on the full test corpus and collecting comprehensive evaluation metrics.
"""

import time
import traceback
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional, Dict, Tuple

# Import methods package to trigger registration
import src.methods  # noqa: F401

from src.framework.registry import get_registered_methods
from src.framework.result import MethodResult
from src.evaluation.evaluator import SegmentEvaluator, EvaluationMetrics, TimeRange
from src.evaluation.ground_truth import GroundTruthLoader, GroundTruth
from src.utils.video import VideoLoader


@dataclass
class MethodVideoResult:
    """Result of running one method on one video."""

    method_name: str
    video_filename: str
    ground_truth: GroundTruth
    method_result: Optional[MethodResult]
    metrics: Optional[EvaluationMetrics]
    processing_time: float  # seconds
    error: Optional[str] = None  # if method crashed


@dataclass
class HarnessResult:
    """Complete results from running test harness."""

    results: List[MethodVideoResult]
    timestamp: str  # ISO format
    total_methods: int
    total_videos: int

    def to_table(self) -> str:
        """
        Render results as formatted text table.

        Returns:
            Formatted string table with columns: Method | Video | Precision | Recall | F1 | Time
        """
        lines = []
        lines.append("=" * 110)
        lines.append(f"{'Method':<20} {'Video':<25} {'Precision':>10} {'Recall':>10} {'F1':>10} {'Time (s)':>10}")
        lines.append("=" * 110)

        # Group results by method
        method_groups: Dict[str, List[MethodVideoResult]] = {}
        for result in self.results:
            if result.method_name not in method_groups:
                method_groups[result.method_name] = []
            method_groups[result.method_name].append(result)

        # Sort methods alphabetically
        for method_name in sorted(method_groups.keys()):
            method_results = method_groups[method_name]

            # Sort videos within method
            method_results.sort(key=lambda r: r.video_filename)

            # Display each video result
            for result in method_results:
                if result.error:
                    # Display error
                    lines.append(
                        f"{method_name:<20} {result.video_filename:<25} "
                        f"{'ERROR':>10} {'ERROR':>10} {'ERROR':>10} "
                        f"{result.processing_time:>10.3f}"
                    )
                else:
                    # Display metrics
                    lines.append(
                        f"{method_name:<20} {result.video_filename:<25} "
                        f"{result.metrics.precision:>10.3f} {result.metrics.recall:>10.3f} "
                        f"{result.metrics.f1:>10.3f} {result.processing_time:>10.3f}"
                    )

            # Calculate and display average for this method
            successful_results = [r for r in method_results if r.error is None]
            if successful_results:
                avg_precision = sum(r.metrics.precision for r in successful_results) / len(successful_results)
                avg_recall = sum(r.metrics.recall for r in successful_results) / len(successful_results)
                avg_f1 = sum(r.metrics.f1 for r in successful_results) / len(successful_results)
                avg_time = sum(r.processing_time for r in successful_results) / len(successful_results)

                lines.append("-" * 110)
                lines.append(
                    f"{method_name + ' (avg)':<20} {'':<25} "
                    f"{avg_precision:>10.3f} {avg_recall:>10.3f} "
                    f"{avg_f1:>10.3f} {avg_time:>10.3f}"
                )
                lines.append("")

        lines.append("=" * 110)
        return "\n".join(lines)

    def to_summary(self) -> Dict[str, Dict]:
        """
        Aggregate metrics per method.

        Returns:
            Dictionary mapping method_name to aggregated statistics:
            {
                "method_name": {
                    "precision": float,
                    "recall": float,
                    "f1": float,
                    "avg_time": float,
                    "num_videos": int,
                    "num_errors": int
                }
            }
        """
        summary = {}

        # Group results by method
        method_groups: Dict[str, List[MethodVideoResult]] = {}
        for result in self.results:
            if result.method_name not in method_groups:
                method_groups[result.method_name] = []
            method_groups[result.method_name].append(result)

        # Calculate aggregates
        for method_name, method_results in method_groups.items():
            successful_results = [r for r in method_results if r.error is None]
            error_results = [r for r in method_results if r.error is not None]

            if successful_results:
                avg_precision = sum(r.metrics.precision for r in successful_results) / len(successful_results)
                avg_recall = sum(r.metrics.recall for r in successful_results) / len(successful_results)
                avg_f1 = sum(r.metrics.f1 for r in successful_results) / len(successful_results)
                avg_time = sum(r.processing_time for r in successful_results) / len(successful_results)
            else:
                avg_precision = avg_recall = avg_f1 = avg_time = 0.0

            summary[method_name] = {
                "precision": avg_precision,
                "recall": avg_recall,
                "f1": avg_f1,
                "avg_time": avg_time,
                "num_videos": len(method_results),
                "num_errors": len(error_results)
            }

        return summary


class TestHarness:
    """
    Automated test harness for evaluating all registered methods.

    Discovers methods via the framework registry, loads ground truth from iOS
    TestResources, executes each method on each video, and calculates evaluation
    metrics.
    """

    def __init__(self, iou_threshold: float = 0.5):
        """
        Initialize test harness.

        Args:
            iou_threshold: IoU threshold for segment matching (default: 0.5)
        """
        self.iou_threshold = iou_threshold

    def run_all(self, verbose: bool = True) -> HarnessResult:
        """
        Run all registered methods on all test videos.

        Args:
            verbose: If True, print progress during execution

        Returns:
            HarnessResult containing all method-video results
        """
        # Discover methods
        methods = get_registered_methods()
        if verbose:
            print(f"\nDiscovered {len(methods)} method(s): {list(methods.keys())}")

        # Load ground truth
        gt_loader = GroundTruthLoader()
        all_gt = gt_loader.load_all()
        if verbose:
            print(f"Loaded {len(all_gt)} ground truth file(s)")
            print()

        # Initialize results collection
        results: List[MethodVideoResult] = []
        video_loader = VideoLoader()

        # Execute each method on each video
        for method_name, method_class in methods.items():
            if verbose:
                print(f"Running {method_name}...")

            # Instantiate method
            method = method_class()

            # Run on each video
            for gt_filename, gt in sorted(all_gt.items()):
                # Resolve video path
                try:
                    video_path = video_loader.resolve_path(gt.video_filename)
                except FileNotFoundError as e:
                    # Video file not found - record error
                    result = MethodVideoResult(
                        method_name=method_name,
                        video_filename=gt.video_filename,
                        ground_truth=gt,
                        method_result=None,
                        metrics=None,
                        processing_time=0.0,
                        error=f"Video file not found: {str(e)}"
                    )
                    results.append(result)
                    if verbose:
                        print(f"  ERROR {method_name} on {gt.video_filename}: Video file not found")
                    continue

                # Get video metadata
                try:
                    metadata = video_loader.get_metadata(video_path)
                except Exception as e:
                    # Metadata extraction failed
                    result = MethodVideoResult(
                        method_name=method_name,
                        video_filename=gt.video_filename,
                        ground_truth=gt,
                        method_result=None,
                        metrics=None,
                        processing_time=0.0,
                        error=f"Metadata extraction failed: {str(e)}"
                    )
                    results.append(result)
                    if verbose:
                        print(f"  ERROR {method_name} on {gt.video_filename}: Metadata extraction failed")
                    continue

                # Run method analysis
                method_result, error = self._safe_analyze(method, video_path)
                processing_time = method_result.processing_time if method_result else 0.0

                if error:
                    # Method crashed
                    result = MethodVideoResult(
                        method_name=method_name,
                        video_filename=gt.video_filename,
                        ground_truth=gt,
                        method_result=None,
                        metrics=None,
                        processing_time=processing_time,
                        error=error
                    )
                    results.append(result)
                    if verbose:
                        print(f"  ERROR {method_name} on {gt.video_filename}: {error}")
                else:
                    # Method succeeded - evaluate
                    detected_segments = [TimeRange(start=s[0], end=s[1]) for s in method_result.segments]
                    gt_segments = gt.as_time_ranges()

                    metrics = SegmentEvaluator.evaluate(
                        detected=detected_segments,
                        ground_truth=gt_segments,
                        iou_threshold=self.iou_threshold
                    )

                    result = MethodVideoResult(
                        method_name=method_name,
                        video_filename=gt.video_filename,
                        ground_truth=gt,
                        method_result=method_result,
                        metrics=metrics,
                        processing_time=processing_time,
                        error=None
                    )
                    results.append(result)

                    if verbose:
                        progress_str = self._format_progress(
                            method_name=method_name,
                            video=gt.video_filename,
                            metrics=metrics,
                            time=processing_time
                        )
                        print(progress_str)

            if verbose:
                print()

        # Create harness result
        harness_result = HarnessResult(
            results=results,
            timestamp=datetime.utcnow().isoformat(),
            total_methods=len(methods),
            total_videos=len(all_gt)
        )

        return harness_result

    def _safe_analyze(self, method, video_path) -> Tuple[Optional[MethodResult], Optional[str]]:
        """
        Safely execute method analysis with error handling.

        Args:
            method: Segmentation method instance
            video_path: Path to video file

        Returns:
            Tuple of (MethodResult or None, error message or None)
        """
        try:
            start_time = time.time()
            result = method.analyze(video_path)
            # Update processing time if method didn't track it
            if result.processing_time == 0.0:
                result.processing_time = time.time() - start_time
            return (result, None)
        except Exception as e:
            error_msg = f"{type(e).__name__}: {str(e)}"
            # Include traceback for debugging (first 500 chars)
            tb = traceback.format_exc()
            if len(tb) > 500:
                tb = tb[:500] + "..."
            error_msg += f"\n{tb}"
            return (None, error_msg)

    def _format_progress(self, method_name: str, video: str, metrics: EvaluationMetrics, time: float) -> str:
        """
        Format progress line for verbose output.

        Args:
            method_name: Name of the method
            video: Video filename
            metrics: Evaluation metrics
            time: Processing time in seconds

        Returns:
            Formatted progress string
        """
        return (
            f"  {method_name} on {video}: "
            f"P={metrics.precision:.2f} R={metrics.recall:.2f} F1={metrics.f1:.2f} "
            f"({time:.2f}s)"
        )
