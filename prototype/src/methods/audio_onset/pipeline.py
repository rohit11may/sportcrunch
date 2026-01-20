"""
TennisCropper: Main pipeline orchestrating audio analysis, video validation, and export.

Implements the "propose and verify" architecture:
1. Audio analysis proposes candidate rally segments (fast, coarse filter)
2. Video validation confirms motion in each segment (targeted verification)
3. Editor merges and exports the final summary
"""

from dataclasses import dataclass
from typing import List, Tuple, Optional, Callable
from pathlib import Path

from .audio_analyzer import TennisAudioAnalyzer, AudioAnalysisResult
from .video_validator import VideoMotionValidator, VideoValidationResult
from src.video_editor import ClipEditor, ExportResult


@dataclass
class PipelineResult:
    """Complete result from the tennis cropping pipeline."""
    # Input info
    video_path: str
    video_duration: float

    # Audio analysis
    audio_result: AudioAnalysisResult
    audio_candidates: List[Tuple[float, float]]

    # Video validation
    video_result: VideoValidationResult
    validated_intervals: List[Tuple[float, float]]
    rejected_intervals: List[Tuple[float, float]]

    # Final output
    merged_intervals: List[Tuple[float, float]]
    output_duration: float
    compression_ratio: float

    # Timing
    audio_processing_time: float
    video_processing_time: float
    total_processing_time: float


