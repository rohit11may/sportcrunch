# Tennis Rally Detector

## What This Is

A research tool that compares multiple video segmentation methods for automatically extracting tennis rally highlights from match recordings. The system provides a pluggable architecture where different detection algorithms can be black-boxed, benchmarked against a common test suite, and visualized through method-specific intermediate processing steps.

## Core Value

Enable objective, quantitative comparison of rally detection methods through a unified testing framework with method-specific visualization pipelines.

## Current Milestone: v1.0 Multi-Method Framework

**Goal:** Build the architectural foundation for comparing multiple segmentation methods, starting with refactoring the existing AV-Funnel approach and preparing for the Streak-Context implementation.

**Target features:**
- Method abstraction layer that encapsulates different detection algorithms
- Common test harness that runs identical test videos through all methods
- Method-specific visualization pipelines for intermediate processing steps
- Shared FSM state timeline visualization (reusable across methods)
- Side-by-side result comparison interface
- Benchmarking metrics (precision, recall, processing speed, compression ratio)

## Requirements

### Validated

(None yet — new project milestone)

### Active

This milestone focuses on building the framework infrastructure:

**Architecture:**
- Abstract base class / interface for segmentation methods
- Method registry system for plugging in new algorithms
- Common video pipeline that feeds frames to methods
- Result data structure that captures segments + intermediate outputs

**Testing:**
- Test suite management (video catalog with ground truth annotations)
- Automated test runner that executes all registered methods
- Metrics calculation engine (precision, recall, F1, speed)
- Results storage and comparison tools

**Visualization:**
- Method-agnostic FSM state timeline component
- Per-method visualization hooks for intermediate steps
- Dashboard for displaying multiple methods' outputs side-by-side

**Method Integration:**
- Refactor existing AV-Funnel into the new architecture
- Document the method interface for future implementations

### Out of Scope

- **Streak-Context implementation** — Framework first, new method implementation comes in next phase
- **Real-time processing** — Benchmarking is offline analysis, optimization comes later
- **UI polish** — Functional dashboards for comparison, not production-ready interface
- **Mobile deployment** — Desktop/server processing for research phase
- **Multi-sport support** — Tennis-only for this milestone

## Context

**Existing codebase:**
The prototype has a working tennis detection system ("AV-Funnel method") that uses:
1. Audio analysis (bandpass filtering, spectral flux, adaptive thresholding)
2. Video validation (motion detection via frame differencing)
3. Temporal clustering (gap-merging for rally segmentation)
4. Streamlit visualization dashboard

**New direction:**
Research document (crackviz-v2-research.md) describes an alternative "Streak-Context method":
1. ROI generation via motion heatmaps
2. Ball detection via Probabilistic Hough Transform on motion blur streaks
3. Context validation via player activity heuristics (aspect ratio variance, centroid acceleration)
4. FSM-based temporal segmentation

**Challenge:**
The two methods use fundamentally different detection primitives and intermediate data structures. We need an architecture that allows both to coexist and be compared objectively without forcing them into an incompatible abstraction.

**Visualization requirements:**
- AV-Funnel: waveform + onset detection, timeline, motion scores
- Streak-Context: ROI heatmap, three-frame diff + Hough lines, player activity metrics, FSM states
- Common: FSM state timeline (should be reusable across methods)

## Constraints

- **Tech stack**: Python (existing codebase is Python-based)
- **Execution environment**: Desktop/server initially (mobile optimization deferred)
- **No external services**: All processing local, no cloud dependencies
- **Test data**: Requires creating/curating ground truth annotations for tennis videos
- **Processing**: Offline analysis, not real-time (speed benchmarks but not strict latency requirements)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Framework-first approach | Need stable architecture before implementing second method | — Pending |
| Method-specific visualizations | Different methods have different intermediate steps worth visualizing | — Pending |
| Shared FSM timeline | All temporal segmentation methods benefit from state visualization | — Pending |

---
*Last updated: 2026-01-19 after milestone initialization*
