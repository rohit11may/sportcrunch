# Coding Conventions

**Analysis Date:** 2026-01-18

## Naming Patterns

**Files:**
- Snake_case for Python modules: `audio_analyzer.py`, `video_validator.py`, `video_editor.py`
- Entry point uses short name: `app.py`
- Config modules use short names: `settings.py`

**Functions:**
- Snake_case for all functions: `analyze_audio()`, `validate_segments()`, `merge_intervals()`
- Private methods prefixed with underscore: `_apply_bandpass()`, `_compute_adaptive_threshold()`, `_validate_segment()`
- Getter methods use `get_` prefix: `get_candidate_intervals()`, `get_validated_intervals()`, `get_intervals_preview()`

**Variables:**
- Snake_case for all variables: `video_path`, `onset_strength`, `motion_score`
- Single-letter variables acceptable for array data: `y` (audio waveform), `b, a` (filter coefficients)
- Constants use SCREAMING_SNAKE_CASE in config: `AUDIO_SAMPLE_RATE`, `BANDPASS_LOW`, `MOTION_AREA_THRESHOLD`

**Classes:**
- PascalCase for classes: `TennisCropper`, `TennisAudioAnalyzer`, `VideoMotionValidator`, `ClipEditor`
- Dataclasses for result containers: `PipelineResult`, `AudioAnalysisResult`, `SegmentValidation`, `ExportResult`

**Types:**
- Type hints used throughout on function signatures
- `Optional[]` for nullable values
- `List[Tuple[float, float]]` for interval lists
- `Callable[[str], None]` for callback functions

## Code Style

**Formatting:**
- No formatter configuration detected
- Use 4-space indentation (Python standard)
- Line length appears to be ~100-120 characters max

**Linting:**
- No linting configuration detected (.flake8, .pylintrc, pyproject.toml absent)
- Manually maintain PEP 8 compliance

**Docstrings:**
- Triple-quoted docstrings at module, class, and function level
- Module docstrings explain purpose and key concepts:
  ```python
  """
  TennisAudioAnalyzer: Detects racket-ball impacts using audio signal processing.

  The acoustic signature of a tennis hit is characterized by:
  - Broadband impulse with energy concentrated in 200-3000 Hz
  - Near-instantaneous attack with rapid decay (<50ms)
  - High spectral flux (sudden change in frequency content)
  """
  ```
- Function docstrings use Args/Returns format:
  ```python
  def analyze(self, audio_path: str) -> AudioAnalysisResult:
      """
      Full analysis pipeline: load audio, detect hits, cluster into rallies.

      Args:
          audio_path: Path to audio file or video file (audio will be extracted)

      Returns:
          AudioAnalysisResult with all intermediate data for visualization
      """
  ```
- Class docstrings include usage examples:
  ```python
  class TennisCropper:
      """
      Main pipeline for tennis video summarization.

      Usage:
          cropper = TennisCropper()
          result = cropper.process("match.mp4", "highlights.mp4")
          print(f"Compressed {result.compression_ratio:.1f}%")
      """
  ```

## Import Organization

**Order:**
1. Standard library imports (`os`, `time`, `tempfile`)
2. Third-party library imports (`numpy`, `scipy`, `cv2`, `librosa`, `streamlit`)
3. Local imports (from `.audio_analyzer import ...`)

**Style:**
- One import per line for most imports
- Grouped related imports from same package:
  ```python
  from scipy.signal import butter, filtfilt
  from scipy.ndimage import maximum_filter1d
  ```
- Relative imports within package:
  ```python
  from .audio_analyzer import TennisAudioAnalyzer, AudioAnalysisResult
  from .video_validator import VideoMotionValidator, VideoValidationResult
  ```

**Path Aliases:**
- None used - standard relative imports only

## Error Handling

**Patterns:**
- Raise `ValueError` for invalid inputs:
  ```python
  if not cap.isOpened():
      raise ValueError(f"Could not open video: {video_path}")

  if self._video_path is None or self._video_info is None:
      raise ValueError("No video loaded. Call load_video() first.")

  if not intervals:
      raise ValueError("No valid intervals to export")
  ```
- Use `warnings.filterwarnings` to suppress noisy library warnings:
  ```python
  warnings.filterwarnings("ignore", category=FutureWarning)
  ```
