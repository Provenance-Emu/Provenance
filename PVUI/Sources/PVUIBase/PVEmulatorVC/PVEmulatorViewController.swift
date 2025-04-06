//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVEmulatorViewController.swift
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import QuartzCore
import RealmSwift
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import ZipArchive
import PVEmulatorCore
import PVCoreBridge
import PVAudio
import PVCoreAudio
import PVThemes
import PVSettings
import PVRealm
import PVLogging
import Combine
import MBProgressHUD

private weak var staticSelf: PVEmualatorControllerProtocol?

func uncaughtExceptionHandler(exception _: NSException?) {
    if let staticSelf = staticSelf, staticSelf.core.supportsSaveStates {
        Task.detached(priority: .utility) { @MainActor in
            do {
                try await staticSelf.autoSaveState()
            } catch {
                ELOG("AutoSave error: \(error.localizedDescription)")
            }
        }
    }
}

#if os(tvOS)
public
typealias PVEmulatorViewControllerRootClass = GCEventViewController
#else
public
typealias PVEmulatorViewControllerRootClass = UIViewController
#endif

public
final class PVEmulatorViewController: PVEmulatorViewControllerRootClass, PVEmualatorControllerProtocol, PVAudioDelegate, PVSaveStatesViewControllerDelegate {


    public let core: PVEmulatorCore
    @ThreadSafe
    public var game: PVGame!
    public internal(set) var autosaveTimer: Timer?
    public internal(set) var gameStartTime: Date?
    // Store a reference to the skin container view
    internal var skinContainerView: UIView?

    // Store the current target frame for positioning
    internal var currentTargetFrame: CGRect?

    // Store the original calculated frame for reset functionality
    internal var originalCalculatedFrame: CGRect?

    // Store cancellables for skin loading observation
    internal var skinLoadingCancellable: AnyCancellable?

    // Store the current skin for rotation handling
    internal var currentSkin: DeltaSkinProtocol?

    // Track current orientation
    internal var currentOrientation: SkinOrientation = .portrait

    // Keep track of whether we've positioned the GPU view
    internal static var hasPositionedGPUView = false

    // Property to track skin hosting controllers - using UIViewController for type flexibility
    internal var skinHostingControllers: [UIViewController] = []

    // Shared input handler to maintain input state across skin changes
    internal var sharedInputHandler: DeltaSkinInputHandler?
    
    internal var audioVisualizerHostingController: UIHostingController<AnyView>? = nil
    
    /// The current visualizer mode
    internal var visualizerMode: VisualizerMode = .off {
        didSet {
            if visualizerMode == .off {
                removeAudioVisualizer()
            } else {
                setupAudioVisualizer()
            }
            // Save the new mode to user defaults
            visualizerMode.saveToUserDefaults()
        }
    }

    // Debug overlay view
    internal var debugOverlayView: UIView?
    internal var debugInfoLabel: UILabel?
    internal var debugUpdateTimer: Timer?

    var menuButton: MenuButton?

    private(set) lazy var gpuViewController: PVGPUViewController = {
        let useMetal = (use_metal && !core.alwaysUseGL) || core.alwaysUseMetal
        return useMetal ? PVMetalViewController(withEmulatorCore: core) : PVGLViewController(withEmulatorCore: core)
    }()

    private(set) lazy public var controllerViewController: (any ControllerVC)? = {
        guard let system = game.system else {
            ELOG("Nil system for \(game.title)")
            return nil
        }
        let controller = PVCoreFactory.controllerViewController(forSystem: system, core: core)
        return controller
    }()

#if os(tvOS)
    public override var preferredUserInterfaceStyle: UIUserInterfaceStyle { ThemeManager.shared.currentPalette.dark ? .dark : .light }
#endif

    public var audioInited: Bool = false
    public private(set) lazy var gameAudio: any AudioEngineProtocol = {
        audioInited = true

        let engineOption = Defaults[.audioEngine]
        return engineOption.makeAudioEngine()
    }()

