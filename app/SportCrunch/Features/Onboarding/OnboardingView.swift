//
//  OnboardingView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI
import Photos

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    @State private var showPermissionAlert = false
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        ZStack {
            MeshGradientBackground()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(AppFont.callout())
                        .foregroundStyle(Color.scTextSecondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .frame(height: 44)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicators and button
                VStack(spacing: Spacing.xl) {
                    // Page dots
                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.scGradientStart : Color.scTextTertiary)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Action button
                    actionButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .alert("Photo Library Access", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {
                completeOnboarding()
            }
        } message: {
            Text("SportCrunch needs access to your photo library to select and process videos. Please enable access in Settings.")
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        let isLastPage = currentPage == pages.count - 1
        
        PrimaryButton(
            isLastPage ? "Get Started" : "Continue",
            icon: isLastPage ? "arrow.right" : nil
        ) {
            if isLastPage {
                requestPhotoLibraryAccess()
            } else {
                withAnimation(.spring(response: 0.4)) {
                    currentPage += 1
                }
            }
        }
    }
    
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    completeOnboarding()
                case .denied, .restricted:
                    showPermissionAlert = true
                case .notDetermined:
                    // Will be handled by the alert
                    break
                @unknown default:
                    completeOnboarding()
                }
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.spring(response: 0.5)) {
            appState.completeOnboarding()
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            // Illustration
            page.illustration
                .frame(height: 280)
            
            // Text content
            VStack(spacing: Spacing.md) {
                Text(page.title)
                    .font(AppFont.displayMedium())
                    .foregroundStyle(Color.scTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Spacing.lg)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Onboarding Page Data

struct OnboardingPage {
    let title: String
    let subtitle: String
    let illustration: AnyView
    
    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            title: "Your Game, Condensed",
            subtitle: "Turn hours of footage into minutes of pure action. No editing skills required.",
            illustration: AnyView(WelcomeIllustration())
        ),
        OnboardingPage(
            title: "Smart Detection",
            subtitle: "Our algorithm listens for the crack of the racket and watches for motion to find every rally.",
            illustration: AnyView(DetectionIllustration())
        ),
        OnboardingPage(
            title: "Ready to Create?",
            subtitle: "Select a video from your library and let SportCrunch do the rest. It's that simple.",
            illustration: AnyView(ReadyIllustration())
        )
    ]
}

// MARK: - Illustrations

struct WelcomeIllustration: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Background circles
            Circle()
                .fill(Color.scGradientStart.opacity(0.1))
                .frame(width: 240, height: 240)
                .offset(y: animate ? -10 : 10)
            
            // Video frame mockup
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.scSurface)
                .frame(width: 200, height: 140)
                .overlay(
                    VStack(spacing: Spacing.sm) {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(i == 1 ? Color.scGradientStart : Color.scSurfaceElevated)
                                    .frame(height: 40)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        
                        // Timeline
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.scSurfaceElevated)
                            .frame(height: 24)
                            .overlay(
                                HStack(spacing: 8) {
                                    ForEach(0..<4) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.scGradientStart.opacity(Double(i) * 0.25 + 0.25))
                                            .frame(width: CGFloat.random(in: 20...40))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                            )
                            .padding(.horizontal, Spacing.md)
                    }
                )
                .scShadow()
            
            // Stats badge
            HStack(spacing: 4) {
                Text("3h")
                    .font(AppFont.captionBold())
                    .foregroundStyle(Color.scTextSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.scTextTertiary)
                Text("18m")
                    .font(AppFont.captionBold())
                    .foregroundStyle(Color.scSuccess)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.scSurfaceElevated)
            .clipShape(Capsule())
            .offset(x: 70, y: -50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct DetectionIllustration: View {
    @State private var showWave = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Audio wave representation
            HStack(spacing: 3) {
                ForEach(0..<20) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            i >= 8 && i <= 12
                                ? Color.scGradientStart
                                : Color.scTextTertiary.opacity(0.5)
                        )
                        .frame(
                            width: 4,
                            height: showWave ? randomHeight(for: i) : 10
                        )
                }
            }
            .offset(y: -60)
            
            // Detection circle
            Circle()
                .stroke(Color.scGradientStart, lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(pulseScale)
                .opacity(2 - pulseScale)
            
            // Tennis ball
            Circle()
                .fill(Color.scTennis)
                .frame(width: 60, height: 60)
                .overlay(
                    // Ball pattern
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 40, height: 40)
                )
                .scShadow()
            
            // Motion lines
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.scTextTertiary.opacity(0.3))
                        .frame(width: 16 - CGFloat(i * 4), height: 3)
                }
            }
            .offset(x: -55)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                showWave = true
            }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 2.0
            }
        }
    }
    
    private func randomHeight(for index: Int) -> CGFloat {
        let peak = index >= 8 && index <= 12
        let baseHeight: CGFloat = peak ? 60 : 30
        return baseHeight + CGFloat.random(in: -10...10)
    }
}

struct ReadyIllustration: View {
    @State private var selectedSport: Sport? = .tennis
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Sport icons
            HStack(spacing: Spacing.md) {
                ForEach(Sport.allCases) { sport in
                    SportMiniIcon(
                        sport: sport,
                        isSelected: selectedSport == sport
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedSport = sport
                        }
                    }
                }
            }
            
            // Arrow
            Image(systemName: "arrow.down")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.scTextTertiary)
            
            // Highlight preview
            RoundedRectangle(cornerRadius: 16)
                .fill(selectedSport?.accentColor.opacity(0.2) ?? Color.scSurfaceElevated)
                .frame(width: 180, height: 100)
                .overlay(
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundStyle(selectedSport?.accentColor ?? .scGradientStart)
                        
                        Text("Highlight Ready")
                            .font(AppFont.captionBold())
                            .foregroundStyle(Color.scTextPrimary)
                    }
                )
                .scShadow()
        }
    }
}

struct SportMiniIcon: View {
    let sport: Sport
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? sport.gradient : LinearGradient(colors: [.scSurfaceElevated], startPoint: .top, endPoint: .bottom))
                .frame(width: 64, height: 64)
            
            Text(sport.emoji)
                .font(.system(size: 28))
        }
        .overlay(
            Circle()
                .stroke(isSelected ? sport.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}

