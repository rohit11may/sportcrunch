//
//  RunStatusRow.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import SwiftUI

/// Individual run status row component displaying run information
struct RunStatusRow: View {
    let run: Run

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: run.status == .running ? 2 : 0)
                        .scaleEffect(run.status == .running ? 1.5 : 1)
                        .opacity(run.status == .running ? 0 : 1)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: run.status == .running)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Run ID (truncated)
                    Text(run.id.uuidString.prefix(8))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    // Method name
                    Text(run.method)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // Sport + mode
                    Text(sportDisplayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    // Created time (relative)
                    Text(relativeTimeText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // Duration (if completed)
                    if let duration = durationText {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Segment count (if completed)
                    if let segments = run.segments {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(segments.count) segments")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch run.status {
        case .queued:
            return .gray
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var sportDisplayText: String {
        if let mode = run.sportMode {
            return "\(run.sport)/\(mode)"
        } else {
            return run.sport
        }
    }

    private var relativeTimeText: String {
        let interval = Date().timeIntervalSince(run.createdAt)

        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }

    private var durationText: String? {
        guard let startedAt = run.startedAt,
              let completedAt = run.completedAt else {
            return nil
        }

        let duration = completedAt.timeIntervalSince(startedAt)

        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            return String(format: "%.1fm", duration / 60)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        RunStatusRow(run: Run(
            status: .queued,
            videoPath: "/path/to/video.mov",
            method: "SpectralFlux",
            sport: "tennis",
            sportMode: "rally"
        ))
        .padding(.horizontal)

        Divider()

        RunStatusRow(run: {
            var run = Run(
                status: .running,
                videoPath: "/path/to/video.mov",
                method: "SpectralFlux",
                sport: "tennis",
                sportMode: "rally"
            )
            run.startedAt = Date().addingTimeInterval(-30)
            return run
        }())
        .padding(.horizontal)

        Divider()

        RunStatusRow(run: {
            var run = Run(
                status: .completed,
                videoPath: "/path/to/video.mov",
                method: "SpectralFlux",
                sport: "tennis",
                sportMode: "rally"
            )
            run.startedAt = Date().addingTimeInterval(-60)
            run.completedAt = Date()
            run.segments = [
                ExportedSegment(startTime: 0, endTime: 10),
                ExportedSegment(startTime: 15, endTime: 25),
                ExportedSegment(startTime: 30, endTime: 40)
            ]
            return run
        }())
        .padding(.horizontal)

        Divider()

        RunStatusRow(run: {
            var run = Run(
                status: .failed,
                videoPath: "/path/to/video.mov",
                method: "SpectralFlux",
                sport: "tennis",
                sportMode: "rally"
            )
            run.error = "File not found"
            return run
        }())
        .padding(.horizontal)
    }
}
