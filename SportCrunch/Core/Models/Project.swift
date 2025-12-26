//
//  Project.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import Foundation

/// Represents a highlight project created by the user
struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    let sport: Sport
    let createdAt: Date
    
    /// URL to the original source video
    let sourceVideoURL: URL
    
    /// URL to the generated highlight video (nil if not yet processed)
    var highlightVideoURL: URL?
    
    /// Duration of the original video in seconds
    let originalDuration: TimeInterval
    
    /// Duration of the highlight video in seconds (nil if not yet processed)
    var highlightDuration: TimeInterval?
    
    /// Processing status
    var status: ProcessingStatus
    
    /// Detected action segments (start, end times in seconds)
    var segments: [ActionSegment]
    
    /// Optional title for the project
    var title: String?
    
    /// Thumbnail image data (stored as base64 for simplicity)
    var thumbnailData: Data?
    
    /// Sport mode (e.g., Tennis Rally vs Individual)
    var sportMode: SportModeWrapper?
    
    init(
        id: UUID = UUID(),
        sport: Sport,
        sourceVideoURL: URL,
        originalDuration: TimeInterval,
        title: String? = nil,
        sportMode: SportModeWrapper? = nil
    ) {
        self.id = id
        self.sport = sport
        self.createdAt = Date()
        self.sourceVideoURL = sourceVideoURL
        self.originalDuration = originalDuration
        self.status = .pending
        self.segments = []
        self.title = title
        self.sportMode = sportMode
    }
    
    /// Formatted sport mode display name
    var formattedSportMode: String? {
        sportMode?.displayName
    }
    
    // MARK: - Computed Properties
    
    /// Time saved by the highlight
    var timeSaved: TimeInterval? {
        guard let highlightDuration else { return nil }
        return originalDuration - highlightDuration
    }
    
    /// Compression ratio (e.g., 0.15 means 15% of original)
    var compressionRatio: Double? {
        guard let highlightDuration, originalDuration > 0 else { return nil }
        return highlightDuration / originalDuration
    }
    
    /// Formatted original duration (e.g., "2h 15m")
    var formattedOriginalDuration: String {
        formatDuration(originalDuration)
    }
    
    /// Formatted highlight duration (e.g., "18m")
    var formattedHighlightDuration: String? {
        guard let highlightDuration else { return nil }
        return formatDuration(highlightDuration)
    }
    
    /// Formatted time saved (e.g., "1h 57m saved")
    var formattedTimeSaved: String? {
        guard let timeSaved else { return nil }
        return "\(formatDuration(timeSaved)) saved"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Processing Status

enum ProcessingStatus: String, Codable, Equatable {
    case pending
    case loadingVideo
    case analyzingAudio
    case detectingAction
    case creatingClips
    case exporting
    case completed
    case failed
    
    var displayText: String {
        switch self {
        case .pending: return "Waiting..."
        case .loadingVideo: return "Loading video..."
        case .analyzingAudio: return "Analyzing audio..."
        case .detectingAction: return "Detecting action..."
        case .creatingClips: return "Creating clips..."
        case .exporting: return "Exporting..."
        case .completed: return "Complete"
        case .failed: return "Failed"
        }
    }
    
    var progress: Double {
        switch self {
        case .pending: return 0.0
        case .loadingVideo: return 0.10
        case .analyzingAudio: return 0.25
        case .detectingAction: return 0.50
        case .creatingClips: return 0.75
        case .exporting: return 0.90
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }
    
    var isProcessing: Bool {
        switch self {
        case .pending, .loadingVideo, .analyzingAudio, .detectingAction, .creatingClips, .exporting:
            return true
        case .completed, .failed:
            return false
        }
    }
}

// MARK: - Action Segment

/// Represents a detected action segment in the video
struct ActionSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    
    /// Confidence score (0.0 to 1.0)
    let confidence: Double
    
    /// Whether this segment is included in the final highlight
    var isIncluded: Bool
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double = 1.0,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.isIncluded = isIncluded
    }
}

// MARK: - Sample Data

extension Project {
    static let sampleTennis = Project(
        sport: .tennis,
        sourceVideoURL: URL(fileURLWithPath: "/sample/tennis.mov"),
        originalDuration: 7200, // 2 hours
        title: "Morning Practice"
    )
    
    static let sampleCricket = Project(
        sport: .cricket,
        sourceVideoURL: URL(fileURLWithPath: "/sample/cricket.mov"),
        originalDuration: 10800, // 3 hours
        title: "Weekend Match"
    )
    
    static var sampleCompleted: Project {
        var project = sampleTennis
        project.status = .completed
        project.highlightDuration = 1080 // 18 minutes
        project.highlightVideoURL = URL(fileURLWithPath: "/sample/tennis_highlights.mov")
        project.segments = [
            ActionSegment(startTime: 120, endTime: 180),
            ActionSegment(startTime: 300, endTime: 420),
            ActionSegment(startTime: 600, endTime: 720),
        ]
        return project
    }
}

