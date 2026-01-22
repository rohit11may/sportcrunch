---
quick_task: 002
type: execute
wave: 1
depends_on: []
files_modified:
  - app/SportCrunch/Core/Models/Sport.swift
autonomous: true

must_haves:
  truths:
    - "Tennis Individual/Shot mode uses tennis-individual.config.json parameters"
    - "Tennis Rally mode uses tennis-rally.config.json parameters"
    - "Cricket uses default-v2.config.json parameters"
    - "All existing tests pass with identical durations (no logic changes)"
  artifacts:
    - path: "app/SportCrunch/Core/Models/Sport.swift"
      provides: "Hardwired method config mapping per sport mode"
      exports: ["Sport.methodConfig(for:)"]
  key_links:
    - from: "Sport.methodConfig(for:)"
      to: "VideoProcessingService.processVideo"
      via: "replace Sport.preset(for:) calls"
      pattern: "sport\\.methodConfig\\(for:"
---

<objective>
Hardwire SportCrunch app to use specific method configurations based on sport modes. The method registry is for Runner experimentation only - the main app should use fixed configurations that match existing behavior.

Purpose: Decouple main app from registry complexity while preserving exact detection behavior
Output: Sport.swift with methodConfig(for:) method returning MethodConfig directly
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@app/SportCrunch/Core/Models/Sport.swift
@app/SportCrunch/Core/Services/VideoProcessingService.swift
@app/SportCrunch/Core/Services/SegmentationMethod.swift
@app/methods/spectral_flux/v2/configs/tennis-individual.config.json
@app/methods/spectral_flux/v2/configs/tennis-rally.config.json
@app/methods/spectral_flux/v2/configs/default-v2.config.json

Current state:
- VideoProcessingService calls sport.preset(for: sportMode) to get AnalysisPreset
- AnalysisPreset contains values like onsetThresholdLambda, paddingPreSec, clusterMaxGapSec, etc.
- These values are then mapped to MethodConfig struct
- SegmentationMethod.detectSegments() accepts MethodConfig

Goal:
- Replace Sport.preset(for:) → Sport.methodConfig(for:) in VideoProcessingService
- methodConfig(for:) returns MethodConfig directly (no intermediate AnalysisPreset step)
- Values must match existing AnalysisPreset values exactly (tests verify durations)
- Method registry JSON files in app/methods/ are reference only (not loaded by main app)
</context>

<tasks>

<task type="auto">
  <name>Add methodConfig(for:) to Sport.swift</name>
  <files>app/SportCrunch/Core/Models/Sport.swift</files>
  <action>
Add a new method `methodConfig(for mode: SportMode?) -> MethodConfig` to Sport enum.

**Implementation:**
1. Add method after existing `preset(for:)` method (around line 265)
2. Switch on self (Sport cases) and mode to return MethodConfig
3. Use existing AnalysisPreset values as source of truth for parameters

**Mapping (must match existing preset values exactly):**

Tennis Individual (.tennis + TennisMode.individual):
- audioThresholdMultiplier: 2.0 (from onsetThresholdLambda)
- peakMinDistance: 0.5 (from peakMinDistanceSec)
- clusterMaxGapSec: 1.0 (SHORT merging for individual shots)
- clusterMinHits: 1 (single hit valid)
- paddingPreSec: 0.5 (SHORT padding)
- paddingPostSec: 0.5 (SHORT padding)
- motionThreshold: 50.0 (from motionAreaThreshold, visual validation enabled)

Tennis Rally (.tennis + TennisMode.rally or nil):
- audioThresholdMultiplier: 2.0
- peakMinDistance: 0.5
- clusterMaxGapSec: 3.0 (AGGRESSIVE merging for rallies)
- clusterMinHits: 2 (minimum 2 hits for rally)
- paddingPreSec: 2.0 (LONGER padding)
- paddingPostSec: 2.0 (LONGER padding)
- motionThreshold: 50.0

Cricket (.cricket):
- audioThresholdMultiplier: 2.0
- peakMinDistance: 0.5
- clusterMaxGapSec: 6.0 (longer pauses between deliveries)
- clusterMinHits: 1
- paddingPreSec: 3.0 (more lead-up for bowler run-up)
- paddingPostSec: 3.0
- motionThreshold: 50.0

**Why these specific values:** They match the existing AnalysisPreset values in tennisPreset(for:) and cricketPreset() methods. Tests verify exact durations, so any deviation will cause failures.

