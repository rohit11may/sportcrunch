"""
Ground truth loading from iOS TestResources.

This module provides utilities for loading annotated segment data from JSON files
stored in the iOS app's test resources.
"""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict

from .evaluator import TimeRange


@dataclass
class Segment:
    """Represents a single annotated segment."""

    start: float
    end: float


@dataclass
class GroundTruth:
    """Ground truth annotation for a video."""

    video_filename: str
    sport: str
    mode: str  # "shot" or "rally"
    segments: List[Segment]

    def as_time_ranges(self) -> List[TimeRange]:
        """
        Convert segments to TimeRange objects for evaluation.

        Returns:
            List of TimeRange objects matching the segments
        """
        return [TimeRange(start=seg.start, end=seg.end) for seg in self.segments]


class GroundTruthLoader:
    """
    Loads ground truth annotations from iOS TestResources.

    Ground truth files are JSON files containing annotated segments for test videos.
    """

    # Path to ground truth JSON files in iOS app
    # From ground_truth.py: parent (evaluation) -> parent (src) -> parent (prototype) -> parent (sportcrunch) -> app
    GROUND_TRUTH_DIR = Path(__file__).parent.parent.parent.parent / "app" / "SportCrunchTests" / "TestResources" / "GroundTruth"

    def load(self, filename: str) -> GroundTruth:
        """
        Load a single ground truth JSON file.

        Args:
            filename: Name of the JSON file (e.g., "tennis-shot-1.json")

        Returns:
            GroundTruth object parsed from the JSON file

        Raises:
            FileNotFoundError: If the ground truth directory or file doesn't exist
            ValueError: If the JSON file is malformed
        """
        if not self.GROUND_TRUTH_DIR.exists():
            raise FileNotFoundError(
                f"Ground truth directory not found: {self.GROUND_TRUTH_DIR}\n"
                "Ensure the iOS app is in the expected location: ../app/"
            )

        file_path = self.GROUND_TRUTH_DIR / filename

        if not file_path.exists():
            raise FileNotFoundError(f"Ground truth file not found: {file_path}")

        try:
            with open(file_path, 'r') as f:
                data = json.load(f)

            # Parse segments
            segments = [
                Segment(start=seg["start"], end=seg["end"])
                for seg in data["segments"]
            ]

            return GroundTruth(
                video_filename=data["videoFilename"],
                sport=data["sport"],
                mode=data["mode"],
                segments=segments
            )
        except (KeyError, json.JSONDecodeError) as e:
            raise ValueError(f"Malformed ground truth JSON in {filename}: {e}")

    def load_all(self) -> Dict[str, GroundTruth]:
        """
        Load all ground truth JSON files from the directory.

        Returns:
            Dictionary mapping filename to GroundTruth object

        Raises:
            FileNotFoundError: If the ground truth directory doesn't exist
        """
        if not self.GROUND_TRUTH_DIR.exists():
            raise FileNotFoundError(
                f"Ground truth directory not found: {self.GROUND_TRUTH_DIR}\n"
                "Ensure the iOS app is in the expected location: ../app/"
            )

        ground_truths = {}
        for json_file in self.GROUND_TRUTH_DIR.glob("*.json"):
            filename = json_file.name
            ground_truths[filename] = self.load(filename)

        return ground_truths

    def list_available(self) -> List[str]:
        """
        List all available ground truth filenames.

        Returns:
            List of JSON filenames in the ground truth directory

        Raises:
            FileNotFoundError: If the ground truth directory doesn't exist
        """
        if not self.GROUND_TRUTH_DIR.exists():
            raise FileNotFoundError(
                f"Ground truth directory not found: {self.GROUND_TRUTH_DIR}\n"
                "Ensure the iOS app is in the expected location: ../app/"
            )

        return sorted([f.name for f in self.GROUND_TRUTH_DIR.glob("*.json")])
