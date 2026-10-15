//
//  CatalogueQuery.swift
//  PVLibrarySharing
//
//  v1.1 catalogue filter and paging (spec §3.2), shared by every catalogue
//  route Provenance serves.
//

import Foundation
import PVSystems

/// `?systemIdentifier=a,b&limit=N&cursor=C` on a catalogue request.
///
/// - The filter takes full dotted ids, comma-separated (ECS's field name).
///   Old servers ignore it, so clients filter locally too.
/// - Paging is opt-in: without `limit` the whole list comes back, as before.
///   The response adds `nextCursor`; absent means the list is complete.
/// - A cursor is bound to the catalogue version it came from. When the
///   catalogue changes between pages the cursor is refused (410) and the
///   client starts over, rather than skipping or repeating entries.
struct CatalogueQuery: Equatable {
    static let systemsItem = "systemIdentifier"
    static let limitItem = "limit"
    static let cursorItem = "cursor"
    static let maxLimit = 500

    var systems: Set<SystemIdentifier>?
    var limit: Int?
    var cursor: String?

    init(systems: Set<SystemIdentifier>? = nil, limit: Int? = nil, cursor: String? = nil) {
        self.systems = systems
        self.limit = limit
        self.cursor = cursor
    }

    init(query: [String: String]) {
        if let raw = query[Self.systemsItem], !raw.isEmpty {
            systems = Set(raw.split(separator: ",").compactMap { SystemMap.systemIdentifier(compact: String($0)) })
        }
        limit = query[Self.limitItem].flatMap(Int.init).map { min(max($0, 1), Self.maxLimit) }
        cursor = query[Self.cursorItem].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Query items for a client request.
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let systems {
            items.append(URLQueryItem(name: Self.systemsItem, value: systems.map(\.rawValue).sorted().joined(separator: ",")))
        }
        if let limit { items.append(URLQueryItem(name: Self.limitItem, value: String(limit))) }
        if let cursor { items.append(URLQueryItem(name: Self.cursorItem, value: cursor)) }
        return items
    }

    func admits(_ system: SystemIdentifier?) -> Bool {
        guard let systems else { return true }
        guard let system else { return false }
        return systems.contains(system)
    }

    enum PageError: Error, Equatable {
        /// The cursor belongs to an older catalogue, or is malformed.
        case staleCursor
    }

    /// One page of `entries` (already filtered and in a stable order), and the
    /// cursor of the next page or nil.
    func page<T>(_ entries: [T], version: String) throws -> (items: [T], nextCursor: String?) {
        let tag = Self.versionTag(version)
        var offset = 0
        if let cursor {
            let parts = cursor.split(separator: ".", maxSplits: 1)
            guard parts.count == 2, parts[0] == tag, let start = Int(parts[1]), start >= 0, start <= entries.count else {
                throw PageError.staleCursor
            }
            offset = start
        }
        guard let limit else { return (Array(entries[offset...]), nil) }
        let end = min(offset + limit, entries.count)
        return (Array(entries[offset..<end]), end < entries.count ? "\(tag).\(end)" : nil)
    }

    /// The first 8 characters of the version's hash: what a cursor and TXT
    /// `cv` carry.
    static func versionTag(_ version: String) -> String {
        let hash = version.hasPrefix("v1-") ? String(version.dropFirst(3)) : version
        return String(hash.prefix(8))
    }
}
