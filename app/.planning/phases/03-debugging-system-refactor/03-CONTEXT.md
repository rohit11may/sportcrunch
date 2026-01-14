# Phase 3: Debugging System Refactor - Context

**Gathered:** 2026-01-14
**Status:** Ready for planning

<vision>
## How This Should Work

A centralized debug service handles all debug logging. The algorithm code focuses purely on detection logic - when it needs to emit debug info, it just calls the service. No more debug code scattered throughout the algorithm files.

The result is algorithm code that reads like what it actually does: detect rallies and shots. The debugging infrastructure lives elsewhere.

</vision>

<essential>
## What Must Be Nailed

- **Cleaner algorithm code** - The detection logic becomes readable and easy to modify. This is the primary win.
- **Segment boundary visibility** - Debug output must show where segments start/end and what triggered those decisions. This is the critical debug info for tuning.

</essential>

<boundaries>
## What's Out of Scope

- New debug features - just extract what exists, don't add new debugging capabilities
- Changing algorithm logic - only move debug code around, don't modify detection behavior
- This is a pure extraction refactor - no new features, no logic changes

</boundaries>

<specifics>
## Specific Ideas

No specific requirements - open to standard approaches for centralized debug services.

</specifics>

<notes>
## Additional Context

Phase 2 provides the safety net (E2E tests). This refactor can proceed with confidence that behavior won't regress.

The goal is making algorithm code easier to work with for Phase 5 (Algorithm Readability). Getting debug code out of the way first makes that cleanup simpler.

</notes>

---

*Phase: 03-debugging-system-refactor*
*Context gathered: 2026-01-14*
