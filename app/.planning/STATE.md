# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-10)

**Core value:** Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space, while processing efficiently enough for 1-hour videos.
**Current focus:** Phase 3 — Debugging System Refactor

## Current Position

Phase: 3 of 6 (Debugging System Refactor)
Plan: 1 of 3 in current phase
Status: Pending
Last activity: 2026-01-13 — Completed 02-02-PLAN.md

Progress: █████░░ 71% (5 of 7 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: 5.2 min
- Total execution time: 0.43 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Test Infrastructure & Baseline | 3 | 16 min | 5.3 min |
| 2. Core E2E Test Coverage | 2 | 13 min | 6.5 min |

**Recent Trend:**
- Last 5 plans: 8 min, 1 min, 5 min, 6.5 min
- Trend: Stable velocity with slight increase in scope

## Accumulated Context

Always use iPhone 17 device for xcodebuild and any testing commands for a simulator.

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

| Phase | Decision | Rationale |
|-------|----------|-----------|
| 01 | IoU threshold default: 0.5 | Standard threshold for object detection tasks, can tune per-test in Phase 2 |
| 01 | FP/FN guardrails: <15% FP, <10% FN | Stricter on false negatives - missing segments worse than including extra |
| 01 | Ground truth format: JSON | Human-readable, easy to create manually, Codable for Swift integration |
| 01 | Use real VideoProcessingService for E2E tests | Validates full pipeline integration vs mocking |
| 01 | Always output FPR/FNR metrics in tests | Provides visibility into detection quality over time |
| 01 | Smoke timeout: 5 minutes | Quick feedback loop for development |
| 01 | Regression timeout: 30 minutes | Room for growth as test suite expands |
| 01 | Code coverage in regression only | Not needed for quick smoke runs |
| 02 | Symlink AccessibilityIdentifiers.swift | Share constants between app and UITests targets without duplication |
| 02 | Screen object pattern for E2E tests | Typed properties for semantic element discovery |

### Deferred Issues

None yet.

### Blockers/Concerns

None

## Session Continuity

Last session: 2026-01-13T12:09:18Z
Stopped at: Completed 02-01-PLAN.md - Accessibility infrastructure
Resume file: None

**Phase 2 Status:**
- ✅ 02-01 complete: Accessibility infrastructure
- ✅ 02-02 complete: E2E test implementation

**Next Steps:**
1. Begin Phase 3: Debugging System Refactor
