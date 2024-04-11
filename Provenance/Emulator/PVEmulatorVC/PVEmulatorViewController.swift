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
import UIKit
import ZipArchive

private weak var staticSelf: PVEmulatorViewController?

func uncaughtExceptionHandler(exception _: NSException?) {
    if let staticSelf = staticSelf, staticSelf.core.supportsSaveStates {
        staticSelf.autoSaveState { result in
            switch result {
            case .success:
                break
            case let .error(error):
                ELOG(error.localizedDescription)
            }
        }
    }
}

#if os(tvOS)
    typealias PVEmulatorViewControllerRootClass = GCEventViewController
#else
    typealias PVEmulatorViewControllerRootClass = UIViewController
#endif

final class PVEmulatorViewController: PVEmulatorViewControllerRootClass, PVAudioDelegate, PVSaveStatesViewControllerDelegate {
    let core: PVEmulatorCore
    let game: PVGame

    var batterySavesPath: URL { return PVEmulatorConfiguration.batterySavesPath(forGame: game) }
    var BIOSPath: URL { return PVEmulatorConfiguration.biosPath(forGame: game) }
    var menuButton: MenuButton?

    let use_metal: Bool = PVSettingsModel.shared.debugOptions.useMetal
    private(set) lazy var gpuViewController: PVGPUViewController = use_metal ? PVMetalViewController(emulatorCore: core) : PVGLViewController(emulatorCore: core)
    private(set) lazy var controllerViewController: (UIViewController & StartSelectDelegate)? = {
        let controller = PVCoreFactory.controllerViewController(forSystem: game.system, core: core)
        return controller
    }()

    var audioInited: Bool = false
    private(set) lazy var gameAudio: OEGameAudio = {
        audioInited = true
        return OEGameAudio(core: core)
    }()

    var fpsTimer: Timer?
    let fpsLabel: UILabel = UILabel()
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

        core.screenType = game.system.screenType.rawValue

        super.init(nibName: nil, bundle: nil)
        let app = UIApplication.shared as! PVApplication
        app.core = core
        if (app.emulator == nil) {
            app.emulator = self
        }
        if let coreClass = type(of: core) as? CoreOptional.Type {
            coreClass.className = core.coreIdentifier ?? ""
            coreClass.systemName = core.systemIdentifier ?? ""
        }
        PVEmulatorCore.status = ["isOn":true]
        PVControllerManager.shared.hasLayout=false
        if core.skipLayout {
            gpuViewController.dismiss(animated: false)
        } else if core.alwaysUseMetal {
            gpuViewController = PVMetalViewController(emulatorCore: core)
        }

        staticSelf = self

        if PVSettingsModel.shared.autoSave {
            NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }

        // Add KVO watcher for isRunning state so we can update play time
        core.addObserver(self, forKeyPath: "isRunning", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
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
            gameAudio.stop()
        }
        NSSetUncaughtExceptionHandler(nil)
        staticSelf = nil
        gpuViewController.dismiss(animated: false)
        controllerViewController?.dismiss(animated: false)
        core.touchViewController=nil
        #if os(iOS)
            PVControllerManager.shared.controllers().forEach { $0.clearPauseHandler() }
        #endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        
        let appDelegate = UIApplication.shared as! PVApplication
        appDelegate.core=nil
        appDelegate.emulator=nil
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
        core.biosPath = BIOSPath.path
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
        let alpha: CGFloat = CGFloat(PVSettingsModel.shared.controllerOpacity)
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

    private func initFPSLabel() {
        fpsLabel.textColor = UIColor.yellow
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        fpsLabel.textAlignment = .right
        fpsLabel.isOpaque = true
        fpsLabel.numberOfLines = 2
        #if os(tvOS)
            fpsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        #else
            fpsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        #endif
        gpuViewController.view.addSubview(fpsLabel)
        view.addConstraint(NSLayoutConstraint(item: fpsLabel, attribute: .top, relatedBy: .equal, toItem: gpuViewController.view, attribute: .top, multiplier: 1.0, constant: 30))
        view.addConstraint(NSLayoutConstraint(item: fpsLabel, attribute: .right, relatedBy: .equal, toItem: gpuViewController.view, attribute: .right, multiplier: 1.0, constant: -40))

        fpsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] (_: Timer) -> Void in
            guard let `self` = self else { return }

