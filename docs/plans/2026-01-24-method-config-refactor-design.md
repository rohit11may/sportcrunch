# Method Config Refactor Design

**Date:** 2026-01-24
**Status:** Approved
**Goal:** Simplify method config structure by removing JSON infrastructure, consolidating method versions, and making configs hot-swappable Swift structs.

## Problem Statement

The current method config structure has unnecessary complexity:

- Multiple JSON files per method with nested folder structures (v1/, v2/)
- JSON decoding overhead at runtime
- Build scripts to compile `_index.json` and registry files
- Multiple abstraction layers: `AnalysisPreset`, `MethodConfig`, `Algorithm`
- Debug reporting infrastructure that's no longer needed
- Shared utilities scattered between method folders

## Design Goals

1. **Self-contained methods**: Every file specific to a method lives in that method's folder
2. **Swift configs**: Replace JSON with compile-time Swift structs (no decoding overhead)
3. **Hot-swappable**: Sport/mode combinations map directly to configured methods
4. **No duplicate filenames**: Config files prefixed with method name to avoid Xcode build conflicts
5. **Simplified architecture**: Remove unnecessary abstraction layers

## 1. Folder Structure

### New Structure
```
methods/
  spectral_flux/
    SpectralFluxMethod.swift
    SpectralFluxMethodConfig.swift
    SpectralFluxAudioAnalyzer.swift
    SpectralFluxVisualValidator.swift
    configs/
      SpectralFluxTennisRally.swift
      SpectralFluxTennisIndividual.swift
```

### Key Principles
- **Self-contained**: All spectral flux files in one folder
- **No versioning**: Only keep current production method (v2 becomes the method)
- **Configs subfolder**: Separate configs from implementation
- **Unique names**: Configs prefixed with `SpectralFlux` to prevent build conflicts

### Migration from Current Structure
```
MOVE: methods/spectral_flux/SpectralFluxMethodConfig.swift
  TO: methods/spectral_flux/SpectralFluxMethodConfig.swift (modify in place)

MOVE: methods/spectral_flux/SpectralFluxAudioAnalyzer.swift
  TO: methods/spectral_flux/SpectralFluxAudioAnalyzer.swift (stays)

MOVE: methods/spectral_flux/SpectralFluxVisualValidator.swift
  TO: methods/spectral_flux/SpectralFluxVisualValidator.swift (stays)

MOVE: methods/spectral_flux/v2/SpectralFluxVisualValidationMethod.swift
  TO: methods/spectral_flux/SpectralFluxMethod.swift (rename)

CREATE: methods/spectral_flux/configs/SpectralFluxTennisRally.swift
CREATE: methods/spectral_flux/configs/SpectralFluxTennisIndividual.swift

DELETE: methods/spectral_flux/v1/ (entire folder)
DELETE: methods/spectral_flux/v2/ (entire folder)
DELETE: methods/spectral_flux/_family.json
DELETE: methods/_index.json
```

## 2. Config Pattern

### SpectralFluxMethodConfig Struct

Each method defines its own config struct (local to method folder).

```swift
//
//  SpectralFluxMethodConfig.swift
//  SportCrunch
//
//  Configuration parameters for spectral flux detection.
//

import Foundation

struct SpectralFluxMethodConfig: Sendable {
    // MARK: - Audio Processing

    /// Target sample rate for audio extraction (Hz)
    let sampleRate: Double

    /// Bandpass filter lower frequency cutoff (Hz)
    let bandpassLow: Double

    /// Bandpass filter upper frequency cutoff (Hz)
    let bandpassHigh: Double

    // MARK: - Onset Detection

    /// Multiplier for spectral flux threshold detection
    /// Higher = more conservative, fewer false positives
    let audioThresholdMultiplier: Double

    /// Minimum time distance between detected peaks (seconds)
    let peakMinDistance: Double

    // MARK: - Clustering

    /// Maximum gap between hits to group into same cluster (seconds)
    let clusterMaxGapSec: Double

    /// Minimum hits required for a cluster to be valid
    let clusterMinHits: Int

    // MARK: - Padding

    /// Seconds to add before detected segment start
    let paddingPreSec: Double

    /// Seconds to add after detected segment end
    let paddingPostSec: Double

    // MARK: - Visual Validation

    /// Frames to skip during motion analysis (higher = faster)
    let videoSampleStride: Int

    /// Thumbnail width for motion analysis
    let videoThumbWidth: Int

    /// Thumbnail height for motion analysis
    let videoThumbHeight: Int

    /// Pixel intensity difference to count as motion (0-255)
    let motionPixelThreshold: Int

    /// Motion threshold for visual validation (nil = audio-only mode)
    let motionThreshold: Double?
}
```

