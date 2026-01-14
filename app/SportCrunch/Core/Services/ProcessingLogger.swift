//
//  ProcessingLogger.swift
//  SportCrunch
//
//  Provides observable logging for the processing pipeline.
//  Log messages are surfaced in the UI during video processing.
//

import Foundation
import Combine

// MARK: - Verbosity Level

enum VerbosityLevel: Int, Comparable {
    case normal = 0   // High-level progress messages
    case verbose = 1  // Detailed stats and configuration
    case debug = 2    // Frame-level debug info, fingerprints

    static func < (lhs: VerbosityLevel, rhs: VerbosityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Entry

struct ProcessingLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let category: LogCategory
    
    enum LogCategory: String {
        case audio = "🎵"
        case visual = "👁️"
        case export = "📼"
        case pipeline = "⚙️"
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
    }
    
    /// User-friendly display text (without emoji prefix)
    var displayText: String {
        message
    }
    
    /// Full text with category emoji for console logging
    var consoleText: String {
        "[\(category.rawValue)] \(message)"
    }
}

// MARK: - Processing Logger

/// Observable logger that captures processing events for UI display.
/// Uses MainActor to ensure thread-safe updates to published properties.
@MainActor
final class ProcessingLogger: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The most recent log entry (for single-line display)
    @Published private(set) var currentMessage: String = ""
    
    /// Current category for styling
    @Published private(set) var currentCategory: ProcessingLogEntry.LogCategory = .info
    
    /// All log entries (for detailed view if needed)
    @Published private(set) var entries: [ProcessingLogEntry] = []
    
    // MARK: - Configuration
    
    /// Maximum number of entries to keep in memory
    private let maxEntries = 100

    /// Whether to also print to console (useful for debugging)
    var printToConsole = true

    /// Current verbosity level - controls which messages are logged
    var verbosity: VerbosityLevel = .verbose
    
    // MARK: - Shared Instance
    
    /// Shared instance for global access from actors
    static let shared = ProcessingLogger()
    
    private init() {}
    
    // MARK: - Logging Methods

    /// Log a message with a category and verbosity level
    func log(_ message: String, category: ProcessingLogEntry.LogCategory = .info, level: VerbosityLevel = .normal) {
        // Skip messages above current verbosity level
        guard level <= verbosity else { return }

        let entry = ProcessingLogEntry(
            timestamp: Date(),
            message: message,
            category: category
        )
        
        entries.append(entry)
        currentMessage = message
        currentCategory = category
        
        // Trim old entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        
        // Console output for debugging
        if printToConsole {
            print(entry.consoleText)
        }
    }
    
    /// Clear all log entries
    func clear() {
        entries.removeAll()
        currentMessage = ""
        currentCategory = .info
    }
    
    // MARK: - Convenience Methods
    
    func audio(_ message: String) {
        log(message, category: .audio)
    }
    
    func visual(_ message: String) {
        log(message, category: .visual)
    }
    
    func export(_ message: String) {
        log(message, category: .export)
    }
    
    func pipeline(_ message: String) {
        log(message, category: .pipeline)
    }
    
    func success(_ message: String) {
        log(message, category: .success)
    }
    
    func warning(_ message: String) {
        log(message, category: .warning)
    }
    
    func error(_ message: String) {
        log(message, category: .error)
    }

    // MARK: - Verbose Level Convenience Methods

    func audioVerbose(_ message: String) {
        log(message, category: .audio, level: .verbose)
    }

    func visualVerbose(_ message: String) {
        log(message, category: .visual, level: .verbose)
    }

    func exportVerbose(_ message: String) {
        log(message, category: .export, level: .verbose)
    }

    func pipelineVerbose(_ message: String) {
        log(message, category: .pipeline, level: .verbose)
    }

    // MARK: - Debug Level Convenience Methods

    func audioDebug(_ message: String) {
        log(message, category: .audio, level: .debug)
    }

    func visualDebug(_ message: String) {
        log(message, category: .visual, level: .debug)
    }

    func exportDebug(_ message: String) {
        log(message, category: .export, level: .debug)
    }

    func pipelineDebug(_ message: String) {
        log(message, category: .pipeline, level: .debug)
    }
}

// MARK: - Async Logging Extension

/// Extension for logging from async contexts (actors)
extension ProcessingLogger {

    /// Log from an async context with verbosity level
    nonisolated func logAsync(_ message: String, category: ProcessingLogEntry.LogCategory = .info, level: VerbosityLevel = .normal) {
        Task { @MainActor in
            self.log(message, category: category, level: level)
        }
    }
    
    nonisolated func audioAsync(_ message: String) {
        logAsync(message, category: .audio)
    }
    
    nonisolated func visualAsync(_ message: String) {
        logAsync(message, category: .visual)
    }
    
    nonisolated func exportAsync(_ message: String) {
        logAsync(message, category: .export)
    }
    
    nonisolated func pipelineAsync(_ message: String) {
        logAsync(message, category: .pipeline)
    }
    
    nonisolated func successAsync(_ message: String) {
        logAsync(message, category: .success)
    }
    
    nonisolated func warningAsync(_ message: String) {
        logAsync(message, category: .warning)
    }
    
    nonisolated func errorAsync(_ message: String) {
        logAsync(message, category: .error)
    }

    // MARK: - Verbose Level Async Methods

    nonisolated func audioVerboseAsync(_ message: String) {
        logAsync(message, category: .audio, level: .verbose)
    }

    nonisolated func visualVerboseAsync(_ message: String) {
        logAsync(message, category: .visual, level: .verbose)
    }

    nonisolated func exportVerboseAsync(_ message: String) {
        logAsync(message, category: .export, level: .verbose)
    }

    nonisolated func pipelineVerboseAsync(_ message: String) {
        logAsync(message, category: .pipeline, level: .verbose)
    }

    // MARK: - Debug Level Async Methods

    nonisolated func audioDebugAsync(_ message: String) {
        logAsync(message, category: .audio, level: .debug)
    }

    nonisolated func visualDebugAsync(_ message: String) {
        logAsync(message, category: .visual, level: .debug)
    }

    nonisolated func exportDebugAsync(_ message: String) {
        logAsync(message, category: .export, level: .debug)
    }

    nonisolated func pipelineDebugAsync(_ message: String) {
        logAsync(message, category: .pipeline, level: .debug)
    }
}

