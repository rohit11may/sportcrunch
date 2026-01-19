# Architecture Research

**Domain:** Multi-Method Comparison Framework for Tennis Segmentation
**Researched:** 2026-01-19
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Execution Layer (Streamlit)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Method 1 UI  │  │ Method 2 UI  │  │ Method 3 UI  │  │ Comparison   │    │
│  │ (Audio-Only) │  │ (Hybrid)     │  │ (Future)     │  │ Dashboard    │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │                 │             │
├─────────┴─────────────────┴─────────────────┴─────────────────┴─────────────┤
│                         Method Registry & Orchestration                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    SegmentationMethod (ABC)                          │    │
│  │  - analyze() → MethodResult                                          │    │
│  │  - get_config_spec() → ConfigSpec                                    │    │
│  │  - get_viz_hooks() → VisualizationHooks                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│         ▲                    ▲                    ▲                          │
│         │                    │                    │                          │
│  ┌──────┴───────┐  ┌─────────┴────────┐  ┌───────┴──────────┐              │
│  │ Audio Method │  │ Hybrid Method    │  │ Future Method    │              │
│  │ (existing)   │  │ (to be added)    │  │ (extensible)     │              │
│  └──────────────┘  └──────────────────┘  └──────────────────┘              │
├─────────────────────────────────────────────────────────────────────────────┤
│                         Shared Test Infrastructure                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Test Harness │  │ Result       │  │ Metrics      │  │ Ground Truth │    │
│  │              │  │ Aggregator   │  │ Calculator   │  │ Manager      │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
├─────────────────────────────────────────────────────────────────────────────┤
│                         Data & Utilities Layer                              │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐                   │
│  │ Video Loader  │  │ Audio Extract │  │ Visualization │                   │
│  │ (shared CV)   │  │ (shared util) │  │ Factory       │                   │
│  └───────────────┘  └───────────────┘  └───────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **SegmentationMethod** | ABC defining method interface, config spec, and viz hooks | Abstract base class with @abstractmethod decorators |
| **Method Registry** | Discovers and manages registered methods | Decorator-based registry pattern with auto-discovery |
| **Test Harness** | Feeds test videos to all methods, collects results | Iterator over test cases, parallel execution support |
| **Result Aggregator** | Normalizes method outputs to common format | Dataclass-based result container with validation |
| **Metrics Calculator** | Computes comparison metrics (precision, recall, IoU) | Pure functions operating on standardized results |
| **Visualization Factory** | Creates method-specific and comparison visualizations | Strategy pattern with method-provided hooks |
| **Ground Truth Manager** | Loads and manages manually-labeled test data | JSON/CSV loader with interval validation |

## Recommended Project Structure

```
src/
├── framework/              # Core framework (method-agnostic)
│   ├── method_base.py      # SegmentationMethod ABC
│   ├── registry.py         # Method registration and discovery
│   ├── result.py           # MethodResult, SegmentInterval dataclasses
│   ├── test_harness.py     # TestHarness, TestCase classes
│   └── metrics.py          # Metric calculation functions
├── methods/                # Method implementations (pluggable)
│   ├── __init__.py         # Auto-discovers and registers all methods
│   ├── audio_onset/        # Existing audio-only method
│   │   ├── method.py       # AudioOnsetMethod(SegmentationMethod)
│   │   ├── analyzer.py     # Refactored TennisAudioAnalyzer
│   │   └── viz.py          # Waveform/onset visualization hooks
│   ├── hybrid/             # Future hybrid method
│   │   ├── method.py       # HybridMethod(SegmentationMethod)
│   │   └── ...
│   └── template/           # Template for new methods
│       └── method.py       # Copy-paste starter
├── visualization/          # Shared visualization components
│   ├── factory.py          # VisualizationFactory
│   ├── comparison.py       # Multi-method comparison plots
│   └── timeline.py         # Interval timeline visualizations
├── utils/                  # Shared utilities
│   ├── video.py            # VideoLoader, frame extraction
│   ├── audio.py            # AudioExtractor
│   └── intervals.py        # Interval merging, IoU calculation
├── app.py                  # Streamlit entry point
└── config/
    └── settings.py         # Global settings
```

### Structure Rationale

- **framework/:** Method-agnostic core. Changes here only when adding new framework capabilities (new metric types, etc.)
- **methods/:** Each method is self-contained. Adding a new method = add new folder, implement ABC, done. No changes to framework.
- **visualization/:** Separated because viz can get complex. Methods provide hooks; factory orchestrates rendering.
- **utils/:** Shared code that multiple methods need (video loading, audio extraction, interval math). Prevents duplication.

