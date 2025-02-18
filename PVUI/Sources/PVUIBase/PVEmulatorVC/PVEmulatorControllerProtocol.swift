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
    func controllerPauseButtonPressed(_ sender: Any?)

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
    func showMenu(_ sender: AnyObject?)
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
public extension PVEmualatorControllerProtocol where Self: GCEventViewController {

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
        controllerUserInteractionEnabled = enabled
        PVControllerManager.shared.controllerUserInteractionEnabled = enabled
#endif
    }
}

public extension PVEmualatorControllerProtocol {

    @MainActor
    func enableControllerInput(_ enabled: Bool) {
#if !os(tvOS)
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
    @MainActor
    func autoSaveState() async throws -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw SaveStateError.saveStatesUnsupportedByCore
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
            throw SaveStateError.ineligibleError
        }

        if let latestManualSaveState = game.saveStates.sorted(byKeyPath: "date", ascending: true).last, (latestManualSaveState.date.timeIntervalSinceNow * -1) < minutes(1) {
            ILOG("Latest manual save state is too recent to make a new auto save")
            throw SaveStateError.ineligibleError
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
    @MainActor
    @discardableResult
    func createNewSaveState(auto: Bool, screenshot: UIImage?) async throws -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw SaveStateError.saveStatesUnsupportedByCore
        }

        let game = self.game.freeze()

        /// Create temporary unmanaged copies of core and game for thread safety
        let coreIdentifier = self.core.coreIdentifier ?? ""
        let gameMD5 = game.md5Hash

        let baseFilename = "\(gameMD5).\(Date().timeIntervalSinceReferenceDate)"
        let saveURL = saveStatePath.appendingPathComponent("\(baseFilename).svs", isDirectory: false)
        let saveFile = PVFile(withURL: saveURL, relativeRoot: .iCloud)

        var imageFile: PVImageFile?
        if let screenshot = screenshot {
            if let jpegData = screenshot.jpegData(compressionQuality: 0.85) {
                let imageURL = saveStatePath.appendingPathComponent("\(baseFilename).jpg")
                do {
                    try jpegData.write(to: imageURL)
                    imageFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
                } catch {
                    if let vc = self as? UIViewController {
                        Task { @MainActor in
                            vc.presentError("Unable to write image to disk, error: \(error.localizedDescription)", source: vc.view)
                        }
                    }
                }
            }
        }

        /// Save state on main thread since it interacts with core
        try await core.saveState(toFileAtPath: saveURL.path)
        DLOG("Succeeded saving state, auto: \(auto)")

        /// Create the save state in database
        try await RomDatabase.sharedInstance.asyncWriteTransaction {
            let realm = RomDatabase.sharedInstance.realm
            /// Fetch fresh instances of core and game within the write transaction
            guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: coreIdentifier),
                  let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5) else {
                ELOG("no core found for identifier: \(coreIdentifier)")
                return
//                throw SaveStateError.noCoreFound(coreIdentifier)
            }

            /// Create and add the save state
            let saveState = PVSaveState(withGame: game, core: core, file: saveFile, image: imageFile, isAutosave: auto)
            realm.add(saveState)

            /// Store metadata asynchronously
            LibrarySerializer.storeMetadata(saveState) { result in
                switch result {
                case .success(let url):
                    ILOG("Serialized save state metadata to (\(url.path))")
                case .error(let error):
                    ELOG("Failed to serialize save metadata. \(error)")
                }
            }
            
            /// Handle cleanup if this is an auto-save
            if auto {
                self.cleanupOldAutoSaves(for: game)
            }
        }

        return true
    }

    /// Separate function to handle cleanup of old auto-saves
    private func cleanupOldAutoSaves(for game: PVGame) {
        guard let autoSaves = game.thaw()?.autoSaves else { return }
        let realm = RomDatabase.sharedInstance.realm

        if autoSaves.count > 5 {
            // Get saves to delete (keeping the 5 most recent)
            let savesToDelete = Array(autoSaves.sorted(byKeyPath: "date", ascending: false).suffix(from: 5))
            
            for saveState in savesToDelete {
                DLOG("Deleting old auto save of \(saveState.game.title) dated: \(saveState.date.description)")
                realm.delete(saveState)
            }
        }
    }
}

extension PVEmualatorControllerProtocol {
    // Event when "pause" aka `menu` button is pressed
    public func controllerPauseButtonPressed(_ sender: Any? = nil) {
        // If option enabled, toggle the pause menu
        if Defaults[.pauseButtonIsMenuButton] {
            DispatchQueue.main.async(execute: { () -> Void in
                if !self.isShowingMenu {
                    self.showMenu(self)
                } else {
                    self.hideMenu()
                }
            })
        }
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
