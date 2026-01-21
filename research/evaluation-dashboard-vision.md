# Evaluation Dashboard Specification (Final)

## 1. Overview

### 1.1 Purpose
A personal dashboard system to facilitate iterative development and comparison of video segmentation algorithms, enabling rapid experimentation, visual comparison against ground truth, and deep-dive analysis of intermediate processing steps.

### 1.2 Core Goals
- **Compare** segmentation results across different methods/configurations
- **Visualize** segmented video outputs alongside ground truth
- **Explore** intermediate processing data (e.g., spectral flux, audio peaks)
- **Track** algorithm versions and persist method configurations for reproducibility

---

## 2. Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **HTTP server library** | **Swifter** | Lightweight, pure Swift, minimal setup—ideal for a personal tool |
| **File transfer strategy** | **Hybrid** | Shared filesystem for simulator (fast iteration), HTTP download for physical devices |
| **Runner discovery** | **Manual IP config** | Simplest approach; physical device IP entered in dashboard settings |
| **Schema registry format** | **JSON files in repo** | Version-controlled, easy to edit, single source of truth |
| **Storage backend** | **Local filesystem** | Simple file-based storage for runs and artifacts |
| **Visualization binding** | **Declarative config per method** | Bespoke visualizations tightly coupled to dashboard code |

---

## 3. System Architecture

### 3.1 High-Level Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Dashboard (Web)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Comparison  │  │  Run        │  │  Method/Config          │  │
│  │ Views       │  │  Manager    │  │  Registry               │  │
│  └─────────────┘  └──────┬──────┘  └─────────────────────────┘  │
└──────────────────────────┼──────────────────────────────────────┘
                           │ HTTP
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Dashboard Backend (Server)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Run         │  │ Artifact    │  │  Runner                 │  │
│  │ Storage     │  │ Storage     │  │  Communication          │  │
│  └─────────────┘  └─────────────┘  └──────────┬──────────────┘  │
└───────────────────────────────────────────────┼─────────────────┘
                                                │ HTTP
                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              iOS Runner App (Simulator or Device)                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Swifter     │  │ Segmentation│  │  Result                 │  │
│  │ HTTP Server │  │ Engine      │  │  Exporter               │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. iOS Runner App

### 4.1 Overview

A minimal iOS app embedding a **Swifter** HTTP server that:
- Listens on a configurable port (default: `8080`)
- Receives run requests from the dashboard backend
- Executes segmentation using native iOS code
- Returns results via HTTP or writes to shared filesystem

### 4.2 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /health` | GET | Returns `{ "status": "ready" }` |
| `GET /methods` | GET | Lists available methods (reads from bundled `methods/*.json`) |
| `POST /runs` | POST | Triggers a new segmentation run |
| `GET /runs/:id` | GET | Returns run status and result |
| `GET /runs/:id/artifacts/:name` | GET | Downloads artifact (device mode only) |

### 4.3 `POST /runs` Request

```json
{
  "run_id": "run_20250712_001",
  "method_id": "spectral_flux_v2",
  "config": {
    "threshold": 0.75,
    "min_segment_duration": 1.5
  },
  "source_video": "video_001.mp4",
  "commit_hash": "a1b2c3d4",
  "transfer_mode": "filesystem" | "http"
}
```

- `transfer_mode: "filesystem"` → Runner writes artifacts to shared Mac directory
- `transfer_mode: "http"` → Dashboard fetches artifacts via HTTP after completion

### 4.4 `GET /runs/:id` Response

```json
{
  "run_id": "run_20250712_001",
  "status": "completed",
  "method_id": "spectral_flux_v2",
  "config": { "threshold": 0.75, "min_segment_duration": 1.5 },
  "commit_hash": "a1b2c3d4",
  "duration_ms": 12340,
  "segments": [
    { "start": 0.0, "end": 3.2, "kept": true },
    { "start": 3.2, "end": 5.1, "kept": false, "reason": "below_threshold" },
    { "start": 5.1, "end": 9.8, "kept": true }
  ],
  "artifacts": [
    { "name": "segmented_output.mp4", "type": "video" },
    { "name": "intermediate.json", "type": "intermediate" }
  ],
  "filesystem_path": "/Users/you/project/dashboard/storage/runs/run_20250712_001"
}
```

### 4.5 Hybrid File Transfer

| Mode | When | Behavior |
|------|------|----------|
| **Simulator** | `transfer_mode: "filesystem"` | Runner writes directly to `dashboard/storage/runs/{run_id}/` via shared Mac filesystem |
| **Physical Device** | `transfer_mode: "http"` | Dashboard backend calls `GET /runs/:id/artifacts/:name` and saves locally |

