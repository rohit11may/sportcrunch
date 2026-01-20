# Phase 1: Framework Foundation - Research

**Researched:** 2026-01-20
**Domain:** Python plugin architecture, ABC patterns, dataclass validation
**Confidence:** HIGH

## Summary

This phase establishes the core abstractions for a multi-method video segmentation framework. The implementation requires three interconnected components: an Abstract Base Class (ABC) defining the method interface, dataclasses for structured results with FSM state timelines, and a decorator-based registry for method auto-discovery.

Python 3.13 provides all necessary features in the standard library. The ABC module, dataclasses with `__post_init__` validation, `StrEnum` for states, and `importlib` for module discovery are mature and well-documented. No external libraries are required for the core framework.

The existing codebase already uses dataclasses (`AudioAnalysisResult`, `PipelineResult`) and a modular pipeline pattern (`TennisCropper`), making the abstraction layer a natural evolution rather than a rewrite.

**Primary recommendation:** Use standard library ABC + dataclass + StrEnum. Implement a simple decorator registry with explicit module imports for method discovery. Avoid complex plugin architectures for this scale.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `abc` | stdlib | Abstract base class | Part of Python since 3.4, recommended over NotImplementedError |
| `dataclasses` | stdlib | Structured result objects | Native since 3.7, project already uses this pattern |
| `enum.StrEnum` | stdlib | FSM state representation | Added 3.11, provides string-compatible enum values |
| `typing` | stdlib | Type hints for interfaces | Standard for modern Python APIs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `importlib` | stdlib | Module discovery for registry | Auto-loading method modules |
| `pkgutil` | stdlib | Package iteration | If methods organized as subpackage |
| `pathlib` | stdlib | Path handling | Video path resolution in interface |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dataclass | Pydantic | Pydantic adds validation but increases complexity; overkill for internal results |
| StrEnum | plain strings | StrEnum catches typos at definition time, better IDE support |
| decorator registry | entry_points | Entry points require packaging setup, too heavy for single-repo |

**Installation:**
```bash
# No additional packages needed - all stdlib
# Existing dependencies already in project: numpy, librosa, scipy
```

## Architecture Patterns

### Recommended Project Structure
```
src/
├── framework/           # Core abstractions
│   ├── __init__.py      # Exports public API
│   ├── method_base.py   # SegmentationMethod ABC
│   ├── result.py        # MethodResult, ConfigSpec dataclasses
│   └── registry.py      # @register_method, get_registered_methods()
├── methods/             # Method implementations
│   ├── __init__.py      # Imports all method modules for registration
│   ├── stub/
│   │   ├── __init__.py
│   │   └── method.py    # StubMethod for testing
│   └── av_funnel/       # (Phase 3)
│       ├── __init__.py
│       └── method.py    # AudioOnsetMethod wrapping TennisCropper
└── [existing modules]   # audio_analyzer.py, pipeline.py, etc.
```

### Pattern 1: Abstract Base Class with Hybrid Interface
**What:** ABC requiring black-box output (MethodResult) while allowing optional intermediate visualization hooks.
**When to use:** When methods have fundamentally different internal architectures but must produce comparable outputs.
**Example:**
```python
# Source: https://docs.python.org/3/library/abc.html
from abc import ABC, abstractmethod
from typing import Dict, Any
from pathlib import Path

class SegmentationMethod(ABC):
    """Base class for all segmentation methods."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable method name."""
        ...

    @property
    @abstractmethod
    def version(self) -> str:
        """Method version string."""
        ...

    @abstractmethod
    def analyze(self, video_path: Path) -> "MethodResult":
        """Run segmentation analysis on video.

        Args:
            video_path: Path to input video file

        Returns:
            MethodResult containing segments and FSM timeline
        """
        ...

    @abstractmethod
    def get_config_spec(self) -> "ConfigSpec":
        """Return parameter definitions for this method."""
        ...

    def get_viz_hooks(self) -> Dict[str, Any]:
        """Optional: Return intermediate data for visualization.

        Default implementation returns empty dict.
        Subclasses can override to expose method-specific data.
        """
        return {}
```

