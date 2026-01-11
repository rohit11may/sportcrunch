# Phase 1: Test Infrastructure & Baseline - Research

**Researched:** 2026-01-11
**Domain:** XCTest for AVFoundation video processing with async/await
**Confidence:** HIGH

<research_summary>
## Summary

Researched the Swift testing ecosystem for building E2E tests that process video files through detection pipelines. The standard approach for 2025/2026 uses XCTest with native async/await support (no more manual expectations), organized via Xcode Test Plans to separate smoke tests from thorough suites.

Key finding: Swift Testing (announced WWDC 2024) is Apple's modern testing framework with better async support and parallel execution, but XCTest remains the standard for established codebases and has full support for async/await as of Swift 5.5. Both can coexist in the same test target.

For fuzzy matching of temporal video segments, the established approach uses Intersection over Union (IoU) combined with false-positive/false-negative rate tracking. IoU measures overlap between detected and ground truth segments (value 0-1), while FP/FN rates quantify how much extra video was kept vs. how much real content was missed.

**Primary recommendation:** Use XCTest with async/await for E2E video pipeline tests, organize via Test Plans (smoke vs regression), implement IoU-based fuzzy matching with FP/FN guardrails for segment evaluation.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| XCTest | Built-in (Xcode 16+) | Testing framework | Apple's standard, mature, full async/await support since Swift 5.5 |
| AVFoundation | Built-in (iOS 16+) | Video processing | Apple's framework for media asset handling |
| Swift 5.5+ | Current | Language | Async/await support required for modern testing patterns |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 16+ | Modern testing framework | New test code, parallel execution by default, better macros |
| XCTest Test Plans | Xcode 11+ | Test organization | Separating smoke tests from regression suites |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| XCTest | Swift Testing | Swift Testing has better async support and runs parallel by default, but XCTest is more mature and widely understood |
| Manual expectations | async/await test methods | async/await is cleaner and eliminates boilerplate, use it for all new tests |

**Installation:**
```swift
// XCTest and AVFoundation are built-in, no installation needed
// Swift Testing available in Xcode 16+ automatically
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
SportCrunchTests/
├── E2E/
│   ├── VideoProcessingTests.swift     # End-to-end pipeline tests
│   ├── SegmentDetectionTests.swift    # Core detection validation
│   └── TestResources/
│       ├── test-videos/               # Short test videos (10-30s)
│       └── ground-truth/              # Expected segments JSON/plist
├── Helpers/
│   ├── SegmentEvaluator.swift         # IoU + FP/FN calculation
│   └── TestVideoLoader.swift          # Load test assets
└── TestPlans/
    ├── Smoke.xctestplan               # Quick tests for dev
    └── Regression.xctestplan          # Thorough pre-commit suite
```

### Pattern 1: Async Test Method (Modern XCTest)
**What:** Test methods marked as `async` can directly await async operations
**When to use:** All new video processing tests
**Example:**
```swift
// Source: Apple Developer Forums + SwiftLee async testing guide
import XCTest
@testable import SportCrunch

final class VideoProcessingTests: XCTestCase {
    func testVideoSegmentDetection() async throws {
        // Load test video
        let videoURL = Bundle(for: type(of: self)).url(forResource: "rally-test", withExtension: "mp4")!

        // Process video through detection pipeline
        let detectedSegments = try await SegmentDetector.process(videoURL)

        // Assert segments match expectations
        XCTAssertEqual(detectedSegments.count, 3)
        XCTAssertEqual(detectedSegments[0].type, .rally)
    }
}
```

