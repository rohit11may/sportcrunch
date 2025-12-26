//
//  BackgroundProcessingManager.swift
//  SportCrunch
//
//  Manages background video processing tasks, allowing users to
//  dismiss the creation flow while processing continues.
//

import Foundation
import Combine
import AVFoundation

// MARK: - Processing Job

/// Represents an active processing job
struct ProcessingJob: Identifiable {
    let id: UUID
    let projectId: UUID
    let sourceURL: URL
    let sport: Sport
    let sportMode: SportMode?
    var progress: Double = 0
    var status: ProcessingStatus = .pending
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
    
    // MARK: - Private State
    
    private var processingTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(processingService: VideoProcessingServiceProtocol, storageService: ProjectStorageServiceProtocol) {
        self.processingService = processingService
        self.storageService = storageService
        
        // Subscribe to processing service updates
        setupSubscriptions()
    }
    
    // MARK: - Public API
    
    /// Queue a new processing job for a project.
    /// Returns immediately after queuing - processing happens in background.
    func queueProcessing(
        project: Project,
        sourceURL: URL,
        sport: Sport,
        sportMode: SportMode?
    ) {
        let job = ProcessingJob(
            id: UUID(),
            projectId: project.id,
            sourceURL: sourceURL,
            sport: sport,
            sportMode: sportMode
        )
        
        activeJobs[project.id] = job
        progressByProject[project.id] = 0
        statusByProject[project.id] = .loadingVideo
        
        // Start processing in background
        let task = Task { [weak self] in
            guard let self else { return }
            await self.processJob(job)
        }
        
        processingTasks[project.id] = task
    }
    
    /// Check if a project is currently being processed
    func isProcessing(projectId: UUID) -> Bool {
        activeJobs[projectId] != nil
    }
    
    /// Get current progress for a project (0.0 to 1.0)
    func progress(for projectId: UUID) -> Double {
        progressByProject[projectId] ?? 0
    }
    
    /// Get current status for a project
    func status(for projectId: UUID) -> ProcessingStatus {
        statusByProject[projectId] ?? .pending
    }
    
    /// Cancel processing for a project
    func cancelProcessing(projectId: UUID) {
        processingTasks[projectId]?.cancel()
        processingTasks.removeValue(forKey: projectId)
        activeJobs.removeValue(forKey: projectId)
        progressByProject.removeValue(forKey: projectId)
        statusByProject.removeValue(forKey: projectId)
        
        // Update project status to failed
        if var project = storageService.getProject(id: projectId) {
            project.status = .failed
            storageService.updateProject(project)
        }
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
    
    private func processJob(_ job: ProcessingJob) async {
        do {
            // Process the video
            let result = try await processingService.processVideo(
                sourceURL: job.sourceURL,
                sport: job.sport,
                sportMode: job.sportMode
            )
            
            // Update project with results
            await MainActor.run {
                if var project = storageService.getProject(id: job.projectId) {
                    project.segments = result.segments
                    project.highlightVideoURL = result.highlightURL
                    project.highlightDuration = result.highlightDuration
                    project.status = .completed
                    storageService.updateProject(project)
                }
                
                // Clean up
                activeJobs.removeValue(forKey: job.projectId)
                processingTasks.removeValue(forKey: job.projectId)
                progressByProject[job.projectId] = 1.0
                statusByProject[job.projectId] = .completed
            }
            
        } catch {
            // Handle failure
            await MainActor.run {
                if var project = storageService.getProject(id: job.projectId) {
                    project.status = .failed
                    storageService.updateProject(project)
                }
                
                activeJobs.removeValue(forKey: job.projectId)
                processingTasks.removeValue(forKey: job.projectId)
                statusByProject[job.projectId] = .failed
            }
        }
    }
}