- In Streamlit UI, catch exceptions and display with traceback:
  ```python
  except Exception as e:
      st.error(f"Error: {str(e)}")
      import traceback
      st.code(traceback.format_exc())
  ```

**Return None for Optional Results:**
- Private cache variables initialized to `None`: `self._last_result: Optional[AudioAnalysisResult] = None`
- Check before accessing: `if self._last_result is None: return []`

## Logging

**Framework:** None - uses print-style output through callbacks

**Patterns:**
- Progress callbacks instead of logging:
  ```python
  def process(
      self,
      video_path: str,
      output_path: Optional[str] = None,
      progress_callback: Optional[Callable[[str], None]] = None,
  ) -> PipelineResult:
      if progress_callback:
          progress_callback("Step 1/3: Analyzing audio...")
  ```
- Streamlit status updates for UI:
  ```python
  progress_bar = st.progress(0, text="Initializing...")
  status_text = st.empty()
  status_text.text(message)
  ```

## Comments

**When to Comment:**
- Step-by-step comments in processing pipelines:
  ```python
  # Step 1: Load and downsample audio
  y, sr = librosa.load(audio_path, sr=self.sample_rate, mono=True)

  # Step 2: Apply bandpass filter
  y_filtered = self._apply_bandpass(y, sr)
  ```
- Explain non-obvious parameters:
  ```python
  downsample = max(1, len(audio_result.waveform_times) // 5000)  # For performance
  ```
- Document algorithm choices in docstrings, not inline

**JSDoc/TSDoc:**
- Not applicable (Python project)

## Function Design

**Size:**
- Functions typically 20-50 lines
- Larger functions (like `main()` in app.py) acceptable for UI orchestration

**Parameters:**
- Use keyword arguments with defaults for optional params:
  ```python
  def __init__(
      self,
      sample_rate: int = 16000,
      bandpass_low: float = 200,
      bandpass_high: float = 3000,
      onset_threshold_lambda: float = 2.0,
      ...
  ):
  ```
- Group related parameters (audio_params, video_params)
- Progress callbacks always optional with `None` default

**Return Values:**
- Return dataclass instances for complex results:
  ```python
  return AudioAnalysisResult(
      sample_rate=sr,
      duration=duration,
      waveform_times=waveform_times,
      ...
  )
  ```
- Return simple types (lists, floats) for single-value results
- Properties for accessing cached results: `@property def last_result(self)`

## Module Design

**Exports:**
- Each module defines its classes and dataclasses
- No explicit `__all__` defined
- `__init__.py` files are minimal (just package comments)

**Barrel Files:**
- Not used - direct imports from modules:
  ```python
  from src.pipeline import TennisCropper, PipelineResult
  from src.audio_analyzer import AudioAnalysisResult
  ```

## Dataclass Usage

**Pattern:**
- Use `@dataclass` for all result containers:
  ```python
  @dataclass
  class SegmentValidation:
      """Validation result for a single segment."""
      start: float
      end: float
      is_valid: bool
      motion_score: float
      frame_scores: List[float]
      sample_frames: List[np.ndarray]
  ```
- Keep all fields public (no private fields in dataclasses)
- Add brief docstrings to describe purpose

## Configuration Pattern

**Constants Location:** `config/settings.py`

**Pattern:**
- Module-level constants with SCREAMING_SNAKE_CASE
- Helper function to return all as dict:
  ```python
  def get_default_params() -> dict:
      """Return all parameters as a dictionary for UI binding."""
      return {
          "audio_sample_rate": AUDIO_SAMPLE_RATE,
          "bandpass_low": BANDPASS_LOW,
          ...
      }
  ```

## Context Manager Pattern

**Usage in ClipEditor:**
```python
def __enter__(self):
    self.load()
    return self

def __exit__(self, exc_type, exc_val, exc_tb):
    self.close()
    return False
```

## Resource Cleanup

**Pattern:**
- Explicit `close()` methods for resources:
  ```python
  def close(self):
      """Release video resources."""
      if self._clip is not None:
          self._clip.close()
          self._clip = None
  ```
- OpenCV VideoCapture released immediately after use:
  ```python
  cap = cv2.VideoCapture(video_path)
  # ... use cap ...
  cap.release()
  ```

---

*Convention analysis: 2026-01-18*