## Architectural Patterns

### Pattern 1: Abstract Base Class + Registry

**What:** Define common interface via ABC, use decorator to auto-register implementations

**When to use:** When you have multiple implementations of the same concept that need to be discovered and instantiated dynamically

**Trade-offs:**
- ✅ **Pro:** New methods require zero framework changes
- ✅ **Pro:** Clear contract enforced at import time
- ✅ **Pro:** Easy to list available methods programmatically
- ❌ **Con:** Slightly more boilerplate than duck typing
- ❌ **Con:** Python ABC errors can be cryptic

**Example:**
```python
# framework/method_base.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Dict, Any

@dataclass
class MethodResult:
    """Standardized result format for all methods."""
    method_name: str
    intervals: List[Tuple[float, float]]  # (start, end) in seconds
    confidence_scores: List[float]         # Per-interval confidence
    metadata: Dict[str, Any]               # Method-specific debug info
    processing_time: float

class SegmentationMethod(ABC):
    """Base class for all segmentation methods."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable method name."""
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """Brief description of approach."""
        pass

    @abstractmethod
    def analyze(self, video_path: str, **kwargs) -> MethodResult:
        """
        Analyze video and return segmentation intervals.

        Args:
            video_path: Path to video file
            **kwargs: Method-specific parameters

        Returns:
            MethodResult with intervals and metadata
        """
        pass

    @abstractmethod
    def get_config_spec(self) -> Dict[str, Any]:
        """
        Return parameter specification for UI generation.

        Returns:
            Dict mapping param name to spec (type, range, default, help)
        """
        pass

    def get_viz_hooks(self) -> Dict[str, callable]:
        """
        Optional: provide method-specific visualization hooks.

        Returns:
            Dict mapping viz name to rendering function
        """
        return {}

# framework/registry.py
_METHODS = {}

def register_method(cls):
    """Decorator to auto-register method implementations."""
    _METHODS[cls.__name__] = cls
    return cls

def get_method(name: str) -> SegmentationMethod:
    """Retrieve method instance by name."""
    if name not in _METHODS:
        raise ValueError(f"Unknown method: {name}")
    return _METHODS[name]()

def list_methods() -> List[str]:
    """List all registered method names."""
    return list(_METHODS.keys())

# methods/audio_onset/method.py
from framework.method_base import SegmentationMethod, MethodResult
from framework.registry import register_method

@register_method
class AudioOnsetMethod(SegmentationMethod):
    """Detects rallies using audio onset detection."""

    @property
    def name(self) -> str:
        return "Audio Onset Detection"

    @property
    def description(self) -> str:
        return "Detects tennis hits via spectral flux in audio signal"

    def analyze(self, video_path: str, **kwargs) -> MethodResult:
        # Use existing TennisAudioAnalyzer
        from .analyzer import TennisAudioAnalyzer

        analyzer = TennisAudioAnalyzer(**kwargs)
        result = analyzer.analyze(video_path)

        return MethodResult(
            method_name=self.name,
            intervals=result.rally_intervals,
            confidence_scores=[1.0] * len(result.rally_intervals),
            metadata={
                "peak_times": result.peak_times,
                "onset_strength": result.onset_strength,
            },
            processing_time=result.processing_time,
        )

    def get_config_spec(self) -> Dict[str, Any]:
        return {
            "onset_threshold_lambda": {
                "type": "float",
                "range": (0.5, 5.0),
                "default": 2.0,
                "help": "Detection sensitivity (higher = stricter)",
            },
            "cluster_max_gap_sec": {
                "type": "float",
                "range": (0.1, 10.0),
                "default": 3.0,
                "help": "Max gap between hits in same rally",
            },
            # ... more params
        }

    def get_viz_hooks(self) -> Dict[str, callable]:
        from .viz import create_waveform_plot, create_onset_plot
        return {
            "waveform": create_waveform_plot,
            "onset_strength": create_onset_plot,
        }
```

### Pattern 2: Strategy Pattern for Visualization

**What:** Methods provide visualization strategies; factory combines them into UI

**When to use:** When different implementations need different visualizations but share common rendering infrastructure

**Trade-offs:**
- ✅ **Pro:** Methods control their own debug visualizations
- ✅ **Pro:** Comparison dashboard can be standardized
- ✅ **Pro:** Easy to add new viz types without touching methods
- ❌ **Con:** Need to coordinate shared visualization types (timelines, etc.)

