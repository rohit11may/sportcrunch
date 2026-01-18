# Testing Patterns

**Analysis Date:** 2026-01-18

## Test Framework

**Runner:**
- No test framework configured
- No test files exist in the codebase
- No `pytest.ini`, `setup.cfg`, or `pyproject.toml` with test configuration

**Assertion Library:**
- Not applicable (no tests)

**Run Commands:**
```bash
# Not configured - would typically be:
pytest                 # Run all tests
pytest -v              # Verbose mode
pytest --cov=src       # With coverage
```

## Test File Organization

**Location:**
- No test files exist
- Recommended pattern: Co-located or `tests/` directory

**Naming:**
- Recommended: `test_<module>.py` (e.g., `test_audio_analyzer.py`)

**Recommended Structure:**
```
prototype/
├── src/
│   ├── audio_analyzer.py
│   ├── video_validator.py
│   ├── pipeline.py
│   └── video_editor.py
└── tests/
    ├── __init__.py
    ├── conftest.py          # Shared fixtures
    ├── test_audio_analyzer.py
    ├── test_video_validator.py
    ├── test_pipeline.py
    └── test_video_editor.py
```

## Test Structure

**Suite Organization:**
- Not yet implemented

**Recommended Pattern for This Codebase:**
```python
import pytest
import numpy as np
from src.audio_analyzer import TennisAudioAnalyzer, AudioAnalysisResult


class TestTennisAudioAnalyzer:
    """Tests for audio analysis pipeline."""

    @pytest.fixture
    def analyzer(self):
        """Default analyzer instance."""
        return TennisAudioAnalyzer()

    def test_bandpass_filter_attenuates_low_frequencies(self, analyzer):
        """Bandpass filter removes frequencies below cutoff."""
        # Arrange
        sr = 16000
        low_freq_signal = np.sin(2 * np.pi * 50 * np.arange(sr) / sr)  # 50 Hz

        # Act
        filtered = analyzer._apply_bandpass(low_freq_signal, sr)

        # Assert
        assert np.max(np.abs(filtered)) < 0.1 * np.max(np.abs(low_freq_signal))

    def test_cluster_peaks_groups_nearby_hits(self, analyzer):
        """Hits within max_gap are grouped into same rally."""
        # Arrange
        peak_times = np.array([1.0, 1.5, 2.0, 10.0, 10.5, 11.0])

        # Act
        intervals, hit_counts = analyzer._cluster_peaks(peak_times)

        # Assert
        assert len(intervals) == 2
        assert hit_counts == [3, 3]
```

## Mocking

**Framework:** pytest-mock (recommended)

**Recommended Patterns:**
```python
def test_analyze_loads_audio(mocker, analyzer):
    """analyze() calls librosa.load with correct parameters."""
    # Arrange
    mock_load = mocker.patch('librosa.load')
    mock_load.return_value = (np.zeros(16000), 16000)
    mocker.patch.object(analyzer, '_apply_bandpass', return_value=np.zeros(16000))
    mocker.patch('librosa.onset.onset_strength', return_value=np.zeros(100))
    mocker.patch('librosa.times_like', return_value=np.linspace(0, 1, 100))

    # Act
    analyzer.analyze('/path/to/video.mp4')

    # Assert
    mock_load.assert_called_once_with('/path/to/video.mp4', sr=16000, mono=True)


def test_video_validator_opens_video(mocker):
    """VideoMotionValidator.load_video opens file with OpenCV."""
    # Arrange
    mock_cap = mocker.MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.get.side_effect = [30.0, 1000, 1920, 1080]  # fps, frames, w, h
    mocker.patch('cv2.VideoCapture', return_value=mock_cap)

    validator = VideoMotionValidator()

    # Act
    info = validator.load_video('/path/to/video.mp4')

    # Assert
    assert info['fps'] == 30.0
    assert info['width'] == 1920
```

**What to Mock:**
- External file I/O (librosa.load, cv2.VideoCapture)
- Video file operations (expensive, require real files)
- moviepy clip operations

**What NOT to Mock:**
- NumPy/SciPy array operations (pure computation)
- Internal method calls when testing integration
- Dataclass creation

