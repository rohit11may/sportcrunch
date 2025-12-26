//
//  ProcessingView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

struct ProcessingView: View {
    var viewModel: HighlightCreationViewModel
    @StateObject private var logger = ProcessingLogger.shared
    
    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()
            
            // Processing animation
            ProcessingAnimation(sport: viewModel.selectedSport ?? .tennis)
                .frame(width: 160, height: 160)
            
            // Status text
            VStack(spacing: Spacing.sm) {
                Text("Creating Your Highlight")
                    .font(AppFont.displayMedium())
                    .foregroundStyle(Color.scTextPrimary)
                
                Text(viewModel.processingStatus.displayText)
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
                    .animation(.easeInOut, value: viewModel.processingStatus)
            }
            
            // Progress bar
            progressBar
            
            Spacer()
            
            // Live log card
            logCard
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .background(SportThemedBackground(sport: viewModel.selectedSport ?? .tennis))
        .onAppear {
            // Clear previous logs when starting new processing
            logger.clear()
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: Spacing.sm) {
            // Progress track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.scSurfaceElevated)
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(viewModel.selectedSport?.gradient ?? AppGradient.primary)
                        .frame(width: geometry.size.width * viewModel.processingProgress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.processingProgress)
                }
            }
            .frame(height: 8)
            
            // Percentage
            Text("\(Int(viewModel.processingProgress * 100))%")
                .font(AppFont.captionBold())
                .foregroundStyle(Color.scTextSecondary)
        }
        .padding(.horizontal, Spacing.xxl)
    }
    
    // MARK: - Log Card
    
    private var logCard: some View {
        HStack(spacing: Spacing.sm) {
            // Dynamic icon based on log category
            Image(systemName: iconForCategory(logger.currentCategory))
                .font(.system(size: 16))
                .foregroundStyle(colorForCategory(logger.currentCategory))
                .frame(width: 20)
            
            // Log message with animation
            Text(logger.currentMessage.isEmpty ? "Preparing..." : logger.currentMessage)
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
        case .audio:
            return "waveform"
        case .visual:
            return "eye"
        case .export:
            return "film"
        case .pipeline:
            return "gearshape"
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    private func colorForCategory(_ category: ProcessingLogEntry.LogCategory) -> Color {
        switch category {
        case .audio:
            return Color.scPrimary
        case .visual:
            return Color.scSecondary
        case .export:
            return Color.scAccent
        case .pipeline:
            return Color.scTextSecondary
        case .info:
            return Color.scTextSecondary
        case .success:
            return Color.scSuccess
        case .warning:
            return Color.scWarning
        case .error:
            return Color.scError
        }
    }
}

// MARK: - Preview

#Preview {
    ProcessingView(viewModel: {
        let vm = HighlightCreationViewModel()
        vm.selectedSport = .tennis
        vm.processingProgress = 0.45
        vm.processingStatus = .detectingAction
        return vm
    }())
}

