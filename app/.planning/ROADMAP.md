# Roadmap: SportCrunch

## Overview

This roadmap focuses on establishing a robust test suite and improving codebase quality. The journey starts with test infrastructure and a golden test suite (test videos + ground truth segments + evaluation metrics), then uses that safety net to refactor debugging systems, clean up service layers, and improve algorithm readability. The goal is velocity through confidence: move faster knowing core functionality won't break.

## Domain Expertise

None

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Test Infrastructure & Baseline** - Set up XCTest framework and establish E2E test patterns (3/3 plans complete)
- [x] **Phase 2: Core E2E Test Coverage** - Export flows, UI navigation, error handling tests (2/2 plans complete)
- [ ] **Phase 3: Service Layer + UI Cleanup** - Refactor services + UI with test safety net (1/3 plans complete)
- [ ] **Phase 4: Algorithm Readability** - Clean up detection algorithm code
- [ ] **Phase 5: Validation & Documentation** - Full suite validation and pattern documentation

## Phase Details

### Phase 1: Test Infrastructure & Baseline
**Goal**: Establish XCTest framework with async/await support and E2E test patterns for video processing pipeline
**Depends on**: Nothing (first phase)
**Research**: Likely (XCTest patterns for AVFoundation, async testing strategies)
**Research topics**: XCTest async/await patterns, testing AVFoundation pipelines, Swift Testing best practices 2025
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 2: Core E2E Test Coverage
**Goal**: Build tests for export flows, UI navigation, and error handling paths
**Depends on**: Phase 1
**Research**: Unlikely (following Phase 1 patterns)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 3: Service Layer + UI Cleanup
**Goal**: Refactor service protocols, implementations and UI for clarity and separation of concerns. 
**Depends on**: Phase 2
**Research**: Unlikely (internal refactoring with test coverage)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 4: Algorithm Readability
**Goal**: Clean up detection algorithm code (easier now that debug code is separated)
**Depends on**: Phase 3
**Research**: Unlikely (internal cleanup following established patterns)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 5: Validation & Documentation
**Goal**: Run full test suite, validate no regressions, document patterns for future work
**Depends on**: Phase 4
**Research**: Unlikely (validating existing work, documenting patterns)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Test Infrastructure & Baseline | 3/3 | Complete | 2026-01-11 |
| 2. Core E2E Test Coverage | 2/2 | Complete | 2026-01-13 |
| 3. Service Layer Cleanup | 1/3 | In progress | - |
| 4. Algorithm Readability | 0/TBD | Not started | - |
| 5. Validation & Documentation | 0/TBD | Not started | - |