### Pattern 2: Validated Dataclass with __post_init__
**What:** Dataclass that validates FSM state timeline completeness on construction.
**When to use:** When result data has invariants that must always hold.
**Example:**
```python
# Source: https://docs.python.org/3/library/dataclasses.html
from dataclasses import dataclass, field
from typing import List, Tuple
from enum import StrEnum, auto

class BaseState(StrEnum):
    """Minimum required states for all methods."""
    ACTIVE = auto()    # 'active'
    INACTIVE = auto()  # 'inactive'

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
        if not self.fsm_timeline:
            raise ValueError("FSM timeline cannot be empty")

        # Check timeline is sorted
        timestamps = [t for t, _ in self.fsm_timeline]
        if timestamps != sorted(timestamps):
            raise ValueError("FSM timeline must be sorted by timestamp")

        # Check timeline covers video
        first_ts = self.fsm_timeline[0][0]
        last_ts = self.fsm_timeline[-1][0]

        if first_ts > 0.1:  # Allow small tolerance
            raise ValueError(f"FSM timeline must start near 0, got {first_ts}")

        if last_ts < self.video_duration - 0.1:
            raise ValueError(
                f"FSM timeline must cover full video duration "
                f"({self.video_duration}s), last entry at {last_ts}s"
            )

        # Validate state names include required states
        states = {s for _, s in self.fsm_timeline}
        required = {BaseState.ACTIVE.value, BaseState.INACTIVE.value}
        if not required.issubset(states):
            missing = required - states
            raise ValueError(f"FSM timeline missing required states: {missing}")
```

### Pattern 3: Decorator Registry with Explicit Import
**What:** Global registry populated by `@register_method` decorator, with methods discovered via explicit imports.
**When to use:** When you have a known set of methods in a single repository.
**Example:**
```python
# Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-python-decorators-part-i-function-registration
from typing import Dict, Type

_METHOD_REGISTRY: Dict[str, Type["SegmentationMethod"]] = {}

def register_method(cls: Type["SegmentationMethod"]) -> Type["SegmentationMethod"]:
    """Decorator to register a segmentation method.

    Usage:
        @register_method
        class MyMethod(SegmentationMethod):
            ...
    """
    # Instantiate to get name (requires no-arg constructor or use class attr)
    instance = cls()
    name = instance.name

    if name in _METHOD_REGISTRY:
        raise ValueError(f"Method '{name}' already registered")

    _METHOD_REGISTRY[name] = cls
    return cls

def get_registered_methods() -> Dict[str, Type["SegmentationMethod"]]:
    """Return all registered method classes."""
    return dict(_METHOD_REGISTRY)

def get_method(name: str) -> Type["SegmentationMethod"]:
    """Get a specific method class by name."""
    if name not in _METHOD_REGISTRY:
        raise KeyError(f"Unknown method: {name}. Available: {list(_METHOD_REGISTRY.keys())}")
    return _METHOD_REGISTRY[name]
```

### Pattern 4: ConfigSpec for Parameter Definitions
**What:** Dataclass defining tunable parameters with metadata for UI generation.
**When to use:** When methods have different parameters that need unified presentation.
**Example:**
```python
from dataclasses import dataclass, field
from typing import Any, List, Optional
from enum import StrEnum, auto

class ParamType(StrEnum):
    """Supported parameter types."""
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
        """Validate and fill in defaults for a config dict."""
        result = self.to_defaults()
        for key, value in config.items():
            if key not in result:
                raise ValueError(f"Unknown parameter: {key}")
            result[key] = value
        return result
```

