//
//  VideoSelectionView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import PhotosUI

struct VideoSelectionView: View {
    @Bindable var viewModel: HighlightCreationViewModel
    @State private var showPicker = false
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            // Illustration
            illustrationView
            
            // Text
            VStack(spacing: Spacing.sm) {
                Text("Select Your Video")
                    .font(AppFont.displayMedium())
                    .foregroundStyle(Color.scTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose a sports video from your library.\nWe'll find and keep all the action.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Select button
            PhotosPicker(
                selection: $viewModel.selectedVideoItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Choose from Library")
                        .font(AppFont.bodyBold())
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppGradient.primary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .accessibilityIdentifier(AccessibilityID.Creation.videoLibraryButton)
            .onChange(of: viewModel.selectedVideoItem) { _, newItem in
                if let item = newItem {
                    viewModel.selectVideo(item)
                }
            }
            
            // Tip
            tipView
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }
    
    // MARK: - Illustration
    
    private var illustrationView: some View {
        ZStack {
            // Background circles
            Circle()
                .fill(Color.scGradientStart.opacity(0.08))
                .frame(width: 200, height: 200)
            
            Circle()
                .fill(Color.scGradientEnd.opacity(0.05))
                .frame(width: 260, height: 260)
            
            // Video icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.scSurface)
                    .frame(width: 120, height: 80)
                    .scShadow()
                
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.scGradientStart, .scGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Decorative sport icons
            Text("🎾")
                .font(.system(size: 28))
                .offset(x: -80, y: -60)
                .opacity(0.8)
            
            Text("🏏")
                .font(.system(size: 28))
                .offset(x: 85, y: 50)
                .opacity(0.8)
        }
        .frame(height: 260)
    }
    
    // MARK: - Tip View
    
    private var tipView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.scWarning)
            
            Text("Tip: Longer videos work great—we'll condense hours into minutes")
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VideoSelectionView(viewModel: HighlightCreationViewModel())
            .background(Color.scBackground)
    }
}

