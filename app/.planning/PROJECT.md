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

(None - project completed at v1.0)

### Out of Scope

<!-- Explicit boundaries. -->

- Multi-sport support beyond tennis (v1 focus on tennis only) — will expand after tennis is proven
- Cloud processing or cloud storage — all processing remains on-device for privacy and speed
- Advanced editing features (trimming segments, filters, text overlays, effects) — keep scope focused on detection and export
- Segment review UI with boundary editing — deferred to future milestone, focus on detection accuracy first
- Enhanced dead space detection modes — deferred (original Active requirement)
- Export highlights to Photos app — deferred (original Active requirement)
- Golden labeled test suite — deferred (original Active requirement)
- Performance optimization for 1-hour videos — deferred (original Active requirement)
- Algorithm readability improvements — deferred (Phase 4)
- Full suite validation and documentation — deferred (Phase 5)

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

---
*Last updated: 2026-01-17 after v1.0 milestone completion*
