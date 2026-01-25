# Dashboard API Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate dashboard and SportCrunchRunner from sport-based discovery to method-based discovery from filesystem

**Architecture:** Replace sport/sportMode endpoints with method discovery by scanning `app/methods/` directory. Backend and frontend will use method/methodFamily/methodVersion pattern. Dashboard calls `/api/methods` to discover available methods from filesystem structure, then POST `/runs` with `method` + `config` parameters.

**Tech Stack:** React (frontend), Express.js (backend), Swift (SportCrunchRunner), FileManager for method discovery

---

## Overview

The SportCrunchRunner API needs to be refactored from sport-based discovery to method-based discovery by scanning the `app/methods/` directory structure. The dashboard needs to be updated to use the new method-based API.

**Key Changes:**

### Backend (SportCrunchRunner):
1. Remove `/sports` endpoints (SportEndpoints.swift)
2. Add `/methods` endpoint that scans `app/methods/` directory
3. Update POST `/runs` to accept `method` + `config` instead of `sport` + `sportMode`
4. Update Run model to store method/config instead of sport/sportMode
5. Update RunExecutor to instantiate methods based on method name and config

### Dashboard:
6. Remove MethodSelector component files
7. Create new MethodSelector that fetches from `/api/methods`
8. Update backend API proxy to use `/api/methods` instead of `/api/sports`
9. Update frontend API client
10. Update Home page to use method selection
11. Update RunTrigger component

**Key API Changes:**
- OLD: `GET /sports`, `POST /runs { sport, sportMode, ... }`
- NEW: `GET /methods`, `POST /runs { method, config, ... }`

**Method Discovery Pattern:**
```
app/methods/
  spectral_flux/                    # Method family
    SpectralFluxMethod.swift
    SpectralFluxMethodConfig.swift
    configs/
      SpectralFluxTennisRally.swift     # Config name: "TennisRally"
      SpectralFluxTennisIndividual.swift # Config name: "TennisIndividual"
```

GET /methods returns:
```json
[
  {
    "family": "spectral_flux",
    "version": "v1",
    "displayName": "Spectral Flux",
    "description": "Audio-based detection using spectral flux",
    "configs": [
      {
        "name": "TennisRally",
        "displayName": "Tennis Rally Mode",
        "description": "Groups consecutive shots"
      },
      {
        "name": "TennisIndividual",
        "displayName": "Tennis Shot Mode",
        "description": "Individual shots"
      }
    ]
  }
]
```

POST /runs:
```json
{
  "videoPath": "/path/to/video.mp4",
  "method": "spectral_flux",
  "config": "TennisRally",
  "deviceTarget": "simulator"
}
```

---

## Task 1: Add Method Discovery Endpoint to SportCrunchRunner

**Files:**
- Create: `app/SportCrunchRunner/Server/MethodEndpoints.swift`
- Modify: `app/SportCrunchRunner/SportCrunchRunnerApp.swift:38-39`

**Step 1: Create MethodEndpoints.swift**

Create `app/SportCrunchRunner/Server/MethodEndpoints.swift`:

