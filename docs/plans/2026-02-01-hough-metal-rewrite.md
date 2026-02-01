# Hough Method Metal GPU Rewrite

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite the O(N³) CPU-bound Hough linearity detection to use Metal compute shaders, achieving real-time performance for tennis ball streak detection.

**Architecture:**
1. Motion differencing stays in CPU (Accelerate vDSP is already fast)
2. GPU takes over for linearity detection via parallel Hough accumulator voting
3. Line extraction happens on GPU, results copied back for temporal tracking

**Tech Stack:** Metal compute shaders, MTLBuffer, MTLComputePipelineState, simd types for CPU-GPU alignment

---

## Background: Why This Fixes the Performance Problem

The current `HoughLinearityDetector.growLine()` iterates ALL points for EACH neighbor of EACH seed = O(N³). For 100k motion points per frame, this is 10^15 operations.

The GPU solution parallelizes this:
- Each motion point votes into a Hough accumulator in parallel
- Peak detection extracts lines in O(accumulator_size)
- Total: O(N) GPU work + O(accumulator) CPU work per frame

---

## Task 1: Create Metal Shader File Structure

**Files:**
- Create: `app/methods/hough/HoughShaders.metal`

**Step 1: Create the Metal shader file with Hough accumulator kernel**

```metal
//
//  HoughShaders.metal
//  SportCrunch
//
//  GPU-accelerated Hough line detection for motion streak analysis.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Structures

/// Motion point passed from CPU
struct MotionPointGPU {
    float x;
    float y;
};

/// Detected line passed back to CPU
struct DetectedLineGPU {
    float rho;      // Distance from origin to line
    float theta;    // Angle of normal to line (radians)
    uint votes;     // Number of votes in accumulator
};

/// Hough transform parameters
struct HoughParams {
    float rhoStep;      // Resolution in rho (pixels)
    float thetaStep;    // Resolution in theta (radians)
    int numRhoSteps;    // Number of rho bins
    int numThetaSteps;  // Number of theta bins (typically 180)
    float maxRho;       // Maximum rho value (diagonal of image)
    int voteThreshold;  // Minimum votes to consider a line
};

// MARK: - Hough Voting Kernel

/// Each thread processes one motion point and votes for all possible lines through it.
/// Uses atomic operations to increment the accumulator.
kernel void houghVoteKernel(
    device const MotionPointGPU* points [[buffer(0)]],
    device atomic_uint* accumulator [[buffer(1)]],
    constant HoughParams& params [[buffer(2)]],
    constant uint& pointCount [[buffer(3)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid >= pointCount) return;

    float x = points[tid].x;
    float y = points[tid].y;

    // Vote for all theta values
    for (int thetaIdx = 0; thetaIdx < params.numThetaSteps; thetaIdx++) {
        float theta = float(thetaIdx) * params.thetaStep;

        // rho = x * cos(theta) + y * sin(theta)
        float rho = x * cos(theta) + y * sin(theta);

        // Convert to bin index (rho ranges from -maxRho to +maxRho)
        int rhoIdx = int((rho + params.maxRho) / params.rhoStep);

        if (rhoIdx >= 0 && rhoIdx < params.numRhoSteps) {
            int accumIdx = thetaIdx * params.numRhoSteps + rhoIdx;
            atomic_fetch_add_explicit(&accumulator[accumIdx], 1, memory_order_relaxed);
        }
    }
}

// MARK: - Peak Detection Kernel

/// Each thread checks one cell in the accumulator for local maximum.
/// Non-maximum suppression: only keep if greater than all 8 neighbors.
kernel void houghPeakKernel(
    device const atomic_uint* accumulator [[buffer(0)]],
    device DetectedLineGPU* peaks [[buffer(1)]],
    device atomic_uint* peakCount [[buffer(2)]],
    constant HoughParams& params [[buffer(3)]],
    constant uint& maxPeaks [[buffer(4)]],
    uint2 tid [[thread_position_in_grid]]
) {
    int thetaIdx = int(tid.x);
    int rhoIdx = int(tid.y);

    if (thetaIdx >= params.numThetaSteps || rhoIdx >= params.numRhoSteps) return;

    int idx = thetaIdx * params.numRhoSteps + rhoIdx;
    uint votes = atomic_load_explicit(&accumulator[idx], memory_order_relaxed);

    // Skip if below threshold
    if (votes < uint(params.voteThreshold)) return;

    // Non-maximum suppression: check 8 neighbors
    bool isLocalMax = true;
    for (int dt = -1; dt <= 1 && isLocalMax; dt++) {
        for (int dr = -1; dr <= 1 && isLocalMax; dr++) {
            if (dt == 0 && dr == 0) continue;

            int nt = thetaIdx + dt;
            int nr = rhoIdx + dr;

            // Handle theta wraparound (circular)
            if (nt < 0) nt += params.numThetaSteps;
            if (nt >= params.numThetaSteps) nt -= params.numThetaSteps;

            if (nr >= 0 && nr < params.numRhoSteps) {
                int neighborIdx = nt * params.numRhoSteps + nr;
                uint neighborVotes = atomic_load_explicit(&accumulator[neighborIdx], memory_order_relaxed);
                if (neighborVotes >= votes) {
                    isLocalMax = false;
                }
            }
        }
    }

    if (isLocalMax) {
        // Atomically claim a slot in the output array
        uint peakIdx = atomic_fetch_add_explicit(peakCount, 1, memory_order_relaxed);
        if (peakIdx < maxPeaks) {
            float theta = float(thetaIdx) * params.thetaStep;
            float rho = float(rhoIdx) * params.rhoStep - params.maxRho;

            peaks[peakIdx].rho = rho;
            peaks[peakIdx].theta = theta;
            peaks[peakIdx].votes = votes;
        }
    }
}

// MARK: - Accumulator Clear Kernel

/// Fast parallel clear of the accumulator between frames.
kernel void houghClearKernel(
    device atomic_uint* accumulator [[buffer(0)]],
    constant uint& size [[buffer(1)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid < size) {
        atomic_store_explicit(&accumulator[tid], 0, memory_order_relaxed);
    }
}
```

