# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-21)

**Core value:** Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space.
**Current focus:** v1.1 DevX for Algorithm Iteration - Phase 7 Method Registry (In Progress)

## Current Position

Phase: 7 of 9 (Method Registry)
Plan: 4 of 4
Status: Phase complete
Last activity: 2026-01-22 — Completed 07-04-PLAN.md (Dashboard Method Selection UI)

Progress: ███████████░░░░░░░░░ 61% (17 of 28 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 17
- Average duration: 5.8 min
- Total execution time: 1.6 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Test Infrastructure & Baseline | 3 | 16 min | 5.3 min |
| 2. Core E2E Test Coverage | 2 | 13 min | 6.5 min |
| 3. Service Layer + UI Cleanup | 3 | 35 min | 11.7 min |
| 4. Method Protocol Foundation | 1 | 9 min | 9.0 min |
| 5. iOS Runner Core | 3 | 4 min | 1.3 min |
| 6. Dashboard Backend & Web Core | 3 | 10 min | 3.3 min |
| 7. Method Registry | 4 | 25 min | 6.3 min |

**Recent Trend:**
- Last 5 plans: 3 min, 7 min, 15 min, (est 20 min for 07-03 incl. Xcode), 3 min
- Trend: Good (07-03 had Xcode checkpoint handling)

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
- [06-02]: Vite for React build tooling with /api proxy
- [06-02]: 2-second status polling interval for run monitoring
- [06-02]: 4-minute timeout for long-running video processing
- [06-03]: Horizontal timeline bars for segment visualization
- [06-03]: Toggle button for rejected segments view
- [06-03]: Static file serving for videos via /videos/ and /uploads/
- [06-03]: 800px fixed timeline width with 30-second time axis intervals
- [06-post]: Dashboard directory at root level (not app/dashboard)
- [06-post]: DeviceManager using devicectl for device communication (macOS only)
- [06-post]: Multi-device support (simulator + physical devices) in Phase 6
- [06-post]: run-map.json for run tracking persistence
- [06-post]: nodemon for backend development workflow
- [06-post]: Enhanced styling across all dashboard components early in development
- [07-design]: Hierarchical method registry (family/version/configs) not flat structure
- [07-design]: Methods in app/methods/ folder, dashboard reads directly (read-only)
- [07-design]: Build-time enforcement of JSON-Swift parallelism (JSON without Swift = build error)
- [07-design]: Dashboard shows method selection UI, not editable forms
- [07-01]: v1 (SpectralFlux) as pure audio-only method, v2 (SpectralFluxVisualValidation) as audio+visual
- [07-01]: v1 has 3 config variants (default/aggressive/conservative), v2 has single config
- [07-01]: v2 preserves current production SpectralFluxMethod implementation exactly
- [07-04]: Backend flattens hierarchical methods into flat array for easier frontend consumption
- [07-04]: localStorage persistence for method selection with key "sportcrunch_method_selection"
- [07-04]: Method selection as object {family, version, config, name} passed through to Runner

### Pending Todos

None yet.

### Blockers/Concerns

**Test Quality (Pre-existing):**
- SegmentDetectionTests.testShotDetection_Tennis has high false negative rates on some test videos
- Verified as pre-existing issue (failing on commit 8eaf9fe before Phase 4 changes)
- Not a regression from method protocol refactoring
- May need test data quality review or detection parameter tuning in future phase

## Session Continuity

Last session: 2026-01-22
Stopped at: Completed 07-04-PLAN.md (Dashboard Method Selection UI) - Phase 7 complete
Resume file: None

**v1.1 Status (post-pivot):**
- Phase 4: Method Protocol Foundation - Complete (1/1 plans done)
- Phase 5: iOS Runner Core - Complete (3/3 plans done)
  - ✅ 05-01: HTTP Server Foundation
  - ✅ 05-02: Run Execution Pipeline
  - ✅ 05-03: Filesystem Video Transfer
- Phase 6: Dashboard Backend & Web Core - Complete (3/3 plans done + enhancements)
  - ✅ 06-01: Node.js Backend & iOS Runner Proxy
  - ✅ 06-02: React Dashboard (video selection, run triggering)
  - ✅ 06-03: Results View (timeline visualization, video player)
  - ✅ Post-GSD: Dashboard reorganization (moved to root level)
  - ✅ Post-GSD: DeviceManager + DeviceSelector (multi-device support)
  - ✅ Post-GSD: Enhanced styling, run-map.json, nodemon, video playback fixes
- Phase 7: Method Registry - Complete (4/4 plans done)
  - ✅ 07-01: Method Registry JSON Structure (spectral_flux family with v1/v2 versions)
  - ✅ 07-02: Build Validation Script + MethodConfig protocol refactoring (Xcode checkpoint complete)
  - ✅ 07-03: Runner Registry Loading + GET /methods (registry loading, method endpoints)
  - ✅ 07-04: Dashboard Method Selection UI (dynamic method selector, localStorage persistence)
- Phase 8: Comparison & Ground Truth - Not started (ground truth overlay, metrics)
- Phase 9: Intermediate Visualization & Polish - Not started (spectral flux viz, remaining device work)
