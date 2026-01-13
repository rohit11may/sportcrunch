# Phase 2: Core E2E Test Coverage - Context

**Gathered:** 2026-01-13
**Status:** Ready for research

<vision>
## How This Should Work

Build E2E tests that verify critical user workflows end-to-end, using semantic/accessibility-based element discovery instead of tight coupling to UI layouts. Tests should survive layout changes and UI refactoring without breaking.

The focus is on testing what users actually do: export video flows and triggering highlight creation. Tests should interact with the UI by semantic purpose (finding the "export button" by its role/accessibility label, not by coordinates or element IDs), making them resilient to future UI changes in Phases 3-5.

</vision>

<essential>
## What Must Be Nailed

- **Coverage of critical user paths** - Export flows and highlight creation triggering must be fully tested end-to-end
- **Semantic element discovery** - Tests find UI elements by purpose/role, not by position or specific IDs, so they survive layout changes
- **Fuzz-resistant testing** - Tests are loose enough to handle minor UI changes but strict enough to catch actual breakage

</essential>

<boundaries>
## What's Out of Scope

- Performance/speed testing - Not measuring how fast exports happen or memory usage
- Algorithm correctness validation - Detection quality validation is Phase 1's job with baselines
- Unit tests - This is E2E only; individual functions get unit coverage elsewhere
- UI visual testing - Not doing pixel-perfect layout or visual regression detection

</boundaries>

<specifics>
## Specific Ideas

- Use XCTest UITest framework with accessibility labels for semantic element discovery
- Tests should find "Export Video" button by its accessibility label/role, not by absolute position
- Brainstorm during planning phase: what's the cleanest way to build these semantic finders as reusable helpers

</specifics>

<notes>
## Additional Context

The user wants tests that can survive refactoring without constant updates. Phase 1 provided the test infrastructure foundation; Phase 2 builds the safety net that will protect refactoring work in Phases 3-5.

Key distinction: fuzzy/semantic E2E tests (what this phase does) vs. unit tests (not doing) vs. performance testing (not doing).

</notes>

---

*Phase: 02-core-e2e-test-coverage*
*Context gathered: 2026-01-13*
