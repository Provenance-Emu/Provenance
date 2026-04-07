//
//  GameContextMenu.swift
//  Provenance
//
//  Created by Ian Clawson on 1/28/22.
//  Copyright 2022 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import PVCoreBridge
import PVLibrary
import RealmSwift
import PVUIBase
import PVRealm
import PVLogging
import PVFeatureFlags
import PVPrimitives

#if canImport(PVAppIntents)
import PVAppIntents
#endif

private struct CoreOptionEntry {
    let coreClass: CoreOptional.Type
    let principleClassName: String
    let name: String
}

/// A SwiftUI context menu for game-related actions
public struct GameContextMenu: View {
    // Use a frozen game to avoid Realm threading issues
    let game: PVGame

    // Cache computed properties
    @State private var availableCores: [PVCore] = []
    @State private var hasSaveStates: Bool = false
    @State private var hasBatterySaves: Bool = false
    @State private var hasCloudRecord: Bool = false
    @State private var isDownloaded: Bool = true
    @Default(.iCloudSync) private var iCloudSyncEnabled

    weak var rootDelegate: PVRootDelegate?
    var contextMenuDelegate: GameContextMenuDelegate?

    @State private var showArtworkSourceAlert = false
    @State private var gameToUpdateCover: PVGame?
    @Environment(\.featureFlags) private var featureFlags

    public init(game: PVGame, rootDelegate: PVRootDelegate?, contextMenuDelegate: GameContextMenuDelegate?) {
        // Ensure we're working with a frozen copy
        self.game = game.isFrozen ? game : game.freeze()
        self.rootDelegate = rootDelegate
        self.contextMenuDelegate = contextMenuDelegate

        // Use self.game (frozen) consistently to avoid Realm thread violations
        let frozenGame = self.game

        // Initialize computed properties
        _availableCores = State(initialValue: frozenGame.system?.cores.toArray().filter {
            !(AppState.shared.isAppStore && $0.appStoreDisabled)
        } ?? [])
        let fm = FileManager.default
        // Check that at least one save-state file actually exists on disk
        let hasLocalSaveStates = frozenGame.saveStates.contains { saveState in
            guard let fileURL = saveState.file?.url else { return false }
            return fm.fileExists(atPath: fileURL.path)
        }
        _hasSaveStates = State(initialValue: hasLocalSaveStates)
        // hasBatterySaves is computed asynchronously in .task to avoid calling
        // Paths.batterySavesPath on the main thread (it may block on iCloud-backed storage).
        _hasBatterySaves = State(initialValue: false)
        _hasCloudRecord = State(initialValue: frozenGame.cloudRecordID != nil)
        _isDownloaded = State(initialValue: frozenGame.isDownloaded)
    }

