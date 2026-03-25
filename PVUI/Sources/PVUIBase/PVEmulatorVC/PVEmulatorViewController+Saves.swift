//
//  PVEmulatorViewController+Saves.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/31/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
import PVRealm
import PVLogging
import PVEmulatorCore
import PVCoreBridge
import PVSettings
#if canImport(UIKit)
import UIKit
#endif

public extension PVEmulatorViewController {
    public func destroyAutosaveTimer() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }

    public func createAutosaveTimer() {
        autosaveTimer?.invalidate()
        let interval = Defaults[.timedAutoSaveInterval]
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
            Task { @MainActor in
                if AppState.shared.emulationUIState.isInBackground {
                    return
                }
                let image = self.captureScreenshot()
                Task.detached {
                    do {
                        return try await self.createNewSaveState(auto: true, screenshot: image)
                    } catch {
                        ELOG("Autosave timer failed to make save state: \(error.localizedDescription)")
                        return false
                    }
                }
            }
        })
    }

    @MainActor
    public func loadSaveState(_ state: PVSaveState) async -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            return false
        }

        // RetroAchievements hardcore mode disallows save-state loads.
        if achievementsBlocksSaveStateLoad() {
            presentError(
                "Save state loading is disabled in RetroAchievements Hardcore Mode.",
                source: view
            )
            return false
        }

        guard let realm = try? await Realm() else {
            ELOG("Realm() failed")
            return false
        }
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
            return false
        }

        // Validate the save file exists before prompting the user
        if let url = state.file?.url, !FileManager.default.fileExists(atPath: url.path) {
            let message =
                """
                Save State is not valid
                Please try another save state
                """
            presentWarning(message, source: self.view, completion: {})
            return false
        }

        // Confirm version mismatch with user before loading.
        // The load task is intentionally deferred until after the user confirms,
        // so that cancelling the dialog reliably prevents the load.
        //
        // Skip the prompt when SceneCoordinator already confirmed this exact save state
        // during the pre-launch flow (library → emulator boot). Consume the confirmation
        // token so any subsequent in-session loads (e.g. from the pause menu) still prompt.
        let alreadyConfirmed: Bool
        if AppState.shared.emulationUIState.confirmedMismatchSaveStateID == state.id {
            AppState.shared.emulationUIState.confirmedMismatchSaveStateID = nil
            alreadyConfirmed = true
        } else {
            alreadyConfirmed = false
        }

        if !alreadyConfirmed {
            // Enable UIKit controller interaction so MFi gamepads can navigate the alert
            // on tvOS (GCEventViewController intercepts input when the game is active).
            enableControllerInput(true)
            let shouldLoad = await SaveStateVersionChecker.confirmLoad(
                saveState: state,
                overrideCore: core,
                on: self
            )
            enableControllerInput(false)
            guard shouldLoad else {
                return false
            }
        }

        // Resolve a live object from this Realm instance — the incoming `state` may be
        // frozen (e.g. from PauseMenuSaveStateBrowserView) or from a different Realm.
        guard let liveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: state.id) else {
            ELOG("Save state \(state.id) not found in Realm")
            return false
        }

        try! realm.write {
            liveState.lastOpened = Date()
        }

        guard let stateURL = liveState.file?.url, FileManager.default.fileExists(atPath: stateURL.path) else {
            return false
        }

        let completion = {
            self.core.setPauseEmulation(false)
            self.isShowingMenu = false
            self.enableControllerInput(true)  // re-enable input after load
        }

        do {
            try await self.core.loadState(fromFileAtPath: stateURL.path)
            completion()
            return true
        } catch {
            let message = error.localizedDescription
            ELOG("Save state load failed: \(message)")
            // Offer the user a choice: attempt to reset, or continue with potentially
            // corrupted emulator state. This is especially important for cores like PicoDrive
            // where a failed load can leave the core in an inconsistent state.
            // Note: retro_reset() is best-effort and may not fully recover from
            // retro_unserialize() corruption for all cores.

            // Guard against the case where the view is not in a window (e.g. dismissal timing).
            // If we cannot present the alert, fall through and unpause rather than hanging.
            guard self.view.window != nil else {
                WLOG("Cannot present save-state error alert — view not in window. Continuing.")
                completion()
                return false
            }

            let alertMessage =
                "Failed to load save state: \(message)\n\n" +
                "The emulator may be in an inconsistent state. " +
                "Reset Game will attempt to restore a playable state (best effort, " +
                "may not fully recover all cores)."

            let resetGame = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                var resumed = false

                func resumeOnce(_ value: Bool) {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: value)
                }

                Task { @MainActor in
                    // Fallback in case the alert fails to present or never calls its actions.
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if !resumed {
                        WLOG("Save-state error alert did not complete in time. Continuing without reset.")
                        completion()
                        resumeOnce(false)
                    }
                }

                self.presentMessage(
                    alertMessage,
                    title: "Save State Load Failed",
                    source: self.view,
                    secondaryActionTitle: "Continue",
                    secondaryActionStyle: .cancel,
                    secondaryCompletion: {
                        completion()
                        resumeOnce(false)
                    },
                    defaultActionTitle: "Reset Game",
                    defaultActionStyle: .destructive,
                    completion: {
                        resumeOnce(true)
                    }
                )
            }
            if resetGame {
                self.core.resetEmulation()
                completion()
            }
            return false
        }
    }
}

