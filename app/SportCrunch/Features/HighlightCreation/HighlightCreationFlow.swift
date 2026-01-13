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
    
    var title: String {
        switch self {
        case .selectVideo: return "Select Video"
        case .selectSport: return "Choose Sport"
        case .selectMode: return "Choose Mode"
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
                }
            }
            .accessibilityIdentifier(AccessibilityID.Creation.flowContainer)
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
                        .accessibilityIdentifier(AccessibilityID.Creation.backButton)
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
                    .accessibilityIdentifier(AccessibilityID.Creation.closeButton)
                }
            }
            .toolbarBackground(Color.scBackground, for: .navigationBar)
        }
        .onAppear {
            viewModel.setServices(
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
    var videoCreationDate: Date?
    var selectedSport: Sport?
    var selectedTennisMode: TennisMode?
    var project: Project?
    var error: ProcessingError?
    var showError = false
    var shouldDismiss = false
    
    /// Whether background processing was started (flow can be dismissed)
    var isBackgroundProcessing = false
    
    // MARK: - Services
    
    private var storageService: ProjectStorageServiceProtocol?
    private var backgroundManager: BackgroundProcessingManager?
    
    // MARK: - Computed Properties
    
    var canGoBack: Bool {
        switch currentStep {
        case .selectVideo:
            return false
        case .selectSport:
            return true
        case .selectMode:
            return true
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
    
    /// Generates a default title based on the video creation date
    var defaultTitle: String {
        let date = videoCreationDate ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Setup
    
    func setServices(
        storage: ProjectStorageServiceProtocol,
        backgroundManager: BackgroundProcessingManager
    ) {
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
        // Background processing is managed by BackgroundProcessingManager
        // Nothing to cancel in the creation flow itself
    }
    
    // MARK: - Video Selection
    
    /// Stores the video reference, loads a quick thumbnail, and moves forward
    func selectVideo(_ item: PhotosPickerItem) {
        selectedVideoItem = item
        
        // Move to sport selection immediately
        withAnimation(.spring(response: 0.4)) {
            currentStep = .selectSport
        }
        
        // Load thumbnail in background for sport selection view
        Task {
            await loadQuickThumbnail(for: item)
        }
    }
    
    /// Loads just the thumbnail quickly for the sport selection view
    private func loadQuickThumbnail(for item: PhotosPickerItem) async {
        guard let assetIdentifier = item.itemIdentifier else { return }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        // Store creation date
        await MainActor.run {
            self.videoCreationDate = asset.creationDate
        }
        
        // Request video asset to get duration and generate thumbnail
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .fastFormat // Fast for quick preview
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avAsset = avAsset else {
                    continuation.resume()
                    return
                }
                
                Task { @MainActor in
                    // Get duration
                    if let duration = try? await avAsset.load(.duration) {
                        self.videoDuration = CMTimeGetSeconds(duration)
                    }
                    
                    // Generate thumbnail from middle of video
                    let imageGenerator = AVAssetImageGenerator(asset: avAsset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    imageGenerator.maximumSize = CGSize(width: 400, height: 400)
                    
                    // Use middle of video for thumbnail
                    let middleTime = CMTime(seconds: self.videoDuration / 2, preferredTimescale: 600)
                    
                    if let cgImage = try? imageGenerator.copyCGImage(at: middleTime, actualTime: nil) {
                        self.videoThumbnail = UIImage(cgImage: cgImage)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    /// Loads the video file from Photos library using PHAssetResourceManager for byte-for-byte original access.
    /// This avoids transcoding issues that cause frame extraction failures on physical devices.
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
        
        // Capture the video creation date
        await MainActor.run {
            self.videoCreationDate = asset.creationDate
            if let date = asset.creationDate {
                print("SportCrunch: Video creation date: \(date)")
            }
        }
        
        // Check if this is a slow-mo or edited video (mediaSubtypes contains .videoHighFrameRate)
        let isSlowMo = asset.mediaSubtypes.contains(.videoHighFrameRate)
        if isSlowMo {
            print("SportCrunch: Video is slow-mo, using PHImageManager fallback...")
            await MainActor.run {
                logger.pipeline("Video is slow-mo, using PHImageManager fallback...")
            }
            return try await loadVideoViaPHImageManager(asset: asset, item: item, logger: logger)
        }
        
        // Use PHAssetResourceManager for byte-for-byte original access (no transcoding)
        print("SportCrunch: Using PHAssetResourceManager for original video access...")
        await MainActor.run {
            logger.pipeline("Loading original video file (no transcoding)...")
        }
        
        return try await loadVideoViaPHAssetResourceManager(asset: asset, item: item, logger: logger)
    }
    
    /// Primary method: Uses PHAssetResourceManager to copy the original video bytes without transcoding.
    /// This is critical for reliable frame extraction on physical devices.
    private func loadVideoViaPHAssetResourceManager(
        asset: PHAsset,
        item: PhotosPickerItem,
        logger: ProcessingLogger
    ) async throws -> URL {
        // Find the video resource (prefer fullSizeVideo for edited videos, fall back to video)
        let resources = PHAssetResource.assetResources(for: asset)
        
        // Log available resources for debugging
        print("SportCrunch: Available resources: \(resources.map { "\($0.type.rawValue):\($0.originalFilename)" })")
        
        // Priority: fullSizeVideo > video (fullSizeVideo is the original for edited assets)
        guard let videoResource = resources.first(where: { $0.type == .fullSizeVideo })
                ?? resources.first(where: { $0.type == .video }) else {
            print("SportCrunch: No video resource found, falling back to PHImageManager...")
            await MainActor.run {
                logger.pipeline("No video resource found, falling back to PHImageManager...")
            }
            return try await loadVideoViaPHImageManager(asset: asset, item: item, logger: logger)
        }
        
        print("SportCrunch: Using resource type \(videoResource.type.rawValue): \(videoResource.originalFilename)")
        await MainActor.run {
            logger.pipeline("Copying original video: \(videoResource.originalFilename)")
        }
        
        // Create destination URL with original filename extension
        let originalExtension = (videoResource.originalFilename as NSString).pathExtension
        let fileExtension = originalExtension.isEmpty ? "mov" : originalExtension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        // Configure options for the copy
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true // For iCloud videos
        
        // Copy the original video bytes to our temp location
        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().writeData(
                for: videoResource,
                toFile: destinationURL,
                options: options
            ) { error in
                if let error = error {
                    print("SportCrunch: PHAssetResourceManager error: \(error.localizedDescription)")
                    Task { @MainActor in
                        logger.error("PHAssetResourceManager error: \(error.localizedDescription)")
                    }
                    
                    // Fall back to PHImageManager on error
                    Task {
                        do {
                            let url = try await self.loadVideoViaPHImageManager(
                                asset: asset,
                                item: item,
                                logger: logger
                            )
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    return
                }
                
                print("SportCrunch: Successfully copied original video to: \(destinationURL)")
                Task { @MainActor in
                    logger.success("Original video copied successfully (no transcoding)")
                }
                continuation.resume(returning: destinationURL)
            }
        }
    }
    
    /// Secondary fallback: Uses PHImageManager for slow-mo and edited videos that need composition.
    /// These videos return AVComposition and need to be exported via Transferable.
    private func loadVideoViaPHImageManager(
        asset: PHAsset,
        item: PhotosPickerItem,
        logger: ProcessingLogger
    ) async throws -> URL {
        print("SportCrunch: Using PHImageManager for video asset...")
        await MainActor.run {
            logger.pipeline("Using PHImageManager for video access...")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
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
                    print("SportCrunch: Got video URL from PHImageManager: \(urlAsset.url)")
                    Task { @MainActor in
                        logger.success("Got video URL from PHImageManager")
                    }
                    continuation.resume(returning: urlAsset.url)
                } else if avAsset is AVComposition {
                    // Slow-mo or heavily edited video - need Transferable export
                    print("SportCrunch: Video is AVComposition, falling back to Transferable export...")
                    Task { @MainActor in
                        logger.pipeline("Video requires export (slow-mo/edited), using Transferable...")
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
                    // Unexpected type - fall back to Transferable
                    print("SportCrunch: Unexpected AVAsset type: \(type(of: avAsset)), falling back to Transferable...")
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
        
        // Generate thumbnail from middle of video
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 400, height: 400)
        
        // Use middle of video for thumbnail
        let middleTime = CMTime(seconds: videoDuration / 2, preferredTimescale: 600)
        let cgImage = try imageGenerator.copyCGImage(at: middleTime, actualTime: nil)
        videoThumbnail = UIImage(cgImage: cgImage)
        
        print("SportCrunch: Thumbnail generated from middle of video")
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
                    title: self.defaultTitle,
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
    
    // MARK: - Project Management
    
    func saveProject() {
        guard let project else { return }
        storageService?.saveProject(project)
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

