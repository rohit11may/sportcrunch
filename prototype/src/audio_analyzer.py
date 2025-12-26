"""
TennisAudioAnalyzer: Detects racket-ball impacts using audio signal processing.

The acoustic signature of a tennis hit is characterized by:
- Broadband impulse with energy concentrated in 200-3000 Hz
- Near-instantaneous attack with rapid decay (<50ms)
- High spectral flux (sudden change in frequency content)
"""

import numpy as np
from scipy.signal import butter, filtfilt
from scipy.ndimage import maximum_filter1d
import librosa
from dataclasses import dataclass
from typing import List, Tuple, Optional
import warnings

warnings.filterwarnings("ignore", category=FutureWarning)


@dataclass
class AudioAnalysisResult:
    """Container for intermediate analysis data (for visualization)."""
    sample_rate: int
    duration: float
    
    # Raw and filtered waveforms (downsampled for display)
    waveform_times: np.ndarray
    waveform_raw: np.ndarray
    waveform_filtered: np.ndarray
    
    # Onset detection
    onset_times: np.ndarray
    onset_strength: np.ndarray
    onset_threshold: np.ndarray
    
    # Detected peaks (hit timestamps)
    peak_times: np.ndarray
    peak_strengths: np.ndarray
    
    # Clustered rallies
    rally_intervals: List[Tuple[float, float]]
    rally_hit_counts: List[int]


