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

      print("🔄 [RunExecutor] Method: \(run.method), Config: \(run.config)")
      print("🔄 [RunExecutor] Executing on \(videoURL.lastPathComponent)")

      // Instantiate the segmentation method based on method + config
      let method = try instantiateMethod(methodFamily: run.method, configName: run.config)
      print("🔄 [RunExecutor] Using method: \(method.name)")

      // Detect segments using configured method
      let segments = try await method.detectSegments(videoURL: videoURL, observation: nil)

      print("🔄 [RunExecutor] ✓ Detected \(segments.count) segments")

      // Convert to ExportedSegment
      let exportedSegments = segments.map { segment in
        ExportedSegment(
          startTime: segment.startTime,
          endTime: segment.endTime,
          type: "segment"  // Generic type
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

  // MARK: - Method Instantiation

  /// Instantiates a segmentation method based on method family and config name
  private func instantiateMethod(methodFamily: String, configName: String) throws -> any SegmentationMethod {
    print("🔄 [RunExecutor] Instantiating method: \(methodFamily)/\(configName)")

    switch methodFamily.lowercased() {
    case "spectral_flux":
      return try instantiateSpectralFluxMethod(configName: configName)
    default:
      throw RunExecutorError.methodNotFound("\(methodFamily)/\(configName)")
    }
  }

  /// Instantiates SpectralFluxMethod with the specified config
  private func instantiateSpectralFluxMethod(configName: String) throws -> SpectralFluxMethod {
    let config: SpectralFluxMethodConfig

    switch configName {
    case "TennisRally":
      config = SpectralFluxTennisRallyConfig.instance
    case "TennisIndividual":
      config = SpectralFluxTennisIndividualConfig.instance
    default:
      throw RunExecutorError.configNotFound(configName)
    }

    return SpectralFluxMethod(config: config)
  }

}

// MARK: - Errors

enum RunExecutorError: LocalizedError {
  case videoNotFound(String)
  case methodNotFound(String)
  case configNotFound(String)

  var errorDescription: String? {
    switch self {
    case .videoNotFound(let path):
      return "Video file not found: \(path)"
    case .methodNotFound(let method):
      return "Method not found: \(method)"
    case .configNotFound(let config):
      return "Config not found: \(config)"
    }
  }
}
