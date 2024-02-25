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
import UIKit

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

public enum SaveResult {
    case success
    case error(SaveStateError)
}

public typealias SaveCompletion = (SaveResult) -> Void
public typealias LoadCompletion = SaveCompletion

extension PVEmulatorViewController {
    var saveStatePath: URL { return PVEmulatorConfiguration.saveStatePath(forGame: game) }

    func destroyAutosaveTimer() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }

    func createAutosaveTimer() {
        autosaveTimer?.invalidate()
        let interval = PVSettingsModel.shared.timedAutoSaveInterval
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
            if let app=UIApplication.shared as? PVApplication,
               app.isInBackground {
                return
            }
            DispatchQueue.main.async {
                let image = self.captureScreenshot()
                self.createNewSaveState(auto: true, screenshot: image) { result in
                    switch result {
                    case .success: break
                    case let .error(error):
                        ELOG("Autosave timer failed to make save state: \(error.localizedDescription)")
                    }
                }
            }
        })
    }

    func autoSaveState(completion: @escaping SaveCompletion) {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            completion(.error(.saveStatesUnsupportedByCore))
            return
        }

        /*
        if let lastPlayed = game.lastPlayed, (lastPlayed.timeIntervalSinceNow * -1) < minimumPlayTimeToMakeAutosave {
            ILOG("Haven't been playing game long enough to make an autosave")
            completion(.error(.ineligibleError))
            return
        }
         */

        guard game.lastAutosaveAge == nil || game.lastAutosaveAge! > minutes(1) else {
            ILOG("Last autosave is too new to make new one")
            completion(.error(.ineligibleError))
            return
        }

        if let latestManualSaveState = game.saveStates.sorted(byKeyPath: "date", ascending: true).last, (latestManualSaveState.date.timeIntervalSinceNow * -1) < minutes(1) {
            ILOG("Latest manual save state is too recent to make a new auto save")
            completion(.error(.ineligibleError))
            return
        }
        let image = captureScreenshot()
        createNewSaveState(auto: true, screenshot: image, completion: completion)
    }

    //    #error ("Use to https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html to save files to iCloud from local url, and setup packages for bundles")
    func createNewSaveState(auto: Bool, screenshot: UIImage?, completion: @escaping SaveCompletion) {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            completion(.error(.saveStatesUnsupportedByCore))
            return
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

        core.saveStateToFile(atPath: saveURL.path) { result, error in
            guard result else {
                completion(.error(.coreSaveError(error)))
                return
            }

            DLOG("Succeeded saving state, auto: \(auto)")
            let realm = RomDatabase.sharedInstance.realm
            guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: self.core.coreIdentifier) else {
                completion(.error(.noCoreFound(self.core.coreIdentifier ?? "nil")))
                return
            }

            do {
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
                completion(.error(.realmWriteError(error)))
                return
            }

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
                completion(.error(.realmDeletionError(error)))
                return
            }

            // All done successfully
            completion(.success)
        }
    }

    func loadSaveState(_ state: PVSaveState) {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            return
        }

        let realm = RomDatabase.sharedInstance.realm
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
            return
        }

        // Create a function to use later
        let loadOk = {
        }

        let loadSave = {
            try! realm.write {
                state.lastOpened = Date()
            }
            if !FileManager.default.fileExists(atPath: state.file.url.path) {
                return
            }
            self.core.loadStateFromFile(atPath: state.file.url.path) { success, error in
                let completion = {
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.enableControllerInput(false)
                }

                guard success else {
                    let message = error?.localizedDescription ?? "Unknown error"
                    self.presentError("Failed to load save state. " + message, source: self.view, completion: completion)
                    return
                }

                completion()
            }
        }

        if !FileManager.default.fileExists(atPath: state.file.url.path) {
            let message =
                """
                Save State is not valid
                Please try another save state
                """
            presentWarning(message, source: self.view, completion: loadOk)
            return
        }
        if core.projectVersion != state.createdWithCoreVersion {
            loadSave()
            let message =
                """
                Save state created with version \(state.createdWithCoreVersion ?? "nil") but current \(core.projectName) core is version \(core.projectVersion).
                Save file may not load. Create a new save state to avoid this warning in the future.
                """
            presentWarning(message, source: self.view, completion: loadOk)
        } else {
            loadSave()
        }
    }
}

// MARK: - Save states UI

extension PVEmulatorViewController {
    func saveStatesViewControllerDone(_: PVSaveStatesViewController) {
        dismiss(animated: true, completion: nil)
        core.setPauseEmulation(false)
        isShowingMenu = false
        enableControllerInput(false)
    }

    func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController, completion: @escaping SaveCompletion) {
        createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot, completion: completion)
    }

    func saveStatesViewControllerOverwriteState(_ saveStatesViewController: PVSaveStatesViewController, state: PVSaveState, completion: @escaping SaveCompletion) {
        createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot) { result in
            switch result {
            case .success:
                do {
                    try PVSaveState.delete(state)
                    completion(.success)
                } catch {
                    completion(.error(.realmDeletionError(error)))
                }
            case .error:
                completion(result)
            }
        }
    }

    func saveStatesViewController(_: PVSaveStatesViewController, load state: PVSaveState) {
        dismiss(animated: true, completion: nil)
        loadSaveState(state)
    }

    @objc func showSaveStateMenu() {
        updateSaveStates()
        recoverSaveStates()
        guard let saveStatesNavController = UIStoryboard(name: "SaveStates", bundle: nil).instantiateViewController(withIdentifier: "PVSaveStatesViewControllerNav") as? UINavigationController else {
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
        let infoURL = saveStatePath.appendingPathComponent("info.plist", isDirectory: false)
        let autoSaveURL = saveStatePath.appendingPathComponent("auto.svs", isDirectory: false)
        let saveStateURLs = (0 ... 4).map { saveStatePath.appendingPathComponent("\($0).svs", isDirectory: false) }

        if fileManager.fileExists(atPath: infoURL.path) {
            do {
                try fileManager.removeItem(at: infoURL)
            } catch {
                presentError("Unable to remove old save state info.plist: \(error.localizedDescription)", source: self.view)
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
                        NSLog(error.localizedDescription)
                    }
                }
            }
        } catch {
            print(error)
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
            print(error)
        }
    }
}
