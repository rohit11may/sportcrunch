//
//  HoughMotionProcessor.swift
//  SportCrunch
//
//  Handles frame buffering and motion mask generation using Accelerate framework.
//  Uses 3-frame differencing for better noise rejection than 2-frame.
//

import Accelerate
import CoreGraphics
import CoreVideo
import Foundation
import simd

// MARK: - Cached Resources

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
///
/// Note: This is a class (not actor) for performance. It should be used
/// from a single context (e.g., the video processing loop).
final class HoughMotionProcessor: @unchecked Sendable {
    private var buffers: MotionBuffers?
    private var frameCount: Int = 0

    // Timing accumulators for analysis
    private var grayscaleTime: Double = 0
    private var vdspTime: Double = 0
    private var extractTime: Double = 0
    private var timingFrameCount: Int = 0

    /// Process a new frame and return the motion mask points.
    /// Returns empty array for first 2 frames (need 3 frames for differencing).
    func process(frame: CVPixelBuffer, config: HoughMethodConfig) throws -> [MotionPoint] {
        let width = CVPixelBufferGetWidthOfPlane(frame, 0)
        let height = CVPixelBufferGetHeightOfPlane(frame, 0)
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

        // 1. Convert current frame to grayscale using fast memory copy
        let grayStart = CFAbsoluteTimeGetCurrent()
        try extractGrayscale(from: frame, into: &buffers.currentGray, width: width, height: height)
        grayscaleTime += CFAbsoluteTimeGetCurrent() - grayStart

        frameCount += 1

        // Need at least 3 frames for 3-frame differencing
        guard frameCount >= 3 else {
            return []
        }

        // 2. Convert UInt8 arrays to Float for vDSP operations
        let vdspStart = CFAbsoluteTimeGetCurrent()
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
        vdspTime += CFAbsoluteTimeGetCurrent() - vdspStart

        // 7. Extract motion points using SIMD-accelerated scanning
        let extractStart = CFAbsoluteTimeGetCurrent()
        let points = extractMotionPointsSIMD(
            from: buffers.intersection,
            width: width,
            height: height,
            reserveCapacity: config.minMotionArea
        )
        extractTime += CFAbsoluteTimeGetCurrent() - extractStart

        // Log timing breakdown every 100 frames
        timingFrameCount += 1
        if timingFrameCount % 100 == 0 {
            let avgGray = grayscaleTime / Double(timingFrameCount) * 1000
            let avgVDSP = vdspTime / Double(timingFrameCount) * 1000
            let avgExtract = extractTime / Double(timingFrameCount) * 1000
            print("⚙️ [MotionProcessor] Avg timing over \(timingFrameCount) frames: grayscale=\(String(format: "%.2f", avgGray))ms, vDSP=\(String(format: "%.2f", avgVDSP))ms, extract=\(String(format: "%.2f", avgExtract))ms")
        }

        return points
    }

    /// Reset the processor state (e.g., when switching videos)
    func reset() {
        buffers = nil
        frameCount = 0
    }

    // MARK: - Private Helpers

    /// Extract grayscale pixel values from a CVPixelBuffer into a pre-allocated buffer.
    /// Reads directly from the Y-plane (plane 0) to avoid color conversion overhead.
    private func extractGrayscale(from pixelBuffer: CVPixelBuffer, into buffer: inout [UInt8], width: Int, height: Int) throws {
        let pixelCount = width * height

        if buffer.count != pixelCount {
            buffer = [UInt8](repeating: 0, count: pixelCount)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            throw HoughProcessorError.frameConversionFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let src = baseAddress.assumingMemoryBound(to: UInt8.self)

        buffer.withUnsafeMutableBufferPointer { dst in
            guard let dstBase = dst.baseAddress else { return }

            if bytesPerRow == width {
                // Fast path: contiguous copy
                dstBase.assign(from: src, count: pixelCount)
            } else {
                // Row-by-row copy to handle padding
                var dstPtr = dstBase
                var srcPtr = src
                for _ in 0..<height {
                    dstPtr.assign(from: srcPtr, count: width)
                    dstPtr = dstPtr.advanced(by: width)
                    srcPtr = srcPtr.advanced(by: bytesPerRow)
                }
            }
        }
    }

    /// Extract motion points using SIMD-accelerated scanning.
    /// Processes 8 floats at a time and skips zero chunks entirely.
    private func extractMotionPointsSIMD(
        from intersection: [Float],
        width: Int,
        height: Int,
        reserveCapacity: Int
    ) -> [MotionPoint] {
        var points: [MotionPoint] = []
        points.reserveCapacity(reserveCapacity)

        let pixelCount = width * height
        let simdWidth = 8 // Process 8 floats at a time
        let fullChunks = pixelCount / simdWidth

        intersection.withUnsafeBufferPointer { buffer in
            let basePtr = buffer.baseAddress!

            // Process full SIMD chunks
            for chunkIndex in 0..<fullChunks {
                let chunkOffset = chunkIndex * simdWidth

                // Load 8 floats into SIMD vector
                let chunk = simd_float8(
                    basePtr[chunkOffset],
                    basePtr[chunkOffset + 1],
                    basePtr[chunkOffset + 2],
                    basePtr[chunkOffset + 3],
                    basePtr[chunkOffset + 4],
                    basePtr[chunkOffset + 5],
                    basePtr[chunkOffset + 6],
                    basePtr[chunkOffset + 7]
                )

                // Quick check: if all zeros, skip this chunk entirely
                // simd_max returns the maximum component
                if simd_reduce_max(chunk) <= 0 {
                    continue
                }

                // At least one non-zero value, check individually
                for i in 0..<simdWidth {
                    if chunk[i] > 0 {
                        let pixelIndex = chunkOffset + i
                        let x = pixelIndex % width
                        let y = pixelIndex / width
                        points.append(MotionPoint(x: Double(x), y: Double(y)))
                    }
                }
            }

            // Handle remaining pixels (less than 8)
            let remainder = pixelCount % simdWidth
            let remainderStart = fullChunks * simdWidth
            for i in 0..<remainder {
                let pixelIndex = remainderStart + i
                if basePtr[pixelIndex] > 0 {
                    let x = pixelIndex % width
                    let y = pixelIndex / width
                    points.append(MotionPoint(x: Double(x), y: Double(y)))
                }
            }
        }

        return points
    }
}
