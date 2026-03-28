//
//  ConsoleGamesView+GameContextMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVCoreBridge
import protocol PVUIBase.GameContextMenuDelegate
import struct PVUIBase.GameContextMenu
import class PVUIBase.SceneCoordinator

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

        let gameTitle = game.title
        let gameMD5 = game.md5Hash

        DLOG("Downloading game from CloudKit: \(gameTitle) (\(recordID))")

        Task { @MainActor in
            // Show sync status overlay with cancel support
            let syncStatusManager = SceneCoordinator.shared.syncStatusManager
            var downloadTask: Task<Void, Error>?
            var progressObserver: Task<Void, Never>?

            syncStatusManager.show(
                gameTitle: gameTitle,
                statusMessage: "Connecting to iCloud...",
                onCancel: {
                    DLOG("User cancelled download for: \(gameTitle)")
                    downloadTask?.cancel()
                    progressObserver?.cancel()
                    CloudKitDownloadQueue.shared.cancelDownload(md5: gameMD5)
                    syncStatusManager.hide()
                }
            )

            // Start progress observation
            progressObserver = Task { @MainActor in
                let progressTracker = SyncProgressTracker.shared
                var lastProgress: Double = 0

                while !Task.isCancelled {
                    // Check if this game is being downloaded
                    if let activeDownload = progressTracker.activeDownloads.first(where: { $0.matchesROM(md5: gameMD5) }) {
                        let progress = activeDownload.progress
                        if progress != lastProgress {
                            let percentage = Int(progress * 100)
                            let bytesStr = ByteCountFormatter.string(fromByteCount: activeDownload.bytesDownloaded, countStyle: .file)
                            let totalStr = ByteCountFormatter.string(fromByteCount: activeDownload.fileSize, countStyle: .file)
                            syncStatusManager.update(statusMessage: "Downloading... \(percentage)% (\(bytesStr) / \(totalStr))")
                            lastProgress = progress
                        }
                    } else if progressTracker.queuedDownloads.contains(where: { $0.matchesROM(md5: gameMD5) }) {
                        syncStatusManager.update(statusMessage: "Queued for download...")
                    }

                    try? await Task.sleep(nanoseconds: 500_000_000) // Update every 0.5 seconds
                }
            }

            // Execute the download
            downloadTask = Task {
                do {
                    guard let syncer = CloudKitSyncerStore.shared.getSyncer() else {
                        throw NSError(domain: "ConsoleGamesView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CloudKit syncer available"])
                    }

                    await MainActor.run {
                        syncStatusManager.update(statusMessage: "Starting download...")
                    }

                    let fileURL = try await syncer.downloadFileOnDemand(recordName: recordID)
                    DLOG("Downloaded file to: \(fileURL.path)")

                    try await self.updateGameDownloadStatus(recordID: recordID, isDownloaded: true)

                    await MainActor.run {
                        progressObserver?.cancel()
                        syncStatusManager.complete()
                        DLOG("Download complete for: \(gameTitle)")
                    }
                } catch {
                    if Task.isCancelled {
                        DLOG("Download was cancelled for: \(gameTitle)")
                        return
                    }
                    ELOG("Error downloading file: \(error.localizedDescription)")
                    await MainActor.run {
                        progressObserver?.cancel()
                        syncStatusManager.error("Download failed: \(error.localizedDescription)")
                        // Auto-hide error after delay
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            syncStatusManager.hide()
                        }
                    }
                    throw error
                }
            }

            // Wait for completion (but don't block UI)
            _ = try? await downloadTask?.value
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
            if let game = gamesViewModel.gameToUpdateCover {
                saveArtwork(image: image, forGame: game)
            }
            gamesViewModel.gameToUpdateCover = nil
            gamesViewModel.showImagePicker = false
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
        let frozenGame = game.freeze()
        Task {
            await gamesViewModel.prepareArtworkSourceAlert(for: frozenGame)
        }
    }

    internal func saveArtwork(image: UIImage, forGame game: PVGame) {
        /// Extract game info before any async operations (thread-safe)
        guard !game.isInvalidated else {
            ELOG("GameContextMenu: Cannot save artwork - game is invalidated")
            rootDelegate?.showMessage("Cannot save artwork - game data is no longer valid.", title: "Error")
            return
        }

        let gameTitle = game.title
        let md5: String = game.md5Hash ?? ""

        guard !md5.isEmpty else {
            ELOG("GameContextMenu: Cannot save artwork - game has no MD5 hash")
            rootDelegate?.showMessage("Cannot save artwork - game has no identifier.", title: "Error")
            return
        }

        DLOG("GameContextMenu: Attempting to save artwork for game: \(gameTitle)")

        let uniqueID: String = UUID().uuidString
        let key = "artwork_\(md5)_\(uniqueID)"
        DLOG("Generated key for image: \(key)")

        do {
            DLOG("Attempting to write image to disk")
            try PVMediaCache.writeImage(toDisk: image, withKey: key)
            DLOG("Image successfully written to disk")

            DLOG("Attempting to update game's customArtworkURL")
            /// Use MD5-based lookup to get a live managed object on the current thread's Realm
            /// This avoids issues with thaw() returning nil for frozen objects from different Realms
            try RomDatabase.sharedInstance.writeTransaction {
                guard let liveGame = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: md5) else {
                    ELOG("Could not find game with MD5: \(md5) to update artwork")
                    return
                }
                liveGame.customArtworkURL = key
                DLOG("Game's customArtworkURL updated to: \(key)")
            }
            DLOG("Database transaction completed successfully")
            rootDelegate?.showMessage("Artwork has been saved for \(gameTitle).", title: "Artwork Saved")

            /// Sync artwork to CloudKit in background using thread-safe MD5-based method
            let gameMD5 = md5.uppercased()
            Task.detached(priority: .utility) {
                do {
                    /// Use syncArtwork(forMD5:artworkKey:) which handles thread-safety internally
                    try await CloudSyncManager.shared.syncArtwork(forMD5: gameMD5, artworkKey: key)
                    ILOG("Artwork synced to CloudKit for game MD5: \(gameMD5)")
                } catch {
                    ELOG("Failed to sync artwork to CloudKit: \(error.localizedDescription)")
                }
            }

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
            rootDelegate?.showMessage("Failed to set custom artwork for \(gameTitle): \(error.localizedDescription)", title: "Error")
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to move game to system")
        let frozenGame = game.isFrozen ? game : game.freeze()
        gamesViewModel.systemMoveState = SystemMoveState(game: frozenGame)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to show save states for game")
        let frozenGame = game.isFrozen ? game : game.freeze()
        gamesViewModel.continuesManagementState = ContinuesManagementState(game: frozenGame)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        DLOG("ConsoleGamesView: Requesting to show game info for game ID: \(gameId) via ViewModel")
        gamesViewModel.showGameInfo(gameId: gameId)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        gamesViewModel.gameToUpdateCover = game.isFrozen ? game : game.freeze()
        gamesViewModel.showImagePicker = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        gamesViewModel.gameToUpdateCover = game.isFrozen ? game : game.freeze()
        gamesViewModel.showArtworkSearch = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to choose artwork source")
        gamesViewModel.gameToUpdateCover = game.isFrozen ? game : game.freeze()
        // The following now calls the async function on the ViewModel
        Task {
            await gamesViewModel.prepareArtworkSourceAlert(for: game)
        }
        // gamesViewModel.showArtworkSourceAlert = true // This line is now handled by prepareArtworkSourceAlert
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        let frozenGame = game.freeze()
        Task {
            await gamesViewModel.presentDiscSelectionAlert(for: frozenGame, rootDelegate: rootDelegate)
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestSkinSelectionFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to show skin selection for game: \(game.title)")
        // Use NotificationCenter to communicate with the parent view
        NotificationCenter.default.post(
            name: NSNotification.Name("PVShowGameSkinSelection"),
            object: nil,
            userInfo: ["game": game.freeze()]
        )
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestCoreOptionsFor game: PVGame, coreClassName: String, coreName: String) {
        DLOG("ConsoleGamesView: Received request to show core options for \(coreName)")
        gamesViewModel.coreOptionsClassName = coreClassName
        gamesViewModel.coreOptionsCoreName = coreName
        gamesViewModel.coreOptionsGameMD5 = game.md5Hash.isEmpty ? nil : game.md5Hash
        gamesViewModel.showCoreOptionsSheet = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestTransferPakConfigFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to show Transfer Pak config")
        gamesViewModel.transferPakGame = game.isFrozen ? game : game.freeze()
        gamesViewModel.showTransferPakConfig = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestControllerPakSlotsFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to show Controller Pak slots")
        gamesViewModel.controllerPakGame = game.isFrozen ? game : game.freeze()
        gamesViewModel.showControllerPakSlots = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestNetworkPlayFor game: PVGame) {
        guard !game.isInvalidated else { return }
        let frozenGame = game.isFrozen ? game : game.freeze()
        // Prefer a RetroArch core for network play since netplay requires libretro support.
        // First try the user's preferred core if it is RetroArch-based, otherwise fall back
        // to the first RetroArch core available for this system.
        let retroArchCoreID: String? = {
            guard let cores = game.system?.cores else { return nil }
            if let preferredID = game.userPreferredCoreID,
               cores.contains(where: { $0.identifier == preferredID && $0.principleClass.contains("RetroArch") }) {
                return preferredID
            }
            return cores.first(where: { $0.principleClass.contains("RetroArch") })?.identifier
        }()
        gamesViewModel.networkPlayGame = frozenGame
        gamesViewModel.networkPlayCoreIdentifier = retroArchCoreID ?? game.userPreferredCoreID ?? game.system?.cores.first?.identifier ?? ""
        gamesViewModel.showNetworkPlay = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestExportSavesFor game: PVGame) {
        guard !game.isInvalidated else { return }
        let frozenGame = game.isFrozen ? game : game.freeze()
        Task { @MainActor in
            await exportSaves(for: frozenGame)
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestExportSRAMFor game: PVGame) {
        guard !game.isInvalidated else { return }
        let frozenGame = game.isFrozen ? game : game.freeze()
        Task { @MainActor in
            await exportSRAM(for: frozenGame)
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestImportSRAMFor game: PVGame) {
        guard !game.isInvalidated else { return }
        let frozenGame = game.isFrozen ? game : game.freeze()
        Task { @MainActor in
            gamesViewModel.sramImportGame = frozenGame
            gamesViewModel.showSRAMImportPicker = true
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestImportSaveFor game: PVGame) {
        guard !game.isInvalidated else { return }
        gamesViewModel.saveImportPreSelectedGame = game.isFrozen ? game : game.freeze()
        gamesViewModel.showSaveImportWizard = true
    }

    @MainActor
    private func exportSRAM(for game: PVGame) async {
        do {
            let url = try await SaveExporter.shared.exportSRAM(for: game)
#if os(tvOS)
            let rootDelegate = self.rootDelegate
            Task.detached(priority: .userInitiated) {
                let exportsDir = URL.cachesPath.appendingPathComponent("Exports", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                    let destURL = exportsDir.appendingPathComponent(url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: url, to: destURL)
                    await MainActor.run {
                        rootDelegate?.showMessage("Battery save exported to Exports/\(url.lastPathComponent)", title: "Export Complete")
                    }
                } catch {
                    SaveExporter.shared.cleanupExport(at: url)
                    await MainActor.run {
                        rootDelegate?.showMessage("Export failed: \(error.localizedDescription)", title: "Error")
                    }
                }
            }
#else
            gamesViewModel.sramExportURL = url
            gamesViewModel.showSRAMExportShareSheet = true
#endif
        } catch {
            rootDelegate?.showMessage("Battery save export failed: \(error.localizedDescription)", title: "Export Error")
        }
    }

    @MainActor
    func handleSRAMImport(urls: [URL], for game: PVGame) async {
        guard let fileURL = urls.first else { return }
        do {
            try await SaveExporter.shared.importSRAM(from: fileURL, for: game)
            rootDelegate?.showMessage("Battery save imported successfully for \(game.title).", title: "Import Complete")
        } catch {
            rootDelegate?.showMessage("Battery save import failed: \(error.localizedDescription)", title: "Import Error")
        }
    }

    @MainActor
    private func exportSRAM(for game: PVGame) async {
        do {
            let url = try await SaveExporter.shared.exportSRAM(for: game)
#if os(tvOS)
            // tvOS: move zip to Caches/Exports on a background thread to avoid blocking the
            // main actor; only the showMessage calls return to the main actor.
            // tvOS does not have a persistent Documents directory — use Caches instead.
            let rootDelegate = self.rootDelegate
            Task.detached(priority: .userInitiated) {
                let exportsDir = URL.cachesPath.appendingPathComponent("Exports", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                    let destURL = exportsDir.appendingPathComponent(url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: url, to: destURL)
                    await MainActor.run {
                        rootDelegate?.showMessage("Battery save exported to Caches/Exports/\(url.lastPathComponent)", title: "Export Complete")
                    }
                } catch {
                    SaveExporter.shared.cleanupExport(at: url)
                    await MainActor.run {
                        rootDelegate?.showMessage("Export failed: \(error.localizedDescription)", title: "Error")
                    }
                }
            }
#else
            gamesViewModel.sramExportURL = url
            gamesViewModel.showSRAMExportShareSheet = true
#endif
        } catch {
            rootDelegate?.showMessage("Battery save export failed: \(error.localizedDescription)", title: "Export Error")
        }
    }

    @MainActor
    func handleSRAMImport(urls: [URL], for game: PVGame) async {
        guard let fileURL = urls.first else { return }
        do {
            try await SaveExporter.shared.importSRAM(from: fileURL, for: game)
            rootDelegate?.showMessage("Battery save imported successfully for \(game.title).", title: "Import Complete")
        } catch {
            rootDelegate?.showMessage("Battery save import failed: \(error.localizedDescription)", title: "Import Error")
        }
    }

    @MainActor
    private func exportSaves(for game: PVGame) async {
        do {
            let url = try await SaveExporter.shared.exportSaves(for: game)
#if os(tvOS)
            // tvOS: move zip to Caches/Exports on a background thread to avoid blocking the
            // main actor; only the showMessage calls return to the main actor.
            let rootDelegate = self.rootDelegate
            Task.detached(priority: .userInitiated) {
                let exportsDir = URL.cachesPath.appendingPathComponent("Exports", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                    let destURL = exportsDir.appendingPathComponent(url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: url, to: destURL)
                    await MainActor.run {
                        rootDelegate?.showMessage("Saves exported to Exports/\(url.lastPathComponent)", title: "Export Complete")
                    }
                } catch {
                    SaveExporter.shared.cleanupExport(at: url)
                    await MainActor.run {
                        rootDelegate?.showMessage("Export failed: \(error.localizedDescription)", title: "Error")
                    }
                }
            }
#else
            gamesViewModel.saveExportURL = url
            gamesViewModel.showSaveExportShareSheet = true
#endif
        } catch {
            rootDelegate?.showMessage("Export failed: \(error.localizedDescription)", title: "Export Error")
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestResetSkinFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to reset skin for game: \(game.title)")
        guard !game.isInvalidated,
              let systemId = game.system?.enumValue else { return }

        let skinManager = DeltaSkinManager.shared
        #if !os(tvOS)
        let portraitOrientation: SkinOrientation = .portrait
        let landscapeOrientation: SkinOrientation = .landscape
        #else
        let portraitOrientation: SkinOrientation = .landscape
        let landscapeOrientation: SkinOrientation = .landscape
        #endif

        // Clear skin preferences for both orientations using centralized manager
        Task { @MainActor in
            DeltaSkinSelectionManager.shared.setSkin(nil, for: systemId, gameId: game.id, orientation: portraitOrientation, scope: .game)
            DeltaSkinSelectionManager.shared.setSkin(nil, for: systemId, gameId: game.id, orientation: landscapeOrientation, scope: .game)
        }

        rootDelegate?.showMessage("Skin preference reset for \(game.title)", title: "Skin Reset")
    }
}
