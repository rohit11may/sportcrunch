# Codebase Structure

**Analysis Date:** 2026-01-18

## Directory Layout

```
prototype/
├── app.py                 # Streamlit dashboard (917 lines)
├── requirements.txt       # Python dependencies
├── README.md              # User documentation
├── TECHNICAL.md           # Algorithm deep-dive
├── config/
│   ├── __init__.py        # Empty
│   └── settings.py        # Default parameters
├── src/
│   ├── __init__.py        # Empty
│   ├── pipeline.py        # Main orchestrator (309 lines)
│   ├── audio_analyzer.py  # Hit detection (280 lines)
│   ├── video_validator.py # Motion validation (241 lines)
│   └── video_editor.py    # Clip extraction (213 lines)
├── prompts/               # Design prompts for iOS app
│   ├── iOS-App-Design-Prompt.md
│   └── Tennis Video Action Detection Algorithm.txt
├── out/                   # Output directory for exports
│   └── .gitkeep
└── .planning/             # GSD planning documents
    └── codebase/          # Architecture docs (this directory)
```

## Directory Purposes

**Root (`prototype/`):**
- Purpose: Project root containing entry point and documentation
- Contains: Main app, requirements, documentation files
- Key files: `app.py`, `requirements.txt`, `README.md`, `TECHNICAL.md`

**`config/`:**
- Purpose: Centralized configuration defaults
- Contains: Parameter constants and getter function
- Key files: `config/settings.py`

**`src/`:**
- Purpose: Core processing modules
- Contains: Pipeline, analyzers, validators, editors
- Key files: `pipeline.py`, `audio_analyzer.py`, `video_validator.py`, `video_editor.py`

**`prompts/`:**
- Purpose: Design documentation for future iOS app
- Contains: Prompt files, algorithm specifications
- Key files: `iOS-App-Design-Prompt.md`, `Tennis Video Action Detection Algorithm.txt`

**`out/`:**
- Purpose: Default output directory for exported highlight videos
- Contains: Generated video files (gitignored except .gitkeep)
- Generated: Yes
- Committed: Only .gitkeep

**`.planning/`:**
- Purpose: GSD planning and architecture documentation
- Contains: Codebase analysis documents
- Generated: By GSD commands
- Committed: Yes

## Key File Locations

**Entry Points:**
- `app.py`: Streamlit dashboard, run with `streamlit run app.py`
- `src/pipeline.py`: Programmatic API via `TennisCropper` class

**Configuration:**
- `config/settings.py`: All tunable parameter defaults
- `requirements.txt`: Python package dependencies

**Core Logic:**
- `src/audio_analyzer.py`: `TennisAudioAnalyzer` class - hit detection
- `src/video_validator.py`: `VideoMotionValidator` class - motion confirmation
- `src/video_editor.py`: `ClipEditor` class - segment extraction
- `src/pipeline.py`: `TennisCropper` class - orchestration

**Data Classes (result containers):**
- `src/pipeline.py`: `PipelineResult`
- `src/audio_analyzer.py`: `AudioAnalysisResult`
- `src/video_validator.py`: `VideoValidationResult`, `SegmentValidation`
- `src/video_editor.py`: `ExportResult`

**Testing:**
- No test files detected in this prototype

**Documentation:**
- `README.md`: User guide, quick start, parameter reference
- `TECHNICAL.md`: Algorithm deep-dive, signal processing explanation

## Naming Conventions

**Files:**
- Lowercase with underscores: `audio_analyzer.py`, `video_validator.py`
- Python modules, not packages (no nested directories in src/)

**Classes:**
- PascalCase with descriptive names: `TennisAudioAnalyzer`, `VideoMotionValidator`
- Result dataclasses suffixed with `Result`: `AudioAnalysisResult`, `ExportResult`

**Functions:**
- snake_case: `analyze()`, `validate_segments()`, `merge_intervals()`
- Private methods prefixed with underscore: `_apply_bandpass()`, `_compute_motion_score()`

**Constants:**
- UPPER_SNAKE_CASE: `BANDPASS_LOW`, `MOTION_AREA_THRESHOLD`
- Defined in `config/settings.py`

**Variables:**
- snake_case: `onset_env`, `peak_times`, `frame_scores`
- Descriptive names that indicate content

## Import Organization

**Standard pattern observed:**
1. Standard library imports (os, tempfile, time, pathlib)
2. Third-party imports (numpy, scipy, librosa, cv2, moviepy, streamlit, plotly)
3. Local imports from `src/` or `config/`

**Path Aliases:**
- None used - relative imports within `src/` package: `from .audio_analyzer import ...`

## Where to Add New Code

**New Processing Stage:**
- Implementation: `src/` as new module (e.g., `src/scene_detector.py`)
- Integration: Import and call from `src/pipeline.py`
- Result class: Define dataclass in new module

**New UI Feature:**
- Implementation: Add to `app.py` in appropriate section
- Follow existing pattern of `st.header()` → metrics → charts

**New Parameter:**
- Add constant to `config/settings.py`
- Add to `get_default_params()` return dict
- Add UI control in `app.py` sidebar
- Pass through to relevant processor class

**Utility Functions:**
- If audio-related: Add to `src/audio_analyzer.py`
- If video-related: Add to `src/video_validator.py` or `src/video_editor.py`
- If general: Consider new `src/utils.py` module

## Special Directories

**`out/`:**
- Purpose: Default export destination for highlight videos
- Generated: Yes, at runtime when user exports
- Committed: Only `.gitkeep` to preserve directory

**`prompts/`:**
- Purpose: Design documentation for future iOS app development
- Generated: No, manually written
- Committed: Yes

**`.planning/`:**
- Purpose: GSD command output for codebase analysis
- Generated: Yes, by GSD map-codebase command
- Committed: Yes

## File Size Reference

| File | Lines | Purpose |
|------|-------|---------|
| `app.py` | 917 | Streamlit dashboard |
| `src/pipeline.py` | 309 | Pipeline orchestrator |
| `src/audio_analyzer.py` | 280 | Audio hit detection |
| `src/video_validator.py` | 241 | Motion validation |
| `src/video_editor.py` | 213 | Clip extraction |
| `config/settings.py` | 48 | Parameter defaults |

---

*Structure analysis: 2026-01-18*
