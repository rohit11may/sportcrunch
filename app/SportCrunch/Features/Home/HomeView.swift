//
//  HomeView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import Observation
import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var appState: AppState
  @State private var viewModel = HomeViewModel()
  @State private var showCreateFlow = false
  @State private var selectedCompletedProject: Project?

  // Track progress and status for reactive updates
  @State private var progressByProject: [UUID: Double] = [:]
  @State private var statusByProject: [UUID: ProcessingStatus] = [:]

  // Delete confirmation
  @State private var showDeleteConfirmation = false
  @State private var projectToDelete: Project?

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
      .sheet(item: $selectedCompletedProject) { project in
        // Create ViewModel with the selected project
        let sheetViewModel = CompletedProjectViewModel(
          project: viewModel.projects.first(where: { $0.id == project.id }) ?? project,
          storageService: appState.projectStorageService
        )
        CompletedProjectSheet(viewModel: sheetViewModel)
          .onChange(of: sheetViewModel.project) { _, updatedProject in
            // Sync changes back to viewModel.projects
            if let index = viewModel.projects.firstIndex(where: { $0.id == updatedProject.id }) {
              viewModel.projects[index] = updatedProject
            }
          }
      }
      .alert("Delete Highlight?", isPresented: $showDeleteConfirmation) {
        Button("Cancel", role: .cancel) {
          projectToDelete = nil
        }
        Button("Delete", role: .destructive) {
          if let project = projectToDelete {
            deleteProject(project)
          }
        }
      } message: {
        if let project = projectToDelete {
          Text(
            "Are you sure you want to delete \"\(project.title ?? "this highlight")\"? This action cannot be undone."
          )
        }
      }
      .onAppear {
        viewModel.loadProjects(using: appState.projectStorageService)
        // Initialize progress/status from background manager
        progressByProject = appState.backgroundProcessingManager.progressByProject
        statusByProject = appState.backgroundProcessingManager.statusByProject
      }
      .onReceive(appState.backgroundProcessingManager.$statusByProject) { newStatus in
        statusByProject = newStatus
        // Reload projects when processing status changes
        viewModel.loadProjects(using: appState.projectStorageService)
      }
      .onReceive(appState.backgroundProcessingManager.$progressByProject) { newProgress in
        progressByProject = newProgress
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
      .accessibilityIdentifier(AccessibilityID.Home.settingsButton)
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
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.Home.createHighlightButton)
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
    .accessibilityIdentifier(AccessibilityID.Home.emptyStateView)
  }

  // MARK: - Recent Projects Section

  private var recentProjectsSection: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      Text("Recent")
        .font(AppFont.headline())
        .foregroundStyle(Color.scTextPrimary)

      LazyVStack(spacing: Spacing.md) {
        ForEach(viewModel.projects) { project in
          let isProcessing = appState.backgroundProcessingManager.isProcessing(
            projectId: project.id)
          let progress = progressByProject[project.id] ?? 0

          ProjectCard(
            project: projectWithLiveStatus(project),
            isProcessing: isProcessing,
            progress: progress,
            action: {
              handleProjectTap(project)
            },
            onLongPress: {
              projectToDelete = project
              showDeleteConfirmation = true
            }
          )
          .accessibilityIdentifier(AccessibilityID.Home.projectCard(id: project.id.uuidString))
        }
      }
    }
  }

  // MARK: - Helper Methods

  /// Updates project with live status from background manager if processing
  private func projectWithLiveStatus(_ project: Project) -> Project {
    if appState.backgroundProcessingManager.isProcessing(projectId: project.id) {
      var updatedProject = project
      updatedProject.status = statusByProject[project.id] ?? project.status
      return updatedProject
    }
    return project
  }

  /// Handles tap on a project card
  private func handleProjectTap(_ project: Project) {
    // If project is currently processing, do nothing (progress shown inline)
    if appState.backgroundProcessingManager.isProcessing(projectId: project.id) {
      return
    } else if project.status == .completed {
      // Show completed project sheet (setting the item triggers the sheet)
      selectedCompletedProject = project
    } else {
      // Failed or other status - could show details or retry option
      viewModel.selectedProject = project
    }
  }

  /// Deletes a project after confirmation
  private func deleteProject(_ project: Project) {
    withAnimation(.easeInOut(duration: 0.3)) {
      viewModel.deleteProject(project, using: appState.projectStorageService)
    }
    projectToDelete = nil
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
    .environmentObject(
      AppState(
        projectStorageService: MockProjectStorageService(withSampleData: false)
      ))
}

#Preview("With Projects") {
  HomeView()
    .environmentObject(
      AppState(
        projectStorageService: MockProjectStorageService(withSampleData: true)
      ))
}
