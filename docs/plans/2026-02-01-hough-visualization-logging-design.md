# Hough Method Visualization Logging Design

## Purpose

Add detailed intermediate visualization logging for the Hough method, enabling algorithm validation across all three pipeline stages (motion detection, linearity detection, temporal grouping). Modeled after SpectralFlux's RunObservation pattern.

## Goals

- Full pipeline traceability across all three stages
- Signal charts for numeric time-series data
- Debug overlay artifacts with motion pixels and detected line streaks
- Sparse sampling (1 frame/sec during active detection) to manage storage

---

## Signal Logging Structure

### Stage 1: Motion Detection

| Signal | Type | Description |
|--------|------|-------------|
| `motion_points` | Double | Count of motion pixels per frame (existing) |
| `motion_area_ratio` | Double | Motion points as percentage of frame area (0.0-1.0) |

### Stage 2: Linearity Detection

| Signal | Type | Description |
|--------|------|-------------|
| `streak_count` | Double | Number of detected streaks per frame (existing) |
| `streak_max_length` | Double | Length of longest streak in pixels |
| `linearity_score` | Double | Ratio of points on streaks vs total motion points (0.0-1.0) |

### Stage 3: Temporal Grouping

| Signal | Type | Description |
|--------|------|-------------|
| `gap_since_detection` | Double | Seconds since last streak detection |
| `rally_active` | Double | Binary indicator (0 or 1) if currently in rally window |

---

## Event Structure

### Stage 2: Linearity Detection

**`streak_detected`** (existing)
- `length`: Streak length in pixels
- `start`: Start point coordinates "(x,y)"
- `end`: End point coordinates "(x,y)"
- `count`: Total streak count in frame

**`hough_debug_frame`** (new)
- `motion_points`: Count of motion pixels
- `streak_count`: Number of detected streaks
- `max_streak_length`: Longest streak length
- `artifactId`: Reference to saved debug overlay image

### Stage 3: Temporal Grouping

**`rally_opened`** (new)
- `start_time`: Rally start timestamp

**`rally_closed`** (new)
- `duration`: Rally duration in seconds
- `detection_count`: Number of detections in rally

---

## Debug Overlay Artifacts

### Capture Trigger

One annotated frame per second, only during "active detection" periods (when `streak_count > 0` or within 1 second of a detection).

### Overlay Content

1. **Motion pixels** — Semi-transparent green dots (3px) at each detected motion point
2. **Detected streaks** — Red lines (2px) from start to end point with endpoint markers

### Storage

- Format: JPEG at 0.7 quality (~50-100KB per frame)
- Location: `artifacts/hough_debug_{timestamp_ms}.jpg`
- Referenced via `artifactId` in `hough_debug_frame` events

### Rate Limiting

- Minimum 1-second gap between captures
- Motion point downsampling to 5000 if exceeded (rendering only, signals keep full count)
- Estimated 100-200 debug frames for a 10-minute video

---

## Implementation Architecture

### Files to Modify

1. **`HoughMethod.swift`** — Add new signals, artifact capture logic, coordinate debug rendering
2. **`HoughLinearityDetector.swift`** — Compute and return `linearity_score`
3. **`HoughTracker.swift`** — Add observation parameter, emit rally events, log gap signal

### New File

4. **`HoughDebugRenderer.swift`** — Overlay rendering utility

### HoughDebugRenderer API

```swift
final class HoughDebugRenderer {
    func render(
        frame: CVPixelBuffer,
        motionPoints: [CGPoint],
        lines: [LineSegment],
        frameSize: CGSize
    ) -> Data?  // Returns JPEG data
}
```

### Implementation Notes

- Use Core Graphics (`CGContext`) for overlay drawing
- Rendering happens after detection, not in critical path
- Only called once per second maximum

### Data Flow

```
HoughMethod.processFrame()
    ├── motionProcessor.process() → points
    ├── linearityDetector.detect() → lines, linearityScore
    ├── tracker.track() → rally state changes
    ├── Log signals to observation
    └── If 1 second elapsed since last artifact:
            debugRenderer.render(frame, points, lines) → JPEG
            Save artifact, log hough_debug_frame event
```

---

## Temporal Grouping Visualization

Example timeline showing how signals and events correlate:

```
Time:     0s    1s    2s    3s    4s    5s    6s
Streaks:  |--D--D-----D-----------D--D--|
Gap:      0.0  0.3   0.8         2.1  0.2
Rally:    [====OPEN====]         [==OPEN==]
Events:   ^open        ^close    ^open   ^close
```

---

## Performance Considerations

- Signal logging: negligible (simple append with downsampling)
- Event logging: minimal (metadata dict creation)
- Artifact rendering: ~10-50ms per frame, once per second max
- Storage: ~10-20MB artifacts for 10-minute video
