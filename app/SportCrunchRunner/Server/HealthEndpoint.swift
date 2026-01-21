//
//  HealthEndpoint.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation
import Swifter

/// Health check endpoint for SportCrunchRunner
struct HealthEndpoint {

    /// Response structure for health check
    struct HealthResponse: Codable {
        let status: String
        let timestamp: String
    }

    /// Registers the health check endpoint on the HTTP server
    static func register(on server: HTTPServer) {
        server.registerRoute(path: "/health", method: "GET") { request in
            return handleHealthCheck(request)
        }
    }

    private static func handleHealthCheck(_ request: HttpRequest) -> HttpResponse {
        let response = HealthResponse(
            status: "ready",
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(response)

            return .ok(.data(jsonData, contentType: "application/json"))
        } catch {
            return .internalServerError
        }
    }
}
