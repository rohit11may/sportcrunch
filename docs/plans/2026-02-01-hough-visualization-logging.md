# Hough Visualization Logging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add detailed intermediate visualization logging for the Hough method to enable algorithm validation across all three pipeline stages.

**Architecture:** Extend existing RunObservation logging in HoughMethod with new signals and events. Add HoughDebugRenderer to capture annotated frames with motion points and detected streaks. Modify HoughTracker to emit rally lifecycle events.

**Tech Stack:** Swift, Core Graphics, CVPixelBuffer, RunObservation actor

---

## Task 1: Add HoughDebugRenderer

**Files:**
- Create: `app/methods/hough/HoughDebugRenderer.swift`

**Step 1: Create the debug renderer class**

```swift
//
//  HoughDebugRenderer.swift
//  SportCrunch
//
//  Renders debug overlay frames with motion points and detected line streaks.
//

import CoreGraphics
import CoreVideo
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Renders debug overlay frames showing motion points and detected line streaks.
/// Used for algorithm validation and debugging.
final class HoughDebugRenderer {

    /// Maximum motion points to render (downsample if exceeded for performance).
    private let maxRenderPoints = 5000

    /// Render an annotated debug frame.
    /// - Parameters:
    ///   - pixelBuffer: The source video frame (Y'CbCr or BGRA)
    ///   - motionPoints: Detected motion pixel locations
    ///   - lines: Detected line streaks
    /// - Returns: JPEG data of the annotated frame, or nil on failure
    func render(
        pixelBuffer: CVPixelBuffer,
        motionPoints: [MotionPoint],
        lines: [LineSegment]
    ) -> Data? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Create CGImage from pixel buffer
        guard let baseImage = createCGImage(from: pixelBuffer) else {
            return nil
        }

        // Create drawing context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw base frame
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Downsample motion points if needed
        let pointsToRender: [MotionPoint]
        if motionPoints.count > maxRenderPoints {
            let step = motionPoints.count / maxRenderPoints
            pointsToRender = stride(from: 0, to: motionPoints.count, by: step)
                .prefix(maxRenderPoints)
                .map { motionPoints[$0] }
        } else {
            pointsToRender = motionPoints
        }

        // Draw motion points as green dots (3px, 50% opacity)
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 0.5))
        for point in pointsToRender {
            let rect = CGRect(
                x: point.x - 1.5,
                y: Double(height) - point.y - 1.5,  // Flip Y for Core Graphics
                width: 3,
                height: 3
            )
            context.fillEllipse(in: rect)
        }

        // Draw line streaks as red lines (2px) with endpoint markers
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1.0))
        context.setLineWidth(2.0)

        for line in lines {
            // Draw line
            context.move(to: CGPoint(x: line.start.x, y: Double(height) - line.start.y))
            context.addLine(to: CGPoint(x: line.end.x, y: Double(height) - line.end.y))
            context.strokePath()

            // Draw endpoint markers (small circles)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1.0))
            let startRect = CGRect(
                x: line.start.x - 3,
                y: Double(height) - line.start.y - 3,
                width: 6,
                height: 6
            )
            let endRect = CGRect(
                x: line.end.x - 3,
                y: Double(height) - line.end.y - 3,
                width: 6,
                height: 6
            )
            context.fillEllipse(in: startRect)
            context.fillEllipse(in: endRect)
        }

        // Create final image
        guard let outputImage = context.makeImage() else {
            return nil
        }

        // Convert to JPEG
        #if canImport(UIKit)
        let uiImage = UIImage(cgImage: outputImage)
        return uiImage.jpegData(compressionQuality: 0.7)
        #else
        // macOS fallback
        let bitmapRep = NSBitmapImageRep(cgImage: outputImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        #endif
    }

    /// Create CGImage from CVPixelBuffer.
    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
```

**Step 2: Verify the file compiles**

Run:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add app/methods/hough/HoughDebugRenderer.swift
git commit -m "feat(hough): add HoughDebugRenderer for debug overlay frames

Renders motion points as green dots and line streaks as red lines
on video frames for algorithm validation.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Extend HoughLinearityDetector to Return Linearity Score

**Files:**
- Modify: `app/methods/hough/HoughLinearityDetector.swift`

**Step 1: Add LineDetectionResult struct and update detect method**

Add after `LineSegment` struct (around line 27):

```swift
/// Result of line detection including quality metrics.
struct LineDetectionResult: Sendable {
    let lines: [LineSegment]
    /// Ratio of points that fall on detected lines vs total points (0.0-1.0).
    let linearityScore: Double
}
```

