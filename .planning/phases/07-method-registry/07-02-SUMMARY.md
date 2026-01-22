# Plan 07-02 Summary: Build Validation Script

**Status:** ✅ Complete
**Duration:** ~15 minutes
**Completed:** 2026-01-22

## What Was Built

Created build-time validation infrastructure to enforce JSON-Swift parallelism and auto-generate method registry index.

### Files Created/Modified

1. **`app/scripts/validate-methods.sh`** (196 lines)
   - Validates every `method.json` has matching Swift file (via `swiftClass` field)
   - Validates all JSON files are syntactically correct
   - Generates `_index.json` with all families, versions, and configs
   - Exits with code 1 on validation failure
   - Color-coded output for validation results

2. **`app/methods/_index.json`** (26 lines, auto-generated)
   - Single source of truth for available methods
   - Hierarchical structure: families → versions → configs
   - spectral_flux family with v1 (3 configs) and v2 (1 config)
   - Generated timestamp for cache invalidation

3. **Swift Method Files** (from Plan 07-01, confirmed parallel to JSON)
   - `app/methods/spectral_flux/v1/SpectralFluxMethod.swift`
   - `app/methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift`

4. **Refactoring Work** (completed after 07-02)
   - Added `MethodConfig` struct to `SegmentationMethod.swift`
   - Updated protocol to accept `config: MethodConfig` instead of `Sport`/`SportMode`
   - Updated `AudioAnalyzer` and `VisualValidator` to accept config
   - Modified `VideoProcessingService` to map Sport/SportMode → MethodConfig

### Xcode Integration (Human Action)

User completed Xcode configuration checkpoint:
- ✅ Added `app/methods/` folder as folder reference (blue folder)
- ✅ Added Swift method files to SportCrunchRunner target
- ✅ Verified build succeeds with new structure

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Validation script uses absolute paths | Works from any directory (project root or Xcode build phase) | ✓ Good |
| Script generates _index.json | Single source of truth, no manual maintenance | ✓ Good |
| Exit code 1 on failure | Xcode build fails if JSON-Swift mismatch (future) | ✓ Good |
| Python for JSON parsing | Cross-platform, built-in json module | ✓ Good |
| Color-coded output | Easy visual scanning of validation results | ✓ Good |
| MethodConfig struct decouples methods from Sport/SportMode | Methods are config-driven, app layer maps Sport → Config | ✓ Good |

## Validation Rules Enforced

1. **JSON Syntax:** All `.json` files must be valid JSON
2. **Swift Parallelism:** Every `method.json` must have matching `{swiftClass}.swift` in same directory
3. **Config Discovery:** Automatically finds all `.config.json` files in `configs/` subdirectories
4. **Family Structure:** Requires `_family.json` at family level

## Registry Structure (v1)

```
methods/
  spectral_flux/               # Family directory
    _family.json              # Family metadata
    v1/                       # Version directory
      method.json             # Method definition (references SpectralFluxMethod)
      SpectralFluxMethod.swift  # Swift implementation
      configs/
        default-v1.config.json
        aggressive.config.json
        conservative.config.json
    v2/                       # Version directory
      method.json             # Method definition (references SpectralFluxVisualValidationMethod)
      SpectralFluxVisualValidationMethod.swift  # Swift implementation
      configs/
        default-v2.config.json
  _index.json                 # Auto-generated registry index
```

## Method Config Structure

```swift
struct MethodConfig: Sendable {
    let audioThresholdMultiplier: Double
    let peakMinDistance: Double
    let clusterMaxGapSec: Double
    let paddingPreSec: Double
    let paddingPostSec: Double
    let motionThreshold: Double?  // Optional, only for visual validation methods
}
```

JSON config files match this structure:
```json
{
  "name": "default",
  "description": "Balanced audio-only detection",
  "parameters": {
    "audioThresholdMultiplier": 1.5,
    "peakMinDistance": 0.5,
    "clusterMaxGapSec": 2.0,
    "paddingPreSec": 1.5,
    "paddingPostSec": 1.0
  }
}
```

## Method Refactoring (Protocol Layer)

**Before:**
```swift
protocol SegmentationMethod {
    func detectSegments(
        videoURL: URL,
        sport: Sport,
        sportMode: SportMode?
    ) async throws -> [ActionSegment]
}
```

**After:**
```swift
protocol SegmentationMethod {
    func detectSegments(
        videoURL: URL,
        config: MethodConfig
    ) async throws -> [ActionSegment]
}
```

**App Layer Mapping (VideoProcessingService):**
```swift
let preset = sport.preset(for: sportMode)
let config = MethodConfig(
    audioThresholdMultiplier: Double(preset.onsetThresholdLambda),
    peakMinDistance: preset.peakMinDistanceSec,
    clusterMaxGapSec: preset.clusterMaxGapSec,
    paddingPreSec: preset.paddingPreSec,
    paddingPostSec: preset.paddingPostSec,
    motionThreshold: preset.skipVisualValidation ? nil : Double(preset.motionAreaThreshold)
)
segments = try await method.detectSegments(videoURL: sourceURL, config: config)
```

## Testing Performed

1. ✅ Validation script runs without errors
2. ✅ `_index.json` generated with correct structure
3. ✅ Validation correctly fails when Swift file is missing (tested by temporarily renaming)
4. ✅ Xcode build succeeds with new method structure
5. ✅ Tests pass with refactored protocol signature

## Blockers/Issues

None encountered. Validation script works as expected.

## Next Steps

- **Plan 07-03:** Implement Runner method registry loading from bundle and GET /methods endpoint
- **Plan 07-04:** Implement dashboard method selection UI

## Performance Notes

- Validation script runs in ~200ms for current registry size (1 family, 2 versions)
- Python JSON parsing is fast enough for build-time validation
- No performance impact on app runtime (validation only runs during build)

## Notes

- Config files are currently in `configs/` subdirectories but not yet loaded by methods
- Methods still hardcode their parameters (config loading will come in Phase 07-03)
- Xcode build phase integration is manual (user action required, not automated)
- Script designed to be idempotent (safe to run multiple times)

---

**Verification Commands:**
```bash
# Run validation
./scripts/validate-methods.sh

# Check generated index
cat app/methods/_index.json | python3 -m json.tool

# Test validation failure (temporarily rename Swift file)
mv app/methods/spectral_flux/v1/SpectralFluxMethod.swift /tmp/
./scripts/validate-methods.sh  # Should fail
mv /tmp/SpectralFluxMethod.swift app/methods/spectral_flux/v1/
```