**Code structure:**
```swift
func methodConfig(for mode: SportMode?) -> MethodConfig {
    switch self {
    case .tennis:
        if let tennisMode = mode as? TennisMode {
            switch tennisMode {
            case .individual:
                return MethodConfig(
                    audioThresholdMultiplier: 2.0,
                    peakMinDistance: 0.5,
                    clusterMaxGapSec: 1.0,
                    clusterMinHits: 1,
                    paddingPreSec: 0.5,
                    paddingPostSec: 0.5,
                    motionThreshold: 50.0
                )
            case .rally:
                return MethodConfig(
                    audioThresholdMultiplier: 2.0,
                    peakMinDistance: 0.5,
                    clusterMaxGapSec: 3.0,
                    clusterMinHits: 2,
                    paddingPreSec: 2.0,
                    paddingPostSec: 2.0,
                    motionThreshold: 50.0
                )
            }
        }
        // Default to rally if no mode specified
        return MethodConfig(
            audioThresholdMultiplier: 2.0,
            peakMinDistance: 0.5,
            clusterMaxGapSec: 3.0,
            clusterMinHits: 2,
            paddingPreSec: 2.0,
            paddingPostSec: 2.0,
            motionThreshold: 50.0
        )
    case .cricket:
        return MethodConfig(
            audioThresholdMultiplier: 2.0,
            peakMinDistance: 0.5,
            clusterMaxGapSec: 6.0,
            clusterMinHits: 1,
            paddingPreSec: 3.0,
            paddingPostSec: 3.0,
            motionThreshold: 50.0
        )
    }
}
```

Add comment above method:
```swift
/// Returns the hardwired method configuration for this sport and mode.
/// These configurations match the method registry JSON files but are
/// compiled into the app for the main processing pipeline.
/// The registry JSON files are used only by SportCrunchRunner for experimentation.
```
  </action>
  <verify>
Build succeeds:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build
```
  </verify>
  <done>Sport.swift contains methodConfig(for:) method returning MethodConfig with correct values for each sport/mode combination</done>
</task>

<task type="auto">
  <name>Update VideoProcessingService to use methodConfig</name>
  <files>app/SportCrunch/Core/Services/VideoProcessingService.swift</files>
  <action>
Replace the existing preset-based config mapping (lines 326-336) with direct methodConfig call.

**Find:**
```swift
// Map sport/sportMode to method config
let preset = sport.preset(for: sportMode)
let config = MethodConfig(
    audioThresholdMultiplier: Double(preset.onsetThresholdLambda),
    peakMinDistance: preset.peakMinDistanceSec,
    clusterMaxGapSec: preset.clusterMaxGapSec,
    clusterMinHits: preset.clusterMinHits,
    paddingPreSec: preset.paddingPreSec,
    paddingPostSec: preset.paddingPostSec,
    motionThreshold: preset.skipVisualValidation ? nil : Double(preset.motionAreaThreshold)
)
```

**Replace with:**
```swift
// Get hardwired method config for this sport/mode
let config = sport.methodConfig(for: sportMode)
```

**Why this works:** Sport.methodConfig(for:) now returns MethodConfig directly with the same values that were previously derived from AnalysisPreset. The intermediate preset step is eliminated.

**Keep existing logging:** The preset variable used for logging (line 261, 272) can remain as-is. It's only used for debug output and doesn't affect detection logic.
  </action>
  <verify>
Build succeeds:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build
```
  </verify>
  <done>VideoProcessingService.processVideo uses sport.methodConfig(for: sportMode) instead of deriving config from preset</done>
</task>

<task type="auto">
  <name>Run tests to verify identical behavior</name>
  <files>None (verification only)</files>
  <action>
Run the full test suite, particularly SegmentDetectionTests which verify exact segment durations.

**Critical:** Tests must pass with identical results. The refactoring changes HOW configs are provided (hardwired vs derived from preset) but NOT the actual config values or detection logic.

**Expected outcome:**
- All tests pass
- testShotDetection_Tennis uses TennisMode.individual config (clusterMaxGapSec=1.0, padding=0.5s)
- Segment durations match pre-refactor baseline
- No FPR/FNR regressions

**If tests fail:** The MethodConfig values in methodConfig(for:) don't match the original AnalysisPreset values. Compare the failing config values against Sport.swift's preset methods and adjust.
  </action>
  <verify>
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
```

All tests pass, specifically SegmentDetectionTests.testShotDetection_Tennis
  </verify>
  <done>All tests pass with identical segment durations, confirming methodConfig values match original preset values exactly</done>
</task>

</tasks>

<verification>
- [ ] Sport.methodConfig(for:) method exists and returns MethodConfig
- [ ] Method has correct switch cases for Tennis Individual, Tennis Rally, Cricket
- [ ] VideoProcessingService uses sport.methodConfig(for: sportMode)
- [ ] All tests pass (particularly SegmentDetectionTests)
- [ ] No changes to detection logic or segment durations
</verification>

<success_criteria>
1. Build succeeds with no errors
2. Sport.swift has methodConfig(for:) returning MethodConfig directly
3. VideoProcessingService simplified from preset → MethodConfig mapping to direct methodConfig call
4. All tests pass with identical segment durations
5. Method registry JSON files remain in app/methods/ but are not loaded by main app
</success_criteria>

<output>
After completion, create `.planning/quick/002-hardwire-method-configs-per-sport-mode/002-SUMMARY.md`
</output>
