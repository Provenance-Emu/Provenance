//
//  ConsoleGamesViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVRealm
import PVSettings
import Combine
import struct PVUIBase.DiscSelectionAlert

class ConsoleGamesViewModel: ObservableObject {
    let console: PVSystem

    /// Game controller navigation state
    @Published var focusedSection: HomeSectionType?
    /// Game controller navigation state
    @Published var focusedItemInSection: String?

    /// Disc selection alert state
    @Published var showDiscSelectionAlert = false
    /// Disc selection alert data
    @Published var discSelectionAlert: DiscSelectionAlert?

    /// Rename Game Alert State
    @Published var showingRenameAlert = false
    /// Game to rename
    @Published var gameToRename: PVGame? = nil
    /// New game title for rename alert
    @Published var newGameTitle = "" // For the TextField binding

    /// Artwork Source Alert State
    @Published var showArtworkSourceAlert = false
    @Published var gameForArtworkUpdate: PVGame? = nil

    /// Import status view properties
    @Published var showImportStatusView = false

    /// Game Info Presentation State
    @Published var selectedGameForInfo: PVGame? = nil
    @Published var showingGameInfo: Bool = false
    
    var gameToUpdateCover: PVGame?

    @Published var gameLibraryItemsPerRow: Int = 4
    @Published var showImagePicker = false
    @Published var showArtworkSearch = false
    @Published var selectedImage: UIImage? = nil
    @Published var renameTitleFieldIsFocused: Bool = false // For FocusState
    @Published var systemMoveState: SystemMoveState? = nil
    @Published var continuesManagementState: ContinuesManagementState? = nil
    
    // Properties that were @State in the View, now @Published in ViewModel
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var previousScrollOffset: CGFloat = 0
    @Published var isSearchBarVisible: Bool = true

    /// Initialize the view model with a console
    init(console: PVSystem) {
        self.console = console

        self.showingRenameAlert = false
    }

    /// Navigation state helpers
    func updateFocus(section: HomeSectionType?, item: String?) async {
        await MainActor.run {
            self.focusedSection = section
            self.focusedItemInSection = item
        }
    }

    /// Get current focused section
    func getCurrentSection() -> HomeSectionType? {
        return focusedSection
    }

    /// Get current focused item
    func getCurrentItem() -> String? {
        return focusedItemInSection
    }

    /// Present disc selection alert for a game
    func presentDiscSelectionAlert(for game: PVGame, rootDelegate: PVRootDelegate?) async {
        let discs = game.relatedFiles.toArray()
        let alertDiscs = discs.compactMap { disc -> DiscSelectionAlert.Disc? in
            return DiscSelectionAlert.Disc(fileName: disc.fileName, path: disc.url!.path)
        }
        
        await MainActor.run {
            self.discSelectionAlert = DiscSelectionAlert(
                game: game,
                discs: alertDiscs
            )
            self.showDiscSelectionAlert = true
        }
    }

    /// MARK: - Rename Game Alert
    func prepareRenameAlert(for game: PVGame) async {
        await MainActor.run {
            self.newGameTitle = game.title
            self.gameToRename = game
            self.showingRenameAlert = true
        }
    }

    /// Note: The actual renaming logic will remain in ConsoleGamesView for now,
    /// or be passed via a closure, to keep ViewModel focused on state.
    /// This ViewModel method will primarily handle the state changes post-action.
    func completeRenameAction() async {
        await MainActor.run {
            self.showingRenameAlert = false
            self.gameToRename = nil
            self.newGameTitle = ""
        }
    }

    /// Note: The actual renaming logic will remain in ConsoleGamesView for now,
    /// or be passed via a closure, to keep ViewModel focused on state.
    /// This ViewModel method will primarily handle the state changes post-action.
    func cancelRenameAction() async {
        await MainActor.run {
            self.showingRenameAlert = false
            self.gameToRename = nil
            self.newGameTitle = ""
        }
    }

    // MARK: - Artwork Source Alert
    func prepareArtworkSourceAlert(for game: PVGame) async {
        await MainActor.run {
            self.gameForArtworkUpdate = game
            self.showArtworkSourceAlert = true
        }
    }

    // These functions will primarily handle the state for the alert itself.
    // The actual presentation of the image picker or search sheet will still be managed by bindings in the View,
    // but these ViewModel methods will ensure the alert is dismissed correctly.

    func handleSelectFromPhotos() async {
        await MainActor.run {
            self.showArtworkSourceAlert = false
        }
    }

    func handleSearchOnline() async {
        await MainActor.run {
            self.showArtworkSourceAlert = false
        }
    }

    func cancelArtworkSourceAlert() async {
        await MainActor.run {
            self.showArtworkSourceAlert = false
            self.gameForArtworkUpdate = nil
        }
    }

    // MARK: - Game Info Presentation
    @MainActor
    func showGameInfo(gameId: String) {
        guard let game = console.games.first(where: { $0.md5Hash == gameId }) else {
            ELOG("ConsoleGamesViewModel: Could not find game with ID: \(gameId) in console \(console.name)")
            return
        }
        DLOG("ConsoleGamesViewModel: Preparing to show game info for game: \(game.title)")
        self.selectedGameForInfo = game
        self.showingGameInfo = true
    }

    @MainActor
    func dismissGameInfo() {
        DLOG("ConsoleGamesViewModel: Dismissing game info")
        self.showingGameInfo = false
        self.selectedGameForInfo = nil
    }
}
