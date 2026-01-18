# External Integrations

**Analysis Date:** 2026-01-18

## APIs & External Services

**None detected.**

This is a fully offline, local-only application. No external API calls, cloud services, or network requests are made.

## Data Storage

**Databases:**
- None - All data is processed in-memory

**File Storage:**
- Local filesystem only
- Input: Video files (MP4, MOV, AVI) read from user-specified paths
- Output: Exported highlight videos written to `out/` directory or user-specified paths
- Temp files: moviepy creates temporary audio files during export (auto-cleaned)

**Caching:**
- None - Results are held in session state during Streamlit sessions only

## Authentication & Identity

**Auth Provider:**
- None - No authentication required
- Local desktop application

## Monitoring & Observability

**Error Tracking:**
- None - Errors displayed in Streamlit UI via `st.error()`

**Logs:**
- Streamlit default logging
- moviepy logging suppressed (`logger=None`)
- Python warnings filtered for FutureWarning from librosa

## CI/CD & Deployment

**Hosting:**
- Local desktop only
- No cloud deployment configured

**CI Pipeline:**
- Not detected (no `.github/workflows`, `Makefile`, or CI config files)

## Environment Configuration

**Required env vars:**
- None

**Secrets location:**
- Not applicable (no secrets required)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## External Binary Dependencies

**FFmpeg:**
- Required by moviepy for video encoding/decoding
- Not bundled - must be installed on system PATH
- Used for: H.264 encoding (`libx264`), AAC audio encoding

## File Format Support

**Video Input (via OpenCV + FFmpeg):**
- MP4 (H.264, H.265)
- MOV
- AVI
- Any format supported by FFmpeg

**Video Output (via moviepy):**
- MP4 with H.264 video codec
- AAC audio codec
- Temp audio files: `.m4a`

**Audio Extraction (via librosa):**
- Extracts audio track from video files directly
- Resamples to 16kHz mono for processing

## Third-Party Library Integrations

**librosa:**
- Purpose: Audio loading and onset detection
- Integration: `librosa.load()` extracts audio from video files
- Integration: `librosa.onset.onset_strength()` computes spectral flux

**scipy:**
- Purpose: Signal processing
- Integration: `scipy.signal.butter()` designs Butterworth bandpass filter
- Integration: `scipy.signal.filtfilt()` applies zero-phase filtering
- Integration: `scipy.ndimage.maximum_filter1d()` finds local maxima
- Integration: `scipy.ndimage.uniform_filter1d()` computes rolling statistics

**opencv-python:**
- Purpose: Video frame processing
- Integration: `cv2.VideoCapture()` reads video metadata and frames
- Integration: `cv2.resize()` downscales frames for motion analysis
- Integration: `cv2.absdiff()` computes frame differences

**moviepy:**
- Purpose: Video editing and export
- Integration: `VideoFileClip()` loads video for editing
- Integration: `subclipped()` extracts time intervals
- Integration: `concatenate_videoclips()` joins segments
- Integration: `write_videofile()` exports final video

**streamlit:**
- Purpose: Web UI for development dashboard
- Integration: Session state holds pipeline results between interactions
- Integration: Progress bars and status text for processing feedback

**plotly:**
- Purpose: Interactive visualization
- Integration: Waveform plots with onset markers
- Integration: Timeline bar charts for segment visualization
- Integration: Motion score bar charts

## Network Requirements

- **None** - Application works fully offline
- No internet connectivity required after initial pip install

---

*Integration audit: 2026-01-18*
