# Project State

## Current Position

Phase: 2 of 5 (Evaluation Infrastructure)
Plan: 1 of 2 completed
Status: In progress
Last activity: 2026-01-20 — Completed 02-01-PLAN.md (Evaluation foundation)

Progress: [████████░░░░░░░░░░░░] 2/5 phases (40%)

## Accumulated Context

**Project Focus:**
Building a multi-method comparison framework for tennis segment detection algorithms (both shots and rallies). Starting with refactoring existing AV-Funnel method.

**Key Technical Decisions:**
- FSM state output is **required** for all methods
- Test videos read from `../app/SportCrunchTests/TestResources/` (single source of truth)
- Visualization rebuilt in unified framework (not preserving old Streamlit)
- Hybrid method abstraction (black-box + optional intermediate outputs)
- Method registry stores classes (not instances) - instantiate per-use
- FSM timeline validation: must cover [0, duration], sorted, contain active/inactive states
- Decorator-based registration with explicit imports (not entry_points or dynamic discovery)
- Virtual environment (venv/) for Python dependencies due to externally-managed system Python
- Path resolution to iOS resources: 4 levels up from module to sportcrunch root
- Ground truth segments convert to TimeRange via as_time_ranges() for evaluator compatibility

**Test Corpus:**
- 6 annotated tennis videos in iOS app's TestResources
- Ground truth format: JSON with `{videoFilename, sport, mode, segments: [{start, end}]}`
- Evaluation logic: IoU-based matching (ported from Swift `SegmentEvaluator`)

**Existing Codebase:**
- AV-Funnel: `src/audio_analyzer.py`, `video_validator.py`, `pipeline.py`, `video_editor.py`
- Streamlit dashboard: `app.py` (~920 lines, 12+ tunable parameters)
- Config: `config/settings.py`

## Session Continuity

Last session: 2026-01-20 13:08 UTC
Stopped at: Completed 02-01-PLAN.md
Resume file: None (plan complete)

---
*State tracking for: Tennis Rally Detector v1.0*