Update the `detect` method signature and implementation. Replace the entire `detect` method:

```swift
func detect(points: [MotionPoint], config: HoughMethodConfig) -> LineDetectionResult {
    guard !points.isEmpty else {
        return LineDetectionResult(lines: [], linearityScore: 0)
    }

    // Build spatial hash grid for O(1) neighbor lookups
    var grid = SpatialHashGrid(points: points, cellSize: config.maxStreakGap)
    var segments: [LineSegment] = []
    var totalPointsOnLines = 0

    // Pre-compute squared thresholds to avoid sqrt in hot paths
    let maxStreakGapSquared = config.maxStreakGap * config.maxStreakGap
    let lineToleranceSquared = config.lineTolerance * config.lineTolerance

    // Max iterations to avoid infinite loops
    var iterations = 0
    let maxIterations = points.count * 2

    while !grid.isEmpty && iterations < maxIterations {
        iterations += 1
        // 1. Pick a random seed point
        guard let seed = grid.randomElement() else { break }

        // 2. Find local neighborhood using spatial hash (O(1) average case)
        let neighbors = grid.neighbors(of: seed, maxDistanceSquared: maxStreakGapSquared)

        if neighbors.isEmpty {
            grid.remove(seed)
            continue
        }

        // 3. Try to grow lines through each neighbor
        var bestLine: LineSegment?

        for neighbor in neighbors {
            let vectorSimd = neighbor.simd - seed.simd
            let lengthSquared = simd_length_squared(vectorSimd)
            if lengthSquared == 0 { continue }
            let direction = simd_normalize(vectorSimd)

            // Grow forward and backward
            let (linePoints, start, end) = growLine(
                center: seed,
                direction: direction,
                candidates: grid.remainingPoints,
                lineToleranceSquared: lineToleranceSquared
            )

            let lineLength = distance(start, end)
            if lineLength >= config.minStreakLength {
                // Check density
                // Relaxed density check for gaps
                // Simple check: is this line better than current best?
                if lineLength > (bestLine?.length ?? 0) {
                     bestLine = LineSegment(start: start, end: end, length: lineLength, points: linePoints)
                }
            }
        }

        if let found = bestLine {
            segments.append(found)
            totalPointsOnLines += found.points.count
            // Remove used points from spatial grid
            for p in found.points {
                grid.remove(p)
            }
        } else {
            // If we couldn't form a line from this seed, remove it to prevent retry
            grid.remove(seed)
        }
    }

    let linearityScore = points.isEmpty ? 0 : Double(totalPointsOnLines) / Double(points.count)
    return LineDetectionResult(lines: segments, linearityScore: linearityScore)
}
```

**Step 2: Verify the file compiles**

Run:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -30
```

Expected: Build errors in HoughMethod.swift and HoughLinearityDetectorGPU.swift (they call `detect` expecting `[LineSegment]` but now get `LineDetectionResult`). This is expected and will be fixed in Task 3.

**Step 3: Commit (with build broken - will fix in next task)**

```bash
git add app/methods/hough/HoughLinearityDetector.swift
git commit -m "feat(hough): add LineDetectionResult with linearity score

Breaking change: detect() now returns LineDetectionResult instead of [LineSegment].
Callers need to access .lines property. Will be fixed in next commit.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Update GPU Detector to Match CPU Interface

**Files:**
- Modify: `app/methods/hough/HoughLinearityDetectorGPU.swift`

**Step 1: Find and update the GPU detector's detect method**

First, read the file to understand its current structure, then update the return type to match CPU detector.

The GPU detector's `detect` method should return `LineDetectionResult`. Since the GPU detector converts to `LineSegment` from internal types, wrap the result:

```swift
func detect(
    points: [MotionPoint],
    config: HoughMethodConfig,
    imageWidth: Int,
    imageHeight: Int
) throws -> LineDetectionResult {
    // ... existing implementation up to where lines are returned ...

    // Instead of: return lines
    // Calculate linearity score
    let totalPointsOnLines = lines.reduce(0) { $0 + $1.points.count }
    let linearityScore = points.isEmpty ? 0 : Double(totalPointsOnLines) / Double(points.count)
    return LineDetectionResult(lines: lines, linearityScore: linearityScore)
}
```

**Step 2: Verify the file compiles**

