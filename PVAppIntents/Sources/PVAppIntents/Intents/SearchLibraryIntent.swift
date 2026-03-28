//
//  SearchLibraryIntent.swift
//  PVAppIntents
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Returns a filtered list of games from the library — usable in Shortcuts
//  automations, e.g. "Show me all my SNES games in Provenance".
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Returns a filtered list of games from the Provenance library.
///
/// Filters by:
/// - `query` — case-insensitive substring match on title
/// - `system` — optional `SystemEntity` to restrict results to one system
///
/// Usage in Shortcuts:
/// - "Search Provenance for Mario" → returns `[GameEntity]` for automations
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct SearchLibraryIntent: AppIntent {

    public static let title: LocalizedStringResource = "Search Game Library"
    public static let description = IntentDescription(
        "Returns games from the Provenance library matching a search query, optionally filtered by system.",
        categoryName: "Games"
    )

    // MARK: - Parameters

    @Parameter(
        title: "Search Query",
        description: "Case-insensitive substring of the game title.",
        requestValueDialog: "What game title would you like to search for?"
    )
    public var query: String

    @Parameter(title: "System", description: "Restrict results to this system. Leave empty for all systems.")
    public var system: SystemEntity?

    // MARK: - Init

    public init() {}

    public init(query: String, system: SystemEntity? = nil) {
        self.query = query
        self.system = system
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ReturnsValue<[GameEntity]> & ProvidesDialog {
        let store = GameEntityStore.shared
        var results = store.allEntities()

        // Filter by system if specified
        if let system {
            results = results.filter { $0.systemIdentifier == system.id }
        }

        // Filter by query (case-insensitive)
        let lowercasedQuery = query.lowercased()
        if !lowercasedQuery.isEmpty {
            results = results.filter { $0.title.lowercased().contains(lowercasedQuery) }
        }

        // Return results sorted by title for consistent ordering.
        results.sort { $0.title.localizedCompare($1.title) == .orderedAscending }

        let count = results.count
        let dialog: IntentDialog
        if count == 0 {
            dialog = "No games found matching '\(query)' in Provenance."
        } else if count == 1 {
            dialog = "Found 1 game matching '\(query)' in Provenance."
        } else {
            dialog = "Found \(count) games matching '\(query)' in Provenance."
        }

        return .result(value: results, dialog: dialog)
    }

    public static var parameterSummary: some ParameterSummary {
        When(\SearchLibraryIntent.$system, .hasAnyValue) {
            Summary("Search Provenance for \(\.$query) on \(\.$system)")
        } otherwise: {
            Summary("Search Provenance for \(\.$query)")
        }
    }
}
#endif