**Step 2: Verify the file is in the correct location**

The file should be at `app/methods/hough/HoughShaders.metal` and will be automatically included in the build.

**Step 3: Commit**

```bash
git add app/methods/hough/HoughShaders.metal
git commit -m "feat(hough): add Metal compute shaders for GPU Hough transform

- houghVoteKernel: parallel voting from motion points
- houghPeakKernel: non-maximum suppression peak detection
- houghClearKernel: fast accumulator reset between frames

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Create GPU Pipeline Manager

**Files:**
- Create: `app/methods/hough/HoughGPU.swift`

**Step 1: Create the GPU pipeline manager**

```swift
//
//  HoughGPU.swift
//  SportCrunch
//
//  Manages Metal compute pipeline for GPU-accelerated Hough line detection.
//

import Foundation
import Metal
import simd

// MARK: - GPU-Compatible Structures

/// Motion point for GPU transfer. Must match HoughShaders.metal MotionPointGPU.
struct MotionPointGPU {
    var x: Float
    var y: Float
}

/// Detected line from GPU. Must match HoughShaders.metal DetectedLineGPU.
struct DetectedLineGPU {
    var rho: Float
    var theta: Float
    var votes: UInt32
}

/// Hough parameters for GPU. Must match HoughShaders.metal HoughParams.
struct HoughParamsGPU {
    var rhoStep: Float
    var thetaStep: Float
    var numRhoSteps: Int32
    var numThetaSteps: Int32
    var maxRho: Float
    var voteThreshold: Int32
}

// MARK: - Errors

