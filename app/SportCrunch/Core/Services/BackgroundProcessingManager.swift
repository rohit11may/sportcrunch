//
//  BackgroundProcessingManager.swift
//  SportCrunch
//
//  Manages background video processing tasks, allowing users to
//  dismiss the creation flow while processing continues.
//

import Combine
import Foundation
import PhotosUI
import SwiftUI

// MARK: - Processing Job

/// Represents an active processing job
struct ProcessingJob: Identifiable {
  let id: UUID
  let projectId: UUID
  /// Source URL if already loaded, nil if needs to be loaded from pickerItem
  var sourceURL: URL?
  /// PhotosPickerItem if video needs to be loaded in background
  let pickerItem: PhotosPickerItem?
  let sport: Sport
  let sportMode: (any SportMode)?
}

// MARK: - Background Processing Manager

/// Manages background video processing tasks.
/// Allows processing to continue after the creation flow is dismissed.
@MainActor
final class BackgroundProcessingManager: ObservableObject {

  // MARK: - Published State

  /// Currently active processing jobs
  @Published private(set) var activeJobs: [UUID: ProcessingJob] = [:]

  /// Progress for each project (keyed by project ID)
  @Published private(set) var progressByProject: [UUID: Double] = [:]

  /// Status for each project (keyed by project ID)
  @Published private(set) var statusByProject: [UUID: ProcessingStatus] = [:]

  // MARK: - Dependencies

  private let processingService: VideoProcessingServiceProtocol
  private let storageService: ProjectStorageServiceProtocol
  private let thumbnailService: ThumbnailServiceProtocol
  private let videoLoaderService: VideoLoaderServiceProtocol

  // MARK: - Private State

  private var processingTasks: [UUID: Task<Void, Never>] = [:]
  private var backgroundTaskIds: [UUID: UIBackgroundTaskIdentifier] = [:]
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization

  init(
    processingService: VideoProcessingServiceProtocol,
    storageService: ProjectStorageServiceProtocol,
    thumbnailService: ThumbnailServiceProtocol = RealThumbnailService(),
    videoLoaderService: VideoLoaderServiceProtocol = RealVideoLoaderService()
  ) {
    self.processingService = processingService
    self.storageService = storageService
    self.thumbnailService = thumbnailService
    self.videoLoaderService = videoLoaderService

    // Subscribe to processing service updates
    setupSubscriptions()
  }

  // MARK: - Public API

  /// Queue a new processing job for a project with a PhotosPickerItem.
  /// Video loading happens in background - returns immediately.
  func queueProcessing(
    project: Project,
    pickerItem: PhotosPickerItem,
    sport: Sport,
    sportMode: (any SportMode)?
  ) {
    let job = ProcessingJob(
      id: UUID(),
      projectId: project.id,
      sourceURL: nil as URL?,
      pickerItem: pickerItem,
      sport: sport,
      sportMode: sportMode
    )

    activeJobs[project.id] = job
    progressByProject[project.id] = 0
    statusByProject[project.id] = .loadingVideo

    // Start processing
    startProcessingTask(for: job)
  }

  /// Queue a new processing job for a project with an already-loaded URL.
  /// Used for test injection or pre-loaded videos.
  func queueProcessing(
    project: Project,
    sourceURL: URL,
    sport: Sport,
    sportMode: (any SportMode)?
  ) {
    let job = ProcessingJob(
      id: UUID(),
      projectId: project.id,
      sourceURL: sourceURL,
      pickerItem: nil as PhotosPickerItem?,
      sport: sport,
      sportMode: sportMode
    )

    activeJobs[project.id] = job
    progressByProject[project.id] = 0
    statusByProject[project.id] = .loadingVideo

    // Start processing
    startProcessingTask(for: job)
  }

  /// Check if a project is currently being processed
  func isProcessing(projectId: UUID) -> Bool {
    activeJobs[projectId] != nil
  }

  // MARK: - Private Methods

