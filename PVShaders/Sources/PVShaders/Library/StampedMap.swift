//
//  StampedMap.swift
//  PVShaders
//
//  A dictionary whose entries carry the time they were last written, so two
//  copies edited on different devices merge per key: the newer write wins,
//  and removals are kept as tombstones so a merge cannot resurrect them.
//

import Foundation

public struct StampedMap<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        /// `nil` marks a removal.
        public var value: Value?
        public var date: Date
    }

    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    public subscript(key: String) -> Value? { entries[key]?.value }

    /// Keys that currently hold a value.
    public var keys: [String] { entries.compactMap { $0.value.value == nil ? nil : $0.key } }

    /// Key-value pairs that currently hold a value.
    public var values: [String: Value] { entries.compactMapValues(\.value) }

    /// Writes (or with `nil`, removes) `key`.
    public mutating func set(_ value: Value?, for key: String, at date: Date = Date()) {
        entries[key] = Entry(value: value, date: date)
    }

    /// Takes every entry of `other` that is newer than ours. Returns the keys whose value changed.
    @discardableResult
    public mutating func merge(_ other: StampedMap) -> Set<String> {
        var changed = Set<String>()
        for (key, theirs) in other.entries {
            guard let ours = entries[key] else {
                entries[key] = theirs
                if theirs.value != nil { changed.insert(key) }
                continue
            }
            if theirs.date > ours.date {
                entries[key] = theirs
                if theirs.value != ours.value { changed.insert(key) }
            }
        }
        return changed
    }

    /// Drops tombstones older than `date`, and the oldest live entries whose key
    /// matches `prefix` beyond `limit` (keeps the iCloud payload bounded).
    public mutating func prune(tombstonesBefore date: Date, prefix: String? = nil, limit: Int? = nil) {
        entries = entries.filter { $0.value.value != nil || $0.value.date >= date }
        guard let limit else { return }
        let matching = entries.filter { entry in prefix.map { entry.key.hasPrefix($0) } ?? true }
            .sorted { $0.value.date > $1.value.date }
        for (key, _) in matching.dropFirst(limit) {
            entries[key] = nil
        }
    }
}
