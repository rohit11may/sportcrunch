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
    static func register(on server: HTTPServer) {

        // GET /sports - List all available sports
        server.registerRoute(path: "/sports", method: "GET") { _ in
            return handleListSports()
        }

        // GET /sports/:sport - Get specific sport details
        server.registerRoute(path: "/sports/:sport", method: "GET") { request in
            return handleGetSport(request: request)
        }

        print("✓ [SportEndpoints] Registered /sports endpoints")
    }

    // MARK: - GET /sports

    private static func handleListSports() -> HttpResponse {
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
            return .raw(500, "Internal Server Error", ["Content-Type": "application/json"]) {
                try? $0.write(Data("{\"error\": \"Failed to encode sports\"}".utf8))
            }
        }

        return .raw(200, "OK", ["Content-Type": "application/json"]) {
            try? $0.write(Data(jsonString.utf8))
        }
    }

    // MARK: - GET /sports/:sport

    private static func handleGetSport(request: HttpRequest) -> HttpResponse {
        guard let sportId = request.params[":sport"],
              let sport = Sport(rawValue: sportId) else {
            return .raw(400, "Bad Request", ["Content-Type": "application/json"]) {
                try? $0.write(Data("{\"error\": \"Invalid sport\"}".utf8))
            }
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
            return .raw(500, "Internal Server Error", ["Content-Type": "application/json"]) {
                try? $0.write(Data("{\"error\": \"Failed to encode sport\"}".utf8))
            }
        }

        return .raw(200, "OK", ["Content-Type": "application/json"]) {
            try? $0.write(Data(jsonString.utf8))
        }
    }
}
