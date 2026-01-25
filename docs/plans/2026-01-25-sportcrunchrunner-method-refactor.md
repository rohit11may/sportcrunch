# SportCrunchRunner Method Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor SportCrunchRunner to use the new unified methods folder structure and delete legacy JSON-based method registry infrastructure.

**Architecture:** SportCrunchRunner currently uses a JSON-based MethodRegistry to load method metadata from bundle and instantiate methods. After the refactor in SportCrunch (documented in 2026-01-24-method-config-refactor-design.md), the methods folder contains Swift-based configs and the Sport enum provides a unified `segmentationMethod(for:)` factory. This plan migrates SportCrunchRunner to use the same pattern, eliminating JSON infrastructure and the MethodRegistry actor.

**Tech Stack:** Swift, SwiftUI, Xcode multi-target project

**Context:**
- SportCrunch and SportCrunchRunner are two targets in the same Xcode project
- The `methods/` folder is shared across both targets (located at `app/methods/`)
- SportCrunch already uses the new Swift-based config pattern (completed in previous plan)
- SportCrunchRunner currently uses MethodRegistry (JSON-based) which is now obsolete
- RunExecutor in SportCrunchRunner already imports and uses Sport.segmentationMethod(for:) correctly

---

## Analysis Summary

### Current State

**SportCrunchRunner structure:**
```
app/SportCrunchRunner/
  Models/
    Run.swift                           # Run model with method/sport/mode fields
    DeviceTypes.swift
  Services/
    MethodRegistry.swift                # LEGACY: JSON-based method registry (250 lines)
    RunExecutor.swift                   # Uses Sport.segmentationMethod(for:) ✓
    RunStore.swift
    ArtifactExporter.swift
    DeviceManager.swift
  Server/
    HTTPServer.swift
    HealthEndpoint.swift
    MethodEndpoints.swift               # LEGACY: Exposes method registry via HTTP
    RunEndpoints.swift
  Views/
    RunnerDashboard.swift
    RunStatusRow.swift
  SportCrunchRunnerApp.swift            # Main app - initializes MethodRegistry
```

**Shared resources (both targets):**
```
app/methods/spectral_flux/              # New Swift-based structure ✓
app/SportCrunch/Core/Models/Sport.swift # Sport enum with segmentationMethod(for:) ✓
app/SportCrunch/Core/Services/SegmentationMethod.swift # Protocol ✓
app/SportCrunch/Core/Models/Project.swift # ActionSegment definition ✓
```

**Key Findings:**

1. **RunExecutor is already correct** (lines 92-109):
   - Parses Sport from run.sport string
   - Calls `sport.segmentationMethod(for: sportMode)`
   - Does NOT use MethodRegistry for method instantiation
   - This is the correct pattern we want everywhere

2. **MethodRegistry is LEGACY** (250 lines):
   - Loads `_index.json` from bundle (which no longer exists)
   - Provides method lookup/instantiation via family/version pattern
   - Only used by MethodEndpoints HTTP API
   - Can be completely deleted

3. **MethodEndpoints is LEGACY** (79 lines):
   - GET /methods - lists all methods from registry
   - GET /methods/:family/:version - gets specific method details
   - Used by external clients to discover available methods
   - Needs replacement with Sport/SportMode-based discovery

4. **Run model has legacy fields** (Run.swift lines 55-57):
   - `method: String` - legacy field (kept for backwards compat)
   - `methodFamily: String?` - never used in new system
   - `methodVersion: String?` - never used in new system
   - Only `sport` and `sportMode` are used by RunExecutor

### Target Architecture

After refactor:

**Discovery pattern:**
- HTTP API exposes Sport enum cases and their available modes
- Clients specify `sport` + `sportMode` (not method family/version)
- Server uses Sport.segmentationMethod(for:) to get configured method
- No method registry needed

**HTTP API endpoints (new):**
```
GET /sports              → List all available sports
GET /sports/:sport/modes → List modes for a sport
POST /runs               → Create run with sport + sportMode
```

**Files to delete:**
- `SportCrunchRunner/Services/MethodRegistry.swift` (250 lines)
- `SportCrunchRunner/Server/MethodEndpoints.swift` (79 lines)

