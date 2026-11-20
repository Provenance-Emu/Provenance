//
//  ProvenanceWidgetsBundle.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import PVWidgets
import SwiftUI
import WidgetKit

/// Entry point for the Provenance Widgets extension.
///
/// Home screen widgets:
/// - **RecentlyPlayedWidget** and **FavoritesWidget** — game lists drawn by the shared
///   PVWidgets package (small/medium/large/xLarge). Each can be switched to another list
///   (recents, favorites, recently added) and to a grid or list layout on its edit screen.
/// - **LibraryStatsWidget** — library overview (small/medium)
///
/// Lock Screen widgets:
/// - **QuickLaunchWidget** — circular, rectangular, inline: tap to launch last-played game
/// - **NowPlayingWidget** — inline/rectangular: current music track
///
/// StandBy widgets:
/// - **GameArtGalleryWidget** — rotating game art gallery (systemSmall in StandBy)
/// - **NowPlayingStandByWidget** — full-screen album art + track info (systemSmall in StandBy)
///
/// Live Activities:
/// - **GameLiveActivityWidget** — Dynamic Island + lock-screen activity for in-game sessions
@main
struct ProvenanceWidgetsBundle: WidgetBundle {
    init() {
        PVWidgetsHost.configure(dataSource: ProvenanceWidgetDataSource(), theme: ProvenanceWidgetTheme.retroWave)
    }

    var body: some Widget {
        // Home screen
        RecentlyPlayedWidget()
        FavoritesWidget()
        LibraryStatsWidget()
        // Lock Screen
        QuickLaunchWidget()
        NowPlayingWidget()
        // StandBy
        GameArtGalleryWidget()
        NowPlayingStandByWidget()
        // Live Activities (requires iOS 16.2+; deployment target is iOS 17+)
        GameLiveActivityWidget()
    }
}
#endif
