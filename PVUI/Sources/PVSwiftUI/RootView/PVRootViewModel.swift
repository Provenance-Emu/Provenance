//
//  PVRootViewModel.swift
//  Provenance
//
//  Created by Ian Clawson on 2/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Destinations use the same live snapshots and game actions as the Home library.
enum LibraryDestination: String, CaseIterable, Identifiable {
    case home, favorites, recentlyPlayed
    var id: Self { self }
    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .favorites: return String(localized: "Favorites")
        case .recentlyPlayed: return String(localized: "Recently played")
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .favorites: return "heart"
        case .recentlyPlayed: return "clock"
        }
    }
}

/// ViewModel for the Root view
public class PVRootViewModel: ObservableObject {

    /// Whether to sort consoles in ascending order
    @Published public var sortConsolesAscending: Bool = true

    /// Whether to sort games in ascending order
    @Published public var sortGamesAscending: Bool = true

    /// Whether to show games in a grid or list
    @Published public var viewGamesAsGrid: Bool = true

    /// Currently selected console
    @Published public var selectedConsole: PVSystem?

    @Published var libraryDestination: LibraryDestination = .home
    @Published var showsLibrarySearch = false
    @Published var isSidebarCollapsed = false

    let drawerState = LibraryDrawerState()

    /// True while a regular-width iPad shows the sidebar inline instead of as an overlay drawer.
    var usesPinnedSidebar = false

    /// Whether the menu is on screen, as an overlay drawer or the pinned sidebar.
    var isMenuShown: Bool { usesPinnedSidebar ? !isSidebarCollapsed : isMenuVisible }

    func toggleMenu() {
        if usesPinnedSidebar { isSidebarCollapsed.toggle() } else { isMenuVisible.toggle() }
    }

    func dismissMenu() {
        if usesPinnedSidebar { isSidebarCollapsed = true } else { isMenuVisible = false }
    }

    public var isMenuVisible: Bool {
        get { drawerState.isPresented }
        set {
            guard drawerState.isPresented != newValue else { return }
            drawerState.isPresented = newValue
        }
    }

    /// Presentations own controller input while the library remains mounted behind them.
    public var isLibraryInputBlocked: Bool { inputOwnership.isBlocked }

    var inputOwnership = LibraryInputOwnership()

    public init() {
        #if DEBUG
        // Snapshot runs use real library data and actions, with deterministic presentation only.
        viewGamesAsGrid = !ProcessInfo.processInfo.arguments.contains("-PVLibraryList")
        #endif
    }
}

/// Drawer motion must not invalidate every library view observing the root model.
final class LibraryDrawerState: ObservableObject {
    @Published var isPresented = false
}

/// Independent presenters release only their own claim on library controller input.
struct LibraryInputOwnership {
    var hasLibraryPresentation = false
    var hasCoreOptionsPresentation = false

    var isBlocked: Bool { hasLibraryPresentation || hasCoreOptionsPresentation }
}
