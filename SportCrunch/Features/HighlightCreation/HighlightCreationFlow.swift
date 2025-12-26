//
//  HighlightCreationFlow.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import Observation
import Combine
import UniformTypeIdentifiers

// MARK: - Creation Step

enum CreationStep: Int, CaseIterable {
    case selectVideo
    case selectSport
    case selectMode    // New step for sports with modes (e.g., Tennis)
    case processing
    case preview
    case export
    
    var title: String {
        switch self {
        case .selectVideo: return "Select Video"
        case .selectSport: return "Choose Sport"
        case .selectMode: return "Choose Mode"
        case .processing: return "Creating Highlights"
        case .preview: return "Preview"
        case .export: return "Export"
        }
    }
}

// MARK: - Highlight Creation Flow

struct HighlightCreationFlow: View {
    @EnvironmentObject private var appState: AppState
    @State private var viewModel = HighlightCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.scBackground.ignoresSafeArea()
                
                switch viewModel.currentStep {
                case .selectVideo:
                    VideoSelectionView(viewModel: viewModel)
                case .selectSport:
                    SportSelectionView(viewModel: viewModel)
                case .selectMode:
                    TennisModeSelectionView(viewModel: viewModel)
                case .processing:
                    ProcessingView(viewModel: viewModel)
                case .preview:
                    PreviewView(viewModel: viewModel)
                case .export:
                    ExportView(viewModel: viewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.canGoBack {
                        Button {
                            viewModel.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.scTextPrimary)
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(viewModel.currentStep.title)
                        .font(AppFont.subheadline())
                        .foregroundStyle(Color.scTextPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.scTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.scSurface)
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(Color.scBackground, for: .navigationBar)
        }
        .onAppear {
            viewModel.setServices(
                processing: appState.videoProcessingService,
                storage: appState.projectStorageService,
                backgroundManager: appState.backgroundProcessingManager
            )
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
}

// MARK: - Highlight Creation View Model

@MainActor
@Observable
final class HighlightCreationViewModel {
    // MARK: - Observable State
    
    var currentStep: CreationStep = .selectVideo
    var selectedVideoItem: PhotosPickerItem?
    var selectedVideoURL: URL?
    var videoDuration: TimeInterval = 0
    var videoThumbnail: UIImage?
    var selectedSport: Sport?
    var selectedTennisMode: TennisMode?
    var processingProgress: Double = 0
    var processingStatus: ProcessingStatus = .pending
    var project: Project?
    var error: ProcessingError?
    var showError = false
    var shouldDismiss = false
    
    /// Whether background processing was started (flow can be dismissed)
    var isBackgroundProcessing = false
    
    // MARK: - Services
    
    private var processingService: VideoProcessingServiceProtocol?
    private var storageService: ProjectStorageServiceProtocol?
    private var backgroundManager: BackgroundProcessingManager?
    private var processingTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var canGoBack: Bool {
        switch currentStep {
        case .selectVideo:
            return false
        case .selectSport:
            return true
        case .selectMode:
            return true
        case .processing, .preview, .export:
            return false
        }
    }
    
    var formattedVideoDuration: String {
        let hours = Int(videoDuration) / 3600
        let minutes = Int(videoDuration) % 3600 / 60
        let seconds = Int(videoDuration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// The sport mode as SportMode protocol type (for passing to processor)
    var sportMode: SportMode? {
        selectedTennisMode
    }
    
    // MARK: - Setup
    
    func setServices(
        processing: VideoProcessingServiceProtocol,
        storage: ProjectStorageServiceProtocol,
        backgroundManager: BackgroundProcessingManager
    ) {
        self.processingService = processing
        self.storageService = storage
        self.backgroundManager = backgroundManager
    }
    
    // MARK: - Navigation
    
    func goBack() {
        switch currentStep {
        case .selectSport:
            currentStep = .selectVideo
            selectedVideoItem = nil
            selectedVideoURL = nil
        case .selectMode:
            currentStep = .selectSport
            selectedSport = nil
            selectedTennisMode = nil
        default:
            break
        }
    }
    
    func cancel() {
        processingTask?.cancel()
        processingService?.cancel()
    }
    
    // MARK: - Video Selection
    
    /// Just stores the video reference and moves forward - no heavy loading yet
    func selectVideo(_ item: PhotosPickerItem) {
        selectedVideoItem = item
        
        // Move to sport selection immediately
        withAnimation(.spring(response: 0.4)) {
            currentStep = .selectSport
        }
    }
    
    /// Loads the video URL directly from Photos library without copying the file.
    /// This is significantly faster than using Transferable which copies the entire video.
    private func loadVideoFile() async throws -> URL {
        guard let item = selectedVideoItem else {
            throw ProcessingError.invalidVideoURL
        }
        
        let logger = ProcessingLogger.shared
        
        // Get the asset identifier from PhotosPickerItem
        guard let assetIdentifier = item.itemIdentifier else {
            print("SportCrunch: No asset identifier, falling back to Transferable...")
            await MainActor.run {
                logger.pipeline("No asset identifier, falling back to Transferable...")
            }
            return try await loadVideoViaTransferable(item: item, logger: logger)
        }
        
        print("SportCrunch: Loading video with asset ID: \(assetIdentifier)")
        
        // Fetch the PHAsset from Photos library
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            print("SportCrunch: Could not fetch PHAsset, falling back to Transferable...")
            await MainActor.run {
                logger.pipeline("Could not fetch PHAsset, falling back to Transferable...")
            }
            return try await loadVideoViaTransferable(item: item, logger: logger)
        }
        
        print("SportCrunch: Requesting video URL directly from Photos...")
        await MainActor.run {
            logger.pipeline("Requesting video URL directly from Photos...")
        }
        
        // Request the video URL directly (no file copy needed!)
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true // For iCloud videos
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                // Check for errors
                if let error = info?[PHImageErrorKey] as? Error {
                    Task { @MainActor in
                        logger.error("PHImageManager error: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                // Check if request was cancelled
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: ProcessingError.cancelled)
                    return
                }
                
                if let urlAsset = avAsset as? AVURLAsset {
                    // Direct URL to the video - no copy needed!
                    print("SportCrunch: Got direct video URL: \(urlAsset.url)")
                    Task { @MainActor in
                        logger.success("Got direct video URL (no copy needed)")
                    }
                    continuation.resume(returning: urlAsset.url)
                } else if avAsset is AVComposition {
                    // Slow-mo or edited video returns AVComposition - need to fall back
                    print("SportCrunch: Video is slow-mo/edited, falling back to Transferable...")
                    Task { @MainActor in
                        logger.pipeline("Video is slow-mo/edited, falling back to Transferable...")
                    }
                    Task {
                        do {
                            let url = try await self.loadVideoViaTransferable(item: item, logger: logger)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    // Unexpected type - fall back
                    print("SportCrunch: Unexpected AVAsset type, falling back to Transferable...")
                    Task {
                        do {
                            let url = try await self.loadVideoViaTransferable(item: item, logger: logger)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    /// Fallback method using Transferable for edge cases (slow-mo, edited videos, non-Photos sources)
    private func loadVideoViaTransferable(item: PhotosPickerItem, logger: ProcessingLogger) async throws -> URL {
        print("SportCrunch: Loading video via Transferable...")
        await MainActor.run {
            logger.pipeline("Loading video via Transferable (this may take a moment)...")
        }
        
        guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
            print("SportCrunch: Failed to load video - loadTransferable returned nil")
            print("SportCrunch: Item supported types: \(item.supportedContentTypes)")
            await MainActor.run {
                logger.error("Failed to load video via Transferable")
            }
            throw ProcessingError.invalidVideoURL
        }
        
        print("SportCrunch: Successfully loaded video at: \(movie.url)")
        await MainActor.run {
            logger.success("Video loaded via Transferable")
        }
        return movie.url
    }
    
    /// Loads video metadata (duration, thumbnail) from a URL
    private func loadVideoMetadata(from url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        videoDuration = CMTimeGetSeconds(duration)
        
        print("SportCrunch: Video duration: \(videoDuration) seconds")
        
        let logger = ProcessingLogger.shared
        await MainActor.run {
            let mins = Int(self.videoDuration) / 60
            let secs = Int(self.videoDuration) % 60
            logger.pipeline("Video duration: \(mins):\(String(format: "%02d", secs))")
        }
        
        // Generate thumbnail
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 400, height: 400)
        
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        videoThumbnail = UIImage(cgImage: cgImage)
        
        print("SportCrunch: Thumbnail generated")
    }
    
    // MARK: - Sport Selection
    
    func selectSport(_ sport: Sport) {
        selectedSport = sport
        
        // If sport has modes (e.g., Tennis), go to mode selection
        // Otherwise, proceed directly to processing
        if sport.hasModes {
            withAnimation(.spring(response: 0.4)) {
                currentStep = .selectMode
            }
        } else {
            startBackgroundProcessing()
        }
    }
    
    // MARK: - Tennis Mode Selection
    
    func selectTennisMode(_ mode: TennisMode) {
        selectedTennisMode = mode
        startBackgroundProcessing()
    }
    
    // MARK: - Background Processing
    
    /// Starts background processing and immediately dismisses the flow.
    /// The user can monitor progress from the home screen.
    func startBackgroundProcessing() {
        guard let sport = selectedSport,
              let manager = backgroundManager,
              let storage = storageService else {
            return
        }
        
        // Show processing view briefly while loading video
        withAnimation(.spring(response: 0.4)) {
            currentStep = .processing
        }
        
        processingStatus = .loadingVideo
        processingProgress = 0.0
        
        // Start the setup and queue background task
        Task { [weak self] in
            guard let self else { return }
            
            do {
                // Step 1: Load the video file from Photos library
                let videoURL = try await self.loadVideoFile()
                
                await MainActor.run {
                    self.selectedVideoURL = videoURL
                }
                
                // Step 2: Load video metadata (duration, thumbnail)
                try await self.loadVideoMetadata(from: videoURL)
                
                // Step 3: Create the project with .processing status
                let sportModeWrapper: SportModeWrapper? = {
                    if let tennisMode = self.selectedTennisMode {
                        return .tennis(tennisMode)
                    }
                    return nil
                }()
                
                let newProject = Project(
                    sport: sport,
                    sourceVideoURL: videoURL,
                    originalDuration: self.videoDuration,
                    sportMode: sportModeWrapper
                )
                
                await MainActor.run {
                    var projectToSave = newProject
                    projectToSave.status = .analyzingAudio  // Mark as processing
                    self.project = projectToSave
                    
                    // Save project immediately so it appears on home screen
                    storage.saveProject(projectToSave)
                    
                    // Queue background processing
                    manager.queueProcessing(
                        project: projectToSave,
                        sourceURL: videoURL,
                        sport: sport,
                        sportMode: self.sportMode
                    )
                    
                    self.isBackgroundProcessing = true
                    
                    // Dismiss the flow - processing continues in background
                    self.shouldDismiss = true
                }
                
            } catch let processingError as ProcessingError {
                await MainActor.run {
                    self.error = processingError
                    self.showError = true
                }
            } catch {
                await MainActor.run {
                    self.error = .unknown(error)
                    self.showError = true
                }
            }
        }
    }
    
    // MARK: - Legacy Processing (for preview flow when opening from home)
    
    func startProcessing() {
        guard let sport = selectedSport,
              let service = processingService else {
            return
        }
        
        processingStatus = .loadingVideo
        processingProgress = 0.0
        
        // Subscribe to status updates
        processingTask = Task { [weak self] in
            for await status in service.statusPublisher.values {
                guard status != .pending else { continue }
                await MainActor.run {
                    self?.processingStatus = status
                }
            }
        }
        
        // Start separate task for progress
        Task { [weak self] in
            for await progress in service.progressPublisher.values {
                await MainActor.run {
                    self?.processingProgress = progress
                }
            }
        }
        
        // Main processing task
        Task { [weak self] in
            guard let self else { return }
            
            do {
                let videoURL = try await self.loadVideoFile()
                
                await MainActor.run {
                    self.selectedVideoURL = videoURL
                }
                
                try await self.loadVideoMetadata(from: videoURL)
                
                await MainActor.run {
                    self.project = Project(
                        sport: sport,
                        sourceVideoURL: videoURL,
                        originalDuration: self.videoDuration
                    )
                }
                
                let result = try await service.processVideo(
                    sourceURL: videoURL,
                    sport: sport,
                    sportMode: self.sportMode
                )
                
                await MainActor.run {
                    self.project?.segments = result.segments
                    self.project?.highlightVideoURL = result.highlightURL
                    self.project?.highlightDuration = result.highlightDuration
                    self.project?.status = .completed
                    
                    withAnimation(.spring(response: 0.4)) {
                        self.currentStep = .preview
                    }
                }
            } catch let processingError as ProcessingError {
                await MainActor.run {
                    self.error = processingError
                    self.showError = true
                    self.project?.status = .failed
                }
            } catch {
                await MainActor.run {
                    self.error = .unknown(error)
                    self.showError = true
                    self.project?.status = .failed
                }
            }
        }
    }
    
    // MARK: - Export
    
    func proceedToExport() {
        withAnimation(.spring(response: 0.4)) {
            currentStep = .export
        }
    }
    
    func saveProject() {
        guard let project else { return }
        storageService?.saveProject(project)
    }
    
    func complete() {
        saveProject()
        shouldDismiss = true
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        // Support multiple video formats that may come from the Photos library
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to a temporary location preserving the original extension
            let originalExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalExtension)
            
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
        
        // Also support QuickTime movies specifically
        FileRepresentation(contentType: .quickTimeMovie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let originalExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalExtension)
            
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
        
        // Also support MPEG-4 movies
        FileRepresentation(contentType: .mpeg4Movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let originalExtension = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalExtension)
            
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Preview

#Preview {
    HighlightCreationFlow()
        .environmentObject(AppState())
}