```swift
//
//  MethodEndpoints.swift
//  SportCrunchRunner
//
//  Method discovery HTTP endpoints that scan filesystem for available methods.
//

import Foundation
import Swifter

/// Registers method discovery HTTP endpoints
enum MethodEndpoints {

    /// Register all method endpoints on the server
    static func register(on server: HTTPServer) {

        // GET /methods - List all available methods by scanning filesystem
        server.registerRoute(path: "/methods", method: "GET") { _ in
            return handleListMethods()
        }

        print("✓ [MethodEndpoints] Registered /methods endpoints")
    }

    // MARK: - GET /methods

    private static func handleListMethods() -> HttpResponse {
        let methodsPath = getMethodsDirectoryPath()

        guard FileManager.default.fileExists(atPath: methodsPath) else {
            return errorResponse(message: "Methods directory not found", statusCode: 500)
        }

        do {
            let methodFamilies = try discoverMethods(at: methodsPath)

            guard let jsonData = try? JSONSerialization.data(withJSONObject: methodFamilies, options: [.prettyPrinted]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return errorResponse(message: "Failed to encode methods", statusCode: 500)
            }

            return .raw(200, "OK", ["Content-Type": "application/json"]) {
                try? $0.write(Data(jsonString.utf8))
            }
        } catch {
            print("❌ [MethodEndpoints] Error discovering methods: \(error)")
            return errorResponse(message: "Failed to discover methods: \(error.localizedDescription)", statusCode: 500)
        }
    }

    // MARK: - Method Discovery

    /// Returns the absolute path to the methods directory
    private static func getMethodsDirectoryPath() -> String {
        // Get path relative to app bundle
        // In Xcode, methods/ is at the project root, sibling to SportCrunch.xcodeproj
        let bundlePath = Bundle.main.bundlePath
        let projectRoot = (bundlePath as NSString).deletingLastPathComponent.deletingLastPathComponent
        return "\(projectRoot)/methods"
    }

    /// Scans the methods directory and returns structured method information
    private static func discoverMethods(at methodsPath: String) throws -> [[String: Any]] {
        let fileManager = FileManager.default
        let methodDirs = try fileManager.contentsOfDirectory(atPath: methodsPath)

        var methods: [[String: Any]] = []

        for methodDir in methodDirs {
            let methodPath = "\(methodsPath)/\(methodDir)"

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: methodPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Skip hidden directories
            guard !methodDir.hasPrefix(".") else { continue }

            // Discover configs for this method
            let configs = try discoverConfigs(methodFamily: methodDir, methodPath: methodPath)

            // Build method info
            let methodInfo: [String: Any] = [
                "family": methodDir,
                "version": "v1",  // Hardcoded for now
                "displayName": formatDisplayName(methodDir),
                "description": generateDescription(methodDir),
                "configs": configs
            ]

            methods.append(methodInfo)
        }

        return methods
    }

    /// Discovers config files for a method family
    private static func discoverConfigs(methodFamily: String, methodPath: String) throws -> [[String: Any]] {
        let fileManager = FileManager.default
        let configsPath = "\(methodPath)/configs"

        guard fileManager.fileExists(atPath: configsPath) else {
            print("⚠️ [MethodEndpoints] No configs directory for \(methodFamily)")
            return []
        }

        let configFiles = try fileManager.contentsOfDirectory(atPath: configsPath)
        var configs: [[String: Any]] = []

        for configFile in configFiles {
            // Skip non-Swift files
            guard configFile.hasSuffix(".swift") else { continue }

            // Extract config name (e.g., "SpectralFluxTennisRally.swift" -> "TennisRally")
            let configName = extractConfigName(from: configFile, methodFamily: methodFamily)

            let configInfo: [String: Any] = [
                "name": configName,
                "displayName": formatDisplayName(configName),
                "description": generateConfigDescription(configName)
            ]

            configs.append(configInfo)
        }

        return configs
    }

    // MARK: - Helpers

    /// Extracts config name from filename
    /// Example: "SpectralFluxTennisRally.swift" -> "TennisRally"
    private static func extractConfigName(from filename: String, methodFamily: String) -> String {
        // Remove .swift extension
        let nameWithoutExtension = filename.replacingOccurrences(of: ".swift", with: "")

        // Remove method family prefix (e.g., "SpectralFlux")
        let prefix = methodFamily
            .split(separator: "_")
            .map { $0.capitalized }
            .joined()

        if nameWithoutExtension.hasPrefix(prefix) {
            let startIndex = nameWithoutExtension.index(nameWithoutExtension.startIndex, offsetBy: prefix.count)
            return String(nameWithoutExtension[startIndex...])
        }

        return nameWithoutExtension
    }

    /// Formats identifier to display name
    /// Example: "spectral_flux" -> "Spectral Flux"
    private static func formatDisplayName(_ identifier: String) -> String {
        return identifier
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Generates a description for a method family
    private static func generateDescription(_ methodFamily: String) -> String {
        switch methodFamily.lowercased() {
        case "spectral_flux":
            return "Audio-based detection using spectral flux analysis"
        default:
            return "Segmentation method"
        }
    }

    /// Generates a description for a config
    private static func generateConfigDescription(_ configName: String) -> String {
        let lower = configName.lowercased()

        if lower.contains("rally") {
            return "Groups consecutive shots into rallies"
        } else if lower.contains("individual") || lower.contains("shot") {
            return "Captures each shot separately"
        } else if lower.contains("tennis") {
            return "Tennis detection mode"
        } else if lower.contains("cricket") {
            return "Cricket detection mode"
        }

        return "Detection configuration"
    }

    private static func errorResponse(message: String, statusCode: Int) -> HttpResponse {
        let json: [String: Any] = ["error": message]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"Unknown error\"}"

        return .raw(statusCode, "Error", ["Content-Type": "application/json"]) {
            try? $0.write(Data(jsonString.utf8))
        }
    }
}
```

**Step 2: Register MethodEndpoints in SportCrunchRunnerApp**

Modify `app/SportCrunchRunner/SportCrunchRunnerApp.swift` around line 38-39:

```swift
// Replace:
SportEndpoints.register(on: server)

// With:
MethodEndpoints.register(on: server)
```

**Step 3: Test method discovery endpoint**

Run SportCrunchRunner app:

```bash
xcodebuild -project app/SportCrunch.xcodeproj -scheme SportCrunchRunner -destination 'platform=iOS Simulator,name=iPhone 17'
```

Test endpoint:

```bash
curl http://localhost:8080/methods | jq
```

Expected output:
```json
[
  {
    "family": "spectral_flux",
    "version": "v1",
    "displayName": "Spectral Flux",
    "description": "Audio-based detection using spectral flux analysis",
    "configs": [
      {
        "name": "TennisRally",
        "displayName": "Tennis Rally",
        "description": "Groups consecutive shots into rallies"
      },
      {
        "name": "TennisIndividual",
        "displayName": "Tennis Individual",
        "description": "Captures each shot separately"
      }
    ]
  }
]
```

**Step 4: Commit method discovery endpoint**

```bash
git add app/SportCrunchRunner/Server/MethodEndpoints.swift app/SportCrunchRunner/SportCrunchRunnerApp.swift
git commit -m "feat: add method discovery endpoint that scans filesystem

- Scan app/methods/ directory for method families
- Discover configs in methods/*/configs/ subdirectories
- Return structured JSON with method family, version, and configs
- Replace SportEndpoints with MethodEndpoints registration

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Update Run Model to Use Method/Config

**Files:**
- Modify: `app/SportCrunchRunner/Models/Run.swift:55-56`

**Step 1: Replace sport/sportMode with method/config**

Modify `app/SportCrunchRunner/Models/Run.swift`:

```swift
// Replace lines 55-56:
    let sport: String
    let sportMode: String?

