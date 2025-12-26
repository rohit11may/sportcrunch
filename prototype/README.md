# 🎾 Tennis Rally Detector

Automatically extract rally highlights from tennis match recordings by detecting racket-ball impacts using audio signal processing and validating with video motion analysis.

## Overview

This tool removes "dead space" (ball retrieval, changeovers, etc.) from tennis videos, keeping only the action. It uses a **no-ML approach**:

1. **Audio Analysis**: Detects racket hits using spectral flux (onset detection) with bandpass filtering
2. **Video Validation**: Confirms motion in detected segments using frame differencing
3. **Smart Editing**: Merges overlapping segments and exports a summary video

## Quick Start

### 1. Install Dependencies

```bash
cd sports-cropper
pip install -r requirements.txt
```

### 2. Run the Development Dashboard

```bash
streamlit run app.py
```

Then open http://localhost:8501 in your browser.

### 3. Using the Dashboard

1. Enter the full path to your tennis video
2. Adjust parameters using the sidebar sliders
3. Click "Analyze Video"
4. Review the visualizations:
   - **Waveform**: See the filtered audio and detected hits
   - **Timeline**: Visualize detected rally segments
   - **Motion Scores**: Check which segments passed validation
5. Export when satisfied with the results

## Project Structure

```
sports-cropper/
├── app.py                 # Streamlit visualization dashboard
├── requirements.txt       # Python dependencies
├── config/
│   └── settings.py        # Default parameters
└── src/
    ├── audio_analyzer.py  # TennisAudioAnalyzer - hit detection
    ├── video_validator.py # VideoMotionValidator - motion check
    ├── video_editor.py    # ClipEditor - segment extraction
    └── pipeline.py        # TennisCropper - main orchestration
```

## Parameter Reference

### Audio Detection

These parameters control how the algorithm identifies racket-ball impacts in the audio track.

#### `bandpass_low` (Default: 200 Hz)

**What it does:** Sets the lower cutoff frequency for the bandpass filter. Audio frequencies below this value are removed before analysis.

**Effect of changing:**
- **Increase (300-500 Hz):** More aggressive filtering of low-frequency noise like wind rumble, distant traffic, or crowd murmur. Use for outdoor recordings with lots of ambient noise.
- **Decrease (50-150 Hz):** Preserves more low-end audio. May help detect heavier ball impacts but risks including unwanted noise.

**When to adjust:** If you see false detections during windy moments or when the crowd is loud, try increasing this value. If legitimate hits are being missed and you're in a quiet indoor setting, try lowering it.

---

#### `bandpass_high` (Default: 3000 Hz)

**What it does:** Sets the upper cutoff frequency for the bandpass filter. Audio frequencies above this value are removed.

**Effect of changing:**
- **Increase (4000-5000 Hz):** Preserves more high-frequency detail. The "crack" of a powerful shot has significant energy up to 4-5kHz.
- **Decrease (1500-2500 Hz):** More aggressive filtering of hiss, squeaky shoes, and high-pitched crowd noise.

**When to adjust:** If you're getting false positives from shoe squeaks or referee whistles, try lowering this. If crisp groundstrokes are being missed, try increasing it.

---

#### `onset_threshold_lambda` (Default: 2.0)

**What it does:** Controls the sensitivity of hit detection. The algorithm detects a hit when the audio onset strength exceeds `median + λ × standard_deviation` over a local window. This is the λ (lambda) multiplier.

**Effect of changing:**
- **Decrease (1.0-1.8):** More sensitive detection. Catches quieter hits (drop shots, slices) but may include false positives from ball bounces or ambient sounds.
- **Increase (2.5-4.0):** Stricter detection. Only the loudest, clearest hits are detected. Good for reducing false positives but may miss softer shots.

**Recommended values:**
- `1.5-2.0` — High sensitivity, good for quiet recordings or when you want to catch every shot
- `2.0-2.5` — Balanced (default range)
- `3.0-4.0` — Strict, use when you have lots of false positives

**When to adjust:** This is the primary tuning knob. If you see too many detected hits (red triangles in the waveform view), increase λ. If rallies are being missed entirely, decrease it.

