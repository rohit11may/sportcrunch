# Technology Stack

**Analysis Date:** 2026-01-18

## Languages

**Primary:**
- Python 3.13+ - All application code

**Secondary:**
- None

## Runtime

**Environment:**
- Python 3.13.1 (local development)
- No containerization detected

**Package Manager:**
- pip
- Lockfile: Not present (only `requirements.txt` with minimum versions)

## Frameworks

**Core:**
- Streamlit >= 1.29.0 - Web-based development dashboard and visualization UI

**Signal Processing:**
- librosa >= 0.10.0 - Audio loading, resampling, and onset detection
- scipy >= 1.11.0 - Butterworth filter design and signal processing
- numpy >= 1.24.0 - Numerical array operations

**Computer Vision:**
- opencv-python >= 4.8.0 - Video capture, frame processing, and motion detection

**Video Editing:**
- moviepy >= 1.0.3 - Video clip extraction and concatenation

**Visualization:**
- Plotly >= 5.18.0 - Interactive waveform and timeline charts

**Testing:**
- Not detected (no test framework configured)

**Build/Dev:**
- Streamlit dev server - Run via `streamlit run app.py`

## Key Dependencies

**Critical (Core Functionality):**
- `librosa` - Required for audio analysis and hit detection
- `opencv-python` - Required for video validation via frame differencing
- `moviepy` - Required for video export and clip concatenation
- `scipy` - Required for bandpass filtering (Butterworth)
- `numpy` - Required by all signal processing components

**UI (Development Dashboard):**
- `streamlit` - Powers the interactive parameter tuning dashboard
- `plotly` - Renders waveform, timeline, and motion score visualizations

## Configuration

**Environment:**
- No `.env` file detected
- No environment variables required
- All configuration via `config/settings.py` constants

**Build:**
- `requirements.txt` - pip dependencies with minimum versions
- No build system (pure Python)

**Runtime Config (`config/settings.py`):**
```python
# Audio Processing
AUDIO_SAMPLE_RATE = 16000  # Hz
BANDPASS_LOW = 200         # Hz
BANDPASS_HIGH = 3000       # Hz

# Onset Detection
ONSET_THRESHOLD_LAMBDA = 2.0
PEAK_MIN_DISTANCE_SEC = 0.5

# Rally Clustering
CLUSTER_MAX_GAP_SEC = 3.0
CLUSTER_MIN_HITS = 2

# Padding
PADDING_PRE_SEC = 2.0
PADDING_POST_SEC = 2.0

# Video Motion Validation
VIDEO_SAMPLE_STRIDE = 10
VIDEO_THUMB_SIZE = (320, 180)
MOTION_PIXEL_THRESHOLD = 25
MOTION_AREA_THRESHOLD = 500
```

## Platform Requirements

**Development:**
- Python 3.13+ (tested on macOS Darwin 25.2.0)
- FFmpeg (required by moviepy for video encoding)
- No GPU required (CPU-only signal processing)

**Production:**
- Standalone Python application
- No server deployment detected
- Designed for local desktop use

## Entry Points

**Interactive Dashboard:**
```bash
streamlit run app.py
```

**Programmatic API:**
```python
from src.pipeline import TennisCropper
cropper = TennisCropper()
result = cropper.process("video.mp4", "output.mp4")
```

## Versioning

**Minimum Versions (from requirements.txt):**
| Package | Minimum Version |
|---------|----------------|
| numpy | 1.24.0 |
| scipy | 1.11.0 |
| librosa | 0.10.0 |
| moviepy | 1.0.3 |
| opencv-python | 4.8.0 |
| streamlit | 1.29.0 |
| plotly | 5.18.0 |

**Version Pinning:** Not enforced (uses `>=` for all dependencies)

---

*Stack analysis: 2026-01-18*
