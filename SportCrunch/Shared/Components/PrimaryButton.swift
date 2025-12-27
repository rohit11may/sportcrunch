//
//  PrimaryButton.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.bodyBold())
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppGradient.primary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.bodyBold())
            }
            .foregroundStyle(Color.scTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.scSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.scTextTertiary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Sport Button

struct SportButton: View {
    let sport: Sport
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var isDisabled: Bool { sport.isComingSoon }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.md) {
                // Sport Icon
                ZStack {
                    Circle()
                        .fill(isDisabled ? LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom) :
                              (isSelected ? sport.gradient : LinearGradient(colors: [.scSurfaceElevated], startPoint: .top, endPoint: .bottom)))
                        .frame(width: 80, height: 80)
                    
                    Text(sport.emoji)
                        .font(.system(size: 36))
                        .grayscale(isDisabled ? 1.0 : 0)
                        .opacity(isDisabled ? 0.5 : 1.0)
                }
                
                // Sport Name
                VStack(spacing: Spacing.xxs) {
                    Text(sport.displayName)
                        .font(AppFont.subheadline())
                        .foregroundStyle(isDisabled ? Color.scTextTertiary : Color.scTextPrimary)
                    
                    if isDisabled {
                        Text("Coming soon!")
                            .font(AppFont.captionBold())
                            .foregroundStyle(Color.scTextTertiary)
                    } else {
                        Text(sport.description)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.scTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(isDisabled ? Color.scSurface.opacity(0.5) : Color.scSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(isSelected && !isDisabled ? sport.accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed && !isDisabled ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .disabled(isDisabled)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Previews

#Preview("Primary Button") {
    VStack(spacing: 20) {
        PrimaryButton("Create Highlight", icon: "sparkles") {}
        SecondaryButton("Select Video", icon: "photo.on.rectangle") {}
    }
    .padding()
    .background(Color.scBackground)
}

#Preview("Sport Buttons") {
    HStack(spacing: 16) {
        SportButton(sport: .tennis, isSelected: true) {}
        SportButton(sport: .cricket, isSelected: false) {}
    }
    .padding()
    .background(Color.scBackground)
}

