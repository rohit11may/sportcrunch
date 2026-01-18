# Codebase Concerns

**Analysis Date:** 2026-01-18

## Tech Debt

**No Automated Testing:**
- Issue: Zero test files exist in the codebase - no unit tests, integration tests, or end-to-end tests
- Files: All source files in `src/` directory untested
- Impact: Any code changes risk introducing regressions undetected. Refactoring is high-risk without test coverage.
- Fix approach: Add pytest as test framework. Start with unit tests for `src/audio_analyzer.py` (pure functions like `_apply_bandpass`, `_compute_adaptive_threshold`, `_find_peaks`, `_cluster_peaks`). Add integration tests for `src/pipeline.py` using sample video fixtures.

**Suppressed Warnings Without Resolution:**
- Issue: FutureWarning suppressed globally in audio analyzer without addressing root cause
- Files: `src/audio_analyzer.py:18`
  ```python
  warnings.filterwarnings("ignore", category=FutureWarning)
  ```
- Impact: May hide deprecation warnings from librosa or numpy that indicate breaking changes in future versions
- Fix approach: Investigate what triggers the FutureWarning (likely librosa), update code to use non-deprecated API, then remove the blanket suppression

**Inline Import Anti-Pattern:**
- Issue: Modules are imported inside functions rather than at module level
- Files:
  - `src/pipeline.py:189` - `import time` inside `process()` method
  - `src/audio_analyzer.py:179` - `from scipy.ndimage import uniform_filter1d, generic_filter1d` inside `_compute_adaptive_threshold()`
  - `app.py:554`, `app.py:792-793`, `app.py:846`, `app.py:868-869` - `import traceback`, `import re`, `from src.video_editor import ClipEditor` inside callbacks
- Impact: Slight performance overhead on repeated calls, makes dependencies harder to track, IDE tooling may miss these imports
- Fix approach: Move all imports to module level. The `traceback` import in `app.py` is for error handling and could remain conditional, but core dependencies should be at top.

**Unused Import:**
- Issue: `generic_filter1d` is imported but never used
- Files: `src/audio_analyzer.py:179`
- Impact: Dead code, confusing for readers
- Fix approach: Remove unused import

## Known Bugs

**Potential Resource Leak in Video Validator on Exception:**
- Symptoms: If an exception occurs during frame reading in `_validate_segment()`, the VideoCapture is not released
- Files: `src/video_validator.py:132-176`
- Trigger: Corrupted video file, disk read error, or any exception during frame processing loop
- Workaround: None currently
- Fix: Wrap VideoCapture usage in try/finally block or use context manager pattern:
  ```python
  cap = cv2.VideoCapture(self._video_path)
  try:
      # ... processing
  finally:
      cap.release()
  ```

**Potential Division by Zero in Video Duration:**
- Symptoms: Division by zero if video has 0 FPS metadata
- Files: `src/video_validator.py:79`
  ```python
  duration = frame_count / fps if fps > 0 else 0
  ```
- Trigger: Malformed video file with 0 FPS metadata
- Workaround: Currently handled with conditional, but downstream code may assume valid duration
- Note: This is partially handled but should propagate error rather than silently set duration=0

## Security Considerations

**Path Injection via User Input:**
- Risk: Video file paths are accepted directly from user input in Streamlit UI without validation
- Files: `app.py:305-309`
  ```python
  video_path = st.text_input(
      "Video File Path",
      placeholder="/path/to/tennis_match.mp4",
  )
  ```
- Current mitigation: Only `os.path.exists()` check performed at `app.py:505`
- Recommendations:
  1. Validate path is within expected directories
  2. Use `pathlib.Path.resolve()` to prevent directory traversal
  3. For production, use file upload instead of path input

**Temp File Handling:**
- Risk: Temp audio file created during export may persist on error
- Files: `src/video_editor.py:149`
  ```python
  temp_audiofile=tempfile.mktemp(suffix=".m4a"),
  ```
- Current mitigation: `remove_temp=True` flag set, but may not clean up on exception
- Recommendations: Use `tempfile.NamedTemporaryFile` with context manager for guaranteed cleanup

## Performance Bottlenecks

**Repeated Video Opening Per Segment:**
- Problem: For N segments, video is opened N times in validation
- Files: `src/video_validator.py:134`
  ```python
  def _validate_segment(self, start: float, end: float) -> SegmentValidation:
      cap = cv2.VideoCapture(self._video_path)  # Opens video each time
  ```
- Cause: Each segment validation opens a new VideoCapture instance
- Improvement path: Keep single VideoCapture instance open, seek between segments. Be mindful of seek performance with compressed video codecs.

