//
//  ProcessingLogger.swift
//  SportCrunch
//
//  Provides observable logging for the processing pipeline.
//  Log messages are surfaced in the UI during video processing.
//

import Foundation
import Combine

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
    
    // MARK: - Shared Instance
    
    /// Shared instance for global access from actors
    static let shared = ProcessingLogger()
    
    private init() {}
    
    // MARK: - Logging Methods
    
    /// Log a message with a category
    func log(_ message: String, category: ProcessingLogEntry.LogCategory = .info) {
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
}

// MARK: - Async Logging Extension

/// Extension for logging from async contexts (actors)
extension ProcessingLogger {
    
    /// Log from an async context
    nonisolated func logAsync(_ message: String, category: ProcessingLogEntry.LogCategory = .info) {
        Task { @MainActor in
            self.log(message, category: category)
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
}

