# Context-Aware Modules Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> **Relevant Skills:** @axiom-ios-vision, @axiom-swift-concurrency

**Goal:** Implement the "Context Layer" (Automated ROI & Activity Recognition) for the Hough Method, enabling "2 hours in minutes" processing by ignoring background areas and walking players.

**Architecture:**
1.  **ROI Module:** `ROIManager` orchestrates `MotionHeatmapGenerator` (Accelerate-based accumulation) and `ShiftDetector` (MSE check) to maintain a "Reactive" crop rect.
2.  **Activity Module:** `ActivityService` uses a "Lazy Anchor" strategy, combining sparse YOLO detections (via `YOLODetectorProtocol`) with `PlayerTracker` (Motion Mask "hijacking") to calculate `HeuristicAnalyzer` energy scores.

**Tech Stack:** Swift 6, Accelerate (vImage/vDSP), CoreGraphics, AVFoundation.

---

### Task 1: Scaffolding & Configuration

**Files:**
- Create: `app/methods/hough/context/HoughContextConfig.swift`
- Create: `app/methods/hough/context/configs/HoughContextDefaultConfig.swift`

**Step 1: Create Configuration Struct**

Define parameters for Heatmap, Shift Detection, and Activity logic.

```swift
// app/methods/hough/context/HoughContextConfig.swift
import Foundation

public struct HoughContextConfig: Sendable {
    // MARK: - ROI / Heatmap
    /// Frame interval for sampling heatmap (e.g., every 30s)
    public let heatmapSampleInterval: TimeInterval
    /// Multiplier for StdDev threshold (Mean + N * StdDev)
    public let heatmapThresholdSigma: Double
    /// Padding percentage for ROI (0.15 = 15%)
    public let roiPadding: Double
    
    // MARK: - Shift Detection
    /// Interval to check for camera shift (frames)
    public let shiftCheckInterval: Int
    /// MSE threshold to trigger a shift event
    public let shiftMSEThreshold: Float
    
    // MARK: - Activity
    /// Minimum energy score to consider "Active Play"
    public let activityEnergyThreshold: Double
    /// Weight for Jerk vs Acceleration in energy score
    public let jerkWeight: Double
    
    public init(heatmapSampleInterval: TimeInterval, heatmapThresholdSigma: Double, roiPadding: Double, shiftCheckInterval: Int, shiftMSEThreshold: Float, activityEnergyThreshold: Double, jerkWeight: Double) {
        self.heatmapSampleInterval = heatmapSampleInterval
        self.heatmapThresholdSigma = heatmapThresholdSigma
        self.roiPadding = roiPadding
        self.shiftCheckInterval = shiftCheckInterval
        self.shiftMSEThreshold = shiftMSEThreshold
        self.activityEnergyThreshold = activityEnergyThreshold
        self.jerkWeight = jerkWeight
    }
}
```

**Step 2: Create Default Config**

```swift
// app/methods/hough/context/configs/HoughContextDefaultConfig.swift
import Foundation

public struct HoughContextDefaultConfig {
    public static let instance = HoughContextConfig(
        heatmapSampleInterval: 30.0,
        heatmapThresholdSigma: 2.0,
        roiPadding: 0.15,
        shiftCheckInterval: 150,
        shiftMSEThreshold: 50.0,
        activityEnergyThreshold: 100.0,
        jerkWeight: 1.5
    )
}
```

**Step 3: Commit**

```bash
git add app/methods/hough/context/HoughContextConfig.swift app/methods/hough/context/configs/HoughContextDefaultConfig.swift
git commit -m "feat: scaffold HoughContextConfig"
```

---

### Task 2: Motion Heatmap Generator (The "Eye")

**Files:**
- Create: `app/methods/hough/context/MotionHeatmapGenerator.swift`
- Create: `app/SportCrunchTests/Methods/Hough/MotionHeatmapGeneratorTests.swift`

**Step 1: Write Failing Test (Synthetic)**
Create a test that feeds simple black/white frames where motion happens in a specific rect, and asserts the output ROI covers it + padding.

