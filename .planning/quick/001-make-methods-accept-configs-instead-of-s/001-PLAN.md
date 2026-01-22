---
phase: quick-001
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - SportCrunch/Core/Services/SegmentationMethod.swift
  - methods/spectral_flux/v1/SpectralFluxMethod.swift
  - methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift
  - SportCrunch/Core/Services/AudioAnalyzer.swift
  - SportCrunch/Core/Services/VisualValidator.swift
  - SportCrunch/Core/Services/VideoProcessingService.swift
  - SportCrunchRunner/Services/RunExecutor.swift
autonomous: true

must_haves:
  truths:
    - "SegmentationMethod.detectSegments() accepts config object instead of SportMode"
    - "v1 SpectralFluxMethod uses config parameters from JSON config"
    - "v2 SpectralFluxVisualValidationMethod uses config parameters from JSON config"
    - "All existing tests still pass with no changes to test code"
    - "SportMode is only used in app UI layer for user selection, not in methods"
  artifacts:
    - path: "SportCrunch/Core/Services/SegmentationMethod.swift"
      provides: "Updated protocol signature with config parameter"
      contains: "detectSegments(videoURL:config:)"
    - path: "methods/spectral_flux/v1/SpectralFluxMethod.swift"
      provides: "Config-based v1 implementation"
      contains: "config parameter usage"
    - path: "methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift"
      provides: "Config-based v2 implementation"
      contains: "config parameter usage"
  key_links:
    - from: "SegmentationMethod protocol"
      to: "config struct"
      via: "detectSegments parameter signature"
      pattern: "func detectSegments.*config:"
    - from: "SpectralFluxMethod"
      to: "config parameters"
      via: "direct usage of config values"
      pattern: "config\\.(audioThresholdMultiplier|peakMinDistance)"
    - from: "VideoProcessingService"
      to: "config from SportMode mapping"
      via: "mapping logic Sport+SportMode -> config"
---

<objective>
Refactor the method system so that methods accept specific config objects (matching the JSON config structure) instead of SportMode, enabling methods to be truly decoupled from app-specific sport selection logic.

Purpose: Prepare for Phase 7 Method Registry where methods are defined by configs, not by SportMode. The app layer will map SportMode selections to specific method+config combinations, but methods themselves only know about configs.

Output:
- SegmentationMethod protocol updated to accept config instead of SportMode
- Both v1 and v2 methods refactored to use config parameters
- AudioAnalyzer and VisualValidator updated to accept config parameters
- VideoProcessingService and RunExecutor updated to create and pass configs
- All tests passing with no test code changes needed
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@methods/spectral_flux/v1/configs/default-v1.config.json
@methods/spectral_flux/v2/configs/default-v2.config.json
@SportCrunch/Core/Services/SegmentationMethod.swift
@methods/spectral_flux/v1/SpectralFluxMethod.swift
@methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift
@SportCrunch/Core/Models/Sport.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create MethodConfig struct and update protocol signature</name>
  <files>
    SportCrunch/Core/Services/SegmentationMethod.swift
  </files>
  <action>
1. Add a `MethodConfig` struct at the top of SegmentationMethod.swift (before the protocol):

```swift
/// Configuration parameters for method execution.
/// Maps to JSON config files in methods/{family}/{version}/configs/
struct MethodConfig: Sendable {
    // Audio parameters
    let audioThresholdMultiplier: Double
    let peakMinDistance: Double

    // Clustering parameters
    let clusterMaxGapSec: Double

    // Padding parameters
    let paddingPreSec: Double
    let paddingPostSec: Double

    // Visual validation parameters (optional, only for methods with visual validation)
    let motionThreshold: Double?

    /// Create config from JSON config parameters
    init(
        audioThresholdMultiplier: Double = 1.5,
        peakMinDistance: Double = 0.5,
        clusterMaxGapSec: Double = 2.0,
        paddingPreSec: Double = 1.5,
        paddingPostSec: Double = 1.0,
        motionThreshold: Double? = nil
    ) {
        self.audioThresholdMultiplier = audioThresholdMultiplier
        self.peakMinDistance = peakMinDistance
        self.clusterMaxGapSec = clusterMaxGapSec
        self.paddingPreSec = paddingPreSec
        self.paddingPostSec = paddingPostSec
        self.motionThreshold = motionThreshold
    }
}
```

2. Update the `SegmentationMethod` protocol's `detectSegments` signature:

OLD:
```swift
func detectSegments(
    videoURL: URL,
    sport: Sport,
    sportMode: SportMode?
) async throws -> [ActionSegment]
```

NEW:
```swift
func detectSegments(
    videoURL: URL,
    config: MethodConfig
) async throws -> [ActionSegment]
```

