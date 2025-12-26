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
final class AppState: ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey)
        }
    }
    
    @Published var selectedTab: Tab = .home
    
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
    
    // MARK: - Initialization
    
    init(
        videoProcessingService: VideoProcessingServiceProtocol = RealVideoProcessingService(),
        projectStorageService: ProjectStorageServiceProtocol = UserDefaultsProjectStorageService()
    ) {
        self.videoProcessingService = videoProcessingService
        self.projectStorageService = projectStorageService
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }
    
    // MARK: - Actions
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
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


