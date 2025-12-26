//
//  HighlightCreationFlow.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Observation
import Combine

// MARK: - Creation Step

enum CreationStep: Int, CaseIterable {
    case selectVideo
    case selectSport
    case processing
    case preview
    case export
    
    var title: String {
        switch self {
        case .selectVideo: return "Select Video"
        case .selectSport: return "Choose Sport"
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
                storage: appState.projectStorageService
            )
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
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
    var processingProgress: Double = 0
    var processingStatus: ProcessingStatus = .pending
    var project: Project?
    var error: ProcessingError?
    var showError = false
    var shouldDismiss = false
    
    // MARK: - Services
    
    private var processingService: VideoProcessingServiceProtocol?
    private var storageService: ProjectStorageServiceProtocol?
    private var processingTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var canGoBack: Bool {
        switch currentStep {
        case .selectVideo:
            return false
        case .selectSport:
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
    
    // MARK: - Setup
    
    func setServices(processing: VideoProcessingServiceProtocol, storage: ProjectStorageServiceProtocol) {
        self.processingService = processing
        self.storageService = storage
    }
    
    // MARK: - Navigation
    
    func goBack() {
        switch currentStep {
        case .selectSport:
            currentStep = .selectVideo
            selectedVideoItem = nil
            selectedVideoURL = nil
        default:
            break
        }
    }
    
    func cancel() {
        processingTask?.cancel()
        processingService?.cancel()
    }
    
    // MARK: - Video Selection
    
    func processSelectedVideo(_ item: PhotosPickerItem) async {
        selectedVideoItem = item
        
        do {
            // Load the video as Data first
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                throw ProcessingError.invalidVideoURL
            }
            
            selectedVideoURL = movie.url
            
            // Get video duration
            let asset = AVURLAsset(url: movie.url)
            let duration = try await asset.load(.duration)
            videoDuration = CMTimeGetSeconds(duration)
            
            // Generate thumbnail
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)
            
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            videoThumbnail = UIImage(cgImage: cgImage)
            
            // Move to sport selection
            withAnimation(.spring(response: 0.4)) {
                currentStep = .selectSport
            }
            
        } catch {
            self.error = .invalidVideoURL
            showError = true
        }
    }
    
    // MARK: - Sport Selection
    
    func selectSport(_ sport: Sport) {
        selectedSport = sport
        
        withAnimation(.spring(response: 0.4)) {
            currentStep = .processing
        }
        
        startProcessing()
    }
    
    // MARK: - Processing
    
    func startProcessing() {
        guard let url = selectedVideoURL,
              let sport = selectedSport,
              let service = processingService else {
            return
        }
        
        // Create initial project
        project = Project(
            sport: sport,
            sourceVideoURL: url,
            originalDuration: videoDuration
        )
        
        // Subscribe to progress updates
        processingTask = Task { [weak self] in
            // Listen for status updates
            for await status in service.statusPublisher.values {
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
        
        // Start processing
        Task { [weak self] in
            do {
                let result = try await service.processVideo(sourceURL: url, sport: sport)
                
                await MainActor.run {
                    self?.project?.segments = result.segments
                    self?.project?.highlightVideoURL = result.highlightURL
                    self?.project?.highlightDuration = result.highlightDuration
                    self?.project?.status = .completed
                    
                    withAnimation(.spring(response: 0.4)) {
                        self?.currentStep = .preview
                    }
                }
            } catch let processingError as ProcessingError {
                await MainActor.run {
                    self?.error = processingError
                    self?.showError = true
                    self?.project?.status = .failed
                }
            } catch {
                await MainActor.run {
                    self?.error = .unknown(error)
                    self?.showError = true
                    self?.project?.status = .failed
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
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to a temporary location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            
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

