//
//  MethodEndpoints.swift
//  SportCrunchRunner
//
//  HTTP endpoints for method registry queries.
//

import Foundation
import Swifter

/// Registers method registry HTTP endpoints
enum MethodEndpoints {

    /// Register all method endpoints on the server
    static func register(on server: HttpServer, registry: MethodRegistry) {

        // GET /methods - List all available methods
        server.GET["/methods"] = { _ in
            let semaphore = DispatchSemaphore(value: 0)
            var responseJSON: String = "[]"

            Task {
                let methods = await registry.allMethods()

                // Convert to JSON
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(methods)
                    responseJSON = String(data: data, encoding: .utf8) ?? "[]"
                } catch {
                    print("❌ [MethodEndpoints] Failed to encode methods: \(error)")
                    responseJSON = "[]"
                }

                semaphore.signal()
            }

            semaphore.wait()

            return .ok(.text(responseJSON, contentType: "application/json"))
        }

        // GET /methods/:family/:version - Get specific method details
        server.GET["/methods/:family/:version"] = { request in
            guard let family = request.params[":family"],
                  let version = request.params[":version"] else {
                return .badRequest(.text("{\"error\": \"Missing family or version\"}"))
            }

            let semaphore = DispatchSemaphore(value: 0)
            var response: HttpResponse = .notFound

            Task {
                if let method = await registry.method(family: family, version: version) {
                    do {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        let data = try encoder.encode(method)
                        let json = String(data: data, encoding: .utf8) ?? "{}"
                        response = .ok(.text(json, contentType: "application/json"))
                    } catch {
                        response = .internalServerError(.text("{\"error\": \"Encoding failed\"}"))
                    }
                } else {
                    response = .notFound(.text("{\"error\": \"Method not found: \(family)/\(version)\"}"))
                }

                semaphore.signal()
            }

            semaphore.wait()
            return response
        }

        print("✓ [MethodEndpoints] Registered /methods endpoints")
    }
}
