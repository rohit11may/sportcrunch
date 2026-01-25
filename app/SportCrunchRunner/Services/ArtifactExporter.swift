//
//  ArtifactExporter.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation

/// Exports run artifacts (segments.json, highlight video) to shared filesystem
class ArtifactExporter {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let baseDirectory: URL

    // MARK: - Initialization

    init() {
        // Use Documents directory for simulator (maps to Mac filesystem)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.baseDirectory = documentsURL
            .appendingPathComponent("SportCrunchRunner", isDirectory: true)
            .appendingPathComponent("Runs", isDirectory: true)

        // Create base directory if it doesn't exist
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        print("📦 [ArtifactExporter] Base directory: \(baseDirectory.path)")
    }

    // MARK: - Export

    /// Export run artifacts to filesystem
    /// - Parameters:
    ///   - run: The run to export artifacts for
    ///   - segments: Detected segments to write to JSON
    ///   - highlightURL: Optional URL to highlight video (will be copied)
    /// - Returns: Artifact paths for the exported files
    func export(
        run: Run,
        segments: [ExportedSegment],
        highlightURL: URL?
    ) throws -> ArtifactPaths {
        // Create run directory
        let runDirectory = baseDirectory.appendingPathComponent(run.id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: runDirectory, withIntermediateDirectories: true)

        print("📦 [ArtifactExporter] Exporting artifacts for run \(run.id.uuidString)")
        print("📦 [ArtifactExporter] Run directory: \(runDirectory.path)")

        // Generate filename with timestamp and method
        let timestamp = formatTimestamp(run.createdAt)
        let methodName = run.method

        // Export segments.json
        let segmentsFilename = "\(timestamp)-\(methodName)-segments.json"
        let segmentsURL = runDirectory.appendingPathComponent(segmentsFilename)
        try exportSegmentsJSON(segments: segments, metadata: run, to: segmentsURL)
        print("📦 [ArtifactExporter] ✓ Wrote segments.json: \(segmentsFilename)")

        // Copy highlight video if provided
        var highlightPath: String?
        if let highlightURL = highlightURL, fileManager.fileExists(atPath: highlightURL.path) {
            let highlightFilename = "highlight.mp4"
            let destinationURL = runDirectory.appendingPathComponent(highlightFilename)

            // Remove existing file if present
            try? fileManager.removeItem(at: destinationURL)

            try fileManager.copyItem(at: highlightURL, to: destinationURL)
            highlightPath = destinationURL.path
            print("📦 [ArtifactExporter] ✓ Copied highlight video: \(highlightFilename)")
        }

        return ArtifactPaths(
            segmentsJSON: segmentsURL.path,
            highlightVideo: highlightPath
        )
    }

    // MARK: - Private Helpers

    private func exportSegmentsJSON(segments: [ExportedSegment], metadata: Run, to url: URL) throws {
        let json: [String: Any] = [
            "segments": segments.map { segment in
                [
                    "startTime": segment.startTime,
                    "endTime": segment.endTime,
                    "type": segment.type
                ]
            },
            "metadata": [
                "runId": metadata.id.uuidString,
                "method": metadata.method,
                "config": metadata.config,
                "videoPath": metadata.videoPath,
                "createdAt": ISO8601DateFormatter().string(from: metadata.createdAt),
                "completedAt": metadata.completedAt.map { ISO8601DateFormatter().string(from: $0) } as Any
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
