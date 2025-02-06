//
//  PVEmulatorControllerProtocol.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2/6/25.
//

import PVAudio
import PVCoreAudio
import PVEmulatorCore
import PVCoreBridge

public protocol PVEmualatorControllerProtocol: AnyObject {
    typealias QuitCompletion = () -> Void

    init(game: PVGame, core: PVEmulatorCore)
    
    // MARK: Memebers
    var core: PVEmulatorCore { get }
    var game: PVGame { get }

    // MARK: UI
    var isShowingMenu: Bool  { get set }
    
    // MARK: Audio
    var audioInited: Bool { get }
    var gameAudio: any AudioEngineProtocol { get }
    
    // MARK: Timers
    var autosaveTimer: Timer?  { get }
    var gameStartTime: Date?  { get }
    
    var controllerViewController: (UIViewController & StartSelectDelegate)? { get }
    func controllerPauseButtonPressed()

    // MARK: - Methods
    
    // MARK: Screenshots
    func captureScreenshot() -> UIImage?
    
    // MARK: Saves
    func quit(optionallySave canSave: Bool, completion: QuitCompletion?) async
    
    // MARK: Menus
    func hideOrShowMenuButton()
    func showCoreOptions()
    func showMoreInfo()
    func hideMoreInfo()
    func hideMenu()
    func showSpeedMenu()
    func showSwapDiscsMenu()
}

public extension PVEmualatorControllerProtocol where Self: UIViewController {
#if os(iOS) && !targetEnvironment(macCatalyst)
    var prefersStatusBarHidden: Bool {
        return true
    }

    var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.left, .right, .bottom]
    }

    var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
#endif
}

// MARK: Core
public extension PVEmualatorControllerProtocol {
    @MainActor
    func initCore() {
        if let audioDelegate = self as? PVAudioDelegate {
            core.audioDelegate = audioDelegate
        }
        core.saveStatesPath = saveStatePath.path
        core.batterySavesPath = batterySavesPath.path
        core.BIOSPath = BIOSPath.path

        core.controller1 = PVControllerManager.shared.player1
        core.controller2 = PVControllerManager.shared.player2
        core.controller3 = PVControllerManager.shared.player3
        core.controller4 = PVControllerManager.shared.player4
        core.controller5 = PVControllerManager.shared.player5
        core.controller6 = PVControllerManager.shared.player6
        core.controller7 = PVControllerManager.shared.player7
        core.controller8 = PVControllerManager.shared.player8

        let md5Hash: String = game.md5Hash
        core.romMD5 = md5Hash
        core.romSerial = game.romSerial

        core.initialize()
    }

    var use_metal: Bool { Defaults[.useMetal] }
}

// MARK: Controllers
public extension PVEmualatorControllerProtocol {
    
    @MainActor
    func enableControllerInput(_ enabled: Bool) {
#if os(tvOS)
        controllerUserInteractionEnabled = enabled
#else
        // Can enable when we change to iOS 10 base
        // and change super class to GCEventViewController
        //    if (@available(iOS 10, *)) {
        //        self.controllerUserInteractionEnabled = enabled;
        //    }
        PVControllerManager.shared.controllerUserInteractionEnabled = enabled
#endif
    }
}

// MARK: Paths
public extension PVEmualatorControllerProtocol {
    func documentsPath() -> String? {
        //#if os(tvOS)
        //        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        //#else
        //        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        //#endif
        //        let documentsDirectoryPath: String = paths[0]
        //        return documentsDirectoryPath
        URL.documentsPath.path()
    }
}

// MARK: Screenshots
public extension PVEmualatorControllerProtocol {
    
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
    
#if os(iOS)
    func takeScreenshot() {
        if let screenshot = captureScreenshot() {
            Task.detached {
                UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
            }
            
            if let pngData = screenshot.pngData() {
                let dateString = PVEmulatorConfiguration.string(fromDate: Date())
                
                let fileName = self.game.title + " - " + dateString + ".png"
                let imageURL = PVEmulatorConfiguration.screenshotsPath(forGame: self.game).appendingPathComponent(fileName, isDirectory: false)
                do {
                    try pngData.write(to: imageURL)
                    RomDatabase.sharedInstance.asyncWriteTransaction {
                        self.game.realm?.refresh()
                        let newFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
                        self.game.screenShots.append(newFile)
                    }
                } catch {
                    ELOG("Unable to write image to disk, error: \(error.localizedDescription)")
                }
            }
        }
        core.setPauseEmulation(false)
        isShowingMenu = false
    }
    
#endif
    
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
                    if let vc = self as? UIViewController {
                        Task { @MainActor in
                            vc.presentError("Unable to write image to disk, error: \(error.localizedDescription)", source: vc.view)
                        }
                    }
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

}

// MARK: Paths
public extension PVEmualatorControllerProtocol {
    var batterySavesPath: URL { get {return PVEmulatorConfiguration.batterySavesPath(forGame: game) }}
    var BIOSPath: URL { get { return PVEmulatorConfiguration.biosPath(forGame: game) } }
    var saveStatePath: URL { get { PVEmulatorConfiguration.saveStatePath(forGame: game) } }
}

// MARK: - Audio
public
extension PVEmulatorViewController  {
    @objc func audioSampleRateDidChange() {
        gameAudio.stopAudio()
        
        try? gameAudio.startAudio()
    }
}
