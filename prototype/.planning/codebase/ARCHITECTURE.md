# Architecture

**Analysis Date:** 2026-01-18

## Pattern Overview

**Overall:** Propose-and-Verify Pipeline

**Key Characteristics:**
- Two-phase detection: fast audio proposal, targeted video verification
- Layered processing components with clean separation
- Dataclass-based result containers for intermediate visualization
- Streamlit dashboard for interactive parameter tuning

## Layers

**Presentation Layer (Dashboard):**
- Purpose: Interactive parameter tuning and visualization
- Location: `app.py`
- Contains: Streamlit UI, Plotly charts, session state management
- Depends on: Pipeline orchestration layer, config settings
- Used by: End users during development/tuning

**Orchestration Layer (Pipeline):**
- Purpose: Coordinates the three processing stages
- Location: `src/pipeline.py`
- Contains: `TennisCropper` class, `PipelineResult` dataclass
- Depends on: Audio analyzer, video validator, clip editor
- Used by: Presentation layer, programmatic API consumers

**Audio Processing Layer:**
- Purpose: Detects racket-ball impacts using spectral analysis
- Location: `src/audio_analyzer.py`
- Contains: `TennisAudioAnalyzer` class, `AudioAnalysisResult` dataclass
- Depends on: librosa, scipy.signal, numpy
- Used by: Pipeline orchestrator

**Video Validation Layer:**
- Purpose: Confirms motion in proposed segments
- Location: `src/video_validator.py`
- Contains: `VideoMotionValidator` class, `SegmentValidation`, `VideoValidationResult` dataclasses
- Depends on: OpenCV (cv2), numpy
- Used by: Pipeline orchestrator

**Video Export Layer:**
- Purpose: Extracts and concatenates validated segments
- Location: `src/video_editor.py`
- Contains: `ClipEditor` class, `ExportResult` dataclass
- Depends on: moviepy
- Used by: Pipeline orchestrator, dashboard export buttons

**Configuration Layer:**
- Purpose: Default parameter values and getter
- Location: `config/settings.py`
- Contains: Module-level constants, `get_default_params()` function
- Depends on: Nothing
- Used by: Dashboard UI, can be imported anywhere

## Data Flow

**Rally Detection Pipeline:**

1. User provides video path and tuning parameters via `app.py`
2. `TennisCropper.process()` in `src/pipeline.py` orchestrates:
   - Calls `TennisAudioAnalyzer.analyze()` to detect hit timestamps
   - Groups hits into candidate rally intervals with padding
   - Passes candidates to `VideoMotionValidator.validate_segments()`
   - Filters to validated intervals only
   - Uses `ClipEditor.merge_intervals()` to combine overlapping segments
3. If export requested, `ClipEditor.extract_and_export()` writes output video
4. `PipelineResult` dataclass returned containing all intermediate data

**Audio Analysis Flow:**
```
Video file → librosa.load() → Butterworth bandpass filter →
librosa.onset_strength() (spectral flux) → Adaptive threshold →
Peak finding → Cluster peaks by gap → Add padding → Rally intervals
```

**Video Validation Flow:**
```
For each candidate interval:
  cv2.VideoCapture → Seek to start → Sample every Nth frame →
  Resize to thumbnail → Convert to grayscale → Frame differencing →
  Count motion pixels → Average score → Compare to threshold → Valid/Invalid
```

**State Management:**
- Dashboard uses `st.session_state` to persist `pipeline_result` between reruns
- Each component stores `_last_result` for access to intermediate data
- Results are dataclasses: immutable containers for all analysis outputs

## Key Abstractions

**Result Dataclasses:**
- Purpose: Capture all intermediate data for visualization and debugging
- Examples:
  - `AudioAnalysisResult` in `src/audio_analyzer.py`
  - `VideoValidationResult`, `SegmentValidation` in `src/video_validator.py`
  - `PipelineResult` in `src/pipeline.py`
  - `ExportResult` in `src/video_editor.py`
- Pattern: Immutable containers with typed fields, created at end of processing

**Analyzer/Validator Classes:**
- Purpose: Encapsulate processing logic with configurable parameters
- Examples:
  - `TennisAudioAnalyzer` in `src/audio_analyzer.py`
  - `VideoMotionValidator` in `src/video_validator.py`
  - `ClipEditor` in `src/video_editor.py`
  - `TennisCropper` in `src/pipeline.py`
- Pattern: Constructor takes config, methods perform analysis, store last result

**Intervals:**
- Purpose: Represent time ranges in video
- Format: `List[Tuple[float, float]]` where each tuple is `(start_seconds, end_seconds)`
- Used everywhere: rally_intervals, validated_intervals, merged_intervals

## Entry Points

**Streamlit Dashboard:**
- Location: `app.py`
- Triggers: `streamlit run app.py`
- Responsibilities: UI rendering, parameter collection, calling pipeline, visualization

**Programmatic API:**
- Location: `src/pipeline.py` via `TennisCropper` class
- Triggers: Python import and method calls
- Responsibilities: Full pipeline or individual stage execution

**Example programmatic usage:**
```python
from src.pipeline import TennisCropper

cropper = TennisCropper(onset_threshold_lambda=2.5)
result = cropper.process("match.mp4", output_path="highlights.mp4")
```

## Error Handling

**Strategy:** Exceptions bubble up with tracebacks displayed in Streamlit

**Patterns:**
- File not found: Checked in `app.py` before processing
- Video open failure: `ValueError` raised in `VideoMotionValidator.load_video()`
- No intervals: `ValueError` raised in `ClipEditor.extract_and_export()`
- General exceptions: Caught in `app.py`, displayed with `st.error()` and `st.code(traceback)`

## Cross-Cutting Concerns

**Logging:** No formal logging framework. Progress communicated via optional callbacks:
- `progress_callback: Optional[Callable[[str], None]]` passed through layers
- Dashboard updates `st.progress()` and `st.empty().text()` based on callbacks

**Validation:** Parameters validated implicitly by libraries (scipy, librosa) or clamped:
- Bandpass frequencies clamped to valid Nyquist range in `_apply_bandpass()`
- Intervals clamped to video duration in `merge_intervals()`

**Authentication:** Not applicable (local desktop tool)

---

*Architecture analysis: 2026-01-18*