### Config Instance Pattern

Each config is a separate Swift file with a static instance:

```swift
//
//  SpectralFluxTennisRally.swift
//  SportCrunch
//
//  Tennis Rally Mode: Groups consecutive shots into rallies with longer padding
//

import Foundation

struct SpectralFluxTennisRallyConfig {
    static let instance = SpectralFluxMethodConfig(
        sampleRate: 16000,
        bandpassLow: 200,
        bandpassHigh: 3000,
        audioThresholdMultiplier: 2.0,
        peakMinDistance: 0.5,
        clusterMaxGapSec: 3.0,
        clusterMinHits: 2,
        paddingPreSec: 2.0,
        paddingPostSec: 2.0,
        videoSampleStride: 15,
        videoThumbWidth: 160,
        videoThumbHeight: 90,
        motionPixelThreshold: 10,
        motionThreshold: 50.0
    )
}
```

### Benefits
- No JSON decoding overhead
- Compile-time type safety
- Documentation in file header comments
- Each config is a separate file for clarity
- Static instance pattern for easy access

## 3. Protocol & Method Implementation

### Updated SegmentationMethod Protocol

Remove config parameter - methods are now "hydrated" with config at initialization:

```swift
//
//  SegmentationMethod.swift
//  SportCrunch
//

import Foundation

protocol SegmentationMethod: Sendable {
    /// Human-readable name identifying this detection method.
    var name: String { get }

    /// Detect action segments in a video.
    ///
    /// - Parameter videoURL: URL to the source video file
    /// - Returns: Array of detected action segments
    /// - Throws: If video access fails or detection encounters an error
    func detectSegments(videoURL: URL) async throws -> [ActionSegment]
}
```

### SpectralFluxMethod Implementation

```swift
//
//  SpectralFluxMethod.swift
//  SportCrunch
//
//  Spectral flux + visual validation detection method.
//

import Foundation

final class SpectralFluxMethod: SegmentationMethod {
    // MARK: - Properties

    var name: String { "SpectralFlux" }

    private let config: SpectralFluxMethodConfig
    private let audioAnalyzer = SpectralFluxAudioAnalyzer()
    private let visualValidator = SpectralFluxVisualValidator()

    // MARK: - Initialization

    init(config: SpectralFluxMethodConfig) {
        self.config = config
    }

    // MARK: - Segmentation Method Protocol

    func detectSegments(videoURL: URL) async throws -> [ActionSegment] {
        // Use self.config throughout
        let audioResult = try await audioAnalyzer.analyze(
            videoURL: videoURL,
            config: self.config
        )

        // ... rest of implementation
    }
}
```

### Key Changes
- Config passed via `init()` and stored as property
- `detectSegments()` no longer takes config parameter
- Remove pattern matching on `MethodConfig` enum (deleted)
- Simpler, cleaner interface

## 4. Sport.swift Integration

### New segmentationMethod(for:) Builder

Replace `algorithm(for:)` and `preset(for:)` with a single factory method:

```swift
// MARK: - Segmentation Method

/// Returns the configured segmentation method for this sport and mode.
///
/// The returned method is "hydrated" with its configuration and ready to use.
///
/// - Parameter mode: Optional sport mode (e.g., TennisMode.rally)
/// - Returns: Configured segmentation method ready for detection
func segmentationMethod(for mode: SportMode?) -> any SegmentationMethod {
    switch self {
    case .tennis:
        let tennisMode = (mode as? TennisMode) ?? .rally

        switch tennisMode {
        case .rally:
            return SpectralFluxMethod(
                config: SpectralFluxTennisRallyConfig.instance
            )
        case .individual:
            return SpectralFluxMethod(
                config: SpectralFluxTennisIndividualConfig.instance
            )
        }

    case .cricket:
        fatalError("Cricket not yet implemented")
    }
}
```

### Usage Pattern

```swift
// Old way (DELETED):
let algorithm = await sport.algorithm(for: mode)
let segments = try await algorithm.detectSegments(videoURL: videoURL)

// New way:
let method = sport.segmentationMethod(for: mode)
let segments = try await method.detectSegments(videoURL: videoURL)
```

### Deletions from Sport.swift
- **Lines 96-366**: Delete `AnalysisPreset` struct and all preset methods
- **Lines 369-401**: Delete `algorithm(for:)` method
- **Lines 403-461**: Delete deprecated `methodConfig(for:)` method