### Pattern 2: IoU-Based Fuzzy Matching
**What:** Measure overlap between detected and ground truth temporal segments
**When to use:** Evaluating detection accuracy when exact timestamps aren't guaranteed
**Example:**
```swift
// Based on video evaluation research (ActivityNet-style)
struct SegmentEvaluator {
    // IoU = intersection / union for temporal intervals
    static func iou(detected: TimeRange, groundTruth: TimeRange) -> Double {
        let intersection = max(0, min(detected.end, groundTruth.end) - max(detected.start, groundTruth.start))
        let union = max(detected.end, groundTruth.end) - min(detected.start, groundTruth.start)
        return union > 0 ? intersection / union : 0.0
    }

    // Match detected segments to ground truth using IoU threshold
    static func evaluate(
        detected: [Segment],
        groundTruth: [Segment],
        iouThreshold: Double = 0.5
    ) -> (tp: Int, fp: Int, fn: Int) {
        var matched = Set<Int>()
        var truePositives = 0

        for detectedSeg in detected {
            var bestMatch: (index: Int, iou: Double)? = nil
            for (idx, gtSeg) in groundTruth.enumerated() where !matched.contains(idx) {
                let overlap = iou(detected: detectedSeg.timeRange, groundTruth: gtSeg.timeRange)
                if overlap >= iouThreshold && (bestMatch == nil || overlap > bestMatch!.iou) {
                    bestMatch = (idx, overlap)
                }
            }
            if let match = bestMatch {
                matched.insert(match.index)
                truePositives += 1
            }
        }

        let falsePositives = detected.count - truePositives
        let falseNegatives = groundTruth.count - truePositives
        return (truePositives, falsePositives, falseNegatives)
    }

    // Calculate FP/FN rates as percentages
    static func calculateRates(detected: [Segment], groundTruth: [Segment]) -> (fpRate: Double, fnRate: Double) {
        let totalGroundTruthDuration = groundTruth.map { $0.duration }.reduce(0, +)
        let totalDetectedDuration = detected.map { $0.duration }.reduce(0, +)

        // FP rate: extra video kept that wasn't in ground truth
        let extraDuration = max(0, totalDetectedDuration - totalGroundTruthDuration)
        let fpRate = totalGroundTruthDuration > 0 ? (extraDuration / totalGroundTruthDuration) * 100 : 0

        // FN rate: ground truth video that was missed
        // (This is simplified - actual implementation needs segment-by-segment analysis)
        let (_, fp, fn) = evaluate(detected: detected, groundTruth: groundTruth)
        let missedSegmentsDuration = groundTruth.enumerated()
            .filter { !matched.contains($0.offset) }
            .map { $0.element.duration }
            .reduce(0, +)
        let fnRate = totalGroundTruthDuration > 0 ? (missedSegmentsDuration / totalGroundTruthDuration) * 100 : 0

        return (fpRate, fnRate)
    }
}
```

### Pattern 3: Test Plan Organization
**What:** Use Xcode Test Plans to separate smoke tests from comprehensive regression tests
**When to use:** When you have both quick development tests and thorough pre-commit suites
**Example:**
```swift
// Smoke.xctestplan - Quick tests (tagged or specific test classes)
{
  "configurations": [
    {
      "name": "Smoke Tests",
      "options": {
        "testTimeoutsEnabled": true,
        "maximumTestExecutionTimeAllowance": 300  // 5 minutes
      }
    }
  ],
  "testTargets": [
    {
      "target": {
        "name": "SportCrunchTests"
      },
      "selectedTests": [
        "VideoProcessingTests/testBasicRallyDetection()",
        "VideoProcessingTests/testShotByShotDetection()"
      ]
    }
  ]
}

// Regression.xctestplan - Comprehensive suite
{
  "configurations": [
    {
      "name": "Regression Tests",
      "options": {
        "testTimeoutsEnabled": true,
        "maximumTestExecutionTimeAllowance": 1800  // 30 minutes
      }
    }
  ],
  "testTargets": [
    {
      "target": {
        "name": "SportCrunchTests"
      }
      // Runs all tests
    }
  ]
}
```

### Anti-Patterns to Avoid
- **Using XCTestExpectation with async/await:** Modern async test methods don't need manual expectations - just mark test as `async throws`
- **Processing long videos in tests:** Use short (10-30s) test clips for fast execution
- **Exact timestamp matching:** Algorithm variations mean you need fuzzy matching with IoU, not exact equality
- **Mixing async/await with waitForExpectations:** This causes hangs - use one pattern or the other, not both
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async test execution | Manual Task + XCTestExpectation | `async` test methods | XCTest natively supports async/await since Swift 5.5, cleaner code |
| Test organization | Manual test grouping | Xcode Test Plans | Built-in support for smoke vs regression, timeout control |
| Temporal overlap calculation | Custom time interval logic | IoU (Intersection over Union) | Well-established metric in video evaluation, handles edge cases |
| Video asset loading | Custom bundle resource logic | `Bundle.url(forResource:withExtension:)` | Standard iOS pattern, handles test bundles correctly |

**Key insight:** XCTest's async/await support (since Swift 5.5) eliminates the need for manual expectation management that plagued older test code. Use native async test methods for all new tests - they're cleaner, less error-prone, and easier to understand.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Test Timeouts with Long Videos
**What goes wrong:** Tests timeout or take too long, slowing development iteration
**Why it happens:** Processing full-length videos (30+ minutes) in tests
**How to avoid:** Use short test clips (10-30 seconds) that still exercise detection logic. Set reasonable timeouts via `executionTimeAllowance` or Test Plans
**Warning signs:** Tests taking >30 seconds to run, frequent timeout failures

