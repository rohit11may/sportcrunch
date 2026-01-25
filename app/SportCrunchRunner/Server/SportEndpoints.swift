//
//  SportEndpoints.swift
//  SportCrunchRunner
//
//  Sport and mode discovery HTTP endpoints.
//

import Foundation
import Swifter

/// Registers sport discovery HTTP endpoints
enum SportEndpoints {

    /// Register all sport endpoints on the server
    static func register(on server: HttpServer) {

        // GET /sports - List all available sports
        server.GET["/sports"] = { _ in
            let sports = Sport.allCases.map { sport in
                [
                    "id": sport.rawValue,
                    "displayName": sport.displayName,
                    "description": sport.description,
                    "modes": sport.availableModes.map { mode in
                        [
                            "id": mode.id,
                            "displayName": mode.displayName,
                            "description": mode.description
                        ]
                    }
                ] as [String: Any]
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: sports, options: [.prettyPrinted]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return .internalServerError(.text("{\"error\": \"Failed to encode sports\"}"))
            }

            return .ok(.text(jsonString))
        }

        // GET /sports/:sport - Get specific sport details
        server.GET["/sports/:sport"] = { request in
            guard let sportId = request.params[":sport"],
                  let sport = Sport(rawValue: sportId) else {
                return .badRequest(.text("{\"error\": \"Invalid sport\"}"))
            }

            let sportInfo: [String: Any] = [
                "id": sport.rawValue,
                "displayName": sport.displayName,
                "description": sport.description,
                "modes": sport.availableModes.map { mode in
                    [
                        "id": mode.id,
                        "displayName": mode.displayName,
                        "description": mode.description
                    ]
                }
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: sportInfo, options: [.prettyPrinted]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return .internalServerError(.text("{\"error\": \"Failed to encode sport\"}"))
            }

            return .ok(.text(jsonString))
        }

        print("✓ [SportEndpoints] Registered /sports endpoints")
    }
}
