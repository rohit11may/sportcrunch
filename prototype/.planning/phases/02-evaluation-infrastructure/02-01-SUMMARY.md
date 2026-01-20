---
phase: 02-evaluation-infrastructure
plan: "01"
subsystem: evaluation
tags: [python, opencv, iou, evaluation, ground-truth]

# Dependency graph
requires:
  - phase: 01-framework-foundation
    provides: Framework structure and method abstraction pattern
provides:
  - IoU-based segment evaluator ported from Swift
  - Ground truth loader for iOS TestResources JSON files
  - Video metadata extraction utilities
affects: [02-02-test-harness, 03-av-funnel-refactor]

# Tech tracking
tech-stack:
  added: [opencv-python, numpy]
  patterns: [dataclass-based models, path resolution to iOS resources]

key-files:
  created:
    - src/evaluation/evaluator.py
    - src/evaluation/ground_truth.py
    - src/utils/video.py
  modified: []

key-decisions:
  - "Created virtual environment for Python dependencies to work with externally-managed system Python"
  - "Path resolution uses relative paths from module location (4 levels up to reach shared iOS resources)"
  - "Ground truth segments converted to TimeRange via as_time_ranges() method for evaluator compatibility"

patterns-established:
  - "Dataclass-based models for all data structures (TimeRange, VideoMetadata, GroundTruth)"
  - "Static methods for evaluator functions (no instance state needed)"
  - "Greedy matching algorithm for IoU-based segment evaluation"

# Metrics
duration: 4min
completed: 2026-01-20
---

# Phase 2 Plan 1: Evaluation Infrastructure Summary

**IoU-based segment evaluator with Swift-equivalent logic, ground truth loader for 6 annotated test videos, and OpenCV video metadata extraction**

## Performance

- **Duration:** 4m 8s
- **Started:** 2026-01-20T13:04:19Z
- **Completed:** 2026-01-20T13:08:27Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Ported SegmentEvaluator from Swift to Python with identical IoU calculation and greedy matching logic
- Created GroundTruthLoader accessing all 6 annotated tennis videos from iOS TestResources
- Built VideoLoader with OpenCV-based metadata extraction (duration, fps, dimensions)
- All three modules work independently with no circular dependencies

## Task Commits

Each task was committed atomically:

1. **Task 1: Port SegmentEvaluator from Swift to Python** - `06471f2` (feat)
   - TimeRange dataclass with start, end, duration property
   - EvaluationMetrics dataclass with tp/fp/fn and computed precision/recall/f1
   - SegmentEvaluator with IoU calculation matching Swift formula
   - Greedy matching evaluate() method for tp/fp/fn counts
   - calculate_rates() for FP/FN rate percentages

2. **Task 2: Create GroundTruthLoader for iOS TestResources** - `0b3b2ea` (feat)
   - Segment and GroundTruth dataclasses matching JSON schema
   - GroundTruthLoader with load(), load_all(), list_available()
   - Path resolution to ../app/SportCrunchTests/TestResources/GroundTruth
   - as_time_ranges() conversion for evaluator compatibility

3. **Task 3: Create VideoLoader abstraction** - `f604294` (feat)
   - VideoMetadata dataclass with path, duration, fps, dimensions, frame_count
   - VideoLoader with resolve_path(), get_metadata(), list_available()
   - OpenCV-based metadata extraction
   - Path resolution to ../app/SportCrunchTests/TestResources/Videos

## Files Created/Modified

- `src/evaluation/__init__.py` - Module exports for SegmentEvaluator, TimeRange, EvaluationMetrics, GroundTruth, GroundTruthLoader, Segment
- `src/evaluation/evaluator.py` - IoU calculation and segment matching (line-by-line port from Swift)
- `src/evaluation/ground_truth.py` - JSON loading from iOS test resources
- `src/utils/__init__.py` - Module exports for VideoLoader, VideoMetadata
- `src/utils/video.py` - Video path resolution and OpenCV metadata extraction

## Decisions Made

**1. Virtual environment for Python dependencies**
- System Python is externally-managed (Homebrew), preventing pip install
- Created venv/ for opencv-python and numpy installation
- Already gitignored in prototype/.gitignore

**2. Path resolution strategy**
- Ground truth: `Path(__file__).parent.parent.parent.parent / "app" / "SportCrunchTests" / "TestResources" / "GroundTruth"`
- Videos: `Path(__file__).parent.parent.parent.parent / "app" / "SportCrunchTests" / "TestResources" / "Videos"`
- 4 levels up: module -> package -> src -> prototype -> sportcrunch root
- Validates directory exists before accessing, clear error messages

**3. IoU calculation verification**
- Plan's test expectation was incorrect (expected 0.5 for d=(10,20) g=(15,25))
- Correct calculation: intersection=5, union=15, IoU=0.333
- Verified against Swift implementation to ensure identical results

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created virtual environment and installed dependencies**
- **Found during:** Task 3 (VideoLoader implementation)
- **Issue:** opencv-python not installed, system Python externally-managed preventing pip install
- **Fix:** Created venv/, installed opencv-python and numpy
- **Files modified:** None (venv/ is gitignored)
- **Verification:** `python -m pip show opencv-python` confirms installation
- **Committed in:** Part of Task 3 workflow (no code changes)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Virtual environment required for development. Standard Python practice, no scope creep.

## Issues Encountered

**Path resolution depth**
- Initial path went up 3 levels (to prototype), but needed 4 levels (to sportcrunch root)
- Fixed by adding one more `.parent` in path resolution
- Verified with `loader.load('tennis-shot-1.json')` loading successfully

## User Setup Required

None - no external service configuration required. Development environment setup (virtual environment) already complete.

## Next Phase Readiness

**Ready for Phase 2 Plan 2 (Test Harness):**
- Evaluator produces identical metrics to Swift version (verified with IoU calculation)
- All 6 ground truth files load correctly
- Video metadata extraction working for all test videos
- Three independent modules ready for integration

**Integration notes:**
- Test harness can import: `from src.evaluation import SegmentEvaluator, GroundTruthLoader`
- Test harness can import: `from src.utils import VideoLoader`
- Ground truth segments convert to TimeRange: `gt.as_time_ranges()`
- Video duration available: `video_loader.get_metadata(path).duration`

**No blockers or concerns.**

---
*Phase: 02-evaluation-infrastructure*
*Completed: 2026-01-20*