Run:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -30
```

Expected: Still build errors in HoughMethod.swift (will fix in Task 4).

**Step 3: Commit**

```bash
git add app/methods/hough/HoughLinearityDetectorGPU.swift
git commit -m "feat(hough): update GPU detector to return LineDetectionResult

Matches CPU detector interface with linearity score calculation.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Update HoughMethod to Use New Detection Result and Add New Signals

**Files:**
- Modify: `app/methods/hough/HoughMethod.swift`

**Step 1: Add debug renderer property and artifact tracking**

Add after line 46 (after `private let tracker = HoughTracker()`):

```swift
private let debugRenderer = HoughDebugRenderer()
private var lastArtifactTime: TimeInterval = -1.0
private var lastDetectionTime: TimeInterval = -1.0

/// Temporary artifact files (artifact ID -> file URL).
/// Stored here so RunExecutor can access them for export.
private(set) var tempArtifactPaths: [String: URL] = [:]
```

**Step 2: Update detection calls to use LineDetectionResult**

In the `processFrames` closure, update the detection code (around lines 145-168).

Replace:
```swift
let lines: [LineSegment]

// Get dimensions from pixel buffer (plane 0 for Y-channel)
let width = CVPixelBufferGetWidthOfPlane(frame.pixelBuffer, 0)
let height = CVPixelBufferGetHeightOfPlane(frame.pixelBuffer, 0)

if useGPU, let gpuDetector = gpuDetector {
    do {
        lines = try gpuDetector.detect(
            points: points,
            config: config,
            imageWidth: width,
            imageHeight: height
        )
    } catch {
        // GPU failed, fall back to CPU
        print("⚙️ [HoughMethod] ⚠️ GPU detection failed, using CPU: \(error.localizedDescription)")
        lines = cpuDetector.detect(points: points, config: config)
    }
} else {
    lines = cpuDetector.detect(points: points, config: config)
}
```

With:
```swift
let detectionResult: LineDetectionResult

// Get dimensions from pixel buffer (plane 0 for Y-channel)
let width = CVPixelBufferGetWidthOfPlane(frame.pixelBuffer, 0)
let height = CVPixelBufferGetHeightOfPlane(frame.pixelBuffer, 0)

if useGPU, let gpuDetector = gpuDetector {
    do {
        detectionResult = try gpuDetector.detect(
            points: points,
            config: config,
            imageWidth: width,
            imageHeight: height
        )
    } catch {
        // GPU failed, fall back to CPU
        print("⚙️ [HoughMethod] ⚠️ GPU detection failed, using CPU: \(error.localizedDescription)")
        detectionResult = cpuDetector.detect(points: points, config: config)
    }
} else {
    detectionResult = cpuDetector.detect(points: points, config: config)
}

let lines = detectionResult.lines
```

**Step 3: Update observation logging with new signals and artifacts**

Replace the observation logging block (lines 183-203) with:

```swift
// 4. Record Observations (only if observation exists)
if let obs = observation {
    // Stage 1: Motion signals
    await obs.addSignalPoint(name: "motion_points", time: frame.time, value: Double(rawPoints.count))
    let frameArea = Double(width * height)
    let motionAreaRatio = frameArea > 0 ? Double(rawPoints.count) / frameArea : 0
    await obs.addSignalPoint(name: "motion_area_ratio", time: frame.time, value: motionAreaRatio)

    // Stage 2: Linearity signals
    if !lines.isEmpty {
        await obs.addSignalPoint(name: "streak_count", time: frame.time, value: Double(lines.count))
        let maxLength = lines.map { $0.length }.max() ?? 0
        await obs.addSignalPoint(name: "streak_max_length", time: frame.time, value: maxLength)
        await obs.addSignalPoint(name: "linearity_score", time: frame.time, value: detectionResult.linearityScore)

        // Record first streak as event (limit to reduce overhead)
        let line = lines[0]
        await obs.addEvent(
            name: "streak_detected",
            time: frame.time,
            metadata: [
                "length": String(format: "%.1f", line.length),
                "start": "(\(Int(line.start.x)),\(Int(line.start.y)))",
                "end": "(\(Int(line.end.x)),\(Int(line.end.y)))",
                "count": "\(lines.count)"
            ]
        )

        // Track last detection time for artifact capture
        self.lastDetectionTime = frame.time
    }

    // Stage 2: Debug artifact capture (1 per second during active detection)
    let timeSinceLastArtifact = frame.time - self.lastArtifactTime
    let timeSinceLastDetection = frame.time - self.lastDetectionTime
    let isActiveDetection = !lines.isEmpty || timeSinceLastDetection <= 1.0

    if isActiveDetection && timeSinceLastArtifact >= 1.0 {
        // Convert rawPoints to MotionPoint array for renderer
        if let jpegData = self.debugRenderer.render(
            pixelBuffer: frame.pixelBuffer,
            motionPoints: rawPoints,
            lines: lines
        ) {
            let artifactId = "hough_debug_\(Int(frame.time * 1000))"
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent("\(artifactId).jpg")

            do {
                try jpegData.write(to: tempURL)
                self.tempArtifactPaths[artifactId] = tempURL
                self.lastArtifactTime = frame.time

                await obs.addEvent(
                    name: "hough_debug_frame",
                    time: frame.time,
                    metadata: [
                        "motion_points": "\(rawPoints.count)",
                        "streak_count": "\(lines.count)",
                        "max_streak_length": String(format: "%.1f", lines.map { $0.length }.max() ?? 0)
                    ],
                    artifactId: artifactId
                )
            } catch {
                print("⚙️ [HoughMethod] ⚠️ Failed to save debug artifact: \(error.localizedDescription)")
            }
        }
    }
}
```

