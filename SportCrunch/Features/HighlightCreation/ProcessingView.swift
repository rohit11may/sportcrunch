//
//  ProcessingView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

struct ProcessingView: View {
    var viewModel: HighlightCreationViewModel
    @State private var currentTipIndex = 0
    
    private let tips: [String] = [
        "Analyzing the audio track for distinctive impact sounds...",
        "Tennis racket-ball impacts have a unique acoustic signature",
        "Motion detection helps verify the action segments",
        "Almost there—creating your highlight clips...",
        "Fun fact: Professional tennis matches have ~20% actual gameplay",
        "Your original video remains completely unchanged"
    ]
    
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
            
            // Rotating tips
            tipCard
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .background(SportThemedBackground(sport: viewModel.selectedSport ?? .tennis))
        .onAppear {
            startTipRotation()
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
    
    // MARK: - Tip Card
    
    private var tipCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.scWarning)
            
            Text(tips[currentTipIndex])
                .font(AppFont.callout())
                .foregroundStyle(Color.scTextSecondary)
                .lineLimit(2)
                .animation(.easeInOut, value: currentTipIndex)
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Tip Rotation
    
    private func startTipRotation() {
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation {
                currentTipIndex = (currentTipIndex + 1) % tips.count
            }
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

