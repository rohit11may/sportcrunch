# SportCrunch

## What This Is

An iOS app that performs intelligent on-device cropping of long sports footage for recreational players. It uses audio/video analysis to automatically detect and remove dead space, creating curated highlight reels from tennis matches. The app focuses on accurate segment detection while maintaining fast, private on-device processing.

## Core Value

Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space, while processing efficiently enough for 1-hour videos.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ Multi-step video selection wizard (video → sport → mode selection) — existing
- ✓ Tennis processing with dual modes (Rally/Shot) — existing
- ✓ Rally mode: 3s gap clustering with audio-only validation — existing
- ✓ Shot mode: 1s gap clustering for snappy clips — existing
- ✓ Cricket sport support with 6s gap clustering — existing
- ✓ On-device audio analysis using Accelerate vDSP for onset detection — existing
- ✓ Visual validation using CoreGraphics for motion confirmation — existing
- ✓ Background processing pipeline with async/await and actor concurrency — existing
- ✓ Real-time progress tracking via Combine publishers — existing
- ✓ Video export using AVFoundation composition — existing
- ✓ Project persistence with UserDefaults — existing
- ✓ Debug reporting system for diagnostic data — existing
- ✓ SwiftUI MVVM architecture with protocol-based services — existing
- ✓ E2E test infrastructure with IoU-based fuzzy matching — v1.0
- ✓ Accessibility-based UI testing with screen object pattern — v1.0
- ✓ Service layer extraction (ProcessingReportManager, ThumbnailService, VideoLoaderService) — v1.0
- ✓ Background video loading for immediate UI dismissal — v1.0

### Active

<!-- Current scope being built toward. -->

- [x] Method abstraction layer — refactor algorithm into swappable "Method" protocol (Phase 4 complete)
- [x] iOS Runner app — dedicated app target with Swifter HTTP server for on-demand segmentation (Phase 5 complete)
- [x] Dashboard backend — Node.js server proxying to iOS Runner, managing runs and artifacts (Phase 6 complete)
- [x] React dashboard — web UI for triggering runs, viewing results, comparing methods (Phase 6 complete)
- [ ] Method registry — Hierarchical method definitions (family/version/configs) with Swift/JSON parallelism enforcement
- [ ] Ground truth comparison — timeline overlay showing method vs. ground truth alignment
- [ ] Intermediate data visualization — spectral flux curves, audio peaks, synced with video

## Current Milestone: v1.1 DevX for Algorithm Iteration

**Goal:** Enable rapid comparison and tuning of detection methods through a dedicated iOS Runner app, Node.js dashboard backend, and React-based visualization tool.

**Architecture:**
- **iOS Runner** — SportCrunchRunner target with embedded Swifter HTTP server
- **Dashboard Backend** — Node.js server managing runs and artifacts
- **React Dashboard** — Web UI for triggering runs and visualizing results
- **Method Registry** — JSON files defining methods with config schemas

**Target features:**
- Method abstraction that makes algorithm implementations swappable (Phase 4 - complete)
- iOS Runner app receiving run requests via HTTP and returning segmentation results
- Dashboard triggering runs, displaying timelines, and comparing results to ground truth
- Side-by-side comparison of multiple methods on the same video
- Bespoke visualizations for intermediate data (spectral flux, audio peaks)

### Out of Scope

<!-- Explicit boundaries. -->

- Multi-sport support beyond tennis (v1 focus on tennis only) — will expand after tennis is proven
- Cloud processing or cloud storage — all processing remains on-device for privacy and speed
- Advanced editing features (trimming segments, filters, text overlays, effects) — keep scope focused on detection and export
- Segment review UI with boundary editing — deferred to future milestone, focus on detection accuracy first
- Real-time streaming export — batch export at run end is sufficient
- Binary format for waveforms — JSON is fine for dev tool
- Progress streaming to browser — poll for completion is sufficient
- Production deployment of dashboard — local dev tool only
- Auto-discovery of iOS Runner — manual IP config is simpler
- Generic visualization framework — bespoke visualizations per method

## Context

This is an existing Swift/SwiftUI codebase with a functional highlight creation pipeline. The app currently supports tennis and cricket with basic audio/visual analysis. The architecture uses:

- Clean MVVM with `@Observable` ViewModels (iOS 17+)
- Protocol-based dependency injection for testability
- Actor-based concurrency for thread-safe media processing
- Sport-specific `AnalysisPreset` configurations for tunable parameters

