//
//  CompletedProjectSheet.swift
//  SportCrunch
//
//  Sheet view for viewing and playing a completed highlight project.
//

import SwiftUI
import AVKit

struct CompletedProjectSheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.scBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(project.title ?? "Highlight")
                            .font(AppFont.subheadline())
                            .foregroundStyle(Color.scTextPrimary)
                        
                        HStack(spacing: Spacing.xxs) {
                            Text(project.sport.emoji)
                                .font(.system(size: 10))
                            Text(project.sport.displayName)
                                .font(AppFont.caption())
                                .foregroundStyle(Color.scTextSecondary)
                        }
                    }
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
            .toolbarBackground(Color.scBackground, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = project.highlightVideoURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Video Player Area
    
    private var videoPlayerArea: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 240)
                    .onAppear {
                        // Auto-play when view appears
                        player.play()
                        isPlaying = true
                    }
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
                    .frame(height: 240)
                    .overlay(
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.scTextTertiary)
                            Text("Video unavailable")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.scTextSecondary)
                        }
                    )
            }
        }
    }
    
    // MARK: - Stats Summary
    
    private var statsSummary: some View {
        HStack(spacing: Spacing.lg) {
            // Original duration
            statItem(
                label: "Original",
                value: project.formattedOriginalDuration,
                color: .scTextSecondary
            )
            
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.scTextTertiary)
            
            // Highlight duration
            statItem(
                label: "Highlight",
                value: project.formattedHighlightDuration ?? "—",
                color: project.sport.accentColor
            )
            
            Spacer()
            
            // Time saved
            if let timeSaved = project.formattedTimeSaved {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 14))
                    Text(timeSaved)
                        .font(AppFont.captionBold())
                }
                .foregroundStyle(Color.scSuccess)
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
                    legendItem(color: project.sport.accentColor, label: "Kept")
                    legendItem(color: .scTextTertiary.opacity(0.3), label: "Removed")
                }
            }
            
            // Timeline bar
            TimelineVisualization(
                segments: project.segments,
                totalDuration: project.originalDuration,
                accentColor: project.sport.accentColor
            )
            .frame(height: 48)
            
            // Segment count and mode
            HStack {
                Text("\(project.segments.count) action segments")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.scTextSecondary)
                
                if let mode = project.formattedSportMode {
                    Text("•")
                        .foregroundStyle(Color.scTextTertiary)
                    Text(mode)
                        .font(AppFont.caption())
                        .foregroundStyle(project.sport.accentColor)
                }
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
            PrimaryButton("Share Highlight", icon: "square.and.arrow.up") {
                showShareSheet = true
            }
            
            SecondaryButton("Save to Camera Roll", icon: "square.and.arrow.down") {
                saveToPhotoLibrary()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer() {
        guard let url = project.highlightVideoURL else { return }
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: url.path) {
            player = AVPlayer(url: url)
        }
    }
    
    private func saveToPhotoLibrary() {
        guard let url = project.highlightVideoURL else { return }
        
        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    CompletedProjectSheet(project: .sampleCompleted)
}

