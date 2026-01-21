//
//  RunEndpoints.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation
import Swifter

/// Register run execution endpoints on the HTTP server
class RunEndpoints {

    static func register(on server: HTTPServer, store: RunStore, executor: RunExecutor) {

        // POST /runs - Create and enqueue a new run
        server.registerRoute(path: "/runs", method: "POST") { request in
            let semaphore = DispatchSemaphore(value: 0)
            var response: HttpResponse = .internalServerError

            Task {
                response = await handleCreateRun(request: request, store: store, executor: executor)
                semaphore.signal()
            }

            semaphore.wait()
            return response
        }

        // GET /runs - List all runs
        server.registerRoute(path: "/runs", method: "GET") { request in
            let semaphore = DispatchSemaphore(value: 0)
            var response: HttpResponse = .internalServerError

            Task {
                response = await handleListRuns(store: store)
                semaphore.signal()
            }

            semaphore.wait()
            return response
        }

        // GET /runs/:id - Get specific run details
        server.registerRoute(path: "/runs/:id", method: "GET") { request in
            let semaphore = DispatchSemaphore(value: 0)
            var response: HttpResponse = .internalServerError

            Task {
                response = await handleGetRun(request: request, store: store)
                semaphore.signal()
            }

            semaphore.wait()
            return response
        }

        print("📡 [RunEndpoints] Registered /runs endpoints")
    }

    // MARK: - POST /runs

    private static func handleCreateRun(
        request: HttpRequest,
        store: RunStore,
        executor: RunExecutor
    ) async -> HttpResponse {
        do {
            // Parse JSON body
            guard let bodyData = Data(bytes: request.body, count: request.body.count) as Data?,
                  let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                return errorResponse(message: "Invalid JSON body", statusCode: 400)
            }

            // Extract required fields
            guard let videoPath = json["videoPath"] as? String else {
                return errorResponse(message: "Missing required field: videoPath", statusCode: 400)
            }

            guard let method = json["method"] as? String else {
                return errorResponse(message: "Missing required field: method", statusCode: 400)
            }

            guard let sport = json["sport"] as? String else {
                return errorResponse(message: "Missing required field: sport", statusCode: 400)
            }

            // Validate video path exists
            guard FileManager.default.fileExists(atPath: videoPath) else {
                return errorResponse(message: "Video file not found: \(videoPath)", statusCode: 404)
            }

            // Extract optional fields
            let sportMode = json["sportMode"] as? String
            let config = json["config"] as? [String: String] ?? [:]

            // Create run
            let run = Run(
                videoPath: videoPath,
                method: method,
                sport: sport,
                sportMode: sportMode,
                config: config
            )

            // Enqueue for execution
            await executor.enqueue(run: run)

            // Return 202 Accepted with run ID
            let response: [String: Any] = [
                "id": run.id.uuidString,
                "status": run.status.rawValue
            ]

            return jsonResponse(data: response, statusCode: 202)

        } catch {
            return errorResponse(message: "Internal server error: \(error.localizedDescription)", statusCode: 500)
        }
    }

    // MARK: - GET /runs

    private static func handleListRuns(store: RunStore) async -> HttpResponse {
        let runs = await store.getAll()

        let runsJSON = runs.map { run in
            encodeRun(run)
        }

        let response: [String: Any] = [
            "runs": runsJSON
        ]

        return jsonResponse(data: response)
    }

    // MARK: - GET /runs/:id

    private static func handleGetRun(request: HttpRequest, store: RunStore) async -> HttpResponse {
        // Extract ID from path
        guard let idString = request.params[":id"],
              let id = UUID(uuidString: idString) else {
            return errorResponse(message: "Invalid run ID", statusCode: 400)
        }

        // Lookup run
        guard let run = await store.get(id: id) else {
            return errorResponse(message: "Run not found", statusCode: 404)
        }

        // Return full run details
        return jsonResponse(data: encodeRun(run))
    }

    // MARK: - Helpers

    private static func encodeRun(_ run: Run) -> [String: Any] {
        var json: [String: Any] = [
            "id": run.id.uuidString,
            "status": run.status.rawValue,
            "videoPath": run.videoPath,
            "method": run.method,
            "sport": run.sport,
            "config": run.config,
            "createdAt": ISO8601DateFormatter().string(from: run.createdAt)
        ]

        if let sportMode = run.sportMode {
            json["sportMode"] = sportMode
        }

        if let startedAt = run.startedAt {
            json["startedAt"] = ISO8601DateFormatter().string(from: startedAt)
        }

        if let completedAt = run.completedAt {
            json["completedAt"] = ISO8601DateFormatter().string(from: completedAt)
        }

        if let segments = run.segments {
            json["segments"] = segments.map { segment in
                [
                    "startTime": segment.startTime,
                    "endTime": segment.endTime,
                    "type": segment.type
                ]
            }
        }

        if let artifactPaths = run.artifactPaths {
            json["artifactPaths"] = [
                "segmentsJSON": artifactPaths.segmentsJSON,
                "highlightVideo": artifactPaths.highlightVideo as Any
            ]
        }

        if let error = run.error {
            json["error"] = error
        }

        return json
    }

    private static func jsonResponse(data: Any, statusCode: Int = 200) -> HttpResponse {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return .ok(.json(jsonString as AnyObject))
        } catch {
            return .internalServerError
        }
    }

    private static func errorResponse(message: String, statusCode: Int) -> HttpResponse {
        let json: [String: Any] = ["error": message]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"Unknown error\"}"

        switch statusCode {
        case 400:
            return .badRequest(.json(jsonString as AnyObject))
        case 404:
            return .notFound
        case 500:
            return .internalServerError
        default:
            return .internalServerError
        }
    }
}