---

#### `peak_min_distance_sec` (Default: 0.5s)

**What it does:** The minimum time gap required between two detected hits. If two peaks are detected closer together than this value, only the strongest one is kept.

**Effect of changing:**
- **Decrease (0.2-0.4s):** Allows detection of rapid-fire exchanges at the net or very fast rallies. May cause double-detection of single hits.
- **Increase (0.6-1.0s):** Prevents double-detection but may miss shots in fast volley exchanges.

**When to adjust:** If you see double-detections (two hits marked for what sounds like one shot), increase this value. For fast-paced doubles or net play where volleys happen quickly, try decreasing it.

---

### Rally Clustering

These parameters control how individual detected hits are grouped into rally segments.

#### `cluster_max_gap_sec` (Default: 3.0s)

**What it does:** Maximum time gap allowed between consecutive hits for them to be considered part of the same rally/segment. Hits separated by more than this gap start a new segment.

**Effect of changing:**
- **Decrease (0.5-1.5s):** Creates tighter, more granular clips. Each shot becomes its own segment. Use for creating individual shot highlights.
- **Increase (4.0-8.0s):** Groups more shots together. Accounts for longer pauses between shots (e.g., after a let, or a player taking time). Use to capture complete rallies.

**Recommended values:**
- `0.5-1.0s` — Individual shots mode (each hit = separate clip)
- `2.0-4.0s` — Rally mode (groups shots into complete points)
- `5.0-8.0s` — Point mode (includes time between shots, good for slow-paced matches)

**When to adjust:** This is the key parameter for controlling whether you get individual shots or complete rallies. Start with 3.0s for rally detection, reduce for shot-by-shot clips.

---

#### `cluster_min_hits` (Default: 2)

**What it does:** Minimum number of detected hits required for a cluster to be kept as a valid segment. Clusters with fewer hits are discarded.

**Effect of changing:**
- **Set to 1:** Keeps every single detected hit, including serves and stray sounds. Useful for individual shot extraction.
- **Set to 2:** Requires at least a serve and return. Filters out lone detections that are likely false positives.
- **Set to 3+:** Only keeps sustained rallies. Good for extracting "rally highlights" while ignoring quick points.

**When to adjust:** Use 1 for maximum coverage (every possible shot). Use 2+ to filter out isolated false detections or quick aces/service winners.

---

### Clip Padding

These parameters control the buffer time added around detected segments.

#### `padding_pre_sec` (Default: 2.0s)

**What it does:** Seconds of video to include before the first detected hit in each segment.

**Effect of changing:**
- **Decrease (0.3-1.0s):** Tighter clips that start right before the action. Good for quick highlights or social media clips.
- **Increase (2.0-4.0s):** Includes more lead-up to the rally (ball toss, player positioning). Better for analysis or complete rally context.

**When to adjust:** For quick-cut highlights, use 0.5-1.0s. For coaching analysis where you want to see preparation, use 2.0-3.0s.

---

#### `padding_post_sec` (Default: 2.0s)

**What it does:** Seconds of video to include after the last detected hit in each segment.

**Effect of changing:**
- **Decrease (0.3-1.0s):** Clips end quickly after the last shot. Good for fast-paced compilations.
- **Increase (2.0-4.0s):** Includes reaction shots, point celebration, or ball rolling to a stop. Better for complete point context.

**When to adjust:** Match your pre-roll setting for balanced clips, or use asymmetric values (short pre, longer post) to see point outcomes.

---

#### `merge_gap` (Default: 0.5s)

**What it does:** After padding is applied, segments with gaps smaller than this value are merged into a single continuous clip.

**Effect of changing:**
- **Decrease (0.0-0.2s):** Only merge truly overlapping segments. Results in more separate clips.
- **Increase (1.0-3.0s):** Aggressively merges nearby segments. Creates longer, continuous clips with fewer cuts.

**When to adjust:** If your output has awkward tiny gaps between clips, increase this. If separate points are being merged together, decrease it.

---

### Video Validation

These parameters control the motion detection that validates audio-detected segments.

#### `motion_area_threshold` (Default: 500)