    public var body: some View {
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

                // Transfer Pak configuration — only shown for N64 games that are known to
                // support the Transfer Pak accessory (e.g. Pokémon Stadium, Mario Tennis).
                // Showing the option for all N64 games is confusing because most titles
                // never use the Transfer Pak.
                if featureFlags.mupenTransferPak,
                   game.systemIdentifier == SystemIdentifier.N64.rawValue,
                   TransferPakCompatibleGames.isKnownTransferPakGame(game.title) {
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestTransferPakConfigFor: game)
                    } label: {
                        Label("Configure Transfer Pak", systemImage: "memorychip")
                    }
                }

                // N64 Controller Pak slot picker (Memory Pak, Rumble Pak, Transfer Pak, etc.)
                if game.systemIdentifier == SystemIdentifier.N64.rawValue {
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestControllerPakSlotsFor: game)
                    } label: {
                        Label("Controller Pak Slots", systemImage: "gamecontroller.fill")
                    }
                }

                if availableCores.count > 1 {
                    // Use inline Menu to show cores with save state counts
                    // directly in the context menu — no separate alert needed.
                    Menu {
                        ForEach(availableCores, id: \.identifier) { core in
                            Button {
                                Task { @MainActor in
                                    if let thawedGame = game.thaw() {
                                        await rootDelegate?.root_load(thawedGame, sender: self, core: core, saveState: nil)
                                    }
                                }
                            } label: {
                                let saveCount = game.saveStates.filter("core.identifier == %@", core.identifier).count
                                if saveCount > 0 {
                                    Label("\(core.projectName) (\(saveCount) save\(saveCount == 1 ? "" : "s"))", systemImage: "gamecontroller")
                                } else {
                                    Label(core.projectName, systemImage: "gamecontroller")
                                }
                            }
                        }
                    } label: {
                        Label("Open in...", systemImage: "gamecontroller")
                    }
                }
                // Core Options for this game — only shown when at least one core supports CoreOptional
                let coreEntries: [CoreOptionEntry] = availableCores.compactMap { core in
                    guard let cls = NSClassFromString(core.principleClass) as? CoreOptional.Type else { return nil }
                    return CoreOptionEntry(coreClass: cls, principleClassName: core.principleClass, name: core.projectName)
                }
                if coreEntries.count == 1 {
                    let entry = coreEntries[0]
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestCoreOptionsFor: game, coreClassName: entry.principleClassName, coreName: entry.name)
                    } label: {
                        Label("Core Options for This Game", systemImage: "slider.horizontal.3")
                    }
                } else if coreEntries.count > 1 {
                    Menu {
                        ForEach(coreEntries.indices, id: \.self) { i in
                            let entry = coreEntries[i]
                            Button {
                                contextMenuDelegate?.gameContextMenu(self, didRequestCoreOptionsFor: game, coreClassName: entry.principleClassName, coreName: entry.name)
                            } label: {
                                Label(entry.name, systemImage: "slider.horizontal.3")
                            }
                        }
                    } label: {
                        Label("Core Options for This Game", systemImage: "slider.horizontal.3")
                    }
                }
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowGameInfoFor: game.md5Hash)
                } label: { Label("Game Info", systemImage: "info.circle") }
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowSaveStatesFor: game)
                } label: {
                    Label("Manage Save States", systemImage: "clock.arrow.circlepath")
                }
                .disabled(!hasSaveStates)
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestExportSavesFor: game)
                } label: {
                    Label("Export Saves", systemImage: "square.and.arrow.up")
                }
                .disabled(!hasSaveStates && !hasBatterySaves)
                if featureFlags.sramImportExport {
                    if hasBatterySaves {
                        Button {
                            contextMenuDelegate?.gameContextMenu(self, didRequestExportSRAMFor: game)
                        } label: {
                            Label("Export Battery Save", systemImage: "memorychip")
                        }
                    }
                    #if !os(tvOS)
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestImportSRAMFor: game)
                    } label: {
                        Label("Import Battery Save", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestImportSaveFor: game)
                    } label: {
                        Label("Import Save Bundle", systemImage: "archivebox.fill")
                    }
                    #endif
                }
                // Show download option for games available in CloudKit but not downloaded locally
                if iCloudSyncEnabled && hasCloudRecord && !isDownloaded {
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestDownloadFromCloudFor: game)
                    } label: { Label("Download from Cloud", systemImage: "icloud.and.arrow.down") }
                }

                // Show offload option for games that are downloaded and have a CloudKit record
                if iCloudSyncEnabled && hasCloudRecord && isDownloaded {
                    Button {
                        offloadGameFromDevice(game)
                    } label: { Label("Offload from Device", systemImage: "icloud.and.arrow.up") }
                }

                Button {
                    // Toggle isFavorite for the selected PVGame
                    toggleFavorite()
                } label: { Label("Favorite", systemImage: "heart") }
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestRenameFor: game)
                } label: { Label("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") }
                #if !os(tvOS)
                Button {
                    promptUserMD5CopiedToClipboard(forGame: game)
                } label: { Label("Copy MD5 URL", systemImage: "number.square") }
                #endif

                if game.userPreferredCoreID != nil || game.system?.userPreferredCoreID != nil {
                    Button {
                        resetCorePreferences(forGame: game)
                    } label: { Label("Reset Core Preferences", systemImage: "arrow.counterclockwise") }
                }
                if featureFlags.netplayEnabled && availableCores.contains(where: { $0.principleClass.contains("RetroArch") }) {
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestNetworkPlayFor: game)
                    } label: { Label("Network Play", systemImage: "antenna.radiowaves.left.and.right") }
                }
                Divider()
    #if !os(tvOS)
                Button {
                    contextMenuDelegate?.gameContextMenu(self, didRequestSkinSelectionFor: game)
                } label: { Label("Controller Skin", systemImage: "gamecontroller") }
                if hasPerGameSkin(for: game) {
                    Button {
                        contextMenuDelegate?.gameContextMenu(self, didRequestResetSkinFor: game)
                    } label: { Label("Reset Game Skin", systemImage: "arrow.counterclockwise.circle") }
                }
                Button {
                    DLOG("GameContextMenu: Choose Cover button tapped")
                    contextMenuDelegate?.gameContextMenu(self, didRequestChooseArtworkSourceFor: game)
                } label: { Label("Choose Cover", systemImage: "book.closed") }
                Button {
                    pasteArtwork(forGame: game)
                } label: { Label("Paste Cover", systemImage: "doc.on.clipboard") }
    #else
                /// tvOS: skip the source alert and go directly to online artwork search
                Button {
                    DLOG("GameContextMenu: Choose Cover (tvOS) button tapped")
                    contextMenuDelegate?.gameContextMenu(self, didRequestShowArtworkSearchFor: game)
                } label: { Label("Search Artwork Online", systemImage: "photo.artframe") }
    #endif
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
        .task {
            // Compute hasBatterySaves on a background thread — Paths.batterySavesPath may
            // block on iCloud-backed storage and must not run on the main thread.
            guard !game.isInvalidated, let romURL = game.file?.url else { return }
            let result = await Task.detached(priority: .utility) {
                let dir = Paths.batterySavesPath(forROM: romURL)
                let fm = FileManager.default
                return fm.fileExists(atPath: dir.path)
                    && ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles))?.isEmpty == false)
            }.value
            hasBatterySaves = result
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
            try RomDatabase.sharedInstance.asyncWriteTransaction {
                if let thawedGame = game.thaw() {
                    thawedGame.isFavorite.toggle()
                }
            }
