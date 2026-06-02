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
import RealmSwift
import PVLibrary
import PVSettings
#if os(tvOS)
import PVFileSystem
import PVHashing
#endif

public protocol PVEmualatorControllerProtocol: AnyObject {
    typealias QuitCompletion = () -> Void

    init(game: PVGame, core: PVEmulatorCore)

    // MARK: Memebers
    var core: PVEmulatorCore { get }
    var game: PVGame! { get }

    // MARK: UI
    var isShowingMenu: Bool  { get set }

    // MARK: Audio
    var audioInited: Bool { get }
    var gameAudio: any AudioEngineProtocol { get }

    // MARK: Timers
    var autosaveTimer: Timer?  { get }

    var controllerViewController: (any ControllerVC)? { get }
    func controllerPauseButtonPressed(_ sender: Any?)

    // MARK: - Methods

    // MARK: Screenshots
    func captureScreenshot() -> UIImage?

    // MARK: Saves
    func quit(optionallySave canSave: Bool, completion: QuitCompletion?) async
    func quicksave() async throws -> Bool
    func quickload() async throws -> Bool
    func autoSaveState() async throws -> Bool

    func takeScreenshot()

    // MARK: Menus
    func hideOrShowMenuButton()
    func showCoreOptions()
    func showMoreInfo()
    func hideMoreInfo()
    func showMenu(_ sender: AnyObject?)
    func hideMenu()
    func showSpeedMenu()
    func showSwapDiscsMenu()

    // MARK: - Database (abstracted for SwiftData migration #2510)

    /// The persistence service used to register save states in the database.
    ///
    /// Defaults to ``RomDatabase/sharedInstance`` (Realm).  Override to inject a
    /// different backend (e.g. `SwiftDataSaveStatePersistenceService` from #2510,
    /// or a mock for testing).
    var saveStatePersistenceService: any SaveStatePersistenceServiceProtocol { get }
}

public extension PVEmualatorControllerProtocol {
    /// Default implementation returns the shared Realm-backed database.
    /// Override this property to substitute a SwiftData or test backend.
    var saveStatePersistenceService: any SaveStatePersistenceServiceProtocol {
        RomDatabase.sharedInstance
    }
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
#if os(tvOS)
    private func storeSaveStateScreenshotForTopShelf(from sourceURL: URL, saveStateID: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path),
              let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            return
        }

        let keyHash = "topshelf_savestate_\(saveStateID)".md5Hash
        let destinations: [URL] = [
            groupURL.appendingPathComponent("Documents/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("Caches/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("Library/Caches/PVCache/\(keyHash)")
        ]

        for destinationURL in destinations {
            do {
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                continue
            }
        }
    }
#endif
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
        controllerUserInteractionEnabled = enabled
        PVControllerManager.shared.controllerUserInteractionEnabled = enabled
    }
}

public extension PVEmualatorControllerProtocol {

    @MainActor
    func enableControllerInput(_ enabled: Bool) {
        PVControllerManager.shared.controllerUserInteractionEnabled = enabled
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
    func quicksave() async throws -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw SaveStateError.saveStatesUnsupportedByCore
        }

