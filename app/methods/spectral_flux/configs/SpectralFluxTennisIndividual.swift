//
//  SpectralFluxTennisIndividual.swift
//  SportCrunch
//
//  Tennis Individual Mode: Detects individual shots with shorter padding
//

import Foundation

struct SpectralFluxTennisIndividualConfig {
    static let instance = SpectralFluxMethodConfig(
        sampleRate: 16000,
        bandpassLow: 200,
        bandpassHigh: 3000,
        audioThresholdMultiplier: 2.0,
        peakMinDistance: 0.5,
        clusterMaxGapSec: 1.0,
        clusterMinHits: 1,
        paddingPreSec: 0.5,
        paddingPostSec: 0.5,
        videoSampleStride: 15,
        videoThumbWidth: 160,
        videoThumbHeight: 90,
        motionPixelThreshold: 10,
        motionThreshold: 50.0
    )
}
