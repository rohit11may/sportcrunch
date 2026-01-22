//
//  DeviceTypes.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation

// MARK: - Device Target

/// Target device type for running segmentation
enum DeviceTarget: String, Codable, Sendable, CaseIterable {
  case simulator
  case device

  var displayName: String {
    switch self {
    case .simulator:
      return "Simulator"
    case .device:
      return "Physical Device"
    }
  }
}

// MARK: - Device Info

/// Information about a connected iOS device
struct DeviceInfo: Identifiable, Codable, Sendable {
  let id: String
  let name: String
  let model: String

  var displayName: String {
    "\(name) (\(model))"
  }
}
