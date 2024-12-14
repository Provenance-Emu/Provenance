import Foundation

/// Result type for artwork mappings query
public struct ArtworkMappings: Sendable {
    public let romMD5: [String: [String: String]]
    public let romFileNameToMD5: [String: String]

    public init(romMD5: [String: [String: String]], romFileNameToMD5: [String: String]) {
        self.romMD5 = romMD5
        self.romFileNameToMD5 = romFileNameToMD5
    }
}

public typealias ArtworkMapping = ArtworkMappings
