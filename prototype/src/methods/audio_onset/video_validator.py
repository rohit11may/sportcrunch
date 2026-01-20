"""
VideoMotionValidator: Validates audio-detected segments using visual motion analysis.

Uses sparse frame differencing to detect player movement:
- Sample frames at low rate (every Nth frame)
- Downscale to thumbnail resolution
- Compute absolute frame differences
- Count "motion pixels" above threshold
"""

import cv2
import numpy as np
from dataclasses import dataclass
from typing import List, Tuple, Optional
from pathlib import Path


@dataclass
class SegmentValidation:
    """Validation result for a single segment."""
    start: float
    end: float
    is_valid: bool
    motion_score: float
    frame_scores: List[float]  # Score for each sampled frame pair
    sample_frames: List[np.ndarray]  # Thumbnail frames for visualization


@dataclass
class VideoValidationResult:
    """Container for all validation results."""
    video_path: str
    video_duration: float
    video_fps: float
    video_resolution: Tuple[int, int]
    segments: List[SegmentValidation]


class VideoMotionValidator:
    """
    Validates candidate segments by checking for sufficient motion.

    Pipeline:
    1. Seek to segment start
    2. Sample frames at stride interval
    3. Downscale to thumbnail size
    4. Compute frame differences
    5. Return True if motion exceeds threshold
    """

    def __init__(
        self,
        sample_stride: int = 10,
        thumb_size: Tuple[int, int] = (320, 180),
        motion_pixel_threshold: int = 25,
        motion_area_threshold: int = 500,
    ):
        self.sample_stride = sample_stride
        self.thumb_size = thumb_size
        self.motion_pixel_threshold = motion_pixel_threshold
        self.motion_area_threshold = motion_area_threshold

        self._video_path: Optional[str] = None
        self._video_info: Optional[dict] = None
        self._last_result: Optional[VideoValidationResult] = None

    def load_video(self, video_path: str) -> dict:
        """Load video and extract metadata."""
        self._video_path = video_path

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise ValueError(f"Could not open video: {video_path}")

        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        duration = frame_count / fps if fps > 0 else 0

        cap.release()

        self._video_info = {
            "path": video_path,
            "fps": fps,
            "frame_count": frame_count,
            "width": width,
            "height": height,
            "duration": duration,
        }

        return self._video_info

    def validate_segments(
        self,
        intervals: List[Tuple[float, float]],
        progress_callback: Optional[callable] = None,
    ) -> VideoValidationResult:
        """
        Validate multiple segments for motion.

        Args:
            intervals: List of (start, end) tuples in seconds
            progress_callback: Optional callback(current, total) for progress updates

        Returns:
            VideoValidationResult with validation for each segment
        """
        if self._video_path is None or self._video_info is None:
            raise ValueError("No video loaded. Call load_video() first.")

        segments = []
        total = len(intervals)

        for i, (start, end) in enumerate(intervals):
            validation = self._validate_segment(start, end)
            segments.append(validation)

            if progress_callback:
                progress_callback(i + 1, total)

        self._last_result = VideoValidationResult(
            video_path=self._video_path,
            video_duration=self._video_info["duration"],
            video_fps=self._video_info["fps"],
            video_resolution=(self._video_info["width"], self._video_info["height"]),
            segments=segments,
        )

        return self._last_result

    def _validate_segment(self, start: float, end: float) -> SegmentValidation:
        """Validate a single segment for motion."""
        cap = cv2.VideoCapture(self._video_path)
        fps = self._video_info["fps"]

        # Calculate frame range
        start_frame = int(start * fps)
        end_frame = int(end * fps)

        # Seek to start
        cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

        prev_thumb = None
        frame_scores = []
        sample_frames = []
        frame_idx = start_frame

        while frame_idx < end_frame:
            ret, frame = cap.read()
            if not ret:
                break

            # Downscale to thumbnail
            thumb = cv2.resize(frame, self.thumb_size)
            thumb_gray = cv2.cvtColor(thumb, cv2.COLOR_BGR2GRAY)

            # Store sample frame (keep only a few for visualization)
            if len(sample_frames) < 8:
                # Convert BGR to RGB for display
                sample_frames.append(cv2.cvtColor(thumb, cv2.COLOR_BGR2RGB))

            # Compute motion score
            if prev_thumb is not None:
                score = self._compute_motion_score(prev_thumb, thumb_gray)
                frame_scores.append(score)

            prev_thumb = thumb_gray

            # Skip frames according to stride
            for _ in range(self.sample_stride - 1):
                cap.read()
                frame_idx += 1
            frame_idx += 1

        cap.release()

        # Calculate overall motion score (average of frame scores)
        if frame_scores:
            motion_score = np.mean(frame_scores)
        else:
            motion_score = 0.0

        is_valid = motion_score >= self.motion_area_threshold

        return SegmentValidation(
            start=start,
            end=end,
            is_valid=is_valid,
            motion_score=motion_score,
            frame_scores=frame_scores,
            sample_frames=sample_frames,
        )

    def _compute_motion_score(
        self,
        frame_a: np.ndarray,
        frame_b: np.ndarray
    ) -> float:
        """
        Compute motion score between two grayscale frames.

        Returns count of pixels with difference above threshold.
        """
        # Absolute difference
        diff = cv2.absdiff(frame_a, frame_b)

        # Threshold to binary
        _, binary = cv2.threshold(
            diff,
            self.motion_pixel_threshold,
            255,
            cv2.THRESH_BINARY
        )

        # Count motion pixels
        motion_pixels = np.count_nonzero(binary)

        return float(motion_pixels)

    def get_validated_intervals(self) -> List[Tuple[float, float]]:
        """Return only the validated (motion confirmed) intervals."""
        if self._last_result is None:
            return []

        return [
            (seg.start, seg.end)
            for seg in self._last_result.segments
            if seg.is_valid
        ]

    @property
    def last_result(self) -> Optional[VideoValidationResult]:
        """Access the full result from the last validation."""
        return self._last_result

    @property
    def video_info(self) -> Optional[dict]:
        """Get video metadata."""
        return self._video_info