**Example:**
```python
# visualization/factory.py
def create_method_viz_tabs(method: SegmentationMethod, result: MethodResult):
    """Create Streamlit tabs for method-specific visualizations."""
    hooks = method.get_viz_hooks()

    if not hooks:
        st.info("No method-specific visualizations available")
        return

    tabs = st.tabs(list(hooks.keys()))
    for tab, (name, hook) in zip(tabs, hooks.items()):
        with tab:
            # Each hook renders its own visualization
            hook(result.metadata)

def create_comparison_timeline(results: List[MethodResult]):
    """Create unified timeline showing all methods' results."""
    fig = go.Figure()

    for i, result in enumerate(results):
        for start, end in result.intervals:
            fig.add_trace(go.Bar(
                x=[end - start],
                y=[result.method_name],
                base=start,
                orientation='h',
                name=f"{result.method_name} segment",
            ))

    st.plotly_chart(fig)
```

### Pattern 3: Template Method for Test Harness

**What:** Fixed pipeline structure with hooks for method-specific execution

**When to use:** When you have a fixed testing workflow but variable implementations

**Trade-offs:**
- ✅ **Pro:** Consistent test execution across all methods
- ✅ **Pro:** Easy to add new test types (different videos, ground truth sets)
- ✅ **Pro:** Parallel execution is transparent to methods
- ❌ **Con:** Methods must conform to interface strictly

**Example:**
```python
# framework/test_harness.py
from dataclasses import dataclass
from typing import List, Dict
import time

@dataclass
class TestCase:
    """Single test video with ground truth."""
    video_path: str
    ground_truth_intervals: List[Tuple[float, float]]
    metadata: Dict[str, Any]  # e.g., video type, difficulty

class TestHarness:
    """Runs methods on test cases and collects results."""

    def __init__(self, test_cases: List[TestCase]):
        self.test_cases = test_cases

    def run_method(
        self,
        method: SegmentationMethod,
        params: Dict[str, Any],
        progress_callback=None,
    ) -> List[MethodResult]:
        """Run method on all test cases."""
        results = []

        for i, test_case in enumerate(self.test_cases):
            if progress_callback:
                progress_callback(i + 1, len(self.test_cases))

            # Execute method
            result = method.analyze(test_case.video_path, **params)

            # Attach ground truth for metric calculation
            result.ground_truth = test_case.ground_truth_intervals

            results.append(result)

        return results

    def compare_methods(
        self,
        methods: List[SegmentationMethod],
        params_per_method: Dict[str, Dict[str, Any]],
    ) -> Dict[str, List[MethodResult]]:
        """Run multiple methods on same test cases."""
        all_results = {}

        for method in methods:
            params = params_per_method.get(method.name, {})
            all_results[method.name] = self.run_method(method, params)

        return all_results
```

## Data Flow

### Single Method Analysis Flow

```
User selects method + params in UI
    ↓
app.py creates method instance
    ↓
method.analyze(video_path, **params)
    ↓
Method-specific processing (audio/video/hybrid)
    ↓
Returns MethodResult (standardized intervals)
    ↓
Visualization Factory renders results
    ├── Timeline (common across methods)
    ├── Metrics table (common)
    └── Method-specific plots (via viz hooks)
```

### Comparison Flow

```
User selects multiple methods + test set
    ↓
TestHarness.compare_methods(methods, params)
    ↓
For each method:
    ├── For each test video:
    │   ├── method.analyze(video_path)
    │   └── Calculate metrics vs ground truth
    └── Aggregate results
    ↓
Result Aggregator normalizes outputs
    ↓
Metrics Calculator computes comparison metrics
    ├── Per-video: Precision, Recall, F1, IoU
    └── Aggregate: Mean, Std, Distribution
    ↓
Comparison Dashboard renders
    ├── Side-by-side timelines
    ├── Metric comparison tables
    ├── Statistical significance tests
    └── Method-specific debug views
```

### Key Data Flows

1. **Method Registration Flow:** On import, `methods/__init__.py` triggers discovery → each method's `@register_method` decorator adds it to registry → `list_methods()` returns all available methods

2. **Configuration Flow:** UI calls `method.get_config_spec()` → Streamlit auto-generates controls → user adjusts params → params passed to `method.analyze(**params)`

3. **Visualization Flow:** Method returns `MethodResult` with metadata → Visualization Factory checks `method.get_viz_hooks()` → renders common plots + method-specific plots → user sees unified dashboard

## Integration with Existing Codebase

### Migration Path (Backward Compatible)