// With:
    let method: String
    let config: String
```

**Step 2: Update initializer**

Replace the initializer parameters:

```swift
// Replace:
    init(
        id: UUID = UUID(),
        status: RunStatus = .queued,
        videoPath: String,
        sport: String,
        sportMode: String? = nil,
        config: [String: String] = [:],
        deviceTarget: DeviceTarget = .simulator
    ) {
        self.id = id
        self.status = status
        self.videoPath = videoPath
        self.sport = sport
        self.sportMode = sportMode
        self.config = config
        self.deviceTarget = deviceTarget
        self.createdAt = Date()
    }

// With:
    init(
        id: UUID = UUID(),
        status: RunStatus = .queued,
        videoPath: String,
        method: String,
        config: String,
        deviceTarget: DeviceTarget = .simulator
    ) {
        self.id = id
        self.status = status
        self.videoPath = videoPath
        self.method = method
        self.config = config
        self.deviceTarget = deviceTarget
        self.createdAt = Date()
    }
```

**Step 3: Remove unused config field**

Remove the `config: [String: String]` field from the struct (it's no longer needed since config is now a string identifier).

**Step 4: Commit Run model changes**

```bash
git add app/SportCrunchRunner/Models/Run.swift
git commit -m "refactor: update Run model to use method/config instead of sport/sportMode

- Replace sport/sportMode fields with method/config
- Update initializer to match new fields
- Remove unused config dictionary field

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Update RunEndpoints to Accept Method/Config

**Files:**
- Modify: `app/SportCrunchRunner/Server/RunEndpoints.swift:82-108`
- Modify: `app/SportCrunchRunner/Server/RunEndpoints.swift:196-215`

**Step 1: Update POST /runs handler to parse method/config**

Replace the request parsing section (lines 82-108):

```swift
      // Extract required fields
      guard let videoPath = json["videoPath"] as? String else {
        print("❌ [RunEndpoints] Missing videoPath")
        return errorResponse(message: "Missing required field: videoPath", statusCode: 400)
      }

      guard let method = json["method"] as? String else {
        print("❌ [RunEndpoints] Missing method")
        return errorResponse(message: "Missing required field: method", statusCode: 400)
      }

      guard let config = json["config"] as? String else {
        print("❌ [RunEndpoints] Missing config")
        return errorResponse(message: "Missing required field: config", statusCode: 400)
      }

      print("📝 [RunEndpoints] videoPath=\(videoPath), method=\(method), config=\(config)")

      // Resolve relative paths (e.g., Documents/test-videos/...) to absolute paths
      let resolvedVideoPath = resolveVideoPath(videoPath)
      print("📝 [RunEndpoints] resolvedVideoPath=\(resolvedVideoPath)")

      // Validate video path exists
      guard FileManager.default.fileExists(atPath: resolvedVideoPath) else {
        print("❌ [RunEndpoints] Video file not found: \(resolvedVideoPath)")
        return errorResponse(message: "Video file not found: \(resolvedVideoPath)", statusCode: 404)
      }

      // Parse device target (defaults to simulator)
      let deviceTarget = parseDeviceTarget(from: json)

      // Create run (use resolved path so executor can find the file)
      let run = Run(
        videoPath: resolvedVideoPath,
        method: method,
        config: config,
        deviceTarget: deviceTarget
      )
```

**Step 2: Update encodeRun to serialize method/config**

Replace the encodeRun function (lines 196-215):

```swift
  private static func encodeRun(_ run: Run) -> [String: Any] {
    print("🔧 [RunEndpoints] Encoding run: \(run.id.uuidString)")

    var json: [String: Any] = [
      "id": run.id.uuidString,
      "status": run.status.rawValue,
      "videoPath": run.videoPath,
      "method": run.method,
      "config": run.config,
      "createdAt": ISO8601DateFormatter().string(from: run.createdAt)
    ]

    print("  ✓ Added base fields (id, status, videoPath, method, config, createdAt)")

    if let startedAt = run.startedAt {
      json["startedAt"] = ISO8601DateFormatter().string(from: startedAt)
      print("  ✓ Added startedAt: \(ISO8601DateFormatter().string(from: startedAt))")
    }

    if let completedAt = run.completedAt {
      json["completedAt"] = ISO8601DateFormatter().string(from: completedAt)
      print("  ✓ Added completedAt: \(ISO8601DateFormatter().string(from: completedAt))")
    }

    if let segments = run.segments {
      print("  🔄 Encoding \(segments.count) segments...")
      let segmentsArray = segments.map { segment in
        [
          "startTime": segment.startTime,
          "endTime": segment.endTime,
          "type": segment.type
        ] as [String: Any]
      }
      json["segments"] = segmentsArray
      print("  ✓ Added segments: \(segments.count) items")
    }

    if let artifactPaths = run.artifactPaths {
      print("  🔄 Encoding artifactPaths...")
      var artifacts: [String: Any] = [
        "segmentsJSON": artifactPaths.segmentsJSON
      ]
      print("    - segmentsJSON: \(artifactPaths.segmentsJSON)")

      if let highlightVideo = artifactPaths.highlightVideo {
        artifacts["highlightVideo"] = highlightVideo
        print("    - highlightVideo: \(highlightVideo)")
      } else {
        print("    - highlightVideo: nil (not added)")
      }

      json["artifactPaths"] = artifacts
      print("  ✓ Added artifactPaths")
    }

    if let error = run.error {
      json["error"] = error
      print("  ✓ Added error: \(error)")
    }

    print("🔧 [RunEndpoints] Finished encoding run, total keys: \(json.keys.count)")
    return json
  }
```

