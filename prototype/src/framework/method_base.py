"""Base class for all segmentation methods."""

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Dict, Any

from .result import MethodResult, ConfigSpec


class SegmentationMethod(ABC):
    """Base class for all segmentation methods.

    All methods must implement the abstract properties and methods to be
    compatible with the framework. Methods can optionally override get_viz_hooks()
    to provide intermediate visualization data.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable method name.

        Returns:
            Method name (e.g., "stub", "audio-onset")
        """
        ...

    @property
    @abstractmethod
    def version(self) -> str:
        """Method version string.

        Returns:
            Semantic version string (e.g., "1.0.0")
        """
        ...

    @abstractmethod
    def analyze(self, video_path: Path | str) -> MethodResult:
        """Run segmentation analysis on video.

        Args:
            video_path: Path to input video file

        Returns:
            MethodResult containing segments and FSM timeline
        """
        ...

    @abstractmethod
    def get_config_spec(self) -> ConfigSpec:
        """Return parameter definitions for this method.

        Returns:
            ConfigSpec describing all tunable parameters
        """
        ...

    def get_viz_hooks(self) -> Dict[str, Any]:
        """Optional: Return intermediate data for visualization.

        Default implementation returns empty dict.
        Subclasses can override to expose method-specific data.

        Returns:
            Dictionary of visualization hook names to data
        """
        return {}