**What it does:** Minimum number of pixels that must show motion for a segment to be considered valid. Segments with less motion are rejected as false positives.

**Effect of changing:**
- **Decrease (100-300):** More lenient validation. Keeps segments with minimal motion. Use for static camera angles or distant shots.
- **Increase (750-1500):** Stricter validation. Requires significant player movement. Use for noisy audio with many false detections.
- **Set to 0:** Disables validation entirely. All audio-detected segments are kept.

**When to adjust:** If legitimate rallies are being rejected (shown in red on the timeline), decrease this value. If false positives are getting through, increase it.

---

#### `video_sample_stride` (Default: 10)

**What it does:** Number of frames to skip between samples during motion analysis. A stride of 10 means only every 10th frame is analyzed.

**Effect of changing:**
- **Decrease (3-5):** More frames analyzed, more accurate motion detection, but slower processing.
- **Increase (15-30):** Faster processing, but may miss brief motion or give less accurate scores.

**When to adjust:** For long videos where processing time matters, increase stride. For short clips where accuracy is critical, decrease it.

---

#### `motion_pixel_threshold` (Default: 25)

**What it does:** Intensity difference (0-255) between consecutive frames required for a pixel to be counted as "moving."

**Effect of changing:**
- **Decrease (10-20):** More sensitive to subtle motion like slight camera shake or small movements. May count noise as motion.
- **Increase (30-50):** Only significant motion is detected. Ignores minor movements and compression artifacts.

**When to adjust:** If segments are being incorrectly validated (false motion detected), increase this. If legitimate segments with subtle movement are rejected, decrease it.

---

### Troubleshooting Guide

| Problem | Parameter to Adjust | Direction |
|---------|-------------------|-----------|
| Too many false hit detections | `onset_threshold_lambda` | Increase |
| Missing quiet shots (slices, drops) | `onset_threshold_lambda` | Decrease |
| Double-detection of single hits | `peak_min_distance_sec` | Increase |
| Missing fast volley exchanges | `peak_min_distance_sec` | Decrease |
| Wind/crowd noise causing false hits | `bandpass_low` | Increase |
| Shoe squeaks detected as hits | `bandpass_high` | Decrease |
| Want individual shots, not rallies | `cluster_max_gap_sec` | Decrease to 0.5-1.0s |
| Rallies split into multiple segments | `cluster_max_gap_sec` | Increase |
| Isolated false positives in output | `cluster_min_hits` | Increase to 2+ |
| Valid rallies rejected (red on timeline) | `motion_area_threshold` | Decrease |
| False positives passing validation | `motion_area_threshold` | Increase |

## Programmatic Usage

```python
from src.pipeline import TennisCropper

# Create pipeline with custom parameters
cropper = TennisCropper(
    bandpass_low=200,
    bandpass_high=3000,
    onset_threshold_lambda=2.0,
    cluster_max_gap_sec=3.0,
    motion_area_threshold=500,
)

# Process video
result = cropper.process(
    "match.mp4",
    output_path="highlights.mp4",
    skip_validation=False,
)

print(f"Found {len(result.merged_intervals)} rallies")
print(f"Compression: {result.compression_ratio:.1f}%")
print(f"Processing time: {result.total_processing_time:.1f}s")
```

## Algorithm Details

### Audio Pipeline
1. Load audio, downsample to 16kHz mono
2. Apply 4th-order Butterworth bandpass filter (200-3000 Hz)
3. Compute STFT and spectral flux (onset strength)
4. Apply adaptive threshold: `median(window) + λ × std(window)`
5. Find peaks with minimum distance constraint
6. Cluster peaks into rallies using gap tolerance
7. Add pre/post padding

### Video Pipeline
1. For each audio-detected segment:
   - Seek to segment start
   - Sample frames at stride (every 10th frame)
   - Resize to 320×180 grayscale
   - Compute frame differences
   - Count motion pixels above threshold
2. Reject segments with insufficient motion

## Performance

- **Audio analysis**: ~30-60 seconds for a 3-hour video
- **Video validation**: ~2-3 minutes (targeted, not full video)
- **Typical compression**: 70-85% (keeps 15-30% of original)

## License

MIT