  private func setupSubscriptions() {
    // Subscribe to status updates from processing service
    processingService.statusPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        self?.updateCurrentJobStatus(status)
      }
      .store(in: &cancellables)

    // Subscribe to progress updates
    processingService.progressPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] progress in
        self?.updateCurrentJobProgress(progress)
      }
      .store(in: &cancellables)
  }

  private func updateCurrentJobStatus(_ status: ProcessingStatus) {
    // Update the status for all active jobs (in practice, only one runs at a time)
    for projectId in activeJobs.keys {
      statusByProject[projectId] = status
    }
  }

  private func updateCurrentJobProgress(_ progress: Double) {
    for projectId in activeJobs.keys {
      progressByProject[projectId] = progress
    }
  }

  private func startProcessingTask(for job: ProcessingJob) {
    let projectId = job.projectId

    // Register background task
    let backgroundTaskId = UIApplication.shared.beginBackgroundTask(
      withName: "com.sportcrunch.processing.\(projectId.uuidString)"
    ) { [weak self] in
      // Expiration handler: cancel task if we run out of time
      print(
        "SportCrunch: [BackgroundProcessingManager] Background task expired for project \(projectId)"
      )
      self?.processingTasks[projectId]?.cancel()
    }
    backgroundTaskIds[projectId] = backgroundTaskId

    let task = Task { [weak self] in
      guard let self else { return }
      await self.processJob(job)
    }

    processingTasks[projectId] = task
  }

  private func cleanupJob(projectId: UUID) {
    processingTasks.removeValue(forKey: projectId)
    activeJobs.removeValue(forKey: projectId)
    progressByProject.removeValue(forKey: projectId)
    statusByProject.removeValue(forKey: projectId)

    if let taskId = backgroundTaskIds[projectId] {
      UIApplication.shared.endBackgroundTask(taskId)
      backgroundTaskIds.removeValue(forKey: projectId)
    }
  }

  private func processJob(_ job: ProcessingJob) async {
    var mutableJob = job

    do {
      // Step 1: Load video if needed (from PhotosPickerItem)
      let sourceURL: URL
      if let existingURL = mutableJob.sourceURL {
        sourceURL = existingURL
      } else if let pickerItem = mutableJob.pickerItem {
        // Load video in background
        sourceURL = try await videoLoaderService.loadVideo(from: pickerItem)
        mutableJob.sourceURL = sourceURL
      } else {
        throw ProcessingError.invalidVideoURL
      }

      // Step 2: Process the video
      // Check for cancellation before expensive operation
      try Task.checkCancellation()

      let result = try await processingService.processVideo(
        sourceURL: sourceURL,
        sport: job.sport,
        sportMode: job.sportMode
      )

      // Step 3: Generate thumbnail from highlight video (delegated to ThumbnailService)
      let thumbnailData = await thumbnailService.generateThumbnail(
        from: result.highlightURL, maxSize: nil)

      // Step 4: Update project with results
      await MainActor.run {
        if var project = storageService.getProject(id: job.projectId) {
          project.segments = result.segments
          project.highlightVideoURL = result.highlightURL
          project.highlightDuration = result.highlightDuration
          project.thumbnailData = thumbnailData
          project.originalFileSize = result.originalFileSize
          project.highlightFileSize = result.highlightFileSize
          project.status = .completed
          storageService.updateProject(project)
        }

        cleanupJob(projectId: job.projectId)

        // Re-add to completed list for UI update (cleanup removes it from active)
        progressByProject[job.projectId] = 1.0
        statusByProject[job.projectId] = .completed
      }

    } catch {
      // Handle failure
      print(
        "SportCrunch: [BackgroundProcessingManager] Processing failed: \(error.localizedDescription)"
      )
      await MainActor.run {
        if var project = storageService.getProject(id: job.projectId) {
          project.status = .failed
          storageService.updateProject(project)
        }

        cleanupJob(projectId: job.projectId)

        statusByProject[job.projectId] = .failed
      }
    }
  }
}