**Files to modify:**
- `SportCrunchRunner/Server/RunEndpoints.swift` - No changes needed (already correct)
- `SportCrunchRunner/SportCrunchRunnerApp.swift` - Remove MethodRegistry initialization
- `SportCrunchRunner/Models/Run.swift` - Mark legacy fields as deprecated

**Files to create:**
- `SportCrunchRunner/Server/SportEndpoints.swift` - New sport/mode discovery API

---

## Implementation Tasks

### Task 1: Create Sport Discovery API

**Goal:** Replace method discovery with sport/mode discovery endpoint.

**Files:**
- Create: `app/SportCrunchRunner/Server/SportEndpoints.swift`

**Step 1: Write SportEndpoints.swift**

Create new HTTP endpoints for sport/mode discovery:

```swift
//
//  SportEndpoints.swift
//  SportCrunchRunner
//
//  Sport and mode discovery HTTP endpoints.
//

import Foundation
import Swifter

/// Registers sport discovery HTTP endpoints
enum SportEndpoints {

    /// Register all sport endpoints on the server
    static func register(on server: HttpServer) {

        // GET /sports - List all available sports
        server.GET["/sports"] = { _ in
            let sports = Sport.allCases.map { sport in
                [
                    "id": sport.rawValue,
                    "displayName": sport.displayName,
                    "description": sport.description,
                    "modes": sport.availableModes.map { mode in
                        [
                            "id": mode.id,
                            "displayName": mode.displayName,
                            "description": mode.description
                        ]
                    }
                ] as [String: Any]
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: sports, options: [.prettyPrinted]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return .internalServerError(.text("{\"error\": \"Failed to encode sports\"}"))
            }

            return .ok(.text(jsonString, contentType: "application/json"))
        }

        // GET /sports/:sport - Get specific sport details
        server.GET["/sports/:sport"] = { request in
            guard let sportId = request.params[":sport"],
                  let sport = Sport(rawValue: sportId) else {
                return .badRequest(.text("{\"error\": \"Invalid sport\"}"))
            }

            let sportInfo: [String: Any] = [
                "id": sport.rawValue,
                "displayName": sport.displayName,
                "description": sport.description,
                "modes": sport.availableModes.map { mode in
                    [
                        "id": mode.id,
                        "displayName": mode.displayName,
                        "description": mode.description
                    ]
                }
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: sportInfo, options: [.prettyPrinted]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return .internalServerError(.text("{\"error\": \"Failed to encode sport\"}"))
            }

            return .ok(.text(jsonString, contentType: "application/json"))
        }

        print("✓ [SportEndpoints] Registered /sports endpoints")
    }
}
```

**Step 2: Verify Sport.swift has availableModes helper**

The Sport enum needs an `availableModes` property. Check if it exists:

```bash
grep -n "availableModes" app/SportCrunch/Core/Models/Sport.swift
```

If not found, proceed to Task 1.3.

**Step 3: Add availableModes helper to Sport.swift (if needed)**

If `availableModes` doesn't exist, add this computed property to Sport enum:

Location: `app/SportCrunch/Core/Models/Sport.swift`

Find the Sport enum definition and add after the `segmentationMethod(for:)` method:

```swift
/// Returns all available modes for this sport
var availableModes: [any SportMode] {
    switch self {
    case .tennis:
        return TennisMode.allCases.map { $0 as any SportMode }
    case .cricket:
        return []  // No modes yet
    }
}
```

**Step 4: Commit**

```bash
git add app/SportCrunchRunner/Server/SportEndpoints.swift
git add app/SportCrunch/Core/Models/Sport.swift  # Only if modified
git commit -m "feat: add sport discovery HTTP endpoints

Replace legacy method registry discovery with sport/mode-based API"
```

---

### Task 2: Update SportCrunchRunnerApp initialization

**Goal:** Remove MethodRegistry initialization and endpoint registration.

**Files:**
- Modify: `app/SportCrunchRunner/SportCrunchRunnerApp.swift`

**Step 1: Read current SportCrunchRunnerApp.swift**

