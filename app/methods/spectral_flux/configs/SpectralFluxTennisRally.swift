//
//  SpectralFluxTennisRally.swift
//  SportCrunch
//
//  Tennis Rally Mode: Groups consecutive shots into rallies with longer padding
//

import Foundation

struct SpectralFluxTennisRallyConfig {
    static let instance = SpectralFluxMethodConfig(
        audioThresholdMultiplier: 2.0,
        peakMinDistance: 0.5,
        clusterMaxGapSec: 3.0,
        clusterMinHits: 2,
        paddingPreSec: 2.0,
        paddingPostSec: 2.0,
        motionThreshold: 50.0
    )
}
