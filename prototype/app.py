"""
Tennis Rally Detector - Development Dashboard

A Streamlit app for visualizing the tennis video processing pipeline.
Allows interactive parameter tuning and inspection of intermediate results.

Run with: streamlit run app.py
"""

import streamlit as st
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os
from pathlib import Path

# Import pipeline components
from src.pipeline import TennisCropper, PipelineResult
from src.audio_analyzer import AudioAnalysisResult
from src.video_validator import VideoValidationResult
from config.settings import get_default_params


# Page config
st.set_page_config(
    page_title="Tennis Rally Detector",
    page_icon="🎾",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Custom CSS for better styling
st.markdown("""
<style>
    .stProgress > div > div > div > div {
        background-color: #00a67d;
    }
    .metric-card {
        background-color: #1e1e1e;
        border-radius: 8px;
        padding: 16px;
        margin: 8px 0;
    }
    .segment-valid {
        color: #00c853;
    }
    .segment-invalid {
        color: #ff5252;
    }
</style>
""", unsafe_allow_html=True)


def format_time(seconds: float) -> str:
    """Format seconds as MM:SS or HH:MM:SS."""
    if seconds < 0:
        return "00:00"
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def create_waveform_plot(audio_result: AudioAnalysisResult) -> go.Figure:
    """Create interactive waveform + onset strength plot."""
    fig = make_subplots(
        rows=2, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.08,
        row_heights=[0.4, 0.6],
        subplot_titles=("Filtered Audio Waveform", "Onset Strength + Detected Hits")
    )
    
    # Waveform (downsampled for performance)
    downsample = max(1, len(audio_result.waveform_times) // 5000)
    fig.add_trace(
        go.Scatter(
            x=audio_result.waveform_times[::downsample],
            y=audio_result.waveform_filtered[::downsample],
            mode='lines',
            name='Waveform',
            line=dict(color='#4fc3f7', width=0.5),
            hovertemplate='Time: %{x:.2f}s<br>Amplitude: %{y:.3f}<extra></extra>'
        ),
        row=1, col=1
    )
    
    # Onset strength
    fig.add_trace(
        go.Scatter(
            x=audio_result.onset_times,
            y=audio_result.onset_strength,
            mode='lines',
            name='Onset Strength',
            line=dict(color='#81c784', width=1),
            hovertemplate='Time: %{x:.2f}s<br>Strength: %{y:.2f}<extra></extra>'
        ),
        row=2, col=1
    )
    
    # Threshold line
    fig.add_trace(
        go.Scatter(
            x=audio_result.onset_times,
            y=audio_result.onset_threshold,
            mode='lines',
            name='Threshold',
            line=dict(color='#ff8a65', width=1, dash='dash'),
            hovertemplate='Time: %{x:.2f}s<br>Threshold: %{y:.2f}<extra></extra>'
        ),
        row=2, col=1
    )
    
    # Detected peaks as markers
    if len(audio_result.peak_times) > 0:
        # Find corresponding strengths for peak times
        peak_strengths = []
        for pt in audio_result.peak_times:
            idx = np.searchsorted(audio_result.onset_times, pt)
            idx = min(idx, len(audio_result.onset_strength) - 1)
            peak_strengths.append(audio_result.onset_strength[idx])
        
        fig.add_trace(
            go.Scatter(
                x=audio_result.peak_times,
                y=peak_strengths,
                mode='markers',
                name='Detected Hits',
                marker=dict(color='#f44336', size=8, symbol='triangle-up'),
                hovertemplate='Hit at %{x:.2f}s<extra></extra>'
            ),
            row=2, col=1
        )
    
    # Rally interval shading
    for start, end in audio_result.rally_intervals:
        fig.add_vrect(
            x0=start, x1=end,
            fillcolor="rgba(76, 175, 80, 0.15)",
            layer="below",
            line_width=0,
            row=2, col=1
        )
    
    fig.update_layout(
        height=400,
        showlegend=True,
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        margin=dict(l=50, r=20, t=60, b=40),
        template="plotly_dark",
        hovermode='x unified'
    )
    
    fig.update_xaxes(title_text="Time (seconds)", row=2, col=1)
    fig.update_yaxes(title_text="Amplitude", row=1, col=1)
    fig.update_yaxes(title_text="Onset Strength", row=2, col=1)
    
    return fig


def create_timeline_plot(
    duration: float,
    audio_intervals: list,
    validated_intervals: list = None,
    rejected_intervals: list = None,
) -> go.Figure:
    """Create segment timeline visualization."""
    fig = go.Figure()
    
    # Background (full duration)
    fig.add_trace(
        go.Bar(
            x=[duration],
            y=["Timeline"],
            orientation='h',
            marker=dict(color='#333333'),
            name='Video Duration',
            hovertemplate=f'Total: {format_time(duration)}<extra></extra>'
        )
    )
    
    # Audio candidates (if no validation yet)
    if validated_intervals is None:
        for i, (start, end) in enumerate(audio_intervals):
            fig.add_trace(
                go.Bar(
                    x=[end - start],
                    y=["Timeline"],
                    orientation='h',
                    base=start,
                    marker=dict(color='#4fc3f7'),
                    name=f'Segment {i+1}' if i == 0 else None,
                    showlegend=(i == 0),
                    legendgroup='candidates',
                    hovertemplate=f'Segment {i+1}<br>{format_time(start)} - {format_time(end)}<br>Duration: {end-start:.1f}s<extra></extra>'
                )
            )
    else:
        # Validated segments
        for i, (start, end) in enumerate(validated_intervals):
            fig.add_trace(
                go.Bar(
                    x=[end - start],
                    y=["Timeline"],
                    orientation='h',
                    base=start,
                    marker=dict(color='#4caf50'),
                    name='Validated' if i == 0 else None,
                    showlegend=(i == 0),
                    legendgroup='validated',
                    hovertemplate=f'Rally {i+1} ✓<br>{format_time(start)} - {format_time(end)}<br>Duration: {end-start:.1f}s<extra></extra>'
                )
            )
        
        # Rejected segments
        if rejected_intervals:
            for i, (start, end) in enumerate(rejected_intervals):
                fig.add_trace(
                    go.Bar(
                        x=[end - start],
                        y=["Timeline"],
                        orientation='h',
                        base=start,
                        marker=dict(color='#f44336', opacity=0.6),
                        name='Rejected' if i == 0 else None,
                        showlegend=(i == 0),
                        legendgroup='rejected',
                        hovertemplate=f'Rejected ✗<br>{format_time(start)} - {format_time(end)}<br>Duration: {end-start:.1f}s<extra></extra>'
                    )
                )
    
    fig.update_layout(
        height=120,
        barmode='overlay',
        showlegend=True,
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        margin=dict(l=80, r=20, t=40, b=20),
        template="plotly_dark",
        xaxis=dict(title="Time (seconds)", range=[0, duration]),
        yaxis=dict(visible=False),
    )
    
    return fig


def create_motion_scores_plot(video_result: VideoValidationResult) -> go.Figure:
    """Create bar chart of motion scores per segment."""
    segments = video_result.segments
    
    labels = [f"{format_time(s.start)}" for s in segments]
    scores = [s.motion_score for s in segments]
    colors = ['#4caf50' if s.is_valid else '#f44336' for s in segments]
    
    fig = go.Figure()
    
    fig.add_trace(
        go.Bar(
            x=labels,
            y=scores,
            marker=dict(color=colors),
            hovertemplate='%{x}<br>Motion Score: %{y:.0f}<extra></extra>'
        )
    )
    
    # Threshold line
    threshold = video_result.segments[0].motion_score if segments else 500  # Fallback
    # Get actual threshold from validator params (we'll approximate)
    fig.add_hline(
        y=500,  # Default threshold
        line_dash="dash",
        line_color="#ff8a65",
        annotation_text="Threshold",
        annotation_position="right"
    )
    
    fig.update_layout(
        height=250,
        margin=dict(l=50, r=20, t=20, b=60),
        template="plotly_dark",
        xaxis=dict(title="Segment Start Time", tickangle=-45),
        yaxis=dict(title="Motion Score"),
    )
    
    return fig


def main():
    st.title("🎾 Tennis Rally Detector")
    st.caption("Development Dashboard for Pipeline Visualization")
    
    # Initialize session state
    if 'pipeline_result' not in st.session_state:
        st.session_state.pipeline_result = None
    if 'processing' not in st.session_state:
        st.session_state.processing = False
    if 'status_message' not in st.session_state:
        st.session_state.status_message = ""
    
    # Sidebar - Parameters
    with st.sidebar:
        st.header("📁 Video Input")
        
        video_path = st.text_input(
            "Video File Path",
            placeholder="/path/to/tennis_match.mp4",
            help="Enter the full path to your tennis video file"
        )
        
        st.divider()
        
        # Preset configurations
        st.header("🎯 Detection Mode")
        
        preset = st.radio(
            "Preset",
            options=["individual_shots", "rallies", "custom"],
            format_func=lambda x: {
                "individual_shots": "🎾 Individual Shots (tight clips)",
                "rallies": "🏸 Full Rallies (grouped points)", 
                "custom": "⚙️ Custom Settings"
            }[x],
            help="Quick presets for common use cases"
        )
        
        # Set defaults based on preset
        if preset == "individual_shots":
            preset_values = {
                "bandpass_low": 200,
                "bandpass_high": 3000,
                "onset_lambda": 1.8,
                "peak_distance": 0.3,
                "cluster_gap": 0.8,  # Very short - don't group shots
                "min_hits": 1,       # Keep single shots
                "padding_pre": 0.5,
                "padding_post": 0.5,
                "merge_gap": 0.2,    # Merge only overlapping
            }
        elif preset == "rallies":
            preset_values = {
                "bandpass_low": 200,
                "bandpass_high": 3000,
                "onset_lambda": 2.0,
                "peak_distance": 0.5,
                "cluster_gap": 3.0,  # Group shots into rallies
                "min_hits": 2,       # Need at least serve + return
                "padding_pre": 2.0,
                "padding_post": 2.0,
                "merge_gap": 1.0,
            }
        else:  # custom - use defaults
            defaults = get_default_params()
            preset_values = {
                "bandpass_low": defaults["bandpass_low"],
                "bandpass_high": defaults["bandpass_high"],
                "onset_lambda": defaults["onset_threshold_lambda"],
                "peak_distance": defaults["peak_min_distance_sec"],
                "cluster_gap": defaults["cluster_max_gap_sec"],
                "min_hits": defaults["cluster_min_hits"],
                "padding_pre": defaults["padding_pre_sec"],
                "padding_post": defaults["padding_post_sec"],
                "merge_gap": 0.5,
            }
        
        defaults = get_default_params()
        
        # Show/hide detailed settings
        show_advanced = st.checkbox("Show Advanced Settings", value=(preset == "custom"))
        
        if show_advanced:
            st.divider()
            st.header("⚙️ Audio Detection")
            
            bandpass_low = st.slider(
                "Bandpass Low (Hz)",
                min_value=50, max_value=500, 
                value=preset_values["bandpass_low"],
                step=10,
                help="Lower cutoff frequency for audio filtering. INCREASE (300-500 Hz) to reduce false detections from wind, crowd noise, or traffic. DECREASE (50-150 Hz) for quiet indoor recordings. Default 200 Hz works for most outdoor matches."
            )
            
            bandpass_high = st.slider(
                "Bandpass High (Hz)",
                min_value=1000, max_value=5000, 
                value=preset_values["bandpass_high"],
                step=100,
                help="Upper cutoff frequency for audio filtering. DECREASE (1500-2500 Hz) to filter out shoe squeaks, whistles, or high-pitched noise. INCREASE (4000-5000 Hz) to better capture the 'crack' of powerful shots. Default 3000 Hz balances both."
            )
            
            onset_lambda = st.slider(
                "Detection Sensitivity (λ)",
                min_value=0.5, max_value=5.0, 
                value=preset_values["onset_lambda"], 
                step=0.1,
                help="Primary tuning parameter. DECREASE (1.0-1.8) to catch quiet shots like slices and drop shots, but may add false positives. INCREASE (2.5-4.0) to only detect loud, clear hits - reduces false positives but may miss soft shots. Start at 2.0 and adjust based on results."
            )
            
            peak_distance = st.slider(
                "Min Time Between Hits (s)",
                min_value=0.1, max_value=2.0, 
                value=preset_values["peak_distance"], 
                step=0.05,
                help="Minimum gap between detected hits. INCREASE (0.6-1.0s) if you see double-detections for single shots. DECREASE (0.2-0.4s) for fast net exchanges or doubles volleys where shots happen in rapid succession."
            )
            
            st.divider()
            st.header("📦 Segment Grouping")
            
            cluster_gap = st.slider(
                "Max Gap to Group (s)",
                min_value=0.1, max_value=10.0, 
                value=preset_values["cluster_gap"], 
                step=0.1,
                help="Key parameter for clip style. LOW (0.5-1.0s): Each shot becomes a separate clip - good for individual shot highlights. HIGH (3.0-5.0s): Groups shots into complete rallies/points. VERY HIGH (6-10s): Accounts for long pauses in slow-paced matches."
            )
            
            min_hits = st.slider(
                "Min Hits per Segment",
                min_value=1, max_value=10, 
                value=preset_values["min_hits"],
                help="Filters segments by hit count. SET TO 1: Keeps every shot including serves. SET TO 2: Requires serve + return, filters isolated false positives. SET TO 3+: Only sustained rallies, good for rally-only highlights."
            )
            
            st.divider()
            st.header("✂️ Clip Padding")
            
            col1, col2 = st.columns(2)
            with col1:
                padding_pre = st.number_input(
                    "Pre-roll (s)",
                    min_value=0.0, max_value=5.0,
                    value=preset_values["padding_pre"],
                    step=0.1,
                    help="Buffer before the first detected hit. SHORT (0.3-1.0s): Tight clips for social media. LONG (2.0-4.0s): See ball toss, player preparation - better for coaching analysis."
                )
            with col2:
                padding_post = st.number_input(
                    "Post-roll (s)",
                    min_value=0.0, max_value=5.0,
                    value=preset_values["padding_post"],
                    step=0.1,
                    help="Buffer after the last detected hit. SHORT (0.3-1.0s): Quick cuts. LONG (2.0-4.0s): See point outcome, reactions, and ball settling."
                )
            
            merge_gap = st.slider(
                "Merge Nearby Clips (s)",
                min_value=0.0, max_value=3.0,
                value=preset_values["merge_gap"],
                step=0.1,
                help="Merges clips after padding is applied. LOW (0.0-0.2s): Only merge overlapping segments, more separate clips. HIGH (1.0-3.0s): Aggressively combine nearby segments into longer continuous clips."
            )
            
            st.divider()
            st.header("🎥 Video Validation")
            
            motion_threshold = st.slider(
                "Motion Threshold",
                min_value=0, max_value=2000, 
                value=defaults["motion_area_threshold"], 
                step=25,
                help="Minimum moving pixels required to validate a segment. DECREASE (100-300) if valid rallies are rejected (red on timeline) - good for distant camera angles. INCREASE (750-1500) if false positives are passing through. SET TO 0 to disable validation entirely."
            )
        else:
            # Use preset values
            bandpass_low = preset_values["bandpass_low"]
            bandpass_high = preset_values["bandpass_high"]
            onset_lambda = preset_values["onset_lambda"]
            peak_distance = preset_values["peak_distance"]
            cluster_gap = preset_values["cluster_gap"]
            min_hits = preset_values["min_hits"]
            padding_pre = preset_values["padding_pre"]
            padding_post = preset_values["padding_post"]
            merge_gap = preset_values["merge_gap"]
            motion_threshold = 500  # Default
        
        skip_validation = st.checkbox(
            "Skip Video Validation",
            value=True if preset == "individual_shots" else False,
            help="Skip motion check (faster, use for quick iteration)"
        )
        
        st.divider()
        
        # Summary of current settings
        with st.expander("📋 Current Settings Summary"):
            st.markdown(f"""
            - **Mode**: {preset.replace('_', ' ').title()}
            - **Sensitivity**: λ={onset_lambda}
            - **Grouping**: {cluster_gap}s gap, min {min_hits} hits
            - **Padding**: {padding_pre}s before, {padding_post}s after
            - **Validation**: {'Disabled' if skip_validation else f'Motion > {motion_threshold}'}
            """)
        
        # Process button
        process_btn = st.button(
            "🔄 Analyze Video",
            type="primary",
            use_container_width=True,
            disabled=not video_path or st.session_state.processing
        )
    
    # Main content area
    if process_btn and video_path:
        if not os.path.exists(video_path):
            st.error(f"❌ File not found: {video_path}")
        else:
            st.session_state.processing = True
            
            # Progress container
            progress_container = st.container()
            
            with progress_container:
                progress_bar = st.progress(0, text="Initializing...")
                status_text = st.empty()
                
                def update_progress(message: str):
                    status_text.text(message)
                    # Rough progress estimation
                    if "audio" in message.lower():
                        progress_bar.progress(20, text=message)
                    elif "validating" in message.lower():
                        progress_bar.progress(50, text=message)
                    elif "complete" in message.lower():
                        progress_bar.progress(100, text=message)
                
                try:
                    # Create pipeline with current parameters
                    cropper = TennisCropper(
                        bandpass_low=bandpass_low,
                        bandpass_high=bandpass_high,
                        onset_threshold_lambda=onset_lambda,
                        peak_min_distance_sec=peak_distance,
                        cluster_max_gap_sec=cluster_gap,
                        cluster_min_hits=min_hits,
                        padding_pre_sec=padding_pre,
                        padding_post_sec=padding_post,
                        motion_area_threshold=motion_threshold,
                    )
                    
                    # Run analysis
                    result = cropper.process(
                        video_path,
                        output_path=None,  # Don't export, just analyze
                        skip_validation=skip_validation,
                        progress_callback=update_progress,
                    )
                    
                    st.session_state.pipeline_result = result
                    progress_bar.progress(100, text="✅ Analysis complete!")
                    
                except Exception as e:
                    st.error(f"❌ Error: {str(e)}")
                    import traceback
                    st.code(traceback.format_exc())
            
            st.session_state.processing = False
    
    # Display results
    result = st.session_state.pipeline_result
    
    if result is None:
        st.info("👆 Enter a video path and click 'Analyze Video' to begin")
        
        # Show example usage
        with st.expander("📖 How to Use", expanded=True):
            st.markdown("""
            ### Getting Started
            1. **Enter Video Path**: Full path to your tennis video file
            2. **Choose a Preset**: Select detection mode in the sidebar
            3. **Click Analyze**: Process the video and visualize results
            4. **Iterate**: Adjust parameters and re-analyze until satisfied
            
            ### Presets Explained
            - 🎾 **Individual Shots**: Tight clips around each hit (0.5s padding, no grouping). Best for creating shot compilations.
            - 🏸 **Full Rallies**: Groups shots into complete points (2s padding, 3s grouping). Best for match highlights.
            - ⚙️ **Custom**: Enable "Show Advanced Settings" for full control over all parameters.
            """)
        
        with st.expander("🔧 Parameter Tuning Guide"):
            st.markdown("""
            ### Most Important Parameters
            
            | Parameter | What It Controls | When to Adjust |
            |-----------|-----------------|----------------|
            | **Sensitivity (λ)** | How easily hits are detected | First thing to tune - affects everything |
            | **Max Gap to Group** | Individual shots vs full rallies | Controls your output style |
            | **Motion Threshold** | False positive filtering | Tune if wrong segments are kept/rejected |
            
            ### Troubleshooting Common Issues
            
            **❌ Too many false detections (detecting non-hits)**
            - Increase **Sensitivity (λ)** from 2.0 → 2.5 or higher
            - Increase **Bandpass Low** to filter wind/crowd noise
            - Decrease **Bandpass High** to filter shoe squeaks
            
            **❌ Missing legitimate hits**
            - Decrease **Sensitivity (λ)** from 2.0 → 1.5 or lower
            - Check waveform - if hits are visible but not detected, λ is too high
            
            **❌ Double-detection of single shots**
            - Increase **Min Time Between Hits** from 0.5s → 0.7s or higher
            
            **❌ Fast volleys being missed**
            - Decrease **Min Time Between Hits** from 0.5s → 0.3s
            
            **❌ Rallies split into multiple segments**
            - Increase **Max Gap to Group** from 3s → 4-5s
            
            **❌ Separate points merged together**
            - Decrease **Max Gap to Group** from 3s → 2s
            - Decrease **Merge Nearby Clips** to 0.0-0.2s
            
            **❌ Valid rallies rejected (red on timeline)**
            - Decrease **Motion Threshold** from 500 → 200-300
            - Or enable "Skip Video Validation"
            
            **❌ False positives passing validation**
            - Increase **Motion Threshold** from 500 → 750-1000
            
            ### Recommended Starting Points
            
            | Scenario | Sensitivity | Gap | Min Hits | Padding |
            |----------|-------------|-----|----------|---------|
            | Outdoor match (windy) | 2.5 | 3.0s | 2 | 2.0s |
            | Indoor match (quiet) | 1.8 | 3.0s | 2 | 2.0s |
            | Shot compilation | 1.5 | 0.8s | 1 | 0.5s |
            | Rally highlights only | 2.5 | 4.0s | 3 | 2.5s |
            | Doubles (fast exchanges) | 2.0 | 2.5s | 2 | 1.5s |
            """)
    else:
        # Summary metrics
        st.header("📊 Summary")
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric(
                "Original Duration",
                format_time(result.video_duration)
            )
        
        with col2:
            st.metric(
                "Summary Duration",
                format_time(result.output_duration)
            )
        
        with col3:
            st.metric(
                "Compression",
                f"{result.compression_ratio:.1f}%",
                help="Percentage of video removed"
            )
        
        with col4:
            st.metric(
                "Rallies Found",
                len(result.merged_intervals)
            )
        
        # Processing time
        st.caption(
            f"⏱️ Processing time: Audio {result.audio_processing_time:.1f}s, "
            f"Video {result.video_processing_time:.1f}s, "
            f"Total {result.total_processing_time:.1f}s"
        )
        
        st.divider()
        
        # Audio Analysis Visualization
        st.header("🔊 Audio Analysis")
        
        audio_result = result.audio_result
        
        # Stats
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Detected Hits", len(audio_result.peak_times))
        with col2:
            st.metric("Candidate Rallies", len(audio_result.rally_intervals))
        with col3:
            avg_hits = np.mean(audio_result.rally_hit_counts) if audio_result.rally_hit_counts else 0
            st.metric("Avg Hits/Rally", f"{avg_hits:.1f}")
        
        # Waveform plot
        fig_waveform = create_waveform_plot(audio_result)
        st.plotly_chart(fig_waveform, use_container_width=True)
        
        st.divider()
        
        # Timeline visualization
        st.header("📍 Segment Timeline")
        
        if result.video_result:
            fig_timeline = create_timeline_plot(
                result.video_duration,
                result.audio_candidates,
                result.validated_intervals,
                result.rejected_intervals,
            )
        else:
            fig_timeline = create_timeline_plot(
                result.video_duration,
                result.audio_candidates,
            )
        
        st.plotly_chart(fig_timeline, use_container_width=True)
        
        # Motion validation details
        if result.video_result and not skip_validation:
            st.divider()
            st.header("🎥 Motion Validation")
            
            col1, col2 = st.columns(2)
            with col1:
                validated_count = len(result.validated_intervals)
                st.metric("Validated Segments", validated_count, 
                         delta=f"{validated_count}/{len(result.audio_candidates)} passed")
            with col2:
                rejected_count = len(result.rejected_intervals)
                st.metric("Rejected Segments", rejected_count,
                         delta=f"-{rejected_count}" if rejected_count else None,
                         delta_color="inverse")
            
            # Motion scores chart
            fig_motion = create_motion_scores_plot(result.video_result)
            st.plotly_chart(fig_motion, use_container_width=True)
            
            # Segment details table
            with st.expander("📋 Segment Details"):
                for i, seg in enumerate(result.video_result.segments):
                    status = "✅" if seg.is_valid else "❌"
                    duration = seg.end - seg.start
                    
                    st.markdown(
                        f"**{status} Segment {i+1}**: "
                        f"`{format_time(seg.start)}` → `{format_time(seg.end)}` "
                        f"({duration:.1f}s) — Motion: {seg.motion_score:.0f}"
                    )
                    
                    # Show sample frames if available
                    if seg.sample_frames:
                        cols = st.columns(min(len(seg.sample_frames), 4))
                        for j, frame in enumerate(seg.sample_frames[:4]):
                            with cols[j]:
                                st.image(frame, use_container_width=True, caption=f"Frame {j+1}")
        
        st.divider()
        
        # Final intervals
        st.header("📦 Final Output")
        
        if result.merged_intervals:
            st.success(f"✅ {len(result.merged_intervals)} segments ready for export")
            
            # Show intervals as table
            interval_data = []
            for i, (start, end) in enumerate(result.merged_intervals):
                interval_data.append({
                    "#": i + 1,
                    "Start": format_time(start),
                    "End": format_time(end),
                    "Duration": f"{end - start:.1f}s"
                })
            
            st.dataframe(interval_data, use_container_width=True, hide_index=True)
            
            # Export section
            st.subheader("💾 Export")
            
            # Quick export to out/ folder
            video_name = Path(result.video_path).stem
            out_dir = Path("out")
            quick_output_path = out_dir / f"{video_name}_highlights.mp4"
            
            st.markdown(f"**Quick Export:** `{quick_output_path}`")
            
            quick_export_btn = st.button(
                "🎬 Export Highlights to out/", 
                type="primary", 
                use_container_width=True,
                help="Export all segments as a single video to the out/ folder"
            )
            
            if quick_export_btn:
                # Create progress indicators
                export_progress = st.progress(0, text="Initializing export...")
                export_status = st.empty()
                
                try:
                    from src.video_editor import ClipEditor
                    import re
                    
                    # Create out/ directory if it doesn't exist
                    out_dir.mkdir(parents=True, exist_ok=True)
                    
                    num_segments = len(result.merged_intervals)
                    
                    def update_export_progress(msg: str):
                        """Parse progress messages and update UI."""
                        export_status.text(f"📦 {msg}")
                        
                        # Estimate progress based on message content
                        if "Preparing" in msg:
                            export_progress.progress(5, text=msg)
                        elif "Extracting segment" in msg:
                            # Parse "Extracting segment X/Y"
                            match = re.search(r"segment (\d+)/(\d+)", msg)
                            if match:
                                current = int(match.group(1))
                                total = int(match.group(2))
                                # Extraction is 10-60% of the process
                                pct = 10 + int((current / total) * 50)
                                export_progress.progress(pct, text=msg)
                        elif "Concatenating" in msg:
                            export_progress.progress(65, text=msg)
                        elif "Writing" in msg:
                            export_progress.progress(70, text="Writing video file (this may take a while)...")
                        elif "complete" in msg.lower():
                            export_progress.progress(100, text="✅ Export complete!")
                    
                    editor = ClipEditor(result.video_path)
                    export_result = editor.extract_and_export(
                        result.merged_intervals,
                        str(quick_output_path),
                        progress_callback=update_export_progress
                    )
                    
                    # Clear progress indicators and show success
                    export_progress.empty()
                    export_status.empty()
                    
                    st.success(f"✅ Exported to: {quick_output_path}")
                    st.info(
                        f"📊 Output: {format_time(export_result.output_duration)} "
                        f"({export_result.segments_count} segments, "
                        f"{export_result.compression_ratio:.1f}% compression)"
                    )
                    st.balloons()
                    
                except Exception as e:
                    export_progress.empty()
                    export_status.empty()
                    st.error(f"❌ Export failed: {str(e)}")
                    import traceback
                    st.code(traceback.format_exc())
            
            # Advanced export options
            with st.expander("⚙️ Custom Export Path"):
                col1, col2 = st.columns([3, 1])
                with col1:
                    output_path = st.text_input(
                        "Output Path",
                        value=str(Path(result.video_path).with_suffix('.summary.mp4')),
                        help="Path for the exported summary video"
                    )
                
                with col2:
                    export_btn = st.button("Export", use_container_width=True)
                
                if export_btn and output_path:
                    # Create progress indicators
                    custom_progress = st.progress(0, text="Initializing export...")
                    custom_status = st.empty()
                    
                    try:
                        from src.video_editor import ClipEditor
                        import re
                        
                        # Ensure parent directory exists
                        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
                        
                        def update_custom_progress(msg: str):
                            """Parse progress messages and update UI."""
                            custom_status.text(f"📦 {msg}")
                            
                            if "Preparing" in msg:
                                custom_progress.progress(5, text=msg)
                            elif "Extracting segment" in msg:
                                match = re.search(r"segment (\d+)/(\d+)", msg)
                                if match:
                                    current = int(match.group(1))
                                    total = int(match.group(2))
                                    pct = 10 + int((current / total) * 50)
                                    custom_progress.progress(pct, text=msg)
                            elif "Concatenating" in msg:
                                custom_progress.progress(65, text=msg)
                            elif "Writing" in msg:
                                custom_progress.progress(70, text="Writing video file...")
                            elif "complete" in msg.lower():
                                custom_progress.progress(100, text="✅ Export complete!")
                        
                        editor = ClipEditor(result.video_path)
                        export_result = editor.extract_and_export(
                            result.merged_intervals,
                            output_path,
                            progress_callback=update_custom_progress
                        )
                        
                        custom_progress.empty()
                        custom_status.empty()
                        
                        st.success(f"✅ Exported to: {output_path}")
                        st.balloons()
                        
                    except Exception as e:
                        custom_progress.empty()
                        custom_status.empty()
                        st.error(f"❌ Export failed: {str(e)}")
        else:
            st.warning("⚠️ No segments detected. Try adjusting parameters.")


if __name__ == "__main__":
    main()

