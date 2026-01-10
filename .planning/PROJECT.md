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

### Active

<!-- Current scope being built toward. -->

- [ ] Enhanced dead space detection with context-aware modes:
  - Technique videos: Remove all time between gameplay for shot-by-shot compilation
  - Rally videos: Combine audio bursts (ball hits) with visual rally detection to form complete rally segments
- [ ] Export highlights to Photos app (standard iOS export)
- [ ] Golden labeled test suite for algorithm accuracy validation
- [ ] Performance optimization to handle 1-hour videos in reasonable time on real devices

### Out of Scope

<!-- Explicit boundaries. -->

- Multi-sport support beyond tennis (v1 focus on tennis only) — will expand after tennis is proven
- Cloud processing or cloud storage — all processing remains on-device for privacy and speed
- Advanced editing features (trimming segments, filters, text overlays, effects) — keep scope focused on detection and export
- Segment review UI with boundary editing — deferred to future milestone, focus on detection accuracy first

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

## Constraints

- **Platform**: iOS 17+ only — leverages modern SwiftUI and Swift Concurrency features
- **Processing**: All on-device, no cloud backend — privacy-first, no uploads required
- **Performance**: Must process 1-hour videos in reasonable time without overheating or excessive battery drain
- **Tech stack**: Swift + SwiftUI + AVFoundation + Accelerate — no external dependencies

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| On-device processing only | Privacy, speed, no upload time, works offline | — Pending |
| Actor-based concurrency | Thread-safe media processing without locks | ✓ Good |
| Protocol-based services | Enables testing with mock implementations | ✓ Good |
| Sport-specific presets | Different sports need different clustering parameters | ✓ Good |
| Defer segment review UI | Focus on detection accuracy before building curation UX | — Pending |
| Golden test suite approach | Validate algorithm accuracy with labeled ground truth data | — Pending |

---
*Last updated: 2026-01-10 after initialization*