class TennisCropper:
    """
    Main pipeline for tennis video summarization.

    Usage:
        cropper = TennisCropper()
        result = cropper.process("match.mp4", "highlights.mp4")
        print(f"Compressed {result.compression_ratio:.1f}%")
    """

    def __init__(
        self,
        # Audio parameters
        bandpass_low: float = 200,
        bandpass_high: float = 3000,
        onset_threshold_lambda: float = 2.0,
        peak_min_distance_sec: float = 0.5,
        cluster_max_gap_sec: float = 3.0,
        cluster_min_hits: int = 2,
        padding_pre_sec: float = 2.0,
        padding_post_sec: float = 2.0,
        # Video parameters
        video_sample_stride: int = 10,
        video_thumb_size: Tuple[int, int] = (320, 180),
        motion_pixel_threshold: int = 25,
        motion_area_threshold: int = 500,
    ):
        # Store parameters
        self.audio_params = {
            "bandpass_low": bandpass_low,
            "bandpass_high": bandpass_high,
            "onset_threshold_lambda": onset_threshold_lambda,
            "peak_min_distance_sec": peak_min_distance_sec,
            "cluster_max_gap_sec": cluster_max_gap_sec,
            "cluster_min_hits": cluster_min_hits,
            "padding_pre_sec": padding_pre_sec,
            "padding_post_sec": padding_post_sec,
        }

        self.video_params = {
            "sample_stride": video_sample_stride,
            "thumb_size": video_thumb_size,
            "motion_pixel_threshold": motion_pixel_threshold,
            "motion_area_threshold": motion_area_threshold,
        }

        # Initialize components
        self.audio_analyzer = TennisAudioAnalyzer(**self.audio_params)
        self.video_validator = VideoMotionValidator(**self.video_params)
        self.editor: Optional[ClipEditor] = None

        # Store last result for visualization
        self._last_result: Optional[PipelineResult] = None

    def analyze_audio(
        self,
        video_path: str,
        progress_callback: Optional[Callable[[str], None]] = None,
    ) -> AudioAnalysisResult:
        """
        Run audio analysis only (for interactive tuning).

        Args:
            video_path: Path to video file
            progress_callback: Optional callback for status messages

        Returns:
            AudioAnalysisResult with detected peaks and rally intervals
        """
        if progress_callback:
            progress_callback("Loading audio from video...")

        result = self.audio_analyzer.analyze(video_path)

        if progress_callback:
            progress_callback(
                f"Found {len(result.peak_times)} hits in "
                f"{len(result.rally_intervals)} potential rallies"
            )

        return result

    def validate_video(
        self,
        video_path: str,
        intervals: List[Tuple[float, float]],
        progress_callback: Optional[Callable[[str], None]] = None,
    ) -> VideoValidationResult:
        """
        Run video validation only (for interactive tuning).

        Args:
            video_path: Path to video file
            intervals: Candidate intervals from audio analysis
            progress_callback: Optional callback for status messages

        Returns:
            VideoValidationResult with motion scores for each segment
        """
        if progress_callback:
            progress_callback("Loading video metadata...")

        self.video_validator.load_video(video_path)

        if progress_callback:
            progress_callback(f"Validating {len(intervals)} segments...")

        def video_progress(current, total):
            if progress_callback:
                progress_callback(f"Validating segment {current}/{total}...")

        result = self.video_validator.validate_segments(
            intervals,
            progress_callback=video_progress
        )

        validated_count = sum(1 for seg in result.segments if seg.is_valid)
        if progress_callback:
            progress_callback(
                f"Validated {validated_count}/{len(intervals)} segments"
            )

        return result

    def process(
        self,
        video_path: str,
        output_path: Optional[str] = None,
        skip_validation: bool = False,
        progress_callback: Optional[Callable[[str], None]] = None,
    ) -> PipelineResult:
        """
        Run the full pipeline: audio analysis → video validation → export.

        Args:
            video_path: Path to input video
            output_path: Path for output video (None = don't export, just analyze)
            skip_validation: If True, skip video motion validation
            progress_callback: Optional callback for status messages

        Returns:
            PipelineResult with all intermediate and final data
        """
        import time
        start_time = time.time()

        # Step 1: Audio Analysis
        if progress_callback:
            progress_callback("Step 1/3: Analyzing audio...")

        audio_start = time.time()
        audio_result = self.analyze_audio(video_path, progress_callback)
        audio_time = time.time() - audio_start

        audio_candidates = audio_result.rally_intervals

        # Step 2: Video Validation
        if skip_validation:
            validated_intervals = audio_candidates
            rejected_intervals = []
            video_result = None
            video_time = 0.0
        else:
            if progress_callback:
                progress_callback("Step 2/3: Validating with video...")

            video_start = time.time()
            video_result = self.validate_video(
                video_path,
                audio_candidates,
                progress_callback
            )
            video_time = time.time() - video_start

            validated_intervals = [
                (seg.start, seg.end)
                for seg in video_result.segments
                if seg.is_valid
            ]
            rejected_intervals = [
                (seg.start, seg.end)
                for seg in video_result.segments
                if not seg.is_valid
            ]

        # Step 3: Merge intervals and optionally export
        if progress_callback:
            progress_callback("Step 3/3: Preparing output...")

        self.editor = ClipEditor(video_path)
        self.editor.load()

        merged_intervals = self.editor.merge_intervals(validated_intervals)
        output_duration = sum(end - start for start, end in merged_intervals)
        video_duration = self.editor._duration
        compression_ratio = (1 - output_duration / video_duration) * 100 if video_duration > 0 else 0

        # Export if output path provided
        if output_path is not None and merged_intervals:
            if progress_callback:
                progress_callback("Exporting summary video...")

            self.editor.extract_and_export(
                merged_intervals,
                output_path,
                merge_overlapping=False,  # Already merged
                progress_callback=progress_callback,
            )

        total_time = time.time() - start_time

        self._last_result = PipelineResult(
            video_path=video_path,
            video_duration=video_duration,
            audio_result=audio_result,
            audio_candidates=audio_candidates,
            video_result=video_result,
            validated_intervals=validated_intervals,
            rejected_intervals=rejected_intervals,
            merged_intervals=merged_intervals,
            output_duration=output_duration,
            compression_ratio=compression_ratio,
            audio_processing_time=audio_time,
            video_processing_time=video_time,
            total_processing_time=total_time,
        )

        if progress_callback:
            progress_callback(
                f"Complete! {len(merged_intervals)} rallies, "
                f"{compression_ratio:.1f}% compression"
            )

        return self._last_result

    def update_params(self, **kwargs):
        """Update pipeline parameters and reinitialize components."""
        # Update audio params
        audio_keys = set(self.audio_params.keys())
        for key, value in kwargs.items():
            if key in audio_keys:
                self.audio_params[key] = value

        # Update video params
        video_key_map = {
            "video_sample_stride": "sample_stride",
            "video_thumb_size": "thumb_size",
            "motion_pixel_threshold": "motion_pixel_threshold",
            "motion_area_threshold": "motion_area_threshold",
        }
        for key, value in kwargs.items():
            if key in video_key_map:
                self.video_params[video_key_map[key]] = value

        # Reinitialize components
        self.audio_analyzer = TennisAudioAnalyzer(**self.audio_params)
        self.video_validator = VideoMotionValidator(**self.video_params)

    @property
    def last_result(self) -> Optional[PipelineResult]:
        """Access the result from the last process() call."""
        return self._last_result
