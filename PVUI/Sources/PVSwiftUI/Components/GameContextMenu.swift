//
//  GameContextMenu.swift
//  Provenance
//
//  Created by Ian Clawson on 1/28/22.
//  Copyright 2022 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import PVLibrary
import RealmSwift
import PVUIBase
import PVRealm
import PVLogging
import PVUIBase

/// A SwiftUI context menu for game-related actions
struct GameContextMenu: View {
    // Use a frozen game to avoid Realm threading issues
    let game: PVGame

    // Cache computed properties
    @State private var availableCores: [PVCore] = []
    @State private var hasSaveStates: Bool = false

    weak var rootDelegate: PVRootDelegate?
    var contextMenuDelegate: GameContextMenuDelegate?

    @State private var showArtworkSearch = false
    @State private var showImagePicker = false
    @State private var showArtworkSourceAlert = false
    @State private var gameToUpdateCover: PVGame?

    init(game: PVGame, rootDelegate: PVRootDelegate?, contextMenuDelegate: GameContextMenuDelegate?) {
        // Ensure we're working with a frozen copy
        self.game = game.isFrozen ? game : game.freeze()
        self.rootDelegate = rootDelegate
        self.contextMenuDelegate = contextMenuDelegate

        let unsupportedCores = Defaults[.unsupportedCores]

        // Initialize computed properties
        _availableCores = State(initialValue: game.system?.cores.filter {
            !(AppState.shared.isAppStore && $0.appStoreDisabled && !unsupportedCores)
        } ?? [])
        _hasSaveStates = State(initialValue: !game.saveStates.isEmpty)
    }

    var body: some View {
        Group {
            if !game.isInvalidated {
                // Add multi-disc menu if game has related files
                if Set(game.relatedFiles).count > 1 {
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestDiscSelectionFor: game)
                    } label: {
                        Label("Select Disc", systemImage: "opticaldisc")
                    }
                }

                if availableCores.count > 1 {
                    Button {
                        Task { @MainActor in
                            // Thaw game for UI operations
                            if let thawedGame = game.thaw() {
                                await rootDelegate?.root_presentCoreSelection(forGame: thawedGame, sender: self)
                            }
                        }
                    } label: { Label("Open in...", systemImage: "gamecontroller") }
                }
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowGameInfoFor: game.md5Hash)
                } label: { Label("Game Info", systemImage: "info.circle") }
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowSaveStatesFor: game)
                } label: {
                    Label("Manage Save States", systemImage: "clock.arrow.circlepath")
                }
                .disabled(game.saveStates.isEmpty)
                Button {
                    // Toggle isFavorite for the selected PVGame
                    toggleFavorite()
                } label: { Label("Favorite", systemImage: "heart") }
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestRenameFor: game)
                } label: { Label("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") }
                Button {
                    promptUserMD5CopiedToClipboard(forGame: game)
                } label: { Label("Copy MD5 URL", systemImage: "number.square") }

                if game.userPreferredCoreID != nil || game.system?.userPreferredCoreID != nil {
                    Button {
                        resetCorePreferences(forGame: game)
                    } label: { Label("Reset Core Preferences", systemImage: "arrow.counterclockwise") }
                }
    #if !os(tvOS)
                Button {
                    DLOG("GameContextMenu: Choose Cover button tapped")
                    contextMenuDelegate?.gameContextMenu(self, didRequestChooseArtworkSourceFor: game)
                } label: { Label("Choose Cover", systemImage: "book.closed") }
    #endif
                Button {
                    pasteArtwork(forGame: game)
                } label: { Label("Paste Cover", systemImage: "doc.on.clipboard") }
                if game.customArtworkURL != "" {
                    Button {
                        clearCustomArtwork(forGame: game)
                    } label: { Label("Clear Custom Artwork", systemImage: "xmark.circle") }
                }
                Divider()
                if !game.contentless {
                    Button {
                        DLOG("GameContextMenu: Move to System button tapped")
                        contextMenuDelegate?.gameContextMenu(self, didRequestMoveToSystemFor: game)
                    } label: { Label("Move to System", systemImage: "folder.fill.badge.plus") }
                }
                if #available(iOS 15, tvOS 15, macOS 12, *), !game.contentless {
                    Button(role: .destructive) {
                        Task.detached { @MainActor in
                            rootDelegate?.attemptToDelete(game: game, deleteSaves: false)
                        }
                    } label: { Label("Delete", systemImage: "trash") }
                } else if !game.contentless {
                    Button {
                        Task.detached { @MainActor in
                            rootDelegate?.attemptToDelete(game: game, deleteSaves: false)
                        }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .uiKitAlert(
            "Choose Artwork Source",
            message: "Select artwork from your photo library or search online sources",
            isPresented: $showArtworkSourceAlert,
            buttons: {
                UIAlertAction(title: "Select from Photos", style: .default) { [contextMenuDelegate] _ in
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowImagePickerFor: game)
                }
                UIAlertAction(title: "Search Online", style: .default) { [contextMenuDelegate] _ in
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowArtworkSearchFor: game)
                }
                UIAlertAction(title: "Cancel", style: .cancel)
            }
        )
    }

    // Move heavy operations to background tasks
    private func toggleFavorite() {
        Task {
            // Perform Realm write on background thread
            try await RomDatabase.sharedInstance.asyncWriteTransaction {
                if let thawedGame = game.thaw() {
                    thawedGame.isFavorite.toggle()
                }
            }
        }
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        Task {
            do {
                let uniqueID = UUID().uuidString
                let key = "artwork_\(game.md5)_\(uniqueID)"

                // Write image to disk asynchronously
                try await Task.detached(priority: .background) {
                    try PVMediaCache.writeImage(toDisk: image, withKey: key)
                }.value

                // Update Realm on main thread
                try await RomDatabase.sharedInstance.asyncWriteTransaction {
                    if let thawedGame = game.thaw() {
                        thawedGame.customArtworkURL = key
                    }
                }

                await MainActor.run {
                    rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")
                }
            } catch {
                await MainActor.run {
                    DLOG("Failed to set custom artwork: \(error.localizedDescription)")
                    rootDelegate?.showMessage("Failed to set custom artwork: \(error.localizedDescription)", title: "Error")
                }
            }
        }
    }
}

