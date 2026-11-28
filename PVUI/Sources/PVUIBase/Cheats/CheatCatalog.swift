// CheatCatalog.swift
// PVUI
//
// The one list the cheats menu shows: the game's saved cheats, then the cheats
// the bundled database and the online sources know for it, without duplicates.

import Foundation
import PVLibrary
import PVPrimitives
import PVRealm

// MARK: - Cheat Code Normalization

/// Puts a cheat code into the form it is saved and compared in.
enum CheatCodeNormalizer {
    /// Matches non-alphanumeric characters (excluding hyphens, brackets, colons, and plus)
    /// and whitespace — replaced with '+' as the canonical multi-code separator.
    private static let separatorRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[^a-zA-Z0-9-\\[\\]:+]+|[\\s]+", options: .caseInsensitive)
    }()
    /// Collapses runs of '+' into a single '+'.
    private static let multiPlusRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[+]+|[\\s]+", options: .caseInsensitive)
    }()
    /// Strips leading and trailing '+' characters.
    private static let leadTrailPlusRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[+]+|[+]+$", options: .caseInsensitive)
    }()

    /// Normalizes a raw cheat code string into a canonical form:
    /// uppercased, non-alphanumeric separators → '+', collapsed, trimmed.
    static func normalize(_ code: String) -> String {
        let upper = code.uppercased()
        var range = NSRange(upper.startIndex..., in: upper)
        var result = separatorRegex.stringByReplacingMatches(in: upper, range: range, withTemplate: "+")
        range = NSRange(result.startIndex..., in: result)
        result = multiPlusRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "+")
        range = NSRange(result.startIndex..., in: result)
        result = leadTrailPlusRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        return result
    }
}

// MARK: - Model

/// A saved cheat, copied out of the database so the list can be built off it.
struct SavedCheatSnapshot: Equatable, Sendable {
    let id: String
    let name: String
    let code: String
    let codeType: String
    let isEnabled: Bool
}

extension SavedCheatSnapshot {
    /// Copies a saved cheat; `nil` when the object has been deleted.
    init?(_ cheat: PVCheats) {
        guard !cheat.isInvalidated else { return nil }
        self.init(
            id: cheat.id,
            name: cheat.type ?? "",
            code: cheat.code ?? "",
            codeType: cheat.codeType,
            isEnabled: cheat.enabled
        )
    }
}

/// One row of the cheats menu.
struct CheatCatalogItem: Identifiable, Equatable, Sendable {
    /// Where a row comes from.
    enum Source: Equatable, Sendable {
        /// The user saved it (typed it in, or switched a database cheat on before).
        case saved
        /// The cheat database that ships with the app.
        case bundled
        /// Fetched from an online source.
        case online
    }

    let id: String
    let name: String
    let code: String
    /// The code format handed to the core when the cheat is switched on.
    let codeType: String
    /// Second line under the code: the device or format, and the category.
    let detail: String?
    let source: Source
    let isEnabled: Bool
    /// The saved cheat's id; `nil` for a cheat that is only on offer.
    let savedID: String?
    /// The normalized code two rows are compared by.
    let key: String

    var isSaved: Bool { source == .saved }
}

// MARK: - Merge

/// Builds and filters the cheats menu's list.
enum CheatCatalog {
    /// The name a cheat without one is shown under.
    static let untitledName = "Cheat Code"
    /// Database categories that say nothing and are left out of the detail line.
    private static let uninformativeCategories: Set<String> = ["", "general"]

    /// Merges the three sources into one list: saved cheats first, in the order
    /// given, then the bundled database's, then the online ones.
    ///
    /// Two cheats are the same when their normalized codes match. Every saved
    /// cheat is kept; a database or online cheat is dropped when a saved cheat
    /// or an earlier entry already has its code, and when it has no code.
    static func merge(
        saved: [SavedCheatSnapshot],
        bundled: [CheatDatabaseEntry],
        online: [CheatDatabaseEntry]
    ) -> [CheatCatalogItem] {
        var items: [CheatCatalogItem] = []
        var seen = Set<String>()

        for cheat in saved {
            let key = CheatCodeNormalizer.normalize(cheat.code)
            seen.insert(key)
            items.append(CheatCatalogItem(
                id: "saved:\(cheat.id)",
                name: cheat.name.isEmpty ? untitledName : cheat.name,
                code: cheat.code,
                codeType: cheat.codeType,
                detail: cheat.codeType.isEmpty ? nil : cheat.codeType,
                source: .saved,
                isEnabled: cheat.isEnabled,
                savedID: cheat.id,
                key: key
            ))
        }

        func add(_ entries: [CheatDatabaseEntry], source: CheatCatalogItem.Source) {
            for entry in entries {
                let key = CheatCodeNormalizer.normalize(entry.cheatCode)
                guard !key.isEmpty, seen.insert(key).inserted else { continue }
                let name = entry.cheatName.trimmingCharacters(in: .whitespacesAndNewlines)
                items.append(CheatCatalogItem(
                    id: "catalog:\(key)",
                    name: name.isEmpty ? untitledName : name,
                    code: entry.cheatCode,
                    codeType: codeType(for: entry),
                    detail: detail(for: entry),
                    // An entry says itself whether it came from the network: the
                    // GameCube and Wii code lookup answers with the bundled search.
                    source: entry.isOnlineResult ? .online : source,
                    isEnabled: false,
                    savedID: nil,
                    key: key
                ))
            }
        }
        add(bundled, source: .bundled)
        add(online, source: .online)
        return items
    }

    /// The rows whose name, code or detail contains `text`, ignoring case.
    /// An empty or blank `text` keeps every row.
    static func filter(_ items: [CheatCatalogItem], matching text: String) -> [CheatCatalogItem] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(needle)
                || item.code.localizedCaseInsensitiveContains(needle)
                || (item.detail?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }

    /// The code format a database entry is saved with: the core's own name for
    /// the device when it is a known one, else the device name as the database has it.
    static func codeType(for entry: CheatDatabaseEntry) -> String {
        CheatCodeTypes(string: entry.deviceName)?.stringValue ?? entry.deviceName
    }

    private static func detail(for entry: CheatDatabaseEntry) -> String? {
        let device = (entry.deviceFormat ?? entry.deviceName).trimmingCharacters(in: .whitespacesAndNewlines)
        let category = entry.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [device, uninformativeCategories.contains(category.lowercased()) ? "" : category]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
