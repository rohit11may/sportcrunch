# Project State

## Current Position

Phase: 1 (Framework Foundation)
Plan: Not yet created
Status: Ready to plan Phase 1
Last activity: 2026-01-20 — Requirements and roadmap defined

## Accumulated Context

**Project Focus:**
Building a multi-method comparison framework for tennis segment detection algorithms (both shots and rallies). Starting with refactoring existing AV-Funnel method.

**Key Technical Decisions:**
- FSM state output is **required** for all methods
- Test videos read from `../app/SportCrunchTests/TestResources/` (single source of truth)
- Visualization rebuilt in unified framework (not preserving old Streamlit)
- Hybrid method abstraction (black-box + optional intermediate outputs)

**Test Corpus:**
- 6 annotated tennis videos in iOS app's TestResources
- Ground truth format: JSON with `{videoFilename, sport, mode, segments: [{start, end}]}`
- Evaluation logic: IoU-based matching (ported from Swift `SegmentEvaluator`)

**Existing Codebase:**
- AV-Funnel: `src/audio_analyzer.py`, `video_validator.py`, `pipeline.py`, `video_editor.py`
- Streamlit dashboard: `app.py` (~920 lines, 12+ tunable parameters)
- Config: `config/settings.py`

---
*State tracking for: Tennis Rally Detector v1.0*