    var fpsTimer: Timer?
    lazy var fpsLabel: UILabel = {
        let fpsLabel = UILabel()
        fpsLabel.textColor = .yellow.withAlphaComponent(0.8)
        fpsLabel.shadowColor = .white.withAlphaComponent(0.75)
        fpsLabel.shadowOffset = .init(width: 0, height: 1)
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        fpsLabel.backgroundColor = .black.withAlphaComponent(0.25)
        fpsLabel.textAlignment = .right
        fpsLabel.isOpaque = false
        fpsLabel.numberOfLines = 5
#if os(tvOS)
        fpsLabel.font = .monospacedSystemFont(ofSize: 26, weight: .light)
#else
        fpsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .light)
#endif
        return fpsLabel
    }()
    var secondaryScreen: UIScreen?
    var secondaryWindow: UIWindow?
    var menuGestureRecognizer: UITapGestureRecognizer?

    public var isShowingMenu: Bool = false {
        willSet {
            DispatchQueue.main.async { [self] in
                if newValue == true {
                    if (!core.skipLayout) {
                        core.setPauseEmulation(true)
                    }
                }
                core.setPauseEmulation(newValue)
            }
        }
        didSet {
            DispatchQueue.main.async { [self] in
                if isShowingMenu == false {
                    if (!core.skipLayout) {
                        core.setPauseEmulation(false)

                        if let metalVC = gpuViewController as? PVMetalViewController {
                            metalVC.safelyRefreshGPUView()
                        }
                    }
                }
                core.setPauseEmulation(isShowingMenu)
            }
        }
    }

    let minimumPlayTimeToMakeAutosave: Double = 60

    required public init(game: PVGame, core: PVEmulatorCore) {
        self.core = core
        self.game = game

        super.init(nibName: nil, bundle: nil)


        let emulationUIState = AppState.shared.emulationUIState
        emulationUIState.core = core
        if (emulationUIState.emulator == nil) {
            emulationUIState.emulator = self
        }
        // Update the singleton state
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = core.coreIdentifier ?? ""
                state.systemName = core.systemIdentifier ?? ""
                state.isOn = true
            }
        }
        PVControllerManager.shared.hasLayout=false
        if core.skipLayout {
            gpuViewController.dismiss(animated: false)
        } else if core.alwaysUseMetal && !core.alwaysUseGL {
            gpuViewController = PVMetalViewController(withEmulatorCore: core)
        }

        staticSelf = self

        if Defaults[.autoSave] {
            NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }

        // Add KVO watcher for isRunning state so we can update play time
        core.addObserver(self, forKeyPath: "isRunning", options: .new, context: nil)
    }

    public override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "isRunning" {
#if os(tvOS) && canImport(SteamController)
            PVControllerManager.shared.setSteamControllersMode(core.isRunning ? .gameController : .keyboardAndMouse)
#endif
            if core.isRunning {
                if gameStartTime != nil {
                    ELOG("Didn't expect to get a KVO update of isRunning to true while we still have an unflushed gameStartTime variable")
                }
                gameStartTime = Date()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.updatePlayedDuration()
                }
            }
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // These need to be first or mutli-threaded cores can cause crashes on close
        NotificationCenter.default.removeObserver(self)
        //        Task { @MainActor in
        //            core.stopEmulation()
        //        }
        // Leave emulation loop first
        if audioInited {
            gameAudio.stopAudio()
        }
        NSSetUncaughtExceptionHandler(nil)
        staticSelf = nil
        gpuViewController.dismiss(animated: false)
        controllerViewController?.dismiss(animated: false)
        core.touchViewController=nil
#if os(iOS) || os(tvOS)
        Task.detached { @MainActor in
            PVControllerManager.shared.controllers.forEach { $0.clearPauseHandler() }
        }
#endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }

        Task { @MainActor in
            let emulationUIState = AppState.shared.emulationUIState

            emulationUIState.core = nil
            emulationUIState.emulator = nil
        }
        core.removeObserver(self, forKeyPath: "isRunning")
    }

    private func initNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.screenDidConnect(_:)), name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.screenDidDisconnect(_:)), name: UIScreen.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handleControllerManagerControllerReassigned(_:)), name: .PVControllerManagerControllerReassigned, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handlePause(_:)), name: Notification.Name("PauseGame"), object: nil)

        // Observer for Delta skin menu button reconnection
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.reconnectDeltaSkinMenuHandler(_:)), name: Notification.Name("DeltaSkinReconnectMenuHandler"), object: nil)

        // Observer for refreshing Delta skin after a skin change
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handleDeltaSkinChanged(_:)), name: Notification.Name("DeltaSkinChanged"), object: nil)
    }

    private func addControllerOverlay() {
        if let aController = controllerViewController {
            addChild(aController)
        }
        if let aView = controllerViewController?.view {
            view.addSubview(aView)
            print("controllerViewController \(controllerViewController), core: \(core)")
            core.touchViewController = controllerViewController
        }
        controllerViewController?.didMove(toParent: self)
    }

    private func initMenuButton() {
        let alpha: CGFloat = CGFloat(Defaults[.controllerOpacity])
        menuButton = MenuButton(type: .custom)
        menuButton?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        menuButton?.setImage(UIImage(named: "button-menu", in: Bundle.module, with: nil), for: .normal)
        menuButton?.setImage(UIImage(named: "button-menu-pressed", in: Bundle.module, with: nil), for: .highlighted)
        // Commenting out title label for now (menu has changed to graphic only)
        // [self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
        // menuButton?.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        // menuButton?.setTitleColor(UIColor.white, for: .normal)
        menuButton?.layer.shadowOffset = CGSize(width: 0, height: 1)
        menuButton?.layer.shadowRadius = 3.0
        menuButton?.layer.shadowColor = UIColor.black.cgColor
        menuButton?.layer.shadowOpacity = 0.75
        menuButton?.tintColor = ThemeManager.shared.currentPalette.defaultTintColor ?? UIColor.white
        menuButton?.alpha = alpha
        menuButton?.addTarget(self, action: #selector(PVEmulatorViewController.showMenu(_:)), for: .touchUpInside)
#if !os(tvOS)
        menuButton?.isPointerInteractionEnabled = true
#endif
        view.addSubview(menuButton!)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = game.title
        view.backgroundColor = UIColor.black
        view.insetsLayoutMarginsFromSafeArea = true

        let emulationState = AppState.shared.emulationUIState

        emulationState.core = core
        if (emulationState.emulator == nil) {
            emulationState.emulator = self
        }

        // Set up the GPU view
        setupGPUView()

        // Set up Delta Skin
        setupDeltaSkinDirectly()

        initNotificationObservers()
        do {
            try createEmulator()
            //            } catch is CreateEmulatorError {
            //                let customError = error as! CreateEmulatorError
            //
            //                presentingViewController?.presentError(customError.localizedDescription, source: self.view)
        } catch {
            let neError = error as NSError

            //                if let presentingViewController = presentingViewController {
            //                    Task { @MainActor in
            //                        presentingViewController.presentError(error.localizedDescription, source: self.view)
            //                    }
            //                } else {
            Task { @MainActor in
                let alert = UIAlertController(title: neError.localizedDescription,
                                              message: neError.localizedRecoverySuggestion,
                                              preferredStyle: .alert)

                alert.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
                alert.popoverPresentationController?.sourceView = self.navigationItem.titleView ?? self.view
                alert.addAction(UIAlertAction(title: "OK",
                                              style: .default,
                                              handler: { (_: UIAlertAction) -> Void in
                    self.dismiss(animated: true, completion: nil)
                }))
                let code = neError.code
                if code == PVEmulatorCoreErrorCode.missingM3U.rawValue {
                    alert.addAction(UIAlertAction(title: "View Wiki", style: .cancel, handler: { (_: UIAlertAction) -> Void in
                        if let url = URL(string: "https://bitly.com/provdiscs") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
                    self?.present(alert, animated: true) { () -> Void in }
                })
            }
            //                }
            return
        }
    }

    private func setupGPUView() {
        // Add the GPU view to the view hierarchy
        view.addSubview(gpuViewController.view)
        gpuViewController.view.frame = view.bounds
        gpuViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    private func createEmulator() throws {
        initCore()

        // Load now. Moved here becauase Mednafen needed to know what kind of game it's working with in order
        // to provide the correct data for creating views.
        let m3uFile: URL? = PVEmulatorConfiguration.m3uFile(forGame: game)
        // TODO: Why are we using `UserDefaults`? @JoeMatt
        // Now I know why, this is how the old library VC would set selected disc


        var romPathMaybe: URL?

        // First check if the user selected a specific related file
        if let selectedDiscFilename = game.selectedDiscFilename {
            let url = URL(fileURLWithPath: selectedDiscFilename, relativeTo: PVEmulatorConfiguration.romDirectory(forSystemIdentifier: game.system?.systemIdentifier ?? .RetroArch))
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                romPathMaybe = url
            }
        }

        // Check for m3uFile or user default set path
        if romPathMaybe == nil {
            romPathMaybe = UserDefaults.standard.url(forKey: game.romPath) ?? m3uFile
        }

        // Finally settle on the single file
        if romPathMaybe == nil {
            romPathMaybe = game.file?.url
        }

#warning("should throw if nil?")
        //        guard let romPath = romPathMaybe else {
        //            throw CreateEmulatorError.gameHasNilRomPath
        //        }

        // Extract Zip before loading the ROM
        romPathMaybe = handleArchives(atPath: romPathMaybe)

        //        guard let romPath = romPathMaybe else {
        //            throw CreateEmulatorError.gameHasNilRomPath
        //        }

        if let romPath = romPathMaybe, needsDownload(romPath) {
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud.label.text = "Downloading \(romPath.lastPathComponent) from iCloud..."
            Task {
                try? await downloadFileIfNeeded(romPath)
            }
            hud.hide(animated: true)
        }

        if let path = romPathMaybe?.path {
            guard FileManager.default.fileExists(atPath: path), !needsDownload(romPathMaybe!) else {
                ELOG("File doesn't exist at path \(path)")

                // Copy path to Pasteboard
#if !os(tvOS)
                UIPasteboard.general.string = path
#endif

                throw CreateEmulatorError.fileDoesNotExist(path: path)
            }
        }

        ILOG("Loading ROM: \(romPathMaybe?.path ?? "null")")

        if let core = core as? any ObjCBridgedCore, let bridge = core.bridge as? EmulatorCoreIOInterface {
            try bridge.loadFile(atPath: romPathMaybe?.path ?? "")
        } else {
            try core.loadFile(atPath: romPathMaybe?.path ?? "")
        }

#warning("TODO: Handle multiple screens with UIScene")
        if UIScreen.screens.count > 1 && !core.skipLayout {
            secondaryScreen = UIScreen.screens[1]
            if let aBounds = secondaryScreen?.bounds {
                secondaryWindow = UIWindow(frame: aBounds)
            }
            if let aScreen = secondaryScreen {
                secondaryWindow?.screen = aScreen
            }
            secondaryWindow?.rootViewController = gpuViewController
            gpuViewController.view?.frame = secondaryWindow?.bounds ?? .zero
            if let aView = gpuViewController.view {
                secondaryWindow?.addSubview(aView)
            }
            secondaryWindow?.isHidden = false
        } else {
#if os(tvOS)
            if core.skipLayout {
                // Special handling for RetroArch cores on tvOS
                addChild(gpuViewController)
                if let gpuView = gpuViewController.view {
                    gpuView.frame = view.bounds
                    gpuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    view.addSubview(gpuView)
                }
                gpuViewController.didMove(toParent: self)
            } else {
                // Keep existing behavior for non-skipLayout cores
                gpuViewController.willMove(toParent: self)
                addChild(gpuViewController)
                if let aView = gpuViewController.view {
                    aView.frame = view.bounds
                    view.addSubview(aView)
                }
                gpuViewController.didMove(toParent: self)
            }
#else
            if (!core.skipLayout) {
                // Keep existing iOS behavior unchanged
                gpuViewController.willMove(toParent: self)
                addChild(gpuViewController)
                // Note: This also initilaizes the view
                // using viewIfLoaded will crash.
                // Should probably imporve this?
                if let aView = gpuViewController.view {
                    aView.frame = view.bounds
                    view.addSubview(aView)
                }
            }
            gpuViewController.didMove(toParent: self)
#endif
        }
#if os(iOS) && !targetEnvironment(macCatalyst) && !os(macOS)
        addControllerOverlay()
        initMenuButton()
#endif

        if Defaults[.showFPSCount] && !core.skipLayout {
            initFPSLabel()
        }

        hideOrShowMenuButton()

        convertOldSaveStatesToNewIfNeeded()

        try gameAudio.setupAudioGraph(for: core)
        try startAudio()

        core.startEmulation()

#if os(tvOS)
        // On tvOS the siri-remotes menu-button will default to go back in the hierachy (thus dismissing the emulator), we don't want that behaviour
        // (we'd rather pause the game), so we just install a tap-recognizer here (that doesn't do anything), and add our own logic in `setupPauseHandler`
        if menuGestureRecognizer == nil {
            menuGestureRecognizer = UITapGestureRecognizer()
            menuGestureRecognizer?.allowedPressTypes = [.menu]
            view.addGestureRecognizer(menuGestureRecognizer!)
        }
#endif
        PVControllerManager.shared.controllers.forEach {
            $0.setupPauseHandler(onPause: {
                NotificationCenter.default.post(name: NSNotification.Name("PauseGame"), object: nil)
            })
        }
        enableControllerInput(false)

        // Update the singleton state
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = core.coreIdentifier ?? ""
                state.systemName = core.systemIdentifier ?? ""
                state.isOn = true
            }
        }
    }

    public override func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)
        // Notifies UIKit that your view controller updated its preference regarding the visual indicator

