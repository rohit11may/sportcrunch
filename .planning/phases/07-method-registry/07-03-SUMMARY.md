# Plan 07-03 Summary: Runner Registry Loading + GET /methods

**Status:** ⚠️  Complete (needs Xcode configuration fix)
**Duration:** ~20 minutes
**Completed:** 2026-01-22

## What Was Built

Implemented Runner method registry loading from bundle and GET /methods HTTP endpoint for method discovery.

### Files Created/Modified

1. **`app/SportCrunchRunner/Services/MethodRegistry.swift`** (264 lines, NEW)
   - Actor for thread-safe registry access
   - Loads `_index.json` from bundle at startup
   - Provides `allMethods()` for API queries
   - Provides `method(family:version:)` for lookups
   - Provides `createMethod(family:version:)` for instantiation
   - Provides `loadConfig(family:version:configName:)` for config loading
   - Graceful handling if `_index.json` missing from bundle (logs warning, returns empty)

2. **`app/SportCrunchRunner/Server/MethodEndpoints.swift`** (77 lines, NEW)
   - `GET /methods` - returns JSON array of all available methods
   - `GET /methods/:family/:version` - returns specific method details
   - Uses DispatchSemaphore for async/sync bridging (matches existing endpoint patterns)

3. **`app/SportCrunchRunner/Models/Run.swift`** (MODIFIED)
   - Added `methodFamily: String?` field
   - Added `methodVersion: String?` field
   - Kept legacy `method: String` field for backwards compatibility

4. **`app/SportCrunchRunner/Services/RunExecutor.swift`** (MODIFIED)
   - Accepts `MethodRegistry` in init
   - Uses `registry.createMethod(family:version:)` instead of hardcoded `SpectralFluxMethod()`
   - Defaults to `spectral_flux/v1` if run doesn't specify method
   - Added `RunExecutorError.methodNotFound` case

5. **`app/SportCrunchRunner/SportCrunchRunnerApp.swift`** (MODIFIED)
   - Creates `MethodRegistry` instance
   - Loads registry from bundle at startup in Task
   - Registers `MethodEndpoints` on server
   - Passes registry to `RunExecutor`

## Key Components

### MethodRegistry Architecture

```swift
actor MethodRegistry {
    private var index: MethodIndex?
    private var methods: [String: MethodInfo] = [:]  // key: family/version

    func loadFromBundle()
    func allMethods() -> [MethodInfo]
    func method(family: String, version: String) -> MethodInfo?
    func createMethod(family: String, version: String) throws -> SegmentationMethod
    func loadConfig(family: String, version: String, configName: String) throws -> [String: Any]
}
```

### Method Instantiation Pattern

```swift
// In MethodRegistry.createMethod()
switch info.swiftClass {
case "SpectralFluxMethod":
    return SpectralFluxMethod()  // v1: Audio-only
case "SpectralFluxVisualValidationMethod":
    return SpectralFluxVisualValidationMethod()  // v2: Audio + visual
default:
    throw MethodRegistryError.unknownSwiftClass(info.swiftClass)
}
```

Note: This is a simple switch for Phase 7. Future: reflection or registration pattern.

### Data Models

```swift
struct MethodInfo: Codable, Sendable {
    let family: String           // "spectral_flux"
    let version: String          // "v1", "v2"
    let name: String             // Display name
    let description: String      // Method description
    let swiftClass: String       // Swift class name for instantiation
    let defaultConfig: String    // Default config filename
    let configs: [String]        // Available config files

    var id: String { "\(family)/\(version)" }
}
```

### AnyCodable Helper

Included `AnyCodable` struct for type-erased Codable support (loosely-typed config parameters per CONTEXT.md).

## API Endpoints

### GET /methods

Returns array of all available methods:

```json
[
  {
    "family": "spectral_flux",
    "version": "v1",
    "name": "SpectralFlux",
    "description": "Pure audio spectral flux onset detection...",
    "swiftClass": "SpectralFluxMethod",
    "defaultConfig": "default.config.json",
    "configs": ["default.config.json", "aggressive.config.json", "conservative.config.json"]
  },
  {
    "family": "spectral_flux",
    "version": "v2",
    "name": "SpectralFluxVisualValidation",
    "description": "Audio spectral flux onset detection enhanced with...",
    "swiftClass": "SpectralFluxVisualValidationMethod",
    "defaultConfig": "default.config.json",
    "configs": ["default.config.json"]
  }
]
```

### GET /methods/:family/:version

Returns specific method details with same structure as above.

## Runner Integration Flow

1. **App Startup:**
   - `SportCrunchRunnerApp.init()` creates `MethodRegistry` instance
   - `.onAppear` calls `methodRegistry.loadFromBundle()` in Task
   - Registers `MethodEndpoints` on HTTP server

2. **Run Execution:**
   - `RunExecutor.executeRun()` reads `run.methodFamily` and `run.methodVersion`
   - Defaults to `spectral_flux/v1` if not specified
   - Calls `registry.createMethod(family:version:)` to instantiate method
   - Executes method with config (existing flow unchanged)

3. **Dashboard Queries:**
   - Dashboard can call `GET /methods` to discover available methods
   - Dashboard can query specific method details for UI
   - This enables Phase 07-04 (method selection UI)

## Testing Performed

✅ Swift code compiles successfully (verified by build log)
❌ Full build blocked by sandbox permission issue (see below)

## Blockers/Issues

### Xcode Sandbox Permission Issue

The "Validate Method Registry" run script phase cannot read `scripts/validate-methods.sh` due to Xcode sandbox restrictions.

**Error:**
```
Sandbox: bash deny(1) file-read-data /Users/rohit/Documents/sportcrunch/app/scripts/validate-methods.sh
```

**Fix Required (Manual Xcode Action):**

Open Xcode and update the "Validate Method Registry" run script build phase:

1. Select SportCrunchRunner target → Build Phases
2. Find "Validate Method Registry" run script phase
3. Click "Input Files" section
4. Add: `$(SRCROOT)/scripts/validate-methods.sh`
5. This grants the script read permission within sandbox

**Alternative (Temporary):**
- Uncheck the "Validate Method Registry" run script phase to skip validation during development
- Re-enable before production builds

## Verification Commands

Once sandbox issue is resolved:

```bash
# Build Runner
cd app
xcodebuild build -project SportCrunch.xcodeproj -scheme SportCrunchRunner \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run Runner in simulator, then test endpoints:
curl http://localhost:8080/methods | python3 -m json.tool
curl http://localhost:8080/methods/spectral_flux/v1 | python3 -m json.tool
curl http://localhost:8080/methods/spectral_flux/v2 | python3 -m json.tool
```

## Next Steps

- **Fix sandbox issue** (user action required - update Xcode build phase)
- **Plan 07-04:** Implement dashboard method selection UI

## Architecture Notes

- Registry is an `actor` for thread-safe access from multiple endpoints
- Method instantiation uses switch on `swiftClass` field (simple for Phase 7)
- Future improvement: reflection-based instantiation or registration pattern
- Config loading infrastructure in place but not yet used by RunExecutor (will use in Phase 07-04)
- Backwards compatibility: Run model keeps legacy `method` field, adds new `methodFamily`/`methodVersion` fields

---

**Key Achievement:** Runner can now dynamically discover and instantiate methods from the registry at runtime, enabling the dashboard to present method choices to users in Phase 07-04.
