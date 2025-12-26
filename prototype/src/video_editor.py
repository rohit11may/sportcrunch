"""
ClipEditor: Extracts and concatenates video segments.

Uses moviepy for video editing operations:
- Extract subclips at validated intervals
- Merge overlapping intervals
- Concatenate into final summary video
"""

import os
from typing import List, Tuple, Optional
from dataclasses import dataclass
from moviepy import VideoFileClip, concatenate_videoclips
import tempfile


@dataclass
class ExportResult:
    """Result of video export operation."""
    input_path: str
    output_path: str
    input_duration: float
    output_duration: float
    segments_count: int
    compression_ratio: float  # Percentage of video kept


class ClipEditor:
    """
    Extracts and concatenates video segments into a summary.
    
    Features:
    - Merges overlapping intervals
    - Handles edge cases (segments at video boundaries)
    - Provides export progress feedback
    """
    
    def __init__(self, video_path: str):
        self.video_path = video_path
        self._clip: Optional[VideoFileClip] = None
        self._duration: float = 0.0
    
    def load(self) -> float:
        """Load video and return duration."""
        self._clip = VideoFileClip(self.video_path)
        self._duration = self._clip.duration
        return self._duration
    
    def merge_intervals(
        self, 
        intervals: List[Tuple[float, float]]
    ) -> List[Tuple[float, float]]:
        """
        Merge overlapping or adjacent intervals.
        
        Args:
            intervals: List of (start, end) tuples
            
        Returns:
            List of merged, non-overlapping intervals
        """
        if not intervals:
            return []
        
        # Sort by start time
        sorted_intervals = sorted(intervals, key=lambda x: x[0])
        
        merged = [sorted_intervals[0]]
        
        for current_start, current_end in sorted_intervals[1:]:
            last_start, last_end = merged[-1]
            
            # Check for overlap or adjacency (within 0.5s)
            if current_start <= last_end + 0.5:
                # Merge by extending the end
                merged[-1] = (last_start, max(last_end, current_end))
            else:
                merged.append((current_start, current_end))
        
        # Clamp to video duration
        merged = [
            (max(0, start), min(self._duration, end))
            for start, end in merged
        ]
        
        # Remove invalid intervals
        merged = [(s, e) for s, e in merged if e > s]
        
        return merged
    
    def extract_and_export(
        self,
        intervals: List[Tuple[float, float]],
        output_path: str,
        merge_overlapping: bool = True,
        progress_callback: Optional[callable] = None,
    ) -> ExportResult:
        """
        Extract segments and export as a single video.
        
        Args:
            intervals: List of (start, end) tuples in seconds
            output_path: Path for output video file
            merge_overlapping: Whether to merge overlapping intervals
            progress_callback: Optional callback(message) for status updates
            
        Returns:
            ExportResult with export statistics
        """
        if self._clip is None:
            self.load()
        
        if progress_callback:
            progress_callback("Preparing intervals...")
        
        # Merge overlapping intervals if requested
        if merge_overlapping:
            intervals = self.merge_intervals(intervals)
        
        if not intervals:
            raise ValueError("No valid intervals to export")
        
        if progress_callback:
            progress_callback(f"Extracting {len(intervals)} segments...")
        
        # Extract subclips (moviepy 2.x uses subclipped instead of subclip)
        subclips = []
        for i, (start, end) in enumerate(intervals):
            if progress_callback:
                progress_callback(f"Extracting segment {i+1}/{len(intervals)}...")
            
            subclip = self._clip.subclipped(start, end)
            subclips.append(subclip)
        
        if progress_callback:
            progress_callback("Concatenating segments...")
        
        # Concatenate all subclips
        final_clip = concatenate_videoclips(subclips, method="compose")
        
        if progress_callback:
            progress_callback("Writing output file...")
        
        # Write output
        final_clip.write_videofile(
            output_path,
            codec="libx264",
            audio_codec="aac",
            temp_audiofile=tempfile.mktemp(suffix=".m4a"),
            remove_temp=True,
            logger=None,  # Suppress moviepy's verbose logging
        )
        
        # Calculate statistics
        output_duration = sum(end - start for start, end in intervals)
        compression_ratio = (1 - output_duration / self._duration) * 100
        
        # Clean up subclips
        for clip in subclips:
            clip.close()
        final_clip.close()
        
        if progress_callback:
            progress_callback("Export complete!")
        
        return ExportResult(
            input_path=self.video_path,
            output_path=output_path,
            input_duration=self._duration,
            output_duration=output_duration,
            segments_count=len(intervals),
            compression_ratio=compression_ratio,
        )
    
    def get_intervals_preview(
        self, 
        intervals: List[Tuple[float, float]]
    ) -> dict:
        """
        Get preview statistics for intervals without exporting.
        
        Returns dict with duration stats and timeline visualization data.
        """
        if self._clip is None:
            self.load()
        
        merged = self.merge_intervals(intervals)
        total_kept = sum(end - start for start, end in merged)
        total_removed = self._duration - total_kept
        
        return {
            "input_duration": self._duration,
            "output_duration": total_kept,
            "removed_duration": total_removed,
            "compression_ratio": (1 - total_kept / self._duration) * 100,
            "segments_count": len(merged),
            "intervals": merged,
        }
    
    def close(self):
        """Release video resources."""
        if self._clip is not None:
            self._clip.close()
            self._clip = None
    
    def __enter__(self):
        self.load()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        return False

