//
//  ContentView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    ZStack {
      if appState.hasCompletedOnboarding {
        HomeView()
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      } else {
        OnboardingView()
          .transition(.opacity.combined(with: .move(edge: .leading)))
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.hasCompletedOnboarding)
  }
}

// MARK: - Preview

#Preview("Onboarding") {
  ContentView()
    .environmentObject(AppState())
}

#Preview("Home") {
  let appState = AppState(
    projectStorageService: MockProjectStorageService(withSampleData: true)
  )
  appState.hasCompletedOnboarding = true

  return ContentView()
    .environmentObject(appState)
}