// MARK: - Save states UI

public extension PVEmulatorViewController {
    func saveStatesViewControllerDone(_: PVSaveStatesViewController) {
        dismiss(animated: true, completion: nil)
        // Don't resume emulation here - the presenting menu handles that.
        // This prevents the game from unpausing when navigating back to the pause menu.
        enableControllerInput(false)
    }
    func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController) async throws -> Bool {
        try await createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot)
    }
    func saveStatesViewControllerOverwriteState(_ saveStatesViewController: PVSaveStatesViewController, state: PVSaveState) async throws -> Bool {
        try await createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot)
    }
    func saveStatesViewController(_: PVSaveStatesViewController, load state: PVSaveState) {
        dismiss(animated: true, completion: nil)
        Task.detached { [weak self] in
            await self?.loadSaveState(state)
        }
    }

    @objc public func showSaveStateMenu() {
        let frozenGame = game.freeze()
        Task.detached { [weak self] in
            guard let self = self else { return }
            await try RomDatabase.sharedInstance.updateSaveStates(forGame: frozenGame)
            await try RomDatabase.sharedInstance.recoverSaveStates(forGame: frozenGame, core: core)
        }
        guard let saveStatesNavController = UIStoryboard(name: "SaveStates", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "PVSaveStatesViewControllerNav") as? UINavigationController else {
            return
        }

        let image = captureScreenshot()

        if let saveStatesViewController = saveStatesNavController.viewControllers.first as? PVSaveStatesViewController {
            // Wrap in AnyRealmCollection to decouple from the @ThreadSafe game's
            // LinkingObjects, preventing Realm thread-safety crashes.
            saveStatesViewController.saveStates = AnyRealmCollection(game.saveStates)
            saveStatesViewController.delegate = self
            saveStatesViewController.screenshot = image
            saveStatesViewController.coreID = core.coreIdentifier
        }

        saveStatesNavController.modalPresentationStyle = .overCurrentContext

#if os(iOS)
        if traitCollection.userInterfaceIdiom == .pad {
            saveStatesNavController.modalPresentationStyle = .formSheet
        }
#endif
#if os(tvOS)
        saveStatesNavController.modalPresentationStyle = .blurOverFullScreen
#endif
        present(saveStatesNavController, animated: true)
    }
    func convertOldSaveStatesToNewIfNeeded() {
        let fileManager = FileManager.default
        let saveStatePath = self.saveStatePath
        let infoURL = saveStatePath.appendingPathComponent("Info.plist", isDirectory: false)
        let autoSaveURL = saveStatePath.appendingPathComponent("auto.svs", isDirectory: false)
        let saveStateURLs = (0 ... 4).map { saveStatePath.appendingPathComponent("\($0).svs", isDirectory: false) }

        if fileManager.fileExists(atPath: infoURL.path) {
            do {
                try fileManager.removeItem(at: infoURL)
            } catch {
                presentError("Unable to remove old save state Info.plist: \(error.localizedDescription)", source: self.view)
            }
        }

        guard let realm = try? Realm() else {
            ELOG("Realm() failed")
            return
        }
        
        if fileManager.fileExists(atPath: autoSaveURL.path) {
            do {
                guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
                    presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
                    return
                }

                let newURL = saveStatePath.appendingPathComponent("\(game.md5Hash).\(Date().timeIntervalSinceReferenceDate)")
                try fileManager.moveItem(at: autoSaveURL, to: newURL)
                let saveFile = PVFile(withURL: newURL)
                let newState = PVSaveState(withGame: game, core: core, file: saveFile, image: nil, isAutosave: true)
                try realm.write {
                    realm.add(newState)
                }
            } catch {
                presentError("Unable to convert autosave to new format: \(error.localizedDescription)", source: self.view)
            }
        }

        for url in saveStateURLs {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
                        presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
                        return
                    }

                    let newURL = saveStatePath.appendingPathComponent("\(game.md5Hash).\(Date().timeIntervalSinceReferenceDate)")
                    try fileManager.moveItem(at: url, to: newURL)
                    let saveFile = PVFile(withURL: newURL)
                    let newState = PVSaveState(withGame: game, core: core, file: saveFile, image: nil, isAutosave: false)
                    try realm.write {
                        realm.add(newState)
                    }
                } catch {
                    presentError("Unable to convert autosave to new format: \(error.localizedDescription)", source: self.view)
                }
            }
        }
    }
}
