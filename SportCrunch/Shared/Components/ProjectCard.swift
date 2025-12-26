//
//  ProjectCard.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import UIKit

struct ProjectCard: View {
    let project: Project
    var isProcessing: Bool = false
    var progress: Double = 0
    let action: () -> Void
    
    @State private var isPressed = false
    
    /// Determines if we should show processing state (from project status or explicit flag)
    private var showsProcessing: Bool {
        isProcessing || project.status.isProcessing
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail
                thumbnailView
                
                // Info Section
                infoSection
            }
            .background(Color.scSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
    
    // MARK: - Thumbnail View
    
    /// Converts the project's thumbnail data to a UIImage
    private var thumbnailImage: UIImage? {
        guard let data = project.thumbnailData else { return nil }
        return UIImage(data: data)
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack(alignment: .topLeading) {
            // Background: Actual thumbnail or gradient placeholder
            if let image = thumbnailImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: 140)
                        .clipped()
                }
                .frame(height: 140)
                .contentShape(Rectangle()) // Constrain hit testing to visible bounds
            } else {
                // Placeholder gradient background
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                project.sport.accentColor.opacity(0.3),
                                project.sport.accentColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)
            }
            
            // Sport badge
            HStack(spacing: Spacing.xxs) {
                Text(project.sport.emoji)
                    .font(.system(size: 14))
                Text(project.sport.displayName)
                    .font(AppFont.captionBold())
            }
            .foregroundStyle(Color.scTextPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.black.opacity(0.5))
            .clipShape(Capsule())
            .padding(Spacing.sm)
            
            // Status indicator for processing
            if showsProcessing {
                VStack {
                    Spacer()
                    processingIndicator
                        .padding(Spacing.sm)
                }
                .frame(height: 140)
            }
            
            // Play button for completed (only if not processing)
            if project.status == .completed && !showsProcessing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        playButton
                        Spacer()
                    }
                    Spacer()
                }
                .frame(height: 140)
            }
        }
    }
    
    private var processingIndicator: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                
                Text(project.status.displayText)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.scTextPrimary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(AppFont.captionBold())
                    .foregroundStyle(Color.scTextPrimary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(project.sport.gradient)
                        .frame(width: max(0, geometry.size.width * progress), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    private var playButton: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 8)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Title
            Text(project.title ?? "Untitled")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.scTextPrimary)
                .lineLimit(1)
            
            // Duration stats
            HStack(spacing: Spacing.md) {
                durationStat(
                    label: "Original",
                    value: project.formattedOriginalDuration,
                    color: .scTextSecondary
                )
                
                if let highlightDuration = project.formattedHighlightDuration {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.scTextTertiary)
                    
                    durationStat(
                        label: "Highlight",
                        value: highlightDuration,
                        color: project.sport.accentColor
                    )
                }
            }
            
            // Savings badges
            HStack(spacing: Spacing.md) {
                if let timeSaved = project.formattedTimeSaved {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 11))
                        Text(timeSaved)
                            .font(AppFont.captionBold())
                    }
                    .foregroundStyle(Color.scSuccess)
                }
                
                if let spaceSaved = project.formattedSpaceSaved {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "externaldrive.badge.checkmark")
                            .font(.system(size: 11))
                        Text(spaceSaved)
                            .font(AppFont.captionBold())
                    }
                    .foregroundStyle(Color.scSuccess)
                }
            }
            .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
    }
    
    private func durationStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextTertiary)
            
            Text(value)
                .font(AppFont.callout())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Previews

#Preview("Project Card - Completed") {
    ProjectCard(project: .sampleCompleted) {}
        .frame(width: 280)
        .padding()
        .background(Color.scBackground)
}

#Preview("Project Card - Processing") {
    var project = Project.sampleTennis
    project.status = .detectingAction
    
    return ProjectCard(project: project, isProcessing: true, progress: 0.45) {}
        .padding()
        .background(Color.scBackground)
}

