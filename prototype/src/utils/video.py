"""
Video loading and metadata extraction utilities.

This module provides utilities for accessing test videos from the iOS app's
TestResources directory and extracting video metadata using OpenCV.
"""

import cv2
from dataclasses import dataclass
from pathlib import Path
from typing import List, Union


@dataclass
class VideoMetadata:
    """Metadata extracted from a video file."""

    path: Path
    filename: str
    duration: float  # seconds
    fps: float
    width: int
    height: int
    frame_count: int


class VideoLoader:
    """
    Loads videos from iOS TestResources directory.

    Provides path resolution and metadata extraction for test videos.
    """

    # Path to video files in iOS app
    # From video.py: parent (utils) -> parent (src) -> parent (prototype) -> parent (sportcrunch) -> app
    VIDEO_DIR = Path(__file__).parent.parent.parent.parent / "app" / "SportCrunchTests" / "TestResources" / "Videos"

    def resolve_path(self, filename: str) -> Path:
        """
        Resolve video filename to full path.

        Args:
            filename: Video filename (e.g., "tennis-shot-1.mp4")

        Returns:
            Full path to the video file

        Raises:
            FileNotFoundError: If the video file doesn't exist
        """
        if not self.VIDEO_DIR.exists():
            raise FileNotFoundError(
                f"Video directory not found: {self.VIDEO_DIR}\n"
                "Ensure the iOS app is in the expected location: ../app/"
            )

        video_path = self.VIDEO_DIR / filename

        if not video_path.exists():
            raise FileNotFoundError(f"Video file not found: {video_path}")

        return video_path

    def get_metadata(self, video_path: Union[str, Path]) -> VideoMetadata:
        """
        Extract metadata from a video file using OpenCV.

        Args:
            video_path: Path to the video file (string or Path object)

        Returns:
            VideoMetadata object with extracted information

        Raises:
            ValueError: If the video cannot be opened or metadata extraction fails
        """
        path = Path(video_path) if isinstance(video_path, str) else video_path

        # Open video with OpenCV
        cap = cv2.VideoCapture(str(path))

        try:
            if not cap.isOpened():
                raise ValueError(f"Cannot open video file: {path}")

            # Extract metadata
            fps = cap.get(cv2.CAP_PROP_FPS)
            frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

            # Calculate duration
            if fps > 0:
                duration = frame_count / fps
            else:
                raise ValueError(f"Invalid FPS ({fps}) for video: {path}")

            return VideoMetadata(
                path=path,
                filename=path.name,
                duration=duration,
                fps=fps,
                width=width,
                height=height,
                frame_count=frame_count
            )
        finally:
            # Always release the video capture
            cap.release()

    def list_available(self) -> List[str]:
        """
        List all available video files in the TestResources directory.

        Returns:
            Sorted list of video filenames (.mp4 and .mov files)

        Raises:
            FileNotFoundError: If the video directory doesn't exist
        """
        if not self.VIDEO_DIR.exists():
            raise FileNotFoundError(
                f"Video directory not found: {self.VIDEO_DIR}\n"
                "Ensure the iOS app is in the expected location: ../app/"
            )

        video_files = []
        for ext in ["*.mp4", "*.mov"]:
            video_files.extend([f.name for f in self.VIDEO_DIR.glob(ext)])

        return sorted(video_files)
