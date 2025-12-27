//
//  SettingsView.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var defaultSport: Sport = .tennis
    @State private var autoSaveToLibrary = true
    @State private var showResetAlert = false
    @State private var showDebugReportsSheet = false
    @State private var debugReportCount = 0
    
    var body: some View {
        ZStack {
            Color.scBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Default Sport Section
                    settingsSection(title: "Defaults") {
                        defaultSportPicker
                        
                        toggleRow(
                            title: "Auto-save to Library",
                            subtitle: "Save highlights automatically after export",
                            isOn: $autoSaveToLibrary
                        )
                    }
                    
                    // About Section
                    settingsSection(title: "About") {
                        infoRow(title: "Version", value: "1.0.0")
                        
                        linkRow(title: "Privacy Policy", icon: "lock.shield") {
                            // Open privacy policy
                        }
                    }
                    
                    // Debug Section (for development)
                    // Note: Temporarily always visible for debugging simulator vs device differences
                    settingsSection(title: "Developer") {
                        debugReportsRow
                        
                        #if DEBUG
                        linkRow(title: "Reset Onboarding", icon: "arrow.counterclockwise") {
                            showResetAlert = true
                        }
                        
                        linkRow(title: "Clear All Projects", icon: "trash", isDestructive: true) {
                            // Clear projects
                        }
                        #endif
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.scBackground, for: .navigationBar)
        .alert("Reset Onboarding", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                appState.resetOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will show the onboarding screens again next time you launch the app.")
        }
        .sheet(isPresented: $showDebugReportsSheet) {
            DebugReportsListView()
        }
        .onAppear {
            updateDebugReportCount()
        }
    }
    
    // MARK: - Debug Reports Row
    
    private var debugReportsRow: some View {
        Button {
            showDebugReportsSheet = true
        } label: {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.scTextSecondary)
                    .frame(width: 24)
                
                Text("Debug Reports")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextPrimary)
                
                Spacer()
                
                Text("\(debugReportCount)")
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.scTextTertiary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.scSurface)
        }
        .buttonStyle(.plain)
    }
    
    private func updateDebugReportCount() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsURL.appendingPathComponent("DebugReports", isDirectory: true)
        
        if let files = try? FileManager.default.contentsOfDirectory(atPath: reportsDir.path) {
            debugReportCount = files.filter { $0.hasSuffix(".json") }.count
        }
    }
    
    // MARK: - Settings Section
    
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextTertiary)
                .padding(.leading, Spacing.xs)
            
            VStack(spacing: 1) {
                content()
            }
            .background(Color.scSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }
    
    // MARK: - Default Sport Picker
    
    private var defaultSportPicker: some View {
        HStack {
            Text("Default Sport")
                .font(AppFont.body())
                .foregroundStyle(Color.scTextPrimary)
            
            Spacer()
            
            Menu {
                ForEach(Sport.allCases) { sport in
                    Button {
                        defaultSport = sport
                    } label: {
                        HStack {
                            Text("\(sport.emoji) \(sport.displayName)")
                            if defaultSport == sport {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(defaultSport.emoji)
                    Text(defaultSport.displayName)
                        .font(AppFont.body())
                        .foregroundStyle(Color.scTextSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.scTextTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.scSurface)
    }
    
    // MARK: - Toggle Row
    
    private func toggleRow(
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body())
                    .foregroundStyle(Color.scTextPrimary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.scTextSecondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .tint(Color.scGradientStart)
                .labelsHidden()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.scSurface)
    }
    
    // MARK: - Info Row
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(Color.scTextPrimary)
            
            Spacer()
            
            Text(value)
                .font(AppFont.body())
                .foregroundStyle(Color.scTextSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.scSurface)
    }
    
    // MARK: - Link Row
    
    private func linkRow(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isDestructive ? Color.scError : Color.scTextSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(AppFont.body())
                    .foregroundStyle(isDestructive ? Color.scError : Color.scTextPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.scTextTertiary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.scSurface)
        }
        .buttonStyle(.plain)
    }
    
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}