```bash
cat app/SportCrunchRunner/SportCrunchRunnerApp.swift
```

**Step 2: Remove MethodRegistry initialization**

Remove lines 18-19 and 21-22:

```diff
- private let methodRegistry = MethodRegistry()
- private let runExecutor: RunExecutor
+ private let runExecutor: RunExecutor

  init() {
-     runExecutor = RunExecutor(store: runStore, exporter: artifactExporter, registry: methodRegistry)
+     runExecutor = RunExecutor(store: runStore, exporter: artifactExporter)
  }
```

**Step 3: Update endpoint registration in onAppear**

Remove MethodRegistry.loadFromBundle() and MethodEndpoints registration:

```diff
  .onAppear {
-     // Load method registry from bundle
-     Task {
-         await methodRegistry.loadFromBundle()
-     }
-
      // Register endpoints before server starts
      HealthEndpoint.register(on: httpServer)
      RunEndpoints.register(on: httpServer, store: runStore, executor: runExecutor)
-     MethodEndpoints.register(on: httpServer, registry: methodRegistry)
+     SportEndpoints.register(on: httpServer)
      httpServer.start()
  }
```

**Step 4: Verify the changes**

Final SportCrunchRunnerApp.swift should look like:

```swift
@main
struct SportCrunchRunnerApp: App {
    @StateObject private var httpServer = HTTPServer()

    // Initialize services (not @StateObject because they're actors/classes)
    private let runStore = RunStore()
    private let artifactExporter = ArtifactExporter()
    private let deviceManager = DeviceManager()
    private let runExecutor: RunExecutor

    init() {
        runExecutor = RunExecutor(store: runStore, exporter: artifactExporter)
    }

    var body: some Scene {
        WindowGroup {
            RunnerDashboard(server: httpServer, store: runStore, deviceManager: deviceManager)
                .onAppear {
                    // Register endpoints before server starts
                    HealthEndpoint.register(on: httpServer)
                    RunEndpoints.register(on: httpServer, store: runStore, executor: runExecutor)
                    SportEndpoints.register(on: httpServer)
                    httpServer.start()
                }
                .onDisappear {
                    httpServer.stop()
                }
        }
    }
}
```

**Step 5: Commit**

```bash
git add app/SportCrunchRunner/SportCrunchRunnerApp.swift
git commit -m "refactor: remove MethodRegistry initialization

Replace with SportEndpoints for discovery"
```

---

### Task 3: Update RunExecutor signature

**Goal:** Remove MethodRegistry parameter from RunExecutor (no longer needed).

**Files:**
- Modify: `app/SportCrunchRunner/Services/RunExecutor.swift`

**Step 1: Read current RunExecutor.swift**

```bash
cat app/SportCrunchRunner/Services/RunExecutor.swift
```

**Step 2: Check if RunExecutor uses MethodRegistry**

Search for any usage of registry parameter:

```bash
grep -n "registry" app/SportCrunchRunner/Services/RunExecutor.swift
```

Expected result: No matches (RunExecutor already uses Sport.segmentationMethod)

**Step 3: Remove registry parameter from init (if present)**

If the init method has a `registry` parameter, remove it:

```diff
- init(store: RunStore, exporter: ArtifactExporter, registry: MethodRegistry) {
+ init(store: RunStore, exporter: ArtifactExporter) {
      self.store = store
      self.exporter = exporter
-     self.registry = registry
  }
```

And remove the property declaration:

```diff
  // MARK: - Dependencies

  private let store: RunStore
  private let exporter: ArtifactExporter
- private let registry: MethodRegistry
```

**Step 4: Build to verify no compilation errors**

```bash
cd app
xcodebuild build -project SportCrunch.xcodeproj -scheme SportCrunchRunner -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add app/SportCrunchRunner/Services/RunExecutor.swift
git commit -m "refactor: remove MethodRegistry dependency from RunExecutor

RunExecutor already uses Sport.segmentationMethod(for:) correctly"
```

---

### Task 4: Mark legacy fields in Run model as deprecated

**Goal:** Document that method/methodFamily/methodVersion fields are legacy.

**Files:**
- Modify: `app/SportCrunchRunner/Models/Run.swift`

