//
//  ProcessingProgressSheet.swift
//  SportCrunch
//
//  Sheet view showing progress of a background processing job.
//  Displayed when user taps on an in-progress project from HomeView.
//

import SwiftUI

struct ProcessingProgressSheet: View {
    let project: Project
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logger = ProcessingLogger.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sport-themed background
                SportThemedBackground(sport: project.sport)
                
                VStack(spacing: Spacing.xxl) {
                    Spacer()
                    
                    // Processing animation
                    ProcessingAnimation(sport: project.sport)
                        .frame(width: 140, height: 140)
                    
                    // Status text
                    VStack(spacing: Spacing.sm) {
                        Text("Creating Highlight")
                            .font(AppFont.displayMedium())
                            .foregroundStyle(Color.scTextPrimary)
                        
                        Text(currentStatus.displayText)
                            .font(AppFont.body())
                            .foregroundStyle(Color.scTextSecondary)
                            .animation(.easeInOut, value: currentStatus)
                        
                        // Sport mode badge if applicable
                        if let modeDisplay = project.formattedSportMode {
                            Text(modeDisplay)
                                .font(AppFont.caption())
                                .foregroundStyle(project.sport.accentColor)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xxs)
                                .background(project.sport.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Progress bar
                    progressBar
                    
                    Spacer()
                    
                    // Log card
                    logCard
                    
                    // Info text
                    Text("Processing continues in background.\nYou can close this sheet.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.scTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Spacing.md)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(project.sport.displayName)
                        .font(AppFont.subheadline())
                        .foregroundStyle(Color.scTextPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
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
            .toolbarBackground(Color.clear, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Computed Properties
    
    private var currentProgress: Double {
        appState.backgroundProcessingManager.progress(for: project.id)
    }
    
    private var currentStatus: ProcessingStatus {
        appState.backgroundProcessingManager.status(for: project.id)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: Spacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.scSurfaceElevated)
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(project.sport.gradient)
                        .frame(width: geometry.size.width * currentProgress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentProgress)
                }
            }
            .frame(height: 8)
            
            // Percentage
            Text("\(Int(currentProgress * 100))%")
                .font(AppFont.captionBold())
                .foregroundStyle(Color.scTextSecondary)
        }
        .padding(.horizontal, Spacing.xxl)
    }
    
    // MARK: - Log Card
    
    private var logCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: iconForCategory(logger.currentCategory))
                .font(.system(size: 16))
                .foregroundStyle(colorForCategory(logger.currentCategory))
                .frame(width: 20)
            
            Text(logger.currentMessage.isEmpty ? "Processing..." : logger.currentMessage)
                .font(AppFont.callout())
                .foregroundStyle(Color.scTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .animation(.easeInOut(duration: 0.2), value: logger.currentMessage)
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Helper Methods
    
    private func iconForCategory(_ category: ProcessingLogEntry.LogCategory) -> String {
        switch category {
        case .audio: return "waveform"
        case .visual: return "eye"
        case .export: return "film"
        case .pipeline: return "gearshape"
        case .info: return "info.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    private func colorForCategory(_ category: ProcessingLogEntry.LogCategory) -> Color {
        switch category {
        case .audio: return Color.scPrimary
        case .visual: return Color.scSecondary
        case .export: return Color.scAccent
        case .pipeline: return Color.scTextSecondary
        case .info: return Color.scTextSecondary
        case .success: return Color.scSuccess
        case .warning: return Color.scWarning
        case .error: return Color.scError
        }
    }
}

// MARK: - Preview

#Preview {
    ProcessingProgressSheet(project: {
        var project = Project.sampleTennis
        project.status = .detectingAction
        return project
    }())
    .environmentObject(AppState())
}

