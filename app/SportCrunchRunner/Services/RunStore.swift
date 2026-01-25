//
//  RunStore.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation

/// Thread-safe storage for run lifecycle management
actor RunStore {

    // MARK: - Storage

    private var runs: [UUID: Run] = [:]

    // MARK: - Public Methods

    /// Add a new run to the store
    func add(run: Run) {
        runs[run.id] = run
    }

    /// Update an existing run
    func update(run: Run) {
        runs[run.id] = run
    }

    /// Get a specific run by ID
    func get(id: UUID) -> Run? {
        return runs[id]
    }

    /// Get all runs sorted by creation date (newest first)
    func getAll() -> [Run] {
        return runs.values.sorted { $0.createdAt > $1.createdAt }
    }
}