```
Phase 1: Extract Interface (No Breaking Changes)
├── Create framework/method_base.py (new)
├── Create framework/result.py (new)
└── Existing code unchanged, still works

Phase 2: Wrap Existing Pipeline
├── Create methods/audio_onset/method.py (new)
│   └── Wraps existing TennisAudioAnalyzer
├── Move src/audio_analyzer.py → methods/audio_onset/analyzer.py
└── app.py can use EITHER old pipeline OR new framework

Phase 3: Migrate Streamlit UI
├── Refactor app.py to use framework registry
├── Auto-generate controls from config_spec
└── Old UI stays as fallback until migration complete

Phase 4: Add Second Method
├── Create methods/hybrid/ (new)
└── No changes to framework or existing method
```

### Existing Code Mapping

| Current Component | New Location | Refactoring Required |
|-------------------|--------------|----------------------|
| `TennisCropper` | `methods/audio_onset/method.py` | Wrap in SegmentationMethod ABC |
| `TennisAudioAnalyzer` | `methods/audio_onset/analyzer.py` | Minimal (just move) |
| `VideoMotionValidator` | `methods/audio_onset/validator.py` | Minimal (just move) |
| `PipelineResult` | `framework/result.py` → `MethodResult` | Rename fields, add confidence scores |
| `ClipEditor` | `utils/video.py` | Move to shared utils |
| Streamlit UI | `app.py` | Refactor to use registry + factory |

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-3 methods | Current architecture is perfect. Single-machine, no distribution needed. |
| 3-10 methods | Add parallel execution in TestHarness (use `multiprocessing` or `concurrent.futures`). Pre-cache video decoding to avoid redundant I/O. |
| 10+ methods or large test sets | Consider distributed execution (Ray, Dask). Persist results to database instead of in-memory. Add result caching layer. |

### Scaling Priorities

1. **First bottleneck:** Video I/O becomes redundant when testing multiple methods on same videos
   - **Fix:** Pre-load videos into shared memory, pass video data (not path) to methods
   - **Alternative:** Cache extracted audio/frames to disk, methods load from cache

2. **Second bottleneck:** UI becomes cluttered with too many methods/visualizations
   - **Fix:** Paginate results, collapsible sections, separate "overview" vs "debug" modes
   - **Alternative:** Generate static HTML reports, keep UI for interactive tuning only

## Anti-Patterns

### Anti-Pattern 1: Method Coupling via Shared State

**What people do:** Methods access shared global state or modify each other's results

**Why it's wrong:**
- Breaks isolation — can't test methods independently
- Order-dependent bugs (Method B depends on Method A running first)
- Impossible to parallelize

**Do this instead:**
- Each method is stateless and independent
- All inputs passed via `analyze()` arguments
- All outputs returned via `MethodResult`
- TestHarness orchestrates dependencies, not methods themselves

### Anti-Pattern 2: Premature Abstraction of Visualizations

**What people do:** Try to make every visualization type pluggable from day one

**Why it's wrong:**
- Over-engineering before you know what viz patterns emerge
- Forces methods to conform to abstractions that may not fit
- Hard to add truly custom visualizations

**Do this instead:**
- Start with method-specific viz hooks (dict of callables)
- Extract common patterns AFTER you have 2-3 methods implemented
- Allow methods to return raw data; let viz factory decide rendering
- It's OK to have method-specific viz code that doesn't fit the framework

### Anti-Pattern 3: Tight Coupling to Streamlit

**What people do:** Methods import Streamlit and render directly in `analyze()`

**Why it's wrong:**
- Methods can't be tested without Streamlit
- Can't use methods in CLI, notebooks, or batch scripts
- Impossible to swap UI framework later

**Do this instead:**
- Methods return data (MethodResult), never render
- Visualization layer (separate from methods) handles rendering
- Use progress callbacks (not `st.progress()`) for status updates
- Methods should work in plain Python REPL

### Anti-Pattern 4: Inconsistent Result Formats

**What people do:** Each method returns different data structures (dict, list, custom class)

**Why it's wrong:**
- Comparison code needs special cases for each method
- Metrics calculator must handle N different formats
- Hard to add new comparison dimensions

**Do this instead:**
- Enforce `MethodResult` dataclass for all methods (via ABC)
- Standardize interval format: `List[Tuple[float, float]]`
- Use `metadata` dict for method-specific extras
- Validate result format at method return (fail fast)

## Extension Points

### Adding a New Method (Step-by-Step)