enum HoughGPUError: Error, LocalizedError {
    case metalNotSupported
    case shaderNotFound(String)
    case pipelineCreationFailed(String)
    case bufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .metalNotSupported:
            return "Metal is not supported on this device"
        case .shaderNotFound(let name):
            return "Metal shader function '\(name)' not found"
        case .pipelineCreationFailed(let reason):
            return "Failed to create compute pipeline: \(reason)"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        }
    }
}

// MARK: - HoughGPU

/// Manages Metal compute pipelines for GPU-accelerated Hough line detection.
final class HoughGPU: @unchecked Sendable {

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let votePipeline: MTLComputePipelineState
    private let peakPipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState

    // MARK: - Buffers (reused across frames)

    private var accumulatorBuffer: MTLBuffer?
    private var peaksBuffer: MTLBuffer?
    private var peakCountBuffer: MTLBuffer?
    private var paramsBuffer: MTLBuffer?

    // MARK: - Configuration

    private let numThetaSteps: Int = 180  // 1 degree resolution
    private let rhoStep: Float = 1.0      // 1 pixel resolution
    private let maxPeaks: Int = 100

    private var currentMaxRho: Float = 0
    private var currentNumRhoSteps: Int = 0

    // MARK: - Initialization

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw HoughGPUError.metalNotSupported
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw HoughGPUError.metalNotSupported
        }
        self.commandQueue = commandQueue

        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            throw HoughGPUError.shaderNotFound("default library")
        }

        // Create vote pipeline
        guard let voteFunction = library.makeFunction(name: "houghVoteKernel") else {
            throw HoughGPUError.shaderNotFound("houghVoteKernel")
        }
        do {
            votePipeline = try device.makeComputePipelineState(function: voteFunction)
        } catch {
            throw HoughGPUError.pipelineCreationFailed(error.localizedDescription)
        }

        // Create peak pipeline
        guard let peakFunction = library.makeFunction(name: "houghPeakKernel") else {
            throw HoughGPUError.shaderNotFound("houghPeakKernel")
        }
        do {
            peakPipeline = try device.makeComputePipelineState(function: peakFunction)
        } catch {
            throw HoughGPUError.pipelineCreationFailed(error.localizedDescription)
        }

        // Create clear pipeline
        guard let clearFunction = library.makeFunction(name: "houghClearKernel") else {
            throw HoughGPUError.shaderNotFound("houghClearKernel")
        }
        do {
            clearPipeline = try device.makeComputePipelineState(function: clearFunction)
        } catch {
            throw HoughGPUError.pipelineCreationFailed(error.localizedDescription)
        }

        // Allocate output buffers
        peaksBuffer = device.makeBuffer(
            length: maxPeaks * MemoryLayout<DetectedLineGPU>.stride,
            options: .storageModeShared
        )
        peakCountBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        paramsBuffer = device.makeBuffer(
            length: MemoryLayout<HoughParamsGPU>.stride,
            options: .storageModeShared
        )
    }

    // MARK: - Public API

    /// Detect lines in the given motion points using GPU Hough transform.
    /// - Parameters:
    ///   - points: Array of motion points from frame differencing
    ///   - imageWidth: Width of the source image (for rho calculation)
    ///   - imageHeight: Height of the source image (for rho calculation)
    ///   - voteThreshold: Minimum votes to consider a line
    /// - Returns: Array of detected lines in (rho, theta, votes) format
    func detectLines(
        points: [MotionPoint],
        imageWidth: Int,
        imageHeight: Int,
        voteThreshold: Int
    ) throws -> [DetectedLineGPU] {
        guard !points.isEmpty else { return [] }

        // Calculate max rho (diagonal of image)
        let maxRho = Float(sqrt(Double(imageWidth * imageWidth + imageHeight * imageHeight)))
        let numRhoSteps = Int(2 * maxRho / rhoStep) + 1

        // Reallocate accumulator if needed
        if currentMaxRho != maxRho || currentNumRhoSteps != numRhoSteps {
            let accumulatorSize = numThetaSteps * numRhoSteps * MemoryLayout<UInt32>.stride
            accumulatorBuffer = device.makeBuffer(length: accumulatorSize, options: .storageModeShared)
            currentMaxRho = maxRho
            currentNumRhoSteps = numRhoSteps
        }

        guard let accumulatorBuffer = accumulatorBuffer,
              let peaksBuffer = peaksBuffer,
              let peakCountBuffer = peakCountBuffer,
              let paramsBuffer = paramsBuffer else {
            throw HoughGPUError.bufferCreationFailed
        }

        // Convert points to GPU format
        let gpuPoints = points.map { MotionPointGPU(x: Float($0.x), y: Float($0.y)) }
        guard let pointsBuffer = device.makeBuffer(
            bytes: gpuPoints,
            length: gpuPoints.count * MemoryLayout<MotionPointGPU>.stride,
            options: .storageModeShared
        ) else {
            throw HoughGPUError.bufferCreationFailed
        }

        // Set up parameters
        var params = HoughParamsGPU(
            rhoStep: rhoStep,
            thetaStep: Float.pi / Float(numThetaSteps),
            numRhoSteps: Int32(numRhoSteps),
            numThetaSteps: Int32(numThetaSteps),
            maxRho: maxRho,
            voteThreshold: Int32(voteThreshold)
        )
        memcpy(paramsBuffer.contents(), &params, MemoryLayout<HoughParamsGPU>.stride)

        // Reset peak count
        var zeroCount: UInt32 = 0
        memcpy(peakCountBuffer.contents(), &zeroCount, MemoryLayout<UInt32>.stride)

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw HoughGPUError.bufferCreationFailed
        }

        // 1. Clear accumulator
        encodeClearKernel(commandBuffer: commandBuffer, accumulator: accumulatorBuffer, size: numThetaSteps * numRhoSteps)

        // 2. Vote kernel
        encodeVoteKernel(
            commandBuffer: commandBuffer,
            points: pointsBuffer,
            accumulator: accumulatorBuffer,
            params: paramsBuffer,
            pointCount: points.count
        )

        // 3. Peak detection kernel
        encodePeakKernel(
            commandBuffer: commandBuffer,
            accumulator: accumulatorBuffer,
            peaks: peaksBuffer,
            peakCount: peakCountBuffer,
            params: paramsBuffer
        )

        // Execute and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results
        let peakCount = peakCountBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee
        let resultCount = min(Int(peakCount), maxPeaks)

        var results: [DetectedLineGPU] = []
        if resultCount > 0 {
            let peaksPtr = peaksBuffer.contents().assumingMemoryBound(to: DetectedLineGPU.self)
            results = Array(UnsafeBufferPointer(start: peaksPtr, count: resultCount))
            // Sort by vote count descending
            results.sort { $0.votes > $1.votes }
        }

        return results
    }

    // MARK: - Private Encoding

    private func encodeClearKernel(commandBuffer: MTLCommandBuffer, accumulator: MTLBuffer, size: Int) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(clearPipeline)
        encoder.setBuffer(accumulator, offset: 0, index: 0)
        var sizeValue = UInt32(size)
        encoder.setBytes(&sizeValue, length: MemoryLayout<UInt32>.stride, index: 1)

        let threadGroupSize = MTLSize(width: 256, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (size + 255) / 256, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }

    private func encodeVoteKernel(
        commandBuffer: MTLCommandBuffer,
        points: MTLBuffer,
        accumulator: MTLBuffer,
        params: MTLBuffer,
        pointCount: Int
    ) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(votePipeline)
        encoder.setBuffer(points, offset: 0, index: 0)
        encoder.setBuffer(accumulator, offset: 0, index: 1)
        encoder.setBuffer(params, offset: 0, index: 2)
        var count = UInt32(pointCount)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 3)

        let threadGroupSize = MTLSize(width: min(256, votePipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let threadGroups = MTLSize(width: (pointCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }

    private func encodePeakKernel(
        commandBuffer: MTLCommandBuffer,
        accumulator: MTLBuffer,
        peaks: MTLBuffer,
        peakCount: MTLBuffer,
        params: MTLBuffer
    ) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(peakPipeline)
        encoder.setBuffer(accumulator, offset: 0, index: 0)
        encoder.setBuffer(peaks, offset: 0, index: 1)
        encoder.setBuffer(peakCount, offset: 0, index: 2)
        encoder.setBuffer(params, offset: 0, index: 3)
        var maxPeaksValue = UInt32(maxPeaks)
        encoder.setBytes(&maxPeaksValue, length: MemoryLayout<UInt32>.stride, index: 4)

        // 2D dispatch: theta x rho
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (numThetaSteps + 15) / 16,
            height: (currentNumRhoSteps + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }
}
```

**Step 2: Commit**

```bash
git add app/methods/hough/HoughGPU.swift
git commit -m "feat(hough): add Metal GPU pipeline manager

- HoughGPU class manages compute pipelines
- Reusable buffers to avoid per-frame allocations
- detectLines() returns lines in rho-theta format

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Create GPU-Based Linearity Detector

**Files:**
- Create: `app/methods/hough/HoughLinearityDetectorGPU.swift`

**Step 1: Create the GPU linearity detector that converts GPU results to LineSegments**

```swift
//
//  HoughLinearityDetectorGPU.swift
//  SportCrunch
//
//  GPU-accelerated linearity detection using Metal Hough transform.
//  Replaces the CPU-bound RANSAC-like algorithm.
//

import Foundation
import simd

/// GPU-accelerated linearity detector using Hough transform.
/// Converts GPU Hough lines (rho, theta) to LineSegment format for compatibility.
final class HoughLinearityDetectorGPU: @unchecked Sendable {

    private let gpu: HoughGPU

    init() throws {
        self.gpu = try HoughGPU()
    }

    /// Detect linear streaks in motion points using GPU Hough transform.
    /// - Parameters:
    ///   - points: Motion points from frame differencing
    ///   - config: Detection configuration
    ///   - imageWidth: Width of source image
    ///   - imageHeight: Height of source image
    /// - Returns: Array of detected line segments
    func detect(
        points: [MotionPoint],
        config: HoughMethodConfig,
        imageWidth: Int,
        imageHeight: Int
    ) throws -> [LineSegment] {
        // Calculate vote threshold based on minimum streak length
        // A line of minStreakLength pixels should have roughly that many votes
        let voteThreshold = max(Int(config.minStreakLength / 2), 10)

        let gpuLines = try gpu.detectLines(
            points: points,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            voteThreshold: voteThreshold
        )

        // Convert Hough lines to LineSegments
        return gpuLines.compactMap { gpuLine in
            convertToLineSegment(
                gpuLine: gpuLine,
                points: points,
                config: config,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
        }
    }

    // MARK: - Private Helpers

    /// Convert a Hough line (rho, theta) to a LineSegment by finding inlier points.
    private func convertToLineSegment(
        gpuLine: DetectedLineGPU,
        points: [MotionPoint],
        config: HoughMethodConfig,
        imageWidth: Int,
        imageHeight: Int
    ) -> LineSegment? {
        let rho = Double(gpuLine.rho)
        let theta = Double(gpuLine.theta)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)

        let tolerance = config.lineTolerance

        // Find all points that lie on this line within tolerance
        var inliers: [MotionPoint] = []
        var minProj: Double = .infinity
        var maxProj: Double = -.infinity

        for point in points {
            // Distance from point to line: |x*cos(theta) + y*sin(theta) - rho|
            let dist = abs(point.x * cosTheta + point.y * sinTheta - rho)

            if dist <= tolerance {
                inliers.append(point)

                // Project onto line direction (perpendicular to normal)
                // Line direction is (-sin(theta), cos(theta))
                let proj = -point.x * sinTheta + point.y * cosTheta
                minProj = min(minProj, proj)
                maxProj = max(maxProj, proj)
            }
        }

        // Check minimum length
        let length = maxProj - minProj
        guard length >= config.minStreakLength else { return nil }

        // Calculate start and end points on the line
        // Point on line closest to origin: (rho * cos(theta), rho * sin(theta))
        // Then move along line direction by minProj and maxProj
        let lineDir = simd_double2(-sinTheta, cosTheta)
        let basePoint = simd_double2(rho * cosTheta, rho * sinTheta)

        let startSimd = basePoint + minProj * lineDir
        let endSimd = basePoint + maxProj * lineDir

        let start = MotionPoint(x: startSimd.x, y: startSimd.y)
        let end = MotionPoint(x: endSimd.x, y: endSimd.y)

        return LineSegment(
            start: start,
            end: end,
            length: length,
            points: inliers
        )
    }
}
```

**Step 2: Commit**

```bash
git add app/methods/hough/HoughLinearityDetectorGPU.swift
git commit -m "feat(hough): add GPU linearity detector with Hough-to-LineSegment conversion

- HoughLinearityDetectorGPU wraps HoughGPU
- Converts rho-theta lines to LineSegment format
- Finds inlier points for each detected line

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Update HoughMethod to Use GPU Detector

**Files:**
- Modify: `app/methods/hough/HoughMethod.swift`

**Step 1: Update HoughMethod to use GPU detector with CPU fallback**

Replace the detector initialization and usage:

```swift
// At line 41, change:
private let detector = HoughLinearityDetector()

// To:
private var gpuDetector: HoughLinearityDetectorGPU?
private let cpuDetector = HoughLinearityDetector()
private var useGPU: Bool = true

// In init(), add GPU initialization:
init(config: HoughMethodConfig) {
    self.config = config
    // Try to initialize GPU detector
    do {
        self.gpuDetector = try HoughLinearityDetectorGPU()
        print("⚙️ [HoughMethod] GPU acceleration enabled")
    } catch {
        print("⚙️ [HoughMethod] ⚠️ GPU init failed: \(error.localizedDescription), using CPU fallback")
        self.useGPU = false
    }
}
```

**Step 2: Update the detection call in detectSegments()**

Replace the line detection call around line 101:

```swift
// Replace:
let lines = detector.detect(points: points, config: config)

// With:
let lines: [LineSegment]
if useGPU, let gpuDetector = gpuDetector {
    do {
        lines = try gpuDetector.detect(
            points: points,
            config: config,
            imageWidth: image.width,
            imageHeight: image.height
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

**Step 3: Commit**

```bash
git add app/methods/hough/HoughMethod.swift
git commit -m "feat(hough): integrate GPU detector with CPU fallback

- Try GPU detection first
- Fall back to CPU if GPU fails or unavailable
- Log which path is being used

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Unit Tests for GPU Detector

**Files:**
- Create: `app/SportCrunchTests/HoughGPUTests.swift`

**Step 1: Create tests for the GPU Hough detector**

```swift
//
//  HoughGPUTests.swift
//  SportCrunchTests
//
//  Tests for GPU-accelerated Hough line detection.
//

import XCTest
@testable import SportCrunch

final class HoughGPUTests: XCTestCase {

    var gpu: HoughGPU!

    override func setUpWithError() throws {
        gpu = try HoughGPU()
    }

    override func tearDown() {
        gpu = nil
    }

    // MARK: - Basic Functionality

    func testEmptyPointsReturnsNoLines() throws {
        let lines = try gpu.detectLines(
            points: [],
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 10
        )
        XCTAssertTrue(lines.isEmpty)
    }

    func testHorizontalLineDetection() throws {
        // Create points along y = 50 (horizontal line)
        var points: [MotionPoint] = []
        for x in stride(from: 10, to: 90, by: 1) {
            points.append(MotionPoint(x: Double(x), y: 50))
        }

        let lines = try gpu.detectLines(
            points: points,
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 20
        )

        XCTAssertFalse(lines.isEmpty, "Should detect horizontal line")

        // Horizontal line: theta should be ~90 degrees (pi/2)
        // rho should be ~50 (distance from origin to line)
        if let bestLine = lines.first {
            let thetaDegrees = bestLine.theta * 180 / Float.pi
            XCTAssertEqual(thetaDegrees, 90, accuracy: 5, "Theta should be ~90 degrees for horizontal line")
            XCTAssertEqual(bestLine.rho, 50, accuracy: 5, "Rho should be ~50 for y=50 line")
        }
    }

    func testVerticalLineDetection() throws {
        // Create points along x = 30 (vertical line)
        var points: [MotionPoint] = []
        for y in stride(from: 10, to: 90, by: 1) {
            points.append(MotionPoint(x: 30, y: Double(y)))
        }

        let lines = try gpu.detectLines(
            points: points,
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 20
        )

        XCTAssertFalse(lines.isEmpty, "Should detect vertical line")

        // Vertical line: theta should be ~0 degrees
        // rho should be ~30 (distance from origin to line)
        if let bestLine = lines.first {
            let thetaDegrees = bestLine.theta * 180 / Float.pi
            XCTAssertTrue(thetaDegrees < 10 || thetaDegrees > 170, "Theta should be ~0 or ~180 for vertical line")
            XCTAssertEqual(abs(bestLine.rho), 30, accuracy: 5, "Rho should be ~30 for x=30 line")
        }
    }

    func testDiagonalLineDetection() throws {
        // Create points along y = x (45 degree diagonal)
        var points: [MotionPoint] = []
        for i in stride(from: 10, to: 90, by: 1) {
            points.append(MotionPoint(x: Double(i), y: Double(i)))
        }

        let lines = try gpu.detectLines(
            points: points,
            imageWidth: 100,
            imageHeight: 100,
            voteThreshold: 20
        )

        XCTAssertFalse(lines.isEmpty, "Should detect diagonal line")

        // 45 degree line through origin: theta should be ~135 degrees, rho ~0
        if let bestLine = lines.first {
            let thetaDegrees = bestLine.theta * 180 / Float.pi
            XCTAssertEqual(thetaDegrees, 135, accuracy: 10, "Theta should be ~135 degrees for y=x line")
        }
    }

    // MARK: - Performance

    func testPerformanceWith10kPoints() throws {
        // Simulate realistic motion point count
        var points: [MotionPoint] = []

        // Add some random noise
        for _ in 0..<9000 {
            points.append(MotionPoint(
                x: Double.random(in: 0..<1920),
                y: Double.random(in: 0..<1080)
            ))
        }

        // Add a clear line
        for x in stride(from: 100, to: 1800, by: 2) {
            points.append(MotionPoint(x: Double(x), y: Double(x) * 0.5 + 100))
        }

        measure {
            _ = try? gpu.detectLines(
                points: points,
                imageWidth: 1920,
                imageHeight: 1080,
                voteThreshold: 50
            )
        }
    }

    func testPerformanceWith50kPoints() throws {
        var points: [MotionPoint] = []

        for _ in 0..<50000 {
            points.append(MotionPoint(
                x: Double.random(in: 0..<1920),
                y: Double.random(in: 0..<1080)
            ))
        }

        measure {
            _ = try? gpu.detectLines(
                points: points,
                imageWidth: 1920,
                imageHeight: 1080,
                voteThreshold: 100
            )
        }
    }
}
```

**Step 2: Run tests to verify they compile and pass**

```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/HoughGPUTests
```

Expected: Tests should pass (or skip if Metal not available in simulator)

**Step 3: Commit**

```bash
git add app/SportCrunchTests/HoughGPUTests.swift
git commit -m "test(hough): add GPU Hough detector tests

- Basic line detection (horizontal, vertical, diagonal)
- Performance benchmarks with 10k and 50k points

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Integration Test with Real Video

**Files:**
- Modify: `app/SportCrunchTests/HoughLinearityDetectorTests.swift` (add GPU comparison test)

**Step 1: Add a test comparing CPU vs GPU results**

Add to the existing test file:

```swift
// MARK: - GPU Comparison Tests

func testGPUvsCPUProducesSimilarResults() throws {
    // Create a synthetic point cloud with a clear line
    var points: [MotionPoint] = []

    // Add a diagonal line
    for i in 0..<100 {
        let x = Double(i) * 2
        let y = Double(i) + 50
        points.append(MotionPoint(x: x, y: y))
        // Add some noise around the line
        points.append(MotionPoint(x: x + Double.random(in: -2...2), y: y + Double.random(in: -2...2)))
    }

    let config = HoughMethodConfig(
        diffThreshold: 25,
        minMotionArea: 50,
        minStreakLength: 50.0,
        maxStreakGap: 10.0,
        lineTolerance: 5.0,
        minDensity: 0.5,
        rallyMaxGap: 4.0,
        rallyMinDuration: 2.0
    )

    // CPU detection
    let cpuDetector = HoughLinearityDetector()
    let cpuLines = cpuDetector.detect(points: points, config: config)

    // GPU detection
    guard let gpuDetector = try? HoughLinearityDetectorGPU() else {
        throw XCTSkip("Metal not available")
    }
    let gpuLines = try gpuDetector.detect(
        points: points,
        config: config,
        imageWidth: 300,
        imageHeight: 200
    )

    // Both should detect at least one line
    XCTAssertFalse(cpuLines.isEmpty, "CPU should detect lines")
    XCTAssertFalse(gpuLines.isEmpty, "GPU should detect lines")

    // The longest line from each should be similar in length
    if let cpuBest = cpuLines.max(by: { $0.length < $1.length }),
       let gpuBest = gpuLines.max(by: { $0.length < $1.length }) {
        XCTAssertEqual(cpuBest.length, gpuBest.length, accuracy: 20, "Line lengths should be similar")
    }
}
```

**Step 2: Run the comparison test**

```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/HoughLinearityDetectorTests/testGPUvsCPUProducesSimilarResults
```

**Step 3: Commit**

```bash
git add app/SportCrunchTests/HoughLinearityDetectorTests.swift
git commit -m "test(hough): add CPU vs GPU comparison test

Verifies GPU detector produces similar results to CPU detector

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Final Verification and Cleanup

**Step 1: Run full test suite**

```bash
cd /Users/rohit/Documents/sportcrunch/app && xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests
```

Expected: All tests pass

**Step 2: Test with actual video (manual)**

Build and run the app, process a tennis video with the Hough method. Verify:
- Processing completes (doesn't hang)
- Reasonable performance (should be much faster than before)
- Detected rallies are reasonable

**Step 3: Delete the old CPU-only detector if GPU works well**

If GPU is working correctly, the old `HoughLinearityDetector.swift` can be kept as fallback or removed:

```bash
# Optional: Remove if GPU is stable
# git rm app/methods/hough/HoughLinearityDetector.swift
# git commit -m "chore(hough): remove CPU detector (GPU is primary)"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Metal shaders | `HoughShaders.metal` |
| 2 | GPU pipeline manager | `HoughGPU.swift` |
| 3 | GPU linearity detector | `HoughLinearityDetectorGPU.swift` |
| 4 | Integrate into HoughMethod | `HoughMethod.swift` |
| 5 | GPU unit tests | `HoughGPUTests.swift` |
| 6 | CPU vs GPU comparison test | `HoughLinearityDetectorTests.swift` |
| 7 | Final verification | Run all tests |

**Expected Performance Improvement:**
- Before: O(N³) - hangs on 100k points
- After: O(N) GPU + O(accumulator) CPU - processes 100k points in <100ms