**Step 4: Update line counting reference**

Find `totalLines += lines.count` and ensure it still works (it should, since `lines` is extracted from `detectionResult.lines`).

**Step 5: Verify the file compiles**

Run:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add app/methods/hough/HoughMethod.swift
git commit -m "feat(hough): add comprehensive observation logging and debug artifacts

- Add motion_area_ratio signal (Stage 1)
- Add streak_max_length and linearity_score signals (Stage 2)
- Add hough_debug_frame events with annotated frame artifacts
- Capture debug frames at 1/sec during active detection periods

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Rally Lifecycle Events to HoughTracker

**Files:**
- Modify: `app/methods/hough/HoughTracker.swift`

**Step 1: Update groupRallies to accept observation and emit events**

Replace the entire `HoughTracker` struct with:

```swift
//
//  HoughTracker.swift
//  SportCrunch
//
//  Groups streak detections into segments based on temporal proximity.
//

import Foundation

/// Groups streak detections into segments based on temporal proximity.
struct HoughTracker: Sendable {

    /// Group detections into segments based on the configured grouping mode.
    /// - Parameters:
    ///   - detections: Array of timestamped line detections
    ///   - config: Configuration with gap, duration, and grouping mode settings
    ///   - observation: Optional observation recorder for telemetry
    /// - Returns: Array of ActionSegments representing detected segments
    func groupRallies(
        detections: [TimestampedLine],
        config: HoughMethodConfig,
        observation: RunObservation? = nil
    ) async -> [ActionSegment] {
        switch config.groupingMode {
        case .rally:
            return await groupAsRallies(detections: detections, config: config, observation: observation)
        case .individual:
            return await groupAsIndividualShots(detections: detections, config: config, observation: observation)
        }
    }

    /// Group detections into rallies - continuous segments within rallyMaxGap.
    private func groupAsRallies(
        detections: [TimestampedLine],
        config: HoughMethodConfig,
        observation: RunObservation?
    ) async -> [ActionSegment] {
        guard !detections.isEmpty else { return [] }

        let sorted = detections.sorted { $0.time < $1.time }
        var rallies: [ActionSegment] = []

        var currentStart = sorted[0].time
        var currentEnd = sorted[0].time
        var currentDetectionCount = 1
        var lastDetectionTime = sorted[0].time

        // Log rally opened for first detection
        if let obs = observation {
            await obs.addEvent(
                name: "rally_opened",
                time: currentStart,
                metadata: ["start_time": String(format: "%.3f", currentStart)]
            )
            await obs.addSignalPoint(name: "rally_active", time: currentStart, value: 1.0)
        }

        for i in 1..<sorted.count {
            let detection = sorted[i]
            let gap = detection.time - currentEnd

            // Log gap signal
            if let obs = observation {
                await obs.addSignalPoint(name: "gap_since_detection", time: detection.time, value: gap)
            }

            if gap <= config.rallyMaxGap {
                // Extend rally
                currentEnd = detection.time
                currentDetectionCount += 1
                lastDetectionTime = detection.time
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

                    // Log rally closed
                    if let obs = observation {
                        await obs.addEvent(
                            name: "rally_closed",
                            time: currentEnd,
                            metadata: [
                                "duration": String(format: "%.3f", duration),
                                "detection_count": "\(currentDetectionCount)"
                            ]
                        )
                        await obs.addSignalPoint(name: "rally_active", time: currentEnd + 0.01, value: 0.0)
                    }
                }

                // Start new rally
                currentStart = detection.time
                currentEnd = detection.time
                currentDetectionCount = 1
                lastDetectionTime = detection.time

                // Log rally opened
                if let obs = observation {
                    await obs.addEvent(
                        name: "rally_opened",
                        time: currentStart,
                        metadata: ["start_time": String(format: "%.3f", currentStart)]
                    )
                    await obs.addSignalPoint(name: "rally_active", time: currentStart, value: 1.0)
                }
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

            // Log rally closed
            if let obs = observation {
                await obs.addEvent(
                    name: "rally_closed",
                    time: currentEnd,
                    metadata: [
                        "duration": String(format: "%.3f", duration),
                        "detection_count": "\(currentDetectionCount)"
                    ]
                )
                await obs.addSignalPoint(name: "rally_active", time: currentEnd + 0.01, value: 0.0)
            }
        }

        return rallies
    }

    /// Group detections into individual shots - each burst of activity is a separate segment.
    /// Uses a tight window (0.15s) to group detections from the same shot event,
    /// then treats each group as a separate segment.
    private func groupAsIndividualShots(
        detections: [TimestampedLine],
        config: HoughMethodConfig,
        observation: RunObservation?
    ) async -> [ActionSegment] {
        guard !detections.isEmpty else { return [] }

        let sorted = detections.sorted { $0.time < $1.time }
        var segments: [ActionSegment] = []

        // Tight window for grouping detections from the same shot (~1-2 frames at 10fps)
        let shotWindow: TimeInterval = 0.15

        var currentStart = sorted[0].time
        var currentEnd = sorted[0].time
        var currentDetectionCount = 1

        for i in 1..<sorted.count {
            let detection = sorted[i]
            let gap = detection.time - currentEnd

            // Log gap signal
            if let obs = observation {
                await obs.addSignalPoint(name: "gap_since_detection", time: detection.time, value: gap)
            }

            if gap <= shotWindow {
                // Same shot event - extend
                currentEnd = detection.time
                currentDetectionCount += 1
            } else {
                // New shot - close previous and start new
                segments.append(ActionSegment(
                    id: UUID(),
                    startTime: currentStart,
                    endTime: currentEnd,
                    isStarred: false
                ))

                currentStart = detection.time
                currentEnd = detection.time
                currentDetectionCount = 1
            }
        }

        // Close last segment
        segments.append(ActionSegment(
            id: UUID(),
            startTime: currentStart,
            endTime: currentEnd,
            isStarred: false
        ))

        return segments
    }
}
```

