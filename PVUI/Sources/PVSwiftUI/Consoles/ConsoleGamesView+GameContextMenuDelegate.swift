//
//  ConsoleGamesView+GameContextMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI

internal struct SystemMoveState: Identifiable {
    var id: String {
        guard !game.isInvalidated else { return "" }
        return game.id
    }
    let game: PVGame
    var isPresenting: Bool = true
}

internal struct ContinuesManagementState: Identifiable {
    var id: String {
        guard !game.isInvalidated else { return "" }
        return game.id
    }
    let game: PVGame
    var isPresenting: Bool = true
}

extension ConsoleGamesView: GameContextMenuDelegate {

#if !os(tvOS)
    internal func imagePickerView() -> some View {
        ImagePicker(sourceType: .photoLibrary) { image in
            if let game = gameToUpdateCover {
                saveArtwork(image: image, forGame: game)
            }
            gameToUpdateCover = nil
            showImagePicker = false
        }
    }
#endif

    internal func renameAlertView() -> some View {
        Group {
            TextField("New name", text: $newGameTitle)
                .onSubmit { submitRename() }
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button("Cancel", role: .cancel) { showingRenameAlert = false }
            Button("OK") { submitRename() }
        }
    }

    // MARK: - Rename Methods
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        gameToRename = game.freeze()
        newGameTitle = game.title
        showingRenameAlert = true
    }

    private func submitRename() {
        if !newGameTitle.isEmpty, let frozenGame = gameToRename, newGameTitle != frozenGame.title {
            do {
                guard let thawedGame = frozenGame.thaw() else {
                    throw NSError(domain: "ConsoleGamesView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to thaw game object"])
                }
                RomDatabase.sharedInstance.renameGame(thawedGame, toTitle: newGameTitle)
                rootDelegate?.showMessage("Game renamed successfully.", title: "Success")
            } catch {
                DLOG("Failed to rename game: \(error.localizedDescription)")
                rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
            }
        } else if newGameTitle.isEmpty {
            rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
        }
        showingRenameAlert = false
        gameToRename = nil
    }

    // MARK: - Image Picker Methods

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game: \(game.title)")

        let uniqueID = UUID().uuidString
        let key = "artwork_\(game.md5)_\(uniqueID)"
        DLOG("Generated key for image: \(key)")

        do {
            DLOG("Attempting to write image to disk")
            try PVMediaCache.writeImage(toDisk: image, withKey: key)
            DLOG("Image successfully written to disk")

            DLOG("Attempting to update game's customArtworkURL")
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                DLOG("Game thawed: \(thawedGame?.title ?? "Unknown")")
                thawedGame?.customArtworkURL = key
                DLOG("Game's customArtworkURL updated to: \(key)")
            }
            DLOG("Database transaction completed successfully")
            rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")

            DLOG("Attempting to verify image retrieval")
            PVMediaCache.shareInstance().image(forKey: key) { retrievedKey, retrievedImage in
                if let retrievedImage = retrievedImage {
                    DLOG("Successfully retrieved saved image for key: \(retrievedKey)")
                    DLOG("Retrieved image size: \(retrievedImage.size)")
                } else {
                    DLOG("Failed to retrieve saved image for key: \(retrievedKey)")
                }
            }
        } catch {
            DLOG("Failed to set custom artwork: \(error.localizedDescription)")
            DLOG("Error details: \(error)")
            rootDelegate?.showMessage("Failed to set custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to move game to system")
        let frozenGame = game.isFrozen ? game : game.freeze()
        systemMoveState = SystemMoveState(game: frozenGame)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to show save states for game")
        continuesManagementState = ContinuesManagementState(game: game)
    }
}
