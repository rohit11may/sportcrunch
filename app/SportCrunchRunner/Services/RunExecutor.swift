//
//  RunExecutor.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import AVFoundation
import Foundation

/// Executes segmentation runs sequentially using a queue
actor RunExecutor {

  // MARK: - Dependencies

  private let store: RunStore
  private let exporter: ArtifactExporter

  // MARK: - Queue State

  private var queue: [UUID] = []
  private var currentRun: UUID?

  // MARK: - Initialization

  init(store: RunStore, exporter: ArtifactExporter) {
    self.store = store
    self.exporter = exporter
  }

  // MARK: - Public Methods

  /// Enqueue a run for execution
  func enqueue(run: Run) async {
    await store.add(run: run)
    queue.append(run.id)
    print("🔄 [RunExecutor] Enqueued run \(run.id.uuidString) - Queue size: \(queue.count)")

    // Trigger processing if not already running
    await processNext()
  }

  // MARK: - Private Methods

  private func processNext() async {
    // Don't start new run if one is already in progress
    guard currentRun == nil else {
      print("🔄 [RunExecutor] Run in progress, waiting...")
      return
    }

    // Check if queue has work
    guard let runId = queue.first else {
      print("🔄 [RunExecutor] Queue empty")
      return
    }

    // Remove from queue and mark as current
    queue.removeFirst()
    currentRun = runId

    print("🔄 [RunExecutor] Starting run \(runId.uuidString)")

    // Execute the run
    await executeRun(runId: runId)

    // Clear current run and process next
    currentRun = nil
    await processNext()
  }

  private func executeRun(runId: UUID) async {
    guard var run = await store.get(id: runId) else {
      print("🔄 [RunExecutor] ❌ Run not found: \(runId.uuidString)")
      return
    }

    // Update status to running
    run.status = .running
    run.startedAt = Date()
    await store.update(run: run)
    print("🔄 [RunExecutor] Run \(runId.uuidString) started")

    do {
      // Load video URL
      let videoURL = URL(fileURLWithPath: run.videoPath)
      guard FileManager.default.fileExists(atPath: videoURL.path) else {
        throw RunExecutorError.videoNotFound(run.videoPath)
      }

      // Parse sport
      guard let sport = Sport(rawValue: run.sport) else {
        throw RunExecutorError.invalidSport(run.sport)
      }

      // Parse sport mode (optional)
      print("🔄 [RunExecutor] Raw sportMode string: \(run.sportMode ?? "nil")")
      let sportMode: SportMode? = parseSportMode(sport: sport, modeString: run.sportMode)
      print("🔄 [RunExecutor] Parsed sportMode: \(sportMode?.displayName ?? "nil (defaulting to rally)")")

      // Get configured segmentation method for this sport/mode
      let method = sport.segmentationMethod(for: sportMode)
      print("🔄 [RunExecutor] Using method: \(method.name)")
      print("🔄 [RunExecutor] Executing on \(videoURL.lastPathComponent)")
      print(
        "🔄 [RunExecutor] Sport: \(sport.displayName), Mode: \(sportMode?.displayName ?? "default")")

      // Detect segments using configured method
      let segments = try await method.detectSegments(videoURL: videoURL)

      print("🔄 [RunExecutor] ✓ Detected \(segments.count) segments")

      // Convert to ExportedSegment
      let exportedSegments = segments.map { segment in
        ExportedSegment(
          startTime: segment.startTime,
          endTime: segment.endTime,
          type: determineSportType(sport: sport, sportMode: sportMode)
        )
      }

      // Export artifacts
      let artifactPaths = try exporter.export(
        run: run,
        segments: exportedSegments,
        highlightURL: nil  // Highlight video export not implemented yet
      )

      // Update run with success
      run.status = .completed
      run.completedAt = Date()
      run.segments = exportedSegments
      run.artifactPaths = artifactPaths
      await store.update(run: run)

      print("🔄 [RunExecutor] ✓ Run \(runId.uuidString) completed successfully")
      print("🔄 [RunExecutor] Segments JSON: \(artifactPaths.segmentsJSON)")

    } catch {
      // Update run with failure
      run.status = .failed
      run.completedAt = Date()
      run.error = error.localizedDescription
      await store.update(run: run)

      print("🔄 [RunExecutor] ❌ Run \(runId.uuidString) failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Helpers

  private func parseSportMode(sport: Sport, modeString: String?) -> SportMode? {
    guard let modeString = modeString else { return nil }

    switch sport {
    case .tennis:
      return TennisMode(rawValue: modeString)
    case .cricket:
      return nil  // No modes for cricket yet
    }
  }

  private func determineSportType(sport: Sport, sportMode: SportMode?) -> String {
    if let tennisMode = sportMode as? TennisMode {
      switch tennisMode {
      case .rally:
        return "rally"
      case .individual:
        return "shot"
      }
    }
    return "segment"
  }
}

// MARK: - Errors

enum RunExecutorError: LocalizedError {
  case videoNotFound(String)
  case invalidSport(String)
  case methodNotFound(String)

  var errorDescription: String? {
    switch self {
    case .videoNotFound(let path):
      return "Video file not found: \(path)"
    case .invalidSport(let sport):
      return "Invalid sport: \(sport)"
    case .methodNotFound(let method):
      return "Method not found: \(method)"
    }
  }
}
