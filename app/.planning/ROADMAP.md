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

**Milestone Goal:** Enable rapid iteration on detection algorithms through an iOS Runner app with embedded HTTP server, a Node.js dashboard backend, and a React-based visualization tool for comparing methods against ground truth.

**Architecture Overview:**
```
┌─────────────────────────────────────────────────────────────────┐
│                        Dashboard (React)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Comparison  │  │  Run        │  │  Method/Config          │  │
│  │ Views       │  │  Manager    │  │  Registry               │  │
│  └─────────────┘  └──────┬──────┘  └─────────────────────────┘  │
└──────────────────────────┼──────────────────────────────────────┘
                           │ HTTP
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Dashboard Backend (Node.js)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Run         │  │ Artifact    │  │  Runner                 │  │
│  │ Storage     │  │ Storage     │  │  Communication          │  │
│  └─────────────┘  └─────────────┘  └──────────┬──────────────┘  │
└───────────────────────────────────────────────┼─────────────────┘
                                                │ HTTP
                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│        SportCrunchRunner Target (Simulator or Device)            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Swifter     │  │ Segmentation│  │  Result                 │  │
│  │ HTTP Server │  │ Engine      │  │  Exporter               │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

#### Phase 4: Method Protocol Foundation ✅
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

#### Phase 5: iOS Runner Core
**Goal**: Create dedicated iOS Runner target with embedded Swifter HTTP server
**Depends on**: Phase 4
**Requirements**: RUN-01, RUN-02, RUN-03, RUN-04
**Success Criteria** (what must be TRUE):
  1. SportCrunchRunner target exists in SportCrunch.xcodeproj
  2. Swifter HTTP server runs on configurable port (default 8080)
  3. `/health` endpoint returns `{ "status": "ready" }`
  4. `POST /runs` triggers segmentation using SpectralFluxMethod
  5. `GET /runs/:id` returns run status, segments, and artifact paths
  6. Artifacts (segmented video, segments.json) written to shared Mac filesystem (simulator)
  7. Runner UI displays current IP/port and recent run status
**Plans**: 3 plans

Plans:
- [ ] 05-01-PLAN.md — Swifter HTTP server setup + /health endpoint
- [ ] 05-02-PLAN.md — Run execution + result persistence + /runs endpoints
- [ ] 05-03-PLAN.md — Runner minimal UI (IP display, run status list)

#### Phase 6: Dashboard Backend & Web Core
**Goal**: Node.js backend + React dashboard for triggering runs and viewing results
**Depends on**: Phase 5
**Requirements**: DASH-01, DASH-02, DASH-03, DASH-04
**Success Criteria** (what must be TRUE):
  1. Node.js backend serves React frontend and proxies to iOS Runner
  2. Dashboard can trigger `POST /runs` to iOS Runner
  3. Dashboard displays run status and detected segments
  4. Timeline visualization shows kept/rejected segments
  5. Video player plays segmented output alongside timeline
**Plans**: TBD

Plans:
- [ ] 06-01: Node.js backend + Runner communication
- [ ] 06-02: React dashboard + run triggering UI
- [ ] 06-03: Segment timeline + video player integration

#### Phase 7: Method Registry
**Goal**: JSON-based method definitions with dynamic configuration
**Depends on**: Phase 6
**Requirements**: REG-01, REG-02, REG-03, REG-04
**Success Criteria** (what must be TRUE):
  1. Method definitions stored in `methods/*.json` files
  2. iOS Runner reads method definitions from bundle at startup
  3. Dashboard displays available methods from registry
  4. Dashboard generates config forms dynamically from `config_schema`
  5. Audio-only method variant (spectral flux without visual validation) exists
**Plans**: TBD

Plans:
- [ ] 07-01: Method JSON schema + initial method definitions
- [ ] 07-02: Runner method registry loading
- [ ] 07-03: Dashboard method selection + dynamic config forms

#### Phase 8: Comparison & Ground Truth
**Goal**: Side-by-side comparison with ground truth and metrics
**Depends on**: Phase 7
**Requirements**: COMP-01, COMP-02, COMP-03, COMP-04
**Success Criteria** (what must be TRUE):
  1. Ground truth JSON files load and display on timeline
  2. Timeline shows method result vs. ground truth alignment
  3. Metrics calculated: precision, recall, IoU
  4. Comparison view shows 2+ runs side-by-side
  5. Run metadata includes commit hash for reproducibility
**Plans**: TBD

Plans:
- [ ] 08-01: Ground truth loading + timeline overlay
- [ ] 08-02: Metrics calculation (precision, recall, IoU)
- [ ] 08-03: Multi-run comparison view

#### Phase 9: Intermediate Visualization & Polish
**Goal**: Bespoke visualizations for intermediate data + device support
**Depends on**: Phase 8
**Requirements**: VIZ-01, VIZ-02, VIZ-03, DEV-01, DEV-02
**Success Criteria** (what must be TRUE):
  1. Methods emit intermediate data during execution
  2. Spectral flux visualization component renders audio waveform + peaks
  3. Video playback syncs with intermediate data visualization
  4. Segment decisions annotated with peak amplitude/threshold info
  5. HTTP artifact transfer works for physical devices
  6. Manual IP configuration in dashboard settings
**Plans**: TBD

Plans:
- [ ] 09-01: Intermediate data schema + method emission
- [ ] 09-02: Spectral flux visualization component
- [ ] 09-03: Device HTTP transfer + IP configuration

## Progress

**Execution Order:**
Phases execute in numeric order: 4 -> 5 -> 6 -> 7 -> 8 -> 9

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Test Infrastructure & Baseline | v1.0 | 3/3 | Complete | 2026-01-14 |
| 2. Core E2E Test Coverage | v1.0 | 2/2 | Complete | 2026-01-15 |
| 3. Service Layer + UI Cleanup | v1.0 | 3/4 | Complete | 2026-01-17 |
| 4. Method Protocol Foundation | v1.1 | 1/1 | Complete | 2026-01-20 |
| 5. iOS Runner Core | v1.1 | 0/3 | Planned | - |
| 6. Dashboard Backend & Web Core | v1.1 | 0/3 | Not started | - |
| 7. Method Registry | v1.1 | 0/3 | Not started | - |
| 8. Comparison & Ground Truth | v1.1 | 0/3 | Not started | - |
| 9. Intermediate Visualization & Polish | v1.1 | 0/3 | Not started | - |
