//
//  SpectralFluxMethodConfig.swift
//  SportCrunch
//
//  Configuration parameters for spectral flux detection.
//

import Foundation

struct SpectralFluxMethodConfig: Sendable {
    // MARK: - Audio Processing

    /// Target sample rate for audio extraction (Hz)
    let sampleRate: Double

    /// Bandpass filter lower frequency cutoff (Hz)
    let bandpassLow: Double

    /// Bandpass filter upper frequency cutoff (Hz)
    let bandpassHigh: Double

    // MARK: - Onset Detection

    /// Multiplier for spectral flux threshold detection
    /// Higher = more conservative, fewer false positives
    let audioThresholdMultiplier: Double

    /// Minimum time distance between detected peaks (seconds)
    let peakMinDistance: Double

    // MARK: - Clustering

    /// Maximum gap between hits to group into same cluster (seconds)
    let clusterMaxGapSec: Double

    /// Minimum hits required for a cluster to be valid
    let clusterMinHits: Int

    // MARK: - Padding

    /// Seconds to add before detected segment start
    let paddingPreSec: Double

    /// Seconds to add after detected segment end
    let paddingPostSec: Double

    // MARK: - Visual Validation

    /// Frames to skip during motion analysis (higher = faster)
    let videoSampleStride: Int

    /// Thumbnail width for motion analysis
    let videoThumbWidth: Int

    /// Thumbnail height for motion analysis
    let videoThumbHeight: Int

    /// Pixel intensity difference to count as motion (0-255)
    let motionPixelThreshold: Int

    /// Motion threshold for visual validation (nil = audio-only mode)
    let motionThreshold: Double?
}
