//
//  GameLaunchingViewController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import Foundation
import PVSupport
import RealmSwift
import PVLibrary
import PVPrimitives
import RxSwift
import RxRealm
import PVPlists
import PVRealm
import PVSystems
import PVFileSystem
import PVUIBase
import SwiftUI
import Defaults
import PVSettings
#if canImport(FreemiumKit)
import FreemiumKit
#endif

private let WIKI_BIOS_URL = "https://wiki.provenance-emu.com/installation-and-usage/bios-requirements"

/// Helper class to hold mutable state for the unified launch flow
private final class LaunchFlowState: @unchecked Sendable {
    var hasResumed = false
    var continuation: CheckedContinuation<GameLaunchDecision?, Never>?
    weak var hostingVC: UIHostingController<RetroAlertNavigationStackHostingView>?
}

/*
 Protocol with default implimentation.

 This allows any UIViewController class to just inherit GameLaunchingViewController, and then it can call load(PVGame)!

 */

public protocol GameLaunchingViewController {
    func canLoad(_ game: PVGame) async throws
    func load(_ game: PVGame,
              sender: Any?,
              core: PVCore?,
              saveState: PVSaveState?) async
    func openSaveState(_ saveState: PVSaveState) async
    func updateRecentGames(_ game: PVGame)
    func presentCoreSelection(forGame game:
                              PVGame, sender: Any?)

    func displayAndLogError(withTitle title: String,
                            message: String,
                            customActions: [UIAlertAction]?)
}

/// The result of the unified launch flow for game launching
public enum GameLaunchDecision {
    case startFresh(core: PVCore)
    case loadSave(save: PVSaveState, core: PVCore)
    case cancelled
}

public extension GameLaunchingViewController {

