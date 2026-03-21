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
/// Included widgets:
/// - **QuickLaunchWidget** — Lock Screen (circular, rectangular, inline): tap to launch last-played game
/// - **NowPlayingWidget** — Lock Screen (inline, rectangular): shows current music track from Music Player (#2654)
/// - **GameArtGalleryWidget** — StandBy (systemSmall): rotating game art gallery
/// - **NowPlayingStandByWidget** — StandBy (systemSmall): full-screen album art + track info
@main
struct ProvenanceWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickLaunchWidget()
        NowPlayingWidget()
        GameArtGalleryWidget()
        NowPlayingStandByWidget()
    }
}
#endif
