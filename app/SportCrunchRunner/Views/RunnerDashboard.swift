//
//  RunnerDashboard.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import SwiftUI

/// Main dashboard view displaying server status and recent runs
struct RunnerDashboard: View {
  @ObservedObject var server: HTTPServer
  let store: RunStore
  let deviceManager: DeviceManager

  @State private var runs: [Run] = []
  @State private var serverURL: String = ""
  @State private var copyButtonText: String = "Copy"
  @State private var availableDevices: [DeviceInfo] = []
  @State private var selectedDevice: DeviceTarget = .simulator
  @State private var isLoadingDevices = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Header section
        headerSection

        Divider()
          .padding(.vertical, 16)

        // Run list section
        runListSection

        Spacer()
      }
      .padding()
      .navigationTitle("SportCrunch Runner")
      .navigationBarTitleDisplayMode(.large)
      .task {
        // Initial load
        await refreshRuns()

        // Poll for updates every 2 seconds
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          await refreshRuns()
        }
      }
    }
  }

  // MARK: - Header Section

  @ViewBuilder
  private var headerSection: some View {
    VStack(spacing: 12) {
      // Server status indicator
      HStack(spacing: 8) {
        Circle()
          .fill(serverStatusColor)
          .frame(width: 12, height: 12)

        Text(serverStatusText)
          .font(.headline)
          .foregroundStyle(serverStatusColor)
      }

      // Server URL
      if case .running(let port, let ipAddress) = server.state {
        let portString = String(port)
        VStack(spacing: 8) {
          Text("http://\(ipAddress):\(portString)")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.blue)
            .textSelection(.enabled)
            .onAppear {
              serverURL = "http://\(ipAddress):\(portString)"
            }

          Button(action: copyServerURL) {
            Label(copyButtonText, systemImage: "doc.on.doc")
              .font(.caption)
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }

  // MARK: - Run List Section

  @ViewBuilder
  private var runListSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent Runs")
          .font(.headline)

        Spacer()

        Text("\(runs.count) total")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if runs.isEmpty {
        emptyState
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(runs) { run in
              RunStatusRow(run: run)

              if run.id != runs.last?.id {
                Divider()
                  .padding(.leading, 26)
              }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "tray")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("No runs yet")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Trigger from dashboard with POST /runs")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  // MARK: - Computed Properties

  private var serverStatusColor: Color {
    switch server.state {
    case .stopped, .error:
      return .red
    case .starting:
      return .orange
    case .running:
      return .green
    }
  }

  private var serverStatusText: String {
    switch server.state {
    case .stopped:
      return "Server Stopped"
    case .starting:
      return "Starting Server..."
    case .running:
      return "Server Running"
    case .error(let message):
      return "Server Error: \(message)"
    }
  }

  // MARK: - Actions

  private func refreshRuns() async {
    runs = await store.getAll()
  }

  private func copyServerURL() {
    UIPasteboard.general.string = serverURL
    copyButtonText = "Copied!"

    // Reset button text after 2 seconds
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      copyButtonText = "Copy"
    }
  }
}

// MARK: - Preview

#Preview {
  RunnerDashboard(
    server: {
      let server = HTTPServer()
      return server
    }(),
    store: RunStore(),
    deviceManager: DeviceManager()
  )
}