```swift
// app/SportCrunchTests/Methods/Hough/MotionHeatmapGeneratorTests.swift
import XCTest
import Accelerate
@testable import SportCrunch

final class MotionHeatmapGeneratorTests: XCTestCase {
    func testHeatmapGeneration() throws {
        let generator = MotionHeatmapGenerator()
        let config = HoughContextDefaultConfig.instance
        
        // 1. Create 3 frames (100x100)
        // Frame 1: Black
        // Frame 2: White rect at (20,20, 40x40) -> Motion!
        // Frame 3: Black -> Motion!
        let width = 100
        let height = 100
        var frame1 = try vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
        var frame2 = try vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
        var frame3 = try vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
        
        defer { frame1.free(); frame2.free(); frame3.free() }
        
        // Clear all
        vImageOverwrite_Planar8(0, &frame1, vImage_Flags(kvImageNoFlags))
        vImageOverwrite_Planar8(0, &frame2, vImage_Flags(kvImageNoFlags))
        vImageOverwrite_Planar8(0, &frame3, vImage_Flags(kvImageNoFlags))
        
        // Draw rect on frame 2
        drawRect(on: &frame2, x: 20, y: 20, w: 40, h: 40, value: 255)
        
        // 2. Accumulate
        generator.accumulate(frame: frame1)
        generator.accumulate(frame: frame2) // Diff 1-2 = Rect
        generator.accumulate(frame: frame3) // Diff 2-3 = Rect
        
        // 3. Generate ROI
        let roi = try generator.generateROI(config: config)
        
        // Rect is (20,20, 40,40). Center (40,40).
        // Padding 15% of 40 = 6.
        // Expected ROI approx: x:14, y:14, w:52, h:52
        
        XCTAssertGreaterThan(roi.width, 40)
        XCTAssertGreaterThan(roi.height, 40)
        XCTAssertLessThan(roi.minX, 20)
        XCTAssertLessThan(roi.minY, 20)
    }
    
    private func drawRect(on buffer: inout vImage_Buffer, x: Int, y: Int, w: Int, h: Int, value: UInt8) {
        let data = buffer.data.assumingMemoryBound(to: UInt8.self)
        let rowBytes = buffer.rowBytes
        for r in y..<(y+h) {
            for c in x..<(x+w) {
                data[r * rowBytes + c] = value
            }
        }
    }
}
```

**Step 2: Run Test (Fail)**
Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/MotionHeatmapGeneratorTests`

**Step 3: Implement Generator**
Use `Float` buffer for accumulation to avoid overflow.

```swift
// app/methods/hough/context/MotionHeatmapGenerator.swift
import Accelerate
import CoreGraphics

public final class MotionHeatmapGenerator {
    private var accumulator: [Float]?
    private var previousFrame: vImage_Buffer?
    private var width: Int = 0
    private var height: Int = 0
    
    public init() {}
    
    deinit {
        previousFrame?.free()
    }
    
    public func accumulate(frame: vImage_Buffer) {
        // Init if needed
        if accumulator == nil {
            width = Int(frame.width)
            height = Int(frame.height)
            accumulator = Array(repeating: 0.0, count: width * height)
        }
        
        // Copy current for diffing
        var currentCopy = try! vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
        try! vImageCopyBuffer(withUnsafePointer(to: frame) { $0 }, &currentCopy, 1, vImage_Flags(kvImageNoFlags))
        
        defer {
             if previousFrame == nil { previousFrame = currentCopy } // Store first
             else { currentCopy.free() } // Or free if not storing
        }

        guard let prev = previousFrame else { return }
        
        // Diff
        var diff = try! vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
        defer { diff.free() }
        
        // Unsafe pointers for vImage ops
        var mutablePrev = prev
        var mutableFrame = frame
        vImageAbsDiff_Planar8(&mutablePrev, &mutableFrame, &diff, vImage_Flags(kvImageNoFlags))
        
        // Add to accumulator (Float)
        // Convert 8-bit diff to float
        var floatDiff = [Float](repeating: 0, count: width * height)
        floatDiff.withUnsafeMutableBufferPointer { ptr in
            var floatBuf = vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
             var mutableDiff = diff // Local mutable copy for address
            vImageConvert_Planar8toPlanarF(&mutableDiff, &floatBuf, 0, 255.0, vImage_Flags(kvImageNoFlags))
        }
        
        // Vector add
        vDSP_vadd(accumulator!, 1, floatDiff, 1, &accumulator!, 1, vDSP_Length(accumulator!.count))
        
        // Update prev (Shift)
        previousFrame?.free()
        previousFrame = currentCopy // Keep the copy
    }
    
