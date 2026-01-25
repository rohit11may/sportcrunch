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
    let method: String
    let config: String
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
        method: String,
        config: String
    ) {
        self.id = id
        self.status = status
        self.videoPath = videoPath
        self.method = method
        self.config = config
        self.createdAt = Date()
    }
}
