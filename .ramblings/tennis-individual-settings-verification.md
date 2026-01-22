# Tennis Individual Mode Settings Verification

**Date:** 2026-01-22
**Context:** Verify tennis individual mode settings are equivalent after MethodConfig refactor

## Summary

✅ **Tennis Individual mode settings are IDENTICAL before and after refactor**
✅ **Dynamic mapping from Sport preset → MethodConfig is working correctly**
⚠️  **Static JSON config files have incorrect values (but are NOT being used yet)**

---

## Detailed Analysis

### 1. Preset Values (Source of Truth)

**Tennis Individual Mode Preset** (Sport.swift:303-332)

| Parameter | Before Refactor | After Refactor | Status |
|-----------|----------------|----------------|--------|
| `onsetThresholdLambda` | 2.0 | 2.0 | ✅ Unchanged |
| `peakMinDistanceSec` | 0.5 | 0.5 | ✅ Unchanged |
| `clusterMaxGapSec` | 1.0 | 1.0 | ✅ Unchanged |
| `paddingPreSec` | 0.5 | 0.5 | ✅ Unchanged |
| `paddingPostSec` | 0.5 | 0.5 | ✅ Unchanged |
| `motionAreaThreshold` | 50 | 50 | ✅ Unchanged |

**Git verification:**
- Before: `git show 8c73883~1:app/SportCrunch/Core/Models/Sport.swift`
- After: Current HEAD

---

### 2. Dynamic Mapping (How It Works)

Both the main app and the Runner dynamically create MethodConfig from Sport presets:

**VideoProcessingService.swift:327-335:**
```swift
let preset = sport.preset(for: sportMode)
let config = MethodConfig(
    audioThresholdMultiplier: Double(preset.onsetThresholdLambda),  // 2.0 → 2.0
    peakMinDistance: preset.peakMinDistanceSec,                     // 0.5 → 0.5
    clusterMaxGapSec: preset.clusterMaxGapSec,                      // 1.0 → 1.0
    paddingPreSec: preset.paddingPreSec,                            // 0.5 → 0.5
    paddingPostSec: preset.paddingPostSec,                          // 0.5 → 0.5
    motionThreshold: preset.skipVisualValidation
        ? nil
        : Double(preset.motionAreaThreshold)                        // 50 → 50.0
)
```

**RunExecutor.swift:102-110:**
```swift
// IDENTICAL mapping
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

**Result:** Both produce IDENTICAL MethodConfig for tennis individual mode:
```swift
MethodConfig(
    audioThresholdMultiplier: 2.0,
    peakMinDistance: 0.5,
    clusterMaxGapSec: 1.0,
    paddingPreSec: 0.5,
    paddingPostSec: 0.5,
    motionThreshold: 50.0
)
```

---

### 3. Static JSON Configs (Not Used Yet)

**Current default-v2.config.json** (app/methods/spectral_flux/v2/configs/default-v2.config.json):
```json
{
  "name": "default",
  "description": "Standard detection parameters with visual validation",
  "parameters": {
    "audioThresholdMultiplier": 1.5,  ❌ Should be 2.0 for individual
    "peakMinDistance": 0.5,           ✅ Correct
    "motionThreshold": 100.0,         ❌ Should be 50.0 for individual
    "paddingPreSec": 1.5,             ❌ Should be 0.5 for individual
    "paddingPostSec": 1.0,            ❌ Should be 0.5 for individual
    "clusterMaxGapSec": 2.0           ❌ Should be 1.0 for individual
  }
}
```

**However:** These JSON configs are **NOT being used** by the app or Runner yet. They're placeholders for Plan 07-03 (Runner method registry loading).

---

### 4. Comparison: Rally vs Individual Modes

| Parameter | Rally Mode | Individual Mode | Current JSON Config |
|-----------|-----------|----------------|-------------------|
| `audioThresholdMultiplier` | 2.0 | 2.0 | 1.5 ❌ |
| `peakMinDistance` | 0.5 | 0.5 | 0.5 ✅ |
| `clusterMaxGapSec` | 3.0 | 1.0 | 2.0 ⚠️ (between modes) |
| `paddingPreSec` | 2.0 | 0.5 | 1.5 ⚠️ (between modes) |
| `paddingPostSec` | 2.0 | 0.5 | 1.0 ⚠️ (between modes) |
| `motionThreshold` | 50.0 | 50.0 | 100.0 ❌ |

The current JSON config values are **somewhere between Rally and Individual modes**, which is incorrect for both.

---

## Why Highlights Might Seem Shorter

If highlights are shorter than expected, possible causes:

1. **Wrong mode selected?**
   - Rally mode: Longer clips (3s gap, 2s padding)
   - Individual mode: Shorter clips (1s gap, 0.5s padding)
   - Check: Are you selecting "Rally" vs "Shot Mode" correctly?

2. **Different video?**
   - Different videos have different action density
   - Fewer rallies = shorter highlight reel

3. **JSON configs confusion?**
   - If you manually edited JSON configs expecting them to be used, they're NOT active yet
   - The app uses Sport presets, not JSON configs

---

## Recommended Actions

### For Current Work:
✅ **No action needed** - The refactor is working correctly with identical settings

### For Future (Plan 07-03):
⚠️  **Fix JSON configs** to provide proper defaults when method registry loading is implemented

Create separate configs for different use cases:
- `tennis-rally.config.json` - Rally mode settings
- `tennis-individual.config.json` - Individual/shot mode settings
- `default-v2.config.json` - Generic balanced settings

---

## Verification Commands

```bash
# Check current preset values
grep -A 30 "case .individual:" app/SportCrunch/Core/Models/Sport.swift

# Check preset values before refactor
git show 8c73883~1:app/SportCrunch/Core/Models/Sport.swift | grep -A 30 "case .individual:"

# Check JSON configs
cat app/methods/spectral_flux/v2/configs/default-v2.config.json

# Verify no config loading code exists
osgrep "load config from json"
```

---

## Conclusion

**The tennis individual mode settings are CORRECT and UNCHANGED after the refactor.**

Both the main app and Runner are using the same dynamic mapping from Sport preset to MethodConfig. The static JSON config files have incorrect values, but they're not being used yet (they're for future Dashboard/Runner method selection in Plan 07-03).

If highlights are shorter than expected, it's likely due to mode selection or video content, NOT the refactor.
