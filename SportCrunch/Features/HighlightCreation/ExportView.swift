//
//  ExportView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

// MARK: - Export Quality

enum ExportQuality: String, CaseIterable, Identifiable {
    case social = "social"
    case fullQuality = "full"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .social: return "Social"
        case .fullQuality: return "Full Quality"
        }
    }
    
    var description: String {
        switch self {
        case .social: return "Optimized for sharing (1080p)"
        case .fullQuality: return "Original resolution"
        }
    }
    
    var icon: String {
        switch self {
        case .social: return "square.and.arrow.up"
        case .fullQuality: return "sparkles.rectangle.stack"
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    var viewModel: HighlightCreationViewModel
    @State private var selectedQuality: ExportQuality = .social
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            if exportComplete {
                exportCompleteView
            } else {
                exportOptionsView
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }
    
    // MARK: - Export Options View
    
    private var exportOptionsView: some View {
        VStack(spacing: Spacing.xl) {
            // Preview thumbnail
            previewThumbnail
            
            // Quality options
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Export Quality")
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.scTextPrimary)
                
                VStack(spacing: Spacing.sm) {
                    ForEach(ExportQuality.allCases) { quality in
                        ExportQualityOption(
                            quality: quality,
                            isSelected: selectedQuality == quality
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedQuality = quality
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Export button
            if isExporting {
                exportingIndicator
            } else {
                PrimaryButton("Save to Camera Roll", icon: "arrow.down.to.line") {
                    performExport()
                }
            }
        }
    }
    
    // MARK: - Preview Thumbnail
    
    private var previewThumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            if let thumbnail = viewModel.videoThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.scSurfaceElevated)
                    .frame(height: 160)
            }
            
            // Overlay gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Sport and duration badge
            HStack {
                if let sport = viewModel.selectedSport {
                    HStack(spacing: Spacing.xxs) {
                        Text(sport.emoji)
                            .font(.system(size: 14))
                        Text(sport.displayName)
                            .font(AppFont.captionBold())
                    }
                    .foregroundStyle(Color.scTextPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                if let duration = viewModel.project?.formattedHighlightDuration {
                    Text(duration)
                        .font(AppFont.captionBold())
                        .foregroundStyle(Color.scTextPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
            .padding(Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Exporting Indicator
    
    private var exportingIndicator: some View {
        HStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .scGradientStart))
            
            Text("Saving to Camera Roll...")
                .font(AppFont.body())
                .foregroundStyle(Color.scTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Export Complete View
    
    private var exportCompleteView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            // Success animation
            SuccessAnimation()
                .frame(width: 120, height: 120)
            
            VStack(spacing: Spacing.sm) {
                Text("Saved to Camera Roll!")
                    .font(AppFont.displayMedium())
                    .foregroundStyle(Color.scTextPrimary)
                
                Text("Your highlight is ready to share")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
            }
            
            Spacer()
            
            // Share options
            VStack(spacing: Spacing.sm) {
                // Share button
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Share")
                            .font(AppFont.bodyBold())
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppGradient.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                
                // Done button
                SecondaryButton("Done") {
                    viewModel.complete()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performExport() {
        isExporting = true
        
        // Simulate export delay (in real implementation, this would save to camera roll)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.5)) {
                isExporting = false
                exportComplete = true
            }
        }
    }
}

// MARK: - Export Quality Option

struct ExportQualityOption: View {
    let quality: ExportQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.scGradientStart : Color.scTextTertiary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.scGradientStart)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Icon
                Image(systemName: quality.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.scGradientStart : Color.scTextSecondary)
                    .frame(width: 24)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(quality.displayName)
                        .font(AppFont.bodyBold())
                        .foregroundStyle(Color.scTextPrimary)
                    
                    Text(quality.description)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.scTextSecondary)
                }
                
                Spacer()
            }
            .padding(Spacing.md)
            .background(isSelected ? Color.scSurface : Color.scSurfaceElevated.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.scGradientStart.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Export Options") {
    ExportView(viewModel: {
        let vm = HighlightCreationViewModel()
        vm.selectedSport = .tennis
        vm.project = .sampleCompleted
        return vm
    }())
    .background(Color.scBackground)
}

