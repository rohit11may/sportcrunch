"""
Tunable parameters for the tennis rally detection pipeline.
These values can be adjusted via the Streamlit UI during development.
"""

# Audio Processing
AUDIO_SAMPLE_RATE = 16000  # Hz - downsample for efficiency
BANDPASS_LOW = 200         # Hz - removes wind rumble
BANDPASS_HIGH = 3000       # Hz - preserves racket crack, removes hiss

# Onset Detection
ONSET_THRESHOLD_LAMBDA = 2.0  # Multiplier for adaptive threshold (median + λ*std)
PEAK_MIN_DISTANCE_SEC = 0.5   # Minimum seconds between detected hits

# Rally Clustering
CLUSTER_MAX_GAP_SEC = 3.0   # Max gap (seconds) between hits in same rally
CLUSTER_MIN_HITS = 2        # Minimum hits to consider a valid rally

# Padding
PADDING_PRE_SEC = 2.0   # Seconds to add before first hit
PADDING_POST_SEC = 2.0  # Seconds to add after last hit

# Video Motion Validation
VIDEO_SAMPLE_STRIDE = 10       # Frames to skip during motion analysis
VIDEO_THUMB_SIZE = (320, 180)  # Resolution for motion analysis
MOTION_PIXEL_THRESHOLD = 25    # Intensity diff to count as motion
MOTION_AREA_THRESHOLD = 500    # Minimum motion pixels for "active" segment


def get_default_params() -> dict:
    """Return all parameters as a dictionary for UI binding."""
    return {
        "audio_sample_rate": AUDIO_SAMPLE_RATE,
        "bandpass_low": BANDPASS_LOW,
        "bandpass_high": BANDPASS_HIGH,
        "onset_threshold_lambda": ONSET_THRESHOLD_LAMBDA,
        "peak_min_distance_sec": PEAK_MIN_DISTANCE_SEC,
        "cluster_max_gap_sec": CLUSTER_MAX_GAP_SEC,
        "cluster_min_hits": CLUSTER_MIN_HITS,
        "padding_pre_sec": PADDING_PRE_SEC,
        "padding_post_sec": PADDING_POST_SEC,
        "video_sample_stride": VIDEO_SAMPLE_STRIDE,
        "video_thumb_size": VIDEO_THUMB_SIZE,
        "motion_pixel_threshold": MOTION_PIXEL_THRESHOLD,
        "motion_area_threshold": MOTION_AREA_THRESHOLD,
    }

