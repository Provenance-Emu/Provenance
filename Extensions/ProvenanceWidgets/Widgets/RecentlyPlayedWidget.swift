//
//  RecentlyPlayedWidget.swift
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

/// Recently played games, drawn by PVWidgets. The person can switch it to another game list
/// or to a list layout from the widget's edit screen.
struct RecentlyPlayedWidget: Widget {
    /// Unchanged from the hand-drawn widget, so widgets already on a Home Screen stay.
    static let kind = "RecentlyPlayedWidget"

    var body: some WidgetConfiguration {
        FeedWidgetDefinition(
            kind: Self.kind,
            displayName: LocalizedStringResource("widget.recent.display-name", defaultValue: "Recently Played", comment: "Recently Played widget display name"),
            description: LocalizedStringResource("widget.recent.description", defaultValue: "See the games you've played most recently.", comment: "Recently Played widget description"),
            defaultFeed: ProvenanceWidgetDataSource.recentlyPlayed,
            fallbackURL: PVLibraryScreenURL
        ).configuration
    }
}
#endif
