//
//  SpectralFluxTennisIndividual.swift
//  SportCrunch
//
//  Tennis Individual Mode: Detects individual shots with shorter padding
//

import Foundation

struct SpectralFluxTennisIndividualConfig {
    static let instance = SpectralFluxMethodConfig(
        audioThresholdMultiplier: 2.0,
        peakMinDistance: 0.5,
        clusterMaxGapSec: 1.0,
        clusterMinHits: 1,
        paddingPreSec: 0.5,
        paddingPostSec: 0.5,
        motionThreshold: 50.0
    )
}
