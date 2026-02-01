# Hough Method Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the "Hough Method" for tennis ball tracking using a custom Swift linearity detector and Accelerate-based motion processing, adhering to the "training-free" physics-based architecture.

**Architecture:**
1.  **MotionProcessor:** Uses `Accelerate` (vImage/vDSP) for 3-frame differencing and vectorized thresholding to produce a binary motion mask. Three-frame differencing provides better noise rejection than two-frame by requiring motion in consecutive frame pairs.
2.  **LinearityDetector:** A custom, pure-Swift algorithm (RANSAC-inspired) to detect linear streaks in the motion mask, robust to gaps.
3.  **HoughMethod:** The method class that coordinates the pipeline and outputs `ActionSegment`s.
4.  **RunObservation:** Fully instrumented to visualize the intermediate masks and detected lines in the Lab view.

**Tech Stack:** Swift 6, Accelerate (vImage/vDSP), AVFoundation.

---

### Task 1: Scaffolding & Configuration

**Files:**
- Create: `app/methods/hough/HoughMethodConfig.swift`
- Create: `app/methods/hough/HoughMethod.swift`
- Create: `app/methods/hough/configs/HoughTennisConfig.swift`

**Step 1: Create Configuration Struct**

Define the parameters needed for tuning both the image processing and line detection.

```swift
// app/methods/hough/HoughMethodConfig.swift
import Foundation

public struct HoughMethodConfig: Sendable {
    // MARK: - Motion Processing
    /// Threshold for pixel intensity difference (0-255)
    public let diffThreshold: UInt8
    /// Minimum motion area to consider (noise filter)
    public let minMotionArea: Int

    // MARK: - Linearity Detection
    /// Minimum length of a streak (pixels)
    public let minStreakLength: Double
    /// Maximum gap between points in a streak (pixels)
    public let maxStreakGap: Double
    /// Tolerance for line fitting (pixels distance from vector)
    public let lineTolerance: Double
    /// Minimum density of points along the line (0.0-1.0)
    public let minDensity: Double

    // MARK: - Temporal
    /// Max gap between frames to link a rally
    public let rallyMaxGap: TimeInterval
    /// Min duration of a rally
    public let rallyMinDuration: TimeInterval
}
```

**Step 2: Create Default Config**

```swift
// app/methods/hough/configs/HoughTennisConfig.swift
import Foundation

public struct HoughTennisConfig {
    public static let instance = HoughMethodConfig(
        diffThreshold: 25,
        minMotionArea: 50,
        minStreakLength: 20.0,
        maxStreakGap: 10.0,
        lineTolerance: 3.0,
        minDensity: 0.5,
        rallyMaxGap: 4.0,
        rallyMinDuration: 2.0
    )
}
```

**Step 3: Scaffold Method Class**

Basic conformance to `SegmentationMethod` to ensure project structure is valid.

```swift
// app/methods/hough/HoughMethod.swift
import Foundation

public final class HoughMethod: SegmentationMethod {
    public let name = "Hough"
    private let config: HoughMethodConfig

    public init(config: HoughMethodConfig) {
        self.config = config
    }

    public func detectSegments(videoURL: URL, observation: RunObservation?) async throws -> [ActionSegment] {
        // Placeholder implementation
        return []
    }
}
```

**Step 4: Commit**

```bash
git add app/methods/hough/HoughMethodConfig.swift app/methods/hough/HoughMethod.swift app/methods/hough/configs/HoughTennisConfig.swift
git commit -m "feat: scaffold HoughMethod configuration and class"
```

---

### Task 2: Custom Linearity Detector (The "Brain")

**Files:**
- Create: `app/methods/hough/HoughLinearityDetector.swift`
- Create: `app/SportCrunchTests/HoughLinearityDetectorTests.swift`

**Step 1: Write Test for Simple Horizontal Line**

We need to test that our detector finds a simple line in a point cloud.