#if os(iOS)
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
#endif

        if Defaults[.timedAutoSaves] {
            createAutosaveTimer()
        }
        
        // Initialize the audio visualizer based on saved preferences
        if visualizerMode == .off {
            // Load the last used mode from user defaults
            visualizerMode = VisualizerMode.current
        }
        
        // If visualizer is enabled, set it up and ensure it's on top
        if visualizerMode != .off {
            setupAudioVisualizer()
            ensureVisualizerOnTop()
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyAutosaveTimer()
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Handle skin changes for orientation
        handleOrientationChange(to: size, with: coordinator)
    }

#if os(iOS) //&& !targetEnvironment(simulator)
    // Check Controller Manager if it has a Controller connected and thus if Home Indicator should hide…
    public override var prefersHomeIndicatorAutoHidden: Bool {
//        let shouldHideHomeIndicator: Bool = PVControllerManager.shared.hasControllers
//        return shouldHideHomeIndicator
        return true
    }
#endif

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
#if os(iOS)
        layoutMenuButton()
#endif
    }

#if os(iOS) && !targetEnvironment(macCatalyst)
    public override var prefersStatusBarHidden: Bool {
        return true
    }

    public override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.left, .right, .bottom]
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
#endif

    public func quit(optionallySave canSave: Bool = true, completion: QuitCompletion? = nil) async {
        NotificationCenter.default.removeObserver(self)
        NSSetUncaughtExceptionHandler(nil)
        enableControllerInput(false)
        if canSave, Defaults[.autoSave], core.supportsSaveStates {
            do {
                try await autoSaveState()
            } catch {
                ELOG("AutoSave error: \(error.localizedDescription)")
            }
        }
        if audioInited {
            gameAudio.stopAudio()
        }
        core.stopEmulation()
        gpuViewController.dismiss(animated: false)
        if let view = controllerViewController?.view {
            for subview in view.subviews {
                subview.removeFromSuperview()
            }
        }
        controllerViewController?.dismiss(animated: false)
        core.touchViewController = nil
#if os(iOS)
        PVControllerManager.shared.controllers.forEach {
            $0.clearPauseHandler()
        }

#endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }

        let emulationUIState = AppState.shared.emulationUIState

        emulationUIState.core = nil
        emulationUIState.emulator = nil

        let emulationState = AppState.shared.emulationState
        emulationState.isOn = false

        fpsTimer?.invalidate()
        fpsTimer = nil
        dismiss(animated: true, completion: completion)
        self.view?.removeFromSuperview()
        self.removeFromParent()
        staticSelf = nil


        AppState.shared.emulationUIState.reset()
    }

    @objc
    func dismissNav() {
        presentedViewController?.dismiss(animated: true, completion: nil)
        core.setPauseEmulation(false)
        isShowingMenu = false

        // Post notifications to reconnect inputs and refresh the GPU view
        NotificationCenter.default.post(name: NSNotification.Name("DeltaSkinInputHandlerReconnect"), object: nil)

        // Make sure the GPU view is refreshed
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Use the safer method to refresh the GPU view
            metalVC.safelyRefreshGPUView()
        }

        // If using a DeltaSkin, ensure game screen view is visible and positioned properly
        if let skinContainerView = self.view.viewWithTag(9876) {
            // Make sure the GPU view is visible on top of the proper layer
            self.gpuViewController.view.alpha = 1.0
            self.gpuViewController.view.isHidden = false

            // If we have a stored target frame, ensure the GPU view is positioned there
            if let targetFrame = self.currentTargetFrame {
                UIView.animate(withDuration: 0.2) {
                    self.gpuViewController.view.frame = targetFrame
                }
            }
        }

        enableControllerInput(false)
    }
}


extension PVEmulatorViewController: GameplayDurationTrackerUtil {}

// MARK: - Skin Management
extension PVEmulatorViewController {

