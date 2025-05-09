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

    /// Import status view properties
    @Published var showImportStatusView = false

    /// Initialize the view model with a console
    init(console: PVSystem) {
        self.console = console
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
        await MainActor.run {
            let discs = game.relatedFiles.toArray()
            let alertDiscs = discs.compactMap { disc -> DiscSelectionAlert.Disc? in
                return DiscSelectionAlert.Disc(fileName: disc.fileName, path: disc.url!.path)
            }
            
            self.discSelectionAlert = DiscSelectionAlert(
                game: game,
                discs: alertDiscs
            )
            self.showDiscSelectionAlert = true
        }
    }

    /// MARK: - Rename Game Alert
    func prepareRenameAlert(for game: PVGame) async {
        // Ensure operations that modify @Published properties are on the MainActor
        await MainActor.run {
            self.newGameTitle = game.title // Pre-fill with current name
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
}
