---
phase: "01-framework-foundation"
plan: "01"
subsystem: "framework-core"
tags: ["abc", "dataclasses", "registry", "python", "architecture"]
requires: []
provides: ["method-abstraction", "result-validation", "method-registry"]
affects: ["02-evaluation-infrastructure", "03-av-funnel-integration"]
tech-stack:
  added: []
  patterns: ["ABC", "decorator-registry", "dataclass-validation"]
key-files:
  created:
    - "src/framework/__init__.py"
    - "src/framework/result.py"
    - "src/framework/method_base.py"
    - "src/framework/registry.py"
    - "src/methods/__init__.py"
    - "src/methods/stub/__init__.py"
    - "src/methods/stub/method.py"
  modified: []
decisions:
  - id: "FRAME-01"
    decision: "Use ABC with hybrid interface (black-box results + optional viz hooks)"
    rationale: "Allows methods with different architectures to coexist while providing comparable outputs"
    alternatives: ["Pure black-box", "Pure white-box"]
  - id: "FRAME-02"
    decision: "Require FSM state timeline in all method results"
    rationale: "Enables unified temporal visualization across all methods"
    alternatives: ["Optional FSM", "Metadata-based states"]
  - id: "FRAME-03"
    decision: "Decorator-based registry with explicit imports"
    rationale: "Simpler than entry_points for single-repo project, explicit control over method loading"
    alternatives: ["Entry points", "Dynamic discovery"]
metrics:
  duration: "137s"
  completed: "2026-01-20"
---

# Phase 1 Plan 1: Core Framework Summary

**One-liner:** Pluggable method abstraction with FSM validation and decorator registry using stdlib ABC + dataclasses.

## What Was Built

Created the foundational framework for multi-method video segmentation comparison. Established three core components:

1. **Result Dataclasses** (`result.py`):
   - `BaseState` enum for FSM states (ACTIVE, INACTIVE)
   - `ParamType` enum for method configuration
   - `ParamDef` and `ConfigSpec` for parameter definitions
   - `MethodResult` with `__post_init__` validation ensuring FSM timeline completeness

2. **Method Abstraction** (`method_base.py`):
   - `SegmentationMethod` ABC defining the interface all methods must implement
   - Required: `name`, `version`, `analyze()`, `get_config_spec()`
   - Optional: `get_viz_hooks()` for method-specific visualization data

3. **Method Registry** (`registry.py`):
   - `@register_method` decorator for automatic registration
   - `get_registered_methods()` and `get_method()` for discovery
   - Registry stores classes (not instances) for clean instantiation

4. **Stub Method** (`methods/stub/method.py`):
   - Reference implementation proving the interface works
   - Returns fixed segments for a hypothetical 60s video
   - Complete FSM timeline with proper validation

## Decisions Made

### FRAME-01: Hybrid Interface Pattern
**Decision:** Use ABC with both black-box outputs (MethodResult) and optional white-box hooks (get_viz_hooks).

**Context:** Different methods have fundamentally different internal steps. AV-Funnel uses audio waveforms and motion scores. Future Streak-Context method will use ROI heatmaps and Hough lines.

**Outcome:** Methods must produce comparable MethodResult, but can expose method-specific intermediate data for visualization without forcing incompatible abstractions.

### FRAME-02: Mandatory FSM Timeline
**Decision:** All methods must output complete FSM state timelines covering [0, video_duration].

**Context:** Temporal state visualization is valuable across all segmentation methods. Need common ground for comparison.

**Outcome:** `MethodResult.__post_init__` validates timeline completeness, sorting, coverage, and presence of required states (active/inactive). Methods can add custom states beyond the base set.

### FRAME-03: Decorator Registry with Explicit Imports
**Decision:** Use `@register_method` decorator with explicit imports in `methods/__init__.py`.

**Context:** Considered entry_points (too heavy for single-repo) vs dynamic discovery (harder to debug) vs explicit imports.

**Outcome:** Simple, debuggable registration. Adding a new method requires: 1) implement SegmentationMethod, 2) add @register_method decorator, 3) import in methods/__init__.py.

## Architecture Notes

### FSM Timeline Validation Rules
- Timeline cannot be empty
- Must be sorted by timestamp
- Must start within 0.1s of 0.0
- Must end within 0.1s of video_duration
- Must contain both "active" and "inactive" states
- Can contain additional method-specific states

### Method Instantiation Model
Registry stores classes, not instances. Callers instantiate when needed:
```python
StubClass = get_method('stub')
stub = StubClass()
result = stub.analyze('video.mp4')
```

This allows stateless methods and avoids singleton complications.

### Path Handling
Methods accept both `Path` and `str` for video_path, converting to Path internally for consistent handling.

## Testing Results

**Framework Verification:**
- FRAME-01 (Method abstraction): PASS - StubMethod instantiates and produces MethodResult
- FRAME-02 (FSM state output): PASS - Timeline validation enforces completeness
- FRAME-03 (Method registry): PASS - StubMethod discovered via decorator registration

**All 3 acceptance criteria verified.**

## Deviations from Plan

None - plan executed exactly as written.

## File Manifest

**Created (7 files):**
- `src/framework/__init__.py` - Public API exports
- `src/framework/result.py` - Result dataclasses and validation
- `src/framework/method_base.py` - SegmentationMethod ABC
- `src/framework/registry.py` - Registration and discovery
- `src/methods/__init__.py` - Method imports for registration
- `src/methods/stub/__init__.py` - Stub subpackage
- `src/methods/stub/method.py` - StubMethod implementation

**Modified:** None

## Commits

| Hash | Message |
|------|---------|
| d74e002 | feat(01-01): create stub method and framework exports |
| d1cf220 | feat(01-01): create ABC and registry |
| 3222b96 | feat(01-01): create result dataclasses and enums |

## Next Phase Readiness

**Phase 2 can proceed immediately.** Framework provides:
- Stable interface for method implementations
- Result structure for evaluation metrics
- Registry for test harness to discover methods

**Blockers:** None

**Concerns:** None

**Recommendations for Phase 2:**
- Use `MethodResult.segments` for precision/recall calculation
- Use `MethodResult.fsm_timeline` for state-based visualization
- Use `MethodResult.processing_time` for speed benchmarking
- Consider extracting video metadata (duration, fps) into shared utility for real methods

## Integration Points

**For Phase 2 (Evaluation):**
- Import `MethodResult` for metrics calculation
- Use `get_registered_methods()` to iterate over all methods in test harness
- Parse `fsm_timeline` for state-based evaluation metrics

**For Phase 3 (AV-Funnel):**
- Implement `SegmentationMethod` interface
- Use `@register_method` decorator
- Map pipeline stages to FSM states
- Expose existing parameters via `ConfigSpec`

**For Phase 4 (Visualization):**
- Use `get_viz_hooks()` to render method-specific intermediate data
- Parse `fsm_timeline` for common timeline component
- Display `ConfigSpec` params for UI generation

## Technical Debt

None. All code uses stdlib, follows Python best practices, has clear interfaces.

## Performance Notes

- StubMethod processing time: 0.001s (not meaningful, no actual processing)
- Registry lookup: O(1) dictionary access
- MethodResult validation: O(n) where n = timeline length (runs once at construction)

No performance concerns for framework infrastructure.

---

*Completed: 2026-01-20*
*Duration: 137 seconds*
*Commits: 3*
