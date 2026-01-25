//
//  SportSelectionView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

struct SportSelectionView: View {
    var viewModel: HighlightCreationViewModel
    @State private var hoveredSport: Sport?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Video preview
            videoPreviewCard

            // Sport selection
            VStack(spacing: Spacing.md) {
                Text("What sport is this?")
                    .font(AppFont.headline())
                    .foregroundStyle(Color.scTextPrimary)

                Text("Select the sport so we can tune detection")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
            }

            // Sport options
            HStack(spacing: Spacing.md) {
                ForEach(Sport.allCases) { sport in
                    SportButton(
                        sport: sport,
                        isSelected: hoveredSport == sport
                    ) {
                        hoveredSport = sport

                        // Brief delay before proceeding
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.selectSport(sport)
                        }
                    }
                    .accessibilityIdentifier(sport == .tennis ? AccessibilityID.Creation.sportTennisButton : AccessibilityID.Creation.sportCricketButton)
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            // Info card
            infoCard
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Video Preview Card

    private var videoPreviewCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail
            if let thumbnail = viewModel.videoThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.scSurfaceElevated)
                    .frame(height: 180)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Duration badge
            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(viewModel.formattedVideoDuration)
                    .font(AppFont.captionBold())
            }
            .foregroundStyle(Color.scTextPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.black.opacity(0.5))
            .clipShape(Capsule())
            .padding(Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.scSurfaceElevated, lineWidth: 1)
        )
        .accessibilityIdentifier(AccessibilityID.Creation.videoPreview)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 20))
                .foregroundStyle(Color.scGradientStart)

            VStack(alignment: .leading, spacing: 2) {
                Text("Processing takes 1-3 minutes")
                    .font(AppFont.callout())
                    .foregroundStyle(Color.scTextPrimary)

                Text("Your original video will remain unchanged")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.scTextSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SportSelectionView(viewModel: {
            let vm = HighlightCreationViewModel()
            vm.videoDuration = 7200
            return vm
        }())
        .background(Color.scBackground)
    }
}
