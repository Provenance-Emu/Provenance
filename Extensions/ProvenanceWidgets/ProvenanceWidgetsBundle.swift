//
//  ProvenanceWidgetsBundle.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI
import WidgetKit

/// Entry point for the Provenance Widgets extension.
///
/// Home screen widgets:
/// - **RecentlyPlayedWidget** — shows recently played games (small/medium/large)
/// - **FavoritesWidget** — quick-access grid of favourite games (small/medium/large/xLarge)
/// - **LibraryStatsWidget** — library overview (small/medium)
///
/// Lock Screen widgets:
/// - **QuickLaunchWidget** — circular, rectangular, inline: tap to launch last-played game
/// - **NowPlayingWidget** — inline/rectangular: current music track
///
/// StandBy widgets:
/// - **GameArtGalleryWidget** — rotating game art gallery (systemSmall in StandBy)
/// - **NowPlayingStandByWidget** — full-screen album art + track info (systemSmall in StandBy)
@main
struct ProvenanceWidgetsBundle: WidgetBundle {
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
    }
}
#endif
