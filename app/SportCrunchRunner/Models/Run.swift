//
//  Run.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation

// MARK: - Run Status

/// Status of a segmentation run
enum RunStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
}

// MARK: - Exported Segment

/// Simplified segment for JSON export (subset of ActionSegment)
struct ExportedSegment: Codable, Sendable {
    let startTime: Double
    let endTime: Double
    let type: String

    init(startTime: Double, endTime: Double, type: String = "rally") {
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
    }
}

// MARK: - Artifact Paths

/// Paths to exported artifacts for a completed run
struct ArtifactPaths: Codable, Sendable {
    let segmentsJSON: String
    let highlightVideo: String?

    init(segmentsJSON: String, highlightVideo: String? = nil) {
        self.segmentsJSON = segmentsJSON
        self.highlightVideo = highlightVideo
    }
}

// MARK: - Run Model

/// Represents a segmentation run request and its lifecycle
struct Run: Identifiable, Codable, Sendable {
    let id: UUID
    var status: RunStatus
    let videoPath: String
    let sport: String
    let sportMode: String?
    let config: [String: String]
    let deviceTarget: DeviceTarget
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var segments: [ExportedSegment]?
    var artifactPaths: ArtifactPaths?
    var error: String?

    init(
        id: UUID = UUID(),
        status: RunStatus = .queued,
        videoPath: String,
        sport: String,
        sportMode: String? = nil,
        config: [String: String] = [:],
        deviceTarget: DeviceTarget = .simulator
    ) {
        self.id = id
        self.status = status
        self.videoPath = videoPath
        self.sport = sport
        self.sportMode = sportMode
        self.config = config
        self.deviceTarget = deviceTarget
        self.createdAt = Date()
    }
}
