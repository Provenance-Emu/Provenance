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
        let finishWithoutLoading = {
            self.core.setPauseEmulation(false)
            self.isShowingMenu = false
            self.enableControllerInput(false)
        }

        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            finishWithoutLoading()
            return false
        }

        // RetroAchievements hardcore mode disallows save-state loads.
        if achievementsBlocksSaveStateLoad() {
            presentError(
                "Save state loading is disabled in RetroAchievements Hardcore Mode.",
                source: view,
                completion: finishWithoutLoading
            )
            return false
        }

        guard let realm = try? await Realm() else {
            ELOG("Realm() failed")
            finishWithoutLoading()
            return false
        }
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view, completion: finishWithoutLoading)
            return false
        }

        let loadSave = Task.init { @MainActor () -> Bool in
            try! realm.write {
                state.lastOpened = Date()
            }
            if let url = state.file!.url, !FileManager.default.fileExists(atPath: url.path) {
                return false
            }

            let completion = {
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableControllerInput(false)
            }

            do {
                try await self.core.loadState(fromFileAtPath: state.file!.url!.path)
                completion()
                return true
            } catch {
                Task.detached { @MainActor in
                    let message = error.localizedDescription
                    self.presentError("Failed to load save state. " + message, source: self.view, completion: completion)
                }
                return false
            }
        }

        if let url = state.file?.url, !FileManager.default.fileExists(atPath: url.path) {
            let message =
                """
                Save State is not valid
                Please try another save state
                """
            presentWarning(message, source: self.view, completion: finishWithoutLoading)
            return false
        }

        let decision = await confirmSaveStateLoadIfNeeded(state, currentCore: core, allowsStartWithoutSave: false)
        guard decision == .loadAnyway else {
            finishWithoutLoading()
            return false
        }

        return await loadSave.value
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
            saveStatesViewController.saveStates = game.saveStates
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
