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
    @State private var isSavedToCameraRoll = false
    
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
                    .frame(height: 320)
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
                    .frame(height: 320)
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
        HStack(spacing: Spacing.md) {
            // Duration: Original → Highlight
            HStack(spacing: Spacing.xs) {
                Text(project.formattedOriginalDuration)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.scTextSecondary)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.scTextTertiary)
                
                Text(project.formattedHighlightDuration ?? "—")
                    .font(AppFont.captionBold())
                    .foregroundStyle(project.sport.accentColor)
            }
            
            // Divider
            Circle()
                .fill(Color.scTextTertiary.opacity(0.5))
                .frame(width: 3, height: 3)
            
            // Space saved badge
            if let spaceSaved = project.formattedSpaceSaved {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(spaceSaved)
                        .font(AppFont.captionBold())
                }
                .foregroundStyle(Color.scSuccess)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.scSurface)
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
        HStack(spacing: Spacing.md) {
            // Share button
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share")
                        .font(AppFont.captionBold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.scGradientStart, .scGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            
            // Save to Camera Roll button
            Button {
                if !isSavedToCameraRoll {
                    saveToPhotoLibrary()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: isSavedToCameraRoll ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isSavedToCameraRoll ? "Saved" : "Save")
                        .font(AppFont.captionBold())
                }
                .foregroundStyle(isSavedToCameraRoll ? Color.scSuccess : Color.scTextPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSavedToCameraRoll ? Color.scSuccess.opacity(0.2) : Color.scSurfaceElevated)
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer() {
        guard let url = project.highlightVideoURL else {
            print("⚠️ [CompletedProjectSheet] No highlight URL stored")
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ [CompletedProjectSheet] Video file not found at: \(url.path)")
            return
        }
        
        // Create player with error observation
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe for playback errors
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("⚠️ [CompletedProjectSheet] Playback error: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveToPhotoLibrary() {
        guard let url = project.highlightVideoURL else { return }
        
        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
        
        withAnimation(.spring(response: 0.4)) {
            isSavedToCameraRoll = true
        }
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

