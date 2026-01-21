# Phase 5: iOS Runner Core - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Create a dedicated iOS Runner target (SportCrunchRunner) with an embedded Swifter HTTP server that accepts run requests, executes segmentation using the Method protocol, and exports results to the filesystem for dashboard consumption.

This is a developer-facing tool — triggered from the Node.js dashboard, not a user-facing app.

</domain>

<decisions>
## Implementation Decisions

### Run Execution Flow
- **One at a time (queue)**: Requests queue up. If a run is in progress, new requests wait.
- **Interruption handling**: Interrupted runs (app backgrounded, killed, crash) marked as failed. Partial artifacts deleted.
- **No time limits**: Runs execute until complete, no matter how long. No timeouts or resource constraints.
- **Status communication**: Dashboard polls `GET /runs/:id` to check status. No push updates (SSE/WebSocket).

### Result Export Format
- **segments.json**: Minimal format (startTime, endTime, type only)
- **Intermediate data**: Separate files per method (e.g., `spectral_flux_peaks.json`). Each method defines its own intermediate data structure.
- **File naming**: Timestamp + method name format: `20260121-143022-SpectralFlux-segments.json`
- **Schema definitions**: Swift protocol defines intermediate data structure. TypeScript types manually kept in sync with embedded comments in both files to ensure synchronization.

### Xcode Manual Steps
Claude must STOP and request manual intervention for:
- **Creating SportCrunchRunner target**: User will create new target in Xcode
- **Configuring schemes**: User will set up build/run configurations
- **DO NOT touch**: `.xcodeproj` or `.xcworkspace` files

Claude CAN:
- Add Swifter SPM dependency (user will resolve in Xcode if needed)
- Create source files for the runner target
- Write server implementation code

### Claude's Discretion
- HTTP server port configuration (default 8080, but allow override)
- Run storage/persistence mechanism (in-memory, file-based, etc.)
- Artifact directory structure under shared filesystem
- Progress reporting granularity during run execution
- Error response format details

</decisions>

<specifics>
## Specific Ideas

**Intermediate data synchronization:**
- Embedded comments in Swift protocols AND TypeScript type files
- Comments MUST remind Claude to keep both in sync
- Example: "SYNC: This structure mirrors IntermediateDataProtocol in Swift. Update both when changing."

**Filesystem transfer (simulator):**
- Runner writes artifacts to shared Mac filesystem location
- Dashboard backend reads from same location
- Path configuration should be explicit in both systems

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-ios-runner-core*
*Context gathered: 2026-01-21*
