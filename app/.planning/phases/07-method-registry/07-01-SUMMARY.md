---
phase: 07
plan: 01
subsystem: method-registry
tags: [json-registry, hierarchical-structure, method-versioning, swift-methods]
requires:
  - 04-01-method-protocol-foundation
provides:
  - spectral_flux family hierarchy (v1 audio-only, v2 visual-validation)
  - JSON method definitions with capabilities metadata
  - Config variants for tuning parameters
  - Distinct Swift method implementations
affects:
  - 07-02-build-validation (will validate this structure)
  - 07-03-dashboard-registry-ui (will read these files)
tech-stack:
  added: []
  patterns:
    - hierarchical-method-registry (family/version/config structure)
    - json-swift-parallelism (method.json + Swift implementation)
key-files:
  created:
    - app/methods/spectral_flux/_family.json
    - app/methods/spectral_flux/v1/method.json
    - app/methods/spectral_flux/v1/configs/default.config.json
    - app/methods/spectral_flux/v1/configs/aggressive.config.json
    - app/methods/spectral_flux/v1/configs/conservative.config.json
    - app/methods/spectral_flux/v1/SpectralFluxMethod.swift
    - app/methods/spectral_flux/v2/method.json
    - app/methods/spectral_flux/v2/configs/default.config.json
    - app/methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift
  modified: []
decisions:
  - title: v1 as pure audio-only method
    rationale: Distinct method variant without visual validation for faster processing
    impact: Enables algorithm comparison (audio-only vs audio+visual)
  - title: v2 preserves current production implementation
    rationale: SpectralFluxVisualValidationMethod is direct copy of existing SpectralFluxMethod
    impact: Zero behavioral change to production algorithm
  - title: Config variants for v1 only
    rationale: Three tuning presets (default/aggressive/conservative) for v1, single config for v2
    impact: Demonstrates config variety without over-engineering
metrics:
  tasks_completed: 3
  commits: 3
  duration: 7 min
  files_created: 9
  completed: 2026-01-22
---

# Phase 07 Plan 01: Method Registry JSON Structure Summary

**One-liner:** Hierarchical JSON registry for spectral_flux family with v1 (audio-only) and v2 (visual-validation) versions, including config variants and Swift implementations

## What Was Built

Created the foundational method registry structure at `app/methods/` with:

1. **Family hierarchy**: `spectral_flux/_family.json` defining family metadata
2. **Version v1 (SpectralFlux)**: Pure audio-only method with 3 config variants
3. **Version v2 (SpectralFluxVisualValidation)**: Audio + visual validation (current production)

### Directory Structure

```
app/methods/
└── spectral_flux/
    ├── _family.json
    ├── v1/
    │   ├── method.json
    │   ├── SpectralFluxMethod.swift
    │   └── configs/
    │       ├── default.config.json
    │       ├── aggressive.config.json
    │       └── conservative.config.json
    └── v2/
        ├── method.json
        ├── SpectralFluxVisualValidationMethod.swift
        └── configs/
            └── default.config.json
```

### Method Capabilities

**v1 (SpectralFlux)**:
- `audioOnly: true`, `visualValidation: false`
- Pure audio spectral flux onset detection
- Faster processing (no video frame analysis)
- 3 config variants: default (balanced), aggressive (lower threshold), conservative (higher threshold)
- Confidence: 0.85 for audio-detected segments

**v2 (SpectralFluxVisualValidation)**:
- `audioOnly: false`, `visualValidation: true`
- Audio + motion-based visual validation
- Current production implementation (preserved exactly)
- Single default config
- Confidence: 0.7-1.0 based on motion score normalization

## Task Breakdown

### Task 1: Create spectral_flux family structure with _family.json
**Commit:** `c6362b6` - `feat(07-01): create spectral_flux family structure with _family.json`

Created:
- `app/methods/spectral_flux/` directory hierarchy
- `_family.json` with minimal metadata (name, description)
- Version folders: v1/, v2/ with configs/ subdirectories

### Task 2: Create v1 (SpectralFlux audio-only) method.json, configs, and Swift implementation
**Commit:** `fca0423` - `feat(07-01): create v1 SpectralFlux audio-only method`

Created:
- `v1/method.json` defining pure audio-only method
- Three config variants with different tuning parameters:
  - **default**: audioThresholdMultiplier 1.5, peakMinDistance 0.5 (balanced)
  - **aggressive**: audioThresholdMultiplier 1.2, peakMinDistance 0.3 (higher recall)
  - **conservative**: audioThresholdMultiplier 2.0, peakMinDistance 0.8 (higher precision)
- `v1/SpectralFluxMethod.swift`: Pure audio-only implementation
  - Uses AudioAnalyzer only (no VisualValidator)
  - Direct conversion of audio peaks to ActionSegments
  - Simplified pipeline compared to v2

### Task 3: Create v2 (SpectralFluxVisualValidation) method.json, config, and Swift implementation
**Commit:** `5825085` - `feat(07-01): create v2 SpectralFluxVisualValidation method`