    //MARK: Default protocol implementation `GameLaunchingViewController`
    @MainActor
    func canLoad(_ game: PVGame) async throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try await biosCheck(system: system)
    }

    @MainActor func openSaveState(withID objectId: String) async {
        let realm = RomDatabase.sharedInstance
        if let object = realm.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: objectId) {
            @ThreadSafe var threadObject = object
            await openSaveState(threadObject!)
        }
    }

    @MainActor
    private func biosCheck(system: PVSystem) async throws {
        guard system.requiresBIOS else {
            // Nothing to do
            return
        }

        // Check if requires a BIOS and has them all - only warns if md5's mismatch
        let biosEntries = system.bioses
        guard !biosEntries.isEmpty else {
            ELOG("System \(system.name) specifies it requires BIOS files but does not provide values for \(SystemDictionaryKeys.BIOSEntries)")
            throw GameLaunchingError.generic("Invalid configuration for system \(system.name). Missing BIOS dictionary in systems.plist")
        }

        let biosPathContents: [String]
        do {
            biosPathContents = try FileManager.default.contentsOfDirectory(at: system.biosDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]).compactMap { $0.isFileURL ? $0.lastPathComponent : nil }
        } catch {
            try? FileManager.default.createDirectory(at: system.biosDirectory, withIntermediateDirectories: true, attributes: nil)
            let biosFiles = await biosEntries.toArray().asyncMap {
                return self.getExpectedFilename($0.asDomain())
            }.joined(separator: ", ")

            let documentsPath = URL.documentsPath.path
            let biosDirectory = system.biosDirectory.path.replacingOccurrences(of: documentsPath, with: "")

            let message = "This system requires BIOS files. Please upload '\(biosFiles)' to \(biosDirectory)."
            ELOG(message)
            throw GameLaunchingError.generic(message)
        }

        // Store the HASH : FILENAME of the BIOS directory contents
        // Only generated if needed for matching if filename fails
        var biosPathContentsMD5Cache: [String: String]?

        var missingBIOSES = [String]()
        var entries = await biosEntries.toArray().asyncMap({ $0.asDomain() })
        // Search for additional conditional bios requirements stored as JSON file
        // TODO: This should be moved to PVLibrary
        if FileManager.default.fileExists(atPath: system.biosDirectory.appendingPathComponent("requirements.json").path) {
            let additionalBios = try LibrarySerializer.retrieve(system.biosDirectory.appendingPathComponent("requirements.json"), as: [String:[String:Int]].self)
            await additionalBios.keys.concurrentForEach({
                file in
                if let biosInfo = additionalBios[file],
                   let md5 = biosInfo.keys.first,
                   let size = biosInfo[md5] {
                    let newBIOS = PVBIOS(withSystem: system, descriptionText: file, expectedMD5: md5, expectedSize: size, expectedFilename: file)
                    newBIOS.optional = false

                    let database = RomDatabase.sharedInstance
                    /// Add the bios to the database
                    /// Skip if Realm is in write transaction (e.g., GameImporter is importing) to avoid blocking
                    if database.realm.isInWriteTransaction {
                        // If GameImporter is holding a write transaction, skip adding BIOS now
                        // It will be added on next launch or when import completes
                        VLOG("Skipping BIOS database add - Realm is in write transaction (likely GameImporter is active)")
                    } else {
                        RomDatabase.refresh()
                        //avoids conflicts if two BIOS share the same name - looking at you jagboot.rom
                        do {
                            try database.add(newBIOS, update: true)
                        } catch {
                            ELOG("Failed to add BIOS: \(error)")
                        }
                    }

                    entries.append(newBIOS.asDomain())
                }
            })
        }

        // Go through each BIOSEntry struct and see if all non-optional BIOS's were found in the BIOS dir
        // Try to match MD5s for files that don't match by name, and rename them to what's expected if found
        // Warn on files that have filename match but MD5 doesn't match expected
        var canLoad = true
        await entries.asyncForEach { currentEntry in
            let expectedFilename = self.getExpectedFilename(currentEntry)
            // Check for a direct filename match and that it isn't an optional BIOS if we don't find it
            if !biosPathContents.contains(expectedFilename), !currentEntry.optional {
                // Didn't match by files name, now we generate all the md5's and see if any match, if they do, move the matching file to the correct filename

                // 1 - Lazily generate the hashes of files in the BIOS directory (async to avoid blocking main thread)
                if biosPathContentsMD5Cache == nil {
                    // Calculate MD5s in parallel on background thread to avoid blocking main thread
                    // This is especially important when GameImporter is actively importing
                    biosPathContentsMD5Cache = await withTaskGroup(of: (String, String?).self, returning: [String: String].self) { group in
                        var hashDictionary: [String: String] = [:]

                        for filename in biosPathContents {
                            group.addTask {
                                let fullBIOSFileURL = system.biosDirectory.appendingPathComponent(filename, isDirectory: false)

                                // Download file if needed (async)
                                do {
                                    try await downloadFileIfNeeded(fullBIOSFileURL)
                                } catch {
                                    // Continue even if download fails
                                }

                                // Calculate MD5 on background thread to avoid blocking
                                let hash = await Task.detached(priority: .userInitiated) {
                                    FileManager.default.md5ForFile(at: fullBIOSFileURL, fromOffset: 0)
                                }.value

                                if let hash = hash, !hash.isEmpty {
                                    return (hash.uppercased(), filename)
                                } else {
                                    return ("", nil)
                                }
                            }
                        }

                        // Collect results
                        for await (hash, filename) in group {
                            if let filename = filename, !hash.isEmpty {
                                hashDictionary[hash] = filename
                            }
                        }

                        return hashDictionary
                    }
                }

                // 2 - See if any hashes in the BIOS directory match the current BIOS entry we're investigating.
                if let biosPathContentsMD5Cache = biosPathContentsMD5Cache, let filenameOfFoundFile = biosPathContentsMD5Cache[currentEntry.expectedMD5.uppercased()] {
                    // Rename the file to what we expected
                    do {
                        let from = system.biosDirectory.appendingPathComponent(filenameOfFoundFile, isDirectory: false)
                        let to = system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
                        try FileManager.default.moveItem(at: from, to: to)
                        // Succesfully move the file, mark this BIOSEntry as true in the .all{} loop
                        ILOG("Rename file \(filenameOfFoundFile) to \(expectedFilename) because it matched by MD5 \(currentEntry.expectedMD5.uppercased())")
                    } catch {
                        ELOG("Failed to rename \(filenameOfFoundFile) to \(expectedFilename)\n\(error.localizedDescription)")
                        // Since we couldn't rename, mark this as a false
                        missingBIOSES.append("\(expectedFilename) (MD5: \(currentEntry.expectedMD5))")
                        canLoad = false
                    }
                } else {
                    // No MD5 matches - try to download from CloudKit on-demand
                    let downloaded = await tryDownloadBIOSFromCloud(filename: expectedFilename, md5: currentEntry.expectedMD5, system: system)
                    if !downloaded {
                        missingBIOSES.append("\(expectedFilename) (MD5: \(currentEntry.expectedMD5))")
                        canLoad = false
                    } else {
                        ILOG("Successfully downloaded BIOS from CloudKit: \(expectedFilename)")
                    }
                }
            } else {
                // Not as important, but log if MD5 is mismatched.
                // Cores care about filenames for some reason, not MD5s
                let url = system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
                Task.detached(priority: .low) {
                    let fileMD5 = FileManager.default.md5ForFile(at: url, fromOffset: 0) ?? ""
                    let expectedMD5 = currentEntry.expectedMD5.lowercased()
                    if fileMD5 != expectedMD5 {
                        WLOG("MD5 hash for \(expectedFilename) didn't match the expected value.\nGot {\(fileMD5)} expected {\(expectedMD5)}")
                    }
                }
            }
        } // End canLoad .all loop

        if !canLoad {
            throw GameLaunchingError.missingBIOSes(missingBIOSES)
        }
    }

    /// Attempt to download a missing BIOS file from CloudKit
    /// - Parameters:
    ///   - filename: The expected BIOS filename
    ///   - md5: The expected MD5 hash
    ///   - system: The system requiring the BIOS
    /// - Returns: True if the BIOS was successfully downloaded
    @MainActor
    private func tryDownloadBIOSFromCloud(filename: String, md5: String, system: PVSystem) async -> Bool {
        ILOG("[BIOS ON-DEMAND] Checking CloudKit for missing BIOS: \(filename)")

        // Check if we have a PVBIOS entry with a cloudRecordID
        let realm = RomDatabase.sharedInstance.realm
        let biosEntry = realm.objects(PVBIOS.self).filter("expectedFilename == %@ OR expectedMD5 ==[c] %@", filename, md5).first

        guard let bios = biosEntry else {
            DLOG("[BIOS ON-DEMAND] No PVBIOS entry found for: \(filename)")
            return false
        }

        // If no cloudRecordID, try to sync metadata first
        if bios.cloudRecordID == nil || bios.cloudRecordID?.isEmpty == true {
            ILOG("[BIOS ON-DEMAND] No cloudRecordID, triggering metadata sync for: \(filename)")
            await CloudSyncManager.shared.forceBIOSDownload()

            // Re-check after sync
            RomDatabase.refresh()
            guard let updatedBios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first,
                  let recordID = updatedBios.cloudRecordID, !recordID.isEmpty else {
                WLOG("[BIOS ON-DEMAND] Still no cloudRecordID after sync for: \(filename)")
                return false
            }
        }

        // Re-fetch the BIOS entry to get updated cloudRecordID
        guard let updatedBios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first,
              let recordID = updatedBios.cloudRecordID, !recordID.isEmpty else {
            return false
        }

        ILOG("[BIOS ON-DEMAND] Found cloudRecordID: \(recordID), downloading: \(filename)")

        // Download the BIOS file
        do {
            // Use CloudSyncManager's forceBIOSDownload which handles the download
            await CloudSyncManager.shared.forceBIOSDownload()

            // Verify the file now exists
            let biosPath = system.biosDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: biosPath.path) {
                ILOG("[BIOS ON-DEMAND] ✓ Successfully downloaded BIOS: \(filename)")
                return true
            } else {
                WLOG("[BIOS ON-DEMAND] Download completed but file not found at: \(biosPath.path)")
                return false
            }
        }
    }

    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.sharedInstance
        RomDatabase.refresh()

        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)

        let recentsMatchingGame = database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
        let recentToDelete = recentsMatchingGame.first
        if let recentToDelete = recentToDelete {
            do {
                try database.delete(recentToDelete)
            } catch {
                ELOG("Failed to delete recent: \(error.localizedDescription)")
            }
        }

        if recents.count >= PVMaxRecentsCount() {
            // TODO: This should delete more than just the last incase we had an overflow earlier
            if let oldestRecent: PVRecentGame = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false).last {
                do {
                    try database.delete(oldestRecent)
                } catch {
                    ELOG("Failed to delete recent: \(error.localizedDescription)")
                }
            }
        }

        if let currentRecent = game.recentPlays.first {
            do {
                currentRecent.lastPlayedDate = Date()
                try database.add(currentRecent, update: true)
            } catch {
                ELOG("Failed to update Recent Game entry. \(error.localizedDescription)")
            }
        } else {
            // TODO: Add PVCore
            let newRecent = PVRecentGame(withGame: game)
            do {
                try database.add(newRecent, update: false)

                let responder = self as? UIResponder ?? UIApplication.shared
                let activity = game.spotlightActivity
                // Make active, causes it to index also
                responder.userActivity = activity
            } catch {
                ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
            }
        }
    }

    func doLoad(_ game: PVGame) async throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try await biosCheck(system: system)
    }

    // MARK: - Private
    private func getExpectedFilename(_ bios:BIOS) -> String {
        var expectedFilename=bios.expectedFilename
        if expectedFilename.contains("|") {
            expectedFilename=expectedFilename.components(separatedBy: "|")[0]
        }
        return expectedFilename
    }

    /// Validates pre-download requirements and prompts user if there are issues
    /// - Parameters:
    ///   - game: The game to validate
    ///   - system: The system the game belongs to
    /// - Returns: True if user wants to continue, false if cancelled
    @MainActor
    func validateAndPromptPreDownload(game: PVGame, system: PVSystem) async -> Bool {
        // Check for available cores
        let unsupportedCores = Defaults[.unsupportedCores]
        let availableCores = system.cores.filter {
            (!$0.disabled || unsupportedCores) &&
            $0.hasCoreClass &&
            !(AppState.shared.isAppStore && $0.appStoreDisabled && !unsupportedCores)
        }
        let hasAvailableCores = !availableCores.isEmpty

        // Check for missing BIOS files
        var missingBIOSFiles: [String] = []

        if system.requiresBIOS {
            let biosEntries = Array(system.bioses)
            let biosDirectory = system.biosDirectory

            // Get existing BIOS files
            var existingFiles: Set<String>
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: biosDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                existingFiles = Set(contents.map { $0.lastPathComponent.lowercased() })
            } else {
                existingFiles = []
            }

            // Check each required BIOS and try to download missing ones from CloudKit
            for bios in biosEntries {
                if bios.optional { continue }

                var expectedFilename = bios.expectedFilename
                if expectedFilename.contains("|") {
                    expectedFilename = expectedFilename.components(separatedBy: "|")[0]
                }

                if !existingFiles.contains(expectedFilename.lowercased()) {
                    // BIOS not found locally - attempt CloudKit download if sync is enabled
                    if Defaults[.iCloudSync] {
                        // Update status via SceneCoordinator
                        SceneCoordinator.shared.syncStatusManager.update(statusMessage: "Downloading BIOS: \(expectedFilename)...")

                        ILOG("[BIOS ON-DEMAND] Missing BIOS \(expectedFilename), attempting CloudKit download...")
                        let downloaded = await SceneCoordinator.shared.tryDownloadBIOSFromCloud(
                            filename: expectedFilename,
                            expectedMD5: bios.expectedMD5,
                            system: system
                        )

                        if downloaded {
                            ILOG("[BIOS ON-DEMAND] ✓ Successfully downloaded BIOS from CloudKit: \(expectedFilename)")
                            existingFiles.insert(expectedFilename.lowercased())
                        } else {
                            WLOG("[BIOS ON-DEMAND] CloudKit download failed for BIOS: \(expectedFilename)")
                            missingBIOSFiles.append(expectedFilename)
                        }
                    } else {
                        // CloudKit sync disabled - mark as missing
                        missingBIOSFiles.append(expectedFilename)
                    }
                }
            }
        }

        // If everything is fine, proceed without prompt
        if hasAvailableCores && missingBIOSFiles.isEmpty {
            return true
        }

        // Build warning message
        var warningParts: [String] = []

        if !hasAvailableCores {
            warningParts.append("• No compatible emulator cores are available for \(system.name)")
        }

        if !missingBIOSFiles.isEmpty {
            let biosFiles = missingBIOSFiles.prefix(3).joined(separator: ", ")
            let moreCount = missingBIOSFiles.count - 3
            if moreCount > 0 {
                warningParts.append("• Missing BIOS files: \(biosFiles) and \(moreCount) more")
            } else {
                warningParts.append("• Missing BIOS files: \(biosFiles)")
            }
        }

        let warningMessage = warningParts.joined(separator: "\n\n")

        // Show warning using RetroWave alert and wait for user response
        // Use a flag to ensure continuation is only resumed once
        var hasResumed = false

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                var title = "Download Warning"
                var message = "This game may not be playable after downloading:\n\n\(warningMessage)\n\nDo you want to download anyway?"

                if !hasAvailableCores {
                    let supportLevel = system.coreSupportLevel(isAppStore: AppState.shared.isAppStore)
                    title = "No Compatible Core"
                    switch supportLevel {
                    case .appStoreRestricted:
                        message = "\(system.name) cores are not available in the App Store build.\n\n"
                        message += "To play \(system.name) games you need a sideloaded build or JIT access (e.g. via AltStore, SideStore, or a developer certificate).\n\n"
                        message += "Download this ROM anyway? You can use it once you have a supported build."
                    case .disabled:
                        message = "No stable emulator core is available for \(system.name). "
                        message += "Support is experimental or not yet implemented.\n\n"
                        message += "Enable 'Unsupported Cores' in Settings → Advanced to try experimental cores.\n\n"
                        message += "Download this ROM anyway?"
                    case .noCores:
                        message = "No emulator core is registered for \(system.name). "
                        message += "ROMs can be stored in your library but cannot be played in this version.\n\n"
                        message += "Download this ROM anyway?"
                    case .fullySupported:
                        // Shouldn't reach here, but provide a fallback message
                        message = "There are no compatible emulator cores available for \(system.name).\n\n"
                        message += "Download this ROM anyway? You won't be able to play it until a compatible core is available."
                    }
                } else if !missingBIOSFiles.isEmpty {
                    title = "Missing BIOS Files"
                    message = "\(system.name) requires BIOS files to run games.\n\n\(warningMessage)\n\nDownload this ROM anyway? You'll need to add the BIOS files before playing."
                }

                SceneCoordinator.shared.alertState.show(
                    title: title,
                    message: message,
                    type: .warning,
                    primaryButtonTitle: "Download Anyway",
                    primaryAction: {
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(returning: true)
                    },
                    secondaryButtonTitle: "Cancel",
                    secondaryAction: {
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(returning: false)
                    },
                    onDismiss: {
                        // Handle case where alert is dismissed via Menu button on tvOS
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                )
            }
        }
    }

    /// Presents a core selection alert with save state counts for each core
    /// - Parameters:
    ///   - game: The game to select a core for
    ///   - cores: Available cores for the game's system
    /// - Returns: The selected core, or nil if cancelled
    @MainActor
    func selectCoreWithSaveCounts(game: PVGame, cores: [PVCore]) async -> PVCore? {
        let items = cores.map { core in
            let saveCount = game.saveStates.filter("core.identifier == %@", core.identifier).count
            let subtitle = formatSaveCountSubtitle(saveCount)
            return RetroSelectionItem(id: core.identifier, title: core.projectName, subtitle: subtitle)
        }

        var hasResumed = false

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Capture hostingVC so callbacks can dismiss it
                var hostingVC: UIHostingController<CoreSelectionAlertHostingView>?

                let selectionView = CoreSelectionAlertHostingView(
                    title: "Select Core",
                    message: "Choose a core to run \(game.title)",
                    items: items,
                    onSelect: { selectedId in
                        guard !hasResumed else { return }
                        hasResumed = true
                        let selectedCore = cores.first { $0.identifier == selectedId }
                        // Dismiss first, then resume continuation in completion
                        hostingVC?.dismiss(animated: true) {
                            continuation.resume(returning: selectedCore)
                        }
                    },
                    onCancel: {
                        guard !hasResumed else { return }
                        hasResumed = true
                        // Dismiss first, then resume continuation in completion
                        hostingVC?.dismiss(animated: true) {
                            continuation.resume(returning: nil)
                        }
                    }
                )

                hostingVC = UIHostingController(rootView: selectionView)
                hostingVC?.modalPresentationStyle = .overFullScreen
                hostingVC?.modalTransitionStyle = .crossDissolve
                hostingVC?.view.backgroundColor = .clear

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var topVC = rootVC
                    while let presented = topVC.presentedViewController {
                        topVC = presented
                    }
                    if let vc = hostingVC {
                        topVC.present(vc, animated: true)
                    }
                }
            }
        }
    }

    private func formatSaveCountSubtitle(_ count: Int) -> String {
        switch count {
        case 0: return "No saves"
        case 1: return "1 save"
        default: return "\(count) saves"
        }
    }

    // MARK: - Unified Launch Flow

    /// Presents a unified flow for core and save state selection using the RetroAlertNavigationStack
    /// - Parameters:
    ///   - game: The game to launch
    ///   - cores: Available cores for the game's system
    ///   - existingStack: Optional existing navigation stack to use
    ///   - preselectedCore: Optional core that was already selected (skips core selection if provided)
    /// - Returns: GameLaunchDecision indicating how to proceed, or nil if cancelled
    @MainActor
    func launchWithUnifiedFlow(game: PVGame, cores: [PVCore], existingStack: RetroAlertNavigationStack? = nil, preselectedCore: PVCore? = nil) async -> GameLaunchDecision? {
        let stack = existingStack ?? RetroAlertNavigationStack()

        // Determine if we need core selection
        let needsCoreSelection = cores.count > 1
        var selectedCore: PVCore?

        // If a core was preselected (e.g., from previous core selection dialog), use it
        if let preselectedCore = preselectedCore, cores.contains(preselectedCore) {
            selectedCore = preselectedCore
        } else if let userSelection = game.userPreferredCoreID ?? game.system?.userPreferredCoreID,
           let preferredCore = cores.first(where: { $0.identifier == userSelection }) {
            // Check for user's preferred core
            selectedCore = preferredCore
        } else if needsCoreSelection {
            selectedCore = nil
        } else {
            selectedCore = cores.first
        }

        let flowState = LaunchFlowState()

        return await withCheckedContinuation { continuation in
            flowState.continuation = continuation

            // Helper to resume once
            let resumeOnce: @MainActor (GameLaunchDecision?) -> Void = { decision in
                guard !flowState.hasResumed else { return }
                flowState.hasResumed = true
                flowState.continuation?.resume(returning: decision)
            }

            // Helper to get saves for a core
            // Note: saveStates already includes autoSaves (autoSaves is a filtered subset of saveStates)
            let getSavesForCore: (PVCore) -> [PVSaveState] = { core in
                game.saveStates.filter("core.identifier == %@", core.identifier)
                    .sorted(byKeyPath: "date", ascending: false)
                    .toArray()
            }

            // Helper to dismiss and resume with proper sequencing
            let dismissAndResume: @MainActor (GameLaunchDecision) -> Void = { decision in
                // First dismiss the hosting controller with a completion handler
                // Only resume the continuation after the dismiss animation completes
                if let hostingVC = flowState.hostingVC {
                    hostingVC.dismiss(animated: true) {
                        resumeOnce(decision)
                    }
                } else {
                    resumeOnce(decision)
                }
            }

            // Helper to create save selection view
            let createSaveSelectionView: @MainActor (PVCore, Bool) -> AnyView = { core, showBack in
                let allSaves = getSavesForCore(core)

                // Debug logging for save count verification
                let totalInRealm = game.saveStates.filter("core.identifier == %@", core.identifier).count
                DLOG("[LaunchFlow] Save count for \(core.projectName): Realm total=\(totalInRealm), getSavesForCore=\(allSaves.count)")

                if allSaves.isEmpty {
                    dismissAndResume(.startFresh(core: core))
                    return AnyView(EmptyView())
                }

                let saveItems = allSaves.map { RetroSaveSelectionItem(from: $0) }
                DLOG("[LaunchFlow] Created \(saveItems.count) RetroSaveSelectionItems for display")
                let viewModel = RetroSaveSelectionViewModel(
                    gameTitle: game.title,
                    coreName: core.projectName,
                    coreIdentifier: core.identifier,
                    saves: saveItems
                )

                return AnyView(RetroSaveSelectionAlertView(
                    viewModel: viewModel,
                    showBackButton: showBack,
                    onStartFresh: {
                        Task { @MainActor in
                            dismissAndResume(.startFresh(core: core))
                        }
                    },
                    onSelectSave: { selectedItem in
                        Task { @MainActor in
                            if let saveState = allSaves.first(where: { $0.id == selectedItem.saveStateId }) {
                                dismissAndResume(.loadSave(save: saveState, core: core))
                            } else {
                                dismissAndResume(.startFresh(core: core))
                            }
                        }
                    },
                    onBack: showBack ? {
                        Task { @MainActor in
                            stack.pop()
                        }
                    } : nil,
                    onCancel: {
                        Task { @MainActor in
                            dismissAndResume(.cancelled)
                        }
                    }
                ))
            }

            // Present on main actor
            Task { @MainActor in
                // If we have a selected core (no core selection needed), go straight to save selection
                if let selectedCore = selectedCore {
                    let saveView = createSaveSelectionView(selectedCore, false)
                    if !flowState.hasResumed {
                        stack.push(saveView, id: "save-selection-\(selectedCore.identifier)")
                    }
                } else {
                    // Show core selection first
                    let coreItems = cores.map { core in
                        // Note: saveStates already includes autoSaves
                        let saveCount = game.saveStates.filter("core.identifier == %@", core.identifier).count
                        DLOG("[LaunchFlow] Core selection: \(core.projectName) has \(saveCount) saves")
                        let subtitle = formatSaveCountSubtitle(saveCount)
                        return RetroSelectionItem(id: core.identifier, title: core.projectName, subtitle: subtitle)
                    }

                    let coreSelectionView = RetroSelectionAlertView(
                        title: "Select Core",
                        message: "Choose a core to run \(game.title)",
                        items: coreItems,
                        isPresented: .constant(true),
                        onSelect: { selectedId in
                            Task { @MainActor in
                                if let core = cores.first(where: { $0.identifier == selectedId }) {
                                    let saveView = createSaveSelectionView(core, true)
                                    if !flowState.hasResumed {
                                        stack.push(saveView, id: "save-selection-\(core.identifier)")
                                    }
                                }
                            }
                        },
                        onCancel: {
                            Task { @MainActor in
                                dismissAndResume(.cancelled)
                            }
                        }
                    )

                    stack.push(coreSelectionView, id: "core-selection")
                }

                /// If the flow already resolved (e.g. no saves => start fresh), do not present the hosting UI.
                /// Otherwise we can end up with an alert controller presented while trying to present the emulator VC.
                if flowState.hasResumed {
                    return
                }

                // Present the stack
                let hostingView = RetroAlertNavigationStackHostingView(stack: stack)
                let hostingVC = UIHostingController(rootView: hostingView)
                flowState.hostingVC = hostingVC
                hostingVC.modalPresentationStyle = .overFullScreen
                hostingVC.modalTransitionStyle = .crossDissolve
                hostingVC.view.backgroundColor = .clear

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var topVC = rootVC
                    while let presented = topVC.presentedViewController {
                        topVC = presented
                    }
                    topVC.present(hostingVC, animated: true)
                }

                // Set up dismiss handler
                stack.onDismiss = {
                    flowState.hostingVC?.dismiss(animated: true)
                }
            }
        }
    }

    /// Check if a ROM file exists locally at the expected path and update the database if found.
    /// This handles the race condition where CloudKit creates PVGame entries before local scanning completes.
    /// - Parameters:
    ///   - game: The game to check
    ///   - system: The system the game belongs to
    /// - Returns: Tuple indicating if file exists and if database was updated
    @MainActor
    func checkAndUpdateLocalFile(for game: PVGame, system: PVSystem) async -> (fileExists: Bool, updated: Bool) {
        // If already marked as downloaded and has a valid file, check if it actually exists
        if game.isDownloaded, let fileURL = game.file?.url {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return (fileExists: true, updated: false)
            }
        }

        // Calculate the expected path for this ROM
        let systemRomsPath = Paths.romsPath(forSystemIdentifier: system.identifier)

        // Try multiple filename sources
        let possibleFilenames: [String] = [
            game.file?.fileName,
            game.romPath.isEmpty ? nil : URL(fileURLWithPath: game.romPath).lastPathComponent,
            game.title.appending(".").appending(game.file?.url?.pathExtension ?? "")
        ].compactMap { $0 }.filter { !$0.isEmpty }

        // Helper to update game in database
        func updateGameWithFile(at fileURL: URL, relativePath: String) -> Bool {
            do {
                let realm = RomDatabase.sharedInstance.realm

                // Get live (thawed) game reference for modification
                let liveGame: PVGame?
                if game.isFrozen {
                    liveGame = game.thaw()
                } else if let gameFromRealm = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) {
                    liveGame = gameFromRealm
                } else {
                    liveGame = game
                }

                guard let gameToUpdate = liveGame else {
                    ELOG("[LOCAL FILE CHECK] Could not get live game reference for: \(game.title)")
                    return false
                }

                try realm.write {
                    // Create or update PVFile
                    if gameToUpdate.file == nil {
                        let pvFile = PVFile(withURL: fileURL)
                        gameToUpdate.file = pvFile
                    } else if let existingFile = gameToUpdate.file {
                        // Update the partial path if needed
                        if existingFile.partialPath != relativePath {
                            existingFile.partialPath = relativePath
                        }
                    }

                    // Mark as downloaded since we found the file locally
                    gameToUpdate.isDownloaded = true
                }
                return true
            } catch {
                ELOG("[LOCAL FILE CHECK] Failed to update database: \(error.localizedDescription)")
                return false
            }
        }

        for filename in possibleFilenames {
            let expectedPath = systemRomsPath.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: expectedPath.path) {
                ILOG("[LOCAL FILE CHECK] Found ROM at expected path: \(expectedPath.path) for game: \(game.title)")

                let relativePath = "\(system.identifier)/\(filename)"
                if updateGameWithFile(at: expectedPath, relativePath: relativePath) {
                    ILOG("[LOCAL FILE CHECK] Updated database for game: \(game.title), isDownloaded=true")
                    return (fileExists: true, updated: true)
                } else {
                    // File exists but database update failed - still return true for fileExists
                    return (fileExists: true, updated: false)
                }
            }
        }

        // Also check if the file might be in a subdirectory (multi-disc games)
        if let filename = possibleFilenames.first {
            // Check in system ROM directory recursively for the file
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(at: systemRomsPath, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.lowercased() == filename.lowercased() {
                        ILOG("[LOCAL FILE CHECK] Found ROM in subdirectory: \(fileURL.path) for game: \(game.title)")

                        // Calculate relative path from Documents
                        let documentsPath = URL.documentsPath.path
                        let relativePath = fileURL.path.replacingOccurrences(of: documentsPath + "/", with: "")

                        if updateGameWithFile(at: fileURL, relativePath: relativePath) {
                            ILOG("[LOCAL FILE CHECK] Updated database for game: \(game.title) from subdirectory")
                            return (fileExists: true, updated: true)
                        } else {
                            return (fileExists: true, updated: false)
                        }
                    }
                }
            }
        }

        DLOG("[LOCAL FILE CHECK] No local file found for game: \(game.title)")
        return (fileExists: false, updated: false)
    }
}

