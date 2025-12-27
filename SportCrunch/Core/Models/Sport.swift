//
//  Sport.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

// MARK: - Sport Mode Protocol

/// Protocol for sport-specific modes (e.g., Tennis Rally vs Individual)
protocol SportMode: Identifiable, Codable, CaseIterable, Hashable {
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var iconName: String { get }
}

// MARK: - Tennis Mode

/// Tennis-specific detection modes
enum TennisMode: String, SportMode, CaseIterable, Codable {
    case rally
    case individual
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rally: return "Rally Mode"
        case .individual: return "Shot Mode"
        }
    }
    
    var description: String {
        switch self {
        case .rally: return "Groups consecutive shots into rallies"
        case .individual: return "Captures each shot separately"
        }
    }
    
    var iconName: String {
        switch self {
        case .rally: return "arrow.left.arrow.right"
        case .individual: return "circlebadge"
        }
    }
}

// MARK: - Sport Mode Wrapper

/// Type-erased wrapper for sport modes to enable storage in Project
enum SportModeWrapper: Codable, Equatable {
    case tennis(TennisMode)
    
    var displayName: String {
        switch self {
        case .tennis(let mode): return mode.displayName
        }
    }
    
    // Coding keys for polymorphic encoding
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "tennis":
            let mode = try container.decode(TennisMode.self, forKey: .value)
            self = .tennis(mode)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unknown sport mode type: \(type)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .tennis(let mode):
            try container.encode("tennis", forKey: .type)
            try container.encode(mode, forKey: .value)
        }
    }
}

// MARK: - Analysis Preset

/// Configurable parameters for audio and video analysis.
/// Each sport has a tuned preset for optimal detection.
/// Settings match the Python prototype in config/settings.py
struct AnalysisPreset {
    
    // MARK: - Audio Processing
    
    /// Target sample rate for audio extraction (Hz)
    let sampleRate: Double
    
    /// Bandpass filter lower frequency cutoff (Hz) - removes wind rumble
    let bandpassLow: Double
    
    /// Bandpass filter upper frequency cutoff (Hz) - preserves impact sounds
    let bandpassHigh: Double
    
    // MARK: - Onset Detection
    
    /// Multiplier for adaptive threshold: threshold = mean + λ * std
    /// Lower values = more sensitive (detects quieter hits)
    /// Typical range: 0.5 (very sensitive) to 3.0 (strict)
    let onsetThresholdLambda: Float
    
    /// Minimum seconds between detected hits (prevents double-counting echoes)
    let peakMinDistanceSec: Double
    
    // MARK: - Rally Clustering
    
    /// Maximum gap (seconds) between hits to consider them part of same rally
    let clusterMaxGapSec: Double
    
    /// Minimum number of hits required to consider a valid action segment
    let clusterMinHits: Int
    
    // MARK: - Segment Padding
    
    /// Seconds to add before first hit in a segment (captures lead-up)
    let paddingPreSec: Double
    
    /// Seconds to add after last hit in a segment (captures follow-through)
    let paddingPostSec: Double
    
    // MARK: - Video Motion Validation
    
    /// Whether to skip visual validation entirely (audio-only mode)
    let skipVisualValidation: Bool
    
    /// Frames to skip during motion analysis (higher = faster, less accurate)
    let videoSampleStride: Int
    
    /// Thumbnail size for motion analysis (width x height)
    let videoThumbSize: (width: Int, height: Int)
    
    /// Pixel intensity difference to count as motion (0-255)
    let motionPixelThreshold: Int
    
    /// Minimum motion pixels required to consider segment "active"
    let motionAreaThreshold: Double
}