#if canImport(PVAppIntents)
            await MainActor.run {
                WidgetDataWriter.shared.writeFromRealm()
            }
#endif
        }
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        Task {
            do {
                let uniqueID = UUID().uuidString
                let md5: String = game.md5Hash ?? ""
                let key = "artwork_\(md5)_\(uniqueID)"

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
    /// Offload the game's primary ROM file from the device while keeping CloudKit record and metadata
    private func offloadGameFromDevice(_ game: PVGame) {
        Task {
            guard !game.isInvalidated else { return }
            let fileURL = game.file?.url

            do {
                if let url = fileURL, FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }

                // Update Realm to mark as not downloaded and clear PVFile reference
                try await RomDatabase.sharedInstance.asyncWriteTransaction {
                    if let thawed = game.thaw() {
                        thawed.isDownloaded = false
                        thawed.file = nil
                    }
                }

                await MainActor.run {
                    // Update local state so the menu reflects the new status if reopened
                    self.isDownloaded = false
                    rootDelegate?.showMessage("Offloaded \(game.title) from this device. You can re-download it from Cloud later.", title: "Offloaded")
                }
            } catch {
                await MainActor.run {
                    rootDelegate?.showMessage("Failed to offload \(game.title): \(error.localizedDescription)", title: "Error")
                }
            }
        }
    }
    /// Download a game from CloudKit with progress tracking UI
    public func downloadGameFromCloud() {
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
                        throw NSError(domain: "GameContextMenu", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CloudKit syncer available"])
                    }

                    await MainActor.run {
                        syncStatusManager.update(statusMessage: "Starting download...")
                    }

                    let fileURL = try await syncer.downloadFileOnDemand(recordName: recordID)
                    DLOG("Downloaded file to: \(fileURL.path)")

                    try await updateGameDownloadStatus(recordID: recordID, isDownloaded: true)

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

    func promptUserMD5CopiedToClipboard(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
        // Get the MD5 of the game
        let md5 = game.md5Hash
        // Copy to pasteboard
#if !os(tvOS)
        UIPasteboard.general.string = "provenance://open?md5=\(md5)"
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

        let gameTitle = game.title
        let md5 = game.md5Hash
        let oldArtworkKey = game.customArtworkURL

        guard !md5.isEmpty else {
            ELOG("GameContextMenu: Cannot clear artwork - game has no MD5 hash")
            return
        }

        DLOG("GameContextMenu: Attempting to clear custom artwork for game: \(gameTitle)")

        do {
            /// Use MD5-based lookup to get a live managed object
            /// This avoids issues with thaw() returning nil for frozen objects
            try RomDatabase.sharedInstance.writeTransaction {
                guard let liveGame = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: md5) else {
                    ELOG("Could not find game with MD5: \(md5) to clear artwork")
                    return
                }
                liveGame.customArtworkURL = ""
                DLOG("Game's customArtworkURL cleared")
            }

            DLOG("Successfully cleared custom artwork for game: \(gameTitle)")
            rootDelegate?.showMessage("Custom artwork has been cleared for \(gameTitle).", title: "Artwork Cleared")

            /// Delete the cached image using the OLD artwork key (captured before transaction)
            if !oldArtworkKey.isEmpty {
                try PVMediaCache.deleteImage(forKey: oldArtworkKey)
                DLOG("Successfully deleted cached artwork for key: \(oldArtworkKey)")
            }
        } catch {
            DLOG("Failed to clear custom artwork: \(error.localizedDescription)")
            rootDelegate?.showMessage("Failed to clear custom artwork for \(gameTitle): \(error.localizedDescription)", title: "Error")
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

    /// Check if game has a per-game skin preference set
    private func hasPerGameSkin(for game: PVGame) -> Bool {
        guard !game.isInvalidated,
              let systemId = game.system?.enumValue else { return false }

        let skinManager = DeltaSkinManager.shared
        #if !os(tvOS)
        let orientation: SkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        #else
        let orientation: SkinOrientation = .landscape
        #endif

        return skinManager.sessionSkinIdentifier(for: systemId, gameId: game.id, orientation: orientation) != nil ||
               DeltaSkinPreferences.shared.effectiveSkinIdentifier(for: game.id, system: systemId, orientation: orientation) != nil
    }
}
