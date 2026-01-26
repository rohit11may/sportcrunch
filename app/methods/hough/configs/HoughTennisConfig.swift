//
//  HoughTennisConfig.swift
//  SportCrunch
//
//  Default configuration for tennis ball tracking using the Hough method.
//

import Foundation

struct HoughTennisConfig {
    static let instance = HoughMethodConfig(
        diffThreshold: 25,
        minMotionArea: 50,
        minStreakLength: 20.0,
        maxStreakGap: 10.0,
        lineTolerance: 3.0,
        minDensity: 0.5,
        rallyMaxGap: 4.0,
        rallyMinDuration: 2.0
    )
}