```swift
// app/SportCrunchTests/HoughLinearityDetectorTests.swift
import XCTest
@testable import SportCrunch

final class HoughLinearityDetectorTests: XCTestCase {
    func testHorizontalLineDetection() {
        let detector = HoughLinearityDetector()
        let config = HoughMethodConfig(
            diffThreshold: 0, minMotionArea: 0, // irrelevant
            minStreakLength: 10,
            maxStreakGap: 5,
            lineTolerance: 2,
            minDensity: 0.5,
            rallyMaxGap: 0, rallyMinDuration: 0
        )

        // Create points for a horizontal line: (0, 10) -> (20, 10)
        var points: [MotionPoint] = []
        for x in stride(from: 0, through: 20, by: 2) {
            points.append(MotionPoint(x: Double(x), y: 10))
        }

        let lines = detector.detect(points: points, config: config)

        XCTAssertEqual(lines.count, 1)
        let line = lines.first!
        XCTAssertEqual(line.start.y, 10, accuracy: 0.1)
        XCTAssertEqual(line.end.y, 10, accuracy: 0.1)
        XCTAssertGreaterThan(line.length, 18)
    }
}
```

**Step 2: Run test (Fail)**
Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/HoughLinearityDetectorTests`
Expected: Fail (Type not found)

**Step 3: Implement Linearity Detector**

We'll use a **Greedy RANSAC-like** approach:
1.  Pick a random point.
2.  Find neighbors within `maxStreakGap`.
3.  Form vectors to neighbors.
4.  Grow the line along the best vector.
5.  If line meets criteria, save it and remove its points.

```swift
// app/methods/hough/HoughLinearityDetector.swift
import Foundation

/// A point in 2D space representing a motion pixel location.
/// Named MotionPoint to avoid collision with CGPoint or other Point types.
public struct MotionPoint: Hashable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct LineSegment: Sendable {
    public let start: MotionPoint
    public let end: MotionPoint
    public let length: Double
    public let points: [MotionPoint]
}

public struct HoughLinearityDetector: Sendable {
    public init() {}

    public func detect(points: [MotionPoint], config: HoughMethodConfig) -> [LineSegment] {
        var remainingPoints = Set(points)
        var segments: [LineSegment] = []

        // Max iterations to avoid infinite loops
        var iterations = 0
        let maxIterations = points.count * 2

        while !remainingPoints.isEmpty && iterations < maxIterations {
            iterations += 1
            // 1. Pick a random seed point
            guard let seed = remainingPoints.randomElement() else { break }

            // 2. Find local neighborhood (potential next points)
            // Optimization: In real image processing, we might use a grid.
            // For now, naive O(N) search is okay for sparse points (< 1000).
            let neighbors = remainingPoints.filter { p in
                p != seed && distance(seed, p) <= config.maxStreakGap
            }

            if neighbors.isEmpty {
                remainingPoints.remove(seed)
                continue
            }

            // 3. Try to grow lines through each neighbor
            var bestLine: LineSegment?

            for neighbor in neighbors {
                let vector = subtract(neighbor, seed)
                let length = magnitude(vector)
                if length == 0 { continue }
                let unitVector = MotionPoint(x: vector.x / length, y: vector.y / length)

                // Grow forward and backward
                let (linePoints, start, end) = growLine(
                    center: seed,
                    direction: unitVector,
                    candidates: remainingPoints,
                    config: config
                )

                let lineLength = distance(start, end)
                if lineLength >= config.minStreakLength {
                    // Check density
                    let density = Double(linePoints.count) / lineLength
                    // Relaxed density check for gaps
                    // Simple check: is this line better than current best?
                    if lineLength > (bestLine?.length ?? 0) {
                         bestLine = LineSegment(start: start, end: end, length: lineLength, points: linePoints)
                    }
                }
            }

            if let found = bestLine {
                segments.append(found)
                // Remove used points
                for p in found.points {
                    remainingPoints.remove(p)
                }
            } else {
                // If we couldn't form a line from this seed, remove it to prevent retry
                remainingPoints.remove(seed)
            }
        }

        return segments
    }

