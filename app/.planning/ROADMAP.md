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
- [ ] **Phase 2: Core E2E Test Coverage** - Export flows, UI navigation, error handling tests (1/2 plans complete)
- [ ] **Phase 3: Debugging System Refactor** - Extract debug logging from algorithm code
- [ ] **Phase 4: Service Layer Cleanup** - Refactor services with test safety net
- [ ] **Phase 5: Algorithm Readability** - Clean up detection algorithm code
- [ ] **Phase 6: Validation & Documentation** - Full suite validation and pattern documentation

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

### Phase 3: Debugging System Refactor
**Goal**: Extract debug logging infrastructure from algorithm code without losing any detail or functionality
**Depends on**: Phase 2 (safety net in place)
**Research**: Unlikely (internal refactoring, moving existing code)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 4: Service Layer Cleanup
**Goal**: Refactor service protocols and implementations for clarity and separation of concerns
**Depends on**: Phase 3
**Research**: Unlikely (internal refactoring with test coverage)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 5: Algorithm Readability
**Goal**: Clean up detection algorithm code (easier now that debug code is separated)
**Depends on**: Phase 4
**Research**: Unlikely (internal cleanup following established patterns)
**Plans**: TBD

Plans:
- TBD (determined during phase planning)

### Phase 6: Validation & Documentation
**Goal**: Run full test suite, validate no regressions, document patterns for future work
**Depends on**: Phase 5
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
| 2. Core E2E Test Coverage | 1/2 | In progress | - |
| 3. Debugging System Refactor | 0/TBD | Not started | - |
| 4. Service Layer Cleanup | 0/TBD | Not started | - |
| 5. Algorithm Readability | 0/TBD | Not started | - |
| 6. Validation & Documentation | 0/TBD | Not started | - |