Created:
- `v2/method.json` defining audio + visual validation method
- Single default config with motionThreshold parameter
- `v2/SpectralFluxVisualValidationMethod.swift`: Production implementation
  - Uses AudioAnalyzer + VisualValidator
  - Fallback to audio-only if visual validation fails
  - Motion score normalization for confidence (0.7-1.0 range)

## Decisions Made

### v1 vs v2 as Distinct Methods
**Decision:** Treat v1 (audio-only) and v2 (visual-validation) as separate method versions, not just config variants.

**Rationale:** These represent fundamentally different algorithmic approaches:
- v1: Pure audio signal processing (faster, simpler)
- v2: Multi-modal analysis (audio + video motion)

**Impact:** Enables clean A/B comparison between audio-only and audio+visual approaches. Registry naturally models the "family" concept where versions can differ significantly in capabilities.

### Config Variant Strategy
**Decision:** Provide 3 config variants for v1, single config for v2.

**Rationale:**
- v1 is simpler and benefits from parameter tuning exploration (aggressive vs conservative thresholds)
- v2 is production-stable with well-tuned defaults

**Impact:** Demonstrates registry flexibility without over-engineering. Easy to add more v2 configs later if needed.

### Preserve Production Implementation Exactly
**Decision:** v2 is a direct copy of existing `SpectralFluxMethod.swift` with only class name change.

**Rationale:** Zero risk to production algorithm. The registry reorganization is structural only.

**Impact:** Existing behavior guaranteed unchanged. All future references will use `SpectralFluxVisualValidationMethod` name.

## Test Results

Ran full test suite on iPhone 17 simulator:

### Unit Tests
- **SegmentDetectionTests**: 1 test, 2 failures (38 seconds)
  - Failures: tennis-shot-2 (97.1% false negative rate), tennis-shot-3 (93.7% false negative rate)
  - **Status**: Known pre-existing issue (documented in STATE.md as failing on commit 8eaf9fe)
  - **Impact**: Not a regression from this plan

### UI Tests
- **All UI tests passed**: 11 tests across HighlightCreationFlowTests, ExportFlowTests, SportCrunchUITests
  - testCreateHighlightButtonOpensFlow: PASS (9.2s)
  - testCreationFlowCanBeClosed: PASS (12.5s)
  - testCompletedProjectOpensSheet: PASS (15.4s)
  - testHighlightCreationIsTriggered: PASS (48.2s)
  - testExample: PASS (6.5s)
  - testExportSheetShowsSaveAndShareOptions: PASS (18.4s)
  - testLaunch (4 variants): ALL PASS (3.8-5.1s each)
  - testSportSelectionShowsTennisAndCricket: PASS (22.4s)
  - testLaunchPerformance: PASS (27.6s)
  - testTennisModeButtonsExist: PASS (32.1s)

### Build Status
- **Build**: SUCCESS
- **Overall Test Result**: FAILED (due to pre-existing unit test issue)
- **This Plan's Impact**: No new test failures introduced

The registry structure compiles cleanly and all UI functionality remains intact. The unit test failures are pre-existing issues with test data quality, not regressions from this work.

## Verification

All verification checks passed:

```bash
# Structure verification
find app/methods -type f \( -name "*.json" -o -name "*.swift" \) | sort
# Returns 9 files (7 JSON + 2 Swift) in correct hierarchy

# JSON validation
for f in $(find app/methods -name "*.json"); do
  python3 -m json.tool < "$f" > /dev/null
done
# All 7 JSON files valid

# Capability verification
grep "audioOnly.*true" app/methods/spectral_flux/v1/method.json  # ✓
grep "visualValidation.*true" app/methods/spectral_flux/v2/method.json  # ✓

# Swift class name matching
v1: swiftClass "SpectralFluxMethod" matches class declaration  # ✓
v2: swiftClass "SpectralFluxVisualValidationMethod" matches class declaration  # ✓
```

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

**Blockers:** None

**Ready for 07-02 (Build Validation):**
- JSON structure established and valid
- Swift implementations exist alongside JSON definitions
- Method families, versions, and configs ready for validation script

**Ready for 07-03 (Dashboard Registry UI):**
- JSON files ready for dashboard to read
- Family/version/config hierarchy navigable via filesystem
- Capability metadata available for UI filtering

## Performance

- **Duration**: 7 minutes
- **Tasks**: 3/3 completed
- **Commits**: 3 atomic commits (1 per task)
- **Files created**: 9 (7 JSON + 2 Swift)

## Artifacts

**Commits:**
- `c6362b6`: feat(07-01): create spectral_flux family structure with _family.json
- `fca0423`: feat(07-01): create v1 SpectralFlux audio-only method
- `5825085`: feat(07-01): create v2 SpectralFluxVisualValidation method

**Key Files:**
- Family: `app/methods/spectral_flux/_family.json`
- v1 Method: `app/methods/spectral_flux/v1/method.json` + SpectralFluxMethod.swift
- v1 Configs: default/aggressive/conservative.config.json
- v2 Method: `app/methods/spectral_flux/v2/method.json` + SpectralFluxVisualValidationMethod.swift
- v2 Config: default.config.json