## 5. Files to Delete

### Core Infrastructure
```
app/SportCrunch/Core/Services/
  ConfigLoader.swift                    # DELETE - no more JSON loading
  MethodConfig.swift                    # DELETE - no more enum wrapper
  Algorithm.swift                       # DELETE - methods are now hydrated
  DebugReportService.swift              # DELETE (~1156 lines)
  ProcessingReportManager.swift         # DELETE (~412 lines)
```

### Method Files (Old Structure)
```
app/methods/
  spectral_flux/
    v1/                                 # DELETE entire folder
    v2/                                 # DELETE entire folder
    _family.json                        # DELETE
  _index.json                           # DELETE
```

### UI Components (Debug Reports)
```
app/SportCrunch/Features/Settings/
  DebugReportsListView.swift            # DELETE (~568 lines)
```

### Build Scripts
```
scripts/
  compile-method-registry.sh            # DELETE (if exists)
  build-configs.sh                      # DELETE (if exists)
```

### Modifications to Existing Files

**SettingsView.swift** - Remove developer mode section:
- Lines 16-17: Remove state variables
- Lines 46-55: Remove "Developer" section
- Lines 83-88: Remove sheet modifiers
- Lines 91-131: Remove debugReportsRow and updateDebugReportCount()

**AppState.swift** - Remove developer mode:
- Lines 29-34: Remove developerModeEnabled property
- Lines 143-148: Remove updateDebugReportService()

**Sport.swift** - Remove old methods:
- Lines 96-366: Delete AnalysisPreset and preset methods
- Lines 369-401: Delete algorithm(for:)
- Lines 403-461: Delete methodConfig(for:)

**Note:** Manually remove build phase from Xcode project that runs JSON compilation scripts.

## 6. Parameter Mapping

### From AnalysisPreset to SpectralFluxMethodConfig

Based on codebase analysis, these parameters map as follows:

| AnalysisPreset | SpectralFluxMethodConfig | Notes |
|---|---|---|
| `sampleRate: Double` | `sampleRate: Double` | Same |
| `bandpassLow: Double` | `bandpassLow: Double` | Same |
| `bandpassHigh: Double` | `bandpassHigh: Double` | Same |
| `onsetThresholdLambda: Float` | `audioThresholdMultiplier: Double` | Renamed, type changed |
| `peakMinDistanceSec: Double` | `peakMinDistance: Double` | Shortened name |
| `clusterMaxGapSec: Double` | `clusterMaxGapSec: Double` | Same |
| `clusterMinHits: Int` | `clusterMinHits: Int` | Same |
| `paddingPreSec: Double` | `paddingPreSec: Double` | Same |
| `paddingPostSec: Double` | `paddingPostSec: Double` | Same |
| `skipVisualValidation: Bool` | `motionThreshold == nil` | Pattern change |
| `videoSampleStride: Int` | `videoSampleStride: Int` | Same |
| `videoThumbSize: (width: Int, height: Int)` | `videoThumbWidth: Int, videoThumbHeight: Int` | Flattened tuple |
| `motionPixelThreshold: Int` | `motionPixelThreshold: Int` | Same |
| `motionAreaThreshold: Double` | `motionThreshold: Double?` | Renamed, made optional |

### Config Values

**Tennis Rally:**
```swift
SpectralFluxMethodConfig(
    sampleRate: 16000,
    bandpassLow: 200,
    bandpassHigh: 3000,
    audioThresholdMultiplier: 2.0,
    peakMinDistance: 0.5,
    clusterMaxGapSec: 3.0,
    clusterMinHits: 2,
    paddingPreSec: 2.0,
    paddingPostSec: 2.0,
    videoSampleStride: 15,
    videoThumbWidth: 160,
    videoThumbHeight: 90,
    motionPixelThreshold: 10,
    motionThreshold: 50.0
)
```

**Tennis Individual:**
```swift
SpectralFluxMethodConfig(
    sampleRate: 16000,
    bandpassLow: 200,
    bandpassHigh: 3000,
    audioThresholdMultiplier: 2.0,
    peakMinDistance: 0.5,
    clusterMaxGapSec: 1.0,      // Shorter gap
    clusterMinHits: 1,          // Single hit valid
    paddingPreSec: 0.5,         // Shorter padding
    paddingPostSec: 0.5,        // Shorter padding
    videoSampleStride: 15,
    videoThumbWidth: 160,
    videoThumbHeight: 90,
    motionPixelThreshold: 10,
    motionThreshold: 50.0
)
```