**Step 3: Commit RunEndpoints changes**

```bash
git add app/SportCrunchRunner/Server/RunEndpoints.swift
git commit -m "refactor: update RunEndpoints to accept method/config

- Parse method and config from POST body instead of sport/sportMode
- Update Run initialization to use method/config
- Update encodeRun to serialize method/config fields

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Update RunExecutor to Instantiate Methods from Method/Config

**Files:**
- Modify: `app/SportCrunchRunner/Services/RunExecutor.swift:72-148`

**Step 1: Replace sport/mode parsing with method/config logic**

Replace the executeRun function body (lines 84-148):

```swift
    do {
      // Load video URL
      let videoURL = URL(fileURLWithPath: run.videoPath)
      guard FileManager.default.fileExists(atPath: videoURL.path) else {
        throw RunExecutorError.videoNotFound(run.videoPath)
      }

      print("🔄 [RunExecutor] Method: \(run.method), Config: \(run.config)")
      print("🔄 [RunExecutor] Executing on \(videoURL.lastPathComponent)")

      // Instantiate the segmentation method based on method + config
      let method = try instantiateMethod(methodFamily: run.method, configName: run.config)
      print("🔄 [RunExecutor] Using method: \(method.name)")

      // Detect segments using configured method
      let segments = try await method.detectSegments(videoURL: videoURL)

      print("🔄 [RunExecutor] ✓ Detected \(segments.count) segments")

      // Convert to ExportedSegment
      let exportedSegments = segments.map { segment in
        ExportedSegment(
          startTime: segment.startTime,
          endTime: segment.endTime,
          type: "segment"  // Generic type
        )
      }

      // Export artifacts
      let artifactPaths = try exporter.export(
        run: run,
        segments: exportedSegments,
        highlightURL: nil  // Highlight video export not implemented yet
      )

      // Update run with success
      run.status = .completed
      run.completedAt = Date()
      run.segments = exportedSegments
      run.artifactPaths = artifactPaths
      await store.update(run: run)

      print("🔄 [RunExecutor] ✓ Run \(runId.uuidString) completed successfully")
      print("🔄 [RunExecutor] Segments JSON: \(artifactPaths.segmentsJSON)")

    } catch {
      // Update run with failure
      run.status = .failed
      run.completedAt = Date()
      run.error = error.localizedDescription
      await store.update(run: run)

      print("🔄 [RunExecutor] ❌ Run \(runId.uuidString) failed: \(error.localizedDescription)")
    }
```

**Step 2: Add method instantiation logic**

Add a new helper method after executeRun:

```swift
  // MARK: - Method Instantiation

  /// Instantiates a segmentation method based on method family and config name
  private func instantiateMethod(methodFamily: String, configName: String) throws -> any SegmentationMethod {
    print("🔄 [RunExecutor] Instantiating method: \(methodFamily)/\(configName)")

    switch methodFamily.lowercased() {
    case "spectral_flux":
      return try instantiateSpectralFluxMethod(configName: configName)
    default:
      throw RunExecutorError.methodNotFound("\(methodFamily)/\(configName)")
    }
  }

  /// Instantiates SpectralFluxMethod with the specified config
  private func instantiateSpectralFluxMethod(configName: String) throws -> SpectralFluxMethod {
    let config: SpectralFluxMethodConfig

    switch configName {
    case "TennisRally":
      config = SpectralFluxTennisRallyConfig.instance
    case "TennisIndividual":
      config = SpectralFluxTennisIndividualConfig.instance
    default:
      throw RunExecutorError.configNotFound(configName)
    }

    return SpectralFluxMethod(config: config)
  }
```

**Step 3: Update error cases**

Update the RunExecutorError enum at the bottom:

```swift
enum RunExecutorError: LocalizedError {
  case videoNotFound(String)
  case methodNotFound(String)
  case configNotFound(String)

  var errorDescription: String? {
    switch self {
    case .videoNotFound(let path):
      return "Video file not found: \(path)"
    case .methodNotFound(let method):
      return "Method not found: \(method)"
    case .configNotFound(let config):
      return "Config not found: \(config)"
    }
  }
}
```

**Step 4: Remove old sport/mode helper methods**

Delete the `parseSportMode` and `determineSportType` functions (lines 152-173).

**Step 5: Commit RunExecutor changes**

```bash
git add app/SportCrunchRunner/Services/RunExecutor.swift
git commit -m "refactor: update RunExecutor to instantiate methods from method/config

- Add instantiateMethod helper to create method from family + config
- Add instantiateSpectralFluxMethod to map config names to config instances
- Remove sport/mode parsing logic
- Update error cases for method/config not found

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Delete SportEndpoints

**Files:**
- Delete: `app/SportCrunchRunner/Server/SportEndpoints.swift`

**Step 1: Delete SportEndpoints file**

