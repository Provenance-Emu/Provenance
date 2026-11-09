//
//  EmulatorSessionHost.swift
//  PVUI
//
//  What a session feature (and the skin input handler, the pause menu, the
//  launch flow) sees of `PVEmulatorViewController`. Formerly
//  `PVEmualatorControllerProtocol`, which survives as a typealias until the
//  host thinning's last step; its protocol extensions stay in
//  `PVEmulatorControllerProtocol.swift`.
//

import PVCoreAudio
import PVEmulatorCore
import PVLibrary
#if canImport(UIKit)
import UIKit
#endif

public protocol EmulatorSessionHost: AnyObject {
    typealias QuitCompletion = () -> Void

    init(game: PVGame, core: PVEmulatorCore)

    // MARK: Members
    var core: PVEmulatorCore { get }
    var game: PVGame! { get }

    // MARK: UI
    var isShowingMenu: Bool { get set }
    /// `true` once `quit()` has begun; timers and observers must not start work after this.
    var isQuitting: Bool { get }
    /// The view controller that presents the core's picture. HUDs that sit on the picture
    /// (the performance HUD) attach to its view; it also reports draw timing.
    var gpuViewController: PVGPUViewController { get }

    // MARK: Audio
    var audioInited: Bool { get }
    var gameAudio: any AudioEngineProtocol { get }

    // MARK: Timers
    var autosaveTimer: Timer? { get }

    /// Sends skin, overlay, keyboard and pause-menu input to the core.
    var coreInputHandler: DeltaSkinInputHandler { get }
    func controllerPauseButtonPressed(_ sender: Any?)

    // MARK: Features

    /// The registered session feature of `type`, if it applies to this session.
    func feature<T: EmulatorSessionFeature>(_ type: T.Type) -> T?

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
