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
}

// MARK: - Tennis Mode

/// Tennis-specific detection modes
enum TennisMode: String, SportMode, CaseIterable, Codable, Sendable {
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
enum SportModeWrapper: Codable, Equatable, Sendable {
  case tennis(TennisMode)

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
        DecodingError.Context(
          codingPath: container.codingPath, debugDescription: "Unknown sport mode type: \(type)")
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

// MARK: - Sport Enum

/// Represents the supported sports for highlight detection
enum Sport: String, CaseIterable, Identifiable, Codable, Sendable {
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

  // MARK: - Segmentation Method

  /// Returns the configured segmentation method for this sport and mode.
  ///
  /// The returned method is "hydrated" with its configuration and ready to use.
  ///
  /// - Parameter mode: Optional sport mode (e.g., TennisMode.rally)
  /// - Returns: Configured segmentation method ready for detection
  func segmentationMethod(for mode: (any SportMode)?) -> any SegmentationMethod {
    switch self {
    case .tennis:
      let tennisMode = (mode as? TennisMode) ?? .rally

      switch tennisMode {
      case .rally:
        return SpectralFluxMethod(
          config: SpectralFluxTennisRallyConfig.instance
        )
      case .individual:
        return SpectralFluxMethod(
          config: SpectralFluxTennisIndividualConfig.instance
        )
      }

    case .cricket:
      fatalError("Cricket not yet implemented")
    }
  }

}
