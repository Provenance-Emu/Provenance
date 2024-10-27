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

public enum SaveStateError: Error {
    case coreSaveError(Error?)
    case coreLoadError(Error?)
    case saveStatesUnsupportedByCore
    case ineligibleError
    case noCoreFound(String)
    case realmWriteError(Error)
    case realmDeletionError(Error)

    var localizedDescription: String {
        switch self {
        case let .coreSaveError(coreError): return "Core failed to save: \(coreError?.localizedDescription ?? "No reason given.")"
        case let .coreLoadError(coreError): return "Core failed to load: \(coreError?.localizedDescription ?? "No reason given.")"
        case .saveStatesUnsupportedByCore: return "This core does not support save states."
        case .ineligibleError: return "Save states are currently ineligible."
        case let .noCoreFound(id): return "No core found to match id: \(id)"
        case let .realmWriteError(realmError): return "Unable to write save state to realm: \(realmError.localizedDescription)"
        case let .realmDeletionError(realmError): return "Unable to delete old auto-save from database: \(realmError.localizedDescription)"
        }
    }
}

public extension PVEmulatorViewController {
    var saveStatePath: URL { get { PVEmulatorConfiguration.saveStatePath(forGame: game) } }

    func destroyAutosaveTimer() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }

    func createAutosaveTimer() {
        autosaveTimer?.invalidate()
        let interval = Defaults[.timedAutoSaveInterval]
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
            if AppState.shared.emulationState.isInBackground {
                return
            }
            Task { @MainActor in
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

    @discardableResult
    func autoSaveState() async throws(SaveStateError) -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw .saveStatesUnsupportedByCore
        }

        /*
         if let lastPlayed = game.lastPlayed, (lastPlayed.timeIntervalSinceNow * -1) < minimumPlayTimeToMakeAutosave {
         ILOG("Haven't been playing game long enough to make an autosave")
         throw .ineligibleError
         return
         }
         */

        guard game.lastAutosaveAge == nil || game.lastAutosaveAge! > minutes(1) else {
            ILOG("Last autosave is too new to make new one")
            throw .ineligibleError
        }

        if let latestManualSaveState = game.saveStates.sorted(byKeyPath: "date", ascending: true).last, (latestManualSaveState.date.timeIntervalSinceNow * -1) < minutes(1) {
            ILOG("Latest manual save state is too recent to make a new auto save")
            throw .ineligibleError
        }
        let image = captureScreenshot()
        return try await createNewSaveState(auto: true, screenshot: image)
    }

    //    #error ("Use to https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html to save files to iCloud from local url, and setup packages for bundles")
    @discardableResult
    func createNewSaveState(auto: Bool, screenshot: UIImage?) async throws(SaveStateError) -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw .saveStatesUnsupportedByCore
        }

        let baseFilename = "\(game.md5Hash).\(Date().timeIntervalSinceReferenceDate)"

        let saveURL = saveStatePath.appendingPathComponent("\(baseFilename).svs", isDirectory: false)
        let saveFile = PVFile(withURL: saveURL, relativeRoot: .iCloud)

        var imageFile: PVImageFile?
        if let screenshot = screenshot {
            if let jpegData = screenshot.jpegData(compressionQuality: 0.85) {
                let imageURL = saveStatePath.appendingPathComponent("\(baseFilename).jpg")
                do {
                    try jpegData.write(to: imageURL)
                    //                    try RomDatabase.sharedInstance.writeTransaction {
                    //                        let newFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
                    //                        game.screenShots.append(newFile)
                    //                    }
                } catch {
                    presentError("Unable to write image to disk, error: \(error.localizedDescription)", source: self.view)
                }

                imageFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
            }
        }

        do {
            try await core.saveState(toFileAtPath: saveURL.path)
        } catch {
            throw .coreSaveError(error)
        }

        DLOG("Succeeded saving state, auto: \(auto)")
        let realm = RomDatabase.sharedInstance.realm
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: self.core.coreIdentifier) else {
            throw .noCoreFound(self.core.coreIdentifier ?? "nil")
        }

//        Task {
            do {
                let realm = RomDatabase.sharedInstance.realm

                var saveState: PVSaveState!

                try realm.write {
                    saveState = PVSaveState(withGame: self.game, core: core, file: saveFile, image: imageFile, isAutosave: auto)
                    realm.add(saveState)
                }

                LibrarySerializer.storeMetadata(saveState, completion: { result in
                    switch result {
                    case let .success(url):
                        ILOG("Serialized save state metadata to (\(url.path))")
                    case let .error(error):
                        ELOG("Failed to serialize save metadata. \(error)")
                    }
                })
            } catch {
                throw SaveStateError.realmWriteError(error)
            }