```bash
git rm app/SportCrunchRunner/Server/SportEndpoints.swift
git commit -m "refactor: remove deprecated SportEndpoints

- Delete SportEndpoints.swift (replaced by MethodEndpoints)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Update Dashboard Backend API

**Files:**
- Modify: `dashboard/backend/server.js:172-233`
- Modify: `dashboard/backend/server.js:239-334`

**Step 1: Replace /api/sports endpoints with /api/methods**

Replace lines 172-233 in `dashboard/backend/server.js`:

```javascript
// ==========================================
// Method Discovery Endpoints
// ==========================================

// GET /api/methods - List available methods (proxy to iOS Runner)
app.get('/api/methods', async (req, res) => {
  try {
    const response = await fetch(`${RUNNER_URL}/methods`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ iOS Runner error (${response.status}):`, errorText);
      return res.status(response.status).json({
        error: `iOS Runner error: ${errorText}`
      });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);
      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running.'
      });
    }

    console.error('❌ Error fetching methods:', error);
    res.status(500).json({ error: 'Failed to fetch methods' });
  }
});
```

**Step 2: Update POST /api/runs handler**

Replace lines 239-334:

```javascript
app.post('/api/runs', async (req, res) => {
  try {
    const { videoPath, method, config, deviceId, deviceIp } = req.body;

    // Validate required fields
    if (!videoPath) {
      return res.status(400).json({ error: 'Missing required field: videoPath' });
    }
    if (!method) {
      return res.status(400).json({ error: 'Missing required field: method' });
    }
    if (!config) {
      return res.status(400).json({ error: 'Missing required field: config' });
    }

    // Determine the runner URL based on device selection
    let runnerUrl = RUNNER_URL; // Default to localhost (simulator)

    if (deviceId && deviceId !== 'simulator') {
      // Physical device - use the provided IP
      if (!deviceIp) {
        return res.status(400).json({
          error: 'Device IP is required for physical devices. Please enter your device IP address.'
        });
      }
      runnerUrl = `http://${deviceIp}:8080`;
      console.log(`📱 Targeting physical device at: ${runnerUrl}`);
    } else {
      console.log(`📱 Targeting simulator at: ${runnerUrl}`);
    }

    // Forward to iOS Runner with new API format
    const response = await fetch(`${runnerUrl}/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        videoPath,
        method,
        config,
        deviceTarget: deviceId === 'simulator' ? 'simulator' : 'device'
      }),
      signal: AbortSignal.timeout(10000) // 10 second timeout
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ iOS Runner error (${response.status}):`, errorText);
      return res.status(response.status).json({
        error: `iOS Runner error: ${errorText}`
      });
    }

    const data = await response.json();

    // Save mapping of Run ID -> Host Video Path
    try {
      const MAP_FILE = path.resolve(__dirname, 'run-map.json');
      let runMap = {};
      if (fs.existsSync(MAP_FILE)) {
        runMap = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
      }

      runMap[data.id] = videoPath;
      fs.writeFileSync(MAP_FILE, JSON.stringify(runMap, null, 2));
      console.log(`📝 Saved video path mapping for run ${data.id}`);
    } catch (err) {
      console.error('⚠️ Failed to save run mapping:', err);
    }

    res.status(202).json(data);

    console.log(`✅ Created run: ${data.id} (${method}/${config})`);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);
      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running on the target device.'
      });
    }

    console.error('❌ Error creating run:', error);
    res.status(500).json({ error: 'Failed to create run' });
  }
});
```

**Step 3: Remove METHODS_PATH constant (if exists)**

If line 25 has `const METHODS_PATH = ...`, remove it.

**Step 4: Commit backend changes**

```bash
git add dashboard/backend/server.js
git commit -m "refactor: migrate backend API from sport discovery to method discovery

- Replace /api/sports with /api/methods proxy endpoint
- Update POST /runs to use method/config instead of sport/sportMode
- Remove deprecated sport endpoints

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Update Dashboard Frontend API Service

**Files:**
- Modify: `dashboard/frontend/src/services/api.js:52-94`

**Step 1: Replace sport functions with method functions**

Replace the functions around lines 52-94:

```javascript
export async function fetchMethods() {
  try {
    const response = await fetch(`${API_BASE_URL}/api/methods`)
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to fetch methods: ${error.message}`, 0)
  }
}

export async function createRun(videoPath, method, config, deviceId = 'simulator', deviceIp = null) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        videoPath,
        method,
        config,
        deviceId,
        deviceIp
      })
    })
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to create run: ${error.message}`, 0)
  }
}
```

**Step 2: Commit API service changes**

```bash
git add dashboard/frontend/src/services/api.js
git commit -m "refactor: update API service for method-based discovery

- Add fetchMethods() function
- Update createRun() to use method/config instead of sport/sportMode
- Remove sport-related API functions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Create New MethodSelector Component

**Files:**
- Create: `dashboard/frontend/src/components/MethodSelector.jsx`
- Create: `dashboard/frontend/src/components/MethodSelector.css`

**Step 1: Create MethodSelector component**

Create `dashboard/frontend/src/components/MethodSelector.jsx`:

```jsx
import { useState, useEffect, useCallback } from 'react'
import './MethodSelector.css'

const STORAGE_KEY = 'sportcrunch_method_selection'

