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

    let drawerState = LibraryDrawerState()

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

    public init() {}
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