**Step 1: Add deprecation warnings to legacy fields**

Update Run struct (lines 55-57):

```diff
  struct Run: Identifiable, Codable, Sendable {
      let id: UUID
      var status: RunStatus
      let videoPath: String
-     let method: String  // Legacy: kept for backwards compatibility
-     let methodFamily: String?  // New: method family (e.g., "spectral_flux")
-     let methodVersion: String?  // New: method version (e.g., "v1", "v2")
+     @available(*, deprecated, message: "Legacy field - use sport + sportMode instead")
+     let method: String
+     @available(*, deprecated, message: "Legacy field - not used in new architecture")
+     let methodFamily: String?
+     @available(*, deprecated, message: "Legacy field - not used in new architecture")
+     let methodVersion: String?
      let sport: String
      let sportMode: String?
```

**Step 2: Update init documentation**

Add comment to init explaining the parameters:

```swift
init(
    id: UUID = UUID(),
    status: RunStatus = .queued,
    videoPath: String,
    method: String,  // Legacy - ignored in execution
    methodFamily: String? = nil,  // Legacy - ignored in execution
    methodVersion: String? = nil,  // Legacy - ignored in execution
    sport: String,  // Used: Sport.rawValue
    sportMode: String? = nil,  // Used: TennisMode.rawValue or nil
    config: [String: String] = [:],
    deviceTarget: DeviceTarget = .simulator
) {
```

**Step 3: Commit**

```bash
git add app/SportCrunchRunner/Models/Run.swift
git commit -m "docs: mark legacy method fields as deprecated in Run model

Only sport + sportMode are used in new architecture"
```

---

### Task 5: Delete MethodRegistry

**Goal:** Remove obsolete MethodRegistry infrastructure.

**Files:**
- Delete: `app/SportCrunchRunner/Services/MethodRegistry.swift`

**Step 1: Verify no references to MethodRegistry**

Search for any remaining imports or usage:

```bash
grep -r "MethodRegistry" app/SportCrunchRunner --include="*.swift"
```

Expected result: No matches (we removed all usage in previous tasks)

If matches found, STOP and fix those files first.

**Step 2: Delete the file**

```bash
rm app/SportCrunchRunner/Services/MethodRegistry.swift
```

**Step 3: Remove from Xcode project**

DEFER TO HUMAN: The user needs to manually remove MethodRegistry.swift from the Xcode project:
1. Open SportCrunch.xcodeproj in Xcode
2. Find MethodRegistry.swift in the Project Navigator (under SportCrunchRunner/Services)
3. Right-click → Delete → Move to Trash

**Step 4: Commit**

```bash
git add app/SportCrunchRunner/Services/MethodRegistry.swift
git commit -m "refactor: delete obsolete MethodRegistry infrastructure

Replaced by Sport.segmentationMethod(for:) pattern"
```

---

### Task 6: Delete MethodEndpoints

**Goal:** Remove obsolete method discovery HTTP endpoints.

**Files:**
- Delete: `app/SportCrunchRunner/Server/MethodEndpoints.swift`

**Step 1: Verify no references to MethodEndpoints**

Search for any remaining imports or usage:

```bash
grep -r "MethodEndpoints" app/SportCrunchRunner --include="*.swift"
```

Expected result: No matches (we removed registration in Task 2)

If matches found, STOP and fix those files first.

**Step 2: Delete the file**

```bash
rm app/SportCrunchRunner/Server/MethodEndpoints.swift
```

**Step 3: Remove from Xcode project**

DEFER TO HUMAN: The user needs to manually remove MethodEndpoints.swift from the Xcode project:
1. Open SportCrunch.xcodeproj in Xcode
2. Find MethodEndpoints.swift in the Project Navigator (under SportCrunchRunner/Server)
3. Right-click → Delete → Move to Trash

**Step 4: Commit**

```bash
git add app/SportCrunchRunner/Server/MethodEndpoints.swift
git commit -m "refactor: delete obsolete MethodEndpoints HTTP API

Replaced by SportEndpoints for discovery"
```

---

### Task 7: Verify build and test

**Goal:** Ensure SportCrunchRunner builds and basic functionality works.

