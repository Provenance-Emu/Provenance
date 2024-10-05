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
import ZipArchive
import PVEmulatorCore
import PVCoreBridge
import PVAudio
import PVCoreAudio
import PVThemes
import PVSettings
import PVRealm
import PVLogging

private weak var staticSelf: PVEmulatorViewController?

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
final class PVEmulatorViewController: PVEmulatorViewControllerRootClass, PVAudioDelegate, PVSaveStatesViewControllerDelegate {
    // TODO: Use protocols instead
#warning("TODO: Use protocols instead")
    //    let core: any PVEmulatorCoreT
    let core: PVEmulatorCore
    
    let game: PVGame
    
    var batterySavesPath: URL { get {return PVEmulatorConfiguration.batterySavesPath(forGame: game) }}
    var BIOSPath: URL { get { return PVEmulatorConfiguration.biosPath(forGame: game) } }
    var menuButton: MenuButton?
    
    var use_metal: Bool { Defaults[.useMetal] }
    private(set) lazy var gpuViewController: PVGPUViewController = {
        return use_metal ? PVMetalViewController(withEmulatorCore: core) : PVGLViewController(withEmulatorCore: core)
    }()
    private(set) lazy var controllerViewController: (UIViewController & StartSelectDelegate)? = {
        let controller = PVCoreFactory.controllerViewController(forSystem: game.system, core: core)
        return controller
    }()
    