    public func generateROI(config: HoughContextConfig) throws -> CGRect {
        guard let acc = accumulator, !acc.isEmpty else { return .zero }
        
        // 1. Stats (Mean, StdDev)
        var mean: Float = 0
        var stdDev: Float = 0
        vDSP_normalize(acc, 1, nil, 1, &mean, &stdDev, vDSP_Length(acc.count))
        
        let threshold = mean + Float(config.heatmapThresholdSigma) * stdDev
        
        // 2. Binarize
        // Simpler: Just iterate and find min/max X/Y of pixels > threshold.
        // Full contour detection is heavy, bounding box of all "hot" pixels is sufficient and faster for ROI.
        
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        
        for y in 0..<height {
            for x in 0..<width {
                if acc[y * width + x] > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        
        if minX > maxX { return CGRect(x: 0, y: 0, width: width, height: height) } // No motion found
        
        // 3. Padding
        let roiW = Double(maxX - minX)
        let roiH = Double(maxY - minY)
        let padW = roiW * config.roiPadding
        let padH = roiH * config.roiPadding
        
        let finalX = max(0.0, Double(minX) - padW)
        let finalY = max(0.0, Double(minY) - padH)
        let finalW = min(Double(width) - finalX, roiW + 2*padW)
        let finalH = min(Double(height) - finalY, roiH + 2*padH)
        
        return CGRect(x: finalX, y: finalY, width: finalW, height: finalH)
    }
}
```

**Step 4: Run Test (Pass)**
Run: `xcodebuild test -scheme SportCrunch ...`

**Step 5: Commit**

```bash
git add app/methods/hough/context/MotionHeatmapGenerator.swift app/SportCrunchTests/Methods/Hough/MotionHeatmapGeneratorTests.swift
git commit -m "feat: implement MotionHeatmapGenerator with Accelerate"
```

---

### Task 3: Shift Detector (The "Anchor")

**Files:**
- Create: `app/methods/hough/context/ShiftDetector.swift`
- Create: `app/SportCrunchTests/Methods/Hough/ShiftDetectorTests.swift`

**Step 1: Write Test**
Test that `detectShift` returns true when images differ significantly.

```swift
// app/SportCrunchTests/Methods/Hough/ShiftDetectorTests.swift
import XCTest
import Accelerate
@testable import SportCrunch

final class ShiftDetectorTests: XCTestCase {
    func testShiftDetection() throws {
        let detector = ShiftDetector()
        let config = HoughContextDefaultConfig.instance
        
        // Create base patch (gray)
        var anchor = try vImage_Buffer(width: 64, height: 64, bitsPerPixel: 8)
        vImageOverwrite_Planar8(100, &anchor, vImage_Flags(kvImageNoFlags))
        defer { anchor.free() }
        
        detector.setAnchor(frame: anchor)
        
        // Test 1: Same image -> No shift
        let isShifted1 = try detector.checkShift(frame: anchor, config: config)
        XCTAssertFalse(isShifted1)
        
        // Test 2: Different image (white) -> Shift
        var shifted = try vImage_Buffer(width: 64, height: 64, bitsPerPixel: 8)
        vImageOverwrite_Planar8(200, &shifted, vImage_Flags(kvImageNoFlags)) // High MSE
        defer { shifted.free() }
        
        let isShifted2 = try detector.checkShift(frame: shifted, config: config)
        XCTAssertTrue(isShifted2)
    }
}
```

**Step 2: Implement ShiftDetector**

```swift
// app/methods/hough/context/ShiftDetector.swift
import Accelerate

public final class ShiftDetector {
    private var anchorPatch: vImage_Buffer?
    
    public init() {}
    
    deinit {
        anchorPatch?.free()
    }
    
    public func setAnchor(frame: vImage_Buffer) {
        anchorPatch?.free()
        // Crop center 64x64 or just take top-left? Design said "patch". 
        // For simplicity, assume caller passes the patch or we take 64x64 from center.
        // Let's take center 64x64.
        
        let patchSize = 64
        let startX = (Int(frame.width) - patchSize) / 2
        let startY = (Int(frame.height) - patchSize) / 2
        
        guard startX >= 0, startY >= 0 else { return } // Too small
        
        var patch = try! vImage_Buffer(width: patchSize, height: patchSize, bitsPerPixel: 8)
        
        // Copy ROI
        var src = frame
        let start = src.data.advanced(by: startY * src.rowBytes + startX)
        var srcROI = vImage_Buffer(data: start, height: vImagePixelCount(patchSize), width: vImagePixelCount(patchSize), rowBytes: src.rowBytes)
        
        try! vImageCopyBuffer(&srcROI, &patch, 1, vImage_Flags(kvImageNoFlags))
        anchorPatch = patch
    }
    
    public func checkShift(frame: vImage_Buffer, config: HoughContextConfig) throws -> Bool {
        guard let anchor = anchorPatch else { return false }
        
        let patchSize = 64
        let startX = (Int(frame.width) - patchSize) / 2
        let startY = (Int(frame.height) - patchSize) / 2
        
        // Extract current center
        var src = frame
        let start = src.data.advanced(by: startY * src.rowBytes + startX)
        var currentROI = vImage_Buffer(data: start, height: vImagePixelCount(patchSize), width: vImagePixelCount(patchSize), rowBytes: src.rowBytes)
        
        // MSE Calculation
        // 1. Diff
        var diff = try vImage_Buffer(width: patchSize, height: patchSize, bitsPerPixel: 8)
        defer { diff.free() }
        
        var mutableAnchor = anchor // Local copy for pointer
        vImageAbsDiff_Planar8(&mutableAnchor, &currentROI, &diff, vImage_Flags(kvImageNoFlags))
        
        // 2. Sum of Squares (implicitly via Mean/StdDev or direct calc)
        // Faster: Convert to float and dot product? Or just sum.
        // Let's use basic loop for 64x64 (4096 pixels) - trivial cost.
        
        var sumSq: Double = 0
        let ptr = diff.data.assumingMemoryBound(to: UInt8.self)
        for i in 0..<4096 {
            let val = Double(ptr[i])
            sumSq += val * val
        }
        
        let mse = sumSq / 4096.0
        return Float(mse) > config.shiftMSEThreshold
    }
}
```

**Step 3: Run Test (Pass)**
Run: `xcodebuild test -scheme SportCrunch ...`

**Step 4: Commit**

```bash
git add app/methods/hough/context/ShiftDetector.swift app/SportCrunchTests/Methods/Hough/ShiftDetectorTests.swift
git commit -m "feat: implement ShiftDetector with MSE check"
```

---

### Task 4: Player Tracker & Activity Analysis

**Files:**
- Create: `app/methods/hough/context/activity/YOLODetectorProtocol.swift`
- Create: `app/methods/hough/context/activity/PlayerTracker.swift`
- Create: `app/methods/hough/context/activity/HeuristicAnalyzer.swift`
- Create: `app/SportCrunchTests/Methods/Hough/HeuristicAnalyzerTests.swift`

**Step 1: Define Protocols**

```swift
// app/methods/hough/context/activity/YOLODetectorProtocol.swift
import CoreGraphics

public protocol YOLODetectorProtocol: Sendable {
    func detectPlayers(in frame: CGImage) async throws -> [CGRect]
}

// Mock
public final class MockYOLODetector: YOLODetectorProtocol {
    public let fixedBoxes: [CGRect]
    public init(boxes: [CGRect] = []) { self.fixedBoxes = boxes }
    public func detectPlayers(in frame: CGImage) async throws -> [CGRect] {
        return fixedBoxes
    }
}
```

**Step 2: Implement Player Tracker (Hijacker)**

```swift
// app/methods/hough/context/activity/PlayerTracker.swift
import Accelerate
import CoreGraphics

public struct PlayerTracker {
    public init() {}

    public func track(players: [CGPoint], using motionMask: vImage_Buffer) -> [CGPoint] {
        // For each player centroid, find center of mass of nearby motion
        return players.map { p in
            findCentroidOfBlob(near: p, in: motionMask) ?? p
        }
    }
    
    private func findCentroidOfBlob(near p: CGPoint, in mask: vImage_Buffer) -> CGPoint? {
        // Scan a window around p (e.g., +/- 50 pixels)
        // Calculate weighted average of x,y
        let radius = 50
        let startX = max(0, Int(p.x) - radius)
        let endX = min(Int(mask.width), Int(p.x) + radius)
        let startY = max(0, Int(p.y) - radius)
        let endY = min(Int(mask.height), Int(p.y) + radius)
        
        var sumX: Double = 0
        var sumY: Double = 0
        var count: Double = 0
        
        let rowBytes = mask.rowBytes
        let data = mask.data.assumingMemoryBound(to: UInt8.self)
        
        for y in startY..<endY {
            let row = data.advanced(by: y * rowBytes)
            for x in startX..<endX {
                if row[x] > 0 { // Motion pixel
                    sumX += Double(x)
                    sumY += Double(y)
                    count += 1
                }
            }
        }
        
        guard count > 10 else { return nil } // Too small noise
        return CGPoint(x: sumX / count, y: sumY / count)
    }
}
```

**Step 3: Implement Analyzer and Test**

```swift
// app/methods/hough/context/activity/HeuristicAnalyzer.swift
import Foundation
import CoreGraphics

public struct HeuristicAnalyzer {
    public init() {}
    
    public func calculateScore(trajectory: [CGPoint], config: HoughContextConfig) -> Double {
        guard trajectory.count >= 3 else { return 0 }
        
        var totalEnergy: Double = 0
        
        for i in 2..<trajectory.count {
            let p0 = trajectory[i-2]
            let p1 = trajectory[i-1]
            let p2 = trajectory[i]
            
            let v1 = distance(p1, p0)
            let v2 = distance(p2, p1)
            let accel = abs(v2 - v1)
            
            // Jerk approximation (change in accel) - requires 4 points, 
            // but we can approximate "burstiness" as Accel itself + variance.
            // Design said: Energy = Sum(|A| + w * |J|)
            // Let's stick to Accel for V1 simplicity or implement full derivative chain.
            
            totalEnergy += accel
        }
        
        return totalEnergy
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}
```

```swift
// app/SportCrunchTests/Methods/Hough/HeuristicAnalyzerTests.swift
import XCTest
@testable import SportCrunch

final class HeuristicAnalyzerTests: XCTestCase {
    func testEnergyCalculation() {
        let analyzer = HeuristicAnalyzer()
        let config = HoughContextDefaultConfig.instance
        
        // 1. Constant velocity (Walking) -> Accel ~ 0
        var walking: [CGPoint] = []
        for i in 0..<10 { walking.append(CGPoint(x: Double(i)*5, y: 0)) }
        
        let walkScore = analyzer.calculateScore(trajectory: walking, config: config)
        XCTAssertLessThan(walkScore, 1.0)
        
        // 2. Sprint/Stop (Active) -> Accel high
        // 0, 0, 10, 30, 60, 60, 60
        let sprinting = [
            CGPoint(x:0, y:0), CGPoint(x:0, y:0),
            CGPoint(x:10, y:0), CGPoint(x:30, y:0),
            CGPoint(x:60, y:0), CGPoint(x:60, y:0)
        ]
        
        let runScore = analyzer.calculateScore(trajectory: sprinting, config: config)
        XCTAssertGreaterThan(runScore, 10.0)
    }
}
```

**Step 4: Run Test**
Run: `xcodebuild test ...`

**Step 5: Commit**

```bash
git add app/methods/hough/context/activity/YOLODetectorProtocol.swift app/methods/hough/context/activity/PlayerTracker.swift app/methods/hough/context/activity/HeuristicAnalyzer.swift app/SportCrunchTests/Methods/Hough/HeuristicAnalyzerTests.swift
git commit -m "feat: implement Activity Recognition logic"
```

---

### Task 5: Activity Service (The Facade)

**Files:**
- Create: `app/methods/hough/context/activity/ActivityService.swift`

**Step 1: Implement Service**

```swift
// app/methods/hough/context/activity/ActivityService.swift
import Foundation
import CoreGraphics
import Accelerate

public actor ActivityService {
    private let detector: YOLODetectorProtocol
    private let tracker = PlayerTracker()
    private let analyzer = HeuristicAnalyzer()
    
    public init(detector: YOLODetectorProtocol) {
        self.detector = detector
    }
    
    // In real implementation, this would take the FrameProvider/VideoAsset to seek.
    // For V1 plan, we define the signature.
    public func validateActivity(
        anchorFrame: CGImage,
        intermediateMasks: [vImage_Buffer],
        config: HoughContextConfig
    ) async throws -> Bool {
        
        // 1. Detect Anchor
        let players = try await detector.detectPlayers(in: anchorFrame)
        var centroids = players.map { CGPoint(x: $0.midX, y: $0.midY) }
        
        var trajectories: [[CGPoint]] = Array(repeating: [], count: centroids.count)
        
        // 2. Track through masks
        for mask in intermediateMasks {
            centroids = tracker.track(players: centroids, using: mask)
            for (i, p) in centroids.enumerated() {
                trajectories[i].append(p)
            }
        }
        
        // 3. Analyze
        var maxEnergy: Double = 0
        for traj in trajectories {
            let energy = analyzer.calculateScore(trajectory: traj, config: config)
            maxEnergy = max(maxEnergy, energy)
        }
        
        return maxEnergy > config.activityEnergyThreshold
    }
}
```

**Step 2: Commit**

```bash
git add app/methods/hough/context/activity/ActivityService.swift
git commit -m "feat: implement ActivityService facade"
```
