//
//  CompletedProjectViewModel.swift
//  SportCrunch
//
//  ViewModel for CompletedProjectSheet handling segment calculations and star toggling.
//

import SwiftUI

// MARK: - CompletedProjectViewModel

@Observable
final class CompletedProjectViewModel {

  // MARK: - Properties

  /// The project being viewed/edited
  var project: Project

  /// Whether to show only starred segments
  var showOnlyStarred: Bool = false

  /// Dependencies
  private let storageService: ProjectStorageServiceProtocol

  // MARK: - Initialization

  init(project: Project, storageService: ProjectStorageServiceProtocol) {
    self.project = project
    self.storageService = storageService
  }

  // MARK: - Computed Properties

  /// Get starred segment IDs from the project's actual segments
  var starredSegments: Set<UUID> {
    Set(project.segments.filter { $0.isStarred }.map { $0.id })
  }

  /// All segments (used for calculations and export)
  var allSegments: [ActionSegment] {
    project.segments
  }

  /// Segments to display (filtered if showOnlyStarred is enabled)
  var displayedSegments: [ActionSegment] {
    if showOnlyStarred {
      return project.segments.filter { $0.isStarred }
    }
    return project.segments
  }

  /// Original 1-based indices for displayed segments (preserves numbering when filtered)
  var displayedSegmentIndices: [Int] {
    if showOnlyStarred {
      // Return the original 1-based index for each starred segment
      return project.segments.enumerated()
        .filter { $0.element.isStarred }
        .map { $0.offset + 1 }  // 1-based index
    }
    // When not filtered, just return sequential indices
    return Array(1...project.segments.count)
  }

  /// Calculate segment offsets within the highlight (concatenated segments)
  /// Uses all segments regardless of filter since offsets are for the full highlight video
  var segmentOffsets: [(segment: ActionSegment, startOffset: TimeInterval, endOffset: TimeInterval)] {
    var offset: TimeInterval = 0
    return allSegments.map { segment in
      let start = offset
      offset += segment.duration
      return (segment: segment, startOffset: start, endOffset: offset)
    }
  }

  /// Offsets for displayed segments only (for navigator UI)
  var displayedSegmentOffsets:
    [(segment: ActionSegment, startOffset: TimeInterval, endOffset: TimeInterval)] {
    segmentOffsets.filter { offsetInfo in
      displayedSegments.contains(where: { $0.id == offsetInfo.segment.id })
    }
  }

  /// Total highlight duration (sum of all segment durations)
  var highlightDuration: TimeInterval {
    project.highlightDuration ?? project.segments.reduce(0) { $0 + $1.duration }
  }

  /// Count of starred segments
  var starredCount: Int {
    starredSegments.count
  }

  /// Check if any segments are starred
  var hasStarredSegments: Bool {
    !starredSegments.isEmpty
  }

  // MARK: - Actions

  /// Toggle the starred status of a segment and persist the change
  func toggleStarred(segment: ActionSegment) {
    // Find the segment in the project and toggle its starred status
    guard let index = project.segments.firstIndex(where: { $0.id == segment.id }) else { return }

    // Create a new segments array to ensure @Observable detects the change
    var updatedSegments = project.segments
    updatedSegments[index].isStarred.toggle()
    project.segments = updatedSegments

    // Persist the change
    storageService.updateProject(project)
  }

  /// Find which segment contains the given time position
  /// - Parameter time: The current playback time
  /// - Returns: The index of the segment containing this time, or nil
  func segmentIndex(for time: TimeInterval) -> Int? {
    for (index, offsetInfo) in segmentOffsets.enumerated() {
      if time >= offsetInfo.startOffset && time < offsetInfo.endOffset {
        return index
      }
    }

    // If we're past all segments, return the last one
    if !segmentOffsets.isEmpty && time >= highlightDuration {
      return segmentOffsets.count - 1
    }

    return nil
  }

  /// Get the start time offset for jumping to a segment
  /// - Parameter index: The segment index
  /// - Returns: The time offset to seek to, or nil if index is invalid
  func seekTime(for index: Int) -> TimeInterval? {
    guard index >= 0 && index < segmentOffsets.count else { return nil }
    return segmentOffsets[index].startOffset
  }
}
