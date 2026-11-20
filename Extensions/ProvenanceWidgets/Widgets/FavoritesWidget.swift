//
//  FavoritesWidget.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import PVLibrary
import PVWidgets
import SwiftUI
import WidgetKit

// MARK: - Widget

/// Favorite games, drawn by PVWidgets. The person can switch it to another game list or to a
/// list layout from the widget's edit screen.
struct FavoritesWidget: Widget {
    /// Unchanged from the hand-drawn widget, so widgets already on a Home Screen stay.
    static let kind = "FavoritesWidget"

    var body: some WidgetConfiguration {
        FeedWidgetDefinition(
            kind: Self.kind,
            displayName: LocalizedStringResource("widget.favorites.display-name", defaultValue: "Favorites", comment: "Favorites widget display name"),
            description: LocalizedStringResource("widget.favorites.description", defaultValue: "Quick access to your favourite games.", comment: "Favorites widget description"),
            defaultFeed: ProvenanceWidgetDataSource.favorites,
            fallbackURL: PVLibraryScreenURL
        ).configuration
    }
}
#endif
