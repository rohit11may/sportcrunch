# Requirements: SportCrunch

**Defined:** 2026-01-21
**Core Value:** Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space.

## v1.1 Requirements

Requirements for the Evaluation Dashboard system. Each maps to roadmap phases.

### iOS Method Framework (Phase 4 - Complete)

- [x] **METH-01**: Method protocol defines interface for swappable detection algorithms
- [x] **METH-02**: Current spectral flux + visual validation refactored into Method implementation

### iOS Runner (Phase 5)

- [ ] **RUN-01**: SportCrunchRunner target in SportCrunch.xcodeproj with Swifter HTTP server
- [ ] **RUN-02**: `/health` endpoint returns ready status; `/runs` POST triggers segmentation
- [ ] **RUN-03**: `GET /runs/:id` returns run status, segments, and artifact locations
- [ ] **RUN-04**: Artifacts written to shared Mac filesystem for simulator transfer mode

### Dashboard Backend & Web Core (Phase 6)

- [ ] **DASH-01**: Node.js backend serves React frontend and proxies requests to iOS Runner
- [ ] **DASH-02**: Dashboard triggers `POST /runs` to iOS Runner with method/config/video selection
- [ ] **DASH-03**: Dashboard displays run status and detected segments on timeline
- [ ] **DASH-04**: Video player plays segmented output synced with timeline visualization

### Method Registry (Phase 7)

- [ ] **REG-01**: Method definitions stored in `methods/*.json` with config_schema and intermediate_schema
- [ ] **REG-02**: iOS Runner reads method definitions from bundle at startup via `GET /methods`
- [ ] **REG-03**: Dashboard generates config forms dynamically from method's config_schema
- [ ] **REG-04**: Audio-only method variant exists (spectral flux without visual validation)

### Comparison & Ground Truth (Phase 8)

- [ ] **COMP-01**: Ground truth JSON files load and display on timeline overlay
- [ ] **COMP-02**: Timeline shows method result vs. ground truth alignment with match/mismatch colors
- [ ] **COMP-03**: Metrics calculated and displayed: precision, recall, IoU
- [ ] **COMP-04**: Comparison view shows 2+ runs side-by-side with synchronized playback

### Intermediate Visualization & Polish (Phase 9)

- [ ] **VIZ-01**: Methods emit intermediate processing data (spectral flux curve, audio peaks)
- [ ] **VIZ-02**: Spectral flux bespoke visualization component with waveform and peak markers
- [ ] **VIZ-03**: Video playback syncs with intermediate data visualization
- [ ] **DEV-01**: HTTP artifact transfer for physical device support
- [ ] **DEV-02**: Manual IP configuration in dashboard settings for device discovery

## Future Requirements

Deferred to later milestones. Tracked but not in current roadmap.

### Parameter Tuning

- **TUNE-01**: Browser UI to edit method parameters inline
- **TUNE-02**: Re-run with modified parameters without code changes
- **TUNE-03**: Parameter impact visualization (before/after diff)

### Advanced Methods

- **ADV-01**: ML-based onset detection method
- **ADV-02**: Method-specific visualization adapters (different methods show different data)
- **ADV-03**: Hot-swappable methods at runtime

### Method Versioning

- **VER-01**: Commit hash tracking per run for reproducibility
- **VER-02**: Method duplication UI (creates new JSON with incremented version)
- **VER-03**: Run history per method with filtering

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time streaming export | Batch export at run end is sufficient for iteration |
| Binary format for waveforms | JSON is fine for dev tool, simplicity over performance |
| Progress streaming to browser | Poll for completion is sufficient |
| Production deployment of dashboard | Local dev tool only |
| Generic visualization framework | Bespoke visualizations tightly coupled to methods |
| Auto-discovery of iOS Runner | Manual IP config is simpler for personal tool |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| METH-01 | Phase 4 | Complete |
| METH-02 | Phase 4 | Complete |
| RUN-01 | Phase 5 | Pending |
| RUN-02 | Phase 5 | Pending |
| RUN-03 | Phase 5 | Pending |
| RUN-04 | Phase 5 | Pending |
| DASH-01 | Phase 6 | Pending |
| DASH-02 | Phase 6 | Pending |
| DASH-03 | Phase 6 | Pending |
| DASH-04 | Phase 6 | Pending |
| REG-01 | Phase 7 | Pending |
| REG-02 | Phase 7 | Pending |
| REG-03 | Phase 7 | Pending |
| REG-04 | Phase 7 | Pending |
| COMP-01 | Phase 8 | Pending |
| COMP-02 | Phase 8 | Pending |
| COMP-03 | Phase 8 | Pending |
| COMP-04 | Phase 8 | Pending |
| VIZ-01 | Phase 9 | Pending |
| VIZ-02 | Phase 9 | Pending |
| VIZ-03 | Phase 9 | Pending |
| DEV-01 | Phase 9 | Pending |
| DEV-02 | Phase 9 | Pending |

**Coverage:**
- v1.1 requirements: 23 total (2 complete, 21 pending)
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-01-21*
*Last updated: 2026-01-21 after evaluation dashboard pivot*