**Simulator shared path detection:**
```swift
#if targetEnvironment(simulator)
    let sharedPath = "/Users/you/project/dashboard/storage/runs"
#else
    let sharedPath = nil // Use HTTP transfer
#endif
```

### 4.6 Runner UI (Minimal)

- Displays current IP address and port
- Shows list of recent runs and their status
- Log viewer for debugging

---

## 5. Method Registry

### 5.1 Location

```
methods/
├── spectral_flux_v1.json
├── spectral_flux_v2.json
└── visual_scene_detect.json
```

Both the iOS Runner and Dashboard read from this directory. For the iOS app, these files are bundled at build time.

### 5.2 Method Schema

```json
{
  "method_id": "spectral_flux_v2",
  "display_name": "Spectral Flux (v2)",
  "description": "Audio-based segmentation using spectral flux peak detection",
  
  "config_schema": {
    "threshold": {
      "type": "number",
      "default": 0.5,
      "min": 0,
      "max": 1,
      "description": "Peak detection threshold"
    },
    "min_segment_duration": {
      "type": "number",
      "default": 1.0,
      "min": 0.1,
      "description": "Minimum segment length in seconds"
    }
  },
  
  "intermediate_schema": {
    "audio_peaks": {
      "type": "array",
      "description": "Detected audio peaks with timestamps"
    },
    "spectral_flux_curve": {
      "type": "array",
      "description": "Raw spectral flux values per frame"
    }
  },
  
  "visualization": "spectral_flux"
}
```

### 5.3 Visualization Binding

The `visualization` field maps to a **bespoke dashboard component**:

| `visualization` value | Dashboard Component | Description |
|-----------------------|---------------------|-------------|
| `spectral_flux` | `<SpectralFluxViz />` | Audio waveform, peak markers, synced playback |
| `visual_scene` | `<VisualSceneViz />` | Scene change thumbnails, confidence graph |
| `generic` | `<GenericJsonViz />` | Fallback: raw JSON tree viewer |

Each component is **tightly coupled** to its method's intermediate data structure—no need for a generic abstraction layer.

---

## 6. Run Management

### 6.1 Run Lifecycle

```
┌──────────┐     POST /runs     ┌──────────┐
│  Pending │ ─────────────────► │ Running  │
└──────────┘                    └────┬─────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                                 ▼
             ┌──────────┐                      ┌──────────┐
             │Completed │                      │  Failed  │
             └──────────┘                      └──────────┘
```

### 6.2 Run Metadata (`meta.json`)

```json
{
  "run_id": "run_20250712_001",
  "method_id": "spectral_flux_v2",
  "config": {
    "threshold": 0.75,
    "min_segment_duration": 1.5
  },
  "commit_hash": "a1b2c3d4",
  "source_video": "video_001.mp4",
  "ground_truth_ref": "ground_truth/video_001.json",
  "timestamp": "2025-07-12T14:32:00Z",
  "status": "completed",
  "duration_ms": 12340
}
```

### 6.3 Segments Output (`segments.json`)

```json
{
  "segments": [
    { "start": 0.0, "end": 3.2, "kept": true },
    { "start": 3.2, "end": 5.1, "kept": false, "reason": "below_threshold" },
    { "start": 5.1, "end": 9.8, "kept": true }
  ],
  "summary": {
    "total_segments": 3,
    "kept_segments": 2,
    "total_duration": 9.8,
    "kept_duration": 7.9
  }
}
```

### 6.4 Ground Truth Format

```json
{
  "video": "video_001.mp4",
  "segments": [
    { "start": 0.0, "end": 3.5, "label": "keep" },
    { "start": 3.5, "end": 5.0, "label": "reject" },
    { "start": 5.0, "end": 9.8, "label": "keep" }
  ]
}
```

---

## 7. Dashboard Features

### 7.1 Run Triggering

- Select method from dropdown (populated from `methods/*.json`)
- Configure parameters via auto-generated form (from `config_schema`)
- Select source video from test set
- Click "Run" → dispatches to iOS Runner

### 7.2 Segmentation Results View

For a single run:

```
┌─────────────────────────────────────────────────────────────────┐
│  ▶ Video Player (segmented output)                              │
├─────────────────────────────────────────────────────────────────┤
│  Timeline                                                       │
│  ┌───────┐     ┌─────────────────────┐                          │
│  │ KEPT  │░░░░░│       KEPT          │  ← Method result         │
│  └───────┘     └─────────────────────┘                          │
│  ┌─────────┐   ┌─────────────────────┐                          │
│  │  KEEP   │░░░│       KEEP          │  ← Ground truth          │
│  └─────────┘   └─────────────────────┘                          │
│                                                                 │
│  Legend: ██ Match  ░░ Mismatch                                  │
├─────────────────────────────────────────────────────────────────┤
│  Metrics: Precision 94% | Recall 88% | IoU 0.82                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Comparison View

Select 2+ runs for side-by-side comparison:

```
┌───────────────────────────┬───────────────────────────┐
│  Run A: spectral_flux_v2  │  Run B: spectral_flux_v3  │
│  threshold: 0.5           │  threshold: 0.75          │
├───────────────────────────┼───────────────────────────┤
│  ▶ Video                  │  ▶ Video                  │
├───────────────────────────┼───────────────────────────┤
│  Timeline + Ground Truth  │  Timeline + Ground Truth  │
├───────────────────────────┼───────────────────────────┤
│  Precision: 88%           │  Precision: 94%           │
│  Recall: 91%              │  Recall: 85%              │
└───────────────────────────┴───────────────────────────┘
```

### 7.4 Intermediate Processing View (Bespoke per Method)

**Example: Spectral Flux Visualization**

```
┌─────────────────────────────────────────────────────────────────┐
│  ▶ Video Player (synced)                                        │
├─────────────────────────────────────────────────────────────────┤
│  Spectral Flux Curve                                            │
│  ▲                                                              │
│  │    ╱╲      ╱╲                                                │
│  │   ╱  ╲    ╱  ╲    ╱╲                                         │
│  │  ╱    ╲──╱    ╲──╱  ╲──                                      │
│  └──────────────────────────────────────────────────────────►   │
│       ▲         ▲                                               │
│       │         └── Peak (rejected: below threshold)            │
│       └── Peak (accepted)                                       │
├─────────────────────────────────────────────────────────────────┤
│  Segment Decisions                                              │
│  [0.0-3.2] KEPT    - peak amplitude: 0.82                       │
│  [3.2-5.1] REJECTED - peak amplitude: 0.31 (< 0.5 threshold)    │
│  [5.1-9.8] KEPT    - peak amplitude: 0.67                       │
└─────────────────────────────────────────────────────────────────┘
```

### 7.5 Method Management

- View all methods from `methods/*.json`
- Duplicate a method → creates new JSON file with incremented version
- Edit config defaults
- View run history per method

---

## 8. Implementation Phases

### Phase 1: Core Loop
- [ ] iOS Runner app with Swifter server (`/health`, `POST /runs`, `GET /runs/:id`)
- [ ] Single hardcoded method (spectral flux)
- [ ] Filesystem transfer (simulator only)
- [ ] Dashboard: trigger run, display segmented video + basic timeline

### Phase 2: Method System
- [ ] Method registry (`methods/*.json`)
- [ ] Dynamic config form generation
- [ ] Runner reads method definitions from bundle
- [ ] Dashboard lists available methods

### Phase 3: Comparison & Ground Truth
- [ ] Ground truth loading and display
- [ ] Comparison view (2+ runs side-by-side)
- [ ] Metrics calculation (precision, recall, IoU)

### Phase 4: Intermediate Visualization
- [ ] Spectral flux bespoke visualization component
- [ ] Synced video + graph playback
- [ ] Segment decision annotations

### Phase 5: Device Support & Polish
- [ ] HTTP artifact transfer for physical devices
- [ ] Manual IP configuration in dashboard settings
- [ ] Commit hash tracking and display
- [ ] Method duplication and versioning UI

---

## 9. Technical Notes

### 9.1 Swifter Setup (iOS Runner)

```swift
import Swifter

let server = HttpServer()

server["/health"] = { _ in
    return .ok(.json(["status": "ready"]))
}

server["/runs"] = { request in
    // Parse request, trigger async run, return run_id
}

server["/runs/:id"] = { request in
    // Return run status and results
}

try server.start(8080)
```

### 9.2 Simulator Shared Filesystem

The iOS Simulator shares the Mac filesystem. Write artifacts to:

```swift
let sharedPath = "/Users/<username>/project/dashboard/storage/runs/\(runId)/"
FileManager.default.createDirectory(atPath: sharedPath, ...)
// Write segmented_output.mp4, segments.json, intermediate.json
```

### 9.3 Dashboard Backend (Minimal)

A simple Node.js or Python server that:
- Serves the frontend
- Proxies requests to iOS Runner
- Reads/writes to `storage/` directory
- Reads method definitions from `methods/`

---

Let me know if you'd like me to generate starter code for the iOS Runner, dashboard backend, or any specific component.