## Fixtures and Factories

**Recommended Test Data:**
```python
# conftest.py
import pytest
import numpy as np


@pytest.fixture
def sample_audio_16khz():
    """1 second of 16kHz audio with synthetic hits."""
    sr = 16000
    duration = 1.0
    t = np.linspace(0, duration, int(sr * duration))

    # Base noise
    audio = np.random.randn(len(t)) * 0.01

    # Add synthetic "hits" at 0.25s and 0.75s
    for hit_time in [0.25, 0.75]:
        hit_idx = int(hit_time * sr)
        # Broadband impulse
        audio[hit_idx:hit_idx+100] += np.random.randn(100) * 0.5

    return audio, sr


@pytest.fixture
def sample_intervals():
    """Sample rally intervals for testing."""
    return [
        (0.0, 5.0),
        (10.0, 15.0),
        (20.0, 25.0),
    ]


@pytest.fixture
def overlapping_intervals():
    """Intervals that should be merged."""
    return [
        (0.0, 5.0),
        (4.5, 8.0),  # Overlaps with first
        (10.0, 12.0),
        (11.5, 15.0),  # Overlaps with previous
    ]
```

**Location:**
- Shared fixtures: `tests/conftest.py`
- Module-specific fixtures: in test file or class

## Coverage

**Requirements:** Not enforced (no tests exist)

**Recommended Target:** 80%+ for core modules (`src/`)

**View Coverage:**
```bash
pytest --cov=src --cov-report=html
open htmlcov/index.html
```

## Test Types

**Unit Tests:**
- Test individual methods in isolation
- Focus on: `_apply_bandpass`, `_compute_adaptive_threshold`, `_cluster_peaks`, `merge_intervals`
- Mock external dependencies

**Integration Tests:**
- Test full pipeline with real audio/video files
- Use small sample files (< 5 seconds)
- Verify end-to-end results

**E2E Tests:**
- Not applicable for CLI/library
- Streamlit UI testing not configured

## Common Patterns

**Async Testing:**
- Not applicable (no async code in codebase)

**Error Testing:**
```python
def test_load_video_raises_for_invalid_path(self):
    """load_video raises ValueError for non-existent file."""
    validator = VideoMotionValidator()

    with pytest.raises(ValueError, match="Could not open video"):
        validator.load_video("/nonexistent/video.mp4")


def test_validate_segments_requires_loaded_video(self):
    """validate_segments raises if no video loaded."""
    validator = VideoMotionValidator()

    with pytest.raises(ValueError, match="No video loaded"):
        validator.validate_segments([(0, 5)])
```

**Parametrized Tests:**
```python
@pytest.mark.parametrize("lambda_val,expected_sensitivity", [
    (1.0, "high"),    # More detections
    (2.0, "medium"),  # Default
    (3.0, "low"),     # Fewer detections
])
def test_onset_threshold_lambda_affects_detection_count(
    lambda_val, expected_sensitivity, sample_audio_16khz
):
    """Higher lambda means fewer detections."""
    audio, sr = sample_audio_16khz
    analyzer = TennisAudioAnalyzer(onset_threshold_lambda=lambda_val)
    # ... test detection counts
```

## Recommended Test Additions

**Priority 1 - Core Algorithm Tests:**
- `test_audio_analyzer.py`: Test bandpass filter, onset detection, peak finding, clustering
- `test_video_editor.py`: Test interval merging logic

**Priority 2 - Integration Tests:**
- `test_pipeline.py`: Test full TennisCropper.process() with fixture files

**Priority 3 - Edge Cases:**
- Empty audio files
- Very short segments
- Overlapping intervals at boundaries
- Invalid file paths

## Testing Gaps

**Currently Untested:**
- All core audio processing algorithms
- Video validation motion scoring
- Interval merging edge cases
- Pipeline orchestration
- Export functionality

**Risk:**
- Changes to algorithms may break detection accuracy without warning
- Edge cases in interval handling could cause crashes

**Priority:** High - Core processing has no test coverage

---

*Testing analysis: 2026-01-18*