            let coreSpeed = self.core.renderFPS/self.core.frameInterval * 100
            let drawTime =  self.gpuViewController.timeSinceLastDraw * 1000
            let fps = 1000 / drawTime
            let mem = self.memoryUsage()

            let cpu = self.cpuUsage()
            let cpuFormatted = String.init(format: "%03.01f", cpu)
//            let cpuAttributed = NSAttributedString(string: cpuFormatted,
//                                                   attributes: red)
//
            let memFormatted: String = NSString.localizedStringWithFormat("%i", (mem.used/1024/1024)) as String
            let memTotalFormatted: String = NSString.localizedStringWithFormat("%i", (mem.total/1024/1024)) as
            String

//            let memUsedAttributed = NSAttributedString(string: memFormatted,
//                                                       attributes: green)
//            let memTotalAttributed = NSAttributedString(string: memTotalFormatted,
//                                                        attributes: green)
//
//            let label = NSMutableAttributedString()
//            
//            let top = NSAttributedString(format: "Core speed %03.02f%% - Draw time %02.02f%ms - FPS %03.02f\n", coreSpeed, drawTime, fps);
//            
//            label.append(top)

            self.fpsLabel.text = String(format: "Core speed %03.02f%% - Draw time %02.02f%ms - FPS %03.02f\nCPU %@%% Mem %@/%@(MB)", coreSpeed, drawTime, fps, cpuFormatted, memFormatted, memTotalFormatted)
        })
    }

    typealias MemoryUsage = (used: UInt64, total: UInt64)
    func memoryUsage() -> MemoryUsage {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }

        let total = ProcessInfo.processInfo.physicalMemory
        return (used, total)
    }

    func cpuUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return totalUsageOfCPU
    }

    // TODO: This method is way too big, break it up
    override func viewDidLoad() {
        super.viewDidLoad()
        title = game.title
        view.backgroundColor = UIColor.black
        
        let app = UIApplication.shared as! PVApplication
        app.core = core
        if (app.emulator == nil) {
            app.emulator = self
        }

        initNotificationObservers()
        initCore()

        // Load now. Moved here becauase Mednafen needed to know what kind of game it's working with in order
        // to provide the correct data for creating views.
        let m3uFile: URL? = PVEmulatorConfiguration.m3uFile(forGame: game)
        var romPathMaybe: URL? = UserDefaults.standard.url(forKey: game.romPath) ?? m3uFile ?? game.file.url

        // Extract Zip before loading the ROM
        if core.extractArchive, let filePath = romPathMaybe {
            if (filePath.pathExtension.caseInsensitiveCompare("zip") == .orderedSame) {
                var unzippedFiles = [URL]()
                SSZipArchive.unzipFile(atPath: filePath.path, toDestination: self.batterySavesPath.path, overwrite: true, password: nil, progressHandler: { (entry: String, _: unz_file_info, entryNumber: Int, total: Int) in
                    if !entry.isEmpty {
                        let url = self.batterySavesPath.appendingPathComponent(entry)
                        unzippedFiles.append(url)
                    }
                }, completionHandler: { [weak self] (_: String?, succeeded: Bool, error: Error?) in
                    guard let self = self else { return }
                    if succeeded {
                        var hasCue:Bool=false;
                        var cueFile:URL?
                        for file in unzippedFiles {
                            if self.game.system.supportedExtensions.contains( file.pathExtension.lowercased() ) {
                                romPathMaybe = file;
                                if (file.pathExtension.lowercased() == "cue") {
                                    cueFile = file;
                                    hasCue = true;
                                }
                            }
                        }
                        if hasCue, let file = cueFile {
                            romPathMaybe = file;
                        }
                    }
                })
            }
        }
        guard let romPath = romPathMaybe else {
            presentingViewController?.presentError("Game has a nil rom path.", source: self.view)
            return
        }

        //		guard FileManager.default.fileExists(atPath: romPath.absoluteString) else {
        //			ELOG("File doesn't exist at path \(romPath.absoluteString)")
        //			presentingViewController?.presentError("File doesn't exist at path \(romPath.absoluteString)")
        //			return
        //		}
        print("Loading ROM %@", romPath.path)
        do {
            try core.loadFile(atPath: romPath.path)
        } catch {
            let alert = UIAlertController(title: error.localizedDescription, message: (error as NSError).localizedRecoverySuggestion, preferredStyle: .alert)
            alert.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
            alert.popoverPresentationController?.sourceView = self.navigationItem.titleView ?? self.view
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            }))
            let code = (error as NSError).code
            if code == PVEmulatorCoreErrorCode.missingM3U.rawValue {
                alert.addAction(UIAlertAction(title: "View Wiki", style: .cancel, handler: { (_: UIAlertAction) -> Void in
                    if let url = URL(string: "https://bitly.com/provm3u") {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
                self?.present(alert, animated: true) { () -> Void in }
            })

            return
        }

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
            if let aView = gpuViewController.view {
                view.addSubview(aView)
            }
            gpuViewController.didMove(toParent: self)
        } 
        #if os(iOS) && !targetEnvironment(macCatalyst) && !os(macOS)
            addControllerOverlay()
            initMenuButton()
        #endif

        if PVSettingsModel.shared.showFPSCount && !core.skipLayout {
            initFPSLabel()
        }

        hideOrShowMenuButton()

        convertOldSaveStatesToNewIfNeeded()

        gameAudio.volume = PVSettingsModel.shared.volume
        gameAudio.outputDeviceID = 0
        gameAudio.start()

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
        PVControllerManager.shared.controllers().forEach {
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

        if PVSettingsModel.shared.timedAutoSaves {
            createAutosaveTimer()
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyAutosaveTimer()
    }

    var autosaveTimer: Timer?

    var gameStartTime: Date?
    @objc
    public func updatePlayedDuration() {
        defer {
            // Clear any temp pointer to start time
            self.gameStartTime = nil
        }
        guard let gameStartTime = gameStartTime else {
            return
        }

        // Calcuate what the new total spent time should be
        let duration = gameStartTime.timeIntervalSinceNow * -1
        let totalTimeSpent = game.timeSpentInGame + Int(duration)
        ILOG("Played for duration \(duration). New total play time: \(totalTimeSpent) for \(game.title)")
        // Write that to the database
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.timeSpentInGame = totalTimeSpent
            }
        } catch {
            NSLog("\(error.localizedDescription)")
        }
    }

    @objc public func updateLastPlayedTime() {
        ILOG("Updating last played")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.lastPlayed = Date()
            }
        } catch {
            NSLog("\(error.localizedDescription)")
        }
    }

    #if os(iOS) && !targetEnvironment(simulator)
        // Check Controller Manager if it has a Controller connected and thus if Home Indicator should hide…
        override var prefersHomeIndicatorAutoHidden: Bool {
            let shouldHideHomeIndicator: Bool = PVControllerManager.shared.hasControllers
            return shouldHideHomeIndicator
        }
    #endif

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if os(iOS)
            layoutMenuButton()
        #endif
    }

    #if os(iOS)
        func layoutMenuButton() {
            if let menuButton = self.menuButton {
                let height: CGFloat = 42
                let width: CGFloat = 42
                menuButton.imageView?.contentMode = .center
                let frame = CGRect(x: view.safeAreaInsets.left + 10, y: view.safeAreaInsets.top + 5, width: width, height: height)
                menuButton.frame = frame
            }
        }
    #endif
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
        override var prefersStatusBarHidden: Bool {
            return true
        }

        override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
            return [.left, .right, .bottom]
        }

        override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return .all
        }
    #endif

    @objc func appWillEnterForeground(_: Notification?) {
        if (!core.isOn) {
            return;
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateLastPlayedTime()
        }
    }

    @objc func appDidEnterBackground(_: Notification?) {}

    @objc func appWillResignActive(_: Notification?) {
        if (!core.isOn) {
            return;
        }
        if PVSettingsModel.shared.autoSave, core.supportsSaveStates {
            autoSaveState { result in
                switch result {
                case .success:
                    break
                case let .error(error):
                    ELOG("Auto-save failed \(error.localizedDescription)")
                }
            }
        }
        gameAudio.pause()
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
        gameAudio.start()
    }

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

    @objc func hideMoreInfo() {
        dismiss(animated: true, completion: { () -> Void in
            self.hideMenu()
        })
    }

    func hideMenu() {
        if (!core.isOn) {
            return;
        }
        enableControllerInput(false)
        isShowingMenu = false
        if (presentedViewController is UIAlertController) && !presentedViewController!.isBeingDismissed {
            dismiss(animated: true) { () -> Void in }
        }
        if (presentedViewController is TVAlertController) && !presentedViewController!.isBeingDismissed {
            dismiss(animated: true) { () -> Void in }
        }
        #if os(iOS)
        // if there is a DONE button, press it
        if let nav = presentedViewController as? UINavigationController, !presentedViewController!.isBeingDismissed {
            let top = nav.topViewController?.navigationItem
            for bbi in (top?.leftBarButtonItems ?? []) + (top?.rightBarButtonItems ?? []) {
                if bbi.style == .done || bbi.action == NSSelectorFromString("done:") {
                    _ = bbi.target?.perform(bbi.action, with:bbi)
                }
            }
        }
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.updateLastPlayedTime()
        }
        core.setPauseEmulation(false)
    }

    @objc func updateFPSLabel() {
        #if DEBUG
            print("FPS: \(gpuViewController.framesPerSecond)")
        #endif
        fpsLabel.text = String(format: "%2.02f", core.emulationFPS)
    }

    func captureScreenshot() -> UIImage? {
        fpsLabel.alpha = 0.0
        if (core.skipLayout && core.touchViewController != nil) {
            let width: CGFloat? = UIScreen.main.bounds.size.width
            let height: CGFloat? = UIScreen.main.bounds.size.height
            let size = CGSize(width: width ?? 0.0, height: height ?? 0.0)
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            let rec = CGRect(x: 0, y: 0, width: width ?? 0.0, height: height ?? 0.0)
            core.touchViewController?.view.drawHierarchy(in: rec, afterScreenUpdates: true)
        } else {
            let width: CGFloat? = gpuViewController.view.frame.size.width > 0 ? gpuViewController.view.frame.size.width : UIScreen.main.bounds.width
            let height: CGFloat? = gpuViewController.view.frame.size.height > 0 ? gpuViewController.view.frame.size.height : UIScreen.main.bounds.height
            let size = CGSize(width: width ?? 0.0, height: height ?? 0.0)
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            let rec = CGRect(x: 0, y: 0, width: width ?? 0.0, height: height ?? 0.0)
            gpuViewController.view.drawHierarchy(in: rec, afterScreenUpdates: true)
        }
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        fpsLabel.alpha = 1.0
        return image
    }

    #if os(iOS)
        @objc func takeScreenshot() {
            if let screenshot = captureScreenshot() {
                DispatchQueue.global(qos: .utility).async(execute: { () -> Void in
                    UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
                })

                if let pngData = screenshot.pngData() {
                    let dateString = PVEmulatorConfiguration.string(fromDate: Date())

                    let fileName = self.game.title + " - " + dateString + ".png"
                    let imageURL = PVEmulatorConfiguration.screenshotsPath(forGame: self.game).appendingPathComponent(fileName, isDirectory: false)
                    do {
                        try pngData.write(to: imageURL)
                        try RomDatabase.sharedInstance.writeTransaction {
                            self.game.realm?.refresh()
                            let newFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
                            self.game.screenShots.append(newFile)
                        }
                    } catch {
                        NSLog("Unable to write image to disk, error: \(error.localizedDescription)")
                    }
                }
            }
            core.setPauseEmulation(false)
            isShowingMenu = false
        }

    #endif
    @objc func showSpeedMenu(_ sender:AnyObject?) {
        let actionSheet = UIAlertController(title: "Game Speed", message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
        actionSheet.popoverPresentationController?.sourceView = self.navigationItem.titleView ?? self.view
        if let menuButton = menuButton {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton.bounds
        }
        let speeds = ["Slow Motion", "Normal", "Fast Forward"]
        speeds.enumerated().forEach { idx, title in
            let action = UIAlertAction(title: title, style: .default, handler: { (_: UIAlertAction) -> Void in
                self.enableControllerInput(false)
                self.isShowingMenu = false
                self.core.gameSpeed = GameSpeed(rawValue: idx) ?? .normal
                self.core.setPauseEmulation(false)
            })
            actionSheet.addAction(action)
            if idx == self.core.gameSpeed.rawValue {
                actionSheet.preferredAction = action
            }
        }
        let action = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { (_: UIAlertAction) -> Void in
            self.enableControllerInput(false)
            self.isShowingMenu = false
            self.core.setPauseEmulation(false)
        })
        actionSheet.addAction(action)
        present(actionSheet, animated: true, completion: { () -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
    }

    func showMoreInfo() {
        guard let moreInfoViewController = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "gameMoreInfoVC") as? PVGameMoreInfoViewController else { return }
        moreInfoViewController.game = self.game
        moreInfoViewController.showsPlayButton = false
        let newNav = UINavigationController(rootViewController: moreInfoViewController)

        #if os(iOS)
            moreInfoViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideMoreInfo))
        #else
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.hideMoreInfo))
            tap.allowedPressTypes = [.menu]
            moreInfoViewController.view.addGestureRecognizer(tap)
        #endif

        // disable iOS 13 swipe to dismiss...
        newNav.isModalInPresentation = true

        self.present(newNav, animated: true) { () -> Void in }
        // hideMoreInfo will/should do this!
        // self.isShowingMenu = false
        // self.enableControllerInput(false)
    }

    typealias QuitCompletion = () -> Void

    func quit(optionallySave canSave: Bool = true, completion: QuitCompletion? = nil) {
        NotificationCenter.default.removeObserver(self)
        NSSetUncaughtExceptionHandler(nil)
		enableControllerInput(false)
        if canSave, PVSettingsModel.shared.autoSave, core.supportsSaveStates {
            autoSaveState { result in
                switch result {
                case .success:
                    break
                case let .error(error):
                    ELOG("Auto-save failed \(error.localizedDescription)")
                }
            }
        }
        core.stopEmulation()
        if audioInited {
            gameAudio.stop()
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
        PVControllerManager.shared.controllers().forEach {
            $0.clearPauseHandler()
        }
        Theme.currentTheme = Theme.currentTheme
        #endif
        updatePlayedDuration()
        destroyAutosaveTimer()
        if let menuGestureRecognizer = menuGestureRecognizer {
            view.removeGestureRecognizer(menuGestureRecognizer)
        }
        let appDelegate = UIApplication.shared as! PVApplication
        appDelegate.core=nil
        appDelegate.emulator=nil
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

// Extension to make gesture.allowedPressTypes and gesture.allowedTouchTypes sane.
extension NSNumber {
    static var menu: NSNumber {
        return NSNumber(pressType: .menu)
    }

    static var playPause: NSNumber {
        return NSNumber(pressType: .playPause)
    }

    static var select: NSNumber {
        return NSNumber(pressType: .select)
    }

    static var upArrow: NSNumber {
        return NSNumber(pressType: .upArrow)
    }

    static var downArrow: NSNumber {
        return NSNumber(pressType: .downArrow)
    }

    static var leftArrow: NSNumber {
        return NSNumber(pressType: .leftArrow)
    }

    static var rightArrow: NSNumber {
        return NSNumber(pressType: .rightArrow)
    }

    // MARK: - Private

    private convenience init(pressType: UIPress.PressType) {
        self.init(integerLiteral: pressType.rawValue)
    }
}

extension NSNumber {
    static var direct: NSNumber {
        return NSNumber(touchType: .direct)
    }

    static var indirect: NSNumber {
        return NSNumber(touchType: .indirect)
    }

    // MARK: - Private

    private convenience init(touchType: UITouch.TouchType) {
        self.init(integerLiteral: touchType.rawValue)
    }
}
