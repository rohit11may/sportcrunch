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