**Step 1: Clean build directory**

```bash
cd app
rm -rf .build
rm -rf ~/Library/Developer/Xcode/DerivedData/SportCrunch-*
```

**Step 2: Build SportCrunchRunner**

```bash
xcodebuild clean build -project SportCrunch.xcodeproj -scheme SportCrunchRunner -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: BUILD SUCCEEDED

If build fails, read error messages and fix before proceeding.

**Step 3: Test HTTP endpoints (manual verification)**

Run SportCrunchRunner in simulator and test new endpoints:

```bash
# List all sports
curl http://localhost:8080/sports | jq

# Get tennis details
curl http://localhost:8080/sports/tennis | jq

# Health check
curl http://localhost:8080/health
```

Expected responses:
- `/sports` - JSON array with tennis/cricket + modes
- `/sports/tennis` - JSON object with tennis modes
- `/health` - "OK"

**Step 4: Document manual testing results**

Create a test summary in the terminal output showing:
- All endpoints return valid JSON
- Tennis has rally + individual modes
- No 500 errors

**Step 5: Commit verification**

No commit needed - this is verification only.

---

### Task 8: Update documentation

**Goal:** Document the new API for clients.

**Files:**
- Create: `app/SportCrunchRunner/API.md`

**Step 1: Write API documentation**

```markdown
# SportCrunchRunner HTTP API

## Overview

SportCrunchRunner provides an HTTP API for triggering video segmentation runs. The API uses a sport + mode discovery pattern instead of method family/version.

**Base URL:** `http://localhost:8080` (when running in simulator)

---

## Endpoints

### Health Check

**GET** `/health`

Returns server health status.

**Response:**
```
200 OK
Body: "OK"
```

---

### Sport Discovery

**GET** `/sports`

List all available sports and their modes.

**Response:**
```json
[
  {
    "id": "tennis",
    "displayName": "Tennis",
    "description": "Tennis video segmentation",
    "modes": [
      {
        "id": "rally",
        "displayName": "Rally Mode",
        "description": "Groups consecutive shots into rallies"
      },
      {
        "id": "individual",
        "displayName": "Shot Mode",
        "description": "Captures each shot separately"
      }
    ]
  },
  {
    "id": "cricket",
    "displayName": "Cricket",
    "description": "Cricket video segmentation",
    "modes": []
  }
]
```

---

**GET** `/sports/:sport`

Get details for a specific sport.

**Parameters:**
- `sport` (path) - Sport ID (e.g., "tennis", "cricket")

**Response:**
```json
{
  "id": "tennis",
  "displayName": "Tennis",
  "description": "Tennis video segmentation",
  "modes": [
    {
      "id": "rally",
      "displayName": "Rally Mode",
      "description": "Groups consecutive shots into rallies"
    },
    {
      "id": "individual",
      "displayName": "Shot Mode",
      "description": "Captures each shot separately"
    }
  ]
}
```

**Errors:**
- `400 Bad Request` - Invalid sport ID

---

### Run Management

**POST** `/runs`

Create a new segmentation run.

**Request Body:**
```json
{
  "videoPath": "/path/to/video.mp4",
  "sport": "tennis",
  "sportMode": "rally",
  "deviceTarget": "simulator"
}
```

**Parameters:**
- `videoPath` (required) - Absolute path to video file
- `sport` (required) - Sport ID (from `/sports`)
- `sportMode` (optional) - Mode ID (from `/sports/:sport/modes`)
- `deviceTarget` (required) - Target device ("simulator" or "device")

**Response:**
```json
{
  "runId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued"
}
```

---

**GET** `/runs/:runId`

Get status and results for a run.

**Parameters:**
- `runId` (path) - Run UUID

**Response (queued/running):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "running",
  "videoPath": "/path/to/video.mp4",
  "sport": "tennis",
  "sportMode": "rally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z"
}
```

**Response (completed):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "videoPath": "/path/to/video.mp4",
  "sport": "tennis",
  "sportMode": "rally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z",
  "completedAt": "2026-01-25T12:00:45Z",
  "segments": [
    {
      "startTime": 5.2,
      "endTime": 12.8,
      "type": "rally"
    },
    {
      "startTime": 18.5,
      "endTime": 25.1,
      "type": "rally"
    }
  ],
  "artifactPaths": {
    "segmentsJSON": "/path/to/segments.json",
    "highlightVideo": null
  }
}
```

