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
import PVLogging
import PVRealm
import PVSettings
import PVThemes
import SwiftUI
import PVArchiving
import PVFileSystem
#if canImport(PVJIT)
import JITManager
#endif
#if canImport(PVAppIntents)
import PVAppIntents
#endif

private weak var staticSelf: PVEmualatorControllerProtocol?

func uncaughtExceptionHandler(exception _: NSException?) {
    guard let staticSelf = staticSelf else { return }
    let core = staticSelf.core
    // CRITICAL: This is a C-level exception handler called on the faulting thread.
    // The process is in an unstable state and will terminate immediately after this
    // function returns. Async tasks (Task.detached, @MainActor hops) are NEVER
    // guaranteed to run here — the Swift concurrency runtime cannot schedule them
    // before the process is killed.
    //
    // autoSaveState() is intentionally omitted: it requires async Realm database
    // writes that cannot complete safely during crash recovery and risk corrupting
    // the database if interrupted mid-write.
    //
    // Only synchronous, signal-safe operations belong here.
    if !core.shouldStop {
        ILOG("uncaughtExceptionHandler: synchronously stopping emulation to flush battery saves")
        core.emergencyStopEmulation()
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
    /// Tracks emulation session play time. Replaces the old KVO + gameStartTime approach.
    var playTimeTracker: PlayTimeTracker?
    /// Combine subscription that observes core.isRunning with duplicate-filtering.
    private var runningCancellable: AnyCancellable?
    // Store a reference to the skin container view
    var skinContainerView: UIView?

    // Store the current target frame for positioning
    var currentTargetFrame: CGRect?

    /// Cache the last applied viewport to avoid redundant layout work
    var lastAppliedViewportFrame: CGRect?

    // Store the original calculated frame for reset functionality
    var originalCalculatedFrame: CGRect?

    // Combine subscriptions for skin lifecycle (app-state, load-pause, etc.)
    var skinCancellables = Set<AnyCancellable>()
    // Store cancellables for skin loading observation
    var skinLoadingCancellable: AnyCancellable?
    /// Observes the FPS counter preference and updates the in-game HUD live.
    private var showFPSCountCancellable: AnyCancellable?

    // Store the current skin for rotation handling
    var currentSkin: DeltaSkinProtocol?

    // Track current orientation
    #if !os(tvOS)
    var currentOrientation: SkinOrientation = .portrait
    #else
    var currentOrientation: SkinOrientation = .landscape
    #endif

    /// Track frames received from skin system for dual screens
    internal var receivedScreenFrames: [String: CGRect] = [:]

    // Rotation handling state
    private var isHandlingRotation: Bool = false
    private var pendingRotationWorkItem: DispatchWorkItem?

    // Viewport application state to prevent layout loops
    var isApplyingViewport: Bool = false

    // Keep track of whether we've positioned the GPU view
    static var hasPositionedGPUView = false

    // Property to track skin hosting controllers - using UIViewController for type flexibility
    var skinHostingControllers: [UIViewController] = []

    // Shared input handler to maintain input state across skin changes
    var sharedInputHandler: DeltaSkinInputHandler?

    #if os(iOS)
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
    #endif

    // Debug overlay view
    var debugOverlayView: UIView?
    var debugInfoLabel: UILabel?
    var debugUpdateTimer: Timer?

    var menuButton: MenuButton?

    /// Toast overlay hosting controller — must survive `radicalCleanup`.
    private var toastHostingController: PVToastHostingController?

    // RTL: do not flip — the emulator screen renders pixel-accurate game content.
    // Mirroring the GPU viewport would produce a horizontally inverted image, breaking gameplay.
    private(set) lazy var gpuViewController: PVGPUViewController = {
        let useMetal = (use_metal && !core.alwaysUseGL) || core.alwaysUseMetal
        let vc: PVGPUViewController = useMetal ? PVMetalViewController(withEmulatorCore: core) : PVGLViewController(withEmulatorCore: core)
        vc.resetFirstFrameTracking()
        return vc
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

    #if canImport(UIKit) && !os(tvOS)
    /// Returns `true` while the GCMouse hardware driver is active so UIKit
    /// suppresses the system cursor and delivers raw relative deltas via GCMouse.
    /// Available on iPadOS 14+; UIKit ignores this on iPhone automatically.
    @available(iOS 14.0, *)
    override public var prefersPointerLocked: Bool {
        gcMouseDriver != nil
    }
    #endif

    public var audioInited: Bool = false

    /// Whether the game audio is currently muted by the user (e.g. via the DualSense mic button).
    /// Toggling this adjusts `gameAudio.setVolume(0)` / restores the user's preferred volume.
    public private(set) var isAudioMuted: Bool = false

    public private(set) lazy var gameAudio: any AudioEngineProtocol = {
        audioInited = true

        let engineOption = Defaults[.audioEngine]
        return engineOption.makeAudioEngine()
    }()

    var fpsTimer: Timer?
    /// Theme-change observer token for the performance HUD.
    /// Must not be `private` because the HUD is configured from a separate extension file.
    var themeDidChangeObserver: NSObjectProtocol?
    /// Container for the performance HUD.
    lazy var fpsHUDView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 8
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.masksToBounds = true
        return view
    }()
    /// Applies the current theme to the performance HUD.
    /// Not `private` because the HUD is configured from a separate extension file.
    func applyFPSHUDTheme() {
        let palette = ThemeManager.shared.currentPalette
        let bg = palette.settingsCellBackground ?? palette.gameLibraryBackground
        let fg = palette.settingsCellText ?? palette.gameLibraryText

        fpsHUDView.backgroundColor = bg.withAlphaComponent(palette.dark ? 0.55 : 0.70)
        fpsHUDView.layer.borderWidth = 1.0 / UIScreen.main.scale
        fpsHUDView.layer.borderColor = palette.defaultTintColor.withAlphaComponent(palette.dark ? 0.25 : 0.15).cgColor

        fpsLabel.textColor = fg
        fpsLabel.shadowColor = UIColor.black.withAlphaComponent(palette.dark ? 0.45 : 0.25)
        fpsLabel.shadowOffset = .init(width: 0, height: 1)
    }
    lazy var fpsLabel: UILabel = {
        let fpsLabel = UILabel()
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        fpsLabel.backgroundColor = .clear
        fpsLabel.textAlignment = .right // RTL: do not flip — FPS counter is always pinned to the right edge (not trailing) regardless of locale
        fpsLabel.lineBreakMode = .byClipping
        fpsLabel.isOpaque = false
        fpsLabel.numberOfLines = 5
        fpsLabel.adjustsFontSizeToFitWidth = false
        #if os(tvOS)
        fpsLabel.font = .monospacedSystemFont(ofSize: 22, weight: .regular)
        #else
        fpsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        #endif
        return fpsLabel
    }()

    /// Shows or hides the in-game FPS/CPU/Mem HUD based on user preference.
    /// Note: Skip-layout cores (e.g. RetroArch rendering its own view) do not use this HUD.
    @MainActor
    private func applyFPSCounterVisibilityPreference(_ enabled: Bool) {
        guard !core.skipLayout else { return }

        if enabled {
            initFPSLabel()
            fpsHUDView.alpha = 1.0
        } else {
            fpsTimer?.invalidate()
            fpsTimer = nil
            if let themeDidChangeObserver {
                NotificationCenter.default.removeObserver(themeDidChangeObserver)
                self.themeDidChangeObserver = nil
            }
            fpsHUDView.removeFromSuperview()
        }
    }

    private func configureFPSCounterPreferenceObservationIfNeeded() {
        guard showFPSCountCancellable == nil else { return }
        showFPSCountCancellable = Defaults.publisher(.showFPSCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                Task { @MainActor in
                    self.applyFPSCounterVisibilityPreference(change.newValue)
                }
            }
    }

    var secondaryScreen: UIScreen?
    var secondaryWindow: UIWindow?
    var menuGestureRecognizer: UITapGestureRecognizer?

    public var isShowingMenu: Bool = false {
        didSet {
            // Single authoritative pause toggle to avoid conflicting calls
            guard core.isOn, !isQuitting else { return }
            core.setPauseEmulation(isShowingMenu)
            setLiveActivityPaused(isShowingMenu)
        }
    }

    /// Set to true when quit is in progress to prevent pause/unpause calls
    /// that can crash RetroArch's runloop during teardown.
    private var isQuitting: Bool = false

    /// Tracks the currently presented pause-menu container so we can dismiss it reliably,
    /// even if additional controllers are presented on top during the menu flow.
    weak var menuPresentationViewController: UIViewController?

    let minimumPlayTimeToMakeAutosave: Double = 60

    /// Retrowave progress HUD shown during emulator boot (and rare one-time RetroArch sync/version updates)
    private var bootHUD: RetroProgressHUD?
    private var bootHUDIsVisible = false

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
        let coreId = core.coreIdentifier ?? ""
        let sysId = core.systemIdentifier ?? ""
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = coreId
                state.systemName = sysId
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

        // Initialize play time tracker and start observing core running state via Combine.
        playTimeTracker = PlayTimeTracker(game: game)
        observeRunningState()
    }

    /// Observes `core.isRunning` via Combine instead of raw KVO.
    ///
    /// `.removeDuplicates()` prevents back-to-back `true→true` fires (which happened
    /// when `setPauseEmulation(false)` was called twice) from double-starting the timer.
    private func observeRunningState() {
        runningCancellable = core.publisher(for: \.isRunning, options: [.new])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                guard let self else { return }
                if isRunning {
                    self.hideBootHUDIfNeeded()
                    self.playTimeTracker?.didResume()
                    /// Cores like RetroArch/Dolphin/Citra/PPSSPP overwrite our pause-button
                    /// bindings inside their own `setupController:` step, which runs after
                    /// `startEmulation` triggers `isRunning = true`. A second rebind at
                    /// +0.3s catches cores that attach controllers asynchronously during
                    /// the first frames of emulation (observed on the thin libretro wrapper).
                    self.reestablishPauseHandlers()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.reestablishPauseHandlers()
                    }
                } else {
                    self.playTimeTracker?.didPause()
                }
                #if os(tvOS) && canImport(SteamController)
                PVControllerManager.shared.setSteamControllersMode(isRunning ? .gameController : .keyboardAndMouse)
                #endif
            }
    }

    @MainActor
    private func showBootHUDIfNeeded() {
        guard !bootHUDIsVisible else { return }
        bootHUDIsVisible = true

        let hud = RetroProgressHUD.show(in: view, animated: true)
        hud.setText(initialBootHUDText())
        bootHUD = hud
    }

    @MainActor
    private func hideBootHUDIfNeeded() {
        guard bootHUDIsVisible else { return }
        bootHUDIsVisible = false

        bootHUD?.hide(animated: true, afterDelay: 0.1)
        bootHUD = nil
    }

    private func initialBootHUDText() -> String {
        if shouldShowRetroArchSyncMessage() {
            return "Updating RetroArch resources…"
        }
        return "Starting emulator…"
    }

    /// True when the running core is the thin libretro wrapper
    /// (`PVThinLibretroCore`). The thin wrapper does not ship or
    /// sync the RetroArch config bundle, so RetroArch-oriented
    /// boot messaging must be suppressed for it.
    private var isThinLibretroCore: Bool {
        NSStringFromClass(type(of: core)) == "PVThinLibretroCore"
    }

    private func shouldShowRetroArchSyncMessage() -> Bool {
        // The thin libretro wrapper shares "libretro" in its core
        // identifier but has no RetroArch resource sync step.
        if isThinLibretroCore { return false }

        guard (core.coreIdentifier?.contains("libretro") == true) || (core.coreIdentifier?.localizedCaseInsensitiveContains("retroarch") == true) else {
            return false
        }

        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !appVersion.isEmpty else {
            return false
        }

        let fm = FileManager.default
        let roots: [URL] = [
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        return !roots.contains(where: { root in
            let marker = root.appendingPathComponent("RetroArch/config/\(appVersion).cfg", isDirectory: false)
            return fm.fileExists(atPath: marker.path)
        })
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
        #if os(iOS) && !targetEnvironment(macCatalyst) && !os(macOS)
        let (trackpadView, cursorHost) = takeVirtualMouseCleanupHandles()
        let lightGunView = takeLightGunCleanupHandle()
        Task { @MainActor in
            trackpadView?.removeFromSuperview()
            cursorHost?.view.removeFromSuperview()
            cursorHost?.removeFromParent()
            lightGunView?.removeFromSuperview()
        }
        #endif
        #if os(iOS) || os(tvOS)
        Task.detached { @MainActor in
            PVControllerManager.shared.controllers.forEach { $0.clearPauseHandler() }
        }
        #endif
        // Safety net: cancel observer and flush any remaining play time.
        // UIViewController deinit is always on the main thread; assumeIsolated
        // is required because deinit is nonisolated even for @MainActor classes.
        MainActor.assumeIsolated {
            runningCancellable = nil
            playTimeTracker?.didPause()
        }
        destroyAutosaveTimer()
        // Remove iOS menu gesture recognizer if present. tvOS no longer installs any
        // UIPress menu gestures — pause input there comes exclusively from GCController.
        #if !os(tvOS)
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        #endif

        Task { @MainActor in
            let emulationUIState = AppState.shared.emulationUIState

            emulationUIState.core = nil
            emulationUIState.emulator = nil
        }
        runningCancellable = nil

        // Cancel the JIT indicator's Combine subscription (#2796).
        // UI teardown (removeJITIndicator) runs on the main actor in viewWillDisappear.
        cancelJITIndicatorSubscription()

        // Virtual keyboard / mouse cursor overlays are cleaned up in viewWillDisappear.
        // Associated objects are automatically released during dealloc.

        /// Safety net: resume all services if VC is torn down via an unexpected path
        Task { @MainActor in
            BackgroundServiceRegistry.shared.resumeAll(reason: .emulation)
        }
    }

    private func initNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.screenDidConnect(_:)), name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.screenDidDisconnect(_:)), name: UIScreen.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handleControllerManagerControllerReassigned(_:)), name: .PVControllerManagerControllerReassigned, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handlePause(_:)), name: Notification.Name("PauseGame"), object: nil)

        // DualSense microphone button → toggle audio mute
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handleMicButtonToggleMute(_:)), name: .PVControllerMicButtonToggleMute, object: nil)

        // Observer for Delta skin menu button reconnection
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.reconnectDeltaSkinMenuHandler(_:)), name: Notification.Name("DeltaSkinReconnectMenuHandler"), object: nil)

        // Observer for refreshing Delta skin after a skin change
        NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handleDeltaSkinChanged(_:)), name: Notification.Name("DeltaSkinChanged"), object: nil)

        #if !os(macOS)
        registerAudioRouteChangeObserver()
        #endif
        registerForOSDNotifications()
    }

    private func addControllerOverlay() {
        if let aController = controllerViewController {
            addChild(aController)
        }
        if let aView = controllerViewController?.view {
            view.addSubview(aView)
            ILOG("controllerViewController \(controllerViewController), core: \(core)")
            /// For RetroArch and PPSSPP cores, always attach the core's view hierarchy to `self`
            /// This ensures a stable container, regardless of skin mode, and avoids layout issues
            /// when switching between DeltaSkins and legacy controller overlays.
            if core.coreIdentifier?.contains("libretro") == true || core.coreIdentifier?.contains("ppsspp") == true {
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
        emulationState.emulator = self

        // Set up the GPU view
        setupGPUView()

        // Set up Delta Skin
        setupDeltaSkinDirectly()

        // Install toast overlay AFTER skin setup so it renders above all emulator views
        #if canImport(UIKit)
        toastHostingController = PVToastHostingController.install(in: self)
        #endif

        initNotificationObservers()

        // Initialize emulator asynchronously to support CloudKit downloads
        Task {
            do {
                await MainActor.run { self.showBootHUDIfNeeded() }
                try await createEmulator()
                //            } catch is CreateEmulatorError {
                //                let customError = error as! CreateEmulatorError
                //
                //                presentingViewController?.presentError(customError.localizedDescription, source: self.view)
            } catch let error as CloudSyncError {
                // Handle CloudSyncError cases
                if case .downloadCancelled = error {
                    // Download was cancelled - just dismiss, don't show error
                    ILOG("Emulator creation cancelled due to download cancellation")
                    await MainActor.run {
                        self.hideBootHUDIfNeeded()
                        self.dismiss(animated: true)
                    }
                    return
                }
                // Fall through to show error for other CloudSyncError cases
                let neError = error as NSError
            } catch {
                let neError = error as NSError

                //                if let presentingViewController = presentingViewController {
                //                    Task { @MainActor in
                //                        presentingViewController.presentError(error.localizedDescription, source: self.view)
                //                    }
                //                } else {
                Task { @MainActor in
                    self.hideBootHUDIfNeeded()
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
        /// Force GPU VC creation so RetroArch always has a valid renderDelegate even if we bail out early
        _ = gpuViewController

        // For RetroArch cores with skipLayout and no skins, RetroArch manages its own view hierarchy
        // Don't create/attach GPU view controller at all to avoid competing Metal layers
        let isRetroArchSkipLayout = core.coreIdentifier?.contains("libretro") == true && core.skipLayout

#if os(tvOS)
        /// tvOS has no controller overlay/skins, so let RetroArch anchor directly to the emulator VC when it skips layout
        if isRetroArchSkipLayout && core.touchViewController !== self {
            core.touchViewController = self
            DLOG("[RA][tvOS] Using PVEmulatorViewController as touchViewController host")
        }
#endif

        if isRetroArchSkipLayout && currentSkin == nil {
            ILOG("[RA] skipLayout + no skin: not attaching PVMetalViewController - RetroArch manages its own rendering")
            return
        }

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
        romPathMaybe = await handleArchives(atPath: romPathMaybe)

        //        guard let romPath = romPathMaybe else {
        //            throw CreateEmulatorError.gameHasNilRomPath
        //        }

        // Check if file needs download and handle with improved UI
        if await needsCloudKitDownload(for: game) {
            do {
                try await handleOnDemandDownload(for: game)
                /// Refresh ROM path after download completes
                romPathMaybe = game.file?.url
                /// Handle archives again in case the downloaded asset was a zip
                romPathMaybe = await handleArchives(atPath: romPathMaybe)
            } catch {
                // Download was cancelled or failed - dismiss emulator and return
                ELOG("Download cancelled or failed for \(game.title): \(error.localizedDescription)")
                await MainActor.run {
                    self.dismiss(animated: true)
                }
                throw error
            }
        }

        /// Rehydrate game from Realm to avoid stale/frozen file metadata after async sync/download work.
        if let refreshedGame = refreshedGameForROMResolution() {
            self.game = refreshedGame
            if romPathMaybe == nil {
                romPathMaybe = refreshedGame.file?.url
                romPathMaybe = await handleArchives(atPath: romPathMaybe)
            }
        }

        /// Ensure we have a valid ROM URL before attempting to load
        guard let romURL = romPathMaybe, !romURL.path.isEmpty else {
            ELOG("Cannot create emulator: ROM path is nil or empty for \(game.title)")
            await MainActor.run {
                self.dismiss(animated: true)
            }
            throw CreateEmulatorError.gameHasNilRomPath
        }
        /// Ensure file exists locally and is not an iCloud placeholder
        guard FileManager.default.fileExists(atPath: romURL.path), !needsDownload(romURL) else {
            ELOG("File doesn't exist at path \(romURL.path) for \(game.title)")
            #if !os(tvOS)
            UIPasteboard.general.string = romURL.path
            #endif
            await MainActor.run {
                self.dismiss(animated: true)
            }
            throw CreateEmulatorError.fileDoesNotExist(path: romURL.path)
        }

        ILOG("Loading ROM: \(romURL.path)")

        if let core = core as? any ObjCBridgedCore, let bridge = core.bridge as? EmulatorCoreIOInterface {
            try bridge.loadFile(atPath: romURL.path)
        } else {
            try core.loadFile(atPath: romURL.path)
        }

        // Route game view to an external display when one is already connected at launch,
        // the user has chosen dedicated mode, and the core reports supportsExternalDisplay == true.
        // In all other cases fall through to the normal primary-screen path below.
        let externalMode = Defaults[.externalDisplayMode]
        let externalScreens = UIScreen.screens.dropFirst()
        if let externalScreen = externalScreens.first, core.supportsExternalDisplay && externalMode == .dedicated {
            // attachGPUView performs UIKit view/window mutations — must run on the main actor.
            await MainActor.run {
                attachGPUView(to: externalScreen)
            }
        } else {
            // For RetroArch cores with skipLayout and no skins, GPU view controller is not attached
            // RetroArch manages its own view hierarchy (CocoaView + Metal/GL surfaces)
            let isRetroArchSkipLayout = core.coreIdentifier?.contains("libretro") == true && core.skipLayout

            #if os(tvOS)
            if core.skipLayout && !(isRetroArchSkipLayout && currentSkin == nil) {
                // Special handling for RetroArch cores on tvOS (only if using skins)
                addChild(gpuViewController)
                if let gpuView = gpuViewController.view {
                    gpuView.frame = view.bounds
                    gpuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    view.addSubview(gpuView)
                }
                gpuViewController.didMove(toParent: self)
            } else if !core.skipLayout {
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
            // For RetroArch skipLayout without skins, GPU view controller is not attached
            // (handled in setupGPUView which is called from viewDidLoad)
            #endif
        }
        #if os(iOS) && !targetEnvironment(macCatalyst) && !os(macOS)
        // Do not show legacy controller overlay when DeltaSkins are enabled
        if !isDeltaSkinEnabled {
            addControllerOverlay()
        }
        initMenuButton()
        // Install cursor overlay + touch trackpad for mouse-supporting cores, then wire
        // all virtual-input toggle closures and honour keyboard auto-show config.
        // setupVirtualMouseIfNeeded() is idempotent; setupVirtualInputOverlaysIfNeeded()
        // also calls it via showVirtualMouse when the core supports mouse.
        setupVirtualMouseIfNeeded()
        setupVirtualInputOverlaysIfNeeded()
        setupLightGunIfNeeded()
        #endif

        configureFPSCounterPreferenceObservationIfNeeded()
        Task { @MainActor in
            self.applyFPSCounterVisibilityPreference(Defaults[.showFPSCount])
        }

        hideOrShowMenuButton()

        convertOldSaveStatesToNewIfNeeded()

        try gameAudio.setupAudioGraph(for: core)
        try startAudio()

        /// Pause all background services during gameplay via the central registry
        BackgroundServiceRegistry.shared.pauseAll(reason: .emulation)

        // Note: pre-launch JIT education (contextual prompt + performance notice) is handled
        // by JITContextualPromptManager in GameLaunchingViewController before presentEMU is
        // called. A second in-emulator modal here would produce a double-alert for the user.
        // In-game JIT status is shown by JITStatusIndicatorViewController (HUD pill + toasts).

        // Apply any persisted Transfer Pak slot selections for this game before the core starts.
        await applyPersistedTransferPakIfNeeded()

        core.startEmulation()

        // Start Live Activity (Dynamic Island / lock screen) for this gameplay session.
        startLiveActivityIfNeeded()

        // Warn if device audio is muted or volume is zero (iOS/iPadOS only, once per session).
        #if os(iOS) && !targetEnvironment(macCatalyst)
        checkAudioMuteWarningAfterDelay()
        #endif

        // Start RetroAchievements session if the user is logged in and the core supports it.
        startAchievementsIfNeeded()

        // Register the core as the active netplay bridge if it supports PVNetplayCapable.
        #if canImport(PVNetplay)
        startNetplayBridgeIfNeeded()
        #endif

        // Connect MIDIDeviceManager to this core if it advertises MIDI support.
        core.attachMIDIResponder()

        // Set up the indicator light overlay (JIT status, etc.) — positioned in controller margin.
        setupIndicatorOverlay()

        // Wire up the JIT-specific status indicator (#2796).
        // Only shows for cores that actually require or benefit from JIT (gated by coreRequiresJIT()).
        setupJITIndicatorIfNeeded()

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
        let coreId2 = core.coreIdentifier ?? ""
        let sysId2 = core.systemIdentifier ?? ""
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = coreId2
                state.systemName = sysId2
                state.isOn = true
            }
        }
    }

    #if os(tvOS)
    /// tvOS pause-menu input is now driven exclusively by `GCController.setupPauseHandler`
    /// (buttonOptions on modern controllers, L3+R3 combo as fallback, and
    /// `controllerPausedHandler` for the Siri Remote). The previous double-tap-on-menu
    /// gesture and `findStartButton` fake-Start path have been removed: they raced the
    /// GCController handlers, depended on a controller overlay that doesn't exist on tvOS,
    /// and were not actually wired to anything that worked.
    private func setupTVOSMenuGestures() {
        // Intentionally empty — kept for symmetry with the previous viewDidAppear flow.
    }

    /// No-op shim retained so existing callers (e.g. CoreOptions cleanup) compile.
    /// We no longer manage UITapGestureRecognizers for the Siri Remote menu button.
    @objc func resetTVOSMenuGestures() {
        // Intentionally empty.
    }
    #endif

    /// Re-establish controller pause handlers after they were clobbered by a core's
    /// own input bindings, a presented modal, or a Control Center roundtrip. Cores
    /// such as RetroArch, Dolphin, Citra, PPSSPP, Play, and emuThree all overwrite
    /// `buttonOptions.pressedChangedHandler` (and on iOS, `buttonMenu`/`buttonHome`)
    /// during their own `setupController:`. Our pause binding from `setupControllers`
    /// therefore gets silently erased as soon as the core finishes initializing —
    /// which is *exactly* when the user would want to hit pause. Calling this after
    /// core init, after menu dismissal, and after app foregrounding makes pause
    /// survive the boot race consistently.
    @objc func reestablishPauseHandlers() {
        for controller in PVControllerManager.shared.controllers {
            controller.setupPauseHandler(onPause: {
                NotificationCenter.default.post(name: NSNotification.Name("PauseGame"), object: nil)
            })
        }
    }

    override public func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)

        /// Update safe area insets for cores that support it
        #if os(iOS)
        if let safeAreaCore = core as? EmulatorCoreSafeAreaSupport {
            safeAreaCore.updateSafeAreaInsets(view.safeAreaInsets)
        }
        #endif
        // Notifies UIKit that your view controller updated its preference regarding the visual indicator

        #if os(iOS)
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        #endif

        if Defaults[.timedAutoSaves] {
            createAutosaveTimer()
        }

        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Ensure the virtual-mouse trackpad uses the correct game viewport rect
        // now that the view hierarchy is fully laid out.
        refreshVirtualMouseLayout()
        refreshLightGunLayout()
        #endif

        #if os(iOS)
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
        #endif

        #if os(iOS) || os(tvOS)
        startClipBufferingIfAvailable()
        #endif

        #if os(tvOS)
        /// Defensive rebind: if a pre-launch modal (e.g. the SwiftUI version-mismatch
        /// alert shown by SceneCoordinator) left any GCController pause handler in a
        /// stale state, the initial `setupPauseHandler` call during viewDidLoad may
        /// have landed before focus was restored to the emulator scene. Rebinding
        /// here — and again a few frames later — makes the pause button reliable
        /// when booting from a save state that prompted the user first.
        reestablishPauseHandlers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.reestablishPauseHandlers()
        }
        #endif
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        #if os(iOS) || os(tvOS)
        // Only stop buffering when the VC is actually leaving the hierarchy, not
        // when it's temporarily covered by a modal (settings, pause menu, etc.).
        // Stopping on every viewWillDisappear would clear the rolling buffer, making
        // "Save Clip" unreliable after dismissing a modal sheet.
        if isMovingFromParent || isBeingDismissed {
            stopClipBuffering()
        }
        #endif
        destroyAutosaveTimer()
        #if !os(tvOS)
        removeVirtualInputOverlays()
        teardownLightGun()
        #endif
        #if os(tvOS)
        if isMovingFromParent || isBeingDismissed {
            teardownSiriRemoteForLightGun()
        }
        #endif
        // Remove the JIT indicator view controller on the main actor (#2796).
        // The Combine subscription is cancelled earlier in deinit via cancelJITIndicatorSubscription().
        removeJITIndicator()
        // Resign the Siri prediction activity when the game session ends so the OS
        // records a clean end-time for time-of-day learning. Setting to nil triggers
        // AppState.currentPlayActivity.didSet which calls resignCurrent().
        if isMovingFromParent || isBeingDismissed {
            AppState.shared.currentPlayActivity = nil
        }
    }

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Handle skin changes for orientation
        handleOrientationChange(to: size, with: coordinator)

        /// Update safe area insets for cores that support it after orientation change
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            if let safeAreaCore = self.core as? EmulatorCoreSafeAreaSupport {
                safeAreaCore.updateSafeAreaInsets(self.view.safeAreaInsets)
            }
            // Ensure skin container frame is updated during transition (important for fullscreen transitions)
            if let skinContainer = self.skinContainerView {
                skinContainer.frame = self.view.bounds
                if let hostView = skinContainer.subviews.first {
                    hostView.frame = skinContainer.bounds
                }
            }
        }, completion: { [weak self] _ in
            // Ensure skin container frame is correct after transition completes
            guard let self = self else { return }
            if let skinContainer = self.skinContainerView {
                skinContainer.frame = self.view.bounds
                if let hostView = skinContainer.subviews.first {
                    hostView.frame = skinContainer.bounds
                }
            }
            #if !os(tvOS)
            /// Final post-rotation sync: ensures virtual mouse gating and overlay
            /// stacking use the latest viewport after transition settles.
            self.refreshVirtualMouseLayout()
            self.bringVirtualInputOverlaysToFront()
            #endif
        })
    }

    // MARK: - CloudKit Download Handling

    /// Resolves the latest Realm-backed game row before final ROM URL resolution.
    /// This prevents stale snapshots from carrying pre-download file metadata.
    private func refreshedGameForROMResolution() -> PVGame? {
        let md5 = game.md5Hash
        guard !md5.isEmpty else {
            return nil
        }
        return RomDatabase.sharedInstance.game(withMD5: md5)
    }

    /// Check if a game needs CloudKit download
    /// - Parameter game: The game to check
    /// - Returns: True if the game needs to be downloaded from CloudKit
    private func needsCloudKitDownload(for game: PVGame) async -> Bool {
        // Use FileLocationResolver for consistent multi-location checking.
        // This checks local Documents/Caches first, then iCloud Drive container.
        if let partialPath = game.file?.partialPath, !partialPath.isEmpty {
            let resolution = FileLocationResolver.shared.resolve(partialPath)
            if let resolvedURL = resolution.url {
                // File found — check if it's an iCloud placeholder (not yet materialized)
                if needsDownload(resolvedURL) {
                    VLOG("Game \(game.title) is an iCloud placeholder at \(resolvedURL.path) - needs download")
                    return true
                }
                return false
            }
        }

        // Fallback: check game.file.url directly (handles edge cases where
        // partialPath is empty but url is set via other means)
        if let fileURL = game.file?.url,
           FileManager.default.fileExists(atPath: fileURL.path),
           !needsDownload(fileURL) {
            return false
        }

        VLOG("Game \(game.title) file not found locally - needs download")
        return true
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

    /// Show download progress UI with cancel option using SceneCoordinator's syncStatusManager
    /// - Parameter game: The game being downloaded
    private func showDownloadProgress(for game: PVGame) async throws {
        let gameMD5 = game.md5Hash ?? ""
        let gameTitle = game.title

        // Use the unified syncStatusManager for consistent UI
        let syncStatusManager = SceneCoordinator.shared.syncStatusManager

        // Only show UI if not already visible (avoids duplicate overlays)
        let shouldShowUI = await MainActor.run { !syncStatusManager.isVisible }

        if shouldShowUI {
            await MainActor.run {
                syncStatusManager.show(
                    gameTitle: gameTitle,
                    statusMessage: "Downloading from iCloud...",
                    onCancel: { [weak self] in
                        ILOG("User cancelled download for: \(gameTitle)")
                        CloudKitDownloadQueue.shared.cancelDownload(md5: gameMD5)
                        syncStatusManager.hide()
                        Task { @MainActor in
                            self?.dismiss(animated: true)
                        }
                    }
                )
            }
        }

        // Start progress monitoring task
        let progressTask = Task { @MainActor in
            let progressTracker = SyncProgressTracker.shared
            var lastProgress: Double = 0

            while !Task.isCancelled {
                if let activeDownload = progressTracker.activeDownloads.first(where: { $0.matchesROM(md5: gameMD5) }) {
                    let progress = activeDownload.progress
                    if progress != lastProgress {
                        syncStatusManager.update(downloadProgress: DownloadProgress(
                            progress: progress,
                            bytesDownloaded: activeDownload.bytesDownloaded,
                            totalBytes: activeDownload.fileSize
                        ))
                        lastProgress = progress
                    }
                } else if progressTracker.queuedDownloads.contains(where: { $0.matchesROM(md5: gameMD5) }) {
                    syncStatusManager.update(statusMessage: "Queued for download...")
                }

                try? await Task.sleep(nanoseconds: 500_000_000) // Update every 0.5 seconds
            }
        }

        defer {
            progressTask.cancel()
        }

        /// Wait for download to start and then complete (or fail)
        return try await withCheckedThrowingContinuation { continuation in
            let progressTracker = SyncProgressTracker.shared
            var cancellables = Set<AnyCancellable>()
            var hasStarted = false
            var hasResumed = false

            Publishers.CombineLatest3(
                progressTracker.$queuedDownloads,
                progressTracker.$activeDownloads,
                progressTracker.$failedDownloads
            )
            .receive(on: DispatchQueue.main)
            .sink { queued, active, failed in
                guard !hasResumed else { return }

                let inQueued = queued.contains { $0.matchesROM(md5: gameMD5) }
                let inActive = active.contains { $0.matchesROM(md5: gameMD5) }
                let hasFailed = failed.contains { $0.matchesROM(md5: gameMD5) }

                if inQueued || inActive { hasStarted = true }

                if hasFailed {
                    hasResumed = true
                    cancellables.removeAll()
                    syncStatusManager.error("Download failed")
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run { syncStatusManager.hide() }
                    }
                    if let failure = failed.first(where: { $0.matchesROM(md5: gameMD5) }) {
                        ELOG("Download failed for \(gameTitle): \(failure.error)")
                        continuation.resume(throwing: failure.error)
                    } else {
                        ELOG("Download failed for \(gameTitle): Unknown error")
                        continuation.resume(throwing: CloudSyncError.unknown)
                    }
                    return
                }

                // Check if download was cancelled (removed from queue without being in failed)
                let inQueuedOrActive = inQueued || inActive
                if hasStarted && !inQueuedOrActive && !hasFailed {
                    hasResumed = true
                    cancellables.removeAll()

                    // Check if the file now exists (successful download) vs cancelled
                    let fileExists = FileManager.default.fileExists(atPath: game.file?.url?.path ?? "")
                    if fileExists {
                        // Completed successfully
                        syncStatusManager.complete()
                        continuation.resume()
                    } else {
                        // Download was cancelled
                        syncStatusManager.hide()
                        ELOG("Download cancelled for \(gameTitle)")
                        continuation.resume(throwing: CloudSyncError.downloadCancelled)
                    }
                    return
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

            let message = """
            Cannot download \(gameTitle).

            Required: \(requiredStr)
            Available: \(availableStr)

            To free up space:
            • Delete unused games or save states
            • Remove large media files
            • Clear app cache in Settings
            • Offload unused apps

            After freeing space, try downloading again.
            """
            let alert = UIAlertController(
                title: "Insufficient Storage",
                message: message,
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

        /// Update safe area insets for cores that support it
        if let safeAreaCore = core as? EmulatorCoreSafeAreaSupport {
            safeAreaCore.updateSafeAreaInsets(view.safeAreaInsets)
        }

        /// CRITICAL: Ensure skin container stays visible and on top after layout
        /// This prevents the GPU view from covering the skin container on iPad
        if isDeltaSkinEnabled, let skinContainer = skinContainerView {
            skinContainer.frame = view.bounds
            if let hostView = skinContainer.subviews.first {
                hostView.frame = skinContainer.bounds
            }
            skinContainer.isHidden = false
            skinContainer.alpha = 1.0
            if let gpuView = gpuViewController.view, gpuView.superview == view {
                view.insertSubview(gpuView, belowSubview: skinContainer)
            }
            view.bringSubviewToFront(skinContainer)
        }

        #if !os(tvOS)
        /// Restore correct z-order for virtual input overlays (trackpad, keyboard,
        /// controller, cursor, menu) on EVERY layout pass — not just for DeltaSkins.
        /// Without this, the trackpad sits above controller buttons and the menu
        /// button after initial setup, blocking all touches.
        bringVirtualInputOverlaysToFront()
        refreshVirtualMouseLayout()
        refreshLightGunLayout()
        #endif
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

    @MainActor
    public func quit(optionallySave canSave: Bool = true, completion: QuitCompletion? = nil) async {
        isQuitting = true
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
        /// Resume all background services after gameplay via the central registry
        BackgroundServiceRegistry.shared.resumeAll(reason: .emulation)

        // Cancel the Combine observer before stopping the core so the sink doesn't
        // deliver a redundant didPause() after we explicitly flush below.
        runningCancellable = nil

        // Deregister the netplay bridge before stopping the core.
        // Awaited so disconnect() completes before RetroArch globals are torn down.
        #if canImport(PVNetplay)
        await stopNetplayBridge()
        #endif

        // Tear down RetroAchievements session before stopping the core.
        stopAchievements()

        // Remove indicator overlay
        removeIndicatorOverlay()

        // Detach MIDI responder before tearing down the core.
        #if canImport(CoreMIDI) && !os(tvOS)
        if #available(iOS 15, tvOS 15, *) {
            MIDIDeviceManager.shared.setResponder(nil)
        }
        #endif

        // End Live Activity before the core shuts down.
        endLiveActivity()

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
        playTimeTracker?.didPause()

        #if canImport(PVAppIntents)
        Task { @MainActor in
            WidgetDataWriter.shared.writeFromRealm()
        }
        #endif

        destroyAutosaveTimer()
        #if !os(tvOS)
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        #endif

        let emulationUIState = AppState.shared.emulationUIState

        emulationUIState.core = nil
        emulationUIState.emulator = nil

        Task {
            await EmulationState.shared.setIsOn(false)
        }

        fpsTimer?.invalidate()
        fpsTimer = nil
        showFPSCountCancellable?.cancel()
        showFPSCountCancellable = nil
        if let themeDidChangeObserver {
            NotificationCenter.default.removeObserver(themeDidChangeObserver)
            self.themeDidChangeObserver = nil
        }
        fpsHUDView.removeFromSuperview()

        dismiss(animated: true, completion: completion)
        view?.removeFromSuperview()
        removeFromParent()
        staticSelf = nil

        AppState.shared.emulationUIState.reset()
    }

    /// Dismisses the currently presented navigation and optionally resumes emulation
    /// - Parameter resumeEmulation: Whether to resume emulation after dismissal. Defaults to true.
    @objc
    func dismissNav() {
        dismissNav(resumeEmulation: true)
    }

    /// Dismisses the currently presented navigation with control over emulation state
    /// - Parameter resumeEmulation: Whether to resume emulation after dismissal
    func dismissNav(resumeEmulation: Bool) {
        dismissNav(resumeEmulation: resumeEmulation, completion: nil)
    }

    /// Restores controller/gesture state after menu dismissal so tvOS pause input remains reliable.
    @MainActor
    private func restoreInputStateAfterMenuDismissal() {
        enableControllerInput(false)
        #if os(tvOS)
        resetTVOSMenuGestures()
        // Rebind pause-button handlers. Presenting a modal can leave the
        // GCController pressedChangedHandlers in a stale state (the system
        // retargets focus while `controllerUserInteractionEnabled` was true),
        // which manifests as the pause menu refusing to reopen after any
        // tile tap that also dismissed the menu.
        reestablishPauseHandlers()
        #endif
    }

    func dismissNav(resumeEmulation: Bool, completion: (() -> Void)?) {
        // Dismiss the menu container reliably if we have it; otherwise fall back to the currently presented VC.
        let dismissalTarget = menuPresentationViewController ?? presentedViewController
        guard let dismissalTarget else {
            isShowingMenu = false
            if core.isOn {
                core.setPauseEmulation(!resumeEmulation)
            }
            restoreInputStateAfterMenuDismissal()
            completion?()
            return
        }

        dismissalTarget.dismiss(animated: true) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            self.menuPresentationViewController = nil
            // Always clear the menu state when dismissing
            self.isShowingMenu = false
            // Keep core pause state consistent even when menu state was already false
            // (e.g., dismissing Game Info after the pause menu was already dismissed).
            if self.core.isOn {
                self.core.setPauseEmulation(!resumeEmulation)
            }
            completion?()
        }

        // Post notifications to reconnect inputs and refresh the GPU view
        NotificationCenter.default.post(name: NSNotification.Name("DeltaSkinInputHandlerReconnect"), object: nil)

        // Make sure the GPU view is refreshed
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Use the safer method to refresh the GPU view
//            metalVC.safelyRefreshGPUView()
        }

        // If using a DeltaSkin, ensure game screen view is visible and positioned properly
        if let skinContainerView = view.viewWithTag(9876), let gpuView = gpuViewController.view {
            // Make sure the GPU view is visible on top of the proper layer
            gpuView.alpha = 1.0
            gpuView.isHidden = false

            // If we have a stored target frame, ensure the GPU view is positioned there
            if let targetFrame = currentTargetFrame {
                UIView.animate(withDuration: 0.2) {
                    gpuView.frame = targetFrame
                }
            }
        }

        restoreInputStateAfterMenuDismissal()
    }
}


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

        // Store the current skin for rotation handling (will be updated after fallback check)

        // When applying a skin, ensure GPU view controller exists and is visible (it's used by the skin system)
        // If it wasn't created before (e.g., RetroArch skipLayout without skin), create it now
        if gpuViewController.parent === nil {
            ILOG("[RA] Creating GPU view controller for skin application")
            setupGPUView()
        }

        if let gpuView = gpuViewController.view {
            gpuView.isHidden = false
            gpuView.alpha = 1.0
        }

        // Clear dual screen frame cache when skin changes
        clearReceivedScreenFrames()

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

        // Check if skin supports current orientation, find fallback if not
        var skinToApply = try await findSkinWithFallback(skin: skin, orientation: currentOrientation)

        // CRITICAL: Validate BEFORE creating view - check if skin can actually render
        // This catches cases where supports() returns true but representation/mappingSize is missing
        let canRender = await validateSkinCanRender(skin: skinToApply, orientation: currentOrientation)
        if !canRender {
            ILOG("skins: Skin '\(skinToApply.name)' cannot render for \(currentOrientation.rawValue), finding fallback")
            // Try to find a fallback skin that can actually render
            if let fallbackSkin = try? await findFallbackSkinForFailedSkin(
                failedSkin: skinToApply,
                orientation: currentOrientation
            ) {
                ILOG("skins: Found fallback skin '\(fallbackSkin.name)'")
                skinToApply = fallbackSkin
            } else {
                // No fallback found, MUST use default skin
                ILOG("skins: No fallback found, MUST use default skin")
                let systemId = game.system?.systemIdentifier ?? SystemIdentifier.RetroArch
                skinToApply = EmulatorWithSkinView.defaultSkin(for: systemId)
                ILOG("skins: Using default skin '\(skinToApply.name)' for system \(systemId.rawValue)")
            }
        }

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

        // Try to create the skin view, with fallback to default if it fails
        // Note: skinToApply has already been validated and may be a fallback/default skin
        var skinView: UIView
        var finalSkin = skinToApply
        let systemId = game.system?.systemIdentifier ?? SystemIdentifier.RetroArch

        do {
            skinView = try await createSkinView(from: skinToApply)
            finalSkin = skinToApply
        } catch {
            // If creation fails, MUST use default skin
            ILOG("skins: Failed to create skin view for '\(skinToApply.name)': \(error), using default skin")
            finalSkin = EmulatorWithSkinView.defaultSkin(for: systemId)
            ILOG("skins: Using default skin '\(finalSkin.name)' for system \(systemId.rawValue)")
            skinView = try await createSkinView(from: finalSkin)
        }

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

            // Force recalculation of screen position for the new skin (use finalSkin which may be fallback)
            repositionGameScreen(for: finalSkin, orientation: currentOrientation, forceRecalculation: true)

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

            // 8. Post notification that the skin has changed to trigger input handler reconnection (use finalSkin)
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinChanged"),
                object: nil,
                userInfo: ["skinIdentifier": finalSkin.identifier]
            )

            // Update currentSkin to the final skin that was actually applied
            currentSkin = finalSkin

            // Also post a reconnect notification to ensure proper input handling
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
                object: nil
            )

            // Make sure to reconnect all input handlers
            reconnectAllInputHandlers()

            // Skin fully applied; resume emulation
            core.setPauseEmulation(false)

            // Re-raise virtual input overlays above the newly added skin views
            #if !os(tvOS)
            bringVirtualInputOverlaysToFront()
            #endif
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

        // Create the traits object for the skin, including game context for per-game overrides
        let traits = DeltaSkinTraits(
            device: currentDevice,
            displayType: displayType,
            orientation: currentOrientation == .landscape ? .landscape : .portrait,
            gameIdentifier: game?.title
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
            preselectedSkinIdentifier: skin.identifier,
            inputHandler: inputHandler,
            virtualInputState: self.virtualInputState
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

        // If DeltaSkin is enabled, let the DeltaSkin viewport system handle positioning
        // Don't override with this legacy method
        if isDeltaSkinEnabled {
            DLOG("DeltaSkin enabled - skipping repositionGameScreen, using DeltaSkin viewport system")
            // Just ensure we apply any pending frame from DeltaSkin system
            if let targetFrame = currentTargetFrame {
                applyFrameToGPUView(targetFrame)
            }
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
            if let originalFrame = originalCalculatedFrame, let gpuView = gpuViewController.view {
                gpuView.frame = originalFrame
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

        // Collect views that must survive cleanup — virtual input overlays
        // (trackpad, cursor, keyboard) are installed once and referenced via
        // associated objects; removing them without clearing those references
        // leaves orphaned views that can never be re-created.
        var preservedViews: Set<ObjectIdentifier> = []
        if let gpuView { preservedViews.insert(ObjectIdentifier(gpuView)) }
        #if !os(tvOS)
        if let trackpad = touchTrackpadView {
            preservedViews.insert(ObjectIdentifier(trackpad))
        }
        if let cursorView = cursorHostingController?.view {
            preservedViews.insert(ObjectIdentifier(cursorView))
        }
        if let keyboardContainer = virtualKeyboardContainer {
            preservedViews.insert(ObjectIdentifier(keyboardContainer))
        }
        #endif
        if let mb = menuButton {
            preservedViews.insert(ObjectIdentifier(mb))
        }
        // Preserve the toast overlay container (parent of the hosting controller's view)
        if let toastContainer = toastHostingController?.view.superview {
            preservedViews.insert(ObjectIdentifier(toastContainer))
        }

        // 2. Remove ALL child view controllers except the GPU controller,
        // virtual-input hosting controllers, and the toast overlay.
        let preservedControllers: Set<ObjectIdentifier> = {
            var set: Set<ObjectIdentifier> = [ObjectIdentifier(gpuViewController)]
            #if !os(tvOS)
            if let cursorHost = cursorHostingController {
                set.insert(ObjectIdentifier(cursorHost))
            }
            if let kbHost = virtualKeyboardHostingVC {
                set.insert(ObjectIdentifier(kbHost))
            }
            #endif
            if let toastHost = toastHostingController {
                set.insert(ObjectIdentifier(toastHost))
            }
            return set
        }()
        for child in children {
            if !preservedControllers.contains(ObjectIdentifier(child)) {
                DLOG("Removing controller: \(child)")
                child.willMove(toParent: nil)
                child.view.removeFromSuperview()
                child.removeFromParent()
            }
        }

        // 3. Clear all tracked hosting controllers
        skinHostingControllers.removeAll()

        // 4. Remove ALL subviews from the main view except preserved views
        for subview in view.subviews {
            if !preservedViews.contains(ObjectIdentifier(subview)) {
                DLOG("Removing view: \(subview)")
                subview.removeFromSuperview()
            }
        }

        // Also remove any skin containers that might be nested
        if let gpuView = gpuView {
            for subview in gpuView.superview?.subviews ?? [] {
                if subview.tag == 9876 || type(of: subview).description().contains("DeltaSkinContainerView") {
                    DLOG("Removing nested skin container view: \(subview)")
                    subview.removeFromSuperview()
                }
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

        // 6b. Ensure toast overlay stays on top after cleanup
        if let toastContainer = toastHostingController?.view.superview {
            view.bringSubviewToFront(toastContainer)
        }

        // 7. Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()

        // 8. Print the final view hierarchy
        DLOG("View hierarchy after radical cleanup:")
        printViewHierarchyRecursively(view, level: 0)
    }

    /// Validate that a skin can actually render (has valid layout)
    /// - Parameters:
    ///   - skin: The skin to validate
    ///   - orientation: The current orientation
    /// - Returns: True if the skin can render, false otherwise
    private func validateSkinCanRender(skin: DeltaSkinProtocol, orientation: SkinOrientation) async -> Bool {
        // Check if the skin has a valid mappingSize for the current traits
        // This is what causes calculateLayout() to return nil
        let device: DeltaSkinDevice = {
            #if os(tvOS)
            return .tv
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
            #endif
        }()

        let displayTypes: [DeltaSkinDisplayType] = [.edgeToEdge, .standard]
        let deltaOrientation = orientation.deltaSkinOrientation

        // Check if skin has a valid mappingSize - this is what calculateLayout() needs
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(
                device: device,
                displayType: displayType,
                orientation: deltaOrientation
            )

            // Check if skin supports these traits
            if skin.supports(traits) {
                // Check if representation exists - this is what actually fails in the error
                guard let _ = skin.representation(for: traits) else {
                    ILOG("skins: Skin '\(skin.name)' supports \(orientation.rawValue) but has no representation")
                    continue
                }
                // Also check if mappingSize exists - required for calculateLayout()
                guard let mappingSize = skin.mappingSize(for: traits), mappingSize.width > 0 && mappingSize.height > 0 else {
                    ILOG("skins: Skin '\(skin.name)' supports \(orientation.rawValue) but has no valid mappingSize")
                    continue
                }
                ILOG("skins: Skin '\(skin.name)' has valid representation and mappingSize \(mappingSize) for \(orientation.rawValue)")
                return true
            }
        }

        return false
    }

    /// Find a fallback skin when the requested skin fails to render
    /// - Parameters:
    ///   - failedSkin: The skin that failed
    ///   - orientation: The current orientation
    /// - Returns: A fallback skin that can render, or nil if none found
    private func findFallbackSkinForFailedSkin(failedSkin: DeltaSkinProtocol, orientation: SkinOrientation) async throws -> DeltaSkinProtocol? {
        guard let systemId = game.system?.systemIdentifier else {
            return nil
        }

        let availableSkins = try await DeltaSkinManager.shared.skins(for: systemId)
        let device: DeltaSkinDevice = {
            #if os(tvOS)
            return .tv
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
            #endif
        }()

        let displayTypes: [DeltaSkinDisplayType] = [.edgeToEdge, .standard]
        let deltaOrientation = orientation.deltaSkinOrientation

        // Try to find first available skin that can actually render
        let allowCaseSkins = CaseControllerDetector.isKnownPhysicalCaseControllerConnected
        for fallbackSkin in availableSkins {
            // Skip the failed skin
            if fallbackSkin.identifier == failedSkin.identifier {
                continue
            }
            if !allowCaseSkins && CaseControllerDetector.isCompanionSkinForKnownCase(fallbackSkin.identifier) {
                continue
            }

            // Check if fallback skin supports this orientation and can render
            for displayType in displayTypes {
                let traits = DeltaSkinTraits(
                    device: device,
                    displayType: displayType,
                    orientation: deltaOrientation
                )
                if fallbackSkin.supports(traits) {
                    // Validate it has a valid representation (what actually fails)
                    guard let _ = fallbackSkin.representation(for: traits) else {
                        continue
                    }
                    // Also validate mappingSize exists (required for calculateLayout)
                    guard let mappingSize = fallbackSkin.mappingSize(for: traits), mappingSize.width > 0 && mappingSize.height > 0 else {
                        continue
                    }
                    ILOG("skins: Found fallback skin '\(fallbackSkin.name)' with valid representation and mappingSize \(mappingSize) for \(orientation.rawValue)")
                    return fallbackSkin
                }
            }
        }

        return nil
    }

    /// Find a skin with fallback if the requested skin doesn't support the current orientation
    /// - Parameters:
    ///   - skin: The requested skin
    ///   - orientation: The current orientation
    /// - Returns: A skin that supports the orientation (fallback or default if needed)
    private func findSkinWithFallback(skin: DeltaSkinProtocol, orientation: SkinOrientation) async throws -> DeltaSkinProtocol {
        // Check if the requested skin supports the current orientation
        let device: DeltaSkinDevice = {
            #if os(tvOS)
            return .tv
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
            #endif
        }()

        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        let deltaOrientation = orientation.deltaSkinOrientation

        // Check if skin supports this orientation AND has valid mappingSize
        var supportsOrientation = false
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(
                device: device,
                displayType: displayType,
                orientation: deltaOrientation
            )
            if skin.supports(traits) {
                // Check if representation exists (what actually fails in the error)
                guard let _ = skin.representation(for: traits) else {
                    ILOG("skins: Skin '\(skin.name)' supports \(orientation.rawValue) but has no representation")
                    continue
                }
                // Also check for valid mappingSize - required for calculateLayout()
                guard let mappingSize = skin.mappingSize(for: traits), mappingSize.width > 0 && mappingSize.height > 0 else {
                    ILOG("skins: Skin '\(skin.name)' supports \(orientation.rawValue) but has no valid mappingSize")
                    continue
                }
                supportsOrientation = true
                break
            }
        }

        if supportsOrientation {
            ILOG("skins: Skin '\(skin.name)' supports \(orientation.rawValue) orientation with valid mappingSize")
            return skin
        }

        // Skin doesn't support orientation, find fallback
        ILOG("skins: Skin '\(skin.name)' doesn't support \(orientation.rawValue), finding fallback")

        guard let systemId = game.system?.systemIdentifier else {
            // No system ID, use default skin
            ILOG("skins: No system ID, using default skin")
            return EmulatorWithSkinView.defaultSkin(for: SystemIdentifier.RetroArch)
        }

        // Get all available skins for this system
        let availableSkins = try await DeltaSkinManager.shared.skins(for: systemId)

        // Try to find first available skin that supports this orientation
        let allowCaseSkinsOrientation = CaseControllerDetector.isKnownPhysicalCaseControllerConnected
        for fallbackSkin in availableSkins {
            // Skip the requested skin
            if fallbackSkin.identifier == skin.identifier {
                continue
            }
            if !allowCaseSkinsOrientation && CaseControllerDetector.isCompanionSkinForKnownCase(fallbackSkin.identifier) {
                continue
            }

            // Check if fallback skin supports this orientation AND has valid mappingSize
            for displayType in displayTypes {
                let traits = DeltaSkinTraits(
                    device: device,
                    displayType: displayType,
                    orientation: deltaOrientation
                )
                if fallbackSkin.supports(traits) {
                    // Validate it has a valid representation (what actually fails)
                    guard let _ = fallbackSkin.representation(for: traits) else {
                        continue
                    }
                    // Also validate mappingSize exists (required for calculateLayout)
                    guard let mappingSize = fallbackSkin.mappingSize(for: traits), mappingSize.width > 0 && mappingSize.height > 0 else {
                        continue
                    }
                    ILOG("skins: Found fallback skin '\(fallbackSkin.name)' with valid representation and mappingSize \(mappingSize) for \(orientation.rawValue)")
                    return fallbackSkin
                }
            }
        }

        // No fallback skin found, MUST use default skin
        ILOG("skins: No fallback skin found for \(orientation.rawValue), MUST use default skin")
        let defaultSkin = EmulatorWithSkinView.defaultSkin(for: systemId)
        ILOG("skins: Returning default skin '\(defaultSkin.name)' for system \(systemId.rawValue)")
        return defaultSkin
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

    /// Ensure proper z-order of views in the hierarchy.
    ///
    /// Works for both DeltaSkin mode (with a skin container) and legacy
    /// PVControllerViewController mode (no skin container).
    private func ensureProperZOrder() {
        guard let gpuView = gpuViewController.view else { return }

        if gpuView.superview !== view {
            gpuView.removeFromSuperview()
            view.addSubview(gpuView)
        }

        /// Skin container handling — only when DeltaSkins are active.
        if let skinContainer = skinContainerView {
            if skinContainer.superview !== view {
                view.addSubview(skinContainer)
            }
            if gpuView.superview == view && skinContainer.superview == view {
                view.insertSubview(gpuView, belowSubview: skinContainer)
            }
            view.bringSubviewToFront(skinContainer)
        }

        #if os(iOS)
        if let visualizerView = audioVisualizerHostingController?.view {
            view.bringSubviewToFront(visualizerView)
            if UIDevice.current.userInterfaceIdiom == .phone {
                let orientation = UIDevice.current.orientation
                let isPortrait = orientation == .portrait || orientation == .portraitUpsideDown || orientation == .unknown
                if isPortrait && visualizerMode != .off {
                    visualizerView.isHidden = false
                    visualizerView.alpha = 1.0
                }
            }
        }
        #endif

        #if !os(tvOS)
        bringVirtualInputOverlaysToFront()
        #endif
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
            } else if let gpuView = self.gpuViewController.view {
                gpuView.frame = self.view.bounds
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

                    let prefersBuiltIn: Bool = {
                        guard let sid = systemId else { return false }
                        if !gameId.isEmpty {
                            return DeltaSkinSelectionManager.shared.prefersBuiltInControllerSkin(for: sid, gameId: gameId, orientation: newOrientation)
                        }
                        return DeltaSkinSelectionManager.shared.prefersBuiltInControllerSkin(for: sid, gameId: nil, orientation: newOrientation)
                    }()

                    let currentId = self.currentSkin?.identifier
                    DLOG("Effective skin id: \(effectiveId ?? "nil"), current: \(currentId ?? "nil"), prefersBuiltIn: \(prefersBuiltIn)")

                    // Built-in choice: do not keep a stray `.deltaskin` on screen when effective id is nil.
                    if effectiveId == nil, prefersBuiltIn, let current = self.currentSkin {
                        let isSwiftUIDefault = current.identifier.hasPrefix("default-") ||
                            current.identifier == "default" ||
                            current.name.lowercased() == "default"
                        if !isSwiftUIDefault {
                            try? await self.resetToDefaultSkin()
                            self.ensureProperZOrder()
                            return
                        }
                    }

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
                if let gpuView = self.gpuViewController.view {
                    gpuView.frame = self.view.bounds
                    self.ensureProperZOrder()
                }
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
        // Update currentSkin and currentOrientation for viewport calculation
        self.currentSkin = skin
        self.currentOrientation = orientation

        // Preserve the last frame and custom positioning to prevent viewDidLayoutSubviews from recalculating
        // The new frame will arrive via protocol/notification shortly
        let lastFrame = self.currentTargetFrame
        let lastUseCustomPositioning = (gpuViewController as? PVGPUViewController)?.useCustomPositioning ?? false
        let lastCustomFrame = (gpuViewController as? PVGPUViewController)?.customFrame ?? .zero

        // Clear cached frame to force recalculation for new orientation
        // The color bars notification will provide the new frame
        self.currentTargetFrame = nil
        self.lastAppliedViewportFrame = nil

        // Use the new viewport system to recalculate position
        self.applyViewportFromCurrentSkin()

        // Don't restore last frame after rotation - it's from the wrong orientation
        // The protocol delegate callback (viewportFrameDidUpdate) will arrive shortly with the correct frame for the new orientation
        // Only wait and check if frame arrived, don't restore old frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            // If still no frame after waiting, the protocol delegate should have provided one
            // Don't restore the old frame as it's from the wrong orientation
            if self.currentTargetFrame == nil {
                DLOG("🎮 SKIN: No frame received after rotation - protocol delegate callback may be delayed")
                // Let applyViewportFromCurrentSkin handle fallback if needed
            }
        }

        if let skinView = self.skinContainerView {
            skinView.frame = self.view.bounds
            skinView.setNeedsLayout()
            skinView.layoutIfNeeded()
        }

        // Force SwiftUI to recalculate frame after rotation
        NotificationCenter.default.post(name: NSNotification.Name("DeltaSkinForceRecalculate"), object: nil)

        // For RetroArch, re-apply internal render view frame to keep it visible
        // Wait a bit for viewport to be recalculated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }

            // Check if this is a default skin - default skins use their own calculation system
            let isDefaultSkin = skin.identifier.hasPrefix("default-") ||
                               skin.identifier == "default" ||
                               skin.name.lowercased() == "default"

            // For default skins, don't use fallback - they broadcast frames via protocol
            // The protocol callback should have arrived by now (0.4 seconds)
            if isDefaultSkin {
                if let frame = self.currentTargetFrame {
                    // Frame received via protocol - apply it
                    self.applyFrameToGPUView(frame)
                } else {
                    DLOG("🎮 SKIN: Default skin - no frame received after rotation, protocol callback may be delayed")
                    // Don't use fallback for default skins - let the protocol system handle it
                }
                return
            }

            // For non-default skins and non-RetroArch cores, ensure we have a frame
            if self.core.coreIdentifier?.contains("libretro") != true {
                // If we still don't have a frame, calculate one manually
                if self.currentTargetFrame == nil {
                    DLOG("🎮 SKIN: No frame received for non-RetroArch core, calculating fallback")
                    if let calculatedFrame = self.currentSkinViewportFrame() {
                        self.currentTargetFrame = calculatedFrame
                        self.applyFrameToGPUView(calculatedFrame)
                    }
                } else {
                    // Apply the frame we have
                    self.applyFrameToGPUView(self.currentTargetFrame!)
                }
            }

            // CRITICAL: Ensure parent view is laid out before coordinate conversion for landscape
            if self.core.coreIdentifier?.contains("libretro") == true,
               let frame = self.currentTargetFrame,
               let viewport = (self.core.bridge as? EmulatorCoreViewportPositioning) {
                viewport.setUseCustomRenderViewLayout(true)
                let parent = (self.core.touchViewController ?? self).view

                // Force layout update on parent view first to ensure correct coordinate system
                parent?.setNeedsLayout()
                parent?.layoutIfNeeded()

                // Ensure parent has valid bounds before conversion
                guard let parent = parent, parent.bounds.width > 0 && parent.bounds.height > 0 else {
                    DLOG("WARNING: Parent view has invalid bounds: \(parent?.bounds ?? .zero), deferring RA viewport update")
                    // Defer the update until next run loop when bounds should be valid
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self,
                              let parent = (self.core.touchViewController ?? self).view,
                              parent.bounds.width > 0 && parent.bounds.height > 0 else { return }
                        let rectInParent = self.view.convert(frame, to: parent)
                        if orientation == .landscape {
                            let clampedRect = CGRect(
                                x: max(0, min(rectInParent.origin.x, parent.bounds.width - rectInParent.width)),
                                y: max(0, min(rectInParent.origin.y, parent.bounds.height - rectInParent.height)),
                                width: min(rectInParent.width, parent.bounds.width),
                                height: min(rectInParent.height, parent.bounds.height)
                            )
                            viewport.applyRenderViewFrameInTouchView(clampedRect)
                        } else {
                            viewport.applyRenderViewFrameInTouchView(rectInParent)
                        }
                    }
                    return
                }

                // Now convert coordinates - the frame is in self.view's coordinate system
                let rectInParent = self.view.convert(frame, to: parent)

                // For landscape, double-check the conversion is correct
                // Sometimes the coordinate conversion can be off if views haven't updated yet
                if orientation == .landscape {
                    // Ensure the rect is within parent bounds (clamp if needed)
                    let clampedRect = CGRect(
                        x: max(0, min(rectInParent.origin.x, parent.bounds.width - rectInParent.width)),
                        y: max(0, min(rectInParent.origin.y, parent.bounds.height - rectInParent.height)),
                        width: min(rectInParent.width, parent.bounds.width),
                        height: min(rectInParent.height, parent.bounds.height)
                    )
                    DLOG("Landscape frame conversion: original=\(rectInParent), clamped=\(clampedRect), parent.bounds=\(parent.bounds), self.view.bounds=\(self.view.bounds)")
                    viewport.applyRenderViewFrameInTouchView(clampedRect)
                } else {
                    viewport.applyRenderViewFrameInTouchView(rectInParent)
                }
            }
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
            self.playTimeTracker?.updateLastPlayedTime()
        }
    }

    @objc func appDidEnterBackground(_: Notification?) {}

    /// Flush battery saves when the app is about to be terminated.
    /// Cores write SRAM/battery data during stopEmulation, so we call it here
    /// to ensure saves are not lost if the app is force-quit or killed by the OS.
    @objc func appWillTerminate(_: Notification?) {
        guard core.isOn else { return }
        ILOG("appWillTerminate: stopping emulation to flush battery saves")
        core.stopEmulation()
    }

    @objc func appWillResignActive(_: Notification?) {
        if !core.isOn {
            return
        }

        /// Safety check: ensure view controller is in a valid state before attempting auto-save
        guard isViewLoaded,
              view.window != nil,
              parent != nil || presentingViewController != nil else {
            DLOG("appWillResignActive: Skipping auto-save - view controller not in valid state")
            return
        }

        #if os(iOS)
        /// ReplayKit start/stop may transiently resign active while presenting
        /// system UI. In that window, forcing our own pause menu can leave the
        /// emulator in a wedged modal/input state after returning to foreground.
        let replayKitTransitionActive = PVRecordingManager.shared.isPreparingRecording
                                    || PVRecordingManager.shared.isRecording
        if replayKitTransitionActive {
            ILOG("appWillResignActive: Skipping pause-menu presentation — ReplayKit transition in progress")
            gameAudio.pauseAudio()
            return
        }
        #endif

        Task { [weak self] in
            guard let self = self else { return }
            if Defaults[.autoSave], self.core.supportsSaveStates {
                // Skip auto-save when ReplayKit is setting up a recording session.
                // Tapping "Record Game" causes the app to resign active while
                // RPScreenRecorder shows its system UI. Attempting a Realm
                // writeAsync at that moment can trigger an ObjC NSException from
                // beginAsyncWriteTransaction that Swift do-catch cannot intercept,
                // crashing the app. isPreparingRecording covers the window between
                // the startRecording() call and the system callback completing;
                // isRecording covers active recording sessions.
#if os(iOS)
                let recorderBusy = PVRecordingManager.shared.isPreparingRecording
                                || PVRecordingManager.shared.isRecording
                if recorderBusy {
                    ILOG("appWillResignActive: Skipping auto-save — ReplayKit recording busy (preparing or active)")
                    return
                }
#endif
                do {
                    let success = try await self.autoSaveState()
                    if !success {
                        ELOG("Auto-save failed for unknown reasons")
                    }
                } catch {
                    ELOG("Auto-save failed \(error.localizedDescription)")
                }
            }
        }
        gameAudio.pauseAudio()
        #if os(tvOS)
        /// On tvOS the PS/home button triggers Control Center, which fires resign-active
        /// while the system UI is taking over the foreground. Calling `showMenu` here
        /// races the system transition and can wedge the presentation state — leaving
        /// `isShowingMenu = true` with no visible menu on return. Skip the auto-menu on
        /// tvOS; `appDidBecomeActive` reconciles state when the app returns.
        #else
        showMenu(self)
        #endif
    }

    @objc func appDidBecomeActive(_: Notification?) {
        if !core.isOn {
            return
        }

        #if os(tvOS)
        /// Returning from Control Center (PS/home button) or any other transient
        /// system UI can desync controller state. Two things can go wrong:
        /// 1. GCController handlers may have been cleared by a brief reconnect.
        /// 2. `isShowingMenu` may be stuck `true` from `appWillResignActive`'s
        ///    `showMenu(self)` call, even though no menu VC is actually presented —
        ///    which flips the next pause-button press into `hideMenu` instead of
        ///    `showMenu`, so the menu appears "broken."
        /// Reconcile both before the user touches a controller.
        reestablishPauseHandlers()
        /// Control Center dismissal on tvOS isn't atomic with didBecomeActive:
        /// the system finishes retargeting GCController focus a few frames later.
        /// Rebinding a second time after a short delay catches the case where the
        /// first rebind landed before the system released `buttonOptions`, which
        /// manifests as the pause button mapping silently breaking after PS/home.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.reestablishPauseHandlers()
        }
        if isShowingMenu && menuPresentationViewController == nil && presentedViewController == nil {
            ILOG("appDidBecomeActive: isShowingMenu stuck true with no menu VC — resetting")
            isShowingMenu = false
        }
        #endif

        /// Match pause state to the actual menu visibility instead of always forcing
        /// pause. This prevents returning from transient ReplayKit UI in a permanently
        /// paused-looking state with no visible pause menu.
        core.setPauseEmulation(isShowingMenu)

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
        // Respect the mic-button mute state so that (re)starting audio
        // doesn't silently undo the user's mute preference.
        gameAudio.setVolume(isAudioMuted ? 0 : Defaults[.volume])
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

    /// Toggle the game audio mute state in response to the DualSense microphone button.
    /// `@MainActor` is a compile-time hint only for `@objc` selectors, so we hop
    /// to the main thread explicitly in case the notification ever arrives off-main.
    @objc func handleMicButtonToggleMute(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleMicButtonToggleMute(notification) }
            return
        }
        isAudioMuted.toggle()
        if isAudioMuted {
            gameAudio.setVolume(0)
            ILOG("DualSense mic button: audio muted")
        } else {
            gameAudio.setVolume(Defaults[.volume])
            ILOG("DualSense mic button: audio unmuted")
        }
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