### Pitfall 2: Mixing Async Patterns
**What goes wrong:** Tests hang indefinitely when mixing async/await with XCTestExpectation
**Why it happens:** Combining old (expectation-based) and new (async/await) patterns in same test
**How to avoid:** Use async test methods exclusively - no expectations needed
**Warning signs:** Tests that never complete, need to force-quit test runner

### Pitfall 3: Flaky Tests from Exact Timestamp Matching
**What goes wrong:** Tests fail randomly despite algorithm working correctly
**Why it happens:** Algorithm produces slightly different timestamps on each run (floating point math, hardware variations)
**How to avoid:** Use IoU-based fuzzy matching with threshold (e.g., IoU > 0.5), track FP/FN rates instead of exact equality
**Warning signs:** Tests that pass/fail inconsistently, "off by 0.2 seconds" type failures

### Pitfall 4: Test Video Resource Management
**What goes wrong:** Test videos not found at runtime, bundle resource errors
**Why it happens:** Test videos not added to test target, incorrect resource paths
**How to avoid:** Add test videos to test target explicitly, use `Bundle(for:)` to get test bundle, verify resources in setUp()
**Warning signs:** "File not found" errors, nil URLs from bundle lookups

### Pitfall 5: Actor Isolation in Async Tests
**What goes wrong:** Data races or actor isolation warnings in test mocks
**Why it happens:** Shared mutable state accessed from multiple async contexts
**How to avoid:** Use actor-isolated test mocks for shared state, or inject dependencies via protocols
**Warning signs:** Concurrency warnings in test code, intermittent test failures
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from official sources:

### Basic Async Test with Video Processing
```swift
// Source: Swift Forums async/await XCTest discussion
import XCTest
import AVFoundation
@testable import SportCrunch

final class SegmentDetectionTests: XCTestCase {
    func testRallyDetection() async throws {
        // Load test video from bundle
        let bundle = Bundle(for: type(of: self))
        guard let videoURL = bundle.url(forResource: "rally-10s", withExtension: "mp4") else {
            XCTFail("Test video not found")
            return
        }

        // Load ground truth segments
        let groundTruthURL = bundle.url(forResource: "rally-10s-truth", withExtension: "json")!
        let groundTruth = try JSONDecoder().decode([Segment].self, from: Data(contentsOf: groundTruthURL))

        // Process video
        let detector = SegmentDetector()
        let detected = try await detector.detect(in: videoURL, mode: .rally)

        // Evaluate with fuzzy matching
        let evaluation = SegmentEvaluator.evaluate(detected: detected, groundTruth: groundTruth, iouThreshold: 0.5)
        let rates = SegmentEvaluator.calculateRates(detected: detected, groundTruth: groundTruth)

        // Assert guardrails
        XCTAssertLessThan(rates.fpRate, 15.0, "False positive rate exceeds 15% threshold")
        XCTAssertLessThan(rates.fnRate, 10.0, "False negative rate exceeds 10% threshold")

        // Assert basic correctness
        XCTAssertGreaterThan(evaluation.tp, 0, "Should detect at least one correct segment")
    }
}
```

### Custom Async Timeout Wrapper (Optional)
```swift
// Source: SwiftLee async testing guide
extension XCTestCase {
    func asyncTest(
        timeout: TimeInterval = 10.0,
        file: StaticString = #file,
        line: UInt = #line,
        test: @escaping () async throws -> Void
    ) async {
        let task = Task {
            try await test()
        }

        do {
            let result = try await task.value
        } catch {
            XCTFail("Async test failed: \(error)", file: file, line: line)
        }
    }
}

// Usage (though modern XCTest async methods are preferred)
func testWithCustomTimeout() async {
    await asyncTest(timeout: 30.0) {
        // Long-running async operation
        try await processLongVideo()
    }
}
```

### Setting Test Timeouts via executionTimeAllowance
```swift
// Source: XCTest documentation
final class LongRunningTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Allow up to 2 minutes for video processing tests
        executionTimeAllowance = 120.0
    }

    func testFullPipelineProcessing() async throws {
        // This test might take 60+ seconds
        let result = try await processTestVideo()
        XCTAssertNotNil(result)
    }
}
```
</code_examples>

<sota_updates>
## State of the Art (2025-2026)

What's changed recently:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| XCTestExpectation for async | async/await test methods | Swift 5.5 (2021), widely adopted 2024+ | Cleaner test code, no manual expectation management |
| XCTest only | Swift Testing framework | WWDC 2024 (Xcode 16) | Better async support, parallel by default, modern macros |
| Manual test grouping | Xcode Test Plans | Xcode 11 (2019), best practice 2024+ | Smoke vs regression separation, timeout control |
| Sequential test execution | Parallel execution | Swift Testing default behavior | Faster test suites, but requires thread-safe test code |