**Response (failed):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "failed",
  "videoPath": "/path/to/video.mp4",
  "sport": "tennis",
  "sportMode": "rally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z",
  "completedAt": "2026-01-25T12:00:10Z",
  "error": "Video file not found: /path/to/video.mp4"
}
```

---

**GET** `/runs`

List all runs.

**Response:**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "completed",
    "sport": "tennis",
    "sportMode": "rally",
    "createdAt": "2026-01-25T12:00:00Z"
  }
]
```

---

## Migration from Legacy API

If you were using the old method registry API:

**OLD:**
```bash
GET /methods
GET /methods/spectral_flux/v2
```

**NEW:**
```bash
GET /sports
GET /sports/tennis
```

**Key changes:**
1. Discovery is now sport-based, not method-based
2. Use `sport` + `sportMode` instead of `methodFamily` + `methodVersion`
3. No more method config parameters - configs are predetermined per sport/mode

---

## Example Workflows

### Discover available options

```bash
# Get all sports and modes
curl http://localhost:8080/sports | jq

# Result: tennis has rally + individual modes
```

### Create and monitor a run

```bash
# Create run
curl -X POST http://localhost:8080/runs \
  -H "Content-Type: application/json" \
  -d '{
    "videoPath": "/path/to/tennis.mp4",
    "sport": "tennis",
    "sportMode": "rally",
    "deviceTarget": "simulator"
  }' | jq

# Get run ID from response
RUN_ID="550e8400-e29b-41d4-a716-446655440000"

# Poll for completion
while true; do
  STATUS=$(curl -s http://localhost:8080/runs/$RUN_ID | jq -r '.status')
  echo "Status: $STATUS"
  if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ]; then
    break
  fi
  sleep 2
done

# Get final results
curl http://localhost:8080/runs/$RUN_ID | jq
```
```

**Step 2: Commit**

```bash
git add app/SportCrunchRunner/API.md
git commit -m "docs: add HTTP API documentation for SportCrunchRunner

Documents new sport-based discovery pattern"
```

---

## Testing Checklist

After implementing all tasks, verify:

- [ ] SportCrunchRunner builds without errors
- [ ] `GET /sports` returns tennis + cricket with modes
- [ ] `GET /sports/tennis` returns rally + individual modes
- [ ] `POST /runs` with tennis/rally creates a run successfully
- [ ] Run execution completes and produces segments
- [ ] No references to MethodRegistry remain in codebase
- [ ] No references to MethodEndpoints remain in codebase
- [ ] Xcode project builds cleanly (no warnings about missing files)

---

## Summary of Changes

**Deleted files:**
- `SportCrunchRunner/Services/MethodRegistry.swift` (~250 lines)
- `SportCrunchRunner/Server/MethodEndpoints.swift` (~79 lines)

**Created files:**
- `SportCrunchRunner/Server/SportEndpoints.swift` (~70 lines)
- `SportCrunchRunner/API.md` (documentation)

**Modified files:**
- `SportCrunchRunner/SportCrunchRunnerApp.swift` - Removed MethodRegistry init/registration
- `SportCrunchRunner/Services/RunExecutor.swift` - Removed registry parameter (if present)
- `SportCrunchRunner/Models/Run.swift` - Deprecated legacy method fields
- `SportCrunch/Core/Models/Sport.swift` - Added availableModes property (if needed)

**Net change:** ~250 lines deleted, ~100 lines added = **150 lines removed**

---

## Benefits

1. **Unified architecture:** SportCrunch and SportCrunchRunner use same pattern
2. **No JSON overhead:** All configs are Swift structs at compile-time
3. **Simpler API:** Sport/mode discovery instead of method family/version
4. **Less code:** Removed 250 lines of JSON registry infrastructure
5. **Better type safety:** Swift enums instead of string-based method IDs
6. **Easier maintenance:** Single source of truth (Sport.swift)
