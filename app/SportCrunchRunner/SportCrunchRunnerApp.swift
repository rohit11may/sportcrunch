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
            RunnerDashboard(server: httpServer, store: runStore)
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
}
