# Requirements: SportCrunch

**Defined:** 2026-01-20
**Core Value:** Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space.

## v1.1 Requirements

Requirements for algorithm iteration DevX. Each maps to roadmap phases.

### iOS Method Framework

- [ ] **METH-01**: Method protocol defines interface for swappable detection algorithms
- [ ] **METH-02**: Current spectral flux + visual validation refactored into Method implementation
- [ ] **METH-03**: Audio-only Method variant (spectral flux without visual validation)
- [ ] **METH-04**: Methods emit intermediate processing data during execution

### Data Export

- [ ] **EXPRT-01**: JSON export of final segment results (timestamps, durations)
- [ ] **EXPRT-02**: JSON export of intermediate data (waveform samples, spectral flux values, method-specific)
- [ ] **EXPRT-03**: Export triggered from XCTest test runs
- [ ] **EXPRT-04**: Consistent output path for browser tool to read (e.g., derived data or tmp)

### Browser Visualization Tool

- [ ] **BROW-01**: Local web server serves the visualization tool
- [ ] **BROW-02**: UI to trigger xcodebuild test commands with method/video selection
- [ ] **BROW-03**: Display of test results and detected segments
- [ ] **BROW-04**: Waveform and spectral flux visualization for audio-based methods
- [ ] **BROW-05**: Side-by-side comparison view of two method outputs on same video

## Future Requirements

Deferred to later milestones. Tracked but not in current roadmap.

### Parameter Tuning

- **TUNE-01**: Browser UI to edit method parameters
- **TUNE-02**: Re-run with modified parameters without code changes
- **TUNE-03**: Parameter impact visualization (before/after diff)

### Advanced Methods

- **ADV-01**: ML-based onset detection method
- **ADV-02**: Method-specific visualization adapters (different methods show different data)
- **ADV-03**: Hot-swappable methods at runtime

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time streaming export | Batch export at test end is sufficient for iteration |
| Binary format for waveforms | JSON is fine for dev tool, simplicity over performance |
| Progress streaming to browser | Poll for completion is sufficient |
| Production deployment of browser tool | Local dev tool only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| METH-01 | Phase 4 | Pending |
| METH-02 | Phase 4 | Pending |
| METH-03 | Phase 5 | Pending |
| METH-04 | Phase 5 | Pending |
| EXPRT-01 | Phase 6 | Pending |
| EXPRT-02 | Phase 6 | Pending |
| EXPRT-03 | Phase 6 | Pending |
| EXPRT-04 | Phase 6 | Pending |
| BROW-01 | Phase 7 | Pending |
| BROW-02 | Phase 7 | Pending |
| BROW-03 | Phase 7 | Pending |
| BROW-04 | Phase 8 | Pending |
| BROW-05 | Phase 8 | Pending |

**Coverage:**
- v1.1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-01-20*
*Last updated: 2026-01-20 after roadmap creation*