The current detection algorithm uses:
- Audio onset detection via FFT and spectral flux (Accelerate framework)
- Visual validation via motion detection (CoreGraphics)
- Configurable clustering based on sport mode

Target users are recreational tennis players who record their own matches and want to quickly create shareable highlight reels without manual editing.

**v1.0 Shipped (2026-01-17):**
- 12,459 lines of Swift code
- 72 files modified (+10,713, -4,952)
- Test infrastructure with IoU-based fuzzy matching
- E2E UI tests with accessibility-based element discovery
- Service layer refactoring (ProcessingReportManager, ThumbnailService, VideoLoaderService)
- Background video loading for improved UX
- 19 days from start to ship

## Constraints

- **Platform**: iOS 17+ only — leverages modern SwiftUI and Swift Concurrency features
- **Processing**: All on-device, no cloud backend — privacy-first, no uploads required
- **Performance**: Must process 1-hour videos in reasonable time without overheating or excessive battery drain
- **Tech stack**: Swift + SwiftUI + AVFoundation + Accelerate — no external dependencies

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| On-device processing only | Privacy, speed, no upload time, works offline | ✓ Good |
| Actor-based concurrency | Thread-safe media processing without locks | ✓ Good |
| Protocol-based services | Enables testing with mock implementations | ✓ Good |
| Sport-specific presets | Different sports need different clustering parameters | ✓ Good |
| IoU-based fuzzy matching (0.5 threshold) | Algorithm timing variations require tolerance | ✓ Good (v1.0) |
| Screen object pattern for E2E tests | Semantic element discovery vs brittle coordinates | ✓ Good (v1.0) |
| Optional dependency injection | Backward compatibility for conditional features | ✓ Good (v1.0) |
| Background video loading | Immediate UI dismissal improves UX | ✓ Good (v1.0) |
| Defer segment review UI | Focus on detection accuracy before building curation UX | — Pending |
| Skip CompletedProjectSheet ViewModel extraction | Low priority, can be done later | — Pending (v1.0) |
| iOS Runner with Swifter HTTP server | Direct HTTP communication faster than xcodebuild invocation | ✓ Good (v1.1) |
| Swifter as HTTP library | Lightweight, pure Swift, minimal setup for personal tool | ✓ Good (v1.1) |
| Same project, new target for Runner | Shares existing segmentation code without duplication | ✓ Good (v1.1) |
| Node.js for dashboard backend | Quick to build, good ecosystem for APIs and static files | ✓ Good (v1.1) |
| React for dashboard frontend | Popular, good visualization ecosystem (recharts, etc.) | ✓ Good (v1.1) |
| Filesystem transfer for simulator | Fast iteration, direct write to shared Mac filesystem | ✓ Good (v1.1) |
| HTTP transfer for physical devices | Required for devices that don't share filesystem | — Pending (v1.1) |
| Bespoke visualizations per method | Tightly coupled to method's intermediate data, no generic abstraction | — Pending (v1.1) |
| JSON method registry | Version-controlled, easy to edit, single source of truth | — Pending (v1.1) |
| Dashboard directory at root level | Separate from app directory for clearer separation of concerns | ✓ Good (v1.1) |
| DeviceManager with devicectl | macOS-only device management using devicectl CLI tool | ✓ Good (v1.1) |
| Multi-device support in Phase 6 | Device selection UI built alongside core dashboard (not deferred) | ✓ Good (v1.1) |
| run-map.json for persistence | JSON file tracking runs for dashboard restart resilience | ✓ Good (v1.1) |
| nodemon for backend dev | Auto-restart on file changes improves iteration speed | ✓ Good (v1.1) |
| Enhanced styling early | Invest in UI polish during initial build for better testing UX | ✓ Good (v1.1) |
| Hierarchical method registry (family/version/configs) | Multi-version support with config variants, not flat structure | — Pending (v1.1) |
| Methods in app/ folder, dashboard reads | Source of truth in app codebase, dashboard is read-only consumer | — Pending (v1.1) |
| Build-time JSON-Swift parallelism enforcement | Prevent divergence between method definitions and implementations | — Pending (v1.1) |
| Read-only method registry UI | Dashboard selects methods/configs, doesn't edit them | — Pending (v1.1) |

**v1.1 Progress (2026-01-22):**
- Phase 5 (iOS Runner Core): Complete - HTTP server, run execution, filesystem transfer
- Phase 6 (Dashboard Backend & Web Core): Complete - Node.js backend, React UI, timeline visualization, device management
- Next: Phase 7 (Method Registry) for JSON-based method definitions

---
*Last updated: 2026-01-22 after Phase 6 completion*
