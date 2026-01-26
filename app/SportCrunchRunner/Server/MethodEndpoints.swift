//
//  MethodEndpoints.swift
//  SportCrunchRunner
//
//  Method discovery HTTP endpoints that scan filesystem for available methods.
//

import Foundation
import Swifter

/// Hardcoded method configuration
struct MethodConfig {
    let name: String
    let displayName: String
    let description: String
}

/// Hardcoded methods
enum Method: String, CaseIterable {
    case spectralFlux = "spectral_flux"

    var displayName: String {
        switch self {
        case .spectralFlux:
            return "Spectral Flux"
        }
    }

    var description: String {
        switch self {
        case .spectralFlux:
            return "Audio-based detection using spectral flux analysis"
        }
    }

    var configs: [MethodConfig] {
        switch self {
        case .spectralFlux:
            return [
                MethodConfig(
                    name: "TennisRally",
                    displayName: "Tennis Rally",
                    description: "Groups consecutive shots into rallies"
                ),
                MethodConfig(
                    name: "TennisIndividual",
                    displayName: "Tennis Individual",
                    description: "Captures each shot separately"
                )
            ]
        }
    }
}

/// Registers method discovery HTTP endpoints
enum MethodEndpoints {

    /// Register all method endpoints on the server
    static func register(on server: HTTPServer) {

        // GET /methods - List all available methods (hardcoded)
        server.registerRoute(path: "/methods", method: "GET") { _ in
            return handleListMethods()
        }

        print("✓ [MethodEndpoints] Registered /methods endpoints")
    }

    // MARK: - GET /methods

    private static func handleListMethods() -> HttpResponse {
        let methodFamilies = getAllMethods()

        guard let jsonData = try? JSONSerialization.data(withJSONObject: methodFamilies, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return errorResponse(message: "Failed to encode methods", statusCode: 500)
        }

        var headers = HTTPServer.corsHeaders
        headers["Content-Type"] = "application/json"

        return .raw(200, "OK", headers) {
            try? $0.write(Data(jsonString.utf8))
        }
    }

    // MARK: - Hardcoded Method Discovery

    /// Returns all available methods (hardcoded)
    private static func getAllMethods() -> [[String: Any]] {
        return Method.allCases.map { method in
            [
                "method": method.rawValue,
                "displayName": method.displayName,
                "description": method.description,
                "configs": method.configs.map { config in
                    [
                        "name": config.name,
                        "displayName": config.displayName,
                        "description": config.description
                    ]
                }
            ]
        }
    }

    private static func errorResponse(message: String, statusCode: Int) -> HttpResponse {
        let json: [String: Any] = ["error": message]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"Unknown error\"}"

        var headers = HTTPServer.corsHeaders
        headers["Content-Type"] = "application/json"

        return .raw(statusCode, "Error", headers) {
            try? $0.write(Data(jsonString.utf8))
        }
    }
}