        DLOG("Performing quick save for \(game.title)")
        let image = captureScreenshot()
        return try await createNewSaveState(auto: false, screenshot: image)
    }

    @discardableResult
    @MainActor
    func quickload() async throws -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw SaveStateError.saveStatesUnsupportedByCore
        }

        // RetroAchievements hardcore mode disallows save-state loads. quickload()
        // bypasses loadSaveState()'s guard (it calls core.loadState directly), so
        // replicate the integrity check here or hardcore unlocks become exploitable.
        // Prefer the view controller's full guard — it adds the
        // `achievementSessionManager != nil` fallback that thin/RetroArch cores need
        // (they report achievementsActive==false but still have a live session). Fall
        // back to a core-level check for any other conformer.
        let hardcoreBlocksLoad: Bool
        if let vc = self as? PVEmulatorViewController {
            hardcoreBlocksLoad = vc.achievementsBlocksSaveStateLoad()
        } else if let achievements = core as? (any CoreRetroAchievements) {
            hardcoreBlocksLoad = achievements.hardcoreMode && achievements.achievementsActive
        } else {
            hardcoreBlocksLoad = false
        }
        if hardcoreBlocksLoad {
            WLOG("QuickLoad blocked: RetroAchievements hardcore mode is active.")
            throw SaveStateError.ineligibleError
        }

        // Get the most recent save state (manual or auto)
        let saveStates = game.saveStates.sorted(byKeyPath: "date", ascending: false)

        guard let latestSaveState = saveStates.first else {
            WLOG("No save states found for \(game.title)")
            throw SaveStateError.noSaveStatesFound
        }

        DLOG("Loading most recent save state for \(game.title) from \(latestSaveState.date)")

        // Load the save state
        guard let saveStateURL = latestSaveState.url else {
            ELOG("Save state file URL is nil")
            throw SaveStateError.saveStateFileNotFound
        }

        try await core.loadState(fromFileAtPath: saveStateURL.path)
        DLOG("Successfully loaded save state")

        return true
    }

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

        guard game.lastAutosaveAge == nil || game.lastAutosaveAge! > PVPrimitives.minutes(1) else {
            ILOG("Last autosave is too new to make new one")
            throw SaveStateError.ineligibleError
        }

        if let latestManualSaveState = game.saveStates.sorted(byKeyPath: "date", ascending: true).last, (latestManualSaveState.date.timeIntervalSinceNow * -1) < PVPrimitives.minutes(1) {
            ILOG("Latest manual save state is too recent to make a new auto save")
            throw SaveStateError.ineligibleError
        }
        let image = captureScreenshot()
        return try await createNewSaveState(auto: true, screenshot: image)
    }

    @MainActor
    func takeScreenshot() {
        if let screenshot = captureScreenshot() {
#if os(iOS)
            if Defaults[.saveScreenshotsToPhotoLibrary] {
                Task.detached {
                    UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
                }
            }
#endif

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


    //    #error ("Use to https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html to save files to iCloud from local url, and setup packages for bundles")
    @MainActor
    @discardableResult
    func createNewSaveState(auto: Bool, screenshot: UIImage?) async throws -> Bool {
        guard core.supportsSaveStates else {
            WLOG("Core \(core.description) doesn't support save states.")
            throw SaveStateError.saveStatesUnsupportedByCore
        }

        guard let rawGame = self.game, !rawGame.isInvalidated else {
            ELOG("createNewSaveState: game is nil or invalidated")
            return false
        }
        let game = rawGame.isFrozen ? rawGame : rawGame.freeze()

        /// Create temporary unmanaged copies of core and game for thread safety
        let coreIdentifier = self.core.coreIdentifier ?? ""
        let gameMD5 = game.md5Hash

        let baseFilename = "\(gameMD5).\(Date().timeIntervalSinceReferenceDate)"
        let saveURL = saveStatePath.appendingPathComponent("\(baseFilename).svs", isDirectory: false)
        let saveFile = PVFile(withURL: saveURL, relativeRoot: .iCloud)

        /// Save state on main thread since it interacts with core.
        /// Run the binary state write BEFORE the .jpg thumbnail write —
        /// otherwise a failed save (e.g. RA wrapper's task_save_handler
        /// silently dropping the write) leaves an orphan thumbnail on disk
        /// that the pause-menu picker shows as a "save state" with no
        /// loadable backing file. Throw early so callers see the real error
        /// and the user gets no ghost row.
        try await core.saveState(toFileAtPath: saveURL.path)
        DLOG("Succeeded saving state, auto: \(auto)")

        var imageFile: PVImageFile?
        #if os(tvOS)
        var localTopShelfImageURL: URL?
        #endif
        if let screenshot = screenshot {
            if let jpegData = screenshot.jpegData(compressionQuality: 0.95) {
                let imageURL = saveStatePath.appendingPathComponent("\(baseFilename).jpg")
                do {
                    // Use atomic write to prevent a partial/corrupt image file if the
                    // process is interrupted between creating and finalising the write.
                    try jpegData.write(to: imageURL, options: .atomic)
                    imageFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
                    #if os(tvOS)
                    localTopShelfImageURL = imageURL
                    #endif
                } catch {
                    if let vc = self as? UIViewController {
                        Task { @MainActor in
                            vc.presentError("Unable to write image to disk, error: \(error.localizedDescription)", source: vc.view)
                        }
                    }
                }
            }
        }

        /// Register the save state in the database via the abstracted persistence service.
        /// This defaults to the Realm-backed RomDatabase today and can be swapped for
        /// a SwiftData implementation when #2510 lands — no changes needed here.
        let saveStateID = try await saveStatePersistenceService.registerSaveState(
            gameID: gameMD5,
            coreIdentifier: coreIdentifier,
            file: saveFile,
            imageFile: imageFile,
            isAutosave: auto
        )

        #if os(tvOS)
        if let localTopShelfImageURL {
            Task.detached(priority: .utility) { [self, localTopShelfImageURL] in
                storeSaveStateScreenshotForTopShelf(from: localTopShelfImageURL, saveStateID: saveStateID)
            }
        }
        #endif

        return true
    }
}

extension PVEmualatorControllerProtocol {
    /// Toggles the pause menu when the controller's pause/menu button is pressed.
    ///
    /// On tvOS there is no on-screen menu button, so the hardware controller must
    /// always be able to open the pause menu. On iOS the behaviour is gated by the
    /// `pauseButtonIsMenuButton` user preference.
    public func controllerPauseButtonPressed(_ sender: Any? = nil) {
        #if os(tvOS)
        let shouldToggle = true
        #else
        let shouldToggle = Defaults[.pauseButtonIsMenuButton]
        #endif
        ILOG("controllerPauseButtonPressed: shouldToggle=\(shouldToggle), isShowingMenu=\(isShowingMenu)")
        guard shouldToggle else { return }
        DispatchQueue.main.async(execute: { () -> Void in
            guard self.core.isOn else {
                ILOG("controllerPauseButtonPressed: core not on, ignoring")
                return
            }
            if !self.isShowingMenu {
                ILOG("controllerPauseButtonPressed: calling showMenu")
                self.showMenu(self)
            } else {
                ILOG("controllerPauseButtonPressed: calling hideMenu")
                self.hideMenu()
            }
        })
    }
}

// MARK: Paths
public extension PVEmualatorControllerProtocol {
    var batterySavesPath: URL { get {return PVEmulatorConfiguration.batterySavesPath(forGame: game) }}
    var BIOSPath: URL { get { return PVEmulatorConfiguration.biosPath(forGame: game) } }
    var saveStatePath: URL { get { PVEmulatorConfiguration.saveStatePath(forGame: game) } }
    var cheatsPath: URL { get { PVEmulatorConfiguration.cheatsPath(forGame: game) } }
}

// MARK: - Audio
public
extension PVEmulatorViewController  {
    @objc func audioSampleRateDidChange() {
        gameAudio.stopAudio()

        try? gameAudio.startAudio()
    }
}
