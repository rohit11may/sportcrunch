//
//  DeviceManager.swift
//  SportCrunchRunner
//
//  Created by Claude Code on 21/01/2026.
//

import Foundation

#if os(macOS)
  /// Manages connected iOS devices and file operations (macOS only)
  /// This manager uses the devicectl command-line tool which requires macOS
  actor DeviceManager {

    private let bundleID = "sportcrunch.SportCrunchRunner"
    private let domainType = "appDataContainer"

    // MARK: - File Operations

    /// Copy a video file to a device
    func copyVideoToDevice(
      deviceID: String,
      sourcePath: String,
      destinationPath: String
    ) async throws {
      // Check if file already exists on device
      let exists = try await fileExistsOnDevice(
        deviceID: deviceID,
        path: destinationPath
      )

      if exists {
        print("📱 [DeviceManager] File already exists on device: \(destinationPath)")
        return
      }

      print("📱 [DeviceManager] Copying \(sourcePath) to device \(deviceID)")

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
      process.arguments = [
        "devicectl", "device", "copy", "to",
        "--device", deviceID,
        "--domain-type", domainType,
        "--domain-identifier", bundleID,
        "--source", sourcePath,
        "--destination", destinationPath
      ]

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe

      try process.run()
      process.waitUntilExit()

      guard process.terminationStatus == 0 else {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw DeviceManagerError.copyFailed(output)
      }

      print("📱 [DeviceManager] ✓ Successfully copied file to device")
    }

    /// Check if a file exists on device
    private func fileExistsOnDevice(
      deviceID: String,
      path: String
    ) async throws -> Bool {
      // Try to list the specific file
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")

      // Get the directory path
      let directoryPath = (path as NSString).deletingLastPathComponent

      process.arguments = [
        "devicectl", "device", "copy", "from",
        "--device", deviceID,
        "--domain-type", domainType,
        "--domain-identifier", bundleID,
        "--source", path,
        "--destination", "/dev/null"
      ]

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe

      try process.run()
      process.waitUntilExit()

      // If exit code is 0, file exists
      return process.terminationStatus == 0
    }

    /// Pull artifacts from device to local directory
    func pullArtifactsFromDevice(
      deviceID: String,
      runID: UUID,
      localExportDir: String
    ) async throws {
      print("📱 [DeviceManager] Pulling artifacts for run \(runID.uuidString)")

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")

      let sourceDir = "Documents/SportCrunchRunner/Runs/\(runID.uuidString)"
      let destDir = "\(localExportDir)/\(runID.uuidString)"

      process.arguments = [
        "devicectl", "device", "copy", "from",
        "--device", deviceID,
        "--domain-type", domainType,
        "--domain-identifier", bundleID,
        "--source", sourceDir,
        "--destination", destDir
      ]

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe

      try process.run()
      process.waitUntilExit()

      guard process.terminationStatus == 0 else {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw DeviceManagerError.pullFailed(output)
      }

      print("📱 [DeviceManager] ✓ Successfully pulled artifacts to \(destDir)")
    }
  }

#endif
