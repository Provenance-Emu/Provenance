//
//  SceneCoordinator.swift
//  PVUI
//
//  Created on 2025-03-25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import PVLogging
import PVLibrary
import PVFileSystem
import PVRealm
import PVSettings
import Combine
import Defaults

// DeltaSkinManager already "conforms" to but does not
// know about SkinImporterServicing, since that's in PVLibrary
// and we don't want to require that dependency
extension DeltaSkinManager: SkinImporterServicing {

}

/// Coordinator for managing scene transitions in the app
@MainActor
public class SceneCoordinator: ObservableObject {
    public static let shared = SceneCoordinator()

    // Track whether we should show the emulator
    @Published public var showEmulator: Bool = false

    // Cancellables for observation
    private var cancellables = Set<AnyCancellable>()

    // Track BIOS downloads requested during preflight so we can notify when they finish
    private var pendingBIOSDownloads = Set<String>()
    private var completedBIOSDownloadsWhileInEmulator = [String]()

    // Sync status manager for showing progress during game launch
    @Published public var syncStatusManager = GameSyncStatusManager()

    // Alert state for showing RetroWave styled alerts
    @Published public var alertState = RetroAlertState()

    public enum Scenes {
        case main
        case emulator
    }

    // Published property to track which scene should be shown
    @Published public var currentScene: Scenes = .main

    private init() {
        // Observe the EmulationUIState for changes to currentGame
        AppState.shared.$emulationUIState
            .map { $0.currentGame != nil }
            .removeDuplicates()
            .sink { [weak self] hasGame in
                guard let self = self else { return }
                if hasGame {
                    ILOG("SceneCoordinator: Game detected in EmulationUIState, showing emulator scene")
                    self.showEmulator = true
                    self.currentScene = .emulator
                } else {
                    ILOG("SceneCoordinator: No game detected in EmulationUIState, returning to main scene")
                    self.showEmulator = false
                    self.currentScene = .main
                }
            }
            .store(in: &cancellables)

        // Observe BIOS downloads completing
        NotificationCenter.default.addObserver(
            forName: .BIOSFileFound,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            self.handleBIOSFileDownloaded(notification)
        }
    }

    public func open(scene: Scenes) {
        switch scene {
        case .main:
            openMainScene()
        case .emulator:
            openEmulatorScene()
        }
    }

    public func openMainScene() {
        guard let url = URL(string: "provenance://main") else {
            ELOG("Failed to create URL for main scene")
            return
        }

        ILOG("skins: Setting SkinImporterInjector service to DeltaSkinManager.shared in SceneCoordinator")
        SkinImporterInjector.shared.service = DeltaSkinManager.shared
        ILOG("skins: SkinImporterInjector service set in SceneCoordinator")

        ILOG("SceneCoordinator: Opening main scene")
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        ILOG("SceneCoordinator: Setting currentScene = .main and showEmulator = false")
        currentScene = .main
        showEmulator = false
        ILOG("SceneCoordinator: Main scene state updated - currentScene: \(currentScene), showEmulator: \(showEmulator)")

        // If there were BIOS downloads completed while in emulator, surface them now
        flushCompletedBIOSDownloadAlerts()
    }

    /// Opens the emulator scene with the current game from AppState
    public func openEmulatorScene() {
//        guard let url = URL(string: "provenance://emulator") else {
//            ELOG("Failed to create URL for emulator scene")
//            return
//        }
//
//        ILOG("SceneCoordinator: Opening emulator scene")
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        ILOG("SceneCoordinator: Opening emulator scene")
        currentScene = .emulator
        showEmulator = true

        // Pause background services during emulation for better performance
        pauseBackgroundServices()
    }

    /// Pauses background services (import queue, cloud sync) during emulation
    private func pauseBackgroundServices() {
        ILOG("SceneCoordinator: Pausing background services for emulation")

        // Pause game importer (emulation-specific pause prevents auto-resume)
        GameImporter.shared.pauseForEmulation()

        // Pause cloud sync operations
        if Defaults[.iCloudSync] {
            CloudSyncManager.shared.pauseForEmulation()
        }
    }

