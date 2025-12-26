//
//  PreviewView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import AVKit

struct PreviewView: View {
    var viewModel: HighlightCreationViewModel
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var showSuccessAnimation = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Success animation overlay (shown briefly)
            if showSuccessAnimation {
                successOverlay
            } else {
                // Video player area
                videoPlayerArea
                
                // Stats summary
                statsSummary
                
                // Timeline visualization
                timelineSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
        }
        .padding(.bottom, Spacing.xl)
        .onAppear {
            // Show success animation briefly
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.5)) {
                    showSuccessAnimation = false
                }
            }
        }
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            SuccessAnimation()
                .frame(width: 150, height: 150)
            
            VStack(spacing: Spacing.sm) {
                Text("Highlight Ready!")
                    .font(AppFont.displayMedium())
                    .foregroundStyle(Color.scTextPrimary)
                
                if let project = viewModel.project {
                    Text("\(project.formattedOriginalDuration) → \(project.formattedHighlightDuration ?? "N/A")")
                        .font(AppFont.headline())
                        .foregroundStyle(Color.scSuccess)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Video Player Area
    
    private var videoPlayerArea: some View {
        ZStack {
            // Thumbnail/Player placeholder
            if let thumbnail = viewModel.videoThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.scSurfaceElevated)
                    .frame(height: 300)
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Play button
            Button {
                isPlaying.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .offset(x: isPlaying ? 0 : 3)
                }
            }
            
            // Progress indicator at bottom
            VStack {
                Spacer()
                
                // Playback progress
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(viewModel.selectedSport?.accentColor ?? .scGradientStart)
                            .frame(width: geometry.size.width * 0.3, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
    }
    
    // MARK: - Stats Summary
    
    private var statsSummary: some View {
        VStack(spacing: Spacing.sm) {
            // Duration row
            HStack(spacing: Spacing.lg) {
                // Original duration
                statItem(
                    label: "Original",
                    value: viewModel.project?.formattedOriginalDuration ?? "—",
                    color: .scTextSecondary
                )
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.scTextTertiary)
                
                // Highlight duration
                statItem(
                    label: "Highlight",
                    value: viewModel.project?.formattedHighlightDuration ?? "—",
                    color: viewModel.selectedSport?.accentColor ?? .scGradientStart
                )
                
                Spacer()
            }
            
            // Savings row
            HStack(spacing: Spacing.lg) {
                // Time saved
                if let timeSaved = viewModel.project?.formattedTimeSaved {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 14))
                        Text(timeSaved)
                            .font(AppFont.captionBold())
                    }
                    .foregroundStyle(Color.scSuccess)
                }
                
                // Space saved
                if let spaceSaved = viewModel.project?.formattedSpaceSaved {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "externaldrive.badge.checkmark")
                            .font(.system(size: 14))
                        Text(spaceSaved)
                            .font(AppFont.captionBold())
                    }
                    .foregroundStyle(Color.scSuccess)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.scSurface)
    }
    
    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextTertiary)
            
            Text(value)
                .font(AppFont.bodyBold())
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Timeline Section
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Timeline")
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.scTextPrimary)
                
                Spacer()
                
                // Legend
                HStack(spacing: Spacing.md) {
                    legendItem(color: viewModel.selectedSport?.accentColor ?? .scGradientStart, label: "Kept")
                    legendItem(color: .scTextTertiary.opacity(0.3), label: "Removed")
                }
            }
            
            // Timeline bar
            TimelineVisualization(
                segments: viewModel.project?.segments ?? [],
                totalDuration: viewModel.project?.originalDuration ?? 0,
                accentColor: viewModel.selectedSport?.accentColor ?? .scGradientStart
            )
            .frame(height: 48)
            
            // Segment count
            if let segmentCount = viewModel.project?.segments.count {
                Text("\(segmentCount) action segments detected")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.scTextSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextSecondary)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton("Export Highlight", icon: "square.and.arrow.up") {
                viewModel.proceedToExport()
            }
            
            SecondaryButton("Watch Full Preview", icon: "play.rectangle") {
                // TODO: Implement full preview playback
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Timeline Visualization

struct TimelineVisualization: View {
    let segments: [ActionSegment]
    let totalDuration: TimeInterval
    let accentColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background (removed time)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.scSurfaceElevated)
                
                // Kept segments
                ForEach(segments) { segment in
                    let startX = (segment.startTime / totalDuration) * geometry.size.width
                    let width = (segment.duration / totalDuration) * geometry.size.width
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(width, 4))
                        .offset(x: startX)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview

#Preview {
    PreviewView(viewModel: {
        let vm = HighlightCreationViewModel()
        vm.selectedSport = .tennis
        vm.videoDuration = 7200
        vm.project = .sampleCompleted
        return vm
    }())
    .background(Color.scBackground)
}

