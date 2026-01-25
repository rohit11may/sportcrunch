//
//  TestResourceLoader.swift
//  SportCrunchTests
//
//  Created by SportCrunch on 2026-01-11.
//

import Foundation

/// Utility for loading test resources from the test bundle
///
/// This class provides methods to load test videos and ground truth data
/// from the TestResources directory in the test bundle.
class TestResourceLoader {

    // MARK: - Error Types

    enum LoadError: Error, LocalizedError {
        case videoNotFound(String)
        case groundTruthNotFound(String)
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .videoNotFound(let name):
                return """
                Test video '\(name)' not found in TestResources/Videos/

                Please ensure the video file is added to the test bundle.
                See TEST_RESOURCES.md for instructions on adding test resources.
                """
            case .groundTruthNotFound(let name):
                return """
                Ground truth file '\(name)' not found in TestResources/GroundTruth/

                Please ensure the JSON file is added to the test bundle.
                See TEST_RESOURCES.md for ground truth format and instructions.
                """
            case .invalidJSON(let name):
                return """
                Invalid JSON in ground truth file '\(name)'

                Please verify the JSON format matches the schema in TEST_RESOURCES.md
                """
            }
        }
    }

    // MARK: - Video Loading

    /// Load a test video from the test bundle
    ///
    /// Videos should be located in TestResources/Videos/ directory within the test bundle.
    ///
    /// - Parameter name: The video filename (e.g., "rally-tennis-01.mp4")
    /// - Returns: URL to the video file
    /// - Throws: `LoadError.videoNotFound` if the video cannot be found
    static func loadTestVideo(named name: String) throws -> URL {
        let bundle = Bundle(for: Self.self)

        // Look for video in TestResources/Videos/ subdirectory
        guard let url = bundle.url(
            forResource: name.replacingOccurrences(of: ".mp4", with: ""),
            withExtension: "mp4",
            subdirectory: "TestResources/Videos"
        ) else {
            throw LoadError.videoNotFound(name)
        }

        return url
    }

    // MARK: - Ground Truth Loading

    /// Load and parse ground truth data from the test bundle
    ///
    /// Ground truth files should be located in TestResources/GroundTruth/ directory
    /// and follow the JSON format specified in TEST_RESOURCES.md.
    ///
    /// - Parameter name: The ground truth filename (e.g., "rally-tennis-01.json")
    /// - Returns: Parsed GroundTruth object
    /// - Throws: `LoadError.groundTruthNotFound` if file not found, or `LoadError.invalidJSON` if parsing fails
    static func loadGroundTruth(named name: String) throws -> GroundTruth {
        let bundle = Bundle(for: Self.self)

        // Look for JSON in TestResources/GroundTruth/ subdirectory
        guard let url = bundle.url(
            forResource: name.replacingOccurrences(of: ".json", with: ""),
            withExtension: "json",
            subdirectory: "TestResources/GroundTruth"
        ) else {
            throw LoadError.groundTruthNotFound(name)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(GroundTruth.self, from: data)
        } catch {
            throw LoadError.invalidJSON(name)
        }
    }

    // MARK: - Directory Access

    /// Get the URL to the GroundTruth directory
    ///
    /// This can be used to discover all available ground truth files.
    ///
    /// - Returns: URL to the GroundTruth directory
    /// - Throws: `LoadError.groundTruthNotFound` if directory cannot be found
    static func groundTruthDirectory() throws -> URL {
        let bundle = Bundle(for: Self.self)
        guard let resourceURL = bundle.resourceURL else {
            throw LoadError.groundTruthNotFound("TestResources/GroundTruth")
        }

        let groundTruthURL = resourceURL
            .appendingPathComponent("TestResources", isDirectory: true)
            .appendingPathComponent("GroundTruth", isDirectory: true)

        guard FileManager.default.fileExists(atPath: groundTruthURL.path) else {
            throw LoadError.groundTruthNotFound("TestResources/GroundTruth")
        }

        return groundTruthURL
    }

}