**Full Waveform Kept in Memory:**
- Problem: Entire audio waveform and filtered version stored for visualization
- Files: `src/audio_analyzer.py:119-124`
- Cause: Storing raw and filtered waveforms at 1kHz for display
- Improvement path: For very long videos (3+ hours), consider streaming processing or only storing display-resolution data on demand

**MoviePy Concatenation Uses "compose" Method:**
- Problem: "compose" method in concatenate_videoclips may be slower than "chain"
- Files: `src/video_editor.py:139`
  ```python
  final_clip = concatenate_videoclips(subclips, method="compose")
  ```
- Cause: "compose" handles different resolutions but has overhead
- Improvement path: If all segments have same resolution (typical for single-source video), use `method="chain"` for faster concatenation

## Fragile Areas

**Streamlit UI State Management:**
- Files: `app.py:294-299`
  ```python
  if 'pipeline_result' not in st.session_state:
      st.session_state.pipeline_result = None
  if 'processing' not in st.session_state:
      st.session_state.processing = False
  ```
- Why fragile: Manual session state initialization scattered across main(). State can become inconsistent if user refreshes mid-processing.
- Safe modification: Always check and reset state at start of main()
- Test coverage: None (UI testing would require Streamlit testing framework)

**Hardcoded Magic Numbers:**
- Files: Multiple locations
  - `src/audio_analyzer.py:104` - `hop_length=512`
  - `src/audio_analyzer.py:120-121` - `display_sr = 1000`, downsample factor calculation
  - `src/video_editor.py:74` - `0.5` seconds merge gap tolerance
  - `src/video_validator.py:159` - `8` max sample frames for visualization
- Why fragile: These values affect algorithm behavior but are not configurable or documented inline
- Safe modification: Extract to constants in `config/settings.py` with documentation

**Preset Value Synchronization:**
- Files: `app.py:328-364`
- Why fragile: Preset parameter values are duplicated between presets and `get_default_params()`. If defaults change in `config/settings.py`, presets won't automatically update.
- Safe modification: Derive preset values from base defaults with overrides

## Scaling Limits

**Memory Usage with Large Videos:**
- Current capacity: Works well with videos up to ~2-3 hours
- Limit: For very long recordings (6+ hours), audio waveform arrays can consume significant RAM (16kHz * 6hr = 345M samples * 4 bytes = 1.4GB per array, times 2 for raw+filtered)
- Scaling path: Implement chunked audio processing, only load sections as needed

**Sequential Segment Validation:**
- Current capacity: Validates segments sequentially
- Limit: For videos with many segments (50+), validation time grows linearly
- Scaling path: Parallel segment validation using multiprocessing (segments are independent)

## Dependencies at Risk

**librosa Version Dependency:**
- Risk: FutureWarning suggests upcoming API changes
- Impact: May break with librosa 1.0 or later releases
- Migration plan: Monitor librosa changelog, test with new versions in CI before upgrade

**moviepy API Compatibility:**
- Risk: Code uses `subclipped()` method (moviepy 2.x API)
- Files: `src/video_editor.py:132`
- Impact: Won't work with moviepy 1.x which uses `subclip()`
- Migration plan: Pin moviepy>=2.0 in requirements.txt or add version check

## Missing Critical Features

**No Progress Persistence:**
- Problem: If processing is interrupted (browser close, crash), all progress is lost
- Blocks: Processing very long videos reliably
- Potential solution: Save intermediate results (audio analysis, validation) to disk, allow resume

**No Batch Processing:**
- Problem: Can only process one video at a time through UI
- Blocks: Processing multiple match recordings efficiently
- Potential solution: Add CLI interface or batch mode to pipeline

**No Configuration Persistence:**
- Problem: Parameter settings reset on page refresh
- Blocks: Iterative tuning workflow
- Potential solution: Save/load parameter presets to JSON, or use browser localStorage via Streamlit

## Test Coverage Gaps

**All Core Modules Untested:**
- What's not tested:
  - Audio analysis pipeline (`src/audio_analyzer.py`)
  - Video motion validation (`src/video_validator.py`)
  - Video editing/export (`src/video_editor.py`)
  - Pipeline orchestration (`src/pipeline.py`)
- Files: No test files exist
- Risk: All functionality could break silently on code changes
- Priority: **High** - Add tests before any refactoring

**Edge Cases Unvalidated:**
- What's not tested:
  - Empty video file
  - Video with no audio track
  - Video with no motion (static image)
  - Very short videos (<5 seconds)
  - Videos with unusual frame rates
  - Audio with no detectable hits
- Risk: Unknown behavior in edge cases, potential crashes
- Priority: Medium - Document expected behavior, add validation

**No CI/CD Pipeline:**
- What's not tested: Automated testing on commits
- Files: No `.github/workflows/` or equivalent
- Risk: Regressions can be merged without detection
- Priority: Medium - Set up after adding initial test suite

---

*Concerns audit: 2026-01-18*
