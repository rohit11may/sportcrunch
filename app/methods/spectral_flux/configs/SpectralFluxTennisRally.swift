//
//  SpectralFluxTennisRally.swift
//  SportCrunch
//
//  Tennis Rally Mode: Groups consecutive shots into rallies with longer padding
//

import Foundation

struct SpectralFluxTennisRallyConfig {
    static let instance = SpectralFluxMethodConfig(
        sampleRate: 16000,
        bandpassLow: 200,
        bandpassHigh: 3000,
        audioThresholdMultiplier: 2.0,
        peakMinDistance: 0.5,
        clusterMaxGapSec: 3.0,
        clusterMinHits: 2,
        paddingPreSec: 2.0,
        paddingPostSec: 2.0,
        videoSampleStride: 15,
        videoThumbWidth: 160,
        videoThumbHeight: 90,
        motionPixelThreshold: 10,
        motionThreshold: 50.0
    )
}