extension GameContextMenu {
    func promptUserMD5CopiedToClipboard(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
        // Get the MD5 of the game
        let md5 = game.md5
        // Copy to pasteboard
#if !os(tvOS)
        UIPasteboard.general.string = md5
#endif
        rootDelegate?.showMessage("The MD5 hash for \(game.title) has been copied to the clipboard.", title: "MD5 Copied")
    }

    func pasteArtwork(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
#if !os(tvOS)
        DLOG("Attempting to paste artwork for game: \(game.title)")
        let pasteboard = UIPasteboard.general
        if let pastedImage = pasteboard.image {
            DLOG("Image found in pasteboard")
            saveArtwork(image: pastedImage, forGame: game)
        } else if let pastedURL = pasteboard.url {
            DLOG("URL found in pasteboard: \(pastedURL)")
            do {
                let imageData = try Data(contentsOf: pastedURL)
                DLOG("Successfully loaded data from URL")
                if let image = UIImage(data: imageData) {
                    DLOG("Successfully created UIImage from URL data")
                    saveArtwork(image: image, forGame: game)
                } else {
                    DLOG("Failed to create UIImage from URL data")
                    artworkNotFoundAlert()
                }
            } catch {
                DLOG("Failed to load data from URL: \(error.localizedDescription)")
                artworkNotFoundAlert()
            }
        } else {
            DLOG("No image or URL found in pasteboard")
            artworkNotFoundAlert()
        }
#else
        DLOG("Pasting artwork not supported on this platform")
        rootDelegate?.showMessage("Pasting artwork is not supported on this platform.", title: "Not Supported")
#endif
    }

    func artworkNotFoundAlert() {
        DLOG("Showing artwork not found alert")
        rootDelegate?.showMessage("Pasteboard did not contain an image.", title: "Artwork Not Found")
    }

    private func clearCustomArtwork(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
        DLOG("GameContextMenu: Attempting to clear custom artwork for game: \(game.title)")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                thawedGame?.customArtworkURL = ""
            }
            DLOG("Successfully cleared custom artwork for game: \(game.title)")
            rootDelegate?.showMessage("Custom artwork has been cleared for \(game.title).", title: "Artwork Cleared")
            try PVMediaCache.deleteImage(forKey: game.customArtworkURL)
            DLOG("Successfully deleted custom artowrk form game: \(game.title)")
        } catch {
            DLOG("Failed to clear custom artwork: \(error.localizedDescription)")
            rootDelegate?.showMessage("Failed to clear custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
        }
    }

    private func resetCorePreferences(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
        let hasGamePreference = game.userPreferredCoreID != nil
        let hasSystemPreference = game.system?.userPreferredCoreID != nil

        let alert = UIAlertController(title: "Reset Core Preferences",
                                    message: "Which core preference would you like to reset?",
                                    preferredStyle: .alert)

        if hasGamePreference {
            alert.addAction(UIAlertAction(title: "Game Preference", style: .default) { _ in
                try! Realm().write {
                    game.thaw()?.userPreferredCoreID = nil
                }
            })
        }

        if hasSystemPreference {
            alert.addAction(UIAlertAction(title: "System Preference", style: .default) { _ in
                try! Realm().write {
                    game.system?.thaw()?.userPreferredCoreID = nil
                }
            })
        }

        if hasGamePreference && hasSystemPreference {
            alert.addAction(UIAlertAction(title: "Both", style: .default) { _ in
                try! Realm().write {
                    game.thaw()?.userPreferredCoreID = nil
                    game.system?.thaw()?.userPreferredCoreID = nil
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
}
