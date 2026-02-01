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

        // Log rally opened for first detection
        if let obs = observation {
            await obs.addEvent(
                name: "rally_opened",
                time: currentStart,
                metadata: ["start_time": String(format: "%.3f", currentStart)]
            )
            await obs.addSignalPoint(name: "rally_active", time: currentStart, value: 1.0)
        }

        for idx in 1..<sorted.count {
            let detection = sorted[idx]
            let gap = detection.time - currentEnd

            // Log gap signal
            if let obs = observation {
                await obs.addSignalPoint(name: "gap_since_detection", time: detection.time, value: gap)
            }

            if gap <= config.rallyMaxGap {
                // Extend rally
                currentEnd = detection.time
                currentDetectionCount += 1
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

        for idx in 1..<sorted.count {
            let detection = sorted[idx]
            let gap = detection.time - currentEnd

            // Log gap signal
            if let obs = observation {
                await obs.addSignalPoint(name: "gap_since_detection", time: detection.time, value: gap)
            }

            if gap <= shotWindow {
                // Same shot event - extend
                currentEnd = detection.time
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
