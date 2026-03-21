//
//  ProvenanceWidgets.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import WidgetKit
import SwiftUI

@main
struct ProvenanceWidgets: WidgetBundle {
    var body: some Widget {
        RecentlyPlayedWidget()
        FavoritesWidget()
        LibraryStatsWidget()
    }
}
#endif
