//
//  ToggleFavoriteIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Marks or unmarks a game as a favourite.
///
/// The actual Realm write is delegated to the host app via the shared App
/// Group UserDefaults (`group.org.provenance-emu.provenance`). Writing the
/// pending favorite key wakes the host app (via background tasks / polling)
/// so it can apply the change to Realm without the extension needing write
/// access to the database.
///
/// Usage: "Hey Siri, add Donkey Kong Country to my Provenance favourites"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct ToggleFavoriteIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Favourite"
    public static var description = IntentDescription(
        "Marks or unmarks a game as a favourite in Provenance.",
        categoryName: "Games"
    )

    public static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(title: "Game", description: "The game to toggle.")
    public var game: GameEntity

    @Parameter(title: "Mark as Favourite", description: "Set to true to add to favourites, false to remove.")
    public var isFavorite: Bool

    // MARK: - Init

    public init() {}

    public init(game: GameEntity, isFavorite: Bool) {
        self.game = game
        self.isFavorite = isFavorite
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Notify the host app via App Group UserDefaults so it can write to Realm
        // without needing write access from this extension process.
        // TODO: Add host-app handler that scans for `pendingFavorite_*` keys in
        // the shared UserDefaults suite on `applicationDidBecomeActive`, applies
        // the Realm write, and removes the keys to prevent stale accumulation.
        let appGroupID = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
            ?? "group.org.provenance-emu.provenance"
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(isFavorite, forKey: "pendingFavorite_\(game.id)")

        let verb = isFavorite ? "Added" : "Removed"
        return .result(dialog: "\(verb) \(game.title) \(isFavorite ? "to" : "from") favourites.")
    }

    public static var parameterSummary: some ParameterSummary {
        When(\.$isFavorite, .equalTo, true) {
            Summary("Add \(\.$game) to favourites")
        } otherwise: {
            Summary("Remove \(\.$game) from favourites")
        }
    }
}
#endif
