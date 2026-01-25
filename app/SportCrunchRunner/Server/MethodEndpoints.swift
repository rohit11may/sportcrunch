//
//  MethodEndpoints.swift
//  SportCrunchRunner
//
//  Method discovery HTTP endpoints that scan filesystem for available methods.
//

import Foundation
import Swifter

/// Registers method discovery HTTP endpoints
enum MethodEndpoints {

    /// Register all method endpoints on the server
    static func register(on server: HTTPServer) {

        // GET /methods - List all available methods by scanning filesystem
        server.registerRoute(path: "/methods", method: "GET") { _ in
            return handleListMethods()
        }

        print("✓ [MethodEndpoints] Registered /methods endpoints")
    }

    // MARK: - GET /methods

    private static func handleListMethods() -> HttpResponse {
        let methodsPath = getMethodsDirectoryPath()

        guard FileManager.default.fileExists(atPath: methodsPath) else {
            return errorResponse(message: "Methods directory not found", statusCode: 500)
        }

        do {
            let methodFamilies = try discoverMethods(at: methodsPath)

            guard let jsonData = try? JSONSerialization.data(withJSONObject: methodFamilies, options: [.prettyPrinted]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return errorResponse(message: "Failed to encode methods", statusCode: 500)
            }

            return .raw(200, "OK", ["Content-Type": "application/json"]) {
                try? $0.write(Data(jsonString.utf8))
            }
        } catch {
            print("❌ [MethodEndpoints] Error discovering methods: \(error)")
            return errorResponse(message: "Failed to discover methods: \(error.localizedDescription)", statusCode: 500)
        }
    }

    // MARK: - Method Discovery

    /// Returns the absolute path to the methods directory
    private static func getMethodsDirectoryPath() -> String {
        // Methods directory is bundled as a resource in the app
        guard let resourcePath = Bundle.main.resourcePath else {
            return ""
        }
        return "\(resourcePath)/methods"
    }

    /// Scans the methods directory and returns structured method information
    private static func discoverMethods(at methodsPath: String) throws -> [[String: Any]] {
        let fileManager = FileManager.default
        let methodDirs = try fileManager.contentsOfDirectory(atPath: methodsPath)

        var methods: [[String: Any]] = []

        for methodDir in methodDirs {
            let methodPath = "\(methodsPath)/\(methodDir)"

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: methodPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Skip hidden directories
            guard !methodDir.hasPrefix(".") else { continue }

            // Discover configs for this method
            let configs = try discoverConfigs(methodFamily: methodDir, methodPath: methodPath)

            // Build method info
            let methodInfo: [String: Any] = [
                "family": methodDir,
                "version": "v1",  // Hardcoded for now
                "displayName": formatDisplayName(methodDir),
                "description": generateDescription(methodDir),
                "configs": configs
            ]

            methods.append(methodInfo)
        }

        return methods
    }

    /// Discovers config files for a method family
    private static func discoverConfigs(methodFamily: String, methodPath: String) throws -> [[String: Any]] {
        let fileManager = FileManager.default
        let configsPath = "\(methodPath)/configs"

        guard fileManager.fileExists(atPath: configsPath) else {
            print("⚠️ [MethodEndpoints] No configs directory for \(methodFamily)")
            return []
        }

        let configFiles = try fileManager.contentsOfDirectory(atPath: configsPath)
        var configs: [[String: Any]] = []

        for configFile in configFiles {
            // Skip non-Swift files
            guard configFile.hasSuffix(".swift") else { continue }

            // Extract config name (e.g., "SpectralFluxTennisRally.swift" -> "TennisRally")
            let configName = extractConfigName(from: configFile, methodFamily: methodFamily)

            let configInfo: [String: Any] = [
                "name": configName,
                "displayName": formatDisplayName(configName),
                "description": generateConfigDescription(configName)
            ]

            configs.append(configInfo)
        }

        return configs
    }

    // MARK: - Helpers

    /// Extracts config name from filename
    /// Example: "SpectralFluxTennisRally.swift" -> "TennisRally"
    private static func extractConfigName(from filename: String, methodFamily: String) -> String {
        // Remove .swift extension
        let nameWithoutExtension = filename.replacingOccurrences(of: ".swift", with: "")

        // Remove method family prefix (e.g., "SpectralFlux")
        let prefix = methodFamily
            .split(separator: "_")
            .map { $0.capitalized }
            .joined()

        if nameWithoutExtension.hasPrefix(prefix) {
            let startIndex = nameWithoutExtension.index(nameWithoutExtension.startIndex, offsetBy: prefix.count)
            return String(nameWithoutExtension[startIndex...])
        }

        return nameWithoutExtension
    }

    /// Formats identifier to display name
    /// Example: "spectral_flux" -> "Spectral Flux"
    private static func formatDisplayName(_ identifier: String) -> String {
        return identifier
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Generates a description for a method family
    private static func generateDescription(_ methodFamily: String) -> String {
        switch methodFamily.lowercased() {
        case "spectral_flux":
            return "Audio-based detection using spectral flux analysis"
        default:
            return "Segmentation method"
        }
    }

    /// Generates a description for a config
    private static func generateConfigDescription(_ configName: String) -> String {
        let lower = configName.lowercased()

        if lower.contains("rally") {
            return "Groups consecutive shots into rallies"
        } else if lower.contains("individual") || lower.contains("shot") {
            return "Captures each shot separately"
        } else if lower.contains("tennis") {
            return "Tennis detection mode"
        } else if lower.contains("cricket") {
            return "Cricket detection mode"
        }

        return "Detection configuration"
    }

    private static func errorResponse(message: String, statusCode: Int) -> HttpResponse {
        let json: [String: Any] = ["error": message]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"Unknown error\"}"

        return .raw(statusCode, "Error", ["Content-Type": "application/json"]) {
            try? $0.write(Data(jsonString.utf8))
        }
    }
}