import Intents

public
extension GameLaunchingViewController where Self: UIViewController {


    func donateShortcut(forGame game: PVGame) {
        let activity = NSUserActivity(activityType: "com.provenance-emu.provenance.openMD5")
        activity.title = "Open \(game.title) in Provenance"
        activity.userInfo = ["url": "provenance://open?md5=\(game.md5Hash)"]
        activity.isEligibleForSearch = false
        activity.isEligibleForPublicIndexing = true
        activity.isEligibleForHandoff = true

        #if !os(tvOS)
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier("com.provenance-emu.provenance.openMD5")
        #endif

        Task { @MainActor in
            self.userActivity = activity
            self.userActivity?.becomeCurrent()
        }
    }

    @MainActor
    func load(_ game: PVGame, sender: Any? = nil, core: PVCore? = nil, saveState: PVSaveState? = nil) async {
        guard game.realm != nil else {
            return
        }

        ILOG("Loading game: \(game.title) at romPath: \(game.romPath), url: \(game.url?.absoluteString ?? "nil"), partialPath: \(game.file?.partialPath ?? "nil")")

        // Show retrowave-themed loading HUD
        let hud = RetroProgressHUD.show(in: self.view, animated: true)
        hud.setText("Loading \(game.title)...")

        defer {
            // Ensure HUD is hidden when function exits
            DispatchQueue.main.async {
                hud.hide(animated: true, afterDelay: 0.1)
            }
        }

        @ThreadSafe var game: PVGame! = game
        @ThreadSafe var core = core
        @ThreadSafe var saveState = saveState

        Task.detached { [weak self] in
            self?.donateShortcut(forGame: game)
        }

        guard !(presentedViewController is PVEmualatorControllerProtocol) else {
            let currentGameVC = presentedViewController as! PVEmualatorControllerProtocol
            displayAndLogError(withTitle: "Cannot open new game", message: "A game is already running the game \(currentGameVC.game.title).")
            return
        }

        if let localSaveState = saveState {
            guard let fileURL = localSaveState.file?.url else {
                displayAndLogError(
                    withTitle: "Cannot open save state",
                    message: "Save state file is missing. Please re-sync or re-create the save state.",
                    customActions: nil
                )
                saveState = nil
                return
            }
            ILOG("Opening with save state at path: \(fileURL.path)")
            do {
                try await downloadFileIfNeeded(fileURL)
            } catch {
                ELOG("Save state was not downloaded: \(error.localizedDescription)")
                saveState = nil
            }
        }

        // Pre-flight system check first
        guard let system = game.system else {
            displayAndLogError(withTitle: "Cannot open game", message: "Requested system cannot be found for game '\(game.title)'.")
            return
        }

        // Contentless games intentionally have no ROM file; bypass file checks/downloads.
        let isContentless = game.contentless

        // Check if file exists locally - handle race condition where CloudKit sync created PVGame before local scan
        let localFileCheckResult: (fileExists: Bool, updated: Bool)
        if isContentless {
            localFileCheckResult = (fileExists: true, updated: false)
        } else {
            let result = await checkAndUpdateLocalFile(for: game, system: system)
            if result.updated {
                ILOG("Found local file for game \(game.title) at expected path, updated database")
                // Refresh game reference after database update
                if let updatedGame = RomDatabase.sharedInstance.game(withMD5: game.md5Hash) {
                    game = updatedGame
                }
            }
            localFileCheckResult = result
        }

        // Now check if file is available (either local or needs download)
        let hasLocalFile = isContentless ? true : localFileCheckResult.fileExists
        let offline: Bool = isContentless ? false : (!(game.file?.online ?? true) && !hasLocalFile)
        let needsDownload = isContentless ? false : ((offline && !hasLocalFile) || (!hasLocalFile && game.file?.url != nil))

        // If download is needed, validate requirements BEFORE downloading
        if needsDownload {
            let shouldContinue = await validateAndPromptPreDownload(game: game, system: system)
            if !shouldContinue {
                ILOG("User cancelled download due to missing requirements for game: \(game.title)")
                return
            }
        }

        if offline && !hasLocalFile {
            do {
                try await downloadFileIfNeeded(game.file?.url)
            } catch {
                displayAndLogError(withTitle: "Cannot open game",
                                   message: "The ROM file for this game cannot be found. Try re-importing the file for this game.\n\(game.file?.fileName ?? "null")")
                return
            }
        }

        do {
            // Only try to download if file doesn't exist locally
            if !hasLocalFile, let url = game.file?.url {
                try await downloadFileIfNeeded(url)
            }

            try await canLoad(game)
            VLOG("canLoad \(game.title)")
            // Init emulator VC

            guard let system = game.system else {
                displayAndLogError(withTitle: "Cannot open game", message: "No system found matching '\(game.systemIdentifier)'.")
                return
            }

            VLOG("\(game.title) matched system \(system.name)\n Cores: \(system.cores.map{$0.principleClass}.joined(separator: ", "))")

            // Are unsupported cores enabled
            let unsupportedCores = Defaults[.unsupportedCores]

            let cores: [PVCore] = system.cores.filter {
                (!$0.disabled || unsupportedCores) && $0.hasCoreClass && !(AppState.shared.isAppStore && $0.appStoreDisabled && !unsupportedCores)
            }.sorted { a, b in
                // If one has "retroarch" and the other doesn't, non-retroarch comes first
                let aHasRetroarch = a.projectName.localizedCaseInsensitiveContains("retroarch")
                let bHasRetroarch = b.projectName.localizedCaseInsensitiveContains("retroarch")

                if aHasRetroarch != bHasRetroarch {
                    return !aHasRetroarch // non-retroarch comes first
                }

                // Within each group, sort alphabetically
                return a.projectName < b.projectName
            }

            guard !cores.isEmpty else {
                displayAndLogError(withTitle: "Cannot open game", message: "No core found for game system '\(system.shortName)'.")
                return
            }

            var selectedCore: PVCore?
            var selectedSaveState: PVSaveState? = saveState
            var skipLegacySaveStatePrompt = false

            // If a save state is passed in and its core is valid, use it directly
            if let saveState = saveState {
                if let saveStateCore = saveState.core, cores.contains(saveStateCore) {
                    selectedCore = saveStateCore
                    ILOG("Using save state's core: \(saveStateCore.projectName)")
                } else {
                    WLOG("Save state core missing or not available. Falling back to selection flow.")
                    selectedSaveState = nil
                }
            }

            // If a core is passed in and it's valid, use it
            if selectedCore == nil, let core = core, cores.contains(core) {
                selectedCore = core
                ILOG("Using passed-in core: \(core.projectName)")
            }

            // If no save state passed in or no core determined, use the unified flow
            // The unified flow handles both core selection AND save state selection
            if selectedCore == nil || (selectedSaveState == nil && !Defaults[.autoLoadSaves]) {
                // Check if user preference allows skipping the UI
                let shouldAskToLoadSave = Defaults[.askToAutoLoad]
                let shouldAutoLoadSave = Defaults[.autoLoadSaves]

                // If auto-load is enabled and we have a core, skip the unified flow
                if shouldAutoLoadSave, let core = selectedCore ?? cores.first {
                    selectedCore = core
                    // The save will be handled by presentEMU's checkForSaveStateThenRun
                } else if shouldAskToLoadSave || selectedCore == nil {
                    // Use unified flow for core + save selection
                    ILOG("Starting unified launch flow for \(game.title)")
                    let decision = await launchWithUnifiedFlow(game: game, cores: cores, preselectedCore: selectedCore)

                    switch decision {
                    case .startFresh(let core):
                        selectedCore = core
                        selectedSaveState = nil
                        skipLegacySaveStatePrompt = true
                        ILOG("Unified flow: Starting fresh with \(core.projectName)")

                    case .loadSave(let save, let core):
                        selectedCore = core
                        selectedSaveState = save
                        skipLegacySaveStatePrompt = false
                        ILOG("Unified flow: Loading save from \(core.projectName)")

                    case .cancelled, .none:
                        ILOG("Unified flow: User cancelled, returning to main scene")
                        AppState.shared.emulationUIState.reset()
                        SceneCoordinator.shared.closeEmulator()
                        return
                    }
                }
            }

            guard let selectedCore = selectedCore ?? cores.first else {
                displayAndLogError(withTitle: "Cannot open game", message: "No core found.")
                return
            }

            let presentingView = self.view

            // If we got a save state from unified flow, pass it directly
            // Otherwise let presentEMU handle save state detection
            if selectedSaveState != nil {
                await presentEMU(withCore: selectedCore, forGame: game, fromSaveState: selectedSaveState, source: sender as? UIView ?? presentingView)
            } else {
                await presentEMU(
                    withCore: selectedCore,
                    forGame: game,
                    fromSaveState: nil,
                    source: sender as? UIView ?? presentingView,
                    skipSaveStatePrompt: skipLegacySaveStatePrompt
                )
            }
        } catch let GameLaunchingError.missingBIOSes(missingBIOSes) {
            // Create missing BIOS directory to help user out
            PVEmulatorConfiguration.createBIOSDirectory(forSystemIdentifier: system.enumValue)

            let missingFilesString = missingBIOSes.joined(separator: "\n")
            // Use platform-aware path (Documents on iOS, Caches on tvOS)
            let rootDirName = RelativeRoot.platformDefault == .caches ? "Caches" : "Documents"
            let relativeBiosPath = "\(rootDirName)/BIOS/\(system.identifier)/"

            let message = "\(system.shortName) requires BIOS files to run games. Ensure the following files are inside \(relativeBiosPath)\n\(missingFilesString)"
#if os(iOS)
            let guideAction = UIAlertAction(title: "Guide", style: .default, handler: { _ in
                Task {@MainActor in
                    UIApplication.shared.open(URL(string: WIKI_BIOS_URL)!, options: [:], completionHandler: nil)
                }
            })
            let cancelAction =  UIAlertAction(title: "Close", style: .destructive)
            displayAndLogError(withTitle: "Missing BIOS files", message: message, customActions: [guideAction, cancelAction])
#else
            let cancelAction =  UIAlertAction(title: "Close", style: .destructive)
            displayAndLogError(withTitle: "Missing BIOS files", message: message, customActions: [cancelAction])
#endif
        } catch GameLaunchingError.systemNotFound {
            displayAndLogError(withTitle: "Core not found", message: "No Core was found to run system '\(system.name)'.")
        } catch let GameLaunchingError.generic(message) {
            displayAndLogError(withTitle: "Cannot open game", message: message)
        } catch {
            displayAndLogError(withTitle: "Cannot open game", message: "Unknown error: \(error.localizedDescription)")
        }
    }

