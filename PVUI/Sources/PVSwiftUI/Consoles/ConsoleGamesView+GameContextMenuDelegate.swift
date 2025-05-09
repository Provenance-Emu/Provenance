//
//  ConsoleGamesView+GameContextMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import protocol PVUIBase.GameContextMenuDelegate
import struct PVUIBase.GameContextMenu

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
    
    // MARK: - CloudKit Download Methods
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestDownloadFromCloudFor game: PVGame) {
        guard !game.isInvalidated, let recordID = game.cloudRecordID else { return }
        
        DLOG("Downloading game from CloudKit: \(game.title) (\(recordID))")
        
        // Show loading indicator
        rootDelegate?.showMessage("Downloading \(game.title)...", title: "Downloading")
        
        Task {
            do {
                // Find the appropriate syncer
                guard let syncer = CloudKitSyncerStore.shared.getSyncer() else {
                    ELOG("No CloudKit syncer available")
                    await MainActor.run {
                        rootDelegate?.showMessage("Failed to download: No CloudKit syncer available", title: "Error")
                    }
                    return
                }
                
                // Download the file
                let fileURL = try await syncer.downloadFileOnDemand(recordName: recordID)
                DLOG("Downloaded file to: \(fileURL.path)")
                
                // Update the game's download status in the database
                try await updateGameDownloadStatus(recordID: recordID, isDownloaded: true)
                
                await MainActor.run {
                    rootDelegate?.showMessage("\(game.title) has been downloaded successfully", title: "Download Complete")
                }
            } catch {
                ELOG("Error downloading file: \(error.localizedDescription)")
                await MainActor.run {
                    rootDelegate?.showMessage("Failed to download: \(error.localizedDescription)", title: "Error")
                }
            }
        }
    }
    
    /// Update the download status of a game in the database
    private func updateGameDownloadStatus(recordID: String, isDownloaded: Bool) async throws {
        let realm = try await Realm()
        
        try await realm.asyncWrite {
            if let game = realm.objects(PVGame.self).filter("cloudRecordID == %@", recordID).first {
                game.isDownloaded = isDownloaded
                DLOG("Updated download status for game: \(game.title)")
            }
        }
    }

#if !os(tvOS)
    @ViewBuilder
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

    // MARK: - Rename Methods
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        let frozenGame = game.freeze()
        Task {
            await gamesViewModel.prepareRenameAlert(for: frozenGame)
        }
    }

    internal func submitRename() {
        if !gamesViewModel.newGameTitle.isEmpty, let frozenGame = gamesViewModel.gameToRename, gamesViewModel.newGameTitle != frozenGame.title {
            do {
                guard let thawedGame = frozenGame.thaw() else {
                    throw NSError(domain: "ConsoleGamesView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to thaw game object"])
                }
                RomDatabase.sharedInstance.renameGame(thawedGame, toTitle: gamesViewModel.newGameTitle)
                rootDelegate?.showMessage("Game renamed successfully.", title: "Success")
            } catch {
                DLOG("Failed to rename game: \(error.localizedDescription)")
                rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
            }
        } else if gamesViewModel.newGameTitle.isEmpty {
            rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
        }
        // Call the ViewModel's method to reset state
        Task {
            await gamesViewModel.completeRenameAction()
        }
    }

    // MARK: - Image Picker Methods

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    internal func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game: \(game.title)")

        let uniqueID: String = UUID().uuidString
        let md5: String = game.md5 ?? ""
        let key = "artwork_\(md5)_\(uniqueID)"
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

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        showGameInfo(gameId)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        gameToUpdateCover = game
        showArtworkSearch = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        DLOG("Setting gameToUpdateCover with game: \(game.title)")
        gameToUpdateCover = game
        showArtworkSourceAlert = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        let frozenGame = game.freeze()
        Task {
            await gamesViewModel.presentDiscSelectionAlert(for: frozenGame, rootDelegate: rootDelegate)
        }
    }
}
