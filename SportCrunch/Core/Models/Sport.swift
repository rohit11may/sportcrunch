//
//  Sport.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

/// Represents the supported sports for highlight detection
enum Sport: String, CaseIterable, Identifiable, Codable {
    case tennis
    case cricket
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tennis: return "Tennis"
        case .cricket: return "Cricket"
        }
    }
    
    var emoji: String {
        switch self {
        case .tennis: return "🎾"
        case .cricket: return "🏏"
        }
    }
    
    var description: String {
        switch self {
        case .tennis: return "Detects racket-ball impacts"
        case .cricket: return "Detects bat-ball contacts"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .tennis: return .scTennis
        case .cricket: return .scCricket
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .tennis: return AppGradient.tennis
        case .cricket: return AppGradient.cricket
        }
    }
    
    var iconName: String {
        switch self {
        case .tennis: return "figure.tennis"
        case .cricket: return "cricket.ball"
        }
    }
    
    // MARK: - Audio Detection Parameters (for future use)
    
    /// Bandpass filter lower frequency cutoff (Hz)
    var audioLowCutoff: Double {
        switch self {
        case .tennis: return 200
        case .cricket: return 150
        }
    }
    
    /// Bandpass filter upper frequency cutoff (Hz)
    var audioHighCutoff: Double {
        switch self {
        case .tennis: return 3000
        case .cricket: return 3500
        }
    }
    
    /// Maximum gap between hits to consider same rally (seconds)
    var maxGapSeconds: Double {
        switch self {
        case .tennis: return 3.0
        case .cricket: return 5.0
        }
    }
    
    /// Minimum number of hits to consider a valid action segment
    var minHitsPerSegment: Int {
        switch self {
        case .tennis: return 2
        case .cricket: return 1
        }
    }
}