class TennisAudioAnalyzer:
    """
    Analyzes audio to detect tennis racket-ball impacts.
    
    Pipeline:
    1. Load audio, downsample to target sample rate
    2. Apply bandpass filter (200-3000 Hz) to isolate hit frequencies
    3. Compute onset strength (spectral flux)
    4. Apply adaptive threshold to find peaks
    5. Cluster peaks into rally intervals
    """
    
    def __init__(
        self,
        sample_rate: int = 16000,
        bandpass_low: float = 200,
        bandpass_high: float = 3000,
        onset_threshold_lambda: float = 2.0,
        peak_min_distance_sec: float = 0.5,
        cluster_max_gap_sec: float = 3.0,
        cluster_min_hits: int = 2,
        padding_pre_sec: float = 2.0,
        padding_post_sec: float = 2.0,
    ):
        self.sample_rate = sample_rate
        self.bandpass_low = bandpass_low
        self.bandpass_high = bandpass_high
        self.onset_threshold_lambda = onset_threshold_lambda
        self.peak_min_distance_sec = peak_min_distance_sec
        self.cluster_max_gap_sec = cluster_max_gap_sec
        self.cluster_min_hits = cluster_min_hits
        self.padding_pre_sec = padding_pre_sec
        self.padding_post_sec = padding_post_sec
        
        # Intermediate data for visualization
        self._last_result: Optional[AudioAnalysisResult] = None
    
    def analyze(self, audio_path: str) -> AudioAnalysisResult:
        """
        Full analysis pipeline: load audio, detect hits, cluster into rallies.
        
        Args:
            audio_path: Path to audio file or video file (audio will be extracted)
            
        Returns:
            AudioAnalysisResult with all intermediate data for visualization
        """
        # Step 1: Load and downsample audio
        y, sr = librosa.load(audio_path, sr=self.sample_rate, mono=True)
        duration = len(y) / sr
        
        # Step 2: Apply bandpass filter
        y_filtered = self._apply_bandpass(y, sr)
        
        # Step 3: Compute onset strength (spectral flux)
        onset_env = librosa.onset.onset_strength(
            y=y_filtered, 
            sr=sr,
            hop_length=512,
            aggregate=np.median,
        )
        onset_times = librosa.times_like(onset_env, sr=sr, hop_length=512)
        
        # Step 4: Compute adaptive threshold
        threshold = self._compute_adaptive_threshold(onset_env, sr)
        
        # Step 5: Find peaks above threshold
        peak_indices, peak_strengths = self._find_peaks(onset_env, threshold, sr)
        peak_times = onset_times[peak_indices] if len(peak_indices) > 0 else np.array([])
        
        # Step 6: Cluster peaks into rallies
        rally_intervals, rally_hit_counts = self._cluster_peaks(peak_times)
        
        # Prepare visualization data (downsample waveform for display)
        display_sr = 1000  # 1000 samples per second for display
        downsample_factor = max(1, sr // display_sr)
        waveform_display = y[::downsample_factor]
        waveform_filtered_display = y_filtered[::downsample_factor]
        waveform_times = np.linspace(0, duration, len(waveform_display))
        
        self._last_result = AudioAnalysisResult(
            sample_rate=sr,
            duration=duration,
            waveform_times=waveform_times,
            waveform_raw=waveform_display,
            waveform_filtered=waveform_filtered_display,
            onset_times=onset_times,
            onset_strength=onset_env,
            onset_threshold=threshold,
            peak_times=peak_times,
            peak_strengths=peak_strengths,
            rally_intervals=rally_intervals,
            rally_hit_counts=rally_hit_counts,
        )
        
        return self._last_result
    
    def _apply_bandpass(self, y: np.ndarray, sr: int) -> np.ndarray:
        """Apply Butterworth bandpass filter to isolate racket hit frequencies."""
        nyquist = sr / 2
        low = self.bandpass_low / nyquist
        high = self.bandpass_high / nyquist
        
        # Clamp to valid range
        low = max(0.001, min(low, 0.999))
        high = max(low + 0.001, min(high, 0.999))
        
        b, a = butter(N=4, Wn=[low, high], btype='band')
        y_filtered = filtfilt(b, a, y)
        
        return y_filtered
    
    def _compute_adaptive_threshold(
        self, 
        onset_env: np.ndarray, 
        sr: int,
        window_sec: float = 5.0
    ) -> np.ndarray:
        """
        Compute adaptive threshold: local_median + lambda * local_std
        
        This handles varying recording levels and background noise.
        """
        hop_length = 512
        fps = sr / hop_length
        window_frames = int(window_sec * fps)
        
        if window_frames < 3:
            window_frames = 3
        if window_frames % 2 == 0:
            window_frames += 1
        
        # Compute rolling statistics using efficient methods
        from scipy.ndimage import uniform_filter1d, generic_filter1d
        
        # Rolling median approximation using uniform filter (faster than true median)
        local_mean = uniform_filter1d(onset_env, size=window_frames, mode='reflect')
        
        # Rolling std
        local_sq_mean = uniform_filter1d(onset_env**2, size=window_frames, mode='reflect')
        local_std = np.sqrt(np.maximum(local_sq_mean - local_mean**2, 0))
        
        threshold = local_mean + self.onset_threshold_lambda * local_std
        
        return threshold
    
    def _find_peaks(
        self, 
        onset_env: np.ndarray, 
        threshold: np.ndarray,
        sr: int
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Find peaks in onset envelope that exceed the adaptive threshold."""
        hop_length = 512
        fps = sr / hop_length
        min_distance_frames = int(self.peak_min_distance_sec * fps)
        
        if min_distance_frames < 1:
            min_distance_frames = 1
        
        # Find local maxima
        local_max = maximum_filter1d(onset_env, size=min_distance_frames * 2 + 1)
        is_peak = (onset_env == local_max)
        
        # Apply threshold
        is_above_threshold = onset_env > threshold
        
        # Combine conditions
        peak_mask = is_peak & is_above_threshold
        peak_indices = np.where(peak_mask)[0]
        peak_strengths = onset_env[peak_indices]
        
        return peak_indices, peak_strengths
    
    def _cluster_peaks(
        self, 
        peak_times: np.ndarray
    ) -> Tuple[List[Tuple[float, float]], List[int]]:
        """
        Cluster detected peaks into rally intervals.
        
        Algorithm:
        - Group consecutive peaks where gap < max_gap
        - Filter clusters with fewer than min_hits
        - Add padding before first and after last hit
        """
        if len(peak_times) == 0:
            return [], []
        
        # Sort peaks (should already be sorted, but ensure)
        peak_times = np.sort(peak_times)
        
        # Find cluster boundaries
        clusters = []
        current_cluster = [peak_times[0]]
        
        for i in range(1, len(peak_times)):
            gap = peak_times[i] - peak_times[i-1]
            
            if gap <= self.cluster_max_gap_sec:
                current_cluster.append(peak_times[i])
            else:
                # Save current cluster and start new one
                if len(current_cluster) >= self.cluster_min_hits:
                    clusters.append(current_cluster)
                current_cluster = [peak_times[i]]
        
        # Don't forget the last cluster
        if len(current_cluster) >= self.cluster_min_hits:
            clusters.append(current_cluster)
        
        # Convert to intervals with padding
        intervals = []
        hit_counts = []
        
        for cluster in clusters:
            start = max(0, cluster[0] - self.padding_pre_sec)
            end = cluster[-1] + self.padding_post_sec
            intervals.append((start, end))
            hit_counts.append(len(cluster))
        
        return intervals, hit_counts
    
    def get_candidate_intervals(self) -> List[Tuple[float, float]]:
        """Return the rally intervals from the last analysis."""
        if self._last_result is None:
            return []
        return self._last_result.rally_intervals
    
    @property
    def last_result(self) -> Optional[AudioAnalysisResult]:
        """Access the full result from the last analysis."""
        return self._last_result