// MARK: - Sport Enum

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
    
    /// Whether this sport is coming soon and should be disabled
    var isComingSoon: Bool {
        switch self {
        case .tennis: return false
        case .cricket: return true
        }
    }
    
    // MARK: - Sport Modes
    
    /// Whether this sport has selectable modes
    var hasModes: Bool {
        switch self {
        case .tennis: return true
        case .cricket: return false
        }
    }
    
    /// Available modes for this sport (empty if no modes)
    var availableTennisModes: [TennisMode] {
        switch self {
        case .tennis: return TennisMode.allCases
        case .cricket: return []
        }
    }
    
    /// Default mode for sports that have modes
    var defaultTennisMode: TennisMode? {
        switch self {
        case .tennis: return .rally
        case .cricket: return nil
        }
    }
    
    // MARK: - Analysis Preset
    
    /// Returns the default analysis preset for this sport.
    /// For sports with modes (like Tennis), use preset(for:) instead.
    var preset: AnalysisPreset {
        preset(for: nil)
    }
    
    /// Returns the tuned analysis preset for this sport and optional mode.
    /// - Parameter mode: Optional sport mode (e.g., TennisMode.rally or .individual)
    func preset(for mode: SportMode?) -> AnalysisPreset {
        switch self {
        case .tennis:
            // Check if we have a tennis mode specified
            if let tennisMode = mode as? TennisMode {
                return tennisPreset(for: tennisMode)
            }
            // Default to rally mode
            return tennisPreset(for: .rally)
            
        case .cricket:
            return cricketPreset()
        }
    }
    
    // MARK: - Tennis Presets
    
    /// Tennis Rally Mode preset - groups consecutive shots into rallies
    /// Settings match Python prototype in config/settings.py
    private func tennisPreset(for mode: TennisMode) -> AnalysisPreset {
        switch mode {
        case .rally:
            // Rally mode: Groups shots together into continuous rally clips
            return AnalysisPreset(
                // Audio Processing (matches prototype)
                sampleRate: 16000,          // AUDIO_SAMPLE_RATE
                bandpassLow: 200,           // BANDPASS_LOW - removes wind rumble
                bandpassHigh: 3000,         // BANDPASS_HIGH - preserves racket crack
                
                // Onset Detection (matches prototype)
                onsetThresholdLambda: 2.0,  // ONSET_THRESHOLD_LAMBDA - adaptive threshold multiplier
                peakMinDistanceSec: 0.5,    // PEAK_MIN_DISTANCE_SEC - min time between hits
                
                // Rally Clustering - AGGRESSIVE MERGING
                clusterMaxGapSec: 3.0,      // CLUSTER_MAX_GAP_SEC - max gap in same rally
                clusterMinHits: 2,          // CLUSTER_MIN_HITS - minimum hits for valid rally
                
                // Segment Padding (matches prototype)
                paddingPreSec: 2.0,         // PADDING_PRE_SEC - seconds before first hit
                paddingPostSec: 2.0,        // PADDING_POST_SEC - seconds after last hit
                
                // Video Motion Validation - ENABLED for tennis
                // OPTIMIZED: stride 15, thumbnail 160x90 for faster processing
                // Thresholds scaled for smaller thumbnail (160x90 = 14,400 pixels)
                skipVisualValidation: false,
                videoSampleStride: 15,
                videoThumbSize: (width: 160, height: 90),
                motionPixelThreshold: 10,
                motionAreaThreshold: 50
            )
            
        case .individual:
            // Individual/Shot mode: Each shot is a separate short clip
            // Short and snappy - 0.5s before and after each hit
            return AnalysisPreset(
                // Audio Processing (same as rally)
                sampleRate: 16000,
                bandpassLow: 200,
                bandpassHigh: 3000,
                
                // Onset Detection (same as rally)
                onsetThresholdLambda: 2.0,
                peakMinDistanceSec: 0.5,
                
                // Clustering - MINIMAL MERGING for individual shots
                clusterMaxGapSec: 1.0,      // Very short gap - only merge if shots are <1s apart
                clusterMinHits: 1,          // Single hit is valid (captures every shot)
                
                // Segment Padding - SHORT AND SNAPPY
                paddingPreSec: 0.5,         // 0.5s before hit
                paddingPostSec: 0.5,        // 0.5s after hit
                
                // Video Motion Validation - ENABLED for shot mode
                // OPTIMIZED: stride 15, thumbnail 160x90 for faster processing
                // Thresholds scaled for smaller thumbnail (160x90 = 14,400 pixels)
                skipVisualValidation: false,
                videoSampleStride: 15,
                videoThumbSize: (width: 160, height: 90),
                motionPixelThreshold: 10,
                motionAreaThreshold: 50
            )
        }
    }
    
    // MARK: - Cricket Preset
    
    private func cricketPreset() -> AnalysisPreset {
        return AnalysisPreset(
            // Audio Processing
            sampleRate: 16000,
            bandpassLow: 100,           // Lower for bat thud
            bandpassHigh: 4000,         // Wide range for different sounds
            
            // Onset Detection
            onsetThresholdLambda: 2.0,
            peakMinDistanceSec: 0.5,
            
            // Rally Clustering
            clusterMaxGapSec: 6.0,      // Cricket has longer pauses between deliveries
            clusterMinHits: 1,          // Single delivery events
            
            // Segment Padding
            paddingPreSec: 3.0,         // More lead-up for bowler run-up
            paddingPostSec: 3.0,        // More follow-through for replay
            
            // Video Motion Validation - Keep for cricket (different audio profile)
            // OPTIMIZED: stride 15, thumbnail 160x90 for faster processing
            // Thresholds scaled for smaller thumbnail (160x90 = 14,400 pixels)
            skipVisualValidation: false,
            videoSampleStride: 15,
            videoThumbSize: (width: 160, height: 90),
            motionPixelThreshold: 10,
            motionAreaThreshold: 50
        )
    }
    
    // MARK: - Convenience Accessors (deprecated - use preset instead)
    
    /// Bandpass filter lower frequency cutoff (Hz)
    @available(*, deprecated, message: "Use preset.bandpassLow instead")
    var audioLowCutoff: Double { preset.bandpassLow }
    
    /// Bandpass filter upper frequency cutoff (Hz)
    @available(*, deprecated, message: "Use preset.bandpassHigh instead")
    var audioHighCutoff: Double { preset.bandpassHigh }
    
    /// Maximum gap between hits to consider same rally (seconds)
    @available(*, deprecated, message: "Use preset.clusterMaxGapSec instead")
    var maxGapSeconds: Double { preset.clusterMaxGapSec }
    
    /// Minimum number of hits to consider a valid action segment
    @available(*, deprecated, message: "Use preset.clusterMinHits instead")
    var minHitsPerSegment: Int { preset.clusterMinHits }
}