### Anti-Patterns to Avoid
- **Over-engineering the registry:** Don't use entry_points or complex plugin discovery for a single-repo project with known methods.
- **Mutable default arguments:** Always use `field(default_factory=list)` for list/dict fields in dataclasses.
- **NotImplementedError instead of ABC:** ABC catches missing implementations at instantiation, not runtime.
- **String states without enum:** Raw strings lead to typos; StrEnum catches errors at definition time.
- **Validation in __init__:** Use `__post_init__` to validate after all fields are set.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Abstract interfaces | Manual NotImplementedError checks | `abc.ABC` + `@abstractmethod` | ABC validates at instantiation, not runtime |
| Structured results | Plain dicts or tuples | `@dataclass` | Type hints, repr, equality, immutability options |
| State enumerations | String constants | `StrEnum` | Catches typos, IDE autocomplete, backwards compatible with strings |
| Timeline validation | External validator function | `__post_init__` | Called automatically, cannot be bypassed |
| Registry singleton | Global dict with manual management | Module-level dict + decorator | Clean API, automatic registration |

**Key insight:** Python's standard library has mature solutions for all these patterns. The complexity should be in the method implementations, not the framework infrastructure.

## Common Pitfalls

### Pitfall 1: Import Order Dependencies
**What goes wrong:** Decorators only run when modules are imported. Methods aren't registered if their modules aren't imported.
**Why it happens:** Python only executes module code on import, not at program start.
**How to avoid:** Create an explicit `methods/__init__.py` that imports all method modules:
```python
# src/methods/__init__.py
from . import stub  # Forces stub/method.py to load and register
from . import av_funnel  # (Phase 3)

# Alternative: dynamic discovery
import importlib
import pkgutil

def _discover_methods():
    """Import all submodules to trigger registration."""
    package = __name__
    for finder, name, ispkg in pkgutil.iter_modules(__path__):
        importlib.import_module(f"{package}.{name}")

_discover_methods()
```
**Warning signs:** `get_registered_methods()` returns empty dict, or methods appear inconsistently.

### Pitfall 2: FSM Timeline Gaps
**What goes wrong:** FSM timeline has gaps where no state is defined, making visualization incomplete.
**Why it happens:** Methods emit state transitions but don't ensure coverage of full duration.
**How to avoid:** Require explicit states at t=0 and t=video_duration in MethodResult validation.
**Warning signs:** Visualization shows undefined regions, evaluation metrics are undefined for time ranges.

### Pitfall 3: Mutable Default Arguments
**What goes wrong:** All instances share the same list/dict object, leading to spooky action at a distance.
**Why it happens:** Default arguments are evaluated once at function definition.
**How to avoid:** Always use `field(default_factory=list)` for mutable defaults.
**Warning signs:** Modifying one result's intermediate_data affects other results.

### Pitfall 4: Mixing Class and Instance State in Registry
**What goes wrong:** Registry stores instances when it should store classes, or vice versa.
**Why it happens:** Unclear whether methods are singletons or instantiated per-use.
**How to avoid:** Registry stores classes; callers instantiate when needed. Document this clearly.
**Warning signs:** Unexpected state sharing between test runs, or "method already instantiated" errors.

### Pitfall 5: Inconsistent Path Handling
**What goes wrong:** Methods fail on Windows paths, or when called with str vs Path objects.
**Why it happens:** Mixing `str` and `pathlib.Path` without normalization.
**How to avoid:** Accept both str and Path in interface, convert to Path internally:
```python
def analyze(self, video_path: Path | str) -> MethodResult:
    video_path = Path(video_path)  # Normalize immediately
    ...
```
**Warning signs:** FileNotFoundError on valid paths, path joining issues.

## Code Examples

Verified patterns from official sources:

### Complete Stub Method Implementation
```python
# src/methods/stub/method.py
from pathlib import Path
from src.framework.method_base import SegmentationMethod
from src.framework.result import MethodResult, ConfigSpec, ParamDef, ParamType, BaseState
from src.framework.registry import register_method

@register_method
class StubMethod(SegmentationMethod):
    """Stub method that returns fixed segments for testing framework."""

    @property
    def name(self) -> str:
        return "stub"

    @property
    def version(self) -> str:
        return "1.0.0"

    def analyze(self, video_path: Path | str) -> MethodResult:
        video_path = Path(video_path)

        # Stub: assume 60s video, return fixed segments
        video_duration = 60.0
        segments = [(5.0, 10.0), (20.0, 25.0), (40.0, 45.0)]

        # FSM timeline: inactive except during segments
        fsm_timeline = [(0.0, BaseState.INACTIVE.value)]
        for start, end in segments:
            fsm_timeline.append((start, BaseState.ACTIVE.value))
            fsm_timeline.append((end, BaseState.INACTIVE.value))
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
```

