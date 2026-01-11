# Test Resources Guide

This document specifies the format and requirements for test resources used in E2E testing of segment detection.

## Directory Structure

```
SportCrunchTests/
├── TestResources/
│   ├── Videos/           # Test video files (MP4)
│   └── GroundTruth/      # Segment annotations (JSON)
├── Helpers/              # Test utilities (SegmentEvaluator, TestResourceLoader)
└── Models/               # Test data models (GroundTruth)
```

## Ground Truth JSON Format

Ground truth files specify the expected segments that should be detected in a test video. Each JSON file corresponds to one test video.

### Schema

```json
{
  "videoFilename": "rally-tennis-01.mp4",
  "sport": "tennis",
  "mode": "rally",
  "segments": [
    {
      "start": 2.5,
      "end": 6.8
    },
    {
      "start": 8.1,
      "end": 11.3
    }
  ]
}
```

### Field Descriptions

- **`videoFilename`** (string, required): Filename of the associated video file (e.g., `"rally-tennis-01.mp4"`)
- **`sport`** (string, required): Sport type (e.g., `"tennis"`, `"cricket"`)
- **`mode`** (string, required): Detection mode (e.g., `"rally"`, `"shot"`) - applies to all segments in this file
- **`segments`** (array, required): Array of expected segment time intervals
  - **`start`** (number, required): Segment start time in seconds (Double precision)
  - **`end`** (number, required): Segment end time in seconds (Double precision)

### Naming Convention

JSON filenames must match the corresponding video filename:
- Video: `rally-tennis-01.mp4`
- Ground Truth: `rally-tennis-01.json`

## Video Requirements

### Format Specifications

- **Container Format:** MP4
- **Video Codec:** H.264 (preferred)
- **Audio Codec:** AAC (preferred)
- **Duration:** 10-30 seconds for quick test execution
- **Resolution:** Any (preferably 1080p or 720p)

### Content Requirements

- Videos should contain **clear examples** of what needs detecting (rallies, shots, etc.)
- Include both:
  - **Action segments:** Clear examples of rallies/shots
  - **Dead space:** Non-action periods between segments
- Avoid edge cases in baseline tests (use those for targeted regression tests)

### Naming Convention

Use descriptive pattern: `{mode}-{sport}-{number}.mp4`

Examples:
- `rally-tennis-01.mp4`
- `rally-tennis-02.mp4`
- `shot-tennis-01.mp4`
- `rally-cricket-01.mp4`

## Adding Resources to Xcode

Follow these steps to add test resources to the Xcode project:

### Step-by-Step Instructions

1. **In Xcode**, right-click the `SportCrunchTests` group in the Project Navigator
2. Select **"Add Files to SportCrunch..."**
3. Navigate to your test video or ground truth JSON file
4. **Check** "Copy items if needed"
5. **IMPORTANT:** In the "Add to targets" section, select **`SportCrunchTests`** (NOT the main app target)
6. Click **Add**

### Verifying Target Membership

After adding files, verify they're in the correct target:

1. Click on the video or JSON file in Project Navigator
2. Open the **File Inspector** (right panel, first tab)
3. Under "Target Membership", verify **`SportCrunchTests`** is checked
4. If `SportCrunch` (main app) is checked, uncheck it

### Directory Structure in Xcode

Organize files in Xcode groups to match the physical directory structure:

- Create `TestResources` group under `SportCrunchTests`
- Create `Videos` subgroup under `TestResources`
- Create `GroundTruth` subgroup under `TestResources`
- Drag files into appropriate groups

## Minimum Requirements for Phase 1

To complete Phase 1 (Test Infrastructure & Baseline), you need:

- **At least 1 tennis rally test video** with corresponding ground truth JSON
- Recommended: Start with 1-2 simple test cases
- Expansion to comprehensive golden test suite occurs in Phase 2

### Suggested First Test Case

**Video:** `rally-tennis-01.mp4`
- Duration: 15-20 seconds
- Contains 2-3 clear rally segments
- Has clear dead space between rallies

**Ground Truth:** `rally-tennis-01.json`
- Matches the video filename
- Accurately marks rally start/end times
- Mode: `"rally"`
- Sport: `"tennis"`

## Validation

### How to Verify Resources Are Properly Added

1. **Build the test target:**
   - Press `Cmd+U` to run tests
   - Or use: `xcodebuild build -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 16'`

2. **Check target membership:**
   - Select video/JSON file in Project Navigator
   - Verify `SportCrunchTests` is checked in File Inspector

3. **Test resource loading:**
   ```swift
   // In any test file
   func testResourcesExist() {
       XCTAssertTrue(TestResourceLoader.testResourcesExist())
   }
   ```

## Troubleshooting

### "Test video not found" Error

**Cause:** Video file not in test bundle or wrong target membership

**Solutions:**
1. Verify file is in `TestResources/Videos/` directory
2. Check target membership: Should be `SportCrunchTests` only
3. Clean build folder: `Product > Clean Build Folder` (Cmd+Shift+K)
4. Rebuild: `Product > Build` (Cmd+B)

### "Ground truth file not found" Error

**Cause:** JSON file not in test bundle or wrong target membership

**Solutions:**
1. Verify file is in `TestResources/GroundTruth/` directory
2. Check target membership: Should be `SportCrunchTests` only
3. Verify filename matches video: `rally-tennis-01.mp4` → `rally-tennis-01.json`
4. Clean and rebuild

### "Invalid JSON" Error

**Cause:** JSON format doesn't match schema

**Solutions:**
1. Validate JSON syntax using online validator (jsonlint.com)
2. Verify all required fields are present: `videoFilename`, `sport`, `mode`, `segments`
3. Check segment format: `start` and `end` are numbers, not strings
4. Ensure arrays use `[]` brackets and objects use `{}` braces

### Bundle Resource Not Found

**Cause:** Xcode not copying resources to test bundle

**Solutions:**
1. Check Build Phases: Select `SportCrunchTests` target → Build Phases → Copy Bundle Resources
2. Verify test resources are listed
3. If missing, drag files from Project Navigator into "Copy Bundle Resources"
4. Clean and rebuild

## Usage in Tests

### Loading Test Resources

```swift
import XCTest

class SegmentDetectionTests: XCTestCase {
    func testRallyDetection() throws {
        // Load test video
        let videoURL = try TestResourceLoader.loadTestVideo(named: "rally-tennis-01.mp4")

        // Load ground truth
        let groundTruth = try TestResourceLoader.loadGroundTruth(named: "rally-tennis-01.json")

        // Run detection
        let detectedSegments = // ... your detection logic

        // Evaluate using SegmentEvaluator
        let (tp, fp, fn) = SegmentEvaluator.evaluate(
            detected: detectedSegments,
            groundTruth: groundTruth.segments.map { TimeRange(start: $0.start, end: $0.end) }
        )

        // Assert guardrails
        XCTAssertGreaterThanOrEqual(tp, groundTruth.segments.count - 1, "Too many false negatives")
        XCTAssertLessThanOrEqual(fp, 2, "Too many false positives")
    }
}
```

## Next Steps

1. **Add your first test video and ground truth** following the instructions above
2. **Verify resources load correctly** using validation methods
3. **Implement E2E tests** in Phase 2 using the test infrastructure

For questions or issues, see the troubleshooting section or consult the project maintainer.
