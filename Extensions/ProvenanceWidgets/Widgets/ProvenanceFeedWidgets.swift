//
//  ProvenanceFeedWidgets.swift
//  ProvenanceWidgets
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import AppIntents
import PVLibrary
import PVWidgets
import SwiftUI

/// Maps Provenance's App Group snapshot (`widget.*` keys) into the shared PVWidgets feeds.
///
/// The grid and list drawing, the size-driven layout and the edit-screen options all live in
/// the PVWidgets package (github.com/Provenance-Emu/PVWidgets), shared with iCube and iFly.
struct ProvenanceWidgetDataSource: WidgetDataSource {

    var feeds: [WidgetFeed] { [Self.recentlyPlayed, Self.favorites, Self.recentlyAdded] }

    func items(for feed: WidgetFeed.ID, limit: Int) -> [WidgetItem] {
        let games: [WidgetGameEntry]
        switch feed {
        case .recentlyPlayed: games = WidgetSharedDefaults.loadRecentGames()
        case .favorites: games = WidgetSharedDefaults.loadFavoriteGames()
        case .recentlyAdded: games = WidgetSharedDefaults.loadRecentlyAddedGames()
        default: games = []
        }
        // Favorites and new imports may never have been played, so only recents show a date.
        let showsDate = feed == .recentlyPlayed
        return games.prefix(limit).map { Self.item(for: $0, showsDate: showsDate) }
    }

    static func item(for game: WidgetGameEntry, showsDate: Bool) -> WidgetItem {
        WidgetItem(
            id: game.id,
            title: game.title,
            badge: game.systemShortName,
            artworkURL: game.artworkPath.flatMap(WidgetSharedDefaults.artworkURL(forRelativePath:)),
            date: showsDate ? game.lastPlayedDate : nil,
            launchURL: game.launchURL
        )
    }

    // MARK: Feeds

    static let recentlyPlayed = WidgetFeed(
        id: .recentlyPlayed,
        title: String(localized: "widget.recent.display-name", defaultValue: "Recently Played", comment: "Recently Played widget display name"),
        symbolName: "clock.arrow.circlepath",
        emptyMessage: String(localized: "widget.recent.empty-message", defaultValue: "Play a game\nto see it here", comment: "Recently Played widget empty state message")
    )

    static let favorites = WidgetFeed(
        id: .favorites,
        title: String(localized: "widget.favorites.display-name", defaultValue: "Favorites", comment: "Favorites widget display name"),
        symbolName: "star.fill",
        emptyMessage: String(localized: "widget.favorites.empty-message", defaultValue: "Mark games as\nfavorites to see them here", comment: "Favorites widget empty state message")
    )

    static let recentlyAdded = WidgetFeed(
        id: .recentlyAdded,
        title: String(localized: "widget.recently-added.display-name", defaultValue: "Recently Added", comment: "Recently Added game list name"),
        symbolName: "square.and.arrow.down",
        emptyMessage: String(localized: "widget.recently-added.empty-message", defaultValue: "Import a game\nto see it here", comment: "Recently Added game list empty state message")
    )
}

/// Provenance's RetroWave look for the shared feed widgets.
enum ProvenanceWidgetTheme {
    /// Space inside each game's card, around its cover and title.
    private static let cellPadding: CGFloat = 6

    static var retroWave: WidgetTheme {
        var theme = WidgetTheme()
        theme.background = AnyView(
            ZStack {
                RetroWaveWidgetPalette.retroBlack
                RetroWaveWidgetGradients.mainNeon.opacity(0.2)
            }
        )
        theme.cellFill = AnyShapeStyle(RetroWaveWidgetPalette.retroBlack.opacity(0.55))
        theme.cellStroke = AnyShapeStyle(
            LinearGradient(
                colors: [RetroWaveWidgetPalette.neonPink.opacity(0.45), RetroWaveWidgetPalette.neonCyan.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        theme.heroStroke = theme.cellStroke
        theme.coverPlaceholderFill = AnyShapeStyle(Color.white.opacity(0.08))
        theme.titleStyle = AnyShapeStyle(RetroWaveWidgetTypography.titleForeground)
        theme.metaStyle = AnyShapeStyle(RetroWaveWidgetTypography.labelForeground)
        theme.headerStyle = AnyShapeStyle(RetroWaveWidgetPalette.neonPink)
        theme.badgeFill = AnyShapeStyle(
            LinearGradient(
                colors: [RetroWaveWidgetPalette.neonPink.opacity(0.92), RetroWaveWidgetPalette.neonPurple.opacity(0.88)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        theme.fontDesign = .rounded
        theme.metrics.cellPadding = cellPadding
        return theme
    }
}

/// Lets the system find the Show and Layout options PVWidgets adds to the widgets' edit screen.
struct ProvenanceWidgetsIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [PVWidgetsIntentsPackage.self] }
}
#endif
