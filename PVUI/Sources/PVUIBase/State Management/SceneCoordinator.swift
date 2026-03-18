//
//  SceneCoordinator.swift
//  PVUI
//
//  Created on 2025-03-25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import GameController
import PVCoreBridge
import PVFeatureFlags
import PVLogging
import PVLibrary
import PVPrimitives
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

    // Navigation stack for multi-step alert flows (core selection, save selection, etc.)
    @Published public var alertNavigationStack = RetroAlertNavigationStack()

    // Pre-launch Transfer Pak setup sheet.
    // showPreLaunchTransferPak drives the sheet isPresented binding.
    // preLaunchTransferPakGame holds the game to configure (non-nil while sheet is shown).
    @Published public var showPreLaunchTransferPak: Bool = false
    @Published public var preLaunchTransferPakGame: PVGame? = nil
    private var _preLaunchContinuation: CheckedContinuation<Void, Never>? = nil

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

        /// Pause all background services via the central registry
        BackgroundServiceRegistry.shared.pauseAll(reason: .emulation)
    }

    /// Launch a specific game with error handling and sync validation
    public func launchGame(_ game: PVGame) {
        ILOG("SceneCoordinator: Launching game: \(game.title) (ID: \(game.id))")

        // Validate and sync game before launch
        Task { @MainActor in
            await launchGameWithValidation(game)
        }
    }

    /// Launch a save state with sync validation for game ROM, BIOS, and save state
    public func launchSaveState(_ saveState: PVSaveState, core: PVCore? = nil) {
        guard let game = saveState.game else {
            showGameLaunchError(
                title: "Cannot Launch Save State",
                message: "No game found for this save state. The save state may be corrupted or misconfigured."
            )
            return
        }

        ILOG("SceneCoordinator: Launching save state: \(saveState.id) for game: \(game.title)")

        // Validate and sync before launch
        Task { @MainActor in
            await launchSaveStateWithValidation(saveState, game: game, core: core)
        }
    }

    /// Launch a game with optional core (bypasses core selection if core is provided)
    public func launchGame(_ game: PVGame, core: PVCore?) {
        ILOG("SceneCoordinator: Launching game: \(game.title) (ID: \(game.id)) with core: \(core?.projectName ?? "auto")")

        // Validate and sync game before launch
        Task { @MainActor in
            await launchGameWithValidation(game, core: core)
        }
    }

    /// Launch a game with disc path (for multi-disc games)
    public func launchGame(_ game: PVGame, discPath: String, core: PVCore?, saveState: PVSaveState?) {
        ILOG("SceneCoordinator: Launching game: \(game.title) with disc path: \(discPath)")

        // Create a temporary game object with the disc path
        var tempGame = game
        tempGame.selectedDiscFilename = (discPath as NSString).lastPathComponent

        // If there's a save state, launch that instead
        if let saveState = saveState {
            launchSaveState(saveState, core: core)
        } else {
            launchGame(tempGame, core: core)
        }
    }

    /// Launch game with sync validation
    private func launchGameWithValidation(_ game: PVGame, core: PVCore? = nil) async {
        guard let system = game.system else {
            showGameLaunchError(
                title: "Cannot Launch Game",
                message: "No system found for this game. The game may be corrupted or misconfigured."
            )
            return
        }

        // Contentless placeholder games intentionally have no ROM file; skip file/sync validation.
        if game.contentless {
            syncStatusManager.hide()
            AppState.shared.emulationUIState.currentGame = game
            if let core = core {
                AppState.shared.emulationUIState.currentCore = core
            }
            openEmulatorScene()
            return
        }

        // Check if the game needs to be downloaded from the cloud
        let needsDownload = !game.isDownloaded || !(game.file?.online ?? true)

        // Show sync status overlay early if we need to validate (may download BIOS)
        if needsDownload || system.requiresBIOS {
            syncStatusManager.show(
                gameTitle: game.title,
                statusMessage: "Validating requirements...",
                onCancel: { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.openMainScene()
                }
            )
        }

        // If download is needed, validate requirements BEFORE downloading
        if needsDownload {
            let validation = await validatePreDownloadRequirements(for: game, system: system)

            if !validation.canProceed {
                // Hide status overlay before showing warning
                syncStatusManager.hide()

                // Show warning and let user choose
                let shouldContinue = await showPreDownloadWarning(validation: validation)
                if !shouldContinue {
                    ILOG("SceneCoordinator: User cancelled download due to missing requirements")
                    return
                }
                ILOG("SceneCoordinator: User chose to continue download despite missing requirements")

                // Re-show status overlay after user chooses to continue
                syncStatusManager.show(
                    gameTitle: game.title,
                    statusMessage: "Checking game file...",
                    onCancel: { [weak self] in
                        self?.syncStatusManager.hide()
                        self?.openMainScene()
                    }
                )
            } else {
                // Validation passed, update status
                syncStatusManager.update(statusMessage: "Checking game file...")
            }
        } else if !system.requiresBIOS {
            // Show sync status overlay (no early show was done)
            syncStatusManager.show(
                gameTitle: game.title,
                statusMessage: "Checking game file...",
                onCancel: { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.openMainScene()
                }
            )
        } else {
            // Early show was done, just update message
            syncStatusManager.update(statusMessage: "Checking game file...")
        }

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

        // ALWAYS validate BIOS and core requirements before launching (not just for cloud downloads)
        // Show status for BIOS validation if system requires BIOS
        if system.requiresBIOS {
            syncStatusManager.update(statusMessage: "Validating BIOS requirements...")
        }

        let validation = await validatePreDownloadRequirements(for: game, system: system)

        // Hide sync status after validation
        syncStatusManager.hide()

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

        // Set the current game and core in EmulationUIState
        AppState.shared.emulationUIState.currentGame = game
        if let core = core {
            AppState.shared.emulationUIState.currentCore = core
        }

        // Verify the game was set correctly
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("SceneCoordinator: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
            if let core = core {
                ILOG("SceneCoordinator: Core set: \(core.projectName)")
            }

            // Load per-game / per-system controller profiles for all connected controllers.
            loadControllerProfiles(for: currentGame, core: core)

            // Show pre-launch Transfer Pak setup sheet for known N64 Transfer Pak titles
            // when the feature is enabled and no slots have been configured yet.
            await maybePromptTransferPakSetup(for: currentGame)

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

    // MARK: - Controller Profile Loading

    /// Load the best-matching controller profile for every connected controller
    /// before launching `game`.  Profiles are scoped (game → system+core → system → global).
    private func loadControllerProfiles(for game: PVGame, core: PVCore? = nil) {
        let systemIdentifier = game.systemIdentifier.isEmpty ? nil : game.systemIdentifier
        let coreIdentifier = core?.identifier.isEmpty == false ? core?.identifier : nil
        let gameID = game.md5Hash.isEmpty ? nil : game.md5Hash

        for controller in PVControllerManager.shared.controllers {
            let wrapper = getRemappableControllerWrapper(for: controller)
            wrapper.loadActiveProfile(systemIdentifier: systemIdentifier, coreIdentifier: coreIdentifier, gameID: gameID)
        }
        ILOG("SceneCoordinator: Loaded controller profiles for \(PVControllerManager.shared.controllers.count) controller(s)")
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
            !(AppState.shared.isAppStore && $0.appStoreDisabled)
        }
        let hasAvailableCores = !availableCores.isEmpty

        // Check for missing BIOS files
        var missingBIOSFiles: [String] = []

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
                    // BIOS not found locally - attempt CloudKit download if sync is enabled
                    if Defaults[.iCloudSync] {
                        // Show status update for BIOS download
                        await MainActor.run {
                            syncStatusManager.update(statusMessage: "Downloading BIOS: \(expectedFilename)...")
                        }

                        ILOG("[BIOS ON-DEMAND] Missing BIOS \(expectedFilename), attempting CloudKit download...")
                        let downloaded = await tryDownloadBIOSFromCloud(
                            filename: expectedFilename,
                            expectedMD5: bios.expectedMD5,
                            system: system
                        )

                        if downloaded {
                            ILOG("[BIOS ON-DEMAND] ✓ Successfully downloaded BIOS from CloudKit: \(expectedFilename)")
                            existingFiles.insert(expectedFilename.lowercased())
                            // Don't add to missingBIOSFiles - we got it!
                        } else {
                            WLOG("[BIOS ON-DEMAND] CloudKit download failed for BIOS: \(expectedFilename)")
                            missingBIOSFiles.append(expectedFilename)
                        }
                    } else {
                        // CloudKit sync disabled - mark as missing
                        DLOG("[BIOS] CloudKit sync disabled, BIOS marked as missing: \(expectedFilename)")
                        missingBIOSFiles.append(expectedFilename)
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
    func tryDownloadBIOSFromCloud(filename: String, expectedMD5: String, system: PVSystem) async -> Bool {
        let systemIdentifier = system.identifier

        // First, check if file already exists (might have been downloaded by another process)
        let biosPath = system.biosDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: biosPath.path) {
            ILOG("[BIOS ON-DEMAND] File already exists at: \(biosPath.path)")
            return true
        }

        ILOG("[BIOS ON-DEMAND] Starting fast targeted download for: \(filename)")

        // Use a timeout task to prevent hanging
        let downloadTask = Task { @MainActor () -> Bool in
            // Try the fast targeted download first (tries predicted record IDs + filename query)
            let fastResult = await CloudSyncManager.shared.downloadSingleBIOS(
                filename: filename,
                expectedMD5: expectedMD5,
                systemIdentifier: systemIdentifier
            )

            if fastResult {
                // Verify the file now exists
                let fileExists = FileManager.default.fileExists(atPath: biosPath.path)
                if fileExists {
                    ILOG("[BIOS ON-DEMAND] ✓ Fast download succeeded: \(filename)")
                    return true
                }
            }

            // Fast method failed - try the slower full sync as fallback
            ILOG("[BIOS ON-DEMAND] Fast download failed, trying full sync for: \(filename)")
            await CloudSyncManager.shared.forceBIOSDownload()

            // Verify the file now exists
            let fileExists = FileManager.default.fileExists(atPath: biosPath.path)
            if fileExists {
                ILOG("[BIOS ON-DEMAND] ✓ Full sync download verified: \(filename)")
            } else {
                WLOG("[BIOS ON-DEMAND] Download completed but file not found at: \(biosPath.path)")
            }

            return fileExists
        }

        // Timeout after 20 seconds (reduced from 45 since fast path should be quick)
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
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

    /// Launch save state with sync validation
    private func launchSaveStateWithValidation(_ saveState: PVSaveState, game: PVGame, core: PVCore? = nil) async {
        guard let system = game.system else {
            showGameLaunchError(
                title: "Cannot Launch Save State",
                message: "No system found for this game. The game may be corrupted or misconfigured."
            )
            return
        }

        // Check if the game needs to be downloaded from the cloud
        let needsDownload = !game.isDownloaded || !(game.file?.online ?? true)

        // Show sync status overlay early if we need to validate (may download BIOS)
        if needsDownload || system.requiresBIOS {
            syncStatusManager.show(
                gameTitle: game.title,
                statusMessage: "Validating requirements...",
                onCancel: { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.openMainScene()
                }
            )
        }

        // If download is needed, validate requirements BEFORE downloading
        if needsDownload {
            let validation = await validatePreDownloadRequirements(for: game, system: system)

            if !validation.canProceed {
                // Hide status overlay before showing warning
                syncStatusManager.hide()

                // Show warning and let user choose
                let shouldContinue = await showPreDownloadWarning(validation: validation)
                if !shouldContinue {
                    ILOG("SceneCoordinator: User cancelled save state launch due to missing requirements")
                    return
                }
                ILOG("SceneCoordinator: User chose to continue save state launch despite missing requirements")

                // Re-show status overlay after user chooses to continue
                syncStatusManager.show(
                    gameTitle: game.title,
                    statusMessage: "Checking game file...",
                    onCancel: { [weak self] in
                        self?.syncStatusManager.hide()
                        self?.openMainScene()
                    }
                )
            } else {
                // Validation passed, update status
                syncStatusManager.update(statusMessage: "Checking game file...")
            }
        } else if !system.requiresBIOS {
            // Show sync status overlay (no early show was done)
            syncStatusManager.show(
                gameTitle: game.title,
                statusMessage: "Checking game file...",
                onCancel: { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.openMainScene()
                }
            )
        } else {
            // Early show was done, just update message
            syncStatusManager.update(statusMessage: "Checking game file...")
        }

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

            if !isValid {
                syncStatusManager.error("Game file is not available. Please ensure iCloud sync is enabled and the game is synced.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Cannot Launch Save State",
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
        }

        // Validate BIOS and core requirements
        // Show status for BIOS validation if system requires BIOS
        if system.requiresBIOS {
            syncStatusManager.update(statusMessage: "Validating BIOS requirements...")
        }

        let validation = await validatePreDownloadRequirements(for: game, system: system)

        if !validation.canProceed {
            var errorTitle = "Cannot Launch Save State"
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
                let rootDirName = RelativeRoot.platformDefault == .caches ? "Caches" : "Documents"
                let biosPath = "\(rootDirName)/BIOS/\(system.identifier)/"
                errorMessage = "\(system.name) requires BIOS files to run games.\n\nMissing files:\n• \(missingFiles)\n\nPlease add these files to:\n\(biosPath)"
            }

            syncStatusManager.hide()
            WLOG("SceneCoordinator: Cannot launch save state - \(errorTitle)")
            showGameLaunchError(title: errorTitle, message: errorMessage)
            return
        }

        // Download save state if needed
        syncStatusManager.update(statusMessage: "Checking save state...")

        let fileManager = FileManager.default
        let saveStateReady: Bool

        if let localURL = saveState.file?.url, fileManager.fileExists(atPath: localURL.path) {
            saveStateReady = true
        } else {
            // Save state needs to be downloaded
            guard let recordID = saveState.cloudRecordID, !recordID.isEmpty else {
                syncStatusManager.error("Save state not available.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Save State Not Available",
                        message: "The save state file is not available on this device and cannot be downloaded from iCloud.\n\nThis may happen if:\n• iCloud sync is disabled\n• The save state was never synced\n• There's a sync issue\n\nTry enabling iCloud sync and waiting for sync to complete."
                    )
                }
                return
            }

            let frozenSaveState = saveState.freeze()
            syncStatusManager.update(statusMessage: "Downloading save state...")

            do {
                try await CloudSyncManager.shared.downloadSaveState(for: frozenSaveState)
                saveStateReady = true
            } catch {
                syncStatusManager.error("Save state download failed.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Download Failed",
                        message: "Failed to download the save state: \(error.localizedDescription)\n\nPlease check your internet connection and iCloud sync settings."
                    )
                }
                ELOG("Failed to download save state \(recordID): \(error)")
                return
            }
        }

        guard saveStateReady else {
            syncStatusManager.hide()
            return
        }

        syncStatusManager.complete()

        // Small delay to show completion status
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Hide sync status before launching
        syncStatusManager.hide()

        // Fetch fresh save state from Realm to ensure file references are up to date
        let preparedSaveState: PVSaveState?
        do {
            let realm = RomDatabase.sharedInstance.realm
            preparedSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveState.id)?.freeze()
        } catch {
            ELOG("Failed to refresh save state \(saveState.id): \(error)")
            preparedSaveState = saveState.freeze()
        }

        // Determine which core to use: explicit core parameter, save state's core, or nil
        let coreToUse: PVCore? = core ?? preparedSaveState?.core

        // Check save state version mismatch before launching.
        // If the user approves (or there is no mismatch), record the save state ID so
        // the emulator VC skips the identical check when it loads the state on boot.
        if let stateToCheck = preparedSaveState {
            let shouldProceed = await SaveStateVersionChecker.confirmLoad(
                saveState: stateToCheck,
                overrideCore: coreToUse,
                alertState: alertState
            )
            if !shouldProceed {
                ILOG("SceneCoordinator: User cancelled save state launch due to version mismatch")
                return
            }
            // Mark this save state as already version-checked for this launch so the
            // emulator VC does not re-prompt on its own load call.
            AppState.shared.emulationUIState.confirmedMismatchSaveStateID = stateToCheck.id
        }

        // Set the current game, save state, and core in EmulationUIState
        AppState.shared.emulationUIState.currentGame = game
        AppState.shared.emulationUIState.currentSaveState = preparedSaveState
        if let coreToUse = coreToUse {
            AppState.shared.emulationUIState.currentCore = coreToUse
        }

        // Verify the game was set correctly
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("SceneCoordinator: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
            if let saveState = preparedSaveState {
                ILOG("SceneCoordinator: Save state set: \(saveState.id)")
            }
            if let core = core {
                ILOG("SceneCoordinator: Core set: \(core.projectName)")
            }

            // Load per-game / per-system controller profiles for all connected controllers.
            loadControllerProfiles(for: currentGame, core: coreToUse)

            // Open the emulator scene - the emulator will handle loading the game with save state
            openEmulatorScene()
        } else {
            ELOG("SceneCoordinator: Failed to set current game in EmulationUIState")
            showGameLaunchError(
                title: "Failed to Launch Save State",
                message: "Could not prepare the game for launch. This may be due to:\n\n• Missing or corrupted game file\n• Core not available or failed to load\n• Insufficient memory\n\nTry restarting the app, or remove and re-import the game if the problem persists."
            )
        }
    }

    // MARK: - Transfer Pak Pre-Launch Setup

    /// Shows the Transfer Pak configuration sheet before launching an N64 game if:
    ///   - The `mupenTransferPak` feature flag is enabled
    ///   - The game is an N64 title known to use the Transfer Pak
    ///   - No Transfer Pak slots are currently configured for this game
    ///
    /// Awaits until the user taps "Skip & Launch", "Launch Game", or swipes to dismiss.
    private func maybePromptTransferPakSetup(for game: PVGame) async {
        guard PVFeatureFlagsManager.shared.isEnabled(.mupenTransferPak),
              SystemIdentifier(rawValue: game.systemIdentifier) == .N64,
              TransferPakCompatibleGames.isKnownTransferPakGame(game.title)
        else { return }

        // Don't re-prompt once the user has configured at least one slot.
        let md5 = game.md5Hash
        let alreadyConfigured = await Task.detached(priority: .userInitiated) {
            (0..<4).contains { TransferPakStore.romPath(forGameMD5: md5, port: $0) != nil }
        }.value
        guard !alreadyConfigured else { return }

        ILOG("SceneCoordinator: Showing pre-launch Transfer Pak setup for \(game.title)")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            _preLaunchContinuation = continuation
            preLaunchTransferPakGame = game
            showPreLaunchTransferPak = true
        }
    }

    /// Called when the pre-launch Transfer Pak sheet is dismissed (button tap or swipe).
    /// Safe to call multiple times — second call is a no-op.
    public func dismissPreLaunchTransferPak() {
        showPreLaunchTransferPak = false
        preLaunchTransferPakGame = nil
        let cont = _preLaunchContinuation
        _preLaunchContinuation = nil
        cont?.resume()
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

        /// Resume all background services via the central registry
        BackgroundServiceRegistry.shared.resumeAll(reason: .emulation)

        // Return to the main scene
        ILOG("SceneCoordinator: Calling openMainScene()")
        openMainScene()
        ILOG("SceneCoordinator: closeEmulator() completed")
    }
}