    @MainActor
    func openSaveState(_ saveState: PVSaveState) async {

        if let gameVC = presentedViewController as? PVEmualatorControllerProtocol {
            //            try? RomDatabase.sharedInstance.writeTransaction {
            try? saveState.realm!.write {
                saveState.lastOpened = Date()
            }

            gameVC.core.setPauseEmulation(true)

            do {
                if let path = saveState.file?.url?.path {
                    try await gameVC.core.loadState(fromFileAtPath: path)
                }
                gameVC.core.setPauseEmulation(false)
            } catch {
                let description = error.localizedDescription
                let reason = (error as NSError).localizedFailureReason

                let msg = "Failed to load save state: \(description) \(reason ?? "")"
                self.presentError(msg, source: self.view) {
                    gameVC.core.setPauseEmulation(false)
                }
            }
        } else {
            presentWarning("No core loaded", source: self.view)
        }
    }

    @MainActor
    func presentCoreSelection(forGame game: PVGame, sender: Any?) {
        guard let system = game.system else {
            ELOG("No system for game \(game.title)")
            return
        }

        // Are unsupported cores enabled
        let unsupportedCores = Defaults[.unsupportedCores]

        let cores: [PVCore] = system.cores.filter {
            (!$0.disabled || unsupportedCores) && $0.hasCoreClass && !(AppState.shared.isAppStore && $0.appStoreDisabled && !unsupportedCores)
        }.sorted(by: { core1, core2 in
            let core1IsRetroArch = core1.projectName.localizedCaseInsensitiveContains("retroarch")
            let core2IsRetroArch = core2.projectName.localizedCaseInsensitiveContains("retroarch")

            // If both are RetroArch or both are not RetroArch, sort alphabetically
            if core1IsRetroArch == core2IsRetroArch {
                return core1.projectName.localizedCaseInsensitiveCompare(core2.projectName) == .orderedAscending
            }

            // If one is RetroArch and one isn't, non-RetroArch comes first
            return !core1IsRetroArch
        })

        let coreChoiceAlert = UIAlertController(title: "Multiple cores found",
                                                message: "Select which core to use with this game.",
                                                preferredStyle: .actionSheet)
#if os(macOS) || targetEnvironment(macCatalyst)
        if let senderView = sender as? UIView ?? self.view {
            coreChoiceAlert.popoverPresentationController?.sourceView = senderView
            coreChoiceAlert.popoverPresentationController?.sourceRect = senderView.bounds
        } else {
            ELOG("Nil senderView")
            assertionFailure("Nil senderview")
        }
#else
        if traitCollection.userInterfaceIdiom == .pad, let senderView = sender as? UIView ?? self.view {
            coreChoiceAlert.popoverPresentationController?.sourceView = senderView
            coreChoiceAlert.popoverPresentationController?.sourceRect = senderView.bounds
        }
#endif

        for core in cores {
            let action = UIAlertAction(title: core.projectName, style: .default) { [unowned self] _ in
                let message = "Open with \(core.projectName)…"
                let alwaysUseAlert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
#if os(macOS) || targetEnvironment(macCatalyst)
                if let senderView = sender as? UIView ?? self.view {
                    alwaysUseAlert.popoverPresentationController?.sourceView = senderView
                    alwaysUseAlert.popoverPresentationController?.sourceRect = senderView.bounds
                } else {
                    ELOG("Nil senderView")
                    assertionFailure("Nil senderview")
                }
#else
                if self.traitCollection.userInterfaceIdiom == .pad, let senderView = sender as? UIView ?? self.view {
                    alwaysUseAlert.popoverPresentationController?.sourceView = senderView
                    alwaysUseAlert.popoverPresentationController?.sourceRect = senderView.bounds
                }
#endif

                let thisTimeOnlyAction = UIAlertAction(title: "This time", style: .default, handler: { _ in
                    Task { @MainActor in
                        await self.presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? self.view)
                    }
                })
                let alwaysThisGameAction = UIAlertAction(title: "Always for this game", style: .default, handler: { [unowned self] _ in
                    try! RomDatabase.sharedInstance.writeTransaction {
                        game.userPreferredCoreID = core.identifier
                    }
                    Task { @MainActor in
                        await self.presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? self.view)
                    }
                })
                let alwaysThisSystemAction = UIAlertAction(title: "Always for this system", style: .default, handler: { [unowned self] _ in
                    try! RomDatabase.sharedInstance.writeTransaction {
                        system.userPreferredCoreID = core.identifier
                    }
                    Task { @MainActor in
                        await self.presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? self.view)
                    }
                })