**Step 2: Update HoughMethod to pass observation to tracker**

In `HoughMethod.swift`, find the line:
```swift
let rallies = tracker.groupRallies(detections: allDetections, config: config)
```

Replace with:
```swift
let rallies = await tracker.groupRallies(detections: allDetections, config: config, observation: observation)
```

**Step 3: Verify the build succeeds**

Run:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add app/methods/hough/HoughTracker.swift app/methods/hough/HoughMethod.swift
git commit -m "feat(hough): add rally lifecycle events and gap signals to tracker

- Add rally_opened/rally_closed events with duration and detection count
- Add gap_since_detection signal for temporal analysis
- Add rally_active binary signal for visualization

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Run Tests to Verify No Regressions

**Files:**
- Test: existing Hough tests

**Step 1: Run Hough-related tests**

Run:
```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests 2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

Expected: All tests pass

**Step 2: If tests fail, fix issues and recommit**

Address any test failures before proceeding.

**Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(hough): address test failures from visualization logging changes

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Summary

After completing all tasks, the Hough method will have:

**7 Signals:**
- `motion_points` (existing) - count of motion pixels
- `motion_area_ratio` (new) - motion as % of frame
- `streak_count` (existing) - number of detected streaks
- `streak_max_length` (new) - longest streak in pixels
- `linearity_score` (new) - points on lines / total points
- `gap_since_detection` (new) - seconds since last detection
- `rally_active` (new) - binary rally state

**5 Events:**
- `streak_detected` (existing) - with length, coordinates
- `hough_debug_frame` (new) - with artifact reference
- `rally_opened` (new) - rally start
- `rally_closed` (new) - rally end with stats

**1 New File:**
- `HoughDebugRenderer.swift` - overlay rendering utility
