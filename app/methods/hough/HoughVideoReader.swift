//
//  HoughVideoReader.swift
//  SportCrunch
//
//  High-performance video frame reader using AVAssetReader for sequential access.
//  Replaces AVAssetImageGenerator which is designed for random access thumbnails.
//

import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

// MARK: - Errors

enum HoughVideoReaderError: Error, LocalizedError {
    case noVideoTrack
    case readerCreationFailed(String)
    case outputCreationFailed
    case readingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found in asset"
        case .readerCreationFailed(let reason):
            return "Failed to create asset reader: \(reason)"
        case .outputCreationFailed:
            return "Failed to create reader output"
        case .readingFailed(let reason):
            return "Reading failed: \(reason)"
        }
    }
}

// MARK: - Frame Result

struct VideoFrame {
    let pixelBuffer: CVPixelBuffer
    let time: TimeInterval
    let frameIndex: Int
}

// MARK: - HoughVideoReader

/// High-performance sequential video frame reader.
/// Uses AVAssetReader for 50-100x faster frame access compared to AVAssetImageGenerator.
final class HoughVideoReader {

    /// Target resolution for processing. nil means native resolution.
    struct Resolution {
        let width: Int
        let height: Int

        /// 720p - good balance of speed and quality for motion detection
        static let hd720 = Resolution(width: 1280, height: 720)

        /// 540p - faster processing, still good for streak detection
        static let qhd540 = Resolution(width: 960, height: 540)

        /// Native resolution (no scaling)
        static let native: Resolution? = nil
    }

    private let asset: AVURLAsset
    private let videoTrack: AVAssetTrack
    private var reader: AVAssetReader?
    private var output: AVAssetReaderTrackOutput?

    let duration: TimeInterval
    let fps: Float
    let timescale: CMTimeScale
    let naturalSize: CGSize
    let targetResolution: Resolution?

    // MARK: - Initialization

    init(url: URL, targetResolution: Resolution? = .hd720) async throws {
        self.asset = AVURLAsset(url: url)
        self.targetResolution = targetResolution

        // Load video track
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw HoughVideoReaderError.noVideoTrack
        }
        self.videoTrack = track

        // Load properties
        self.duration = try await asset.load(.duration).seconds
        self.fps = try await track.load(.nominalFrameRate)
        self.timescale = try await track.load(.naturalTimeScale)
        self.naturalSize = try await track.load(.naturalSize)
    }

    // MARK: - Frame Reading

    /// Process all frames with the given stride, calling the handler for each frame.
    /// This is much faster than random access because it uses sequential decoding.
    ///
    /// - Parameters:
    ///   - stride: Process every Nth frame (1 = all frames, 2 = every other, etc.)
    ///   - handler: Called for each processed frame. Return false to stop early.
    func processFrames(
        stride: Int = 1,
        handler: (VideoFrame) async throws -> Bool
    ) async throws {
        // Create reader
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw HoughVideoReaderError.readerCreationFailed(error.localizedDescription)
        }

        // Configure output settings
        // Use YUV (420v) to get the luminance plane directly without RGB conversion
        var outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]

        // Add scaling if target resolution specified
        if let target = targetResolution {
            // Calculate scaled size maintaining aspect ratio
            let scaledSize = calculateScaledSize(
                from: naturalSize,
                targetWidth: target.width,
                targetHeight: target.height
            )
            outputSettings[kCVPixelBufferWidthKey as String] = scaledSize.width
            outputSettings[kCVPixelBufferHeightKey as String] = scaledSize.height
        }

        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false  // Zero-copy when possible

        guard reader.canAdd(output) else {
            throw HoughVideoReaderError.outputCreationFailed
        }
        reader.add(output)

        // Start reading
        guard reader.startReading() else {
            let errorMsg = reader.error?.localizedDescription ?? "Unknown error"
            throw HoughVideoReaderError.readingFailed(errorMsg)
        }

        // Process frames
        var frameIndex = 0
        var processedCount = 0

        while let sampleBuffer = output.copyNextSampleBuffer() {
            defer { frameIndex += 1 }

            // Apply stride - skip frames we don't need
            if frameIndex % stride != 0 {
                continue
            }

            // Get timestamp
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let timeSeconds = presentationTime.seconds

            // Get PixelBuffer directly
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let frame = VideoFrame(
                pixelBuffer: pixelBuffer,
                time: timeSeconds,
                frameIndex: frameIndex
            )

            processedCount += 1

            // Call handler
            let shouldContinue = try await handler(frame)
            if !shouldContinue {
                break
            }
        }

        // Check for errors
        if reader.status == .failed {
            let errorMsg = reader.error?.localizedDescription ?? "Unknown error"
            throw HoughVideoReaderError.readingFailed(errorMsg)
        }
    }

    // MARK: - Private Helpers

    /// Calculate scaled size maintaining aspect ratio, fitting within target bounds.
    private func calculateScaledSize(from natural: CGSize, targetWidth: Int, targetHeight: Int) -> (width: Int, height: Int) {
        let widthRatio = CGFloat(targetWidth) / natural.width
        let heightRatio = CGFloat(targetHeight) / natural.height
        let scale = min(widthRatio, heightRatio, 1.0)  // Don't upscale

        // Ensure dimensions are even (required for video)
        let scaledWidth = Int(natural.width * scale) & ~1
        let scaledHeight = Int(natural.height * scale) & ~1

        return (max(scaledWidth, 2), max(scaledHeight, 2))
    }
}
