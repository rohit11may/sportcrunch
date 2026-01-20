"""Result dataclasses and enums for segmentation methods."""

from dataclasses import dataclass, field
from enum import StrEnum, auto
from typing import Any, List, Tuple, Optional


class BaseState(StrEnum):
    """Minimum required FSM states for all methods."""
    ACTIVE = auto()    # Serializes as "active"
    INACTIVE = auto()  # Serializes as "inactive"


class ParamType(StrEnum):
    """Supported parameter types for method configuration."""
    INT = auto()
    FLOAT = auto()
    BOOL = auto()
    STRING = auto()
    CHOICE = auto()


@dataclass
class ParamDef:
    """Definition of a single parameter."""
    name: str
    type: ParamType
    default: Any
    description: str
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    choices: Optional[List[str]] = None


@dataclass
class ConfigSpec:
    """Parameter specification for a method."""
    params: List[ParamDef] = field(default_factory=list)

    def to_defaults(self) -> dict:
        """Return dict of parameter names to default values."""
        return {p.name: p.default for p in self.params}

    def validate(self, config: dict) -> dict:
        """Validate and fill in defaults for a config dict.

        Args:
            config: User-provided configuration dictionary

        Returns:
            Complete configuration with defaults filled in

        Raises:
            ValueError: If config contains unknown parameters
        """
        result = self.to_defaults()
        for key, value in config.items():
            if key not in result:
                raise ValueError(f"Unknown parameter: {key}")
            result[key] = value
        return result


@dataclass
class MethodResult:
    """Result from a segmentation method."""
    video_path: str
    video_duration: float
    segments: List[Tuple[float, float]]  # [(start, end), ...]
    fsm_timeline: List[Tuple[float, str]]  # [(timestamp, state), ...]
    processing_time: float
    method_name: str
    method_version: str

    # Optional intermediate data (not validated)
    intermediate_data: dict = field(default_factory=dict)

    def __post_init__(self):
        """Validate FSM timeline covers full video duration."""
        # FSM timeline cannot be empty
        if not self.fsm_timeline:
            raise ValueError("FSM timeline cannot be empty")

        # Timeline must be sorted by timestamp
        timestamps = [t for t, _ in self.fsm_timeline]
        if timestamps != sorted(timestamps):
            raise ValueError("FSM timeline must be sorted by timestamp")

        # Timeline must start near 0 (allow 0.1s tolerance)
        first_ts = self.fsm_timeline[0][0]
        if first_ts > 0.1:
            raise ValueError(f"FSM timeline must start near 0, got {first_ts}s")

        # Timeline must cover full video duration (within 0.1s)
        last_ts = self.fsm_timeline[-1][0]
        if last_ts < self.video_duration - 0.1:
            raise ValueError(
                f"FSM timeline must cover full video duration "
                f"({self.video_duration}s), last entry at {last_ts}s"
            )

        # Required states (active, inactive) must be present
        states = {s for _, s in self.fsm_timeline}
        required = {BaseState.ACTIVE.value, BaseState.INACTIVE.value}
        if not required.issubset(states):
            missing = required - states
            raise ValueError(f"FSM timeline missing required states: {missing}")