    /// Resumes background services after emulation ends
    private func resumeBackgroundServices() {
        ILOG("SceneCoordinator: Resuming background services after emulation")

        // Resume game importer
        GameImporter.shared.resumeFromEmulation()

        // Resume cloud sync operations
        if Defaults[.iCloudSync] {
            CloudSyncManager.shared.resumeFromEmulation()
        }
    }

    /// Launch a specific game with error handling and sync validation
    public func launchGame(_ game: PVGame) {
        ILOG("SceneCoordinator: Launching game: \(game.title) (ID: \(game.id))")

        // Validate and sync game before launch
        Task { @MainActor in
            await launchGameWithValidation(game)
        }
    }

    /// Launch game with sync validation
    private func launchGameWithValidation(_ game: PVGame) async {
        guard let system = game.system else {
            showGameLaunchError(
                title: "Cannot Launch Game",
                message: "No system found for this game. The game may be corrupted or misconfigured."
            )
            return
        }

        // Check if the game needs to be downloaded from the cloud
        let needsDownload = !game.isDownloaded || !(game.file?.online ?? true)

        // If download is needed, validate requirements BEFORE downloading
        if needsDownload {
            let validation = await validatePreDownloadRequirements(for: game, system: system)

            if !validation.canProceed {
                // Show warning and let user choose
                let shouldContinue = await showPreDownloadWarning(validation: validation)
                if !shouldContinue {
                    ILOG("SceneCoordinator: User cancelled download due to missing requirements")
                    return
                }
                ILOG("SceneCoordinator: User chose to continue download despite missing requirements")
            }
        }

        // Show sync status overlay
        syncStatusManager.show(
            gameTitle: game.title,
            statusMessage: "Checking game file...",
            onCancel: { [weak self] in
                self?.syncStatusManager.hide()
                self?.openMainScene()
            }
        )

        // Create validator if cloud sync is enabled
        let validator: GameSyncValidator?
        if Defaults[.iCloudSync] {
            validator = GameSyncValidator(cloudSyncManager: CloudSyncManager.shared)
        } else {
            validator = nil
        }

        // Validate game availability
        if let validator = validator {
            let isValid = await validator.ensureGameReady(game) { [weak self] progressMessage in
                Task { @MainActor in
                    self?.syncStatusManager.update(statusMessage: progressMessage)
                }
                ILOG("Game sync progress: \(progressMessage)")
            }

            if isValid {
                syncStatusManager.complete()
            } else {
                syncStatusManager.error("Game file is not available. Please ensure iCloud sync is enabled and the game is synced.")
                // Show error alert after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Cannot Launch Game",
                        message: "The game file is not available on this device.\n\nTo fix this:\n1. Make sure iCloud sync is enabled in Settings\n2. Wait for the game to finish syncing (check the cloud icon)\n3. Try launching again\n\nIf the problem persists, try removing and re-importing the game."
                    )
                }
                return
            }
        } else {
            // No cloud sync - just verify file exists
            syncStatusManager.update(statusMessage: "Verifying file...")

            guard let fileURL = game.file?.url,
                  FileManager.default.fileExists(atPath: fileURL.path) else {
                syncStatusManager.error("Game file not found. Please verify the ROM file exists.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Game File Not Found",
                        message: "The game file could not be found on your device.\n\nThis can happen if:\n• The file was deleted\n• The file was moved\n• There's a storage issue\n\nTry removing the game from your library and re-importing it."
                    )
                }
                return
            }

            syncStatusManager.complete()
        }

        // Small delay to show completion status
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Hide sync status before any further checks
        syncStatusManager.hide()

        // ALWAYS validate BIOS and core requirements before launching (not just for cloud downloads)
        let validation = await validatePreDownloadRequirements(for: game, system: system)

        if !validation.canProceed {
            // Show error and stay in main scene - don't launch emulator
            var errorTitle = "Cannot Launch Game"
            var errorMessage = ""

            if !validation.hasAvailableCores {
                errorTitle = "No Compatible Core"
                errorMessage = "There are no compatible emulator cores available for \(system.name).\n\n"
                if AppState.shared.isAppStore {
                    errorMessage += "Some cores may be unavailable in the App Store version. Enable 'Unsupported Cores' in Settings to see more options."
                } else {
                    errorMessage += "Please ensure the required core is installed and enabled."
                }
            } else if !validation.missingBIOSFiles.isEmpty {
                errorTitle = "Missing BIOS Files"
                PVEmulatorConfiguration.createBIOSDirectory(forSystemIdentifier: system.enumValue)
                let missingFiles = validation.missingBIOSFiles.joined(separator: "\n• ")
                // Use platform-aware path (Documents on iOS, Caches on tvOS)
                let rootDirName = RelativeRoot.platformDefault == .caches ? "Caches" : "Documents"
                let biosPath = "\(rootDirName)/BIOS/\(system.identifier)/"
                errorMessage = "\(system.name) requires BIOS files to run games.\n\nMissing files:\n• \(missingFiles)\n\nPlease add these files to:\n\(biosPath)"
            }

            WLOG("SceneCoordinator: Cannot launch game - \(errorTitle)")
            showGameLaunchError(title: errorTitle, message: errorMessage)
            return
        }

        // Set the current game in EmulationUIState
        AppState.shared.emulationUIState.currentGame = game

        // Verify the game was set correctly
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("SceneCoordinator: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")

            // Open the emulator scene - errors will be handled by PVEmulatorViewController
            openEmulatorScene()
        } else {
            ELOG("SceneCoordinator: Failed to set current game in EmulationUIState")
            // Show error and stay in main scene
            showGameLaunchError(
                title: "Failed to Launch Game",
                message: "Could not prepare the game for launch. This may be due to:\n\n• Missing or corrupted game file\n• Core not available or failed to load\n• Insufficient memory\n\nTry restarting the app, or remove and re-import the game if the problem persists."
            )
        }
    }

    // MARK: - Pre-Download Validation

    /// Result of pre-download validation
    public struct PreDownloadValidation {
        let canProceed: Bool
        let missingBIOSFiles: [String]
        let hasAvailableCores: Bool
        let systemName: String

        var warningMessage: String {
            var messages: [String] = []

            if !hasAvailableCores {
                messages.append("• No compatible emulator cores are available for \(systemName)")
            }

            if !missingBIOSFiles.isEmpty {
                let biosFiles = missingBIOSFiles.prefix(3).joined(separator: ", ")
                let moreCount = missingBIOSFiles.count - 3
                if moreCount > 0 {
                    messages.append("• Missing BIOS files: \(biosFiles) and \(moreCount) more")
                } else {
                    messages.append("• Missing BIOS files: \(biosFiles)")
                }
            }

            return messages.joined(separator: "\n\n")
        }
    }

    /// Validates requirements before downloading a cloud ROM
    private func validatePreDownloadRequirements(for game: PVGame, system: PVSystem) async -> PreDownloadValidation {
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
        var queuedBackgroundBIOSDownloads: [String] = []

        if system.requiresBIOS {
            // Snapshot BIOS entries to an Array to avoid iterating live Realm collections across awaits
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
                    // BIOS not found locally - if it exists in CloudKit, queue background download instead of blocking launch
                    if let biosEntry = RomDatabase.sharedInstance.realm.objects(PVBIOS.self).filter("expectedFilename ==[c] %@", expectedFilename).first,
                       let recordID = biosEntry.cloudRecordID,
                       !recordID.isEmpty {
                        queueBackgroundBIOSDownload(filename: expectedFilename)
                        queuedBackgroundBIOSDownloads.append(expectedFilename)
                        missingBIOSFiles.append(expectedFilename)
                    } else {
                        // Fall back to legacy on-demand attempt (kept for safety)
                        ILOG("[BIOS ON-DEMAND] Missing BIOS \(expectedFilename), attempting CloudKit download...")
                        let downloaded = await tryDownloadBIOSFromCloud(filename: expectedFilename, expectedMD5: bios.expectedMD5, system: system)

                        if downloaded {
                            ILOG("[BIOS ON-DEMAND] ✓ Successfully downloaded BIOS: \(expectedFilename)")
                            existingFiles.insert(expectedFilename.lowercased())
                        } else {
                            WLOG("[BIOS ON-DEMAND] Failed to download BIOS: \(expectedFilename)")
                            missingBIOSFiles.append(expectedFilename)
                        }
                    }
                }
            }
        }

        let canProceed = hasAvailableCores && missingBIOSFiles.isEmpty

        return PreDownloadValidation(
            canProceed: canProceed,
            missingBIOSFiles: missingBIOSFiles,
            hasAvailableCores: hasAvailableCores,
            systemName: system.name
        )
    }

    /// Queue a BIOS download in the background and notify the user in library views
    private func queueBackgroundBIOSDownload(filename: String) {
        let key = filename.lowercased()
        guard !pendingBIOSDownloads.contains(key) else { return }
        pendingBIOSDownloads.insert(key)

        Task.detached {
            await CloudSyncManager.shared.forceBIOSDownload()
        }

        // Inform the user only when in library scenes to avoid interrupting emulation
        if currentScene == .main {
            alertState.show(
                title: "Downloading BIOS",
                message: "Required BIOS '\(filename)' will download in the background. You'll be notified when it's ready.",
                type: .standard
            )
        }
    }

    /// Handle BIOS download completion notifications
    private func handleBIOSFileDownloaded(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        let name = url.lastPathComponent.lowercased()

        guard pendingBIOSDownloads.contains(name) else { return }
        pendingBIOSDownloads.remove(name)

        if currentScene == .main {
            alertState.show(
                title: "BIOS Downloaded",
                message: " '\(url.lastPathComponent)' is ready. You can launch games that require it.",
                type: .success
            )
        } else {
            completedBIOSDownloadsWhileInEmulator.append(url.lastPathComponent)
        }
    }

    /// Show any BIOS download completions that happened while in emulator, once back in library
    private func flushCompletedBIOSDownloadAlerts() {
        guard currentScene == .main, !completedBIOSDownloadsWhileInEmulator.isEmpty else { return }
        let names = completedBIOSDownloadsWhileInEmulator
        completedBIOSDownloadsWhileInEmulator.removeAll()

        let list = names.joined(separator: ", ")
        alertState.show(
            title: "BIOS Downloads Completed",
            message: "\(list) ready. You can launch games that need these BIOS files.",
            type: .success
        )
    }

    /// Attempt to download a missing BIOS file from CloudKit on-demand (with timeout)
    /// - Parameters:
    ///   - filename: The expected BIOS filename
    ///   - expectedMD5: The expected MD5 hash
    ///   - system: The system requiring the BIOS
    /// - Returns: True if the BIOS was successfully downloaded
    private func tryDownloadBIOSFromCloud(filename: String, expectedMD5: String, system: PVSystem) async -> Bool {
        // Check if we have a PVBIOS entry with a cloudRecordID
        let realm = RomDatabase.sharedInstance.realm
        let biosEntry = realm.objects(PVBIOS.self).filter("expectedFilename == %@ OR expectedMD5 ==[c] %@", filename, expectedMD5).first

        // If no PVBIOS entry found, we can't download from cloud
        guard let bios = biosEntry else {
            DLOG("[BIOS ON-DEMAND] No PVBIOS entry found for: \(filename)")
            return false
        }

        // Use a timeout task to prevent hanging
        let downloadTask = Task { @MainActor () -> Bool in
            // If no cloudRecordID, try to sync metadata first to get one
            if bios.cloudRecordID == nil || bios.cloudRecordID?.isEmpty == true {
                ILOG("[BIOS ON-DEMAND] No cloudRecordID for \(filename), triggering BIOS metadata sync...")
                await CloudSyncManager.shared.forceBIOSDownload()

                // Re-check after sync
                RomDatabase.refresh()
            }

            // Re-fetch to get updated cloudRecordID
            guard let updatedBios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first,
                  let recordID = updatedBios.cloudRecordID, !recordID.isEmpty else {
                WLOG("[BIOS ON-DEMAND] Still no cloudRecordID after sync for: \(filename)")
                return false
            }

            ILOG("[BIOS ON-DEMAND] Found cloudRecordID: \(recordID), downloading: \(filename)")

            // Trigger download - forceBIOSDownload will handle fetching and downloading
            await CloudSyncManager.shared.forceBIOSDownload()

            // Verify the file now exists
            let biosPath = system.biosDirectory.appendingPathComponent(filename)
            let fileExists = FileManager.default.fileExists(atPath: biosPath.path)

            if fileExists {
                ILOG("[BIOS ON-DEMAND] ✓ Download verified, file exists at: \(biosPath.path)")
            } else {
                WLOG("[BIOS ON-DEMAND] Download completed but file not found at: \(biosPath.path)")
            }

            return fileExists
        }

        // Timeout after 45 seconds to prevent indefinite hanging
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 45_000_000_000) // 45 seconds
            downloadTask.cancel()
            WLOG("[BIOS ON-DEMAND] Download timed out for: \(filename)")
        }

        do {
            let result = try await downloadTask.value
            timeoutTask.cancel()
            return result
        } catch is CancellationError {
            WLOG("[BIOS ON-DEMAND] Download was cancelled (timeout) for: \(filename)")
            return false
        } catch {
            ELOG("[BIOS ON-DEMAND] Download failed for \(filename): \(error.localizedDescription)")
            return false
        }
    }

    /// Shows a warning alert and returns true if user wants to continue
    private func showPreDownloadWarning(validation: PreDownloadValidation) async -> Bool {
        // Use a flag to ensure continuation is only resumed once
        var hasResumed = false

        return await withCheckedContinuation { continuation in
            var title = "Download Warning"
            var message = "This game may not be playable after downloading:\n\n\(validation.warningMessage)\n\nDo you want to download anyway?"

            if !validation.hasAvailableCores {
                title = "No Compatible Core"
                message = "There are no compatible emulator cores available for \(validation.systemName).\n\n"
                if AppState.shared.isAppStore {
                    message += "Some cores may be unavailable in the App Store version. Enable 'Unsupported Cores' in Settings to see more options.\n\n"
                }
                message += "Download this ROM anyway? You won't be able to play it until a compatible core is available."
            } else if !validation.missingBIOSFiles.isEmpty {
                title = "Missing BIOS Files"
                message = "\(validation.systemName) requires BIOS files to run games.\n\n\(validation.warningMessage)\n\nDownload this ROM anyway? You'll need to add the BIOS files before playing."
            }

            alertState.show(
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

    /// Show error alert for game launch failures and return to main scene
    private func showGameLaunchError(title: String, message: String) {
        // Ensure we're on the main scene
        openMainScene()

        // Show RetroWave styled alert
        alertState.show(
            title: title,
            message: message,
            type: .error
        )
    }

    /// Handles closing the emulator and returning to the main scene
    public func closeEmulator() {
        ILOG("SceneCoordinator: closeEmulator() called")

        // Reset the app open action FIRST to prevent any reopening attempts
        AppState.shared.appOpenAction = .none
        ILOG("SceneCoordinator: Reset appOpenAction to .none when closing emulator")

        // Clear the emulation state
        AppState.shared.emulationUIState.core = nil
        AppState.shared.emulationUIState.emulator = nil
        AppState.shared.emulationUIState.currentGame = nil
        ILOG("SceneCoordinator: Cleared emulation state")

        // Resume background services that were paused during emulation
        resumeBackgroundServices()

        // Return to the main scene
        ILOG("SceneCoordinator: Calling openMainScene()")
        openMainScene()
        ILOG("SceneCoordinator: closeEmulator() completed")
    }
}
