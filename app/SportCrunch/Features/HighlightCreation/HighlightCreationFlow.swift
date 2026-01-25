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
            .accessibilityElement(children: .contain)
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
                backgroundManager: appState.backgroundProcessingManager,
                videoLoader: appState.videoLoaderService
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

    /// Check if running in UI test mode
    var isTestingVideoFlow: Bool {
        ProcessInfo.processInfo.arguments.contains("-isTestingVideoFlow")
    }

    // MARK: - Services

    private var storageService: ProjectStorageServiceProtocol?
    private var backgroundManager: BackgroundProcessingManager?
    private var videoLoader: VideoLoaderServiceProtocol?

    // MARK: - Static Formatters

    private static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

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
    var sportMode: (any SportMode)? {
        selectedTennisMode
    }

    /// Generates a default title based on the video creation date
    var defaultTitle: String {
        let date = videoCreationDate ?? Date()
        return Self.titleDateFormatter.string(from: date)
    }

    // MARK: - Setup

    func setServices(
        storage: ProjectStorageServiceProtocol,
        backgroundManager: BackgroundProcessingManager,
        videoLoader: VideoLoaderServiceProtocol
    ) {
        self.storageService = storage
        self.backgroundManager = backgroundManager
        self.videoLoader = videoLoader
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
        Task { [weak self] in
            guard let self else { return }
            await self.loadQuickThumbnail(for: item)
        }
    }

    /// Injects a test video from the path provided by UI tests via environment variable
    func injectTestVideo() {
        guard isTestingVideoFlow else { return }

        // The test video path is provided by the UI test via launch environment
        guard let testVideoPath = ProcessInfo.processInfo.environment["TEST_VIDEO_PATH"] else {
            print("SportCrunch: TEST_VIDEO_PATH environment variable not set")
            return
        }

        let sampleURL = URL(fileURLWithPath: testVideoPath)
        guard FileManager.default.fileExists(atPath: testVideoPath) else {
            print("SportCrunch: Test video not found at path: \(testVideoPath)")
            return
        }

        print("SportCrunch: Injecting test video from: \(sampleURL)")

        // Copy to temp directory to simulate a real video selection
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        do {
            try FileManager.default.copyItem(at: sampleURL, to: tempURL)
            selectedVideoURL = tempURL

            // Move to sport selection immediately
            withAnimation(.spring(response: 0.4)) {
                currentStep = .selectSport
            }

            // Load video metadata in background
            Task { [weak self] in
                guard let self else { return }
                try? await self.loadVideoMetadata(from: tempURL)
            }
        } catch {
            print("SportCrunch: Failed to copy test video: \(error)")
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

    /// Loads video metadata (duration, thumbnail) from a URL
    private func loadVideoMetadata(from url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        videoDuration = CMTimeGetSeconds(duration)

        print("SportCrunch: Video duration: \(videoDuration) seconds")

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
    /// Video loading happens in background - user sees progress on home screen.
    func startBackgroundProcessing() {
        guard let sport = selectedSport,
              let manager = backgroundManager,
              let storage = storageService else {
            return
        }

        // Build sport mode wrapper
        let sportModeWrapper: SportModeWrapper? = {
            if let tennisMode = selectedTennisMode {
                return .tennis(tennisMode)
            }
            return nil
        }()

        // Case 1: Video URL already loaded (test injection or pre-loaded)
        if let existingURL = selectedVideoURL {
            let newProject = Project(
                sport: sport,
                sourceVideoURL: existingURL,
                originalDuration: videoDuration,
                title: defaultTitle,
                sportMode: sportModeWrapper
            )

            var projectToSave = newProject
            projectToSave.status = .loadingVideo
            project = projectToSave

            // Save project and queue processing with URL
            storage.saveProject(projectToSave)
            manager.queueProcessing(
                project: projectToSave,
                sourceURL: existingURL,
                sport: sport,
                sportMode: sportMode
            )

            isBackgroundProcessing = true
            shouldDismiss = true
            return
        }

        // Case 2: Need to load video from PhotosPickerItem (normal flow)
        guard let pickerItem = selectedVideoItem else {
            error = .invalidVideoURL
            showError = true
            return
        }

        // Create project with placeholder URL (will be updated when video loads)
        // Use a temporary placeholder - BackgroundProcessingManager will update it
        let placeholderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-\(UUID().uuidString).mov")

        let newProject = Project(
            sport: sport,
            sourceVideoURL: placeholderURL,
            originalDuration: videoDuration,  // May be 0 if not loaded yet
            title: defaultTitle,
            sportMode: sportModeWrapper
        )

        var projectToSave = newProject
        projectToSave.status = .loadingVideo
        project = projectToSave

        // Save project so it appears on home screen immediately
        storage.saveProject(projectToSave)

        // Queue background processing - video loading happens in background
        manager.queueProcessing(
            project: projectToSave,
            pickerItem: pickerItem,
            sport: sport,
            sportMode: sportMode
        )

        isBackgroundProcessing = true

        // Dismiss immediately - processing continues in background
        shouldDismiss = true
    }

    // MARK: - Project Management

    func saveProject() {
        guard let project else { return }
        storageService?.saveProject(project)
    }
}

// MARK: - Preview

#Preview {
    HighlightCreationFlow()
        .environmentObject(AppState())
}