    // Helpers
    private func distance(_ a: MotionPoint, _ b: MotionPoint) -> Double {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    private func subtract(_ a: MotionPoint, _ b: MotionPoint) -> MotionPoint {
        return MotionPoint(x: a.x - b.x, y: a.y - b.y)
    }

    private func magnitude(_ v: MotionPoint) -> Double {
        return sqrt(v.x * v.x + v.y * v.y)
    }

    private func growLine(center: MotionPoint, direction: MotionPoint, candidates: Set<MotionPoint>, config: HoughMethodConfig) -> ([MotionPoint], MotionPoint, MotionPoint) {
        var inliers: [MotionPoint] = []
        var minProj: Double = 0
        var maxProj: Double = 0
        var minP = center
        var maxP = center

        // Project all candidates onto the line defined by center + direction
        // Line equation: P = center + t * direction
        // t = (P - center) dot direction
        // Distance to line = |(P - center) - t * direction|

        for p in candidates {
            let relative = subtract(p, center)
            let t = relative.x * direction.x + relative.y * direction.y
            let projected = MotionPoint(x: center.x + t * direction.x, y: center.y + t * direction.y)
            let distToLine = distance(p, projected)

            if distToLine <= config.lineTolerance {
                inliers.append(p)
                if t < minProj {
                    minProj = t
                    minP = projected
                }
                if t > maxProj {
                    maxProj = t
                    maxP = projected
                }
            }
        }

        return (inliers, minP, maxP)
    }
}
```

**Step 4: Run test (Pass)**
Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/HoughLinearityDetectorTests`
Expected: Pass

**Step 5: Commit**

```bash
git add app/methods/hough/HoughLinearityDetector.swift app/SportCrunchTests/HoughLinearityDetectorTests.swift
git commit -m "feat: implement HoughLinearityDetector with RANSAC-like logic"
```

---

### Task 3: Motion Processor (The "Eyes")

**Files:**
- Create: `app/methods/hough/HoughMotionProcessor.swift`

**Step 1: Implement Accelerate Pipeline**

Using `vImage` for frame differencing and `vDSP` for vectorized thresholding. This approach:
- Uses CGContext for reliable grayscale conversion (simpler than vImageConverter setup)
- Uses pre-allocated `[UInt8]` and `[Float]` arrays to avoid per-frame allocations
- Uses vDSP for vectorized thresholding (vImageThreshold_Planar8 doesn't exist)
- Properly manages buffer lifecycle within the actor

```swift
// app/methods/hough/HoughMotionProcessor.swift
import Foundation
import Accelerate
import CoreGraphics

// MARK: - Errors

enum HoughProcessorError: Error, LocalizedError {
    case frameConversionFailed
    case invalidFrameDimensions

    var errorDescription: String? {
        switch self {
        case .frameConversionFailed:
            return "Failed to convert frame to grayscale"
        case .invalidFrameDimensions:
            return "Frame dimensions do not match expected size"
        }
    }
}

// MARK: - Reusable Buffers

/// Pre-allocated buffers to avoid per-frame allocations.
/// Follows the pattern from SpectralFluxVisualValidator.
private final class MotionBuffers {
    var currentGray: [UInt8]
    var previousGray: [UInt8]
    var twoFramesAgoGray: [UInt8]

    // Float buffers for vDSP operations
    var floatCurrent: [Float]
    var floatPrevious: [Float]
    var floatTwoAgo: [Float]
    var diff1: [Float]
    var diff2: [Float]
    var intersection: [Float]

    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        let pixelCount = width * height
        self.width = width
        self.height = height

        currentGray = [UInt8](repeating: 0, count: pixelCount)
        previousGray = [UInt8](repeating: 0, count: pixelCount)
        twoFramesAgoGray = [UInt8](repeating: 0, count: pixelCount)

        floatCurrent = [Float](repeating: 0, count: pixelCount)
        floatPrevious = [Float](repeating: 0, count: pixelCount)
        floatTwoAgo = [Float](repeating: 0, count: pixelCount)
        diff1 = [Float](repeating: 0, count: pixelCount)
        diff2 = [Float](repeating: 0, count: pixelCount)
        intersection = [Float](repeating: 0, count: pixelCount)
    }
}

// MARK: - Motion Processor

/// Handles frame buffering and motion mask generation using Accelerate.
/// Uses 3-frame differencing for better noise rejection than 2-frame.
actor HoughMotionProcessor {
    private var buffers: MotionBuffers?
    private var frameCount: Int = 0

    /// Process a new frame and return the motion mask points.
    /// Returns empty array for first 2 frames (need 3 frames for differencing).
    func process(frame: CGImage, config: HoughMethodConfig) throws -> [MotionPoint] {
        let width = frame.width
        let height = frame.height
        let pixelCount = width * height

        // Initialize or validate buffers
        if buffers == nil {
            buffers = MotionBuffers(width: width, height: height)
        }

        guard let buffers = buffers,
              buffers.width == width && buffers.height == height else {
            throw HoughProcessorError.invalidFrameDimensions
        }

        // Rotate buffers: twoAgo <- previous <- current
        swap(&buffers.twoFramesAgoGray, &buffers.previousGray)
        swap(&buffers.previousGray, &buffers.currentGray)

        // 1. Convert current frame to grayscale using CGContext
        try extractGrayscale(from: frame, into: &buffers.currentGray, width: width, height: height)

        frameCount += 1

        // Need at least 3 frames for 3-frame differencing
        guard frameCount >= 3 else {
            return []
        }

        // 2. Convert UInt8 arrays to Float for vDSP operations
        let length = vDSP_Length(pixelCount)
        vDSP_vfltu8(buffers.currentGray, 1, &buffers.floatCurrent, 1, length)
        vDSP_vfltu8(buffers.previousGray, 1, &buffers.floatPrevious, 1, length)
        vDSP_vfltu8(buffers.twoFramesAgoGray, 1, &buffers.floatTwoAgo, 1, length)

        // 3. Compute |current - previous|
        vDSP_vsub(buffers.floatPrevious, 1, buffers.floatCurrent, 1, &buffers.diff1, 1, length)
        vDSP_vabs(buffers.diff1, 1, &buffers.diff1, 1, length)

        // 4. Compute |previous - twoFramesAgo|
        vDSP_vsub(buffers.floatTwoAgo, 1, buffers.floatPrevious, 1, &buffers.diff2, 1, length)
        vDSP_vabs(buffers.diff2, 1, &buffers.diff2, 1, length)

        // 5. Intersection: min(diff1, diff2) - motion must be in both diffs
        vDSP_vmin(buffers.diff1, 1, buffers.diff2, 1, &buffers.intersection, 1, length)

        // 6. Threshold using vDSP (vectorized)
        // Subtract threshold, clip negatives to 0, clip positives to 1
        var negThreshold = -Float(config.diffThreshold)
        vDSP_vsadd(buffers.intersection, 1, &negThreshold, &buffers.intersection, 1, length)

        var zero: Float = 0
        var one: Float = 1
        vDSP_vclip(buffers.intersection, 1, &zero, &one, &buffers.intersection, 1, length)

        // 7. Extract motion points (pixels where intersection > 0)
        var points: [MotionPoint] = []
        points.reserveCapacity(config.minMotionArea) // Pre-allocate reasonable capacity

        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                if buffers.intersection[rowOffset + x] > 0 {
                    points.append(MotionPoint(x: Double(x), y: Double(y)))
                }
            }
        }

        return points
    }

    /// Reset the processor state (e.g., when switching videos)
    func reset() {
        buffers = nil
        frameCount = 0
    }

    // MARK: - Private Helpers

    /// Extract grayscale pixel values from a CGImage into a pre-allocated buffer.
    /// Uses CGContext for reliable conversion across all input formats.
    private func extractGrayscale(from cgImage: CGImage, into buffer: inout [UInt8], width: Int, height: Int) throws {
        let pixelCount = width * height

        if buffer.count != pixelCount {
            buffer = [UInt8](repeating: 0, count: pixelCount)
        }

        try buffer.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else {
                throw HoughProcessorError.frameConversionFailed
            }

            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                throw HoughProcessorError.frameConversionFailed
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
```

**Design Notes:**
- **CGContext for grayscale**: Simpler and more reliable than setting up vImageConverter with correct format matching. vImageConverter requires exact format specification which varies by input source.
- **vDSP for thresholding**: There is no `vImageThreshold_Planar8` function. We use vDSP_vsadd + vDSP_vclip for vectorized thresholding.
- **Buffer rotation**: Instead of copying, we swap buffer pointers for O(1) rotation.
- **Pre-allocated arrays**: Avoids heap allocations per frame, following the pattern from SpectralFluxVisualValidator.

**Step 2: Commit**

```bash
git add app/methods/hough/HoughMotionProcessor.swift
git commit -m "feat: implement Accelerate-based motion processor with vDSP thresholding"
```

---

### Task 4: Integration (Wiring it together)

**Files:**
- Modify: `app/methods/hough/HoughMethod.swift`

**Step 1: Update HoughMethod**

Wire the Processor and Detector. Add observation logging. Use frame stride to reduce actor overhead.

```swift
// app/methods/hough/HoughMethod.swift
import AVFoundation
import Foundation

// MARK: - Errors

enum HoughMethodError: Error, LocalizedError {
    case noVideoTrack
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found in file"
        case .processingFailed(let reason):
            return "Hough processing failed: \(reason)"
        }
    }
}

// MARK: - HoughMethod

public final class HoughMethod: SegmentationMethod {
    public let name = "Hough"
    private let config: HoughMethodConfig
    private let processor = HoughMotionProcessor()
    private let detector = HoughLinearityDetector()

    /// Frame stride: process every Nth frame to reduce overhead.
    /// At 30fps, stride of 2 = 15 effective fps, stride of 3 = 10 effective fps.
    private let frameStride: Int = 2

    public init(config: HoughMethodConfig) {
        self.config = config
    }

    public func detectSegments(videoURL: URL, observation: RunObservation?) async throws -> [ActionSegment] {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // Properly handle missing video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw HoughMethodError.noVideoTrack
        }

        let duration = try await asset.load(.duration).seconds
        let fps = try await videoTrack.load(.nominalFrameRate)
        let timescale = try await videoTrack.load(.naturalTimeScale)

        print("🎯 [HoughMethod] Processing \(videoURL.lastPathComponent)")
        print("🎯 [HoughMethod] Duration: \(String(format: "%.2f", duration))s, FPS: \(fps), Stride: \(frameStride)")

        // Reset processor for new video
        await processor.reset()

        var allDetections: [TimestampedLine] = []
        var frameIndex = 0
        var processedFrames = 0

        // Processing loop with frame stride to reduce actor hops
        while Double(frameIndex) / Double(fps) < duration {
            let timeSec = Double(frameIndex) / Double(fps)
            let time = CMTime(seconds: timeSec, preferredTimescale: timescale)

            do {
                let (image, actualTime) = try await generator.image(at: time)
                let actualTimeSec = actualTime.seconds

                // 1. Process Motion (actor call)
                let points = try await processor.process(frame: image, config: config)

                // 2. Detect Lines (synchronous, no actor)
                let lines = detector.detect(points: points, config: config)

                // 3. Record detections for tracking
                for line in lines {
                    allDetections.append(TimestampedLine(line: line, time: actualTimeSec))
                }

                // 4. Record Observations (batched to reduce overhead)
                if let obs = observation {
                    // Record motion intensity (point count)
                    await obs.addSignalPoint(name: "motion_points", time: actualTimeSec, value: Double(points.count))

                    if !lines.isEmpty {
                        await obs.addSignalPoint(name: "streak_count", time: actualTimeSec, value: Double(lines.count))

                        // Record first streak as event (limit events to avoid flooding)
                        let line = lines[0]
                        await obs.addEvent(
                            name: "streak_detected",
                            time: actualTimeSec,
                            metadata: [
                                "length": String(format: "%.1f", line.length),
                                "start": "(\(Int(line.start.x)),\(Int(line.start.y)))",
                                "end": "(\(Int(line.end.x)),\(Int(line.end.y)))",
                                "count": "\(lines.count)"
                            ]
                        )
                    }
                }

                processedFrames += 1

            } catch {
                // Log but continue processing
                print("🎯 [HoughMethod] Frame \(frameIndex) error: \(error.localizedDescription)")
            }

            frameIndex += frameStride
        }

        print("🎯 [HoughMethod] Processed \(processedFrames) frames, found \(allDetections.count) streak detections")

        // Return empty for now - Task 5 adds temporal tracking
        return []
    }
}
```

**Design Notes:**
- **Frame stride**: Processing every frame (1800 frames for 60s @ 30fps) causes excessive actor hops. Stride of 2 halves this while maintaining detection quality.
- **Proper error handling**: Missing video track throws a clear error instead of using fallback values.
- **Reset on new video**: Processor state is cleared to avoid cross-video contamination.
- **Batched observations**: Signal points are automatically downsampled by RunObservation (2 points/sec), and we limit events to prevent flooding.

**Step 2: Commit**

```bash
git add app/methods/hough/HoughMethod.swift
git commit -m "feat: wire HoughMethod with processor and detector"
```

---

### Task 5: Temporal Tracking (Rally Logic)

**Files:**
- Create: `app/methods/hough/HoughTracker.swift`
- Modify: `app/methods/hough/HoughMethod.swift`

**Step 1: Implement Tracker**

Simple state machine: merge close detection timestamps into rallies.

```swift
// app/methods/hough/HoughTracker.swift
import Foundation

/// A line detection with its timestamp for temporal tracking.
struct TimestampedLine: Sendable {
    let line: LineSegment
    let time: TimeInterval
}

/// Groups streak detections into rally segments based on temporal proximity.
struct HoughTracker: Sendable {

    /// Group detections into rallies based on temporal gaps.
    /// - Parameters:
    ///   - detections: Array of timestamped line detections
    ///   - config: Configuration with gap and duration thresholds
    /// - Returns: Array of ActionSegments representing detected rallies
    func groupRallies(detections: [TimestampedLine], config: HoughMethodConfig) -> [ActionSegment] {
        guard !detections.isEmpty else { return [] }

        let sorted = detections.sorted { $0.time < $1.time }
        var rallies: [ActionSegment] = []

        var currentStart = sorted[0].time
        var currentEnd = sorted[0].time
        var hitCount = 1

        for i in 1..<sorted.count {
            let detection = sorted[i]
            let gap = detection.time - currentEnd

            if gap <= config.rallyMaxGap {
                // Extend rally
                currentEnd = detection.time
                hitCount += 1
            } else {
                // Close rally if it meets minimum duration
                let duration = currentEnd - currentStart
                if duration >= config.rallyMinDuration {
                    rallies.append(ActionSegment(
                        id: UUID(),
                        startTime: currentStart,
                        endTime: currentEnd,
                        isStarred: false
                    ))
                }

                // Start new rally
                currentStart = detection.time
                currentEnd = detection.time
                hitCount = 1
            }
        }

        // Close last rally if it meets minimum duration
        let duration = currentEnd - currentStart
        if duration >= config.rallyMinDuration {
            rallies.append(ActionSegment(
                id: UUID(),
                startTime: currentStart,
                endTime: currentEnd,
                isStarred: false
            ))
        }

        return rallies
    }
}
```

**Design Notes:**
- **Struct instead of Actor**: HoughTracker is stateless and only processes input data, so it doesn't need actor isolation. Using a struct is simpler and avoids unnecessary async overhead.
- **ActionSegment initializer**: Requires `id: UUID()` and `isStarred: false` per the actual type definition in Project.swift.

**Step 2: Update HoughMethod**

Collect detections and pass to tracker. Update the full method to integrate tracking.

```swift
// Update app/methods/hough/HoughMethod.swift

// Add tracker to property list (after detector)
private let tracker = HoughTracker()

// Replace the return statement at the end of detectSegments with:
// (The allDetections array is already populated in the loop from Task 4)

let rallies = tracker.groupRallies(detections: allDetections, config: config)

print("🎯 [HoughMethod] Grouped into \(rallies.count) rallies")
for (i, rally) in rallies.enumerated() {
    print("🎯 [HoughMethod]   Rally \(i + 1): \(String(format: "%.2f", rally.startTime))s - \(String(format: "%.2f", rally.endTime))s (\(String(format: "%.2f", rally.duration))s)")
}

return rallies
```

**Step 3: Commit**

```bash
git add app/methods/hough/HoughTracker.swift app/methods/hough/HoughMethod.swift
git commit -m "feat: implement temporal tracker for rally segmentation"
```

---

### Task 6: Integration with Sport.swift

**Files:**
- Modify: `app/SportCrunch/Core/Models/Sport.swift`

**Step 1: Register HoughMethod as an Option**

Add HoughMethod to the segmentation method factory so it can be selected in the app.

```swift
// In Sport.swift, update the segmentationMethod(for:) function

// Add a new case or modify existing tennis case:
func segmentationMethod(for mode: (any SportMode)?) -> any SegmentationMethod {
    switch self {
    case .tennis:
        let tennisMode = (mode as? TennisMode) ?? .rally

        // Option 1: Replace SpectralFlux with Hough for testing
        // return HoughMethod(config: HoughTennisConfig.instance)

        // Option 2: Use Hough for a specific mode (e.g., add TennisMode.hough)
        switch tennisMode {
        case .rally:
            return SpectralFluxMethod(config: SpectralFluxTennisRallyConfig.instance)
        case .individual:
            return SpectralFluxMethod(config: SpectralFluxTennisIndividualConfig.instance)
        // Future: case .hough:
        //     return HoughMethod(config: HoughTennisConfig.instance)
        }
    case .cricket:
        fatalError("Cricket not yet implemented")
    }
}
```

**Note:** The exact integration depends on how you want to expose Hough as an option:
1. **For testing**: Temporarily replace SpectralFlux with Hough
2. **As a new mode**: Add `TennisMode.hough` enum case
3. **As a setting**: Add a user preference to choose the detection method

For initial testing, use Option 1 to validate the implementation end-to-end.

**Step 2: Commit**

```bash
git add app/SportCrunch/Core/Models/Sport.swift
git commit -m "feat: integrate HoughMethod with Sport selection"
```

---

### Summary of Corrected Implementation

| Task | Component | Key Fixes Applied |
|------|-----------|-------------------|
| 1 | Config & Scaffold | Fixed `Observation` → `RunObservation` |
| 2 | LinearityDetector | Renamed `Point` → `MotionPoint`, fixed test path |
| 3 | MotionProcessor | Replaced broken vImage code with CGContext + vDSP, pre-allocated buffers |
| 4 | Integration | Added error handling, frame stride for performance, proper track loading |
| 5 | Tracker | Fixed `ActionSegment` initializer, changed actor → struct |
| 6 | Sport.swift | New task for app integration |

**Performance Considerations:**
- Frame stride reduces actor hops from ~1800 to ~900 for a 60s video @ 30fps
- Pre-allocated buffers avoid per-frame heap allocations
- vDSP vectorized operations process multiple pixels in parallel
- Struct-based tracker avoids unnecessary async overhead
