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
import Combine
import MBProgressHUD
import PVAudio
import PVCoreAudio
import PVCoreBridge
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVRealm
import PVSettings
import PVThemes
import SwiftUI
import ZipArchive

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
    var skinContainerView: UIView?

    // Store the current target frame for positioning
    var currentTargetFrame: CGRect?

    // Store the original calculated frame for reset functionality
    var originalCalculatedFrame: CGRect?

    // Store cancellables for skin loading observation
    var skinLoadingCancellable: AnyCancellable?

    // Store the current skin for rotation handling
    var currentSkin: DeltaSkinProtocol?

    // Track current orientation
    #if !os(tvOS)
    var currentOrientation: SkinOrientation = .portrait
    #else
    var currentOrientation: SkinOrientation = .landscape
    #endif

    // Rotation handling state
    private var isHandlingRotation: Bool = false
    private var pendingRotationWorkItem: DispatchWorkItem?

    // Keep track of whether we've positioned the GPU view
    static var hasPositionedGPUView = false

    // Property to track skin hosting controllers - using UIViewController for type flexibility
    var skinHostingControllers: [UIViewController] = []

    // Shared input handler to maintain input state across skin changes
    var sharedInputHandler: DeltaSkinInputHandler?

    var audioVisualizerHostingController: UIHostingController<AnyView>? = nil

    /// The current visualizer mode
    var visualizerMode: VisualizerMode = .off {
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
    var debugOverlayView: UIView?
    var debugInfoLabel: UILabel?
    var debugUpdateTimer: Timer?

    var menuButton: MenuButton?

    private(set) lazy var gpuViewController: PVGPUViewController = {
        let useMetal = (use_metal && !core.alwaysUseGL) || core.alwaysUseMetal
        return useMetal ? PVMetalViewController(withEmulatorCore: core) : PVGLViewController(withEmulatorCore: core)
    }()

    public private(set) lazy var controllerViewController: (any ControllerVC)? = {
        guard let system = game.system else {
            ELOG("Nil system for \(game.title)")
            return nil
        }
        let controller = PVCoreFactory.controllerViewController(forSystem: system, core: core)
        return controller
    }()

    #if os(tvOS)
    override public var preferredUserInterfaceStyle: UIUserInterfaceStyle { ThemeManager.shared.currentPalette.dark ? .dark : .light }
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
        didSet {
            DispatchQueue.main.async { [self] in
                // Single authoritative pause toggle to avoid conflicting calls
                core.setPauseEmulation(isShowingMenu)
            }
        }
    }

    let minimumPlayTimeToMakeAutosave: Double = 60

    public required init(game: PVGame, core: PVEmulatorCore) {
        self.core = core
        self.game = game

        super.init(nibName: nil, bundle: nil)

        let emulationUIState = AppState.shared.emulationUIState
        emulationUIState.core = core
        if emulationUIState.emulator == nil {
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
        PVControllerManager.shared.hasLayout = false
        // Ensure a single stable GPU VC instance; do not reassign or dismiss here

        staticSelf = self

        if Defaults[.autoSave] {
            NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }

        // Add KVO watcher for isRunning state so we can update play time
        core.addObserver(self, forKeyPath: "isRunning", options: .new, context: nil)
    }

    override public func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
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

    @available(*, unavailable)
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
        core.touchViewController = nil
        #if os(iOS) || os(tvOS)
        Task.detached { @MainActor in
            PVControllerManager.shared.controllers.forEach { $0.clearPauseHandler() }
        }
        #endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        // Remove all menu-related gesture recognizers
        #if os(tvOS)
        // Remove all gesture recognizers that handle menu button presses
        let menuGestures = view.gestureRecognizers?.filter { gesture in
            if let tapGesture = gesture as? UITapGestureRecognizer {
                return tapGesture.allowedPressTypes.contains(NSNumber(value: UIPress.PressType.menu.rawValue))
            }
            return false
        }
        menuGestures?.forEach { view.removeGestureRecognizer($0) }
        #else
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        #endif

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
            ILOG("controllerViewController \(controllerViewController), core: \(core)")
            // For RetroArch with DeltaSkins, attach RA views to self to avoid hiding issues
            if Defaults[.skinMode] != .off && (core.coreIdentifier?.contains("libretro") == true) {
                core.touchViewController = self
            } else {
                core.touchViewController = controllerViewController
            }
        }
        controllerViewController?.didMove(toParent: self)
    }

    private func initMenuButton() {
        let alpha = CGFloat(Defaults[.controllerOpacity])
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

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = game.title
        view.backgroundColor = UIColor.black
        view.insetsLayoutMarginsFromSafeArea = true

        let emulationState = AppState.shared.emulationUIState

        emulationState.core = core
        if emulationState.emulator == nil {
            emulationState.emulator = self
        }

        // Set up the GPU view
        setupGPUView()

        // Set up Delta Skin
        setupDeltaSkinDirectly()

        initNotificationObservers()

        // Initialize emulator asynchronously to support CloudKit downloads
        Task {
            do {
                try await createEmulator()
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
                                                  handler: { (_: UIAlertAction) in
                                                      ILOG("PVEmulatorViewController: User tapped OK on error alert, returning to main scene")
                                                      // Ensure we're on the main thread for UI updates with a small delay
                                                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                          ILOG("PVEmulatorViewController: About to call SceneCoordinator.closeEmulator()")

                                                          // First dismiss any presented view controllers
                                                          if let presentedVC = self.presentedViewController {
                                                              ILOG("PVEmulatorViewController: Dismissing presented view controller first")
                                                              presentedVC.dismiss(animated: false) {
                                                                  SceneCoordinator.shared.closeEmulator()
                                                              }
                                                          } else {
                                                              // Dismiss this view controller if it's presented
                                                              if self.presentingViewController != nil {
                                                                  ILOG("PVEmulatorViewController: Dismissing self, then calling closeEmulator")
                                                                  self.dismiss(animated: false) {
                                                                      SceneCoordinator.shared.closeEmulator()
                                                                  }
                                                              } else {
                                                                  ILOG("PVEmulatorViewController: No presented view controllers, calling closeEmulator directly")
                                                                  SceneCoordinator.shared.closeEmulator()
                                                              }
                                                          }
                                                      }
                                                  }))

                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func setupGPUView() {
        // Attach gpuViewController as child once; update frame if already added
        if gpuViewController.parent !== self {
            addChild(gpuViewController)
            gpuViewController.view.frame = view.bounds
            gpuViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(gpuViewController.view)
            gpuViewController.didMove(toParent: self)
        } else {
            gpuViewController.view.frame = view.bounds
            gpuViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    private func createEmulator() async throws {
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

        // Check if file needs download and handle with improved UI
        if await needsCloudKitDownload(for: game) {
            try await handleOnDemandDownload(for: game)
            /// Refresh ROM path after download completes
            romPathMaybe = game.file?.url
            /// Handle archives again in case the downloaded asset was a zip
            romPathMaybe = handleArchives(atPath: romPathMaybe)
        }

        /// Ensure we have a valid ROM URL before attempting to load
        guard let romURL = romPathMaybe else {
            throw CreateEmulatorError.gameHasNilRomPath
        }
        /// Ensure file exists locally and is not an iCloud placeholder
        guard FileManager.default.fileExists(atPath: romURL.path), !needsDownload(romURL) else {
            ELOG("File doesn't exist at path \(romURL.path)")
            #if !os(tvOS)
            UIPasteboard.general.string = romURL.path
            #endif
            throw CreateEmulatorError.fileDoesNotExist(path: romURL.path)
        }

        ILOG("Loading ROM: \(romURL.path)")

        if let core = core as? any ObjCBridgedCore, let bridge = core.bridge as? EmulatorCoreIOInterface {
            try bridge.loadFile(atPath: romURL.path)
        } else {
            try core.loadFile(atPath: romURL.path)
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
            if !core.skipLayout {
                if gpuViewController.parent !== self {
                    gpuViewController.willMove(toParent: self)
                    addChild(gpuViewController)
                    if let aView = gpuViewController.view {
                        aView.frame = view.bounds
                        view.addSubview(aView)
                    }
                    gpuViewController.didMove(toParent: self)
                } else {
                    gpuViewController.view.frame = view.bounds
                }
            }
            #endif
        }
        #if os(iOS) && !targetEnvironment(macCatalyst) && !os(macOS)
        // Do not show legacy controller overlay when DeltaSkins are enabled
        if Defaults[.skinMode] == .off || !core.supportsSkins {
            addControllerOverlay()
        }
        initMenuButton()
        #endif

        if Defaults[.showFPSCount] && !core.skipLayout {
            initFPSLabel()
        }

        hideOrShowMenuButton()

        convertOldSaveStatesToNewIfNeeded()

        try gameAudio.setupAudioGraph(for: core)
        try startAudio()

        // Pause CloudKit when gameplay starts
        CloudKitDownloadQueue.shared.pauseQueue()

        core.startEmulation()

        #if os(tvOS)
        // On tvOS the siri-remotes menu-button will default to go back in the hierachy (thus dismissing the emulator), we don't want that behaviour
        // Set up gesture recognizers for menu button interactions
        setupTVOSMenuGestures()
        #endif
        for controller in PVControllerManager.shared.controllers {
            controller.setupPauseHandler(onPause: {
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

    #if os(tvOS)
    /// Set up tvOS-specific menu button gesture recognizers
    private func setupTVOSMenuGestures() {
        // Single tap gesture for "start" button
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMenuSingleTap(_:)))
        singleTapGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        singleTapGesture.numberOfTapsRequired = 1

        // Double tap gesture for pause menu
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMenuDoubleTap(_:)))
        doubleTapGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        doubleTapGesture.numberOfTapsRequired = 2

        // Make single tap wait for double tap to fail
        singleTapGesture.require(toFail: doubleTapGesture)

        // Add gestures to the view
        view.addGestureRecognizer(singleTapGesture)
        view.addGestureRecognizer(doubleTapGesture)

        // Store reference to single tap gesture (reusing existing property)
        menuGestureRecognizer = singleTapGesture

        ILOG("tvOS menu gestures configured: single tap = start button, double tap = pause menu")
    }

    /// Handle single tap of menu button - send "start" button press
    @objc private func handleMenuSingleTap(_ gesture: UITapGestureRecognizer) {
        ILOG("tvOS menu single tap - sending start button press")

        // Send start button press to the controller
        if let controllerVC = controllerViewController {
            // Try to find and trigger the start button
            if let startButton = findStartButton(in: controllerVC.view) {
                DLOG("Found start button, triggering press")
                startButton.sendActions(for: .touchUpInside)
            } else {
                // Fallback: Log that no start button was found
                DLOG("No start button found in controller view hierarchy")
                // Could potentially add other fallback methods here if needed
            }
        }
    }

    /// Handle double tap of menu button - show pause menu
    @objc private func handleMenuDoubleTap(_ gesture: UITapGestureRecognizer) {
        ILOG("tvOS menu double tap - showing pause menu")
        showMenu(gesture)
    }

    /// Recursively find the start button in the controller view hierarchy
    private func findStartButton(in view: UIView) -> UIButton? {
        // Check if this view is a start button
        if let button = view as? UIButton {
            // Check button title, accessibility identifier, or tag to identify start button
            if let title = button.titleLabel?.text?.lowercased(),
               title.contains("start") || title.contains("pause")
            {
                return button
            }

            // Check accessibility identifier
            if let identifier = button.accessibilityIdentifier?.lowercased(),
               identifier.contains("start") || identifier.contains("pause")
            {
                return button
            }

            // Check tag (you might need to adjust this based on your button tagging system)
            if button.tag == 1000 { // Assuming start button has a specific tag
                return button
            }
        }

        // Recursively search subviews
        for subview in view.subviews {
            if let startButton = findStartButton(in: subview) {
                return startButton
            }
        }

        return nil
    }
    #endif

    override public func viewDidAppear(_: Bool) {
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

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyAutosaveTimer()
    }

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Handle skin changes for orientation
        handleOrientationChange(to: size, with: coordinator)
    }

    // MARK: - CloudKit Download Handling

    /// Check if a game needs CloudKit download
    /// - Parameter game: The game to check
    /// - Returns: True if the game needs to be downloaded from CloudKit
    private func needsCloudKitDownload(for game: PVGame) async -> Bool {
        // Check if local file exists and is accessible
        guard let fileURL = game.file?.url else {
            VLOG("Game \(game.title) has no file URL - needs download")
            return true
        }

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)

        if !fileExists {
            VLOG("Game \(game.title) file doesn't exist at \(fileURL.path) - needs download")
            return true
        }

        // Check if file is just an iCloud placeholder
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                switch downloadStatus {
                case .notDownloaded:
                    VLOG("Game \(game.title) is not downloaded from iCloud - needs download")
                    return true
                case .downloaded:
                    VLOG("Game \(game.title) is already downloaded")
                    return false
                case .current:
                    VLOG("Game \(game.title) is current")
                    return false
                default:
                    VLOG("Game \(game.title) has unknown download status - assuming needs download")
                    return true
                }
            }
        } catch {
            VLOG("Could not check iCloud status for \(game.title): \(error)")
        }

        return false
    }

    /// Handle on-demand download with improved progress UI
    /// - Parameters:
    ///   - game: The game to download
    ///   - romPath: The ROM file path
    private func handleOnDemandDownload(for game: PVGame) async throws {
        ILOG("Starting on-demand download for: \(game.title)")

        let downloadQueue = CloudKitDownloadQueue.shared

        // Check if already queued or downloading
        let status = await downloadQueue.downloadStatus(for: game.md5Hash ?? "")
        switch status {
        case .downloading:
            ILOG("Game \(game.title) is already downloading")
            try await showDownloadProgress(for: game)
            return
        case .queued:
            ILOG("Game \(game.title) is already queued")
            try await showDownloadProgress(for: game)
            return
        case .failed:
            ILOG("Game \(game.title) had failed download - retrying")
            downloadQueue.retryDownload(md5: game.md5Hash ?? "")
            try await showDownloadProgress(for: game)
            return
        case .notQueued:
            break
        }

        do {
            // Queue the download with high priority (on-demand)
            try await downloadQueue.queueDownload(
                md5: game.md5Hash ?? "",
                title: game.title,
                fileSize: Int64(game.fileSize),
                systemIdentifier: game.systemIdentifier,
                priority: .high,
                onDemand: true
            )

            // Show progress UI
            try await showDownloadProgress(for: game)

        } catch let CloudSyncError.insufficientSpace(required, available) {
            // Show space error alert
            await showInsufficientSpaceAlert(
                gameTitle: game.title,
                required: required,
                available: available
            )
            throw CreateEmulatorError.insufficientSpace

        } catch {
            ELOG("Failed to queue on-demand download for \(game.title): \(error)")
            await showDownloadErrorAlert(gameTitle: game.title, error: error)
            throw error
        }
    }

    /// Show download progress UI with cancel option
    /// - Parameter game: The game being downloaded
    private func showDownloadProgress(for game: PVGame) async throws {
        await MainActor.run {
            let progressView = CloudKitDownloadProgressView(
                gameMD5: game.md5Hash ?? "",
                gameTitle: game.title,
                onCancel: { [weak self] in
                    // User cancelled - go back to library
                    ILOG("User cancelled download for: \(game.title)")
                    self?.dismiss(animated: true)
                },
                onComplete: { [weak self] in
                    // Download completed – dismiss progress UI and allow calling flow to continue
                    ILOG("Download UI dismissed for: \(game.title)")
                    self?.dismiss(animated: true)
                }
            )

            let hostingController = UIHostingController(rootView: progressView)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.modalTransitionStyle = .crossDissolve

            self.present(hostingController, animated: true)
        }

        /// Wait for download to start and then complete (or fail)
        return try await withCheckedThrowingContinuation { continuation in
            let progressTracker = SyncProgressTracker.shared
            var cancellables = Set<AnyCancellable>()
            var hasStarted = false

            Publishers.CombineLatest3(
                progressTracker.$queuedDownloads,
                progressTracker.$activeDownloads,
                progressTracker.$failedDownloads
            )
            .sink { queued, active, failed in
                let md5 = game.md5Hash ?? ""
                let inQueued = queued.contains { $0.md5 == md5 }
                let inActive = active.contains { $0.md5 == md5 }
                let hasFailed = failed.contains { $0.md5 == md5 }

                if inQueued || inActive { hasStarted = true }

                if hasFailed {
                    cancellables.removeAll()
                    if let failure = failed.first(where: { $0.md5 == md5 }) {
                        continuation.resume(throwing: failure.error)
                    } else {
                        continuation.resume(throwing: CloudSyncError.unknown)
                    }
                    return
                }

                if hasStarted && !inQueued && !inActive {
                    // Completed successfully
                    cancellables.removeAll()
                    continuation.resume()
                }
            }
            .store(in: &cancellables)
        }
    }

    /// Show insufficient space alert
    private func showInsufficientSpaceAlert(gameTitle: String, required: Int64, available: Int64) async {
        await MainActor.run {
            let requiredStr = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let availableStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)

            let alert = UIAlertController(
                title: "Insufficient Storage",
                message: "Cannot download \(gameTitle). Requires \(requiredStr) but only \(availableStr) available.\n\nPlease free up space and try again.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            })

            #if os(tvOS)
            alert.addAction(UIAlertAction(title: "Storage Settings", style: .default) { _ in
                // On tvOS, open storage settings if possible
                if let settingsURL = URL(string: "App-Prefs:General&path=STORAGE_MGMT") {
                    UIApplication.shared.open(settingsURL)
                }
                self.dismiss(animated: true)
            })
            #endif

            present(alert, animated: true)
        }
    }

    /// Show download error alert
    private func showDownloadErrorAlert(gameTitle: String, error: Error) async {
        await MainActor.run {
            let alert = UIAlertController(
                title: "Download Failed",
                message: "Failed to download \(gameTitle).\n\nError: \(error.localizedDescription)",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                Task {
                    // Retry the download
                    try? await self.handleOnDemandDownload(for: self.game)
                }
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.dismiss(animated: true)
            })

            present(alert, animated: true)
        }
    }


    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if os(iOS)
        layoutMenuButton()
        #endif
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    override public var prefersStatusBarHidden: Bool {
        return true
    }

    override public var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.left, .right, .bottom]
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
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
        // Resume CloudKit when gameplay stops
        CloudKitDownloadQueue.shared.resumeQueue()

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
        for controller in PVControllerManager.shared.controllers {
            controller.clearPauseHandler()
        }

        #endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        // Remove all menu-related gesture recognizers
        #if os(tvOS)
        // Remove all gesture recognizers that handle menu button presses
        let menuGestures = view.gestureRecognizers?.filter { gesture in
            if let tapGesture = gesture as? UITapGestureRecognizer {
                return tapGesture.allowedPressTypes.contains(NSNumber(value: UIPress.PressType.menu.rawValue))
            }
            return false
        }
        menuGestures?.forEach { view.removeGestureRecognizer($0) }
        #else
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        #endif

        let emulationUIState = AppState.shared.emulationUIState

        emulationUIState.core = nil
        emulationUIState.emulator = nil

        let emulationState = AppState.shared.emulationState
        emulationState.isOn = false

        fpsTimer?.invalidate()
        fpsTimer = nil
        dismiss(animated: true, completion: completion)
        view?.removeFromSuperview()
        removeFromParent()
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
//            metalVC.safelyRefreshGPUView()
        }

        // If using a DeltaSkin, ensure game screen view is visible and positioned properly
        if let skinContainerView = view.viewWithTag(9876) {
            // Make sure the GPU view is visible on top of the proper layer
            gpuViewController.view.alpha = 1.0
            gpuViewController.view.isHidden = false

            // If we have a stored target frame, ensure the GPU view is positioned there
            if let targetFrame = currentTargetFrame {
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
        // Check if the core supports skins
        guard core.supportsSkins else {
            DLOG("Core does not support skins: \(core.description)")
            throw NSError(domain: "PVEmulatorViewController", code: 1001, userInfo: [NSLocalizedDescriptionKey: "This core does not support skins"])
        }

        ILOG("Applying skin: \(skin.name)")

        // Log core dimensions before skin application
        if let metalVC = gpuViewController as? PVMetalViewController {
            ILOG("""
            Core dimensions before skin application:
            Buffer size: \(core.bufferSize)
            Screen rect: \(core.screenRect)
            GPU view frame: \(metalVC.view.frame)
            Orientation: \(currentOrientation)
            """)
        }

        // Reset the current target frame to force recalculation for the new skin
        currentTargetFrame = nil

        // Store the current skin for rotation handling
        currentSkin = skin

        // IMPORTANT: Use device orientation for skin traits
        // First get the real device orientation
        #if !os(tvOS)
        let deviceOrientation = UIDevice.current.orientation

        // If it's not a valid orientation (face up/down/unknown), use interface orientation
        let validOrientations: [UIDeviceOrientation] = [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]

        let isValidOrientation = validOrientations.contains(deviceOrientation)

        // Determine the current orientation from device or interface orientation
        if isValidOrientation {
            currentOrientation = deviceOrientation.isLandscape ? .landscape : .portrait
        } else {
            // Fallback to interface orientation
            let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
            currentOrientation = (interfaceOrientation == .landscapeLeft || interfaceOrientation == .landscapeRight) ? .landscape : .portrait
        }
        #else
        #endif

        // Log the orientation we're using
        DLOG("Using orientation for skin application: \(currentOrientation)")

        // RADICAL APPROACH: Completely rebuild the view hierarchy
        await MainActor.run {
            // 1. Remove ALL views and controllers except the essential ones
            radicalCleanup()

            // 2. Print the view hierarchy after cleanup to verify it's clean
            ILOG("View hierarchy after radical cleanup:")
            printViewHierarchy(view, level: 0)
        }

        // 3. Create a new skin container with edge-to-edge layout
        let skinContainer = UIView(frame: view.bounds)
        skinContainer.tag = 9876 // Unique tag for skin container views
        skinContainer.isOpaque = false
        skinContainer.backgroundColor = .clear // UIColor.black // Set background to black for retrowave aesthetic
        skinContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight] // Ensure it resizes with parent

        // 4. Add the container at the bottom of the view hierarchy
        await MainActor.run {
            view.addSubview(skinContainer)

            // Store reference to the skin container
            self.skinContainerView = skinContainer
        }

        // 5. Create and add the skin view
        // Pause emulation while building the skin to avoid glitches
        core.setPauseEmulation(true)
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
                DLOG("GPU view frame BEFORE repositioning: \(gpuView.frame)")
            } else {
                WLOG("WARNING: GPU view is nil before repositioning!")
            }

            // Force recalculation of screen position for the new skin
            repositionGameScreen(for: skin, orientation: currentOrientation, forceRecalculation: true)

            // Log the GPU view frame after repositioning
            if let gpuView = gpuViewController.view {
                DLOG("GPU view frame AFTER repositioning: \(gpuView.frame)")
            }

            // Ensure proper z-order of all elements
            ensureProperZOrder()

            // Force a layout update
            view.setNeedsLayout()
            view.layoutIfNeeded()

            // 7. Print the final view hierarchy
            DLOG("View hierarchy after applying new skin:")
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

            // Skin fully applied; resume emulation
            core.setPauseEmulation(false)
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

        DLOG("Creating skin view with traits: \(traits)")

        // Create an input handler for the skin
        let inputHandler = DeltaSkinInputHandler(
            emulatorCore: core,
            controllerVC: controllerViewController,
            emulatorController: self
        )

        // Store the input handler for reuse
        sharedInputHandler = inputHandler

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
                DLOG("Skin loaded callback triggered")

                // Force a redraw of the GPU view
                if let metalVC = self.gpuViewController as? PVMetalViewController {
//                    metalVC.safelyRefreshGPUView()
                }
            },
            onRefreshRequested: {
                // This is called when a refresh is needed
                DLOG("Refresh requested callback triggered")

                // Force a redraw of the GPU view
                if let metalVC = self.gpuViewController as? PVMetalViewController {
//                    metalVC.safelyRefreshGPUView()
                }
            },
            inputHandler: inputHandler
        )

        // Create a UIHostingController to host the SwiftUI view
        let hostingController = SkinHostingController(rootView: wrapperView)

        // Add the hosting controller as a child
        await MainActor.run {
            addChild(hostingController)
            hostingController.didMove(toParent: self)

            // Keep track of the hosting controller
            skinHostingControllers.append(hostingController)
            #if os(iOS)
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            #endif
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
            ELOG("Cannot position game screen - GPU view is nil")
            return
        }

        // Log core dimensions before repositioning
        ILOG("""
         Core dimensions before repositioning game screen:
         Buffer size: \(core.bufferSize)
         Screen rect: \(core.screenRect)
         GPU view frame: \(gpuView.frame)
         Orientation: \(orientation)
         Force recalculation: \(forceRecalculation)
        """)

        // If we have a cached target frame and we're not forcing recalculation, use it
        if let targetFrame = currentTargetFrame, !forceRecalculation {
            // Only apply if the frames are significantly different to avoid jitter
            if abs(gpuView.frame.width - targetFrame.width) > 1 ||
                abs(gpuView.frame.height - targetFrame.height) > 1 ||
                abs(gpuView.frame.origin.x - targetFrame.origin.x) > 1 ||
                abs(gpuView.frame.origin.y - targetFrame.origin.y) > 1
            {
                DLOG("Using cached target frame: \(targetFrame)")
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
            ILOG("Positioning GPU view at: \(absoluteFrame)")
            gpuView.frame = absoluteFrame

            // Log core dimensions after repositioning
            if let metalVC = gpuViewController as? PVMetalViewController {
                // Force a refresh of the GPU view after repositioning
                DispatchQueue.main.async {
//                    metalVC.safelyRefreshGPUView()

                    // Log dimensions after refresh
                    ILOG("""
                    Core dimensions after repositioning game screen:
                    Buffer size: \(self.core.bufferSize)
                    Screen rect: \(self.core.screenRect)
                    GPU view frame: \(gpuView.frame)
                    Metal view drawable size: \(metalVC.mtlView.drawableSize)
                    Orientation: \(orientation)
                    """)

                    // Dump texture info for debugging
//                    metalVC.dumpTextureInfo()
                }
            }

            // Make sure the GPU view is visible
            gpuView.isHidden = false
            gpuView.alpha = 1.0

            // Force a redraw of the GPU view
            if let metalVC = gpuViewController as? PVMetalViewController {
//                metalVC.safelyRefreshGPUView()
            }
        } else {
            // Fall back to default positioning (full screen or some reasonable default)
            let defaultFrame: CGRect

            if orientation == .landscape {
                // Default landscape position (centered, 80% of width, maintain aspect ratio)
                let width = view.bounds.width * 0.8
                let height = width * (3.0 / 4.0) // 4:3 aspect ratio typical for retro games
                let x = (view.bounds.width - width) / 2
                let y = (view.bounds.height - height) / 2
                defaultFrame = CGRect(x: x, y: y, width: width, height: height)
            } else {
                // Default portrait position (centered, 80% of width, maintain aspect ratio)
                let width = view.bounds.width * 0.8
                let height = width * (3.0 / 4.0) // 4:3 aspect ratio typical for retro games
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
            DLOG("Using default positioning for GPU view: \(defaultFrame)")
            gpuView.frame = defaultFrame

            // Make sure the GPU view is visible
            gpuView.isHidden = false
            gpuView.alpha = 1.0
        }
    }

    /// Reconnect all input handlers to ensure they're properly linked after skin changes
    private func reconnectAllInputHandlers() {
        DLOG("Reconnecting all input handlers")

        // Update the shared input handler references
        if let inputHandler = sharedInputHandler {
            DLOG("Updating shared input handler references")

            // Re-link the core, controller, and emulator controller
            inputHandler.setEmulatorCore(core)
            inputHandler.setControllerVC(controllerViewController)
            inputHandler.setEmulatorController(self)

            // Ensure menu button handler is set
            inputHandler.menuButtonHandler = { [weak self] in
                DLOG("Menu button pressed from reconnected handler, showing menu")
                self?.showMenu(nil)
            }

            DLOG("✅ Successfully updated all input handler references")
        }

        // Trigger input handler reconnect notification as well for belt and suspenders
        NotificationCenter.default.post(
            name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
            object: nil
        )
    }

    /// Reset to the default skin
    public func resetToDefaultSkin() async throws {
        DLOG("Resetting to default skin")

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
        DLOG("Performing RADICAL cleanup of view hierarchy")

        // 1. Save reference to essential views we need to keep
        let gpuView = gpuViewController.view

        // 2. Remove ALL child view controllers except the GPU controller
        for child in children {
            if child !== gpuViewController {
                DLOG("Removing controller: \(child)")
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
                DLOG("Removing view: \(subview)")
                subview.removeFromSuperview()
            }
        }

        // 5. Clear the skin container reference and reset target frame
        skinContainerView = nil
        currentTargetFrame = nil // Reset target frame to force recalculation

        // NOTE: We intentionally DO NOT reset the sharedInputHandler here
        // to maintain input state across skin changes

        // 6. Make sure the GPU view is still in the hierarchy
        if let gpuView = gpuView, gpuView.superview == nil {
            DLOG("Re-adding GPU view")
            view.addSubview(gpuView)
        }

        // 7. Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()

        // 8. Print the final view hierarchy
        DLOG("View hierarchy after radical cleanup:")
        printViewHierarchyRecursively(view, level: 0)
    }

    /// Debug helper to print the view hierarchy
    private func printViewHierarchy(_ view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        DLOG("\(indent)\(view) (tag: \(view.tag))")
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
        DLOG("View hierarchy after applying new skin:")
        printViewHierarchyRecursively(view, level: 0)
    }

    /// Recursively print a view hierarchy for debugging
    private func printViewHierarchyRecursively(_ view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        DLOG("\(indent)<\(type(of: view)): \(view); frame = \(view.frame); \(view.tag != 0 ? "tag = \(view.tag); " : "")backgroundColor = \(String(describing: view.backgroundColor)); layer = <\(type(of: view.layer)): \(view.layer)>> (tag: \(view.tag))")

        for subview in view.subviews {
            printViewHierarchyRecursively(subview, level: level + 1)
        }
    }

    // Handle rotation and skin changes
    func handleOrientationChange(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        DLOG("Handling orientation change to size: \(size)")

        // Determine new orientation
        let newOrientation: SkinOrientation = size.width > size.height ? .landscape : .portrait

        // Debounce and coalesce rapid orientation callbacks
        pendingRotationWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isHandlingRotation { return }
            self.isHandlingRotation = true

            // Log core dimensions before orientation change
            DLOG("""
            Core dimensions before orientation change:
            Buffer size: \(self.core.bufferSize)
            Screen rect: \(self.core.screenRect)
            New orientation: \(newOrientation)
            """)

            let previousSkin = self.currentSkin
            let orientationChanged = (newOrientation != self.currentOrientation)
            self.currentOrientation = newOrientation

            self.coordinatorAnimateRotation(previousSkin: previousSkin, newOrientation: newOrientation) {
                self.isHandlingRotation = false
            }
        }
        pendingRotationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func coordinatorAnimateRotation(previousSkin: DeltaSkinProtocol?, newOrientation: SkinOrientation, completion: @escaping () -> Void) {
        let coordinator = self.transitionCoordinator
        let animateBlock = {
            if self.isDeltaSkinEnabled, let skin = previousSkin {
                self.repositionGameScreen(for: skin, orientation: newOrientation, forceRecalculation: true)
            } else {
                self.gpuViewController.view.frame = self.view.bounds
                self.ensureProperZOrder()
            }
        }

        let applyBlock = { [weak self] in
            guard let self = self else { completion(); return }
            if self.isDeltaSkinEnabled {
                Task { @MainActor in
                    defer { completion() }
                    // Determine effective skin id for the new orientation
                    let systemId = self.game.system?.systemIdentifier
                    let gameId = self.game.md5Hash ?? self.game.crc
                    let effectiveId = systemId.flatMap {
                        DeltaSkinManager.shared.effectiveSkinIdentifier(for: $0, gameId: gameId, orientation: newOrientation)
                    }

                    let currentId = self.currentSkin?.identifier
                    DLOG("Effective skin id: \(effectiveId ?? "nil"), current: \(currentId ?? "nil")")

                    // If effective id is nil but we have a current skin, keep current and relayout
                    if effectiveId == nil, let current = self.currentSkin {
                        self.minimalRelayout(with: current, orientation: newOrientation)
                        return
                    }

                    // Reload only if the id differs
                    if let eid = effectiveId, eid != currentId {
                        if let skin = try? await DeltaSkinManager.shared.skin(withIdentifier: eid) {
                            try? await self.applySkin(skin)
                        } else {
                            try? await self.resetToDefaultSkin()
                        }
                        self.ensureProperZOrder()
                    } else if let current = self.currentSkin {
                        self.minimalRelayout(with: current, orientation: newOrientation)
                    } else {
                        try? await self.resetToDefaultSkin()
                    }
                }
            } else {
                self.gpuViewController.view.frame = self.view.bounds
                self.ensureProperZOrder()
                completion()
            }
        }

        if let coordinator = coordinator {
            coordinator.animate(alongsideTransition: { _ in animateBlock() }, completion: { _ in applyBlock() })
        } else {
            animateBlock()
            applyBlock()
        }
    }

    private func minimalRelayout(with skin: DeltaSkinProtocol, orientation: SkinOrientation) {
        self.repositionGameScreen(for: skin, orientation: orientation, forceRecalculation: true)
        if let skinView = self.skinContainerView {
            skinView.frame = self.view.bounds
            skinView.setNeedsLayout()
            skinView.layoutIfNeeded()
        }
        // For RetroArch, re-apply internal render view frame to keep it visible
        if self.core.coreIdentifier?.contains("libretro") == true,
           let frame = self.currentTargetFrame,
           let viewport = (self.core.bridge as? EmulatorCoreViewportPositioning) {
            viewport.setUseCustomRenderViewLayout(true)
            let parent = (self.core.touchViewController ?? self).view
            let rectInParent = self.view.convert(frame, to: parent)
            viewport.applyRenderViewFrameInTouchView(rectInParent)
        }
        self.ensureProperZOrder()
    }
}

extension PVEmulatorViewController {
    @objc func appWillEnterForeground(_: Notification?) {
        if !core.isOn {
            return
        }
        Task.detached { @MainActor in
            self.updateLastPlayedTime()
        }
    }

    @objc func appDidEnterBackground(_: Notification?) {}

    @objc func appWillResignActive(_: Notification?) {
        if !core.isOn {
            return
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
        if !core.isOn {
            return
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
