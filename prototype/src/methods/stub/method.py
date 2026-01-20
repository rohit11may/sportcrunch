"""Stub method that returns fixed segments for testing framework."""

from pathlib import Path

from src.framework.method_base import SegmentationMethod
from src.framework.result import MethodResult, ConfigSpec, ParamDef, ParamType, BaseState
from src.framework.registry import register_method


@register_method
class StubMethod(SegmentationMethod):
    """Stub method that returns fixed segments for testing framework.

    This method doesn't actually analyze video - it returns predetermined
    segments to verify the framework interface works correctly.
    """

    @property
    def name(self) -> str:
        return "stub"

    @property
    def version(self) -> str:
        return "1.0.0"

    def analyze(self, video_path: Path | str) -> MethodResult:
        """Return fixed segments for a hypothetical 60s video.

        Args:
            video_path: Path to video (not actually read by stub)

        Returns:
            MethodResult with fixed segments and FSM timeline
        """
        # Convert to Path for consistent handling
        video_path = Path(video_path)

        # Stub: assume 60s video, return fixed segments
        video_duration = 60.0
        segments = [(5.0, 10.0), (20.0, 25.0), (40.0, 45.0)]

        # Build FSM timeline: start inactive, active during segments, inactive between
        fsm_timeline = [(0.0, BaseState.INACTIVE.value)]
        for start, end in segments:
            fsm_timeline.append((start, BaseState.ACTIVE.value))
            fsm_timeline.append((end, BaseState.INACTIVE.value))
        # Ensure timeline covers full duration
        fsm_timeline.append((video_duration, BaseState.INACTIVE.value))

        return MethodResult(
            video_path=str(video_path),
            video_duration=video_duration,
            segments=segments,
            fsm_timeline=fsm_timeline,
            processing_time=0.001,
            method_name=self.name,
            method_version=self.version,
        )

    def get_config_spec(self) -> ConfigSpec:
        """Return config spec with one dummy parameter for testing.

        Returns:
            ConfigSpec with a single float parameter
        """
        return ConfigSpec(params=[
            ParamDef(
                name="dummy_param",
                type=ParamType.FLOAT,
                default=1.0,
                description="A dummy parameter for testing",
                min_value=0.0,
                max_value=10.0,
            )
        ])
