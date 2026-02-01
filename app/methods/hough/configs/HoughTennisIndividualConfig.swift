//
//  HoughTennisIndividualConfig.swift
//  SportCrunch
//
//  Configuration for individual shot detection using the Hough method.
//  Captures each shot separately without grouping into rallies.
//

import Foundation

struct HoughTennisIndividualConfig {
    static let instance = HoughMethodConfig(
        diffThreshold: 25,
        minMotionArea: 50,
        maxMotionPoints: 15000,
        minStreakLength: 20.0,
        maxStreakGap: 10.0,
        lineTolerance: 3.0,
        minDensity: 0.5,
        // Individual shot settings - don't group shots together
        rallyMaxGap: 0.5,        // Short gap tolerance (shots more than 0.5s apart are separate)
        rallyMinDuration: 0.3,   // Capture short individual shots
        groupingMode: .individual
    )
}