Remove `sport` and `sportMode` parameters entirely. Methods no longer need to know about sports - they only need config values.

3. Update the protocol documentation to reflect that configs are the source of truth for method behavior.
  </action>
  <verify>
    - `grep "struct MethodConfig" SportCrunch/Core/Services/SegmentationMethod.swift` finds the struct
    - `grep "func detectSegments.*config: MethodConfig" SportCrunch/Core/Services/SegmentationMethod.swift` finds the new signature
    - `grep -c "sportMode" SportCrunch/Core/Services/SegmentationMethod.swift` returns 0 (no more SportMode references)
  </verify>
  <done>
    - MethodConfig struct exists with all necessary parameters matching JSON configs
    - SegmentationMethod.detectSegments() accepts config instead of sport/sportMode
    - Protocol documentation updated to emphasize config-driven behavior
  </done>
</task>

<task type="auto">
  <name>Task 2: Update AudioAnalyzer and VisualValidator to accept config parameters</name>
  <files>
    SportCrunch/Core/Services/AudioAnalyzer.swift
    SportCrunch/Core/Services/VisualValidator.swift
  </files>
  <action>
**AudioAnalyzer.swift:**

1. Update the `analyze()` method signature:

OLD:
```swift
func analyze(
    videoURL: URL,
    sport: Sport,
    sportMode: SportMode?
) async throws -> AudioAnalysisResult
```

NEW:
```swift
func analyze(
    videoURL: URL,
    config: MethodConfig
) async throws -> AudioAnalysisResult
```

2. Replace all usages of `sport.preset(for: sportMode)` with direct config parameter access:
   - Replace `preset.onsetThresholdLambda` with `Float(config.audioThresholdMultiplier)`
   - Replace `preset.peakMinDistanceSec` with `config.peakMinDistance`
   - Replace `preset.clusterMaxGapSec` with `config.clusterMaxGapSec`
   - Replace `preset.paddingPreSec` with `config.paddingPreSec`
   - Replace `preset.paddingPostSec` with `config.paddingPostSec`
   - Keep `preset.sampleRate`, `preset.bandpassLow`, `preset.bandpassHigh` as hardcoded constants (16000, 200, 3000) - these are audio processing constants, not tunable parameters

3. Remove any references to Sport or SportMode enums.

**VisualValidator.swift:**

1. Update the `validate()` method signature to accept config:

OLD:
```swift
func validate(
    candidateIntervals: [TimeInterval],
    videoURL: URL,
    sport: Sport,
    sportMode: SportMode?
) async throws -> [ActionSegment]
```

NEW:
```swift
func validate(
    candidateIntervals: [TimeInterval],
    videoURL: URL,
    config: MethodConfig
) async throws -> [ActionSegment]
```

2. Replace `sport.preset(for: sportMode)` usage with `config.motionThreshold` (or use default if nil).
3. Keep other video processing parameters (videoSampleStride, videoThumbSize, motionPixelThreshold, motionAreaThreshold) as hardcoded constants for now - these are implementation details, not config parameters.

Note: Audio and visual validators are internal implementation details of methods. They use config parameters but don't need to understand sports.
  </action>
  <verify>
    - `grep -c "sport: Sport" SportCrunch/Core/Services/AudioAnalyzer.swift` returns 0
    - `grep -c "sportMode" SportCrunch/Core/Services/AudioAnalyzer.swift` returns 0
    - `grep "config: MethodConfig" SportCrunch/Core/Services/AudioAnalyzer.swift` finds the new signature
    - `grep -c "sport: Sport" SportCrunch/Core/Services/VisualValidator.swift` returns 0
    - `grep "config: MethodConfig" SportCrunch/Core/Services/VisualValidator.swift` finds the new signature
  </verify>
  <done>
    - AudioAnalyzer.analyze() accepts MethodConfig instead of Sport/SportMode
    - VisualValidator.validate() accepts MethodConfig instead of Sport/SportMode
    - All config parameter values come from MethodConfig, not AnalysisPreset
    - No references to Sport or SportMode enums in either file
  </done>
</task>

<task type="auto">
  <name>Task 3: Update method implementations and call sites with config mapping</name>
  <files>
    methods/spectral_flux/v1/SpectralFluxMethod.swift
    methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift
    SportCrunch/Core/Services/VideoProcessingService.swift
    SportCrunchRunner/Services/RunExecutor.swift
  </files>
  <action>
**v1/SpectralFluxMethod.swift:**

1. Update `detectSegments()` signature to match protocol:
```swift
func detectSegments(
    videoURL: URL,
    config: MethodConfig
) async throws -> [ActionSegment]
```

