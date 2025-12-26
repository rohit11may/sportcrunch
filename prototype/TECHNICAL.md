# Technical Deep Dive: Tennis Rally Detection Algorithm

This document explains the signal processing and computer vision techniques used to automatically detect tennis rallies from match videos.

## Table of Contents

1. [Overview](#overview)
2. [Pipeline Architecture](#pipeline-architecture)
3. [Audio Analysis](#audio-analysis)
   - [Loading and Preprocessing](#loading-and-preprocessing)
   - [Bandpass Filtering](#bandpass-filtering)
   - [Onset Detection (Spectral Flux)](#onset-detection-spectral-flux)
   - [Adaptive Thresholding](#adaptive-thresholding)
   - [Peak Finding](#peak-finding)
   - [Rally Clustering](#rally-clustering)
4. [Video Validation](#video-validation)
   - [Frame Differencing](#frame-differencing)
   - [Motion Scoring](#motion-scoring)
5. [Interval Merging](#interval-merging)
6. [Why This Works](#why-this-works)

---

## Overview

The goal is to remove "dead time" (ball retrieval, changeovers, replays) from tennis videos while keeping all the action. The algorithm uses a **propose-and-verify** architecture:

1. **Audio analysis** proposes candidate segments by detecting the distinctive sound of racket-ball impacts
2. **Video validation** verifies each candidate by checking for player movement
3. **Merging** combines overlapping segments into the final output

This approach is fast because audio processing is computationally cheap, and video analysis is only done on the proposed segments (typically 15-30% of the video), not the entire recording.

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INPUT VIDEO                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AUDIO ANALYSIS (Fast)                               │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │  Load &  │ → │ Bandpass │ → │ Spectral │ → │ Adaptive │ → │  Peak    │  │
│  │ Resample │   │  Filter  │   │   Flux   │   │ Threshold│   │ Finding  │  │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘  │
│                                                                              │
│                              ↓ Detected Hits (timestamps)                    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    CLUSTERING → Rally Intervals                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼ Candidate Segments
┌─────────────────────────────────────────────────────────────────────────────┐
│                       VIDEO VALIDATION (Targeted)                            │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │ Seek to Each │ → │ Sample Every │ → │    Frame     │ → │   Motion     │ │
│  │   Segment    │   │  Nth Frame   │   │ Differencing │   │   Scoring    │ │
│  └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼ Validated Segments
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MERGE & EXPORT                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │     Merge Overlapping Intervals → Extract Clips → Concatenate        │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             OUTPUT VIDEO                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Audio Analysis

The audio pipeline exploits the fact that a tennis racket hitting a ball produces a distinctive sound: a sharp, broadband impulse with energy concentrated between 200-3000 Hz.

### Loading and Preprocessing

**What happens:** The audio track is extracted from the video and resampled to 16 kHz mono.

**Why 16 kHz?** The highest frequency we care about is ~3 kHz (racket impacts). By the Nyquist theorem, we need at least 6 kHz sampling rate. 16 kHz gives us plenty of headroom while reducing data size by ~66% compared to CD-quality audio (44.1 kHz).

**Why mono?** Stereo channels would double our processing time with no benefit—we only care about *when* hits occur, not their spatial location.

```python
# Using librosa for audio loading
y, sr = librosa.load(video_path, sr=16000, mono=True)
```

### Bandpass Filtering

**The problem:** Raw audio contains unwanted sounds—wind rumble (low frequencies), crowd noise, shoe squeaks, and hiss (high frequencies). We need to isolate the frequencies where racket impacts have the most energy.

**The solution:** A **Butterworth bandpass filter** that only allows frequencies between 200 Hz and 3000 Hz to pass through.

#### How a Butterworth Filter Works

A Butterworth filter is designed to have a maximally flat frequency response in the passband (no ripples). The filter is defined by:

- **Order (N):** How steep the rolloff is. We use 4th order, which gives -24 dB/octave rolloff.
- **Cutoff frequencies:** The -3 dB points where the filter starts attenuating.

The transfer function magnitude for a Butterworth lowpass filter is:

$$|H(f)|^2 = \frac{1}{1 + (f/f_c)^{2N}}$$

Where:
- $f$ is the frequency
- $f_c$ is the cutoff frequency  
- $N$ is the filter order

For a bandpass filter, we combine a highpass and lowpass filter:

$$|H(f)|^2 = \frac{1}{1 + (f_{low}/f)^{2N}} \cdot \frac{1}{1 + (f/f_{high})^{2N}}$$

**Intuitive explanation:** Imagine a graphic equalizer. The bandpass filter is like turning down the bass (below 200 Hz) and treble (above 3000 Hz) knobs all the way, while keeping the midrange at full volume. This lets the "thwack" of the racket through while filtering out rumble and hiss.

```python
from scipy.signal import butter, filtfilt

# Normalize frequencies to Nyquist (0 to 1 range)
nyquist = sample_rate / 2
low = 200 / nyquist   # 0.025 at 16kHz
high = 3000 / nyquist # 0.375 at 16kHz

# Design 4th-order Butterworth bandpass filter
b, a = butter(N=4, Wn=[low, high], btype='band')

# Apply filter (forward-backward for zero phase distortion)
y_filtered = filtfilt(b, a, y)
```

**Why `filtfilt`?** Applying a filter normally introduces phase delay (different frequencies are delayed by different amounts). `filtfilt` applies the filter forward, then backward, which cancels out the phase distortion and keeps transients sharp. This is crucial for accurate timing.

### Onset Detection (Spectral Flux)

**The problem:** We have filtered audio, but we need to find the exact moments when hits occur. Hits are characterized by a sudden change in the audio spectrum.

**The solution:** Compute **spectral flux** (also called "onset strength") which measures how much the frequency content changes between consecutive time windows.

#### Short-Time Fourier Transform (STFT)

First, we divide the audio into overlapping windows and compute the frequency spectrum of each window using the Fast Fourier Transform (FFT).

**Parameters:**
- **Window size:** 2048 samples = 128ms at 16kHz. This determines frequency resolution.
- **Hop length:** 512 samples = 32ms. This is how much we advance between windows.

The STFT gives us a **spectrogram**: a 2D representation where:
- X-axis = time (each column is one window)
- Y-axis = frequency (each row is one frequency bin)
- Value = magnitude of that frequency at that time

#### Computing Spectral Flux

Spectral flux measures the positive change in spectral magnitude between consecutive frames:

$$SF(t) = \sum_{k=0}^{N/2} H(|X(t,k)| - |X(t-1,k)|)$$

Where:
- $X(t,k)$ is the magnitude of frequency bin $k$ at time $t$
- $H(x) = \max(0, x)$ is the half-wave rectifier (only count increases)
- $N$ is the FFT size

**Intuitive explanation:** A tennis hit creates a burst of energy across many frequencies simultaneously. Spectral flux captures this by summing up all the frequency bins that got louder compared to the previous frame. A hit produces a spike; steady-state sounds (crowd noise, commentary) produce low, constant values.

```python
import librosa

# Compute onset strength (librosa handles the STFT internally)
onset_env = librosa.onset.onset_strength(
    y=y_filtered, 
    sr=16000,
    hop_length=512,      # 32ms between frames
    aggregate=np.median, # Use median for robustness
)
```

**Why median aggregation?** When aggregating across frequency bands, median is more robust to outliers than mean. A single dominant frequency (like a referee's whistle) won't skew the result.

### Adaptive Thresholding

**The problem:** Recording levels vary wildly. A hit in a quiet recording might have lower absolute onset strength than background noise in a loud recording. A fixed threshold won't work.

**The solution:** An **adaptive threshold** that adjusts to local audio conditions:

$$threshold(t) = \mu_{local}(t) + \lambda \cdot \sigma_{local}(t)$$

Where:
- $\mu_{local}(t)$ is the local mean of onset strength around time $t$
- $\sigma_{local}(t)$ is the local standard deviation
- $\lambda$ is a sensitivity parameter (default 2.0)

#### Rolling Statistics

We compute mean and standard deviation over a sliding window (default 5 seconds):

```python
from scipy.ndimage import uniform_filter1d

window_frames = int(5.0 * frames_per_second)

# Rolling mean
local_mean = uniform_filter1d(onset_env, size=window_frames)

# Rolling standard deviation
local_sq_mean = uniform_filter1d(onset_env**2, size=window_frames)
local_std = np.sqrt(local_sq_mean - local_mean**2)

# Adaptive threshold
threshold = local_mean + lambda_param * local_std
```

**Intuitive explanation:** The threshold adapts to the current "noise floor." In a quiet section, the threshold is low, so subtle hits are detected. In a loud section (crowd cheering), the threshold rises, so only clear hits above the noise are detected.

**The λ parameter:** This controls sensitivity:
- λ = 1.5: Detects hits at 1.5 standard deviations above mean (more sensitive)
- λ = 2.0: Detects hits at 2 standard deviations above mean (default)
- λ = 3.0: Detects hits at 3 standard deviations above mean (strict)

Statistically, if onset strength were normally distributed:
- λ = 1: ~16% of points would exceed threshold
- λ = 2: ~2.3% of points would exceed threshold
- λ = 3: ~0.13% of points would exceed threshold

### Peak Finding

**The problem:** We have an onset strength curve and an adaptive threshold. When the curve exceeds the threshold, that indicates a hit. But hits cause *spikes*, not just any crossing. We need to find the *peaks* of these spikes.

**The solution:** Find local maxima that exceed the threshold, with a minimum distance constraint.

#### Local Maximum Detection

A point is a local maximum if it's the highest value within a window around it:

```python
from scipy.ndimage import maximum_filter1d

min_distance_frames = int(0.5 * frames_per_second)  # 0.5 seconds

# Find local maxima: points equal to the max in their neighborhood
local_max = maximum_filter1d(onset_env, size=min_distance_frames * 2 + 1)
is_peak = (onset_env == local_max)

# Keep only peaks that exceed threshold
is_above_threshold = (onset_env > threshold)
peak_mask = is_peak & is_above_threshold

peak_indices = np.where(peak_mask)[0]
```

**Why minimum distance?** Two detections less than 0.5 seconds apart are likely the same hit being double-counted (maybe the racket sound plus the ball bounce). The minimum distance ensures we only count each hit once.

### Rally Clustering

**The problem:** We have a list of hit timestamps. We need to group them into rally segments (continuous action) vs. dead time.

**The solution:** Sequential clustering with a maximum gap threshold.

#### Algorithm

```
Initialize: first_hit → current_cluster
For each subsequent hit:
    If gap to previous hit ≤ max_gap:
        Add hit to current_cluster
    Else:
        Save current_cluster (if enough hits)
        Start new_cluster with this hit
Save final cluster (if enough hits)

For each cluster:
    interval = (first_hit - pre_padding, last_hit + post_padding)
```

**Parameters:**
- `max_gap` (default 3.0s): Maximum time between consecutive hits in the same rally
- `min_hits` (default 2): Minimum hits required to keep a cluster
- `pre_padding` (default 2.0s): Buffer before first hit
- `post_padding` (default 2.0s): Buffer after last hit

**Intuitive explanation:** If two hits are more than 3 seconds apart, they're probably from different points (player retrieving ball, taking position, etc.). Hits closer together are grouped into the same rally.

---

## Video Validation

Audio detection can produce false positives (ball bounces, crowd claps, equipment sounds). Video validation confirms that the proposed segments actually contain player movement.

### Frame Differencing

**The concept:** If there's action in a video segment, consecutive frames will be different (players moving). If the segment is a false positive (maybe just noise during a changeover), frames will be nearly identical (static camera, no movement).

#### Sampling Strategy

Instead of analyzing every frame (expensive), we sample frames at a stride:

```python
# At 30 fps with stride=10, we analyze 3 frames/second
for frame_idx in range(start_frame, end_frame, stride):
    frame = read_frame(frame_idx)
    # ... process frame
```

**Why stride?** A 10-second segment at 30fps has 300 frames. Analyzing all of them is slow and unnecessary. Sampling every 10th frame (30 frames total) is 10x faster and sufficient to detect motion.

#### Thumbnail Downscaling

Before computing differences, frames are downscaled to 320×180:

```python
thumbnail = cv2.resize(frame, (320, 180))
gray = cv2.cvtColor(thumbnail, cv2.COLOR_BGR2GRAY)
```

**Why downscale?** 
1. **Speed:** 320×180 = 57,600 pixels vs. 1920×1080 = 2,073,600 pixels (36x less data)
2. **Noise reduction:** Downscaling naturally smooths out compression artifacts
3. **Sufficient for motion:** We're detecting large movements (players running), not fine details

### Motion Scoring

For each pair of consecutive frames, we compute a motion score:

```python
# Absolute difference between frames
diff = cv2.absdiff(frame_a, frame_b)

# Threshold to binary: pixels with diff > 25 are "motion pixels"
_, binary = cv2.threshold(diff, 25, 255, cv2.THRESH_BINARY)

# Count motion pixels
motion_score = np.count_nonzero(binary)
```

**The math:**

$$motion\_score = \sum_{x,y} \mathbf{1}[|I_t(x,y) - I_{t-1}(x,y)| > \tau]$$

Where:
- $I_t(x,y)$ is the grayscale intensity at pixel $(x,y)$ at time $t$
- $\tau$ is the motion pixel threshold (default 25)
- $\mathbf{1}[\cdot]$ is the indicator function (1 if true, 0 if false)

#### Segment Validation

The segment's overall motion score is the average of all frame-pair scores:

$$segment\_score = \frac{1}{N-1} \sum_{i=1}^{N-1} motion\_score(frame_i, frame_{i+1})$$

A segment is **valid** if `segment_score ≥ motion_area_threshold` (default 500).

**Intuitive explanation:** If the average motion is 500 pixels changing per frame pair (out of 57,600 total pixels = 0.87%), there's enough movement to confirm this is real action. Static segments (false positives) will have near-zero scores.

---

## Interval Merging

After validation, we may have overlapping intervals (due to padding). These need to be merged.

### Algorithm

```
Sort intervals by start time
merged = [first_interval]

For each subsequent interval:
    If interval.start ≤ merged[-1].end + gap_tolerance:
        merged[-1].end = max(merged[-1].end, interval.end)
    Else:
        merged.append(interval)
```

**Example:**
```
Input:  [(0, 5), (4, 8), (10, 15), (20, 25)]
With gap_tolerance = 0.5:
  - (0, 5) and (4, 8) overlap → merge to (0, 8)
  - (10, 15) doesn't overlap with (0, 8) → keep separate
  - (20, 25) doesn't overlap with (10, 15) → keep separate
Output: [(0, 8), (10, 15), (20, 25)]
```

---

## Why This Works

### The Physics of Tennis Sounds

A tennis racket hitting a ball creates a distinctive acoustic signature:

1. **Broadband impulse:** Energy spread across many frequencies (200-3000+ Hz)
2. **Fast attack:** Rise time < 10ms
3. **Rapid decay:** Sound dies out within 50-100ms
4. **High amplitude:** One of the loudest sounds in a match

This is in contrast to other sounds:
- **Crowd noise:** Lower frequency, sustained, no sharp attack
- **Commentary:** Speech frequencies (80-3000 Hz), but sustained patterns
- **Ball bounce:** Similar but lower amplitude, no racket resonance
- **Shoe squeak:** Higher frequency (3000-8000 Hz), filtered out by bandpass

### Why "Propose and Verify"?

**Efficiency:** Audio analysis of a 3-hour video takes 30-60 seconds. Full video analysis would take 30+ minutes. By using audio to narrow down candidates first, we only need to validate ~20% of the video.

**Accuracy:** Audio gives timestamp precision (within 32ms). Video gives semantic verification (is there actually motion?). Together, they're more accurate than either alone.

**Robustness:** If audio produces false positives (ball bounces), video rejects them. If audio misses quiet hits, that segment might still be included due to padding from nearby hits.

### Tuning Philosophy

The algorithm has many parameters, but they fall into categories:

1. **Sensitivity (λ, thresholds):** Trade-off between false positives and false negatives
2. **Temporal (gaps, padding):** Trade-off between granularity and completeness
3. **Performance (stride, resolution):** Trade-off between speed and accuracy

For most tennis videos, the defaults work well. Parameter tuning is mainly needed for:
- Unusual recording conditions (very noisy, very quiet)
- Different output goals (individual shots vs. complete rallies)
- Edge cases (fast doubles exchanges, very slow-paced matches)

---

## References

- Librosa onset detection: https://librosa.org/doc/main/onset.html
- Butterworth filter design: https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.butter.html
- Frame differencing for motion detection: OpenCV tutorials

## Implementation Files

- [`src/audio_analyzer.py`](src/audio_analyzer.py) - Hit detection from audio
- [`src/video_validator.py`](src/video_validator.py) - Motion validation
- [`src/pipeline.py`](src/pipeline.py) - Main orchestration
- [`src/video_editor.py`](src/video_editor.py) - Clip extraction and export

