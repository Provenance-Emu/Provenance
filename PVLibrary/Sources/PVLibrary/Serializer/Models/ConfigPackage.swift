///
/// ConfigPackage.swift
/// PVLibrary
///
/// Created by Joseph Mattiello
/// Copyright © 2024 Provenance Emu. All rights reserved.
///

import Foundation
import CryptoKit

fileprivate extension Data {
    /// Generate a SHA256 hash of the data
    func sha256() -> String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Metadata for a RetroArch configuration file
public struct ConfigMetadata: Codable, Sendable {
    /// The name of the config file
    public let name: String

    /// The date the config was created/modified
    public let modifiedDate: Date

    /// A hash of the config contents for comparison
    public let contentHash: String

    /// Optional description of what this config is for
    public let description: String?
}

/// Package for RetroArch configuration files
public struct ConfigPackage: Package {
    /// The type of package
    public var type: SerializerPackageType { return .config }

    /// The raw config file data
    public let data: Data

    /// Metadata about the config file
    public let metadata: ConfigMetadata

    /// Create a new config package
    /// - Parameters:
    ///   - data: The raw config file data
    ///   - name: Name of the config
    ///   - description: Optional description
    public init(data: Data, name: String, description: String? = nil) {
        self.data = data
        self.metadata = ConfigMetadata(
            name: name,
            modifiedDate: Date(),
            contentHash: data.sha256(),
            description: description
        )
    }
}
