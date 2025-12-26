//
//  HomeView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import Observation

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var viewModel = HomeViewModel()
    @State private var showCreateFlow = false
    @State private var showProgressSheet = false
    @State private var showCompletedSheet = false
    @State private var selectedProcessingProject: Project?
    @State private var selectedCompletedProject: Project?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.scBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Header
                        headerSection
                        
                        // Create button
                        createHighlightButton
                        
                        // Recent projects
                        if viewModel.projects.isEmpty {
                            emptyStateView
                        } else {
                            recentProjectsSection
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCreateFlow) {
                HighlightCreationFlow()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showProgressSheet) {
                if let project = selectedProcessingProject {
                    ProcessingProgressSheet(project: project)
                        .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showCompletedSheet) {
                if let project = selectedCompletedProject {
                    CompletedProjectSheet(project: project)
                }
            }
            .onAppear {
                viewModel.loadProjects(using: appState.projectStorageService)
            }
            .onReceive(appState.backgroundProcessingManager.$statusByProject) { _ in
                // Reload projects when processing status changes
                viewModel.loadProjects(using: appState.projectStorageService)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("SportCrunch")
                    .font(AppFont.displayLarge())
                    .foregroundStyle(Color.scTextPrimary)
                
                Text("Turn hours into highlights")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
            }
            
            Spacer()
            
            // Profile/Settings button
            NavigationLink(destination: SettingsView()) {
                Circle()
                    .fill(Color.scSurface)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.scTextSecondary)
                    )
            }
        }
    }
    
    // MARK: - Create Highlight Button
    
    private var createHighlightButton: some View {
        Button {
            showCreateFlow = true
        } label: {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppGradient.primary)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Create Highlight")
                        .font(AppFont.headline())
                        .foregroundStyle(Color.scTextPrimary)
                    
                    Text("Select a video to get started")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.scTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.scTextTertiary)
            }
            .padding(Spacing.md)
            .background(Color.scSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 40)
            
            // Illustration
            ZStack {
                Circle()
                    .fill(Color.scSurfaceElevated)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "film.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.scTextTertiary)
            }
            
            VStack(spacing: Spacing.xs) {
                Text("No highlights yet")
                    .font(AppFont.headline())
                    .foregroundStyle(Color.scTextPrimary)
                
                Text("Create your first highlight by\nselecting a video above")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }
    
    // MARK: - Recent Projects Section
    
    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent")
                .font(AppFont.headline())
                .foregroundStyle(Color.scTextPrimary)
            
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.projects) { project in
                    ProjectCard(
                        project: projectWithLiveStatus(project),
                        isProcessing: appState.backgroundProcessingManager.isProcessing(projectId: project.id)
                    ) {
                        handleProjectTap(project)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Updates project with live status from background manager if processing
    private func projectWithLiveStatus(_ project: Project) -> Project {
        if appState.backgroundProcessingManager.isProcessing(projectId: project.id) {
            var updatedProject = project
            updatedProject.status = appState.backgroundProcessingManager.status(for: project.id)
            return updatedProject
        }
        return project
    }
    
    /// Handles tap on a project card
    private func handleProjectTap(_ project: Project) {
        // If project is currently processing, show progress sheet
        if appState.backgroundProcessingManager.isProcessing(projectId: project.id) {
            selectedProcessingProject = project
            showProgressSheet = true
        } else if project.status == .completed {
            // Show completed project sheet
            selectedCompletedProject = project
            showCompletedSheet = true
        } else {
            // Failed or other status - could show details or retry option
            viewModel.selectedProject = project
        }
    }
}

// MARK: - Home View Model

@MainActor
@Observable
final class HomeViewModel {
    var projects: [Project] = []
    var selectedProject: Project?
    
    func loadProjects(using storage: ProjectStorageServiceProtocol) {
        projects = storage.loadProjects()
    }
    
    func deleteProject(_ project: Project, using storage: ProjectStorageServiceProtocol) {
        storage.deleteProject(project)
        projects.removeAll { $0.id == project.id }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    HomeView()
        .environmentObject(AppState(
            projectStorageService: MockProjectStorageService(withSampleData: false)
        ))
}

#Preview("With Projects") {
    HomeView()
        .environmentObject(AppState(
            projectStorageService: MockProjectStorageService(withSampleData: true)
        ))
}