function MethodSelector({ onChange }) {
  const [methods, setMethods] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Selection state
  const [selectedMethod, setSelectedMethod] = useState(null)
  const [selectedConfig, setSelectedConfig] = useState(null)

  // Load methods from API
  useEffect(() => {
    async function fetchMethods() {
      try {
        const response = await fetch('/api/methods')
        if (!response.ok) throw new Error('Failed to fetch methods')

        const data = await response.json()
        setMethods(data || [])

        // Restore last selection from localStorage
        const saved = localStorage.getItem(STORAGE_KEY)
        if (saved) {
          const { methodFamily, configName } = JSON.parse(saved)
          const method = data.find(m => m.family === methodFamily)
          if (method) {
            setSelectedMethod(method)
            // Find config
            const config = method.configs.find(c => c.name === configName)
            setSelectedConfig(config || method.configs[0] || null)
          }
        }

        // Default to first method + first config if nothing saved
        if (!saved && data.length > 0) {
          const first = data[0]
          setSelectedMethod(first)
          setSelectedConfig(first.configs[0] || null)
        }

        setLoading(false)
      } catch (err) {
        console.error('Failed to load methods:', err)
        setError(err.message)
        setLoading(false)
      }
    }

    fetchMethods()
  }, [])

  // Notify parent when selection changes
  useEffect(() => {
    if (selectedMethod && selectedConfig) {
      // Save to localStorage
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        methodFamily: selectedMethod.family,
        configName: selectedConfig.name
      }))

      // Notify parent
      onChange({
        method: selectedMethod.family,
        config: selectedConfig.name,
        methodDisplayName: selectedMethod.displayName,
        configDisplayName: selectedConfig.displayName
      })
    }
  }, [selectedMethod, selectedConfig, onChange])

  const handleMethodChange = useCallback((e) => {
    const methodFamily = e.target.value
    const method = methods.find(m => m.family === methodFamily)
    if (method) {
      setSelectedMethod(method)
      // Reset to first config
      setSelectedConfig(method.configs[0] || null)
    }
  }, [methods])

  const handleConfigChange = useCallback((e) => {
    const configName = e.target.value
    const config = selectedMethod?.configs.find(c => c.name === configName)
    setSelectedConfig(config || null)
  }, [selectedMethod])

  if (loading) {
    return (
      <div className="method-selector">
        <h3>Method & Config</h3>
        <div className="method-loading">Loading methods...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="method-selector">
        <h3>Method & Config</h3>
        <div className="method-error">Error: {error}</div>
      </div>
    )
  }

  if (methods.length === 0) {
    return (
      <div className="method-selector">
        <h3>Method & Config</h3>
        <div className="method-empty">
          No methods available. Please ensure SportCrunchRunner is running.
        </div>
      </div>
    )
  }

  return (
    <div className="method-selector">
      <h3>Method & Config</h3>

      {/* Method dropdown */}
      <div className="method-field">
        <label htmlFor="method-select">Method</label>
        <select
          id="method-select"
          value={selectedMethod?.family || ''}
          onChange={handleMethodChange}
        >
          {methods.map(method => (
            <option key={method.family} value={method.family}>
              {method.displayName} ({method.version})
            </option>
          ))}
        </select>
      </div>

      {/* Method description */}
      {selectedMethod && (
        <div className="method-description">
          {selectedMethod.description}
        </div>
      )}

      {/* Config dropdown (only if method has configs) */}
      {selectedMethod && selectedMethod.configs && selectedMethod.configs.length > 0 && (
        <div className="method-field">
          <label htmlFor="config-select">Config</label>
          <select
            id="config-select"
            value={selectedConfig?.name || ''}
            onChange={handleConfigChange}
          >
            {selectedMethod.configs.map(config => (
              <option key={config.name} value={config.name}>
                {config.displayName}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Config description */}
      {selectedConfig && (
        <div className="config-description">
          {selectedConfig.description}
        </div>
      )}

      {/* No config indicator */}
      {selectedMethod && (!selectedMethod.configs || selectedMethod.configs.length === 0) && (
        <div className="method-no-configs">
          This method has no configs
        </div>
      )}
    </div>
  )
}

export default MethodSelector
```

**Step 2: Create MethodSelector styles**

Create `dashboard/frontend/src/components/MethodSelector.css`:

```css
.method-selector {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  margin-bottom: 20px;
}

.method-selector h3 {
  margin: 0 0 15px 0;
  color: #333;
  font-size: 18px;
}

.method-field {
  margin-bottom: 15px;
}

.method-field label {
  display: block;
  margin-bottom: 5px;
  color: #666;
  font-weight: 500;
  font-size: 14px;
}

.method-field select {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
  background: white;
  cursor: pointer;
}

.method-field select:hover {
  border-color: #999;
}

.method-field select:focus {
  outline: none;
  border-color: #4CAF50;
  box-shadow: 0 0 0 2px rgba(76, 175, 80, 0.1);
}

.method-description {
  padding: 10px;
  background: #f5f5f5;
  border-radius: 4px;
  font-size: 13px;
  color: #666;
  margin-bottom: 15px;
  line-height: 1.5;
}

.config-description {
  padding: 10px;
  background: #e8f5e9;
  border-radius: 4px;
  font-size: 13px;
  color: #2e7d32;
  margin-top: 10px;
  line-height: 1.5;
}

.method-no-configs {
  padding: 10px;
  background: #f5f5f5;
  border-radius: 4px;
  font-size: 13px;
  color: #999;
  font-style: italic;
}

.method-loading {
  padding: 15px;
  text-align: center;
  color: #666;
  font-style: italic;
}

.method-error {
  padding: 15px;
  background: #ffebee;
  color: #c62828;
  border-radius: 4px;
  font-size: 14px;
}

.method-empty {
  padding: 15px;
  background: #fff3e0;
  color: #e65100;
  border-radius: 4px;
  font-size: 14px;
}
```

**Step 3: Commit MethodSelector component**

```bash
git add dashboard/frontend/src/components/MethodSelector.jsx dashboard/frontend/src/components/MethodSelector.css
git commit -m "feat: add MethodSelector component for method-based discovery

- Fetch methods from /api/methods endpoint
- Support method family and config selection
- Add localStorage persistence for last selection
- Display method and config descriptions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Update Home Page to Use MethodSelector

**Files:**
- Modify: `dashboard/frontend/src/pages/Home.jsx:3-7`
- Modify: `dashboard/frontend/src/pages/Home.jsx:13`
- Modify: `dashboard/frontend/src/pages/Home.jsx:25-27`
- Modify: `dashboard/frontend/src/pages/Home.jsx:60-108`
- Modify: `dashboard/frontend/src/pages/Home.jsx:130-132`

**Step 1: Update imports**

Replace the import around line 4:

```jsx
import MethodSelector from '../components/MethodSelector'
```

Remove the SportSelector import.

**Step 2: Update state variables**

Replace line 13:

```jsx
const [methodSelection, setMethodSelection] = useState(null)
```

Remove the `sportSelection` state.

**Step 3: Update callbacks**

Replace lines 25-27:

```jsx
const handleMethodChange = useCallback((selection) => {
  setMethodSelection(selection)
}, [])
```

Remove the `handleSportChange` callback.

**Step 4: Update handleTriggerRun function**

Replace the handleTriggerRun function:

```jsx
async function handleTriggerRun() {
  if (!selectedVideo || !methodSelection) {
    setError('Please select a video and method')
    return
  }

  try {
    setIsProcessing(true)
    setError(null)
    setStatusMessage('')

    let videoPathToUse = selectedVideo

    // If physical device, copy video first
    if (selectedDevice !== 'simulator') {
      setStatusMessage('Copying video to device...')

      const videoName = selectedVideo.split('/').pop()
      const copyResult = await copyVideoToDevice(
        selectedDevice,
        selectedVideo,
        videoName
      )

      if (copyResult.alreadyExists) {
        setStatusMessage('Video already on device, skipping copy')
      } else if (copyResult.copied) {
        setStatusMessage('Video copied successfully')
      }

      // Use the remote path on the device
      videoPathToUse = `Documents/test-videos/${videoName}`
    }

    setStatusMessage('Creating run...')

    // Create the run with method/config
    const result = await createRun(
      videoPathToUse,
      methodSelection.method,
      methodSelection.config,
      selectedDevice,
      deviceIp
    )

    setStatusMessage('Processing video...')

    // Poll for completion
    await pollRunStatus(result.id)

    // Navigate to results page
    navigate(`/results/${result.id}`)
  } catch (err) {
    setError(err.message || 'Failed to process video')
    setIsProcessing(false)
    setStatusMessage('')
  }
}
```

**Step 5: Update component rendering**

Replace the selector component (around line 130):

```jsx
<MethodSelector onChange={handleMethodChange} />
```

Remove the SportSelector component.

**Step 6: Update RunTrigger props**

Update the RunTrigger component:

```jsx
<RunTrigger
  videoPath={selectedVideo}
  method={methodSelection}
  isProcessing={isProcessing}
  error={error}
  statusMessage={statusMessage}
  onTrigger={handleTriggerRun}
/>
```

**Step 7: Commit Home page changes**

```bash
git add dashboard/frontend/src/pages/Home.jsx
git commit -m "refactor: update Home page to use MethodSelector

- Replace SportSelector with MethodSelector
- Update state and callbacks for method selection
- Change handleTriggerRun to use method/config
- Update RunTrigger props

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Update RunTrigger Component

**Files:**
- Modify: `dashboard/frontend/src/components/RunTrigger.jsx:3`
- Modify: `dashboard/frontend/src/components/RunTrigger.jsx:24-28`

**Step 1: Update prop and canProcess check**

Replace line 3:

```jsx
function RunTrigger({ videoPath, method, isProcessing, error, statusMessage, onTrigger }) {
  const canProcess = videoPath && method && !isProcessing
```

**Step 2: Update method display text**

Replace lines 24-28:

```jsx
{method && !isProcessing && (
  <div className="method-info">
    Using: {method.methodDisplayName} / {method.configDisplayName}
  </div>
)}
```

**Step 3: Commit RunTrigger changes**

```bash
git add dashboard/frontend/src/components/RunTrigger.jsx
git commit -m "refactor: update RunTrigger to display method info

- Change prop from sport to method
- Update display text to show method and config

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 11: Delete Deprecated SportSelector Component

**Files:**
- Delete: `dashboard/frontend/src/components/SportSelector.jsx`
- Delete: `dashboard/frontend/src/components/SportSelector.css`

**Step 1: Delete SportSelector files**

```bash
git rm dashboard/frontend/src/components/SportSelector.jsx dashboard/frontend/src/components/SportSelector.css
git commit -m "refactor: remove deprecated SportSelector component

- Delete SportSelector.jsx
- Delete SportSelector.css
- Component replaced by MethodSelector

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 12: Update API Documentation

**Files:**
- Modify: `app/SportCrunchRunner/API.md`

**Step 1: Update API.md to reflect method-based discovery**

Replace the content of `app/SportCrunchRunner/API.md`:

```markdown
# SportCrunchRunner HTTP API

## Overview

SportCrunchRunner provides an HTTP API for triggering video segmentation runs. The API uses a method-based discovery pattern that scans the filesystem for available methods.

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

### Method Discovery

**GET** `/methods`

List all available methods by scanning the `app/methods/` directory.

**Response:**
```json
[
  {
    "family": "spectral_flux",
    "version": "v1",
    "displayName": "Spectral Flux",
    "description": "Audio-based detection using spectral flux analysis",
    "configs": [
      {
        "name": "TennisRally",
        "displayName": "Tennis Rally",
        "description": "Groups consecutive shots into rallies"
      },
      {
        "name": "TennisIndividual",
        "displayName": "Tennis Individual",
        "description": "Captures each shot separately"
      }
    ]
  }
]
```

**Method Discovery Logic:**
- Scans `app/methods/` for method family directories (e.g., `spectral_flux/`)
- Scans `app/methods/<family>/configs/` for config files (e.g., `SpectralFluxTennisRally.swift`)
- Extracts config name by removing method family prefix from filename
- Returns structured JSON with method families and their available configs

---

### Run Management

**POST** `/runs`

Create a new segmentation run.

**Request Body:**
```json
{
  "videoPath": "/path/to/video.mp4",
  "method": "spectral_flux",
  "config": "TennisRally",
  "deviceTarget": "simulator"
}
```

**Parameters:**
- `videoPath` (required) - Absolute path to video file
- `method` (required) - Method family name (from `/methods`)
- `config` (required) - Config name (from `/methods` configs array)
- `deviceTarget` (required) - Target device ("simulator" or "device")

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
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
  "method": "spectral_flux",
  "config": "TennisRally",
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
  "method": "spectral_flux",
  "config": "TennisRally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z",
  "completedAt": "2026-01-25T12:00:45Z",
  "segments": [
    {
      "startTime": 5.2,
      "endTime": 12.8,
      "type": "segment"
    },
    {
      "startTime": 18.5,
      "endTime": 25.1,
      "type": "segment"
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
  "method": "spectral_flux",
  "config": "TennisRally",
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
{
  "runs": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "completed",
      "method": "spectral_flux",
      "config": "TennisRally",
      "createdAt": "2026-01-25T12:00:00Z"
    }
  ]
}
```

---

## Example Workflows

### Discover available methods

```bash
# Get all methods and configs
curl http://localhost:8080/methods | jq

# Result: spectral_flux has TennisRally + TennisIndividual configs
```

### Create and monitor a run

```bash
# Create run
curl -X POST http://localhost:8080/runs \
  -H "Content-Type: application/json" \
  -d '{
    "videoPath": "/path/to/tennis.mp4",
    "method": "spectral_flux",
    "config": "TennisRally",
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

---

## Adding New Methods

To add a new method that will be discovered by the API:

1. Create method family directory: `app/methods/<method_family>/`
2. Implement method class: `<MethodFamily>Method.swift`
3. Implement config struct: `<MethodFamily>MethodConfig.swift`
4. Create config instances in `configs/` subdirectory:
   - Example: `configs/<MethodFamily><ConfigName>.swift`
   - Must define static `instance` property of config type
5. Update `RunExecutor.instantiateMethod()` to handle new method family
6. Restart SportCrunchRunner - new method will appear in `/methods` endpoint
```

**Step 2: Commit API documentation changes**

```bash
git add app/SportCrunchRunner/API.md
git commit -m "docs: update API documentation for method-based discovery

- Document /methods endpoint and filesystem scanning
- Update /runs request/response examples to use method/config
- Add guide for adding new methods
- Remove sport-based discovery references

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 13: Manual Testing

**Testing checklist:**

1. **Start SportCrunchRunner in simulator**
   - Build and run SportCrunchRunner app in iPhone 17 simulator
   - Verify HTTP server starts on port 8080

2. **Test method discovery**
   ```bash
   curl http://localhost:8080/methods | jq
   ```
   - Verify spectral_flux method appears
   - Verify TennisRally and TennisIndividual configs appear

3. **Start dashboard backend**
   ```bash
   cd dashboard/backend
   npm start
   ```
   - Verify server starts on port 3000
   - Check that it can connect to SportCrunchRunner

4. **Start dashboard frontend**
   ```bash
   cd dashboard/frontend
   npm run dev
   ```
   - Verify Vite dev server starts

5. **Test method discovery in UI**
   - Open dashboard in browser
   - Verify MethodSelector loads with Spectral Flux method
   - Verify configs dropdown shows TennisRally and TennisIndividual
   - Verify descriptions display correctly

6. **Test method selection persistence**
   - Select Spectral Flux + TennisIndividual
   - Refresh page
   - Verify Spectral Flux + TennisIndividual is still selected

7. **Test run creation**
   - Select a test video
   - Select Spectral Flux + TennisRally
   - Click "Process Video"
   - Verify run is created successfully
   - Verify status polling works
   - Verify navigation to results page

8. **Test error handling**
   - Stop SportCrunchRunner app
   - Refresh dashboard
   - Verify friendly error message: "iOS Runner unavailable"
   - Restart SportCrunchRunner
   - Verify dashboard recovers

**Manual testing notes:**
- Document any issues found
- Verify all commits are clean and follow conventions
- Ensure no console errors in browser or backend

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-01-25-dashboard-api-migration.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
