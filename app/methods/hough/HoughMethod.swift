//
//  HoughMethod.swift
//  SportCrunch
//
//  Hough-based tennis ball tracking using motion differencing and linearity detection.
//  Uses high-performance AVAssetReader for sequential frame access.
//

import AVFoundation
import CoreVideo
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
    private let debugRenderer = HoughDebugRenderer()
    private var lastArtifactTime: TimeInterval = -1.0
    private var lastDetectionTime: TimeInterval = -1.0

    /// Temporary artifact files (artifact ID -> file URL).
    /// Stored here so RunExecutor can access them for export.
    private(set) var tempArtifactPaths: [String: URL] = [:]

    /// Target effective fps for processing. Motion streak detection works well at 8-12 fps.
    /// The actual stride is calculated dynamically based on source video fps.
    private let targetEffectiveFPS: Double = 10.0

    /// Target resolution for processing. 720p provides good balance of speed and quality.
    private let targetResolution: HoughVideoReader.Resolution? = .hd720

    /// Calculate optimal frame stride based on source fps to achieve target effective fps.
    private func calculateStride(sourceFPS: Float) -> Int {
        let stride = Int(round(Double(sourceFPS) / targetEffectiveFPS))
        // Clamp to reasonable range: at least 1 (process all), at most fps/4 (minimum 4 effective fps)
        return max(1, min(stride, Int(sourceFPS) / 4))
    }

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
        let startTime = CFAbsoluteTimeGetCurrent()
        print("⚙️ [HoughMethod] Starting detection for \(videoURL.lastPathComponent)")

        // Create high-performance video reader
        let videoReader: HoughVideoReader
        do {
            videoReader = try await HoughVideoReader(url: videoURL, targetResolution: targetResolution)
        } catch {
            print("⚙️ [HoughMethod] ❌ Failed to create video reader: \(error.localizedDescription)")
            throw HoughMethodError.noVideoTrack
        }

        // Calculate optimal stride based on source fps
        let frameStride = calculateStride(sourceFPS: videoReader.fps)
        let effectiveFPS = Double(videoReader.fps) / Double(frameStride)

        let resolutionDesc = targetResolution.map { "\($0.width)x\($0.height)" } ?? "native"
        print("⚙️ [HoughMethod] ✓ Video loaded: \(videoURL.lastPathComponent)")
        print("⚙️ [HoughMethod]   Duration: \(String(format: "%.2f", videoReader.duration))s")
        print("⚙️ [HoughMethod]   Native: \(Int(videoReader.naturalSize.width))x\(Int(videoReader.naturalSize.height)) @ \(String(format: "%.1f", videoReader.fps))fps")
        print("⚙️ [HoughMethod]   Processing: \(resolutionDesc), stride \(frameStride) (effective: \(String(format: "%.1f", effectiveFPS)) fps)")

        // Reset processor for new video
        processor.reset()

        var allDetections: [TimestampedLine] = []
        var processedFrames = 0
        var frameErrors = 0
        var skippedFrames = 0
        var totalMotionPoints = 0
        var totalLines = 0
        var lastProgressTime: TimeInterval = 0

        // Threshold for skipping frames - 2x the max is likely camera shake/scene change
        let skipThreshold = config.maxMotionPoints * 2

        print("⚙️ [HoughMethod] Starting frame processing (using AVAssetReader)...")
        print("⚙️ [HoughMethod]   Max motion points: \(config.maxMotionPoints), skip threshold: \(skipThreshold)")

        // Process frames using high-performance sequential reader
        try await videoReader.processFrames(stride: frameStride) { [self] frame in
            do {
                // Timing for bottleneck analysis
                let frameStart = CFAbsoluteTimeGetCurrent()

                // 1. Process Motion
                let motionStart = CFAbsoluteTimeGetCurrent()
                // Use pixel buffer directly
                let rawPoints = try processor.process(frame: frame.pixelBuffer, config: config)
                let motionTime = CFAbsoluteTimeGetCurrent() - motionStart
                totalMotionPoints += rawPoints.count

                // 2. Skip frames with excessive motion (camera shake, scene changes)
                if rawPoints.count > skipThreshold {
                    skippedFrames += 1
                    processedFrames += 1
                    return true // Skip this frame but continue processing
                }

                // 3. Cap points to maxMotionPoints for performance
                let points: [MotionPoint]
                if rawPoints.count > config.maxMotionPoints {
                    // Sample evenly across all points to maintain spatial distribution
                    let step = rawPoints.count / config.maxMotionPoints
                    points = stride(from: 0, to: rawPoints.count, by: step).prefix(config.maxMotionPoints).map { rawPoints[$0] }
                } else {
                    points = rawPoints
                }

                // 4. Detect Lines (GPU with CPU fallback)
                let detectStart = CFAbsoluteTimeGetCurrent()
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
                let detectTime = CFAbsoluteTimeGetCurrent() - detectStart
                totalLines += lines.count

                // Log detailed timing every 50 frames
                if processedFrames % 50 == 0 && processedFrames > 0 {
                    let frameTotal = CFAbsoluteTimeGetCurrent() - frameStart
                    let cappedInfo = rawPoints.count > config.maxMotionPoints ? " (capped from \(rawPoints.count))" : ""
                    print("⚙️ [HoughMethod] Frame \(processedFrames) timing: motion=\(String(format: "%.1f", motionTime * 1000))ms, detect=\(String(format: "%.1f", detectTime * 1000))ms, total=\(String(format: "%.1f", frameTotal * 1000))ms, points=\(points.count)\(cappedInfo)")
                }

                // 3. Record detections for tracking
                for line in lines {
                    allDetections.append(TimestampedLine(line: line, time: frame.time))
                }

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

                processedFrames += 1

                // Log progress every 2 seconds of video time
                if frame.time - lastProgressTime >= 2.0 {
                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    let speed = frame.time / elapsed
                    print("⚙️ [HoughMethod] Processing: \(String(format: "%.1f", frame.time))s / \(String(format: "%.1f", videoReader.duration))s (\(String(format: "%.1f", speed))x realtime)")
                    lastProgressTime = frame.time
                }

            } catch {
                frameErrors += 1
                if frameErrors <= 5 {
                    print("⚙️ [HoughMethod] ⚠️ Frame \(frame.frameIndex) error: \(error.localizedDescription)")
                }
            }

            return true // Continue processing
        }

        let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let processingSpeed = videoReader.duration / totalElapsed

        print("⚙️ [HoughMethod] ✓ Frame processing complete")
        print("⚙️ [HoughMethod]   Processed: \(processedFrames) frames in \(String(format: "%.1f", totalElapsed))s")
        print("⚙️ [HoughMethod]   Speed: \(String(format: "%.1f", processingSpeed))x realtime")
        if skippedFrames > 0 {
            print("⚙️ [HoughMethod]   Skipped: \(skippedFrames) frames (excessive motion)")
        }
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