    /// Apply a skin to the emulator
    /// - Parameter skin: The skin to apply
    public func applySkin(_ skin: DeltaSkinProtocol) async throws {
        print("Applying skin: \(skin.name)")

        // Reset the current target frame to force recalculation for the new skin
        currentTargetFrame = nil

        // Store the current skin for rotation handling
        self.currentSkin = skin

        // IMPORTANT: Use device orientation for skin traits
        // First get the real device orientation
        let deviceOrientation = UIDevice.current.orientation

        // If it's not a valid orientation (face up/down/unknown), use interface orientation
        let validOrientations: [UIDeviceOrientation] = [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]

        let isValidOrientation = validOrientations.contains(deviceOrientation)

        // Determine the current orientation from device or interface orientation
        if isValidOrientation {
            self.currentOrientation = deviceOrientation.isLandscape ? .landscape : .portrait
        } else {
            // Fallback to interface orientation
            let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
            self.currentOrientation = (interfaceOrientation == .landscapeLeft || interfaceOrientation == .landscapeRight) ? .landscape : .portrait
        }

        // Log the orientation we're using
        print("Using orientation for skin application: \(self.currentOrientation)")

        // RADICAL APPROACH: Completely rebuild the view hierarchy
        await MainActor.run {
            // 1. Remove ALL views and controllers except the essential ones
            radicalCleanup()

            // 2. Print the view hierarchy after cleanup to verify it's clean
            print("View hierarchy after radical cleanup:")
            printViewHierarchy(view, level: 0)
        }

        // 3. Create a new skin container with edge-to-edge layout
        let skinContainer = UIView(frame: view.bounds)
        skinContainer.tag = 9876 // Unique tag for skin container views
        skinContainer.isOpaque = false
        skinContainer.backgroundColor = .clear //UIColor.black // Set background to black for retrowave aesthetic
        skinContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight] // Ensure it resizes with parent

        // 4. Add the container at the bottom of the view hierarchy
        await MainActor.run {
            view.addSubview(skinContainer)

            // Store reference to the skin container
            self.skinContainerView = skinContainer
        }

        // 5. Create and add the skin view
        let skinView = try await createSkinView(from: skin)

        await MainActor.run {
            // Add the skin view to the container
            skinContainer.addSubview(skinView)

            // Set the frame to fill the container
            skinView.frame = skinContainer.bounds
            skinView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            // 6. Position the game screen within the skin view at the correct position
            // IMPORTANT: Log the GPU view frame before repositioning
            if let gpuView = gpuViewController.view {
                print("GPU view frame BEFORE repositioning: \(gpuView.frame)")
            } else {
                print("WARNING: GPU view is nil before repositioning!")
            }

            // Force recalculation of screen position for the new skin
            repositionGameScreen(for: skin, orientation: currentOrientation, forceRecalculation: true)

            // Log the GPU view frame after repositioning
            if let gpuView = gpuViewController.view {
                print("GPU view frame AFTER repositioning: \(gpuView.frame)")
            }

            // Ensure proper z-order of all elements
            ensureProperZOrder()

            // Force a layout update
            view.setNeedsLayout()
            view.layoutIfNeeded()

            // 7. Print the final view hierarchy
            print("View hierarchy after applying new skin:")
            printViewHierarchyRecursively(view, level: 0)

            // 8. Post notification that the skin has changed to trigger input handler reconnection
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinChanged"),
                object: nil,
                userInfo: ["skinIdentifier": skin.identifier]
            )