    var audioInited: Bool = false
    private(set) lazy var gameAudio: any AudioEngineProtocol = {
        audioInited = true
        
        if Defaults[.useLegacyAudioEngine] {
            let engine = OEGameAudio()
            return engine
        } else {
            let engine = GameAudioEngine2()
            return engine
        }
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
    
    var isShowingMenu: Bool = false {
        willSet {
            if newValue == true {
                if (!core.skipLayout) {
                    gpuViewController.isPaused = true
                }
            }
        }
        didSet {
            if isShowingMenu == false {
                if (!core.skipLayout) {
                    gpuViewController.isPaused = false
                }
            }
        }
    }
    
    let minimumPlayTimeToMakeAutosave: Double = 60
    
    required init(game: PVGame, core: PVEmulatorCore) {
        self.core = core
        self.game = game
        
        super.init(nibName: nil, bundle: nil)
        let app = UIApplication.shared as! PVApplication
        app.core = core
        if (app.emulator == nil) {
            app.emulator = self
        }
        if let coreClass = type(of: core) as? OptionalCore.Type {
            coreClass.coreClassName = core.coreIdentifier ?? ""
            coreClass.systemName = core.systemIdentifier ?? ""
        }
        PVEmulatorCore.status = ["isOn":true]
        PVControllerManager.shared.hasLayout=false
        if core.skipLayout {
            gpuViewController.dismiss(animated: false)
        } else if core.alwaysUseMetal {
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
#if os(tvOS)
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
        core.stopEmulation()
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
        
        // This has a race condition
//        let appDelegate = UIApplication.shared as! PVApplication
//        appDelegate.core = nil
//        appDelegate.emulator = nil
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
    
    private func initCore() {
        core.audioDelegate = self
        core.saveStatesPath = saveStatePath.path
        core.batterySavesPath = batterySavesPath.path
        core.BIOSPath = BIOSPath.path
        core.controller1 = PVControllerManager.shared.player1
        core.controller2 = PVControllerManager.shared.player2
        core.controller3 = PVControllerManager.shared.player3
        core.controller4 = PVControllerManager.shared.player4
        
        let md5Hash: String = game.md5Hash
        core.romMD5 = md5Hash
        core.romSerial = game.romSerial
        
        core.initialize()
    }
    
    private func addControllerOverlay() {
        if let aController = controllerViewController {
            addChild(aController)
        }
        if let aView = controllerViewController?.view {
            view.addSubview(aView)
            core.touchViewController = controllerViewController
        }
        controllerViewController?.didMove(toParent: self)
    }
    
    private func initMenuButton() {
        let alpha: CGFloat = CGFloat(Defaults[.controllerOpacity])
        menuButton = MenuButton(type: .custom)
        menuButton?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        menuButton?.setImage(UIImage(named: "button-menu"), for: .normal)
        menuButton?.setImage(UIImage(named: "button-menu-pressed"), for: .highlighted)
        // Commenting out title label for now (menu has changed to graphic only)
        // [self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
        // menuButton?.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        // menuButton?.setTitleColor(UIColor.white, for: .normal)
        menuButton?.layer.shadowOffset = CGSize(width: 0, height: 1)
        menuButton?.layer.shadowRadius = 3.0
        menuButton?.layer.shadowColor = UIColor.black.cgColor
        menuButton?.layer.shadowOpacity = 0.75
        menuButton?.tintColor = UIColor.white
        menuButton?.alpha = alpha
        menuButton?.addTarget(self, action: #selector(PVEmulatorViewController.showMenu(_:)), for: .touchUpInside)
        view.addSubview(menuButton!)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = game.title
        view.backgroundColor = UIColor.black
        
        let app = UIApplication.shared as! PVApplication
        app.core = core
        if (app.emulator == nil) {
            app.emulator = self
        }
        
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
    
    private func createEmulator() throws {
        initCore()
        
        // Load now. Moved here becauase Mednafen needed to know what kind of game it's working with in order
        // to provide the correct data for creating views.
        let m3uFile: URL? = PVEmulatorConfiguration.m3uFile(forGame: game)
        var romPathMaybe: URL? = UserDefaults.standard.url(forKey: game.romPath) ?? m3uFile
        if romPathMaybe == nil {
            romPathMaybe = game.file.url
        }
        
#warning("should throw if nil?")
        guard let romPath = romPathMaybe else {
            throw CreateEmulatorError.gameHasNilRomPath
        }
        
        // Extract Zip before loading the ROM
        romPathMaybe = handleArchives(atPath: romPathMaybe)
        
        guard let romPath = romPathMaybe else {
            throw CreateEmulatorError.gameHasNilRomPath
        }
        
        let path = romPath.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else {
            ELOG("File doesn't exist at path \(path)")
            
            // Copy path to Pasteboard
            UIPasteboard.general.string = path
            
            throw CreateEmulatorError.fileDoesNotExist(path: path)
        }
        
        ILOG("Loading ROM: \(path)")
        
        if let core = core as? any ObjCBridgedCore, let bridge = core.bridge as? EmulatorCoreIOInterface {
            try bridge.loadFile(atPath: path)
        } else {
            try core.loadFile(atPath: path)
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
        } else if (!core.skipLayout) {
            addChild(gpuViewController)
            // Note: This also initilaizes the view
            // using viewIfLoaded will crash.
            // Should probably imporve this?
            if let aView = gpuViewController.view {
                view.addSubview(aView)
            }
            gpuViewController.didMove(toParent: self)
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
        //        gameAudio.volume = Defaults[.volume]
        //        gameAudio.outputDeviceID = 0
        //        gameAudio.startAudio()
        
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
    }
    
    public override func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)
        // Notifies UIKit that your view controller updated its preference regarding the visual indicator
        
#if os(iOS)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
#endif
        
        if Defaults[.timedAutoSaves] {
            createAutosaveTimer()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyAutosaveTimer()
    }
    
    var autosaveTimer: Timer?
    
    var gameStartTime: Date?
    
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
    
    func documentsPath() -> String? {
#if os(tvOS)
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
#else
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
#endif
        let documentsDirectoryPath: String = paths[0]
        return documentsDirectoryPath
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
    
    typealias QuitCompletion = () -> Void
    
    func quit(optionallySave canSave: Bool = true, completion: QuitCompletion? = nil) async {
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
        core.stopEmulation()
        if audioInited {
            gameAudio.stopAudio()
        }
        gpuViewController.dismiss(animated: false)
        if let view = controllerViewController?.view {
            for subview in view.subviews {
                subview.removeFromSuperview()
            }
        }
        controllerViewController?.dismiss(animated: false)
        core.touchViewController=nil
#if os(iOS)
        PVControllerManager.shared.controllers.forEach {
            $0.clearPauseHandler()
        }
        
        // EEEEEWWWW WTF X - X?
        // TODO: You that lazy or retarded bro? @JoeMatt 7/25/24
        ThemeManager.shared.setCurrentTheme(ThemeManager.shared.currentTheme)
        
#endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        let appDelegate = UIApplication.shared as! PVApplication
        appDelegate.core = nil
        appDelegate.emulator = nil
        PVEmulatorCore.status = [:]
        fpsTimer?.invalidate()
        fpsTimer = nil
        dismiss(animated: true, completion: completion)
        self.view?.removeFromSuperview()
        self.removeFromParent()
        staticSelf = nil
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
