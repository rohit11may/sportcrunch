//
//  Observation.swift
//  SportCrunch
//
//  Thread-safe observation recorder using Swift 6 actor isolation.
//  Stores downsampled signals (2 points/sec) and discrete events for debugging.
//

import Foundation

/// Thread-safe observation recorder using Swift 6 actor isolation.
/// Stores downsampled signals (2 points/sec) and discrete events for debugging.
public actor RunObservation {
    public struct SignalPoint: Codable, Sendable {
        public let time: TimeInterval
        public let value: Double

        public init(time: TimeInterval, value: Double) {
            self.time = time
            self.value = value
        }
    }

    public struct Event: Codable, Sendable {
        public let id: UUID
        public let timestamp: TimeInterval
        public let name: String
        public let metadata: [String: String]
        public let artifactId: String?

        public init(id: UUID = UUID(), timestamp: TimeInterval, name: String, metadata: [String: String] = [:], artifactId: String? = nil) {
            self.id = id
            self.timestamp = timestamp
            self.name = name
            self.metadata = metadata
            self.artifactId = artifactId
        }
    }

    private var signals: [String: [SignalPoint]] = [:]
    private var events: [Event] = []

    public init() {}

    /// Add signal point with automatic downsampling.
    /// Only records if sufficient time has passed since last point (2 points/sec = 0.5s threshold).
    public func addSignalPoint(name: String, time: TimeInterval, value: Double) {
        if signals[name] == nil {
            signals[name] = []
        }

        // Downsample: only add if 0.5s elapsed since last point (2 points/sec)
        if let lastPoint = signals[name]?.last, time - lastPoint.time < 0.5 {
            return
        }

        signals[name]?.append(SignalPoint(time: time, value: value))
    }

    public func addEvent(name: String, time: TimeInterval, metadata: [String: String] = [:], artifactId: String? = nil) {
        let event = Event(timestamp: time, name: name, metadata: metadata, artifactId: artifactId)
        events.append(event)
    }

    // MARK: - Snapshot Accessors (for export/encoding)

    public func getSignals() -> [String: [SignalPoint]] {
        return signals
    }

    public func getEvents() -> [Event] {
        return events
    }

    /// Create a codable snapshot for serialization.
    /// This avoids actor isolation issues with Codable conformance.
    public func snapshot() -> Snapshot {
        return Snapshot(signals: signals, events: events)
    }

    // MARK: - Codable Snapshot

    /// Sendable, codable snapshot of observation data.
    /// Use this for encoding/decoding instead of the actor itself.
    public struct Snapshot: Codable, Sendable {
        public let signals: [String: [SignalPoint]]
        public let events: [Event]

        public init(signals: [String: [SignalPoint]], events: [Event]) {
            self.signals = signals
            self.events = events
        }
    }
}
