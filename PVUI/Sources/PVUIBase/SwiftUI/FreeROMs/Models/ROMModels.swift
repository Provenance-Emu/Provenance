import Foundation

/// Models for ROM data from JSON
public struct ROMMapping: Codable {
    /// Dictionary mapping system IDs to their ROM collections
    private let storage: [String: SystemROMs]

    public var systems: [String: SystemROMs] { storage }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        storage = try container.decode([String: SystemROMs].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}

public struct SystemROMs: Codable {
    public let count: Int
    public let roms: [ROM]
}

public struct ROM: Codable, Identifiable {
    public let file: String
    public let size: Int
    public let artwork: ROMArtwork?

    public var id: String { file }
}

public struct ROMArtwork: Codable {
    public let cover: String?
    public let screenshot: String?
}
