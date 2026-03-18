//
//  ListRecentGamesIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Returns a list of recently played games — usable in Shortcuts automations.
///
/// Example automation: "If recently played games include Pokémon, send a notification."
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct ListRecentGamesIntent: AppIntent {
    public static var title: LocalizedStringResource = "List Recent Games"
    public static var description = IntentDescription(
        "Returns a list of recently played games from your Provenance library.",
        categoryName: "Games"
    )

    public static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(title: "Limit", description: "Maximum number of games to return (1–20).", default: 5)
    public var limit: Int

    // MARK: - Init

    public init() {}

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[GameEntity]> {
        let clampedLimit = max(1, min(20, limit))
        let recents = GameEntityStore.shared.recentEntities(limit: clampedLimit)
        if recents.isEmpty {
            return .result(value: recents, dialog: "You haven't played any games recently.")
        }
        let count = recents.count
        return .result(
            value: recents,
            dialog: "Here are your \(count) most recent game\(count == 1 ? "" : "s")."
        )
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("List \(\.$limit) recent games")
    }
}
#endif