1. **Create method folder:** `src/methods/my_method/`
2. **Implement ABC:** Create `method.py` with class inheriting `SegmentationMethod`
3. **Register:** Add `@register_method` decorator
4. **Implement required methods:**
   - `name`, `description` properties
   - `analyze()` — main logic
   - `get_config_spec()` — parameter definitions
5. **Optional: Add visualizations:** Implement `get_viz_hooks()`
6. **Import in `methods/__init__.py`:** Add `from .my_method.method import *`
7. **Done!** Method now appears in UI automatically

### Adding a New Metric

1. **Define metric function:** In `framework/metrics.py`
```python
def compute_temporal_iou(
    predicted: List[Tuple[float, float]],
    ground_truth: List[Tuple[float, float]]
) -> float:
    """Compute intersection-over-union for temporal intervals."""
    # Implementation
```

2. **Register in metrics registry:** (if using dynamic metric discovery)
3. **Update comparison dashboard:** Add metric to table/plots

### Adding a New Visualization Type

1. **Create rendering function:** In `visualization/`
2. **Add to factory:** Register in `VisualizationFactory`
3. **Methods can opt-in:** Return hook in `get_viz_hooks()`

## Build Order (Dependency Graph)

**Phase 1: Foundation (no dependencies)**
```
1. framework/result.py        # MethodResult dataclass
2. framework/method_base.py   # SegmentationMethod ABC
3. framework/registry.py      # Registration decorator
```

**Phase 2: Shared Utilities (depends on Phase 1)**
```
4. utils/intervals.py         # Interval math (merge, IoU)
5. utils/video.py             # VideoLoader
6. utils/audio.py             # AudioExtractor
7. framework/metrics.py       # Metric calculation (depends on utils)
```

**Phase 3: First Method (depends on Phase 1-2)**
```
8. methods/audio_onset/analyzer.py    # Refactored from existing
9. methods/audio_onset/method.py      # Wraps analyzer in ABC
10. methods/audio_onset/viz.py        # Existing viz code
```

**Phase 4: Test Infrastructure (depends on Phase 1-3)**
```
11. framework/test_harness.py         # TestHarness class
12. tests/ground_truth/               # Sample test videos + labels
```

**Phase 5: Visualization Framework (depends on all above)**
```
13. visualization/factory.py          # VisualizationFactory
14. visualization/comparison.py       # Multi-method comparison plots
15. visualization/timeline.py         # Interval timeline plots
```

**Phase 6: UI Refactor (depends on all above)**
```
16. app.py                            # Refactored Streamlit app
```

**Critical Path:** 1 → 2 → 3 → 9 → 16 (can have working single-method UI)

**Parallel Work:** Phases 2, 4, 5 can be developed concurrently after Phase 1

## Sources

**Plugin Architecture & Registry Pattern:**
- [Python Packaging Guide - Creating and discovering plugins](https://packaging.python.org/en/latest/guides/creating-and-discovering-plugins/)
- [Building a plugin architecture with Python (Medium)](https://mwax911.medium.com/building-a-plugin-architecture-with-python-7b4ab39ad4fc)
- [Python Registry Pattern (GitHub)](https://github.com/SughoshKulkarni/Python-Registry)
- [Dynamically Loading Models: Model Registry Patterns](https://www.abhik.xyz/articles/registry-pattern)

**Abstract Base Classes:**
- [Python abc module documentation](https://docs.python.org/3/library/abc.html)
- [PEP 3119 – Introducing Abstract Base Classes](https://peps.python.org/pep-3119/)

**Benchmark & Comparison Frameworks:**
- [Performance Evaluation of AI Models (ITEA)](https://itea.org/journals/volume-46-1/ai-model-performance-benchmarking-harness/)
- [EleutherAI LM Evaluation Harness](https://github.com/EleutherAI/lm-evaluation-harness)
- [Understanding AI Benchmarks](https://blog.sshh.io/p/understanding-ai-benchmarks)

**Design Patterns:**
- [Strategy vs Template Method Pattern Comparison](https://www.codeproject.com/Articles/695871/Comparison-of-Template-and-Strategy-Design-Pattern)
- [Strategy Pattern in Python](https://www.giacomodebidda.com/posts/strategy-pattern-in-python/)

**Scientific Visualization:**
- [Extensible data-visualization substrate (BMC)](https://bdataanalytics.biomedcentral.com/articles/10.1186/s41044-019-0043-6)

---
*Architecture research for: Multi-Method Comparison Framework for Tennis Segmentation*
*Researched: 2026-01-19*