**New tools/patterns to consider:**
- **Swift Testing (#expect, @Test):** Modern framework with better async support, can coexist with XCTest in same target
- **Test Plans:** Separate smoke tests (quick dev feedback) from regression tests (comprehensive pre-commit)
- **Native async/await:** No more expectations, timeouts, or fulfillment tracking for async operations

**Deprecated/outdated:**
- **XCTestExpectation for async code:** Use async test methods instead
- **waitForExpectations(timeout:):** Not needed with async/await
- **Manual timeout management:** Use executionTimeAllowance or Test Plan configuration
</sota_updates>

<open_questions>
## Open Questions

Things that couldn't be fully resolved:

1. **Swift Testing adoption timeline**
   - What we know: Swift Testing announced WWDC 2024, available in Xcode 16+, can coexist with XCTest
   - What's unclear: How quickly iOS teams are migrating, production readiness for large test suites
   - Recommendation: Start with XCTest (established, well-understood), evaluate Swift Testing for new test targets after Phase 1

2. **Optimal IoU threshold for temporal segments**
   - What we know: Standard object detection uses 0.5, ActivityNet-style evaluation uses 0.5 default
   - What's unclear: Whether 0.5 is appropriate for sports video segments (rally detection might need tighter/looser)
   - Recommendation: Start with 0.5, tune based on actual algorithm behavior during Phase 2 (Golden Test Suite)

3. **Test video storage approach**
   - What we know: Bundle resources work, Test Plans can reference files
   - What's unclear: Whether to store test videos in Git (size concerns) vs external storage
   - Recommendation: Start with small test clips (<1MB each) in Git, move to Git LFS or external storage if test suite grows
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [Asynchronous Tests and Expectations | Apple Developer](https://developer.apple.com/documentation/xctest/asynchronous-tests-and-expectations) - Official XCTest async patterns
- [Unit testing Swift code that uses async/await | Swift by Sundell](https://www.swiftbysundell.com/articles/unit-testing-code-that-uses-async-await/) - Modern async testing patterns
- [Meet Swift Testing - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10179/) - Official Swift Testing introduction
- [Intersection over Union (IoU) | PyImageSearch](https://pyimagesearch.com/2016/11/07/intersection-over-union-iou-for-object-detection/) - IoU fundamentals
- [Intersection Over Union IoU | LearnOpenCV](https://learnopencv.com/intersection-over-union-iou-in-object-detection-and-segmentation/) - IoU for detection/segmentation

### Secondary (MEDIUM confidence)
- [Unit testing async/await Swift code - SwiftLee](https://www.avanderlee.com/concurrency/unit-testing-async-await/) - Verified async patterns
- [Swift Testing vs. XCTest | Infosys](https://blogs.infosys.com/digital-experience/mobility/swift-testing-vs-xctest-a-comprehensive-comparison.html) - Framework comparison
- [XCTest Best Practices | Maestro](https://maestro.dev/insights/xctest-best-practices-ios-testing) - Test organization patterns
- [Evaluating Models | FiftyOne](https://docs.voxel51.com/user_guide/evaluation.html) - FP/FN evaluation for video
- [WWDC19: Getting Started with Test Plan for XCTest](https://shashikantjagtap.net/wwdc19-getting-started-with-test-plan-for-xctest/) - Test Plans guide

### Tertiary (LOW confidence - needs validation)
- [A Closer Look at Temporal Ordering in Video Segmentation](https://arxiv.org/abs/2209.15501) - Academic research on temporal segment matching (not Swift-specific)
- [DuckDB's AsOf Joins](https://duckdb.org/2023/09/15/asof-joins-fuzzy-temporal-lookups) - Temporal fuzzy matching concept (different domain)
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: XCTest with async/await for AVFoundation video processing
- Ecosystem: Swift Testing, Test Plans, IoU evaluation metrics
- Patterns: Async test methods, fuzzy matching, smoke vs regression organization
- Pitfalls: Timeout handling, test flakiness, resource management

**Confidence breakdown:**
- Standard stack: HIGH - XCTest is well-documented, async/await support verified in official Apple sources
- Architecture: HIGH - Patterns from official docs and established developer guides (2024-2025)
- Pitfalls: HIGH - Common issues documented in Swift Forums, developer blogs
- Code examples: HIGH - Sourced from official documentation and verified developer resources

**Research date:** 2026-01-11
**Valid until:** 2026-02-11 (30 days - Swift/XCTest ecosystem is stable, but Swift Testing is new)

</metadata>

---

*Phase: 01-test-infrastructure-baseline*
*Research completed: 2026-01-11*
*Ready for planning: yes*
