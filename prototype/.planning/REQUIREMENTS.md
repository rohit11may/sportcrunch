# Requirements: v1.0 Multi-Method Framework

## Overview

Build a pluggable framework for comparing multiple tennis segment detection methods against a shared test corpus with standardized evaluation metrics.

---

## Must Have

### FRAME-01: Method Abstraction Layer
Methods implement a common interface (`SegmentationMethod` ABC) with:
- `analyze(video_path) → MethodResult`
- `get_config_spec() → ConfigSpec` (parameter definitions)
- `get_viz_hooks() → Dict[str, VizHook]` (intermediate visualization data)

**Acceptance:** Two methods (AV-Funnel + a stub) can be instantiated and called through the same interface.

### FRAME-02: Required FSM State Output
All methods must emit an FSM state timeline as part of `MethodResult`:
- Timeline of `(timestamp, state)` tuples
- States are method-specific but must include at minimum: `active` and `inactive`
- Framework validates that state timeline covers full video duration

**Acceptance:** Method result validation fails if FSM timeline is missing or incomplete.

### FRAME-03: Method Registry
Decorator-based registration system:
- `@register_method` decorator adds method to global registry
- `get_registered_methods()` returns all available methods
- Methods are auto-discovered at import time

**Acceptance:** Adding a new method file with decorator automatically makes it available to test harness.

### EVAL-01: Port Evaluation Logic from iOS
Port `SegmentEvaluator.swift` to Python:
- `iou(detected, ground_truth) → float` (Intersection over Union)
- `evaluate(detected, ground_truth, iou_threshold=0.5) → (tp, fp, fn)`
- `calculate_rates(detected, ground_truth, video_duration) → (fp_rate, fn_rate)`

**Acceptance:** Python evaluator produces identical results to Swift version on same inputs.

### EVAL-02: Ground Truth Loader
Load ground truth from iOS app's TestResources:
- Read JSON files from `../app/SportCrunchTests/TestResources/GroundTruth/`
- Parse into `GroundTruth` dataclass matching iOS schema
- Support both `shot` and `rally` modes

**Acceptance:** All 6 existing ground truth files load correctly.

### EVAL-03: Test Harness
Automated testing of all methods against test corpus:
- Enumerate all registered methods
- Run each method on each test video
- Collect `MethodResult` + timing metrics
- Calculate evaluation metrics per method per video

**Acceptance:** Single command runs all methods on all videos and produces comparison table.

### VIZ-01: Metrics Dashboard
Unified dashboard showing:
- Metrics table: precision, recall, F1, processing time per method per video
- Summary statistics across full corpus
- Sortable/filterable by method or video

**Acceptance:** Dashboard displays results from test harness run.

### VIZ-02: FSM Timeline Visualization
Reusable timeline component showing:
- Ground truth segments (reference bar)
- Detected segments per method (comparison bars)
- FSM state color-coding
- Overlaid on same time axis for comparison

**Acceptance:** Can display side-by-side timelines for 2+ methods on same video.

### METH-01: Refactor AV-Funnel into Framework
Wrap existing `TennisCropper` pipeline as `AudioOnsetMethod`:
- Implement `SegmentationMethod` interface
- Extract FSM states from pipeline stages
- Package visualization hooks (waveform, onset, motion)
- Preserve all existing parameters in `ConfigSpec`

**Acceptance:** AV-Funnel runs through test harness and produces equivalent results to current Streamlit output.

---

## Should Have

### VIZ-03: Method-Specific Intermediate Viz
For AV-Funnel, port existing Streamlit visualizations:
- Filtered waveform + onset strength plot
- Detected peaks overlay
- Motion scores bar chart
- Sample frame thumbnails

**Acceptance:** Method-specific viz hooks render in dashboard alongside timeline.

### EVAL-04: Results Persistence
Save test harness results for later comparison:
- JSON export of all metrics
- Timestamp + git hash for reproducibility
- Load historical results for trend analysis

**Acceptance:** Can compare current run against previous saved run.

### FRAME-04: Video Loader Abstraction
Shared video loading utilities:
- Path resolution for iOS TestResources videos
- Frame extraction at specified timestamps
- Audio extraction
- Caching for repeated access

**Acceptance:** Methods use shared loader instead of direct file access.

---

## Nice to Have

### VIZ-04: Per-Segment Drill-Down
Click on a detected segment to see:
- Matched ground truth segment (if any)
- IoU score
- Method-specific intermediate data at that timestamp

### EVAL-05: Aggregate Corpus Metrics
Beyond per-video metrics:
- Micro/macro averages across corpus
- Confidence intervals
- Statistical significance tests between methods

### FRAME-05: Parameter Sweep Runner
Run method with multiple parameter combinations:
- Grid search or random search
- Track metrics per configuration
- Find optimal parameters for corpus

---

## Out of Scope (v1.0)

- Streak-Context method implementation (framework first, method later)
- Real-time processing optimization
- Mobile deployment
- Multi-sport support beyond tennis
- Production UI polish
- Creating new ground truth annotations (use existing 6 videos)

---

*Last updated: 2026-01-20*
