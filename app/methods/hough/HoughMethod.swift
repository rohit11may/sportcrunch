//
//  HoughMethod.swift
//  SportCrunch
//
//  Hough-based tennis ball tracking using motion differencing and linearity detection.
//

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

// MARK: - Timestamped Detection

/// A line detection with its timestamp for temporal tracking.
struct TimestampedLine: Sendable {
    let line: LineSegment
    let time: TimeInterval
}

// MARK: - HoughMethod

final class HoughMethod: SegmentationMethod {
    let name = "Hough"
    private let config: HoughMethodConfig
    private let processor = HoughMotionProcessor()
    private let detector = HoughLinearityDetector()

    /// Frame stride: process every Nth frame to reduce overhead.
    /// At 30fps, stride of 2 = 15 effective fps, stride of 3 = 10 effective fps.
    private let frameStride: Int = 2

    init(config: HoughMethodConfig) {
        self.config = config
    }

    func detectSegments(videoURL: URL, observation: RunObservation?) async throws -> [ActionSegment] {
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
