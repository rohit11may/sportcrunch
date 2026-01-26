//
//  HoughMotionProcessor.swift
//  SportCrunch
//
//  Handles frame buffering and motion mask generation using Accelerate framework.
//  Uses 3-frame differencing for better noise rejection than 2-frame.
//

import Accelerate
import CoreGraphics
import Foundation

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
