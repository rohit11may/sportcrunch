//
//  HoughTracker.swift
//  SportCrunch
//
//  Groups streak detections into rally segments based on temporal proximity.
//

import Foundation

/// Groups streak detections into rally segments based on temporal proximity.
struct HoughTracker: Sendable {

    /// Group detections into rallies based on temporal gaps.
    /// - Parameters:
    ///   - detections: Array of timestamped line detections
    ///   - config: Configuration with gap and duration thresholds
    /// - Returns: Array of ActionSegments representing detected rallies
    func groupRallies(detections: [TimestampedLine], config: HoughMethodConfig) -> [ActionSegment] {
        guard !detections.isEmpty else { return [] }

        let sorted = detections.sorted { $0.time < $1.time }
        var rallies: [ActionSegment] = []

        var currentStart = sorted[0].time
        var currentEnd = sorted[0].time

        for i in 1..<sorted.count {
            let detection = sorted[i]
            let gap = detection.time - currentEnd

            if gap <= config.rallyMaxGap {
                // Extend rally
                currentEnd = detection.time
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
                }

                // Start new rally
                currentStart = detection.time
                currentEnd = detection.time
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
        }

        return rallies
    }
}
