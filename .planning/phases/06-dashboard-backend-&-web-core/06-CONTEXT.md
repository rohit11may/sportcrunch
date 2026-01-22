# Phase 6: Dashboard Backend & Web Core - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a Node.js backend that proxies to the iOS Runner and a React frontend that allows triggering runs, viewing results, and playing segmented videos with timeline visualization. Ground truth comparison and metrics are Phase 8's domain.

</domain>

<decisions>
## Implementation Decisions

### Video input
- Videos stored in designated Mac folder (start with `SportCrunchTests/TestResources/Videos`)
- Dashboard displays available videos in a dropdown
- Also support browser file upload for ad-hoc testing
- Backend handles both: file upload to temp location and direct path passing to iOS Runner

### Run configuration
- User selects detection method only (e.g., SpectralFlux)
- Config parameters use method defaults
- Phase 7 adds dynamic configuration forms
- No manual parameter tuning in Phase 6

### Execution feedback
- Simple loading spinner with status text ("Processing video...")
- Display "Complete" or error message when done
- No progress percentage or real-time log streaming in Phase 6

### Post-run flow
- Auto-navigate to results view immediately after run completes
- Show timeline + video player for the completed run
- No manual navigation required

### Timeline visualization style
- Horizontal colored bars along time axis
- Green bars for kept segments, red/gray bars for rejected segments
- Clear visual distinction between kept and rejected

### Segment interaction
- Clicking a segment scrubs the video player to that timestamp
- Video player plays the segmented output (kept segments only)
- Timeline and video player stay in sync

### Timeline views
- Two views available: "Original segments" (all kept + rejected) and "Final output" (kept only)
- Toggle button to switch between views (e.g., "Show rejected segments")
- When showing original segments: green bars for kept, red/gray bars for rejected
- When showing final output: only green bars (kept segments)

### Layout
- Video player and timeline both prominent (timeline is critical for algorithm iteration)
- Timeline must accommodate future ground truth overlay (Phase 8)

### Claude's Discretion
- Backend architecture (Express vs Fastify, routing patterns)
- Frontend structure (component architecture, state management approach)
- Exact layout positioning (video top/bottom, timeline size)
- Segment hover/tooltip details (timestamps, metadata display)
- Color palette specifics (exact shades of green/red/gray)
- Video player controls (play/pause, seek, volume)

</decisions>

<specifics>
## Specific Ideas

- Videos should come from `SportCrunchTests/TestResources/Videos` folder initially
- Timeline is "quite important" — must be prominent and clear
- User wants to compare timeline fingerprints (ground truth vs segmented) in Phase 8

</specifics>

<deferred>
## Deferred Ideas

- Ground truth loading and comparison — Phase 8
- Metrics calculation (precision, recall, IoU) — Phase 8
- Dynamic configuration forms for method parameters — Phase 7
- Progress percentage or real-time log streaming — future enhancement (not in roadmap)

</deferred>

---

*Phase: 06-dashboard-backend-&-web-core*
*Context gathered: 2026-01-21*