            // Also post a reconnect notification to ensure proper input handling
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
                object: nil
            )

            // Make sure to reconnect all input handlers
            reconnectAllInputHandlers()
        }
    }

    /// Create a SwiftUI view for the skin
    /// - Parameter skin: The skin to create a view for
    /// - Returns: A UIView containing the skin
    private func createSkinView(from skin: DeltaSkinProtocol) async throws -> UIView {
        /// Create traits based on the current device and orientation
        let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone

        // Create display type based on the device
        // For iPhones with notches, use edgeToEdge
        let displayType: DeltaSkinDisplayType = {
            if #available(iOS 11.0, *), UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0 > 0 {
                return .edgeToEdge
            } else {
                return .standard
            }
        }()

        // Create the traits object for the skin
        let traits = DeltaSkinTraits(
            device: currentDevice,
            displayType: displayType,
            orientation: currentOrientation == .landscape ? .landscape : .portrait
        )

        print("Creating skin view with traits: \(traits)")

        // Create an input handler for the skin
        let inputHandler = DeltaSkinInputHandler(
            emulatorCore: core,
            controllerVC: controllerViewController,
            emulatorController: self
        )

        // Store the input handler for reuse
        self.sharedInputHandler = inputHandler

        // Set up menu button handler
        inputHandler.menuButtonHandler = { [weak self] in
            self?.showMenu(nil)
        }

        // Create the skin view with EmulatorWrapperView
        let wrapperView = EmulatorWrapperView(
            game: game,
            coreInstance: core,
            onSkinLoaded: {
                // This is called when the skin is loaded
                print("Skin loaded callback triggered")

                // Force a redraw of the GPU view
                if let metalVC = self.gpuViewController as? PVMetalViewController {
                    metalVC.safelyRefreshGPUView()
                }
            },
            onRefreshRequested: {
                // This is called when a refresh is needed
                print("Refresh requested callback triggered")

                // Force a redraw of the GPU view
                if let metalVC = self.gpuViewController as? PVMetalViewController {
                    metalVC.safelyRefreshGPUView()
                }
            },
            inputHandler: inputHandler
        )

        // Create a UIHostingController to host the SwiftUI view
        let hostingController = UIHostingController(rootView: wrapperView)

        // Add the hosting controller as a child
        await MainActor.run {
            addChild(hostingController)
            hostingController.didMove(toParent: self)

            // Keep track of the hosting controller
            skinHostingControllers.append(hostingController)
        }

        // Get the view from the hosting controller
        let uiView = hostingController.view!

        // Configure the view
        uiView.backgroundColor = UIColor.clear
        uiView.isOpaque = false

        return uiView
    }

    /// Reposition the game screen (GPU view) based on the skin and orientation
    /// - Parameters:
    ///   - skin: The skin to position the game screen for
    ///   - orientation: The current orientation
    ///   - forceRecalculation: Whether to force recalculation of the screen position
    private func repositionGameScreen(for skin: DeltaSkinProtocol, orientation: SkinOrientation, forceRecalculation: Bool = false) {
        // Get the GPU view
        guard let gpuView = gpuViewController.view else {
            print("ERROR: Cannot position game screen - GPU view is nil")
            return
        }

        // If we have a cached target frame and we're not forcing recalculation, use it
        if let targetFrame = currentTargetFrame, !forceRecalculation {
            // Only apply if the frames are significantly different to avoid jitter
            if abs(gpuView.frame.width - targetFrame.width) > 1 ||
               abs(gpuView.frame.height - targetFrame.height) > 1 ||
               abs(gpuView.frame.origin.x - targetFrame.origin.x) > 1 ||
               abs(gpuView.frame.origin.y - targetFrame.origin.y) > 1 {

                print("Using cached target frame: \(targetFrame)")
                gpuView.frame = targetFrame
            }
            return
        }

        // Get screen position information from the skin
        if let screenFrame = getScreenPositionFromSkin(skin, for: orientation) {
            // Convert the relative position to absolute coordinates
            let viewBounds = view.bounds
            let absoluteFrame = CGRect(
                x: viewBounds.width * screenFrame.origin.x,
                y: viewBounds.height * screenFrame.origin.y,
                width: viewBounds.width * screenFrame.size.width,
                height: viewBounds.height * screenFrame.size.height
            )

            // Store the target frame for future reference
            currentTargetFrame = absoluteFrame

            // Store the original calculated frame if we haven't already
            if originalCalculatedFrame == nil {
                originalCalculatedFrame = absoluteFrame
            }

            // Apply the frame to the GPU view
            print("Positioning GPU view at: \(absoluteFrame)")
            gpuView.frame = absoluteFrame

            // Make sure the GPU view is visible
            gpuView.isHidden = false
            gpuView.alpha = 1.0

            // Force a redraw of the GPU view
            if let metalVC = gpuViewController as? PVMetalViewController {
                metalVC.safelyRefreshGPUView()
            }
        } else {
            // Fall back to default positioning (full screen or some reasonable default)
            let defaultFrame: CGRect

            if orientation == .landscape {
                // Default landscape position (centered, 80% of width, maintain aspect ratio)
                let width = view.bounds.width * 0.8
                let height = width * (3.0/4.0) // 4:3 aspect ratio typical for retro games
                let x = (view.bounds.width - width) / 2
                let y = (view.bounds.height - height) / 2
                defaultFrame = CGRect(x: x, y: y, width: width, height: height)
            } else {
                // Default portrait position (centered, 80% of width, maintain aspect ratio)
                let width = view.bounds.width * 0.8
                let height = width * (3.0/4.0) // 4:3 aspect ratio typical for retro games
                let x = (view.bounds.width - width) / 2
                let y = view.bounds.height * 0.2 // Position in upper part of screen
                defaultFrame = CGRect(x: x, y: y, width: width, height: height)
            }

            // Store the target frame
            currentTargetFrame = defaultFrame

            // Store the original calculated frame if we haven't already
            if originalCalculatedFrame == nil {
                originalCalculatedFrame = defaultFrame
            }

            // Apply the frame to the GPU view
            print("Using default positioning for GPU view: \(defaultFrame)")
            gpuView.frame = defaultFrame

            // Make sure the GPU view is visible
            gpuView.isHidden = false
            gpuView.alpha = 1.0
        }
    }

    /// Reconnect all input handlers to ensure they're properly linked after skin changes
    private func reconnectAllInputHandlers() {
        print("Reconnecting all input handlers")

        // Update the shared input handler references
        if let inputHandler = sharedInputHandler {
            print("Updating shared input handler references")

            // Re-link the core, controller, and emulator controller
            inputHandler.setEmulatorCore(core)
            inputHandler.setControllerVC(controllerViewController)
            inputHandler.setEmulatorController(self)

            // Ensure menu button handler is set
            inputHandler.menuButtonHandler = { [weak self] in
                DLOG("Menu button pressed from reconnected handler, showing menu")
                self?.showMenu(nil)
            }

            print("✅ Successfully updated all input handler references")
        }

        // Trigger input handler reconnect notification as well for belt and suspenders
        NotificationCenter.default.post(
            name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
            object: nil
        )
    }

    /// Reset to the default skin
    public func resetToDefaultSkin() async throws {
        print("Resetting to default skin")

        // Clean up any existing skin views and hosting controllers
        await MainActor.run {
            radicalCleanup()
        }
        currentSkin = nil

        // Reset the game screen position to its original position
        await MainActor.run {
            if let originalFrame = originalCalculatedFrame {
                gpuViewController.view.frame = originalFrame
            }
        }

        // Create and apply the default skin
        if let systemId = game.system?.systemIdentifier {
            // Get the default skin for the system
            let defaultSkin = EmulatorWithSkinView.defaultSkin(for: systemId)

            // Apply the skin - this will handle all the UI setup
            try await applySkin(defaultSkin)

            // Post notification that the skin has changed to trigger input handler reconnection
            // This is in addition to the notification sent by applySkin
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DeltaSkinChanged"),
                    object: nil,
                    userInfo: ["skinIdentifier": defaultSkin.identifier, "isDefault": true]
                )
            }
        } else {
            // If we can't load a default skin, still post the reconnect notifications
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DeltaSkinChanged"),
                    object: nil,
                    userInfo: ["isDefault": true]
                )

                NotificationCenter.default.post(
                    name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
                    object: nil
                )
            }
        }
    }

    /// Perform a radical cleanup of the entire view hierarchy
    private func radicalCleanup() {
        print("Performing RADICAL cleanup of view hierarchy")

        // 1. Save reference to essential views we need to keep
        let gpuView = gpuViewController.view

        // 2. Remove ALL child view controllers except the GPU controller
        for child in children {
            if child !== gpuViewController {
                print("Removing controller: \(child)")
                child.willMove(toParent: nil)
                child.view.removeFromSuperview()
                child.removeFromParent()
            }
        }

        // 3. Clear all tracked hosting controllers
        skinHostingControllers.removeAll()

        // 4. Remove ALL subviews from the main view except the GPU view
        for subview in view.subviews {
            if subview !== gpuView {
                print("Removing view: \(subview)")
                subview.removeFromSuperview()
            }
        }

        // 5. Clear the skin container reference and reset target frame
        skinContainerView = nil
        currentTargetFrame = nil  // Reset target frame to force recalculation

        // NOTE: We intentionally DO NOT reset the sharedInputHandler here
        // to maintain input state across skin changes

        // 6. Make sure the GPU view is still in the hierarchy
        if let gpuView = gpuView, gpuView.superview == nil {
            print("Re-adding GPU view")
            view.addSubview(gpuView)
        }

        // 7. Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    /// Debug helper to print the view hierarchy
    private func printViewHierarchy(_ view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)\(view) (tag: \(view.tag))")
        for subview in view.subviews {
            printViewHierarchy(subview, level: level + 1)
        }
    }

    /// Get screen position information based on orientation
    private func getScreenPositionFromSkin(_ skin: DeltaSkinProtocol, for orientation: SkinOrientation) -> CGRect? {
        // Since we can't access the skin's layout directly, we'll use default positions
        // that work well with the retrowave styling and most skins

        // Check if we're dealing with a specific skin type that might have custom positioning
        let skinName = skin.name.lowercased()

        // For landscape orientation
        if orientation == .landscape {
            // Special case for certain skin types
            if skinName.contains("gameboy") || skinName.contains("gb") {
                // Game Boy skins typically have a different aspect ratio
                return CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.7)
            } else if skinName.contains("snes") || skinName.contains("super nintendo") {
                // SNES skins often have the screen positioned higher
                return CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.55)
            } else {
                // Default landscape position
                return CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.6)
            }
        }
        // For portrait orientation
        else {
            // Special case for certain skin types
            if skinName.contains("gameboy") || skinName.contains("gb") {
                // Game Boy skins typically have a different aspect ratio
                return CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.5)
            } else if skinName.contains("snes") || skinName.contains("super nintendo") {
                // SNES skins often have the screen positioned higher
                return CGRect(x: 0.1, y: 0.15, width: 0.8, height: 0.4)
            } else {
                // Default portrait position
                return CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.5)
            }
        }
    }

    /// Ensure proper z-order of views in the hierarchy
    private func ensureProperZOrder() {
        guard let gpuView = gpuViewController.view else { return }
        guard let skinContainer = skinContainerView else { return }

        // First, make sure the GPU view is a direct child of the main view (not the skin container)
        if gpuView.superview !== view {
            gpuView.removeFromSuperview()
            view.addSubview(gpuView)
        }

        // Make sure the skin container is in the view hierarchy
        if skinContainer.superview !== view {
            view.addSubview(skinContainer)
        }

        // We want the game view to be ABOVE the skin container
        // This ensures the game is visible above any skin background elements
        view.bringSubviewToFront(gpuView)
        view.bringSubviewToFront(skinContainer)
        if let visualizerView = audioVisualizerHostingController?.view {
            view.bringSubviewToFront(visualizerView)
        }

        // If we have a menu button, make sure it's on top of everything
        if let menuButton = menuButton {
            view.bringSubviewToFront(menuButton)
        }
    }

    /// Debug print the current view hierarchy for troubleshooting
    private func debugPrintViewHierarchy() {
        print("View hierarchy after applying new skin:")
        printViewHierarchyRecursively(view, level: 0)
    }

    /// Recursively print a view hierarchy for debugging
    private func printViewHierarchyRecursively(_ view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)<\(type(of: view)): \(view); frame = \(view.frame); \(view.tag != 0 ? "tag = \(view.tag); " : "")backgroundColor = \(String(describing: view.backgroundColor)); layer = <\(type(of: view.layer)): \(view.layer)>> (tag: \(view.tag))")

        for subview in view.subviews {
            printViewHierarchyRecursively(subview, level: level + 1)
        }
    }

    // Handle rotation and skin changes
    func handleOrientationChange(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("Handling orientation change to size: \(size)")

        // Determine new orientation
        let newOrientation: SkinOrientation = size.width > size.height ? .landscape : .portrait
        print("New orientation: \(newOrientation)")

        // Only reload skin if orientation changed
        if newOrientation != currentOrientation {
            print("Orientation changed from \(currentOrientation) to \(newOrientation)")

            // Update orientation first
            let oldOrientation = currentOrientation
            currentOrientation = newOrientation

            // Save current skin for reference
            let previousSkin = self.currentSkin

            // Handle rotation in two phases to avoid visual glitches
            coordinator.animate { _ in
                // During animation phase, just reposition the game screen
                // but don't change the skin yet to avoid visual glitches
                if let skin = previousSkin {
                    print("Repositioning game screen during animation")
                    // Force recalculation during rotation to ensure proper positioning
                    self.repositionGameScreen(for: skin, orientation: newOrientation, forceRecalculation: true)
                }
            } completion: { _ in
                // After rotation animation completes, apply the appropriate skin
                Task {
                    do {
                        print("Rotation animation completed, applying appropriate skin")

                        // Get the system and game IDs
                        guard let systemId = self.game.system?.systemIdentifier else { return }
                        let gameId = self.game.md5 ?? self.game.crc

                        // Check if we have a different skin for this orientation
                        // Use DeltaSkinManager which now handles session skins as well as preferences
                        let skinIdentifier = DeltaSkinManager.shared.effectiveSkinIdentifier(
                            for: systemId,
                            gameId: gameId,
                            orientation: newOrientation
                        )

                        print("Effective skin identifier for new orientation: \(skinIdentifier ?? "nil")")
                        print("Current skin identifier: \(self.currentSkin?.identifier ?? "nil")")

                        // Determine if we need to change the skin
                        let needsSkinChange = skinIdentifier != nil &&
                            (self.currentSkin == nil || skinIdentifier != self.currentSkin?.identifier)

                        if needsSkinChange {
                            print("Need to change skin for new orientation")
                            if let skinId = skinIdentifier,
                               let skin = try? await DeltaSkinManager.shared.skin(withIdentifier: skinId) {
                                print("Applying new skin: \(skin.name)")
                                try await self.applySkin(skin)
                            } else {
                                print("Falling back to default skin")
                                try await self.resetToDefaultSkin()
                            }
                        } else if self.currentSkin != nil {
                            print("Using existing skin, need to reapply for proper layout")
                            // We need to do a complete reapplication to ensure proper traits
                            // This fixes issues with skins not drawing correctly after rotation
                            try await self.applySkin(self.currentSkin!)

                            // Ensure the game screen is properly positioned with the correct z-order
                            self.repositionGameScreen(for: self.currentSkin!, orientation: newOrientation, forceRecalculation: true)
                        } else {
                            print("No skin at all, applying default")
                            try await self.resetToDefaultSkin()
                        }

                        // Final check to ensure proper z-order after all changes
                        self.ensureProperZOrder()
                    } catch {
                        print("Error handling orientation change: \(error)")
                    }
                }
            }
        } else {
            print("Orientation didn't change, just repositioning")
            // Even if orientation didn't change, we might need to reposition due to size changes
            if let skin = self.currentSkin {
                self.repositionGameScreen(for: skin, orientation: newOrientation)
            }
        }
    }
}