2. Update the call to `audioAnalyzer.analyze()` to pass config:
```swift
audioResult = try await audioAnalyzer.analyze(
    videoURL: videoURL,
    config: config
)
```

3. Remove Sport/SportMode parameters and references.

**v2/SpectralFluxVisualValidationMethod.swift:**

1. Update `detectSegments()` signature to match protocol
2. Update both `audioAnalyzer.analyze()` and `visualValidator.validate()` calls to pass config
3. Remove Sport/SportMode parameters and references

**VideoProcessingService.swift:**

In the `RealVideoProcessingService` class:

1. Find the call to `method.detectSegments(videoURL:sport:sportMode:)` (around line 326 based on verification docs)

2. Create a MethodConfig from Sport/SportMode BEFORE calling method:
```swift
// Map sport/sportMode to method config
let preset = sport.preset(for: sportMode)
let config = MethodConfig(
    audioThresholdMultiplier: Double(preset.onsetThresholdLambda),
    peakMinDistance: preset.peakMinDistanceSec,
    clusterMaxGapSec: preset.clusterMaxGapSec,
    paddingPreSec: preset.paddingPreSec,
    paddingPostSec: preset.paddingPostSec,
    motionThreshold: preset.skipVisualValidation ? nil : Double(preset.motionAreaThreshold)
)

// Detect segments using method with config
let segments = try await method.detectSegments(
    videoURL: sourceURL,
    config: config
)
```

3. Keep the Sport/SportMode parameters in `processVideo()` - the SERVICE layer still needs to know about sports for the app UI, but it maps them to configs before calling methods.

**RunExecutor.swift:**

In the `executeRun()` method:

1. After parsing Sport and SportMode (lines 91-98), create config from preset:
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
```

2. Update the method call (line 113):
```swift
let segments = try await method.detectSegments(
    videoURL: videoURL,
    config: config
)
```

3. Keep the Sport/SportMode parsing logic - RunExecutor still receives sport/sportMode from API requests and maps them to configs.

Note: The OLD SpectralFluxMethod.swift in SportCrunch/Core/Services/ should be left as-is for now (it's the legacy implementation). Only update the NEW method files in methods/spectral_flux/v1/ and v2/.
  </action>
  <verify>
    - Build succeeds: `xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' clean build | tail -20`
    - No compiler errors related to method signatures
    - `grep "detectSegments.*config:" methods/spectral_flux/v1/SpectralFluxMethod.swift` finds updated signature
    - `grep "detectSegments.*config:" methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift` finds updated signature
    - All tests pass: `xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' | tail -50`
  </verify>
  <done>
    - Both method implementations updated to accept config parameter
    - VideoProcessingService maps Sport/SportMode to MethodConfig before calling method
    - RunExecutor maps Sport/SportMode to MethodConfig before calling method
    - All call sites updated, no SportMode passed to methods
    - Build succeeds with no warnings
    - All tests pass without modification
  </done>
</task>

</tasks>

<verification>
Run these commands to verify the complete refactoring:

```bash
# Verify protocol signature change
grep -n "func detectSegments" SportCrunch/Core/Services/SegmentationMethod.swift

# Verify no Sport/SportMode in protocol, analyzers, or validators
grep -c "sportMode" SportCrunch/Core/Services/SegmentationMethod.swift  # Should be 0
grep -c "sport: Sport" SportCrunch/Core/Services/AudioAnalyzer.swift  # Should be 0
grep -c "sport: Sport" SportCrunch/Core/Services/VisualValidator.swift  # Should be 0

# Verify config usage in methods
grep "config:" methods/spectral_flux/v1/SpectralFluxMethod.swift
grep "config:" methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift

# Verify MethodConfig struct exists
grep -A 20 "struct MethodConfig" SportCrunch/Core/Services/SegmentationMethod.swift

# Build and run all tests
xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: All tests pass with no code changes to test files. Tests use VideoProcessingService which internally maps Sport/SportMode to configs.
</verification>

<success_criteria>
- MethodConfig struct exists with parameters matching JSON config structure
- SegmentationMethod protocol uses config parameter, not Sport/SportMode
- AudioAnalyzer and VisualValidator accept config parameters
- Both v1 and v2 method implementations use config parameter
- VideoProcessingService and RunExecutor map Sport/SportMode to MethodConfig
- Sport/SportMode remain in app UI layer (HighlightCreationFlow, Project model)
- All existing tests pass without modification
- Build completes with no errors or warnings
- No SportMode references in SegmentationMethod, AudioAnalyzer, VisualValidator, or method implementations
</success_criteria>

<output>
After completion, create `.planning/quick/001-make-methods-accept-configs-instead-of-s/001-SUMMARY.md`
</output>
