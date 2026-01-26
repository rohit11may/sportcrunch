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
    }

    /// Registers the health check endpoint on the HTTP server
    static func register(on server: HTTPServer) {
        server.registerRoute(path: "/health", method: "GET") { _ in
            return handleHealthCheck()
        }
    }

    private static func handleHealthCheck() -> HttpResponse {
        let response = HealthResponse()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(response)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            var headers = HTTPServer.corsHeaders
            headers["Content-Type"] = "application/json"

            return .raw(200, "OK", headers) {
                try? $0.write(Data(jsonString.utf8))
            }
        } catch {
            var headers = HTTPServer.corsHeaders
            headers["Content-Type"] = "application/json"
            return .raw(500, "Internal Server Error", headers) {
                try? $0.write(Data("{\"error\":\"Internal server error\"}".utf8))
            }
        }
    }
}
