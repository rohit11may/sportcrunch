//
//  AppState.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import Combine

// MARK: - App State

/// Central app state that manages navigation and shared dependencies
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey)
        }
    }
    
    @Published var selectedTab: Tab = .home
    
    // MARK: - Developer Settings
    
    @Published var developerModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(developerModeEnabled, forKey: developerModeKey)
            updateDebugReportService()
        }
    }
    
    // MARK: - Services
    
    let videoProcessingService: VideoProcessingServiceProtocol
    let projectStorageService: ProjectStorageServiceProtocol
    
    /// Background processing manager for non-blocking video processing
    /// Initialized on first access on the main actor
    @MainActor
    private(set) lazy var backgroundProcessingManager: BackgroundProcessingManager = {
        BackgroundProcessingManager(
            processingService: videoProcessingService,
            storageService: projectStorageService
        )
    }()
    
    // MARK: - Constants
    
    private let onboardingKey = "com.sportcrunch.hasCompletedOnboarding"
    private let developerModeKey = "com.sportcrunch.developerModeEnabled"
    
    // MARK: - Test Mode Detection

    /// Check if running in UI test mode with mock projects
    static var shouldInjectMockProjects: Bool {
        ProcessInfo.processInfo.arguments.contains("-injectMockProjects")
    }

    // MARK: - Initialization

    init(
        videoProcessingService: VideoProcessingServiceProtocol? = nil,
        projectStorageService: ProjectStorageServiceProtocol = UserDefaultsProjectStorageService()
    ) {
        // Initialize stored properties first
        self.projectStorageService = projectStorageService
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)

        // Load developer mode setting
        let developerMode = UserDefaults.standard.bool(forKey: developerModeKey)
        self.developerModeEnabled = developerMode

        // Create video processing service with report manager if in developer mode
        if let customService = videoProcessingService {
            self.videoProcessingService = customService
        } else {
            let reportManager = developerMode ? RealProcessingReportManager() : nil
            self.videoProcessingService = RealVideoProcessingService(reportManager: reportManager)
        }

        // Apply developer mode setting to debug report service on init
        updateDebugReportService()

        // Inject mock projects for UI testing
        if Self.shouldInjectMockProjects {
            injectMockProjectsForTesting()
        }
    }

    // MARK: - Test Helpers

    /// Injects mock completed projects for UI testing
    private func injectMockProjectsForTesting() {
        // Create a completed project with a test highlight video
        var mockProject = Project.sampleCompleted

        // Copy the sample video to the Highlights directory for testing
        let highlightsDir = Project.highlightsDirectory
        try? FileManager.default.createDirectory(at: highlightsDir, withIntermediateDirectories: true)

        // Use the bundle's sample video as a fake highlight
        if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
            let highlightFilename = "test_highlight_\(mockProject.id.uuidString).mp4"
            let destURL = highlightsDir.appendingPathComponent(highlightFilename)

            // Remove existing file if present
            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.copyItem(at: sampleURL, to: destURL)

            mockProject.highlightVideoFilename = highlightFilename
        }

        // Add some starred segments for testing
        mockProject.segments = [
            ActionSegment(startTime: 0, endTime: 2, isStarred: true),
            ActionSegment(startTime: 2, endTime: 4, isStarred: false),
            ActionSegment(startTime: 4, endTime: 6, isStarred: true),
        ]

        // Save the mock project
        projectStorageService.saveProject(mockProject)
    }
    
    // MARK: - Actions
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
    
    // MARK: - Developer Mode
    
    private func updateDebugReportService() {
        Task {
            await DebugReportService.shared.setEnabled(developerModeEnabled)
        }
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case home
    case settings
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .settings: return "gearshape.fill"
        }
    }
}


