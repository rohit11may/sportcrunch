//
//  SportCrunchRunnerApp.swift
//  SportCrunchRunner
//
//  Created by Rohit Prasad on 21/01/2026.
//

import SwiftUI

@main
struct SportCrunchRunnerApp: App {
    @StateObject private var httpServer = HTTPServer()

    // Initialize services (not @StateObject because they're actors/classes)
    private let runStore = RunStore()
    private let artifactExporter = ArtifactExporter()
    private let runExecutor: RunExecutor

    init() {
        runExecutor = RunExecutor(store: runStore, exporter: artifactExporter)
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Image(systemName: "server.rack")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("SportCrunch Runner")
                    .font(.title)
                    .fontWeight(.bold)

                statusView

                Spacer()
            }
            .padding()
            .onAppear {
                // Register endpoints before server starts
                HealthEndpoint.register(on: httpServer)
                RunEndpoints.register(on: httpServer, store: runStore, executor: runExecutor)
                httpServer.start()
            }
            .onDisappear {
                httpServer.stop()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch httpServer.state {
        case .stopped:
            Text("Server Stopped")
                .foregroundStyle(.secondary)

        case .starting:
            ProgressView()
                .progressViewStyle(.circular)
            Text("Starting Server...")
                .foregroundStyle(.secondary)

        case .running(let port, let ipAddress):
            VStack(spacing: 8) {
                Text("Server Running")
                    .font(.headline)
                    .foregroundStyle(.green)

                Text("http://\(ipAddress):\(port)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)

                VStack(spacing: 4) {
                    Text("Health: /health")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Runs: POST /runs, GET /runs, GET /runs/:id")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .error(let message):
            VStack {
                Text("Server Error")
                    .font(.headline)
                    .foregroundStyle(.red)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
