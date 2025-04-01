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
    private var sharedInputHandler: DeltaSkinInputHandler?

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
                        gpuViewController.isPaused = true
                    }
                }
                core.setPauseEmulation(newValue)
            }
        }
        didSet {
            DispatchQueue.main.async { [self] in
                if isShowingMenu == false {
                    if (!core.skipLayout) {
                        gpuViewController.isPaused = false
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

#if os(iOS) && !targetEnvironment(simulator)
    // Check Controller Manager if it has a Controller connected and thus if Home Indicator should hide…
    public override var prefersHomeIndicatorAutoHidden: Bool {
        let shouldHideHomeIndicator: Bool = PVControllerManager.shared.hasControllers
        return shouldHideHomeIndicator
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
        enableControllerInput(false)
    }
}


extension PVEmulatorViewController: GameplayDurationTrackerUtil {}

// MARK: - Skin Management
extension PVEmulatorViewController {
    
    
    /// Apply a skin to the emulator view
    /// - Parameter skin: The skin to apply
    public func applySkin(_ skin: DeltaSkinProtocol) async throws {
        print("Applying skin: \(skin.name)")
        
        // Reset the current target frame to force recalculation for the new skin
        currentTargetFrame = nil
        
        // Store the current skin for rotation handling
        self.currentSkin = skin
        
        // Determine the current orientation
        self.currentOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        
        // RADICAL APPROACH: Completely rebuild the view hierarchy
        await MainActor.run {
            // 1. Remove ALL views and controllers except the essential ones
            radicalCleanup()
            
            // 2. Print the view hierarchy after cleanup to verify it's clean
            print("View hierarchy after radical cleanup:")
            printViewHierarchy(view, level: 0)
        }
        
        // 3. Create a new skin container with edge-to-edge layout
        let skinContainer = UIView()
        skinContainer.tag = 9876 // Unique tag for skin container views
        skinContainer.translatesAutoresizingMaskIntoConstraints = false
        skinContainer.backgroundColor = UIColor.black // Set background to black for retrowave aesthetic
        
        // 4. Add the container at the bottom of the view hierarchy
        await MainActor.run {
            // Insert at the very bottom of the view hierarchy
            if view.subviews.isEmpty {
                view.addSubview(skinContainer)
            } else {
                view.insertSubview(skinContainer, at: 0)
            }
            
            // Set up constraints for the skin container - ensure edge-to-edge coverage
            // Use the superview bounds, not the safe area
            NSLayoutConstraint.activate([
                skinContainer.topAnchor.constraint(equalTo: view.topAnchor),
                skinContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                skinContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                skinContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            // Store reference to the skin container
            self.skinContainerView = skinContainer
        }
        
        // 5. Create and add the skin view
        let skinView = try await createSkinView(from: skin)
        
        await MainActor.run {
            // Add the skin view to the container
            skinContainer.addSubview(skinView)
            
            // Ensure the skin view fills the container edge-to-edge
            skinView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                skinView.topAnchor.constraint(equalTo: skinContainer.topAnchor),
                skinView.leadingAnchor.constraint(equalTo: skinContainer.leadingAnchor),
                skinView.trailingAnchor.constraint(equalTo: skinContainer.trailingAnchor),
                skinView.bottomAnchor.constraint(equalTo: skinContainer.bottomAnchor)
            ])
            
            // 6. Position the game screen within the skin view at the correct position
            // Force recalculation of screen position for the new skin
            repositionGameScreen(for: skin, orientation: currentOrientation, forceRecalculation: true)
            
            // 7. Print the final view hierarchy
            print("View hierarchy after applying new skin:")
            printViewHierarchy(view, level: 0)
        }
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
            let defaultSkin = EmulatorWithSkinView.defaultSkin(for: systemId)
            try await applySkin(defaultSkin)
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
    
    /// Create a skin view from a DeltaSkin
    private func createSkinView(from skin: DeltaSkinProtocol) async throws -> UIView {
        print("Creating skin view for: \(skin.name)")
        
        // Always use the current orientation from the stored property
        // This ensures consistency with the rest of the code
        let deltaSkinOrientation: DeltaSkinOrientation = currentOrientation == .landscape ? .landscape : .portrait
        print("Using orientation for skin view: \(deltaSkinOrientation)")
        
        // Create the appropriate traits for the current device and orientation
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        
        // Check if device has a notch (iPhone X or newer)
        let hasNotch: Bool
        if #available(iOS 11.0, *) {
            let window = UIApplication.shared.windows.first
            let safeAreaInsets = window?.safeAreaInsets
            hasNotch = (safeAreaInsets?.top ?? 0) > 20
        } else {
            hasNotch = false
        }
        
        let displayType: DeltaSkinDisplayType = hasNotch ? .edgeToEdge : .standard
        let traits = DeltaSkinTraits(device: device, displayType: displayType, orientation: deltaSkinOrientation)
        print("Created traits: device=\(device), displayType=\(displayType), orientation=\(deltaSkinOrientation)")
        
        // Reuse the existing input handler or create a new one if it doesn't exist
        if sharedInputHandler == nil {
            sharedInputHandler = DeltaSkinInputHandler(emulatorCore: core)
            print("Created new shared input handler")
        } else {
            print("Reusing existing shared input handler")
        }
        
        // Ensure the input handler is properly configured
        let inputHandler = sharedInputHandler!
        print("Using input handler with isInEmulator = true")
        
        // Create the SwiftUI skin view with environment object
        // Use AnyView to erase the type while preserving the environment object
        let skinContentView = AnyView(
            DeltaSkinView(skin: skin, traits: traits, isInEmulator: true, inputHandler: inputHandler)
                .environmentObject(DeltaSkinManager.shared)
                .edgesIgnoringSafeArea(.all) // Ensure edge-to-edge drawing
        )
        
        // Create a hosting controller for the SwiftUI view with a unique identifier
        let hostingController = UIHostingController(rootView: skinContentView)
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.tag = 9877 // Unique tag for skin views
        
        // Configure the hosting controller for edge-to-edge layout
        if #available(iOS 11.0, *) {
            hostingController.view.insetsLayoutMarginsFromSafeArea = false
        }
        
        print("Created hosting controller with skin view")
        
        // Add the hosting controller as a child view controller
        addChild(hostingController)
        hostingController.didMove(toParent: self)
        
        // Track this hosting controller
        skinHostingControllers.append(hostingController)
        
        print("Created new skin view for \(skin.name)")
        
        return hostingController.view
    }
    
    /// Reposition the game screen based on the current skin and orientation
    /// - Parameters:
    ///   - skin: The skin to position the screen for
    ///   - orientation: The current orientation
    ///   - forceRecalculation: Whether to force recalculation of the screen position
    private func repositionGameScreen(for skin: DeltaSkinProtocol, orientation: SkinOrientation, forceRecalculation: Bool = false) {
        print("Repositioning game screen for skin: \(skin.name), orientation: \(orientation)")
        
        // Always reset currentTargetFrame when changing skins to force recalculation
        if forceRecalculation {
            currentTargetFrame = nil
            print("Reset currentTargetFrame to force recalculation")
        }
        
        // Store the original frame if not already stored
        if originalCalculatedFrame == nil {
            originalCalculatedFrame = gpuViewController.view.frame
            print("Stored original frame: \(String(describing: originalCalculatedFrame))")
        }
        
        // Get the screen bounds
        let screenBounds = view.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        print("Screen bounds: \(screenBounds)")
        
        // Get the appropriate screen position from the skin based on orientation
        let screenPosition: CGRect
        
        // Get screen position from the skin
        if let skinScreenPosition = getScreenPositionFromSkin(skin, for: orientation) {
            screenPosition = skinScreenPosition
            print("Using skin-specific screen position: \(screenPosition)")
        } else {
            // Default position if not specified in skin
            if orientation == .landscape {
                // Default landscape position - adjusted for retrowave styling
                screenPosition = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.7)
                print("Using default landscape position")
            } else {
                // Default portrait position - adjusted for retrowave styling
                screenPosition = CGRect(x: 0.1, y: 0.15, width: 0.8, height: 0.6)
                print("Using default portrait position")
            }
        }
        
        // Calculate actual frame in points
        let newFrame = CGRect(
            x: screenWidth * screenPosition.origin.x,
            y: screenHeight * screenPosition.origin.y,
            width: screenWidth * screenPosition.size.width,
            height: screenHeight * screenPosition.size.height
        )
        print("New calculated frame: \(newFrame)")
        
        // Apply the new frame with animation
        UIView.animate(withDuration: 0.3) {
            self.gpuViewController.view.frame = newFrame
        }
        
        // Don't bring the game view to front if we want filters and transparent elements to appear over it
        // This is commented out to allow skin elements to appear over the game screen
        // view.bringSubviewToFront(gpuViewController.view)
        
        // Store the current target frame
        currentTargetFrame = newFrame
        print("Repositioning complete")
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
            
            // Handle rotation in two phases to avoid visual glitches
            coordinator.animate { _ in
                // During animation phase, just reposition the game screen
                // but don't change the skin yet to avoid visual glitches
                if let skin = self.currentSkin {
                    print("Repositioning game screen during animation")
                    self.repositionGameScreen(for: skin, orientation: newOrientation)
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
                        let skinIdentifier = DeltaSkinPreferences.shared.effectiveSkinIdentifier(
                            for: gameId,
                            system: systemId,
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
                            print("Using existing skin, just repositioning")
                            // We need to do a complete reapplication to ensure proper traits
                            // This fixes issues with skins not drawing correctly after rotation
                            try await self.applySkin(self.currentSkin!)
                        } else {
                            print("No skin at all, applying default")
                            try await self.resetToDefaultSkin()
                        }
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
}