## 7. Integration Changes

### VideoProcessingService.swift

**Replace:**
```swift
let preset = sport.preset(for: sportMode)
let algorithm = await sport.algorithm(for: sportMode)
let segments = try await algorithm.detectSegments(videoURL: sourceURL)
```

**With:**
```swift
let method = sport.segmentationMethod(for: sportMode)
let segments = try await method.detectSegments(videoURL: sourceURL)
```

**Additional changes:**
- Update/remove logging that references preset values
- Remove any `ProcessingReportManager` / debug report code

### RunExecutor.swift

**Similar changes:**
- Replace `sport.algorithm(for:)` with `sport.segmentationMethod(for:)`
- Remove any debug reporting infrastructure

### SpectralFluxMethod.swift

**Remove pattern matching:**

**Current:**
```swift
func detectSegments(videoURL: URL, config: MethodConfig) async throws -> [ActionSegment] {
    guard case .spectralFlux(let spectralFluxConfig) = config else {
        fatalError("SpectralFluxMethod requires .spectralFlux config")
    }
    // Use spectralFluxConfig...
}
```

**New:**
```swift
func detectSegments(videoURL: URL) async throws -> [ActionSegment] {
    // Use self.config directly (stored from init)
    let audioResult = try await audioAnalyzer.analyze(
        videoURL: videoURL,
        config: self.config
    )
    // ...
}
```

### SpectralFluxAudioAnalyzer & SpectralFluxVisualValidator

**No interface changes needed** - they already accept `SpectralFluxMethodConfig` directly.

All fields from the expanded config are compatible with their current usage.

## Implementation Strategy

### Phase 1: Create New Structure
1. Create `methods/spectral_flux/configs/` folder
2. Write `SpectralFluxTennisRally.swift` and `SpectralFluxTennisIndividual.swift`
3. Update `SpectralFluxMethodConfig.swift` with expanded parameters
4. Rename `SpectralFluxVisualValidationMethod.swift` → `SpectralFluxMethod.swift`
5. Update `SpectralFluxMethod` to use config from init

### Phase 2: Update Protocol & Sport.swift
1. Update `SegmentationMethod.swift` protocol (remove config parameter)
2. Add `Sport.segmentationMethod(for:)` method
3. Update `SpectralFluxMethod.init()` to take config

### Phase 3: Update Integration Points
1. Update `VideoProcessingService.swift`
2. Update `RunExecutor.swift`
3. Update any other consumers of the old API

### Phase 4: Delete Old Infrastructure
1. Delete JSON config files
2. Delete `ConfigLoader.swift`, `MethodConfig.swift`, `Algorithm.swift`
3. Delete `DebugReportService.swift` and `ProcessingReportManager.swift`
4. Delete `DebugReportsListView.swift`
5. Update `SettingsView.swift` and `AppState.swift`
6. Delete build scripts
7. Delete `methods/spectral_flux/v1/` and `methods/spectral_flux/v2/` folders
8. Delete `_index.json` and `_family.json`
9. Remove old methods from `Sport.swift` (AnalysisPreset, algorithm, methodConfig)

### Phase 5: Manual Xcode Changes
1. Remove build phase that runs JSON compilation scripts (user will do this)

## Testing Considerations

- Verify tennis rally mode still detects segments correctly
- Verify tennis individual mode still detects segments correctly
- Verify config values match exactly between JSON and Swift versions
- Run existing tests to ensure no regression
- Test that logging still works without preset references

## Migration Notes

- **No backward compatibility needed** - this is a breaking refactor
- All config values migrated from existing JSON files
- Parameter mapping verified through codebase analysis
- Debug reports removed entirely (not migrated)

## Benefits

1. **Performance**: No JSON decoding overhead
2. **Type Safety**: Compile-time validation of all configs
3. **Simplicity**: Fewer abstraction layers (no Algorithm, MethodConfig, ConfigLoader)
4. **Maintainability**: Each method self-contained in one folder
5. **Build Simplicity**: No build scripts or JSON generation needed
6. **Cleaner Xcode**: No duplicate filename warnings

## Future Extensions

When adding new methods:

1. Create new method folder: `methods/new_method/`
2. Define method-specific config struct: `NewMethodConfig.swift`
3. Create config instances in `configs/` subfolder
4. Implement `SegmentationMethod` protocol
5. Add mapping in `Sport.segmentationMethod(for:)`

No changes to infrastructure needed - each method is self-contained.
