//
//  TennisModeSelectionView.swift
//  SportCrunch
//
//  View for selecting between Rally and Individual (Shot) modes for tennis.
//

import SwiftUI

struct TennisModeSelectionView: View {
    var viewModel: HighlightCreationViewModel
    @State private var hoveredMode: TennisMode?
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Header
            VStack(spacing: Spacing.md) {
                // Sport badge
                HStack(spacing: Spacing.xs) {
                    Text(Sport.tennis.emoji)
                        .font(.system(size: 24))
                    Text(Sport.tennis.displayName)
                        .font(AppFont.headline())
                        .foregroundStyle(Color.scTextPrimary)
                }
                
                Text("How should we detect highlights?")
                    .font(AppFont.headline())
                    .foregroundStyle(Color.scTextPrimary)
                
                Text("Choose based on how you want clips grouped")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
            }
            .padding(.top, Spacing.lg)
            
            // Mode options
            VStack(spacing: Spacing.md) {
                ForEach(TennisMode.allCases, id: \.self) { mode in
                    TennisModeButton(
                        mode: mode,
                        isSelected: hoveredMode == mode
                    ) {
                        hoveredMode = mode
                        
                        // Brief delay before proceeding
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.selectTennisMode(mode)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            
            Spacer()
            
            // Info cards
            VStack(spacing: Spacing.sm) {
                modeInfoCard(
                    icon: "arrow.left.arrow.right",
                    title: "Rally Mode",
                    description: "Best for match analysis. Groups consecutive shots into continuous rally clips (5-30s each)."
                )
                
                modeInfoCard(
                    icon: "circlebadge",
                    title: "Shot Mode",
                    description: "Best for technique review. Creates short, snappy clips around each individual shot (~1s each)."
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }
    
    // MARK: - Mode Info Card
    
    private func modeInfoCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Sport.tennis.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.captionBold())
                    .foregroundStyle(Color.scTextPrimary)
                
                Text(description)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.scTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Tennis Mode Button

struct TennisModeButton: View {
    let mode: TennisMode
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                // Mode Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Sport.tennis.gradient : LinearGradient(colors: [.scSurfaceElevated], startPoint: .top, endPoint: .bottom))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: mode.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color.scTextSecondary)
                }
                
                // Mode Info
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(mode.displayName)
                        .font(AppFont.headline())
                        .foregroundStyle(Color.scTextPrimary)
                    
                    Text(mode.description)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.scTextSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.scTextTertiary)
            }
            .padding(Spacing.md)
            .background(Color.scSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(isSelected ? Sport.tennis.accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TennisModeSelectionView(viewModel: {
            let vm = HighlightCreationViewModel()
            vm.selectedSport = .tennis
            vm.videoDuration = 7200
            return vm
        }())
        .background(Color.scBackground)
    }
}