                alwaysUseAlert.addAction(thisTimeOnlyAction)
                alwaysUseAlert.addAction(alwaysThisGameAction)
                alwaysUseAlert.addAction(alwaysThisSystemAction)

                self.present(alwaysUseAlert, animated: true)
            }

            coreChoiceAlert.addAction(action)
        }

        coreChoiceAlert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .destructive, handler: nil))

        present(coreChoiceAlert, animated: true)
    }

    func displayAndLogError(withTitle title: String, message: String, customActions: [UIAlertAction]? = nil) {
        ELOG(message)

        // Use RetroWave styled alert for simple OK-only alerts
        if customActions == nil || customActions?.isEmpty == true {
            Task { @MainActor in
                SceneCoordinator.shared.alertState.show(
                    title: title,
                    message: message,
                    type: .error
                )
            }
        } else {
            // Fall back to UIKit alert for complex alerts with custom actions
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
            customActions?.forEach { alertController.addAction($0) }
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true)
        }
    }

    /// Presents the emulator and optionally prompts the user about continuing from a save state.
    /// - Note: When a caller has already explicitly decided to **start fresh** (e.g. via `RetroSaveSelectionAlertView`),
    ///   pass `skipSaveStatePrompt = true` to avoid falling back to the legacy UIKit prompt.
    @MainActor private func presentEMU(
        withCore core: PVCore,
        forGame game: PVGame,
        fromSaveState saveState: PVSaveState? = nil,
        source: UIView?,
        skipSaveStatePrompt: Bool = false
    ) async {
        guard let realm = await try? Realm() else {
            ELOG("Realm initialization failed")
            return
        }
        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) else {
            ELOG("No game found for id: \(game.md5Hash)")
            return
        }
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.identifier) else {
            ELOG("No core found for id: \(core.identifier)")
            return
        }
        guard let system = game.system, let coreInstance = core.createInstance(forSystem: system) else {
            displayAndLogError(withTitle: "Cannot open game", message: "Failed to create instance of core '\(core.projectName)'.")
            ELOG("Failed to init core instance")
            return
        }

        let emulatorViewController = PVEmulatorViewController(game: game, core: coreInstance)

        // Check if Save State exists
        // Check both core.supportsSaveStates AND if saves exist in DB for this core
        // This handles RetroArch cores where supportsSaveStates may be false before core initialization
        let hasSavesInDatabase = !game.saveStates.filter("core.identifier == %@", core.identifier).isEmpty ||
                                  !game.autoSaves.filter("core.identifier == %@", core.identifier).isEmpty
        let shouldCheckForSaves = !skipSaveStatePrompt && saveState == nil && (emulatorViewController.core.supportsSaveStates || hasSavesInDatabase)

        if shouldCheckForSaves {
            @ThreadSafe var theadsafeCore = core
            @ThreadSafe var threadsafeGame = game

            await checkForSaveStateThenRun(withCore: theadsafeCore!, forGame: threadsafeGame!, source: source) { optionallyChosenSaveState in
                self.presentEMUVC(emulatorViewController, withGame: game, loadingSaveState: optionallyChosenSaveState)
            }
        } else {
            presentEMUVC(emulatorViewController, withGame: game, loadingSaveState: saveState)
        }
    }

    // Used to just show and then optionally quickly load any passed in PVSaveStates
    @MainActor private func presentEMUVC(_ emulatorViewController: PVEmulatorViewController, withGame game: PVGame, loadingSaveState saveState: PVSaveState? = nil) {
        // Check if we should show the support nag screen
        checkAndShowSupportNag()

        // Present the emulator VC
        emulatorViewController.modalTransitionStyle = .crossDissolve
        emulatorViewController.modalPresentationStyle = .fullScreen

        present(emulatorViewController, animated: true) { () -> Void in

            let systemScreenType = game.system?.screenType ?? .unknown
            emulatorViewController.core.screenType = systemScreenType.objcType
            emulatorViewController.gpuViewController.screenType = systemScreenType.rawValue

            // Open the save state after a bootup delay if the user selected one
            // Use a timer loop on ios 10+ to check if the emulator has started running
            if let saveState = saveState {
                let saveStateID = saveState.id

                emulatorViewController.gpuViewController.view.isHidden = true
                _ = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: {[weak self] timer in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }
                    /// Check if the emulator has started
                    if !emulatorViewController.core.isEmulationPaused {
                        /// Cancel the timer
                        timer.invalidate()
                        /// Create thread safe reference to the save state
                        Task { @MainActor in
                            await self.openSaveState(withID: saveStateID)
                            emulatorViewController.gpuViewController.view.isHidden = false
                        }
                    }
                })
            }
        }

        Task.detached { @MainActor in
            await PVControllerManager.shared.iCadeController?.refreshListener()
        }

        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.playCount += 1
                game.lastPlayed = Date()
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }

    @MainActor
    private func checkForSaveStateThenRun(withCore core: PVCore, forGame game: PVGame, source: UIView?, completion: @escaping (PVSaveState?) -> Void) async {
        var foundSave = false
        // Note: saveStates already includes autoSaves (autoSaves is a filtered subset)
        let saves = game.saveStates.filter("core.identifier == \"\(core.identifier)\"")
            .sorted(byKeyPath: "date", ascending: false)
            .toArray()

        let saveState : PVSaveState? = await Task {
            for save in saves {
                if let path = await save.file?.url?.path,
                   !foundSave && FileManager.default.fileExists(atPath: path) && save.core.identifier == core.identifier {
                    foundSave = true
                    return save
                }
            }
            return nil
        }.value

        if foundSave, let latestSaveState = saveState {
            let shouldAskToLoadSaveState: Bool = Defaults[.askToAutoLoad]
            let shouldAutoLoadSaveState: Bool = Defaults[.autoLoadSaves]

            if shouldAutoLoadSaveState {
                completion(latestSaveState)
            } else if shouldAskToLoadSaveState {
                Task { @MainActor in
                    // 1) Alert to ask about loading latest save state
                    let alert = UIAlertController(title: "Save State Detected", message: nil, preferredStyle: .actionSheet)
                    // TODO: XCode15/iOS17 Requires actual source view here
                    alert.preferredContentSize = CGSize(width: 300, height: 150)
                    alert.popoverPresentationController?.sourceView = source
                    alert.popoverPresentationController?.sourceRect = source?.bounds ?? UIScreen.main.bounds
#if os(iOS)
                    let switchControl = UISwitch()
                    switchControl.isOn = !Defaults[.askToAutoLoad]
                    textEditBlocker.switchControl = switchControl

                    // Add a save this setting toggle
                    alert.addTextField { textField in
                        textField.text = "Auto Load Saves"
                        textField.rightViewMode = .always
                        textField.rightView = switchControl
                        textField.borderStyle = .none
                        textField.delegate = textEditBlocker // Weak ref
                        switchControl.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
                    }
#endif

                    // Restart
                    alert.addAction(UIAlertAction(title: "Restart", style: .default, handler: { (_: UIAlertAction) -> Void in
#if os(iOS)
                        if switchControl.isOn {
                            Defaults[.askToAutoLoad] = false
                            Defaults[.autoLoadSaves] = false
                        }
#endif
                        completion(nil)
                    }))

#if os(tvOS)
                    alert.addAction(UIAlertAction(title: "Restart (Always)", style: .default, handler: { (_: UIAlertAction) -> Void in
                        Defaults[.askToAutoLoad] = false
                        Defaults[.autoLoadSaves] = false
                        completion(nil)
                    }))
#endif

                    // Continue
                    alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (_: UIAlertAction) -> Void in
#if os(iOS)
                        if switchControl.isOn {
                            Defaults[.askToAutoLoad] = false
                            Defaults[.autoLoadSaves] = true
                        }
#endif
                        completion(latestSaveState)
                    }))
                    alert.preferredAction = alert.actions.last

#if os(tvOS)
                    // Continue Always
                    alert.addAction(UIAlertAction(title: "Continue (Always)", style: .default, handler: { (_: UIAlertAction) -> Void in
                        Defaults[.askToAutoLoad] = false
                        Defaults[.autoLoadSaves] = true
                        completion(latestSaveState)
                    }))
#endif

                    alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))

                    // Present the alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let `self` = self else { return }

                        self.present(alert, animated: true)
                    }
                }
            } else {
                // Asking is turned off, either load the save state or don't based on the 'autoLoadSaves' setting
                completion(shouldAutoLoadSaveState ? latestSaveState : nil)
            }
        } else {
            completion(nil)
        }
    }

    /// Check if we should show the support nag screen and present it if needed
    @MainActor
    private func checkAndShowSupportNag() {
        guard SupportNagManager.incrementLaunchCount() else {
            return
        }

        let launchCount = SupportNagManager.currentLaunchCount

        // Delay presentation slightly to avoid interrupting game launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            #if canImport(FreemiumKit)
            let nagView = SupportNagView(gameLaunchCount: launchCount) {
                // Dismiss handler - nothing special needed
            }

            let hostingController = UIHostingController(rootView: nagView)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.modalTransitionStyle = .crossDissolve

            self.present(hostingController, animated: true)
            #endif
        }
    }
}

// MARK: - Core Selection Hosting View

/// A SwiftUI view that wraps RetroSelectionAlertView for core selection
/// Note: The caller is responsible for dismissing the hosting controller
struct CoreSelectionAlertHostingView: View {
    let title: String
    let message: String
    let items: [RetroSelectionItem]
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var isPresented = true

    var body: some View {
        ZStack {
            if isPresented {
                RetroSelectionAlertView(
                    title: title,
                    message: message,
                    items: items,
                    isPresented: $isPresented,
                    onSelect: { selectedId in
                        isPresented = false
                        onSelect(selectedId)
                    },
                    onCancel: {
                        isPresented = false
                        onCancel()
                    }
                )
            }
        }
    }
}
