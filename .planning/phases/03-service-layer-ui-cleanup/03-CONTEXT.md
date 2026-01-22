# Phase 3: Service Layer + UI Cleanup - Context

**Gathered:** 2026-01-14
**Status:** Ready for research

<vision>
## How This Should Work

This phase is about refactoring both the service layer and UI layer to make the codebase easier to understand and modify. The approach is sequential: clean up the service layer first (protocols and implementations), then update the UI to properly use the improved services.

Critically, this is a refactoring phase - the app's look and feel should remain visually identical. No user-facing changes. The transformation is entirely internal: making the architecture clearer so that adding features to existing flows in the future is straightforward and low-risk.

The phase should start with research to identify what architectural flaws exist in the current service/UI design, then tackle those issues early before they become harder to fix.

</vision>

<essential>
## What Must Be Nailed

- **Easier to understand code** - Anyone reading the code should quickly grasp what each piece does and how it fits together
- **Safer to modify going forward** - Changes should be low-risk because the architecture makes dependencies and impacts clear
- **Expose and fix architectural flaws early** - Research phase should identify problems with current service/UI design (UI doing too much, unclear service boundaries, tight coupling) and address them before they calcify

The goal is enabling future feature additions to existing flows - being able to extend current functionality with minimal ripple effects.

</essential>

<boundaries>
## What's Out of Scope

- **Algorithm changes** - Don't touch the detection algorithm logic itself - that's Phase 4
- **New features or functionality** - This is refactoring existing code, not adding new capabilities
- **Performance optimization** - Focus on clarity and structure, not making things faster
- **User-facing changes** - The app should look and behave identically; this is purely internal refactoring

</boundaries>

<specifics>
## Specific Ideas

- **Services-first approach**: Tackle service layer cleanup before UI changes
- **Research-driven**: Phase should start with research to identify architectural problems (no known issues yet, but want to surface them)
- **Visual regression testing**: Use the existing E2E test suite (from Phases 1-2) as a safety net to ensure no behavioral changes
- **Clear protocol boundaries**: Services should have clean contracts, implementations shouldn't leak details
- **Lightweight UI**: View controllers should orchestrate but delegate heavy lifting to services

</specifics>

<notes>
## Additional Context

User emphasized that while separation of concerns is important, the priority is readability and maintainability. The refactoring should make it obvious what will break when making changes, reducing the fear factor of touching code.

The existing test suite from Phases 1-2 provides the safety net to refactor with confidence - tests should pass before and after with identical behavior.

</notes>

---

*Phase: 03-service-layer-ui-cleanup*
*Context gathered: 2026-01-14*