//        }


        do {
            // Delete the oldest auto-saves over 5 count
            try realm.write {
                let autoSaves = self.game.autoSaves
                if autoSaves.count > 5 {
                    autoSaves.suffix(from: 5).forEach {
                        DLOG("Deleting old auto save of \($0.game.title) dated: \($0.date.description)")
                        realm.delete($0)
                    }
                }
            }
        } catch {
            throw .realmDeletionError(error)
        }

        // All done successfully
        return true
    }

    func loadSaveState(_ state: PVSaveState) async -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            return false
        }

        let realm = RomDatabase.sharedInstance.realm
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
            return false
        }

        // Create a function to use later
        let loadOk = {
        }

        let loadSave = Task.init { () -> Bool in
            try! realm.write {
                state.lastOpened = Date()
            }
            if !FileManager.default.fileExists(atPath: state.file.url.path) {
                return false
            }

            let completion = {
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableControllerInput(false)
            }

            do {
                try await self.core.loadState(fromFileAtPath: state.file.url.path)
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

        if await !FileManager.default.fileExists(atPath: state.file.url.path) {
            let message =
                """
                Save State is not valid
                Please try another save state
                """
            presentWarning(message, source: self.view, completion: loadOk)
            return await loadSave.value
        }
        if core.projectVersion != state.createdWithCoreVersion {
            Task.detached { @MainActor [weak self] in
                guard let self = self else { return }
                let message =
                """
                Save state created with version \(state.createdWithCoreVersion ?? "nil") but current \(core.projectName) core is version \(core.projectVersion).
                Save file may not load. Create a new save state to avoid this warning in the future.
                """
                presentWarning(message, source: self.view, completion: loadOk)
            }
            return await loadSave.value
        } else {
            return await loadSave.value
        }
    }
}

// MARK: - Save states UI

public extension PVEmulatorViewController {
    func saveStatesViewControllerDone(_: PVSaveStatesViewController) {
        dismiss(animated: true, completion: nil)
        core.setPauseEmulation(false)
        isShowingMenu = false
        enableControllerInput(false)
    }
    func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController) async throws -> Bool {
        try await createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot)
    }
    func saveStatesViewControllerOverwriteState(_ saveStatesViewController: PVSaveStatesViewController, state: PVSaveState) async throws(SaveStateError) -> Bool {
        try await createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot)
    }
    func saveStatesViewController(_: PVSaveStatesViewController, load state: PVSaveState) {
        dismiss(animated: true, completion: nil)
        Task.detached { [weak self] in
            await self?.loadSaveState(state)
        }
    }

    @objc func showSaveStateMenu() {
        Task.detached { [weak self] in
            guard let self = self else { return }
            await updateSaveStates()
            await recoverSaveStates()
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

        let realm = RomDatabase.sharedInstance.realm

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
    
    func recoverSaveStates() {
        do {
            let fileManager = FileManager.default
            let directoryContents = try fileManager.contentsOfDirectory(
                at: saveStatePath,
                includingPropertiesForKeys:[.contentModificationDateKey]
            ).filter { $0.lastPathComponent.hasSuffix(".svs") }
                .sorted(by: {
                    let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                    let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                    return date0.compare(date1) == .orderedAscending
                })
            let realm = RomDatabase.sharedInstance.realm
            var saves:[String:Int]=[:]
            for saveState in game.saveStates {
                saves[saveState.file.url.lastPathComponent.lowercased()] = 1;
            }
            for url in directoryContents {
                let file = url.lastPathComponent.lowercased()
                if (fileManager.fileExists(atPath: url.path) &&
                    file.contains("svs") &&
                    !file.contains("json") &&
                    !file.contains("jpg") &&
                    saves.index(forKey: file) == nil) {
                    do {
                        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
                            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
                            return
                        }
                        let imgFile = PVImageFile(withURL:  URL(fileURLWithPath: url.path.replacingOccurrences(of: "svs", with: "jpg")))
                        let saveFile = PVFile(withURL: url)
                        let newState = PVSaveState(withGame: game, core: core, file: saveFile, image: imgFile, isAutosave: false)
                        try realm.write {
                            realm.add(newState)
                        }
                    } catch {
                        ELOG(error.localizedDescription)
                    }
                }
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }
    
    func updateSaveStates() {
        do {
            for save in game.saveStates {
                if !FileManager.default.fileExists(atPath: save.file.url.path) {
                    try PVSaveState.delete(save)
                }
            }
            for save in game.autoSaves {
                if !FileManager.default.fileExists(atPath: save.file.url.path) {
                    try PVSaveState.delete(save)
                }
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }
}