### Framework Public API
```python
# src/framework/__init__.py
"""
Framework for multi-method video segmentation comparison.

Usage:
    from src.framework import SegmentationMethod, MethodResult, register_method
    from src.methods import *  # Import to trigger registration
    from src.framework import get_registered_methods

    methods = get_registered_methods()
    for name, cls in methods.items():
        method = cls()
        result = method.analyze("video.mp4")
"""

from .method_base import SegmentationMethod
from .result import MethodResult, ConfigSpec, ParamDef, ParamType, BaseState
from .registry import register_method, get_registered_methods, get_method

__all__ = [
    "SegmentationMethod",
    "MethodResult",
    "ConfigSpec",
    "ParamDef",
    "ParamType",
    "BaseState",
    "register_method",
    "get_registered_methods",
    "get_method",
]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@abstractproperty` | `@property` + `@abstractmethod` | Python 3.3 | Deprecated decorator removed |
| `abc.ABCMeta` metaclass | `abc.ABC` base class | Python 3.4 | Simpler inheritance syntax |
| String state constants | `StrEnum` | Python 3.11 | Type-safe, serializes as string |
| `typing.NamedTuple` for results | `@dataclass` with validation | Python 3.7+ | Mutable by default, `__post_init__` |
| Plugin entry_points | Decorator registry | Best practice for single-repo | Lower complexity, no packaging overhead |

**Deprecated/outdated:**
- `@abstractclassmethod`, `@abstractstaticmethod`, `@abstractproperty`: Use stacked decorators instead
- `collections.abc` for custom ABCs: Use `abc.ABC` directly
- `typing.NamedTuple` for mutable data: Use `@dataclass` with `frozen=False`

## Open Questions

Things that couldn't be fully resolved:

1. **Method instantiation model**
   - What we know: Registry should store classes, not instances
   - What's unclear: Should methods be instantiated once and reused, or per-analysis?
   - Recommendation: Instantiate per-analysis for now; allows stateless methods. Can optimize later if needed.

2. **FSM state extensibility**
   - What we know: `active` and `inactive` are required minimum states
   - What's unclear: How to handle method-specific states (e.g., `pre_hit`, `post_hit`)
   - Recommendation: Allow any string state in timeline, but validate that `active`/`inactive` are present. Method-specific states can coexist.

3. **Video duration discovery for stub**
   - What we know: StubMethod needs video duration for FSM timeline validation
   - What's unclear: Whether to require methods to actually probe video metadata
   - Recommendation: For stub, accept an optional `duration` parameter. Real methods will probe video.

## Sources

### Primary (HIGH confidence)
- [Python abc documentation](https://docs.python.org/3/library/abc.html) - ABC patterns, `@abstractmethod` stacking
- [Python dataclasses documentation](https://docs.python.org/3/library/dataclasses.html) - `__post_init__`, `field()`, validation patterns
- [Python enum documentation](https://docs.python.org/3/library/enum.html) - StrEnum usage, `auto()` behavior
- [Python Packaging Guide - Plugins](https://packaging.python.org/en/latest/guides/creating-and-discovering-plugins/) - Registry patterns comparison

### Secondary (MEDIUM confidence)
- [Miguel Grinberg - Decorator Registration](https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-python-decorators-part-i-function-registration) - Practical registry implementation
- [Real Python - ABC Guide](https://realpython.com/ref/glossary/abstract-base-class/) - ABC best practices

### Tertiary (LOW confidence)
- Web search results for dataclass validation patterns - Multiple community sources agreed on `__post_init__` approach

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All stdlib, mature APIs, official documentation verified
- Architecture: HIGH - Patterns derived from official docs and established libraries
- Pitfalls: MEDIUM - Mix of documented issues and community experience

**Research date:** 2026-01-20
**Valid until:** 2026-02-20 (30 days - stable APIs, no expected changes)
