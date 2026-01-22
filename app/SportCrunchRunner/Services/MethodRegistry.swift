//
//  MethodRegistry.swift
//  SportCrunchRunner
//
//  Loads method definitions from bundle and provides lookup.
//

import Foundation

// MARK: - Data Models

/// Information about a method configuration
struct ConfigInfo: Codable, Sendable {
    let name: String
    let description: String
    let parameters: [String: AnyCodable]  // Loosely typed per CONTEXT.md
}

/// Information about a method version
struct VersionInfo: Codable, Sendable {
    let version: String
    let name: String
    let description: String
    let swiftClass: String
    let defaultConfig: String
    let configs: [String]
}

/// Information about a method family
struct FamilyInfo: Codable, Sendable {
    let family: String
    let description: String
    let versions: [VersionInfo]
}

/// Root index structure
struct MethodIndex: Codable, Sendable {
    let generated: String
    let families: [FamilyInfo]
}

/// Flattened method info for API responses
struct MethodInfo: Codable, Sendable {
    let family: String
    let version: String
    let name: String
    let description: String
    let swiftClass: String
    let defaultConfig: String
    let configs: [String]

    /// Unique identifier: family/version
    var id: String { "\(family)/\(version)" }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable for loosely-typed config parameters
struct AnyCodable: Codable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}

// MARK: - Method Registry

/// Registry of available detection methods loaded from bundle.
///
/// Loads _index.json from the app bundle at startup and provides:
/// - List of all available methods for API
/// - Method instantiation by family/version identifier
actor MethodRegistry {

    // MARK: - Properties

    private var index: MethodIndex?
    private var methods: [String: MethodInfo] = [:]  // key: family/version
    private var isLoaded = false

    // MARK: - Loading

    /// Load method registry from bundle
    func loadFromBundle() {
        guard !isLoaded else { return }

        guard let indexURL = Bundle.main.url(forResource: "_index", withExtension: "json", subdirectory: "methods") else {
            print("⚠️ [MethodRegistry] _index.json not found in bundle - no methods available")
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            index = try decoder.decode(MethodIndex.self, from: data)

            // Flatten into methods dictionary
            for family in index?.families ?? [] {
                for version in family.versions {
                    let info = MethodInfo(
                        family: family.family,
                        version: version.version,
                        name: version.name,
                        description: version.description,
                        swiftClass: version.swiftClass,
                        defaultConfig: version.defaultConfig,
                        configs: version.configs
                    )
                    methods[info.id] = info
                }
            }

            print("✓ [MethodRegistry] Loaded \(methods.count) method(s) from \(index?.families.count ?? 0) family(ies)")
            isLoaded = true

        } catch {
            print("❌ [MethodRegistry] Failed to load _index.json: \(error.localizedDescription)")
            isLoaded = true
        }
    }

    // MARK: - Queries

    /// Get all available methods
    func allMethods() -> [MethodInfo] {
        return Array(methods.values).sorted { $0.id < $1.id }
    }

    /// Get method by identifier (family/version)
    func method(id: String) -> MethodInfo? {
        return methods[id]
    }

    /// Get method by family and version
    func method(family: String, version: String) -> MethodInfo? {
        return methods["\(family)/\(version)"]
    }

    // MARK: - Method Instantiation

    /// Create a SegmentationMethod instance by family/version
    ///
    /// Per CONTEXT.md: Runner fails if requested method not found (no fallback)
    func createMethod(family: String, version: String) throws -> SegmentationMethod {
        let id = "\(family)/\(version)"

        guard let info = methods[id] else {
            throw MethodRegistryError.methodNotFound(id)
        }

        // Instantiate based on swiftClass
        // Note: This is a simple switch for now. Future: reflection or registration pattern.
        switch info.swiftClass {
        case "SpectralFluxMethod":
            // v1: Audio-only method from methods/spectral_flux/v1/
            return SpectralFluxMethod()
        case "SpectralFluxVisualValidationMethod":
            // v2: Audio + visual validation method from methods/spectral_flux/v2/
            return SpectralFluxVisualValidationMethod()
        default:
            throw MethodRegistryError.unknownSwiftClass(info.swiftClass)
        }
    }

    /// Load config parameters for a method version
    func loadConfig(family: String, version: String, configName: String) throws -> [String: Any] {
        // Config path in bundle: methods/{family}/{version}/configs/{configName}
        let configPath = "methods/\(family)/\(version)/configs"
        let configFile = configName.hasSuffix(".config.json") ? configName.replacingOccurrences(of: ".config.json", with: "") : configName

        guard let configURL = Bundle.main.url(forResource: configFile + ".config", withExtension: "json", subdirectory: configPath) else {
            throw MethodRegistryError.configNotFound(configName, "\(family)/\(version)")
        }

        let data = try Data(contentsOf: configURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MethodRegistryError.invalidConfig(configName)
        }

        return json["parameters"] as? [String: Any] ?? [:]
    }
}

// MARK: - Errors

enum MethodRegistryError: LocalizedError {
    case methodNotFound(String)
    case unknownSwiftClass(String)
    case configNotFound(String, String)
    case invalidConfig(String)

    var errorDescription: String? {
        switch self {
        case .methodNotFound(let id):
            return "Method not found: \(id)"
        case .unknownSwiftClass(let className):
            return "Unknown Swift class: \(className)"
        case .configNotFound(let config, let method):
            return "Config '\(config)' not found for method \(method)"
        case .invalidConfig(let config):
            return "Invalid config file: \(config)"
        }
    }
}
