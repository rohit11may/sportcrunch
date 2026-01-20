# Roadmap: v1.0 Multi-Method Framework

## Milestone Overview

**Goal:** Build pluggable framework for comparing tennis segment detection methods with standardized evaluation.

**Phases:** 5 phases, building infrastructure → evaluation → visualization → method integration

---

## Phase 1: Framework Foundation

**Goal:** Establish the core abstractions that all methods will implement.

**Requirements:** FRAME-01, FRAME-02, FRAME-03

**Plans:** 1 plan

Plans:
- [x] 01-01-PLAN.md — Core framework (ABC, dataclasses, registry, stub method)

**Status:** Complete (2026-01-20)

**Deliverables:**
- `SegmentationMethod` ABC with required interface
- `MethodResult` dataclass with FSM state timeline validation
- `ConfigSpec` for parameter definitions
- Method registry with `@register_method` decorator
- Stub method for testing framework

**Key Files:**
- `src/framework/method_base.py`
- `src/framework/registry.py`
- `src/framework/result.py`
- `src/methods/stub/method.py`

---

## Phase 2: Evaluation Infrastructure

**Goal:** Port iOS evaluation logic and build test harness.

**Requirements:** EVAL-01, EVAL-02, EVAL-03, FRAME-04

**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — Core evaluation components (evaluator, ground truth, video loader)
- [ ] 02-02-PLAN.md — Test harness and verification

**Deliverables:**
- `SegmentEvaluator` class (ported from Swift)
- `GroundTruthLoader` reading from iOS TestResources
- `VideoLoader` abstraction for shared video access
- `TestHarness` that runs all methods on all videos
- Metrics collection (precision, recall, F1, timing)

**Key Files:**
- `src/evaluation/evaluator.py`
- `src/evaluation/ground_truth.py`
- `src/evaluation/harness.py`
- `src/utils/video.py`

**Verification:** Run harness with stub method, confirm metrics calculated correctly.

---

## Phase 3: AV-Funnel Method Integration

**Goal:** Wrap existing pipeline as a framework-compatible method.

**Requirements:** METH-01

**Plans:** 1 plan

Plans:
- [ ] 03-01-PLAN.md — AudioOnsetMethod wrapper with FSM extraction and viz hooks

**Deliverables:**
- `AudioOnsetMethod` implementing `SegmentationMethod`
- FSM state extraction from pipeline stages
- `ConfigSpec` with all existing parameters
- Visualization hooks for intermediate data

**Key Files:**
- `src/methods/audio_onset/method.py`
- `src/methods/audio_onset/audio_analyzer.py`
- `src/methods/audio_onset/video_validator.py`
- `src/methods/audio_onset/pipeline.py`

**Verification:** AV-Funnel runs through test harness on all 6 videos, produces valid results.

---

## Phase 4: Visualization Dashboard

**Goal:** Build unified comparison interface.

**Requirements:** VIZ-01, VIZ-02, VIZ-03

**Deliverables:**
- Metrics table component (sortable, filterable)
- FSM timeline component (reusable across methods)
- Side-by-side comparison view
- Method-specific viz rendering (AV-Funnel waveform, motion plots)
- Streamlit app refactored to use new components

**Key Files:**
- `src/visualization/metrics_table.py`
- `src/visualization/timeline.py`
- `src/visualization/method_viz.py`
- `app.py` (refactored)

**Verification:** Dashboard displays test harness results with interactive comparison.

---

## Phase 5: Polish & Persistence

**Goal:** Add results storage and refinements.

**Requirements:** EVAL-04

**Deliverables:**
- JSON export of harness results
- Historical results loading
- Run comparison (current vs previous)
- Documentation updates

**Key Files:**
- `src/evaluation/storage.py`
- `README.md` updates

**Verification:** Can save run, load previous run, compare metrics.

---

## Phase Summary

| Phase | Name | Requirements | Depends On |
|-------|------|--------------|------------|
| 1 | Framework Foundation | FRAME-01, FRAME-02, FRAME-03 | — |
| 2 | Evaluation Infrastructure | EVAL-01, EVAL-02, EVAL-03, FRAME-04 | Phase 1 |
| 3 | AV-Funnel Integration | METH-01 | Phase 2 |
| 4 | Visualization Dashboard | VIZ-01, VIZ-02, VIZ-03 | Phase 3 |
| 5 | Polish & Persistence | EVAL-04 | Phase 4 |

---

*Last updated: 2026-01-20*
