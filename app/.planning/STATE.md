# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-21)

**Core value:** Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space.
**Current focus:** v1.1 DevX for Algorithm Iteration - Phase 5 iOS Runner Core

## Current Position

Phase: 6 of 9 (Dashboard Backend & Web Core)
Plan: 1 of 3
Status: In progress
Last activity: 2026-01-21 — Completed 06-01-PLAN.md

Progress: ████████▓░░░░░░░░░░░ 43% (12 of 28 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 12
- Average duration: 6.6 min
- Total execution time: 1.3 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Test Infrastructure & Baseline | 3 | 16 min | 5.3 min |
| 2. Core E2E Test Coverage | 2 | 13 min | 6.5 min |
| 3. Service Layer + UI Cleanup | 3 | 35 min | 11.7 min |
| 4. Method Protocol Foundation | 1 | 9 min | 9.0 min |
| 5. iOS Runner Core | 3 | 4 min | 1.3 min |
| 6. Dashboard Backend & Web Core | 1 | 2 min | 2.0 min |

**Recent Trend:**
- Last 5 plans: 18 min, 9 min, 4 min, 2 min
- Trend: Improving (recent plans faster due to clear specifications)

## Accumulated Context

Always use iPhone 17 device for xcodebuild and any testing commands for a simulator.

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.0]: IoU-based fuzzy matching for segment tests
- [v1.0]: Service layer extraction pattern (Manager/Service naming)
- [v1.0]: Background video loading for immediate UI dismissal
- [04-01]: Protocol-based method abstraction for algorithm swapping
- [04-01]: SpectralFluxMethod as final class (not actor) with actor components
- [04-01]: Progress reporting stays in service layer, not method layer
- [v1.1 pivot]: iOS Runner with Swifter HTTP server (not xcodebuild)
- [v1.1 pivot]: Same project, new target (SportCrunchRunner)
- [v1.1 pivot]: Node.js backend + React frontend
- [v1.1 pivot]: Filesystem transfer for simulator, HTTP for device
- [v1.1 pivot]: Bespoke visualizations per method (no generic framework)
- [v1.1 pivot]: JSON method registry in methods/*.json
- [05-02]: ExportedSegment naming to avoid DebugReportService collision
- [05-02]: DispatchSemaphore for async/sync bridging in HTTP handlers
- [05-02]: Timestamp-method artifact naming (YYYYMMDD-HHMMSS-Method-segments.json)
- [06-01]: Express.js backend for API layer and iOS Runner proxy
- [06-01]: ES modules syntax for backend (type: "module")
- [06-01]: 500MB upload limit for video files

### Pending Todos

None yet.

### Blockers/Concerns

**Test Quality (Pre-existing):**
- SegmentDetectionTests.testShotDetection_Tennis has high false negative rates on some test videos
- Verified as pre-existing issue (failing on commit 8eaf9fe before Phase 4 changes)
- Not a regression from method protocol refactoring
- May need test data quality review or detection parameter tuning in future phase

## Session Continuity

Last session: 2026-01-21
Stopped at: Completed 06-01-PLAN.md (Node.js Backend & iOS Runner Proxy)
Resume file: None

**v1.1 Status (post-pivot):**
- Phase 4: Method Protocol Foundation - Complete (1/1 plans done)
- Phase 5: iOS Runner Core - Complete (3/3 plans done)
  - ✅ 05-01: HTTP Server Foundation
  - ✅ 05-02: Run Execution Pipeline
  - ✅ 05-03: Filesystem Video Transfer
- Phase 6: Dashboard Backend & Web Core - In progress (1/3 plans done)
  - ✅ 06-01: Node.js Backend & iOS Runner Proxy
  - ⏳ 06-02: React Dashboard (video selection, run triggering)
  - ⏳ 06-03: Results View (timeline visualization, video player)
- Phase 7: Method Registry - Not started (JSON definitions, dynamic config forms)
- Phase 8: Comparison & Ground Truth - Not started (ground truth overlay, metrics)
- Phase 9: Intermediate Visualization & Polish - Not started (spectral flux viz, device support)