extension PVEmulatorViewController {

    @objc func appWillEnterForeground(_: Notification?) {
        if (!core.isOn) {
            return;
        }
        Task.detached { @MainActor in
            self.updateLastPlayedTime()
        }
    }

    @objc func appDidEnterBackground(_: Notification?) {}

    @objc func appWillResignActive(_: Notification?) {
        if (!core.isOn) {
            return;
        }
        Task {
            if Defaults[.autoSave], core.supportsSaveStates {
                do {
                    let success = try await autoSaveState()
                    if !success {
                        ELOG("Auto-save failed for unknown reasons")
                    }
                } catch {
                    ELOG("Auto-save failed \(error.localizedDescription)")
                }
            }
        }
        gameAudio.pauseAudio()
        showMenu(self)
    }

    @objc func appDidBecomeActive(_: Notification?) {
        if (!core.isOn) {
            return;
        }
        if !isShowingMenu {
            core.setPauseEmulation(false)
        }
        core.setPauseEmulation(true)

        do {
            // TODO: Test if we need to recreate the audio graph
            try gameAudio.setupAudioGraph(for: core)
            try startAudio()
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }

    fileprivate func startAudio() throws {
        //        gameAudio.outputDeviceID = 0
        gameAudio.setVolume(Defaults[.volume])
        do {
            try gameAudio.startAudio()
        } catch {
            ELOG("\(error.localizedDescription)")
            throw error
        }
        setMono()
    }

    fileprivate func setMono() {
        if let gameAudio = gameAudio as? MonoAudioEngine {
            gameAudio.setMono(Defaults[.monoAudio])
            Task {
                for await value in Defaults.updates(.monoAudio) {
                    gameAudio.setMono(Defaults[.monoAudio])
                }
            }
        }
    }

    // MARK: - Delta Skin Notification Handlers

    /// Handler for reconnecting the menu button handler to the Delta skin input handler
    @objc func reconnectDeltaSkinMenuHandler(_ notification: Notification) {
        ILOG("Reconnecting Delta skin menu button handler")

        // Find the Delta skin input handler
        if let hostingControllers = skinHostingControllers as? [UIHostingController<AnyView>] {
            for hostingController in hostingControllers {
                // Access our skin view and input handler
                // The direct cast won't work due to type erasure with AnyView
                // Instead, we'll look for the shared input handler
                if let inputHandler = sharedInputHandler {
                    DLOG("Found shared input handler, reconnecting menu button handler")

                    // Set the menu button handler to show the menu
                    inputHandler.menuButtonHandler = { [weak self] in
                        DLOG("Menu button pressed through reconnected handler")
                        self?.showMenu(nil)
                    }

                    ILOG("✅ Successfully reconnected menu button handler")
                } else {
                    ELOG("Could not find shared input handler to reconnect menu button")
                }
            }
        } else {
            ELOG("No hosting controllers available for Delta skin menu button reconnection")
        }

        // Additional measure: refresh any input connections
        NotificationCenter.default.post(
            name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
            object: nil
        )
    }

    /// Handler for skin change notifications
    @objc func handleDeltaSkinChanged(_ notification: Notification) {
        ILOG("Handling Delta skin changed notification")

        // After a skin change, ensure the menu button handler is still set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }

            // Reconnect the menu button handler
            if let inputHandler = self.sharedInputHandler {
                inputHandler.menuButtonHandler = { [weak self] in
                    DLOG("Menu button pressed through restored handler")
                    self?.showMenu(nil)
                }

                ILOG("✅ Automatically restored menu button handler after skin change")
            } else {
                ELOG("Could not find shared input handler after skin change")
            }

            // Force a reconnection of input handlers
            self.reconnectAllInputHandlers()
        }
    }
}
