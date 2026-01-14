# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-10)

**Core value:** Accurate, on-device segment detection that identifies rallies and shots without missing good moments or including dead space, while processing efficiently enough for 1-hour videos.
**Current focus:** Phase 3 — Debugging System Refactor

## Current Position

Phase: 3 of 6 (Debugging System Refactor)
Plan: 1 of 3 in current phase
Status: In progress
Last activity: 2026-01-14 — Completed 03-01-PLAN.md

Progress: ██████░░ 75% (6 of 8 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 7.3 min
- Total execution time: 0.73 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Test Infrastructure & Baseline | 3 | 16 min | 5.3 min |
| 2. Core E2E Test Coverage | 2 | 13 min | 6.5 min |
| 3. Service Layer + UI Cleanup | 1 | 15 min | 15 min |

**Recent Trend:**
- Last 5 plans: 1 min, 5 min, 6.5 min, 6.5 min, 15 min
- Trend: Refactoring plans take longer than test infrastructure

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
| 03 | Actor-based ProcessingReportManager | Thread-safe debug report operations |
| 03 | Optional dependency injection for debug manager | Backward compatibility: nil = no debug reporting |

### Deferred Issues

None yet.

### Blockers/Concerns

None

## Session Continuity

Last session: 2026-01-14T10:15:00Z
Stopped at: Completed 03-01-PLAN.md - ProcessingReportManager extraction
Resume file: None

**Phase 3 Status:**
- ✅ 03-01 complete: ProcessingReportManager extraction (VideoProcessingService 884→675 lines)
- ⏳ 03-02 pending: Progress tracking refactor
- ⏳ 03-03 pending: UI cleanup

**Next Steps:**
1. Execute 03-02-PLAN.md: Progress tracking refactor
