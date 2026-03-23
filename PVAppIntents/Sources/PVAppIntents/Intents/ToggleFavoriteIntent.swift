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
/// Group UserDefaults suite (configured via `APP_GROUP_IDENTIFIER` in
/// `Info.plist`). Writing the pending favourite key signals the host app to
/// apply the change to Realm on next foreground, without requiring the
/// extension to have direct Realm write access.
///
/// Usage: "Hey Siri, add Donkey Kong Country to my Provenance favourites"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct ToggleFavoriteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Favourite"
    public static let description = IntentDescription(
        "Marks or unmarks a game as a favourite in Provenance.",
        categoryName: "Games"
    )

    public static let openAppWhenRun: Bool = false

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
        // `PVAppDelegate.processPendingIntents()` scans for `pendingFavorite_*` keys
        // in `applicationDidBecomeActive`, applies the Realm write, and removes them.
        pvAppGroupDefaults?.set(isFavorite, forKey: "pendingFavorite_\(game.id)")

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
