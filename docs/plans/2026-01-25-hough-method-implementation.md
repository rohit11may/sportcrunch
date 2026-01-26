# Hough Method Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the "Hough Method" for tennis ball tracking using a custom Swift linearity detector and Accelerate-based motion processing, adhering to the "training-free" physics-based architecture.

**Architecture:**
1.  **MotionProcessor:** Uses `Accelerate` (vImage) for 3-frame differencing and morphological cleanup to produce a binary motion mask.
2.  **LinearityDetector:** A custom, pure-Swift algorithm (RANSAC-inspired) to detect linear streaks in the motion mask, robust to gaps.
3.  **HoughMethod:** The method actor that coordinates the pipeline and outputs `ActionSegment`s.
4.  **Observation:** Fully instrumented to visualize the intermediate masks and detected lines in the Lab view.

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

    public func detectSegments(videoURL: URL, observation: Observation?) async throws -> [ActionSegment] {
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
- Create: `app/SportCrunchTests/Methods/HoughLinearityDetectorTests.swift`

**Step 1: Write Test for Simple Horizontal Line**

We need to test that our detector finds a simple line in a point cloud.

```swift
// app/SportCrunchTests/Methods/HoughLinearityDetectorTests.swift
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
        var points: [Point] = []
        for x in stride(from: 0, through: 20, by: 2) {
            points.append(Point(x: Double(x), y: 10))
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

public struct Point: Hashable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct LineSegment: Sendable {
    public let start: Point
    public let end: Point
    public let length: Double
    public let points: [Point]
}

public struct HoughLinearityDetector: Sendable {
    public init() {}

    public func detect(points: [Point], config: HoughMethodConfig) -> [LineSegment] {
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
                let unitVector = Point(x: vector.x / length, y: vector.y / length)

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
    private func distance(_ a: Point, _ b: Point) -> Double {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    private func subtract(_ a: Point, _ b: Point) -> Point {
        return Point(x: a.x - b.x, y: a.y - b.y)
    }

    private func magnitude(_ v: Point) -> Double {
        return sqrt(v.x * v.x + v.y * v.y)
    }

    private func growLine(center: Point, direction: Point, candidates: Set<Point>, config: HoughMethodConfig) -> ([Point], Point, Point) {
        var inliers: [Point] = []
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
            let projected = Point(x: center.x + t * direction.x, y: center.y + t * direction.y)
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
git add app/methods/hough/HoughLinearityDetector.swift app/SportCrunchTests/Methods/HoughLinearityDetectorTests.swift
git commit -m "feat: implement HoughLinearityDetector with RANSAC-like logic"
```

---

### Task 3: Motion Processor (The "Eyes")

**Files:**
- Create: `app/methods/hough/HoughMotionProcessor.swift`
- Modify: `app/methods/hough/HoughMethod.swift` (Wiring)

**Step 1: Implement Accelerate Pipeline**

Using `vImage` for efficient difference and morphology.

```swift
// app/methods/hough/HoughMotionProcessor.swift
import Foundation
import Accelerate
import CoreGraphics

/// Handles frame buffering and motion mask generation using Accelerate
actor HoughMotionProcessor {
    private var previousFrame: vImage_Buffer?
    private var twoFramesAgo: vImage_Buffer?

    deinit {
        // Cleanup buffers
        previousFrame?.free()
        twoFramesAgo?.free()
    }

    /// Process a new frame and return the motion mask points
    func process(frame: CGImage, config: HoughMethodConfig) throws -> [Point] {
        var currentBuffer = try vImage_Buffer(cgImage: frame)
        defer { currentBuffer.free() } // We only need it for this step, or copy it

        // 1. Convert to Grayscale (8-bit)
        // Note: Ideally we keep persistent buffers to avoid allocs, but for V1 simplify.
        var grayBuffer = try vImage_Buffer(width: Int(currentBuffer.width), height: Int(currentBuffer.height), bitsPerPixel: 8)

        // Create a temporary format for the source (assuming RGBA/BGRA)
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        try vImageConvert_AnyToAny(
            &currentBuffer,
            &grayBuffer,
            nil,
            &format,
            nil,
            vImage_Flags(kvImageNoFlags)
        )

        // Store copy for history
        var currentCopy = try vImage_Buffer(width: Int(grayBuffer.width), height: Int(grayBuffer.height), bitsPerPixel: 8)
        try vImageCopyBuffer(&grayBuffer, &currentCopy, 4, vImage_Flags(kvImageNoFlags))

        // 2. Three-Frame Difference
        guard let prev = previousFrame, let prev2 = twoFramesAgo else {
            // Shift buffers and return empty
            twoFramesAgo?.free()
            twoFramesAgo = previousFrame
            previousFrame = currentCopy
            grayBuffer.free()
            return []
        }

        // Diff 1: |Curr - Prev|
        var diff1 = try vImage_Buffer(width: Int(grayBuffer.width), height: Int(grayBuffer.height), bitsPerPixel: 8)
        // Diff 2: |Prev - Prev2|
        var diff2 = try vImage_Buffer(width: Int(grayBuffer.width), height: Int(grayBuffer.height), bitsPerPixel: 8)
        // Result: Intersection
        var intersection = try vImage_Buffer(width: Int(grayBuffer.width), height: Int(grayBuffer.height), bitsPerPixel: 8)

        defer {
            diff1.free()
            diff2.free()
            intersection.free()
            grayBuffer.free()
        }

        // AbsDiff
        vImageAbsDiff_Planar8(&grayBuffer, &prev, &diff1, vImage_Flags(kvImageNoFlags))
        vImageAbsDiff_Planar8(&prev, &prev2, &diff2, vImage_Flags(kvImageNoFlags))

        // Min (Intersection logic: AND equivalent for grayscale)
        vImageMin_Planar8(&diff1, &diff2, &intersection, vImage_Flags(kvImageNoFlags))

        // 3. Threshold
        // Using kvImageCompareGreaterThan: Sets to 255 if > threshold, else 0
        // But vImage doesn't have a simple "Threshold" in one go for arbitrary value easily exposed in Swift without boilerplate.
        // Easier: vImageContrastStretch or lookup table?
        // Actually: vImageThreshold_Planar8 is available!
        // Wait, standard vImageThreshold is strictly "pixel > T ? 255 : 0"
        try vImageThreshold_Planar8(
            &intersection,
            &intersection,
            Pixel_8(config.diffThreshold),
            255,
            vImage_Flags(kvImageNoFlags)
        )

        // 4. Extract Points
        // Iterate output buffer to find non-zero pixels
        var points: [Point] = []
        let width = Int(intersection.width)
        let height = Int(intersection.height)
        let rowBytes = intersection.rowBytes
        let data = intersection.data.assumingMemoryBound(to: UInt8.self)

        // Optimization: Use stride
        for y in 0..<height {
            let row = data.advanced(by: y * rowBytes)
            for x in 0..<width {
                if row[x] > 0 {
                    points.append(Point(x: Double(x), y: Double(y)))
                }
            }
        }

        // Shift history
        twoFramesAgo?.free()
        twoFramesAgo = previousFrame
        previousFrame = currentCopy

        return points
    }
}

// Helpers extensions for vImage ease of use
extension vImage_Buffer {
    init(cgImage: CGImage) throws {
        var format = vImage_CGImageFormat(
            bitsPerComponent: UInt32(cgImage.bitsPerComponent),
            bitsPerPixel: UInt32(cgImage.bitsPerPixel),
            colorSpace: cgImage.colorSpace!,
            bitmapInfo: cgImage.bitmapInfo,
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
        self.init()
        try vImageBuffer_InitWithCGImage(&self, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
    }

    init(width: Int, height: Int, bitsPerPixel: UInt32) throws {
        self.init()
        try vImageBuffer_Init(&self, vImagePixelCount(height), vImagePixelCount(width), bitsPerPixel, vImage_Flags(kvImageNoFlags))
    }
}
```

**Step 2: Commit**

```bash
git add app/methods/hough/HoughMotionProcessor.swift
git commit -m "feat: implement Accelerate-based motion processor"
```

---

### Task 4: Integration (Wiring it together)

**Files:**
- Modify: `app/methods/hough/HoughMethod.swift`
- Test: `app/SportCrunchTests/Methods/HoughMethodTests.swift`

**Step 1: Update HoughMethod**

Wire the Processor and Detector. Add observation logging.

```swift
// app/methods/hough/HoughMethod.swift
import AVFoundation

public final class HoughMethod: SegmentationMethod {
    // ... config init ...
    private let processor = HoughMotionProcessor()
    private let detector = HoughLinearityDetector()

    public func detectSegments(videoURL: URL, observation: Observation?) async throws -> [ActionSegment] {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let duration = try await asset.load(.duration).seconds
        let fps = try await asset.loadTracks(withMediaType: .video).first?.load(.nominalFrameRate) ?? 30.0

        var detectedSegments: [LineSegment] = [] // Store temporarily
        var frameIndex = 0

        // Processing Loop (Sequential for now)
        // In real app, batch this using the async generator pattern from VisualValidator
        // For V1, simple loop is safer to verify logic.
        while Double(frameIndex) / Double(fps) < duration {
            let time = CMTime(seconds: Double(frameIndex) / Double(fps), preferredTimescale: 600)

            do {
                let (image, actualTime) = try await generator.image(at: time)
                let timeSec = actualTime.seconds

                // 1. Process Motion
                let points = try await processor.process(frame: image, config: config)

                // 2. Detect Lines
                let lines = detector.detect(points: points, config: config)

                // 3. Record Observations
                if let obs = observation, !lines.isEmpty {
                    await obs.addSignalPoint(name: "streak_count", time: timeSec, value: Double(lines.count))
                    for line in lines {
                        await obs.addEvent(
                            name: "streak_detected",
                            time: timeSec,
                            metadata: [
                                "length": "\(line.length)",
                                "start": "(\(Int(line.start.x)),\(Int(line.start.y)))",
                                "end": "(\(Int(line.end.x)),\(Int(line.end.y)))"
                            ]
                        )
                    }
                }

                // TODO: Store line with timestamp for tracking
            } catch {
                print("Error frame \(frameIndex): \(error)")
            }

            frameIndex += 1
        }

        return [] // Returning empty for now, next task adds tracking
    }
}
```

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

struct TimestampedLine: Sendable {
    let line: LineSegment
    let time: TimeInterval
}

actor HoughTracker {
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
                // Close rally
                let duration = currentEnd - currentStart
                if duration >= config.rallyMinDuration {
                    rallies.append(ActionSegment(startTime: currentStart, endTime: currentEnd))
                }

                // Start new
                currentStart = detection.time
                currentEnd = detection.time
                hitCount = 1
            }
        }

        // Close last
        let duration = currentEnd - currentStart
        if duration >= config.rallyMinDuration {
            rallies.append(ActionSegment(startTime: currentStart, endTime: currentEnd))
        }

        return rallies
    }
}
```

**Step 2: Update HoughMethod**

Collect detections and pass to tracker.

```swift
// Update HoughMethod.swift

// In property list
private let tracker = HoughTracker()

// In detectSegments
var allDetections: [TimestampedLine] = []

// Inside loop, after detecting lines:
for line in lines {
    allDetections.append(TimestampedLine(line: line, time: timeSec))
}

// At end of method:
let rallies = await tracker.groupRallies(detections: allDetections, config: config)
return rallies
```

**Step 3: Commit**

```bash
git add app/methods/hough/HoughTracker.swift app/methods/hough/HoughMethod.swift
git commit -m "feat: implement temporal tracker for rally segmentation"
```
