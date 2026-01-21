//
//  HTTPServer.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation
import Combine
import Swifter

/// HTTP server wrapper around Swifter for the SportCrunchRunner
@MainActor
class HTTPServer: ObservableObject {

    // MARK: - Server State

    enum ServerState: Equatable {
        case stopped
        case starting
        case running(port: UInt16, ipAddress: String)
        case error(String)
    }

    @Published private(set) var state: ServerState = .stopped

    // MARK: - Properties

    private let server = HttpServer()
    private let defaultPort: UInt16

    // MARK: - Initialization

    init(port: UInt16 = 8080) {
        // Allow port override from UserDefaults or environment
        if let envPort = ProcessInfo.processInfo.environment["RUNNER_PORT"],
           let parsedPort = UInt16(envPort) {
            self.defaultPort = parsedPort
        } else if let savedPort = UserDefaults.standard.object(forKey: "runner_port") as? Int {
            self.defaultPort = UInt16(savedPort)
        } else {
            self.defaultPort = port
        }
    }

    // MARK: - Server Control

    func start() {
        guard state == .stopped || state != .running(port: defaultPort, ipAddress: "") else {
            print("⚠️ Server already running")
            return
        }

        state = .starting

        do {
            try server.start(defaultPort, forceIPv4: true)

            // Get device IP address
            let ipAddress = getDeviceIPAddress() ?? "localhost"
            state = .running(port: defaultPort, ipAddress: ipAddress)

            print("✅ HTTPServer started")
            print("   URL: http://\(ipAddress):\(defaultPort)")
            print("   Listening on port \(defaultPort)")

        } catch {
            let errorMessage = "Failed to start server: \(error.localizedDescription)"
            state = .error(errorMessage)
            print("❌ \(errorMessage)")
        }
    }

    func stop() {
        server.stop()
        state = .stopped
        print("🛑 HTTPServer stopped")
    }

    // MARK: - Route Registration

    func registerRoute(path: String, method: String = "GET", handler: @escaping (HttpRequest) -> HttpResponse) {
        switch method.uppercased() {
        case "GET":
            server.GET[path] = handler
        case "POST":
            server.POST[path] = handler
        case "PUT":
            server.PUT[path] = handler
        case "DELETE":
            server.DELETE[path] = handler
        default:
            print("⚠️ Unsupported HTTP method: \(method)")
        }
    }

    // MARK: - Network Utilities

    private func getDeviceIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Prioritize en0 (WiFi) or en1 (Ethernet)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                              socklen_t(interface.ifa_addr.pointee.sa_len),
                              &hostname,
                              socklen_t(hostname.count),
                              nil,
                              socklen_t(0),
                              NI_NUMERICHOST)
                    address = String(cString: hostname)

                    if name == "en0" {
                        break // Prefer WiFi
                    }
                }
            }
        }

        return address
    }
}
