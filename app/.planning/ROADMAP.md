# Roadmap: SportCrunch

## Milestones

- **v1.0 Test Infrastructure & Service Layer** - Phases 1-3 (shipped 2026-01-17)
- **v1.1 DevX for Algorithm Iteration** - Phases 4-8 (in progress)

## Phases

<details>
<summary>v1.0 Test Infrastructure & Service Layer (Phases 1-3) - SHIPPED 2026-01-17</summary>

### Phase 1: Test Infrastructure & Baseline
**Goal**: Establish testing foundation with fuzzy segment matching
**Plans**: 3 plans

Plans:
- [x] 01-01: Test infrastructure with IoU-based matching
- [x] 01-02: Baseline test coverage
- [x] 01-03: CI integration

### Phase 2: Core E2E Test Coverage
**Goal**: Comprehensive UI test coverage with accessibility identifiers
**Plans**: 2 plans

Plans:
- [x] 02-01: Accessibility identifiers throughout app
- [x] 02-02: E2E UI test suite

### Phase 3: Service Layer + UI Cleanup
**Goal**: Extract services for testability and clean architecture
**Plans**: 4 plans (03-03 skipped)

Plans:
- [x] 03-01: ProcessingReportManager extraction
- [x] 03-02: ThumbnailService extraction
- [x] 03-03: CompletedProjectSheet ViewModel extraction (SKIPPED)
- [x] 03-04: VideoLoaderService with background loading

</details>

### v1.1 DevX for Algorithm Iteration (In Progress)

**Milestone Goal:** Enable rapid iteration on detection algorithms through swappable methods, data export, and browser-based visualization tools.

#### Phase 4: Method Protocol Foundation
**Goal**: Establish swappable detection algorithm abstraction
**Depends on**: Phase 3 (v1.0 complete)
**Requirements**: METH-01, METH-02
**Success Criteria** (what must be TRUE):
  1. A Method protocol defines the interface that detection algorithms implement
  2. Current spectral flux + visual validation algorithm runs through the Method interface
  3. New Method implementations can be added without modifying existing code
**Plans**: 1 plan

Plans:
- [x] 04-01-PLAN.md — SegmentationMethod protocol + SpectralFluxMethod implementation + service wiring

#### Phase 5: Method Variants & Intermediate Data
**Goal**: Extend method framework with variants and observable processing data
**Depends on**: Phase 4
**Requirements**: METH-03, METH-04
**Success Criteria** (what must be TRUE):
  1. Audio-only method variant exists (spectral flux without visual validation)
  2. Methods emit intermediate processing data during execution
  3. Different methods can emit different types of intermediate data
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

#### Phase 6: Data Export
**Goal**: Export segment results and intermediate data for external tooling
**Depends on**: Phase 5
**Requirements**: EXPRT-01, EXPRT-02, EXPRT-03, EXPRT-04
**Success Criteria** (what must be TRUE):
  1. XCTest runs produce JSON files with final segment results (timestamps, durations)
  2. XCTest runs produce JSON files with intermediate data (waveform, spectral flux, method-specific)
  3. Export outputs go to a consistent, predictable path that external tools can read
  4. Developer can trigger export by running test command
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD

#### Phase 7: Browser Tool Core
**Goal**: Web-based tool to trigger tests and display results
**Depends on**: Phase 6
**Requirements**: BROW-01, BROW-02, BROW-03
**Success Criteria** (what must be TRUE):
  1. Local web server serves the visualization tool
  2. Developer can trigger xcodebuild test runs from browser UI
  3. Browser displays detected segments and test results
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD

#### Phase 8: Visualization & Comparison
**Goal**: Rich visualization of intermediate data and method comparison
**Depends on**: Phase 7
**Requirements**: BROW-04, BROW-05
**Success Criteria** (what must be TRUE):
  1. Waveform and spectral flux visualizations render for audio-based methods
  2. Developer can view side-by-side comparison of two methods on the same video
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 4 -> 5 -> 6 -> 7 -> 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Test Infrastructure & Baseline | v1.0 | 3/3 | Complete | 2026-01-14 |
| 2. Core E2E Test Coverage | v1.0 | 2/2 | Complete | 2026-01-15 |
| 3. Service Layer + UI Cleanup | v1.0 | 3/4 | Complete | 2026-01-17 |
| 4. Method Protocol Foundation | v1.1 | 1/1 | Complete | 2026-01-20 |
| 5. Method Variants & Intermediate Data | v1.1 | 0/? | Not started | - |
| 6. Data Export | v1.1 | 0/? | Not started | - |
| 7. Browser Tool Core | v1.1 | 0/? | Not started | - |
| 8. Visualization & Comparison | v1.1 | 0/? | Not started | - |
