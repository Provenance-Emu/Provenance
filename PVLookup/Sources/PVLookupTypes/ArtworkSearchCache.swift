import Foundation
import PVSystems

public struct ArtworkSearchKey: Hashable, Sendable {
    public let gameName: String
    public let systemID: SystemIdentifier?
    public let artworkTypes: ArtworkType
    
    public init(gameName: String, systemID: SystemIdentifier?, artworkTypes: ArtworkType) {
        self.gameName = gameName
        self.systemID = systemID
        self.artworkTypes = artworkTypes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(gameName.lowercased())
        hasher.combine(systemID)
        hasher.combine(artworkTypes)
    }

    public static func == (lhs: ArtworkSearchKey, rhs: ArtworkSearchKey) -> Bool {
        lhs.gameName.lowercased() == rhs.gameName.lowercased() &&
        lhs.systemID == rhs.systemID &&
        lhs.artworkTypes == rhs.artworkTypes
    }
}

public actor ArtworkSearchCache {
    public static let shared = ArtworkSearchCache()

    private var cache: [ArtworkSearchKey: [ArtworkMetadata]] = [:]
    private let maxCacheSize = 100
    private var accessOrder: [ArtworkSearchKey] = []  // LRU tracking

    public func get(key: ArtworkSearchKey) -> [ArtworkMetadata]? {
        if let results = cache[key] {
            // Update access order for LRU
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(key)
            return results
        }
        return nil
    }

    public func set(key: ArtworkSearchKey, results: [ArtworkMetadata]) {
        // Remove oldest entry if cache is full
        if cache.count >= maxCacheSize {
            if let oldestKey = accessOrder.first {
                cache.removeValue(forKey: oldestKey)
                accessOrder.removeFirst()
            }
        }

        cache[key] = results

        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }

    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}
