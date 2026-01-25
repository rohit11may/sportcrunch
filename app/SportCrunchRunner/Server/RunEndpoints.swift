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

      Task.detached {
        response = await handleCreateRun(request: request, store: store, executor: executor)
        semaphore.signal()
      }

      semaphore.wait()
      return response
    }

    // GET /runs - List all runs
    server.registerRoute(path: "/runs", method: "GET") { _ in
      let semaphore = DispatchSemaphore(value: 0)
      var response: HttpResponse = .internalServerError

      Task.detached {
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

      Task.detached {
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
    print("📥 [RunEndpoints] POST /runs - Received request")

    do {
      // Parse JSON body
      guard let bodyData = Data(bytes: request.body, count: request.body.count) as Data?,
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
      else {
        print("❌ [RunEndpoints] Invalid JSON body")
        return errorResponse(message: "Invalid JSON body", statusCode: 400)
      }

      print("✅ [RunEndpoints] Parsed request body: \(json)")

      // Extract required fields
      guard let videoPath = json["videoPath"] as? String else {
        print("❌ [RunEndpoints] Missing videoPath")
        return errorResponse(message: "Missing required field: videoPath", statusCode: 400)
      }

      guard let sport = json["sport"] as? String else {
        print("❌ [RunEndpoints] Missing sport")
        return errorResponse(message: "Missing required field: sport", statusCode: 400)
      }

      print("📝 [RunEndpoints] videoPath=\(videoPath), sport=\(sport)")

      // Resolve relative paths (e.g., Documents/test-videos/...) to absolute paths
      let resolvedVideoPath = resolveVideoPath(videoPath)
      print("📝 [RunEndpoints] resolvedVideoPath=\(resolvedVideoPath)")

      // Validate video path exists
      guard FileManager.default.fileExists(atPath: resolvedVideoPath) else {
        print("❌ [RunEndpoints] Video file not found: \(resolvedVideoPath)")
        return errorResponse(message: "Video file not found: \(resolvedVideoPath)", statusCode: 404)
      }

      // Extract optional fields
      let sportMode = json["sportMode"] as? String
      let config = json["config"] as? [String: String] ?? [:]

      print("📝 [RunEndpoints] sportMode=\(sportMode ?? "nil"), config=\(config)")

      // Parse device target (defaults to simulator)
      let deviceTarget = parseDeviceTarget(from: json)

      // Create run (use resolved path so executor can find the file)
      let run = Run(
        videoPath: resolvedVideoPath,
        sport: sport,
        sportMode: sportMode,
        config: config,
        deviceTarget: deviceTarget
      )

      print("✅ [RunEndpoints] Created run: \(run.id.uuidString)")

      // Enqueue for execution
      await executor.enqueue(run: run)

      print("✅ [RunEndpoints] Enqueued run for execution")

      // Return 202 Accepted with run ID
      let response: [String: Any] = [
        "id": run.id.uuidString,
        "status": run.status.rawValue
      ]

      print("📤 [RunEndpoints] Returning 202 response: \(response)")
      return jsonResponse(data: response, statusCode: 202)

    } catch {
      print("❌ [RunEndpoints] Exception: \(error)")
      return errorResponse(
        message: "Internal server error: \(error.localizedDescription)", statusCode: 500)
    }
  }

  // MARK: - GET /runs

  private static func handleListRuns(store: RunStore) async -> HttpResponse {
    print("📥 [RunEndpoints] GET /runs - Listing all runs")
    let runs = await store.getAll()
    print("📊 [RunEndpoints] Found \(runs.count) runs")

    let runsJSON = runs.map { run in
      encodeRun(run)
    }

    let response: [String: Any] = [
      "runs": runsJSON
    ]

    print("📤 [RunEndpoints] Returning list of \(runsJSON.count) runs")
    return jsonResponse(data: response)
  }

  // MARK: - GET /runs/:id

  private static func handleGetRun(request: HttpRequest, store: RunStore) async -> HttpResponse {
    print("📥 [RunEndpoints] GET /runs/:id - Received request")
    print("   Available params: \(request.params)")

    // Extract ID from path (Swifter includes the colon in the key for path patterns like "/runs/:id")
    guard let idString = request.params[":id"],
      let id = UUID(uuidString: idString)
    else {
      print("❌ [RunEndpoints] Invalid run ID format")
      print("   Params received (request.params): \(request.params)")
      return errorResponse(message: "Invalid run ID", statusCode: 400)
    }

    print("🔍 [RunEndpoints] Looking up run: \(id.uuidString)")

    // Lookup run
    guard let run = await store.get(id: id) else {
      print("❌ [RunEndpoints] Run not found: \(id.uuidString)")
      return errorResponse(message: "Run not found", statusCode: 404)
    }

    print("✅ [RunEndpoints] Found run: \(id.uuidString), status: \(run.status.rawValue)")
    print("📝 [RunEndpoints] Encoding run details...")

    // Return full run details
    return jsonResponse(data: encodeRun(run))
  }

  // MARK: - Helpers

  private static func encodeRun(_ run: Run) -> [String: Any] {
    print("🔧 [RunEndpoints] Encoding run: \(run.id.uuidString)")

    var json: [String: Any] = [
      "id": run.id.uuidString,
      "status": run.status.rawValue,
      "videoPath": run.videoPath,
      "sport": run.sport,
      "config": run.config,
      "createdAt": ISO8601DateFormatter().string(from: run.createdAt)
    ]

    print("  ✓ Added base fields (id, status, videoPath, sport, config, createdAt)")

    if let sportMode = run.sportMode {
      json["sportMode"] = sportMode
      print("  ✓ Added sportMode: \(sportMode)")
    }

    if let startedAt = run.startedAt {
      json["startedAt"] = ISO8601DateFormatter().string(from: startedAt)
      print("  ✓ Added startedAt: \(ISO8601DateFormatter().string(from: startedAt))")
    }

    if let completedAt = run.completedAt {
      json["completedAt"] = ISO8601DateFormatter().string(from: completedAt)
      print("  ✓ Added completedAt: \(ISO8601DateFormatter().string(from: completedAt))")
    }

    if let segments = run.segments {
      print("  🔄 Encoding \(segments.count) segments...")
      let segmentsArray = segments.map { segment in
        [
          "startTime": segment.startTime,
          "endTime": segment.endTime,
          "type": segment.type
        ] as [String: Any]
      }
      json["segments"] = segmentsArray
      print("  ✓ Added segments: \(segments.count) items")
    }

    if let artifactPaths = run.artifactPaths {
      print("  🔄 Encoding artifactPaths...")
      var artifacts: [String: Any] = [
        "segmentsJSON": artifactPaths.segmentsJSON
      ]
      print("    - segmentsJSON: \(artifactPaths.segmentsJSON)")

      if let highlightVideo = artifactPaths.highlightVideo {
        artifacts["highlightVideo"] = highlightVideo
        print("    - highlightVideo: \(highlightVideo)")
      } else {
        print("    - highlightVideo: nil (not added)")
      }

      json["artifactPaths"] = artifacts
      print("  ✓ Added artifactPaths")
    }

    if let error = run.error {
      json["error"] = error
      print("  ✓ Added error: \(error)")
    }

    print("🔧 [RunEndpoints] Finished encoding run, total keys: \(json.keys.count)")
    return json
  }

  private static func jsonResponse(data: Any, statusCode: Int = 200) -> HttpResponse {
    print("🔄 [RunEndpoints] Creating JSON response (status: \(statusCode))")

    // Validate that the data is JSON-serializable
    guard JSONSerialization.isValidJSONObject(data) else {
      print("❌ [RunEndpoints] Data is NOT valid JSON object!")
      print("   Type: \(type(of: data))")
      print("   Data: \(data)")

      return .raw(500, "Internal Server Error", ["Content-Type": "application/json"]) {
        try? $0.write(
          Data("{\"error\":\"Serialisation error: invalidObject\"}".utf8))
      }
    }

    print("✅ [RunEndpoints] Data is valid JSON object")

    do {
      // Remove .sortedKeys option as it can cause issues with nested dictionaries
      let jsonData = try JSONSerialization.data(
        withJSONObject: data, options: [.prettyPrinted])
      let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

      print("✅ [RunEndpoints] Successfully serialized to JSON (\(jsonData.count) bytes)")

      return .raw(
        statusCode, statusCode == 200 ? "OK" : (statusCode == 201 ? "Created" : "Accepted"),
        ["Content-Type": "application/json"]
      ) {
        try? $0.write(Data(jsonString.utf8))
      }
    } catch {
      print("❌ [RunEndpoints] Serialisation error: \(error)")
      print("   Error type: \(type(of: error))")
      print("   LocalizedDescription: \(error.localizedDescription)")
      print("   Data attempted: \(data)")

      return .raw(500, "Internal Server Error", ["Content-Type": "application/json"]) {
        try? $0.write(
          Data("{\"error\":\"Serialisation error: \(error.localizedDescription)\"}".utf8))
      }
    }
  }

  private static func parseDeviceTarget(from json: [String: Any]) -> DeviceTarget {
    // Parse device target from JSON (defaults to simulator)
    if let targetString = json["deviceTarget"] as? String,
      let target = DeviceTarget(rawValue: targetString) {
      return target
    }
    return .simulator
  }

  /// Resolve video path - converts relative paths like Documents/... to absolute paths
  private static func resolveVideoPath(_ path: String) -> String {
    // If already absolute, return as-is
    if path.hasPrefix("/") {
      return path
    }

    // Check if it's a relative path starting with Documents/
    if path.hasPrefix("Documents/") {
      // Get the app's Documents directory
      if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first {
        // Remove "Documents/" prefix and append to actual Documents path
        let relativePath = String(path.dropFirst("Documents/".count))
        let fullPath = documentsURL.appendingPathComponent(relativePath).path
        print("📁 [RunEndpoints] Resolved path: \(path) -> \(fullPath)")
        return fullPath
      }
    }

    // For other relative paths, try to resolve from home directory
    let homeDirectory = NSHomeDirectory()
    return "\(homeDirectory)/\(path)"
  }

  private static func errorResponse(message: String, statusCode: Int) -> HttpResponse {
    let json: [String: Any] = ["error": message]
    let jsonData = try? JSONSerialization.data(withJSONObject: json)
    let jsonString =
      jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"Unknown error\"}"

    switch statusCode {
    case 400:
      return .badRequest(.json(jsonString as AnyObject))
    case 404:
      return .raw(404, "Not Found", ["Content-Type": "application/json"]) {
        try? $0.write(Data(jsonString.utf8))
      }
    case 500:
      return .raw(500, "Internal Server Error", ["Content-Type": "application/json"]) {
        try? $0.write(Data(jsonString.utf8))
      }
    default:
      return .raw(statusCode, "Error", ["Content-Type": "application/json"]) {
        try? $0.write(Data(jsonString.utf8))
      }
    }
  }
}
