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
    private var gpuDetector: HoughLinearityDetectorGPU?
    private let cpuDetector = HoughLinearityDetector()
    private var useGPU: Bool = true
    private let tracker = HoughTracker()

    /// Frame stride: process every Nth frame to reduce overhead.
    /// At 30fps, stride of 2 = 15 effective fps, stride of 3 = 10 effective fps.
    private let frameStride: Int = 2

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

    func detectSegments(videoURL: URL, observation: RunObservation?) async throws -> [ActionSegment] {
        print("⚙️ [HoughMethod] Starting detection for \(videoURL.lastPathComponent)")

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // Properly handle missing video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            print("⚙️ [HoughMethod] ❌ No video track found")
            throw HoughMethodError.noVideoTrack
        }

        let duration = try await asset.load(.duration).seconds
        let fps = try await videoTrack.load(.nominalFrameRate)
        let timescale = try await videoTrack.load(.naturalTimeScale)

        print("⚙️ [HoughMethod] ✓ Video loaded: \(videoURL.lastPathComponent)")
        print("⚙️ [HoughMethod]   Duration: \(String(format: "%.2f", duration))s")
        print("⚙️ [HoughMethod]   FPS: \(fps), Stride: \(frameStride) (effective: \(String(format: "%.1f", Double(fps) / Double(frameStride))) fps)")

        // Reset processor for new video
        await processor.reset()

        var allDetections: [TimestampedLine] = []
        var frameIndex = 0
        var processedFrames = 0
        var frameErrors = 0
        var totalMotionPoints = 0
        var totalLines = 0

        print("⚙️ [HoughMethod] Starting frame processing...")

        // Processing loop with frame stride to reduce actor hops
        while Double(frameIndex) / Double(fps) < duration {
            let timeSec = Double(frameIndex) / Double(fps)
            let time = CMTime(seconds: timeSec, preferredTimescale: timescale)

            do {
                let (image, actualTime) = try await generator.image(at: time)
                let actualTimeSec = actualTime.seconds

                // 1. Process Motion (actor call)
                let points = try await processor.process(frame: image, config: config)
                totalMotionPoints += points.count

                // 2. Detect Lines (GPU with CPU fallback)
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
                totalLines += lines.count

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

                // Log progress every 30 frames
                if processedFrames % 30 == 0 {
                    print("⚙️ [HoughMethod] Processing: \(String(format: "%.1f", timeSec))s / \(String(format: "%.2f", duration))s (\(processedFrames) frames)")
                }

            } catch {
                // Log but continue processing
                frameErrors += 1
                print("⚙️ [HoughMethod] ⚠️ Frame \(frameIndex) error: \(error.localizedDescription)")
            }

            frameIndex += frameStride
        }

        print("⚙️ [HoughMethod] ✓ Frame processing complete")
        print("⚙️ [HoughMethod]   Processed: \(processedFrames) frames")
        if frameErrors > 0 {
            print("⚙️ [HoughMethod]   Errors: \(frameErrors) frames")
        }
        print("⚙️ [HoughMethod]   Motion points detected: \(totalMotionPoints)")
        print("⚙️ [HoughMethod]   Line streaks detected: \(totalLines)")

        guard totalLines > 0 else {
            print("⚙️ [HoughMethod] ❌ No line streaks detected")
            throw HoughMethodError.processingFailed("No motion linearity detected in video")
        }

        print("⚙️ [HoughMethod] Grouping \(allDetections.count) detections into rallies...")

        let rallies = tracker.groupRallies(detections: allDetections, config: config)

        guard !rallies.isEmpty else {
            print("⚙️ [HoughMethod] ❌ No rallies grouped from detections")
            throw HoughMethodError.processingFailed("Failed to group detections into rallies")
        }

        print("⚙️ [HoughMethod] ✓ Grouped into \(rallies.count) rallies")
        for (i, rally) in rallies.enumerated() {
            let duration = rally.duration
            print("⚙️ [HoughMethod]   Rally \(i + 1): \(String(format: "%.2f", rally.startTime))s - \(String(format: "%.2f", rally.endTime))s (\(String(format: "%.2f", duration))s)")
        }

        return rallies
    }
}
