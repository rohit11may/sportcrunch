"""AudioOnsetMethod: Framework wrapper for AV-Funnel pipeline."""

import time
from pathlib import Path
from typing import Dict, Any

from src.framework.method_base import SegmentationMethod
from src.framework.result import MethodResult, ConfigSpec, ParamDef, ParamType, BaseState
from src.framework.registry import register_method
from src.utils.video import VideoLoader

from .pipeline import TennisCropper


@register_method
class AudioOnsetMethod(SegmentationMethod):
    """
    Audio onset detection with video motion validation.

    Uses the AV-Funnel pipeline:
    1. Audio analysis: bandpass filter + spectral flux + peak detection
    2. Temporal clustering: group hits into rally candidates
    3. Video validation: motion detection to confirm activity
    4. Merge overlapping intervals

    FSM States:
    - inactive: No rally activity
    - audio_candidate: Audio detected hits but not yet validated
    - active: Validated rally segment
    - rejected: Audio candidate rejected by video validation
    """

    def __init__(self, **config):
        """Initialize with optional configuration overrides.

        Args:
            **config: Parameter overrides (see get_config_spec for available params)
        """
        # Get defaults and merge with user config
        spec = self.get_config_spec()
        self.config = spec.validate(config)

        # Store last pipeline result for visualization hooks
        self._last_cropper = None

    @property
    def name(self) -> str:
        return "audio-onset"

    @property
    def version(self) -> str:
        return "1.0.0"

    def analyze(self, video_path: Path | str) -> MethodResult:
        """Run AV-Funnel pipeline on video.

        Args:
            video_path: Path to input video file

        Returns:
            MethodResult with segments, FSM timeline, and intermediate data
        """
        video_path = Path(video_path)

        # Get video metadata for duration
        metadata = VideoLoader().get_metadata(str(video_path))

        # Parse video_thumb_size from string "WxH" to tuple (W, H)
        thumb_size_str = self.config.get("video_thumb_size", "320x180")
        if isinstance(thumb_size_str, str):
            w, h = thumb_size_str.split("x")
            thumb_size = (int(w), int(h))
        else:
            thumb_size = thumb_size_str

        # Build config dict for TennisCropper (with parsed thumb_size)
        cropper_config = self.config.copy()
        cropper_config["video_thumb_size"] = thumb_size

        # Create pipeline with current config
        cropper = TennisCropper(**cropper_config)

        # Run pipeline (no export, just analysis)
        start_time = time.time()
        pipeline_result = cropper.process(
            str(video_path),
            output_path=None,  # Don't export
            skip_validation=False,
        )
        processing_time = time.time() - start_time

        # Store for viz hooks
        self._last_cropper = cropper

        # Build segments from merged intervals
        segments = pipeline_result.merged_intervals

        # Build FSM timeline
        fsm_timeline = self._build_fsm_timeline(pipeline_result, metadata.duration)

        # Package intermediate data
        intermediate_data = {
            "audio_result": pipeline_result.audio_result,
            "video_result": pipeline_result.video_result,
            "audio_candidates": pipeline_result.audio_candidates,
            "validated_intervals": pipeline_result.validated_intervals,
            "rejected_intervals": pipeline_result.rejected_intervals,
        }

        return MethodResult(
            video_path=str(video_path),
            video_duration=metadata.duration,
            segments=segments,
            fsm_timeline=fsm_timeline,
            processing_time=processing_time,
            method_name=self.name,
            method_version=self.version,
            intermediate_data=intermediate_data,
        )

    def _build_fsm_timeline(self, pipeline_result, video_duration: float):
        """Build FSM state timeline from pipeline stages.

        States:
        - inactive: Gaps between rallies
        - audio_candidate: Audio detected but not yet validated
        - active: Validated rally
        - rejected: Audio candidate that failed video validation

        Args:
            pipeline_result: Result from TennisCropper.process()
            video_duration: Total video duration in seconds

        Returns:
            List of (timestamp, state) tuples covering [0, video_duration]
        """
        # Collect all intervals with their states
        events = []

        # Active segments (validated + merged)
        for start, end in pipeline_result.merged_intervals:
            events.append((start, "active_start"))
            events.append((end, "active_end"))

        # Rejected segments (audio candidates that failed validation)
        for start, end in pipeline_result.rejected_intervals:
            events.append((start, "rejected_start"))
            events.append((end, "rejected_end"))

        # Sort events by timestamp
        events.sort(key=lambda x: x[0])

        # Build timeline
        timeline = [(0.0, BaseState.INACTIVE.value)]

        for timestamp, event_type in events:
            if event_type == "active_start":
                timeline.append((timestamp, BaseState.ACTIVE.value))
            elif event_type == "active_end":
                timeline.append((timestamp, BaseState.INACTIVE.value))
            elif event_type == "rejected_start":
                timeline.append((timestamp, "rejected"))
            elif event_type == "rejected_end":
                timeline.append((timestamp, BaseState.INACTIVE.value))

        # Ensure timeline ends at video duration
        if timeline[-1][0] < video_duration:
            # Extend last state to video end
            last_state = timeline[-1][1]
            timeline.append((video_duration, last_state))

        return timeline

    def get_config_spec(self) -> ConfigSpec:
        """Return all 12 tunable parameters from TennisCropper."""
        return ConfigSpec(params=[
            # Audio analysis parameters
            ParamDef(
                name="bandpass_low",
                type=ParamType.FLOAT,
                default=200.0,
                description="Bandpass filter low frequency (Hz)",
                min_value=50.0,
                max_value=1000.0,
            ),
            ParamDef(
                name="bandpass_high",
                type=ParamType.FLOAT,
                default=3000.0,
                description="Bandpass filter high frequency (Hz)",
                min_value=1000.0,
                max_value=10000.0,
            ),
            ParamDef(
                name="onset_threshold_lambda",
                type=ParamType.FLOAT,
                default=2.0,
                description="Onset detection threshold (λ × median)",
                min_value=0.5,
                max_value=5.0,
            ),
            ParamDef(
                name="peak_min_distance_sec",
                type=ParamType.FLOAT,
                default=0.5,
                description="Minimum seconds between detected hits",
                min_value=0.1,
                max_value=2.0,
            ),
            ParamDef(
                name="cluster_max_gap_sec",
                type=ParamType.FLOAT,
                default=3.0,
                description="Max gap within rally (seconds)",
                min_value=1.0,
                max_value=10.0,
            ),
            ParamDef(
                name="cluster_min_hits",
                type=ParamType.INT,
                default=2,
                description="Minimum hits per rally",
                min_value=1,
                max_value=10,
            ),
            ParamDef(
                name="padding_pre_sec",
                type=ParamType.FLOAT,
                default=2.0,
                description="Padding before rally (seconds)",
                min_value=0.0,
                max_value=5.0,
            ),
            ParamDef(
                name="padding_post_sec",
                type=ParamType.FLOAT,
                default=2.0,
                description="Padding after rally (seconds)",
                min_value=0.0,
                max_value=5.0,
            ),
            # Video validation parameters
            ParamDef(
                name="video_sample_stride",
                type=ParamType.INT,
                default=10,
                description="Sample every Nth frame for motion detection",
                min_value=1,
                max_value=30,
            ),
            ParamDef(
                name="video_thumb_size",
                type=ParamType.STRING,
                default="320x180",
                description="Thumbnail size for motion detection (WxH)",
            ),
            ParamDef(
                name="motion_pixel_threshold",
                type=ParamType.INT,
                default=25,
                description="Pixel difference threshold for motion",
                min_value=10,
                max_value=100,
            ),
            ParamDef(
                name="motion_area_threshold",
                type=ParamType.INT,
                default=500,
                description="Minimum motion pixels to validate segment",
                min_value=100,
                max_value=5000,
            ),
        ])

    def get_viz_hooks(self) -> Dict[str, Any]:
        """Return intermediate data for visualization.

        Available after analyze() is called:
        - waveform: Audio waveform (raw + filtered)
        - onset: Onset strength and detected peaks
        - motion: Motion scores per segment
        """
        if self._last_cropper is None or self._last_cropper.last_result is None:
            return {}

        result = self._last_cropper.last_result
        audio = result.audio_result
        video = result.video_result

        return {
            "waveform": {
                "times": audio.waveform_times,
                "raw": audio.waveform_raw,
                "filtered": audio.waveform_filtered,
            },
            "onset": {
                "times": audio.onset_times,
                "strength": audio.onset_strength,
                "threshold": audio.onset_threshold,
                "peaks": audio.peak_times,
                "peak_strengths": audio.peak_strengths,
            },
            "motion": {
                "segments": [
                    {
                        "start": seg.start,
                        "end": seg.end,
                        "is_valid": seg.is_valid,
                        "motion_score": seg.motion_score,
                        "frame_scores": seg.frame_scores,
                    }
                    for seg in video.segments
                ] if video else [],
            },
        }
