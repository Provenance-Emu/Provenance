//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVEmulatorViewController.swift
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import PVSupport
import QuartzCore
import UIKit

private weak var staticSelf: PVEmulatorViewController?

func uncaughtExceptionHandler(exception: NSException?) {
	do {
		try staticSelf?.autoSaveState()
	} catch {
		ELOG("\(error.localizedDescription)")
	}
}

public enum SaveStateError: Error {
	case failedToSave(isAutosave: Bool)
}

#if os(tvOS)
typealias PVEmulatorViewControllerRootClass = GCEventViewController
#else
typealias PVEmulatorViewControllerRootClass = UIViewController
#endif

extension UIViewController {
	func presentMessage(_ message : String, title: String, completion: (() -> Swift.Void)? = nil) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

		let presentingVC = self.presentedViewController ?? self

		if presentingVC.isBeingDismissed || presentingVC.isBeingPresented {
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
				presentingVC.present(alert, animated: true, completion: nil)
			}
		} else {
			presentingVC.present(alert, animated: true, completion: nil)
		}
	}

	func presentError(_ message : String, completion: (() -> Swift.Void)? = nil) {
		ELOG("\(message)")
		presentMessage(message, title: "Error", completion: completion)
	}

	func presentWarning(_ message : String, completion: (() -> Swift.Void)? = nil) {
		WLOG("\(message)")
		presentMessage(message, title: "Warning", completion: completion)
	}
}

class PVEmulatorViewController: PVEmulatorViewControllerRootClass, PVAudioDelegate, PVSaveStatesViewControllerDelegate {

    var core: PVEmulatorCore
    var game: PVGame

    var batterySavesPath = ""
    var saveStatePath = ""
    var BIOSPath = ""
    var menuButton: UIButton?

    var glViewController: PVGLViewController!
    var gameAudio: OEGameAudio!
    let controllerViewController: (UIViewController & StartSelectDelegate)?
    var fpsTimer: Timer?
    var fpsLabel: UILabel?
    var secondaryScreen: UIScreen?
    var secondaryWindow: UIWindow?
    var menuGestureRecognizer: UITapGestureRecognizer?

    weak var menuActionSheet: UIAlertController?
    var isShowingMenu: Bool = false

    required init(game: PVGame, core: PVEmulatorCore) {
        self.core = core
        self.game = game

        controllerViewController = PVCoreFactory.controllerViewController(forSystem: game.system, core: core)

        super.init(nibName: nil, bundle: nil)

		staticSelf = self

        if PVSettingsModel.sharedInstance().autoSave {
            NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        core.stopEmulation()
        //Leave emulation loop first
        gameAudio?.stop()
        NSSetUncaughtExceptionHandler(nil)
        NotificationCenter.default.removeObserver(self)
        staticSelf = nil
        controllerViewController?.willMove(toParentViewController: nil)
        controllerViewController?.view?.removeFromSuperview()
        controllerViewController?.removeFromParentViewController()
        glViewController?.willMove(toParentViewController: nil)
        glViewController?.view?.removeFromSuperview()
        glViewController?.removeFromParentViewController()
#if os(iOS)
    GCController.controllers().forEach { $0.controllerPausedHandler = nil }
#endif
        updatePlayedDuration()
    }

	private func initNotifcationObservers() {
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillEnterForeground(_:)), name: .UIApplicationWillEnterForeground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appWillResignActive(_:)), name: .UIApplicationWillResignActive, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.appDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.screenDidConnect(_:)), name: .UIScreenDidConnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.screenDidDisconnect(_:)), name: .UIScreenDidDisconnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVEmulatorViewController.handleControllerManagerControllerReassigned(_:)), name: .PVControllerManagerControllerReassigned, object: nil)
	}

	private func initCore() {
		core.audioDelegate = self
		core.saveStatesPath = self.saveStatePath
		core.batterySavesPath = batterySavesPath
		core.biosPath = BIOSPath
		core.controller1 = PVControllerManager.shared.player1
		core.controller2 = PVControllerManager.shared.player2
		core.controller3 = PVControllerManager.shared.player3
		core.controller4 = PVControllerManager.shared.player4

		let md5Hash: String = game.md5Hash
		core.romMD5 = md5Hash
		core.romSerial = game.romSerial
	}

	private func initMenuButton() {
		//        controllerViewController = PVCoreFactory.controllerViewController(forSystem: game.system, core: core)
		if let aController = controllerViewController {
			addChildViewController(aController)
		}
		if let aView = controllerViewController?.view {
			view.addSubview(aView)
		}
		controllerViewController?.didMove(toParentViewController: self)

		let alpha: CGFloat = PVSettingsModel.sharedInstance().controllerOpacity
		menuButton = UIButton(type: .custom)
		menuButton?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
		menuButton?.setImage(UIImage(named: "button-menu"), for: .normal)
		menuButton?.setImage(UIImage(named: "button-menu-pressed"), for: .highlighted)
		// Commenting out title label for now (menu has changed to graphic only)
		//[self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
		//menuButton?.titleLabel?.font = UIFont.systemFont(ofSize: 12)
		//menuButton?.setTitleColor(UIColor.white, for: .normal)
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
		fpsLabel = UILabel()
		fpsLabel?.textColor = UIColor.yellow
		fpsLabel?.text = "\(glViewController.framesPerSecond)"
		fpsLabel?.translatesAutoresizingMaskIntoConstraints = false
		fpsLabel?.textAlignment = .right
		#if os(tvOS)
		fpsLabel?.font = UIFont.systemFont(ofSize: 100, weight: .bold)
		#else
		if #available(iOS 8.2, *) {
			fpsLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
		}
		#endif
		if let aLabel = fpsLabel {
			glViewController?.view.addSubview(aLabel)
		}
		if let aLabel = fpsLabel {
			view.addConstraint(NSLayoutConstraint(item: aLabel, attribute: .top, relatedBy: .equal, toItem: glViewController?.view, attribute: .top, multiplier: 1.0, constant: 30))
		}
		if let aLabel = fpsLabel {
			view.addConstraint(NSLayoutConstraint(item: aLabel, attribute: .right, relatedBy: .equal, toItem: glViewController?.view, attribute: .right, multiplier: 1.0, constant: -40))
		}

		if #available(iOS 10.0, tvOS 10.0, *) {
			// Block-based NSTimer method is only available on iOS 10 and later
			fpsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: {(_ timer: Timer) -> Void in
				if self.core.renderFPS == self.core.emulationFPS {
					self.fpsLabel?.text = String(format: "%2.02f", self.core.renderFPS)
				} else {
					self.fpsLabel?.text = String(format: "%2.02f (%2.02f)", self.core.renderFPS, self.core.emulationFPS)
				}
			})
		} else {

			// Use traditional scheduledTimerWithTimeInterval method on older version of iOS
			fpsTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateFPSLabel), userInfo: nil, repeats: true)
			fpsTimer?.fire()
		}
	}

	// TODO: This method is way too big, break it up
    override func viewDidLoad() {
        super.viewDidLoad()
        title = game.title
        view.backgroundColor = UIColor.black
        
		initNotifcationObservers()
		initCore()

		var romPath: URL? = game.file.url

        glViewController = PVGLViewController(emulatorCore: core)
            // Load now. Moved here becauase Mednafen needed to know what kind of game it's working with in order
            // to provide the correct data for creating views.
        let m3uFile: URL? = PVEmulatorConfiguration.m3uFile(forGame: game)
        if m3uFile != nil {
            romPath = m3uFile
        }

        do {
            try core.loadFile(atPath: romPath?.path)
        } catch {
            let alert = UIAlertController(title: error.localizedDescription, message: (error as NSError).localizedRecoverySuggestion, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
				self.dismiss(animated: true, completion: nil)
			}))
            let code = (error as NSError).code
            if code == PVEmulatorCoreErrorCode.missingM3U.rawValue {
                alert.addAction(UIAlertAction(title: "View Wiki", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
                    if let aString = URL(string: "https://bitly.com/provm3u") {
                        UIApplication.shared.openURL(aString)
                    }
                }))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
                self?.present(alert, animated: true) {() -> Void in }
            })

            return
        }

        if UIScreen.screens.count > 1 {
            secondaryScreen = UIScreen.screens[1]
            if let aBounds = secondaryScreen?.bounds {
                secondaryWindow = UIWindow(frame: aBounds)
            }
            if let aScreen = secondaryScreen {
                secondaryWindow?.screen = aScreen
            }
            secondaryWindow?.rootViewController = glViewController
            glViewController?.view?.frame = secondaryWindow?.bounds ?? .zero
            if let aView = glViewController?.view {
                secondaryWindow?.addSubview(aView)
            }
            secondaryWindow?.isHidden = false
        } else {
            if let aController = glViewController {
                addChildViewController(aController)
            }
            if let aView = glViewController?.view {
                view.addSubview(aView)
            }
            glViewController?.didMove(toParentViewController: self)
        }
		#if os(iOS)
		initMenuButton()
		#endif

        if PVSettingsModel.sharedInstance().showFPSCount {
			initFPSLabel()
        }

#if !targetEnvironment(simulator)
        if GCController.controllers().count != 0 {
            menuButton?.isHidden = true
        }
#endif

		convertOldSaveStatesToNewIfNeeded()

        core.startEmulation()
		
        gameAudio = OEGameAudio(core: core)
        gameAudio?.volume = PVSettingsModel.sharedInstance().volume
        gameAudio?.outputDeviceID = 0
        gameAudio?.start()


        // stupid bug in tvOS 9.2
        // the controller paused handler (if implemented) seems to cause a 'back' navigation action
        // as well as calling the pause handler itself. Which breaks the menu functionality.
        // But of course, this isn't the case on iOS 9.3. YAY FRAGMENTATION. ¬_¬
        // Conditionally handle the pause menu differently dependning on tvOS or iOS. FFS.
#if os(tvOS)
        // Adding a tap gesture recognizer for the menu type will override the default 'back' functionality of tvOS
        if menuGestureRecognizer == nil {
            menuGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PVEmulatorViewController.controllerPauseButtonPressed(_:)))
            menuGestureRecognizer?.allowedPressTypes = [.menu]
        }
        if let aRecognizer = menuGestureRecognizer {
            view.addGestureRecognizer(aRecognizer)
        }
#else
        GCController.controllers().forEach { [unowned self] in
            $0.controllerPausedHandler = { controller in
                self.controllerPauseButtonPressed(controller)
            }
        }
#endif
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        //Notifies UIKit that your view controller updated its preference regarding the visual indicator

        #if os(iOS)
        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
        #endif

        #if os(iOS)
        //Ignore Smart Invert
        self.view.ignoresInvertColors = true
        #endif
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc
    public func updatePlayedDuration() {
        guard let startTime = game.lastPlayed else {
            return
        }

        let duration = startTime.timeIntervalSinceNow * -1
        let totalTimeSpent = game.timeSpentInGame + Int(duration)

        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.timeSpentInGame = totalTimeSpent
                game.lastPlayed = Date()
            }
        } catch {
            presentError("\(error.localizedDescription)")
        }
    }

    @objc public func updateLastPlayedTime() {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.lastPlayed = Date()
            }
        } catch {
            presentError("\(error.localizedDescription)")
        }
    }

#if os(iOS) && !(arch(i386) || arch(x86_64))
    //Check Controller Manager if it has a Controller connected and thus if Home Indicator should hide…
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        let shouldHideHomeIndicator: Bool = PVControllerManager.shared.hasControllers
        return shouldHideHomeIndicator
    }

#endif
    
#if os(iOS)
    var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, tvOS 11.0, *) {
            return view.safeAreaInsets
        } else {
            return UIEdgeInsets.zero
        }
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
            let frame = CGRect(x: safeAreaInsets.left + 10, y: safeAreaInsets.top + 5, width: width, height: height)
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

    #if os(iOS)
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func preferredScreenEdgesDeferringSystemGestures() -> UIRectEdge {
        return .bottom
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    #endif

    @objc func appWillEnterForeground(_ note: Notification?) {
        updatePlayedDuration()
    }

    @objc func appDidEnterBackground(_ note: Notification?) {
        updatePlayedDuration()
    }

    @objc func appWillResignActive(_ note: Notification?) {
		if PVSettingsModel.sharedInstance().autoSave {
			do {
				try autoSaveState()
			} catch {
				ELOG("Auto-save failed \(error.localizedDescription)")
			}
		}
        gameAudio?.pause()
        showMenu(self)
    }

    @objc func appDidBecomeActive(_ note: Notification?) {
        if !isShowingMenu {
            core.setPauseEmulation(false)
        }
        core.setPauseEmulation(true)
        gameAudio?.start()
    }

    func enableContorllerInput(_ enabled: Bool) {
#if os(tvOS)
        controllerUserInteractionEnabled = enabled
#else
        // Can enable when we change to iOS 10 base
        // and change super class to GCEventViewController
        //    if (@available(iOS 10, *)) {
        //        self.controllerUserInteractionEnabled = enabled;
        //    }
#endif
    }

    @objc func showMenu(_ sender: Any?) {
        enableContorllerInput(true)
        core.setPauseEmulation(true)
        isShowingMenu = true
        let actionsheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if traitCollection.userInterfaceIdiom == .pad {
            actionsheet.popoverPresentationController?.sourceView = menuButton
            actionsheet.popoverPresentationController?.sourceRect = menuButton!.bounds
        }
        menuActionSheet = actionsheet
        if PVControllerManager.shared.iCadeController != nil {
            actionsheet.addAction(UIAlertAction(title: "Disconnect iCade", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                NotificationCenter.default.post(name: .GCControllerDidDisconnect, object: PVControllerManager.shared.iCadeController)
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }))
        }
        let controllerManager = PVControllerManager.shared
        let wantsStartSelectInMenu: Bool = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(game.system.identifier)
        var hideP1MenuActions = false
        if let player1 = controllerManager.player1 {
#if os(iOS)
            if PVSettingsModel.shared.startSelectAlwaysOn {
                hideP1MenuActions = true
            }
#endif
            if (player1.extendedGamepad != nil || wantsStartSelectInMenu) && !hideP1MenuActions {
                // left trigger bound to Start
                // right trigger bound to Select
                actionsheet.addAction(UIAlertAction(title: "P1 Start", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: {() -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
                actionsheet.addAction(UIAlertAction(title: "P1 Select", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: {() -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
            }
        }
        if let player2 = controllerManager.player2 {
            if (player2.extendedGamepad != nil || wantsStartSelectInMenu) {
                actionsheet.addAction(UIAlertAction(title: "P2 Start", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: {() -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionsheet.addAction(UIAlertAction(title: "P2 Select", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: {() -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
            }
        }
        if let swappableCore = core as? DiscSwappable, swappableCore.currentGameSupportsMultipleDiscs {
            actionsheet.addAction(UIAlertAction(title: "Swap Disc", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.showSwapDiscsMenu()
                })
            }))
        }
#if os(iOS)
        actionsheet.addAction(UIAlertAction(title: "Screenshot", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            self.perform(#selector(self.takeScreenshot), with: nil, afterDelay: 0.1)
        }))
#endif
        actionsheet.addAction(UIAlertAction(title: "Save States", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            self.perform(#selector(self.showSaveStateMenu), with: nil, afterDelay: 0.1)
        }))
        actionsheet.addAction(UIAlertAction(title: "Game Speed", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            self.perform(#selector(self.showSpeedMenu), with: nil, afterDelay: 0.1)
        }))
        actionsheet.addAction(UIAlertAction(title: "Reset", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            if PVSettingsModel.sharedInstance().autoSave {
                try? self.autoSaveState()
            }
            self.core.setPauseEmulation(false)
            self.core.resetEmulation()
            self.isShowingMenu = false
            self.enableContorllerInput(false)
        }))
        actionsheet.addAction(UIAlertAction(title: "Game Info", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            let sb = UIStoryboard(name: "Provenance", bundle: nil)
            let moreInfoViewContrller = sb.instantiateViewController(withIdentifier: "gameMoreInfoVC") as? PVGameMoreInfoViewController
            moreInfoViewContrller?.game = self.game
            moreInfoViewContrller?.showsPlayButton = false
            moreInfoViewContrller?.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideModeInfo))
            let newNav = UINavigationController(rootViewController: moreInfoViewContrller ?? UIViewController())
            self.present(newNav, animated: true) {() -> Void in }
			self.isShowingMenu = false
			self.enableContorllerInput(false)
        }))
        actionsheet.addAction(UIAlertAction(title: "Return to Game Library", style: .destructive, handler: {(_ action: UIAlertAction) -> Void in
            self.quit()
        }))
        let resumeAction = UIAlertAction(title: "Resume", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            })
        actionsheet.addAction(resumeAction)
        if #available(iOS 9.0, *) {
            actionsheet.preferredAction = resumeAction
        }
        present(actionsheet, animated: true, completion: {() -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
        updatePlayedDuration()
    }

    @objc func hideModeInfo() {
        dismiss(animated: true, completion: {() -> Void in
#if os(tvOS)
            self.showMenu(nil)
#else
            self.hideMenu()
#endif
        })
    }

    func hideMenu() {
        enableContorllerInput(false)
        if menuActionSheet != nil {
            dismiss(animated: true) {() -> Void in }
            isShowingMenu = false
        }
        updateLastPlayedTime()
        core.setPauseEmulation(false)
    }

    @objc func updateFPSLabel() {
#if DEBUG
        print("FPS: \(glViewController?.framesPerSecond ?? 0)")
#endif
        fpsLabel?.text = String(format: "%2.02f", core.emulationFPS)
    }

    @objc func showSaveStateMenu() {
		guard let saveStatesNavController = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "PVSaveStatesViewControllerNav") as? UINavigationController else {
			return
		}

		let image = captureScreenshot()

		if let saveStatesViewController = saveStatesNavController.viewControllers.first as? PVSaveStatesViewController {
			saveStatesViewController.saveStates = game.saveStates
			saveStatesViewController.delegate = self
			saveStatesViewController.screenshot = image
		}

		saveStatesNavController.modalPresentationStyle = .overCurrentContext

#if os(iOS)
		if traitCollection.userInterfaceIdiom == .pad {
			saveStatesNavController.modalPresentationStyle = .formSheet
		}
#endif
#if os(tvOS)
		if #available(tvOS 11, *) {
			saveStatesNavController.modalPresentationStyle = .blurOverFullScreen
		}
#endif
		present(saveStatesNavController, animated: true)
    }

	func convertOldSaveStatesToNewIfNeeded() {
		let fileManager = FileManager.default
		let infoURL =  URL(fileURLWithPath: saveStatePath).appendingPathComponent("info.plist")
		let autoSaveURL = URL(fileURLWithPath: saveStatePath).appendingPathComponent("auto.svs")
		let saveStateURLs = [
			URL(fileURLWithPath: saveStatePath).appendingPathComponent("0.svs"),
			URL(fileURLWithPath: saveStatePath).appendingPathComponent("1.svs"),
			URL(fileURLWithPath: saveStatePath).appendingPathComponent("2.svs"),
			URL(fileURLWithPath: saveStatePath).appendingPathComponent("3.svs"),
			URL(fileURLWithPath: saveStatePath).appendingPathComponent("4.svs")
		]

		if fileManager.fileExists(atPath: infoURL.path) {
			do {
				try fileManager.removeItem(at: infoURL)
			} catch let error {
				presentError("Unable to remove old save state info.plist: \(error.localizedDescription)")
			}
		}

		guard let realm = try? Realm() else {
			presentError("Unable to instantiate realm, abandoning old save state conversion")
			return
		}

		if fileManager.fileExists(atPath: autoSaveURL.path) {
			do {
				guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
					presentError("No core in database with id \(self.core.coreIdentifier ?? "null")")
					return
				}

				let newURL = URL(fileURLWithPath: saveStatePath).appendingPathComponent("\(game.md5Hash)|\(Date().timeIntervalSinceReferenceDate)")
				try fileManager.moveItem(at: autoSaveURL, to: newURL)
				let saveFile = PVFile(withURL: newURL)
				let newState = PVSaveState(withGame: game, core: core, file: saveFile, image: nil, isAutosave: true)
				try realm.write {
					realm.add(newState)
				}
			} catch let error {
				presentError("Unable to convert autosave to new format: \(error.localizedDescription)")
			}
		}

		for url in saveStateURLs {
			if fileManager.fileExists(atPath: url.path) {
				do {
					guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
						presentError("No core in database with id \(self.core.coreIdentifier ?? "null")")
						return
					}

					let newURL = URL(fileURLWithPath: saveStatePath).appendingPathComponent("\(game.md5Hash)|\(Date().timeIntervalSinceReferenceDate)")
					try fileManager.moveItem(at: url, to: newURL)
					let saveFile = PVFile(withURL: newURL)
					let newState = PVSaveState(withGame: game, core: core, file: saveFile, image: nil, isAutosave: false)
					try realm.write {
						realm.add(newState)
					}
				} catch let error {
					presentError("Unable to convert autosave to new format: \(error.localizedDescription)")
				}
			}
		}
	}

	func autoSaveState() throws {
		let image = captureScreenshot()
		try createNewSaveState(auto: true, screenshot: image)
	}

	func createNewSaveState(auto: Bool, screenshot: UIImage?) throws {
		let saveFile = PVFile(withURL: URL(fileURLWithPath: saveStatePath).appendingPathComponent("\(game.md5Hash)|\(Date().timeIntervalSinceReferenceDate).svs"))

		var imageFile: PVImageFile?
		if let screenshot = screenshot {
			if let pngData = UIImagePNGRepresentation(screenshot) {
				let imageURL = URL(fileURLWithPath: saveStatePath).appendingPathComponent("\(game.md5Hash)|\(Date().timeIntervalSinceReferenceDate).png")
				do {
					try pngData.write(to: imageURL)
				} catch let error {
					presentError("Unable to write image to disk, error: \(error.localizedDescription)")
				}

				imageFile = PVImageFile(withURL: imageURL)
			}
		}

		if self.core.saveStateToFile(atPath: saveFile.url.path) {
			DLOG("Succeeded saving state, auto: \(auto)")
			if let realm = try? Realm() {
				guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
					presentError("No core in database with id \(self.core.coreIdentifier ?? "null")")
					return
				}

				let saveState = PVSaveState(withGame: game, core: core, file: saveFile, image: imageFile, isAutosave: auto)
				do {
					try realm.write {
						realm.add(saveState)
					}
				} catch let error {
					presentError("Unable to write save state to realm: \(error.localizedDescription)")
				}

				// Delete the oldest auto-saves over 5 count
				try? realm.write {
					let autoSaves = game.saveStates.filter({ $0.isAutosave == true  }).sorted(by: {$0.date > $1.date})
					if autoSaves.count > 5 {
						autoSaves.suffix(from: 5).forEach {
							DLOG("Deleting old auto save of \($0.game.title) dated: \($0.date.description)")
							realm.delete($0)
						}
					}
				}
			}
		} else {
			throw SaveStateError.failedToSave(isAutosave: auto)
		}
	}

	func loadSaveState(_ state: PVSaveState) {
		let realm = try! Realm()
		guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
			presentError("No core in database with id \(self.core.coreIdentifier ?? "null")")
			return
		}

		let loadSave = {
			try! realm.write {
				state.lastOpened = Date()
			}
			self.core.loadStateFromFile(atPath: state.file.url.path)
			self.core.setPauseEmulation(false)
			self.isShowingMenu = false
			self.enableContorllerInput(false)
		}

		if core.projectVersion != state.createdWithCoreVersion {
			let message =
			"""
			Save state created with version \(state.createdWithCoreVersion) but current \(core.projectName) core is version \(core.projectVersion).
			Save file may not load. Create a new save state to avoid this warning in the future.
			"""
			presentWarning(message, completion: loadSave)
		} else {
			loadSave()
		}
	}

	func saveStatesViewControllerDone(_ saveStatesViewController: PVSaveStatesViewController) {
		dismiss(animated: true, completion: nil)
		self.core.setPauseEmulation(false)
		self.isShowingMenu = false
		self.enableContorllerInput(false)
	}

	func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController) throws {
		try createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot)
	}

    func saveStatesViewControllerOverwriteState(_ saveStatesViewController: PVSaveStatesViewController, state: PVSaveState) throws {
        try createNewSaveState(auto: false, screenshot: saveStatesViewController.screenshot)
		try PVSaveState.delete(state)
    }

	func saveStatesViewController(_ saveStatesViewController: PVSaveStatesViewController, load state: PVSaveState) {
		dismiss(animated: true, completion: nil)
		loadSaveState(state)
	}

	func captureScreenshot() -> UIImage? {
		fpsLabel?.alpha = 0.0
		let width: CGFloat? = self.glViewController?.view.frame.size.width
		let height: CGFloat? = self.glViewController?.view.frame.size.height
		let size = CGSize(width: width ?? 0.0, height: height ?? 0.0)
		UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
		let rec = CGRect(x: 0, y: 0, width: width ?? 0.0, height: height ?? 0.0)
		self.glViewController?.view.drawHierarchy(in: rec, afterScreenUpdates: true)
		let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		fpsLabel?.alpha = 1.0
		return image
	}
#if os(iOS)
    @objc func takeScreenshot() {
		if let screenshot = captureScreenshot() {
			DispatchQueue.global(qos: .default).async(execute: {() -> Void in
				UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
			})
		}
		self.core.setPauseEmulation(false)
		self.isShowingMenu = false
    }

#endif
    @objc func showSpeedMenu() {
        let actionSheet = UIAlertController(title: "Game Speed", message: nil, preferredStyle: .actionSheet)
        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton!.bounds
        }
        let speeds = ["Slow", "Normal", "Fast"]
        speeds.enumerated().forEach { (idx, title) in
            actionSheet.addAction(UIAlertAction(title: title, style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.core.gameSpeed = GameSpeed(rawValue: idx) ?? .normal
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }))
        }
        present(actionSheet, animated: true, completion: {() -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
    }

    typealias QuitCompletion = () -> Void

    func quit(_ completion: QuitCompletion? = nil) {
        if PVSettingsModel.sharedInstance().autoSave {
			do {
				try autoSaveState()
			} catch {
				ELOG("Auto-save failed \(error.localizedDescription)")
			}
        }
        core.stopEmulation()
        //Leave emulation loop first
        fpsTimer?.invalidate()
        fpsTimer = nil
        gameAudio?.stop()
#if os(iOS)
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
#endif
        dismiss(animated: true, completion: completion)
        enableContorllerInput(false)
        updatePlayedDuration()
    }

// MARK: - Controllers
    //#if os(tvOS)
    // Ensure that override of menu gesture is caught and handled properly for tvOS
    @available(iOS 9.0, *)
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {

        if let press = presses.first, press.type == .menu && !isShowingMenu {
            //         [self controllerPauseButtonPressed];
        } else {
            super.pressesBegan(presses, with: event)
        }
    }

    //#endif
    @objc func controllerPauseButtonPressed(_ sender: Any?) {
        DispatchQueue.main.async(execute: {() -> Void in
            if !self.isShowingMenu {
                self.showMenu(self)
            } else {
                self.hideMenu()
            }
        })
    }

    @objc func controllerDidConnect(_ note: Notification?) {
        let controller = note?.object as? GCController
        // 8Bitdo controllers don't have a pause button, so don't hide the menu
        if !(controller is PViCade8BitdoController || controller is PViCade8BitdoZeroController) {
            menuButton?.isHidden = true
                // In instances where the controller is connected *after* the VC has been shown, we need to set the pause handler
#if os(iOS)

    controller?.controllerPausedHandler = {[unowned self] controller in
        self.controllerPauseButtonPressed(controller)
    }
            if #available(iOS 11.0, *) {
                setNeedsUpdateOfHomeIndicatorAutoHidden()
            }
#endif
        }
    }

    @objc func controllerDidDisconnect(_ note: Notification?) {
        menuButton?.isHidden = false
#if os(iOS)
        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
#endif
    }

    @objc func handleControllerManagerControllerReassigned(_ notification: Notification?) {
        core.controller1 = PVControllerManager.shared.player1
        core.controller2 = PVControllerManager.shared.player2
        core.controller3 = PVControllerManager.shared.player3
        core.controller4 = PVControllerManager.shared.player4
    }

// MARK: - UIScreenNotifications
    @objc func screenDidConnect(_ note: Notification?) {
        ILOG("Screen did connect: \(note?.object ?? "")")
        if secondaryScreen == nil {
            secondaryScreen = UIScreen.screens[1]
            if let aBounds = secondaryScreen?.bounds {
                secondaryWindow = UIWindow(frame: aBounds)
            }
            if let aScreen = secondaryScreen {
                secondaryWindow?.screen = aScreen
            }
            glViewController?.view?.removeFromSuperview()
            glViewController?.removeFromParentViewController()
            secondaryWindow?.rootViewController = glViewController
            glViewController?.view?.frame = secondaryWindow?.bounds ?? .zero
            if let aView = glViewController?.view {
                secondaryWindow?.addSubview(aView)
            }
            secondaryWindow?.isHidden = false
            glViewController?.view?.setNeedsLayout()
        }
    }

    @objc func screenDidDisconnect(_ note: Notification?) {
        ILOG("Screen did disconnect: \(note?.object ?? "")")
        let screen = note?.object as? UIScreen
        if secondaryScreen == screen {
            glViewController?.view?.removeFromSuperview()
            glViewController?.removeFromParentViewController()
            if let aController = glViewController {
                addChildViewController(aController)
            }
            if let aView = glViewController?.view, let aView1 = controllerViewController?.view {
                view.insertSubview(aView, belowSubview: aView1)
            }
            glViewController?.view?.setNeedsLayout()
            secondaryWindow = nil
            secondaryScreen = nil
        }
    }

// MARK: - PVAudioDelegate
    func audioSampleRateDidChange() {
        gameAudio?.stop()
        gameAudio?.start()
    }
}

extension PVEmulatorViewController {
    func showSwapDiscsMenu() {
        guard let core = self.core as? (PVEmulatorCore & DiscSwappable) else {
			presentError("Internal error: No core found.")
			self.isShowingMenu = false
			self.enableContorllerInput(false)
            return
        }

        let numberOfDiscs = core.numberOfDiscs
        guard numberOfDiscs > 1 else {
            presentError("Game only supports 1 disc.")
			core.setPauseEmulation(false)
			self.isShowingMenu = false
			self.enableContorllerInput(false)
            return
        }

        // Add action for each disc
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for index in 1...numberOfDiscs {
            actionSheet.addAction(UIAlertAction(title: "\(index)", style: .default, handler: {[unowned self] (sheet) in

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    core.swapDisc(number: index)
                })

                core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }))
        }

        // Add cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {[unowned self] (sheet) in
            core.setPauseEmulation(false)
            self.isShowingMenu = false
			self.enableContorllerInput(false)
        }))

        // Present
        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton?.bounds ?? .zero
        }

        self.present(actionSheet, animated: true) {
            PVControllerManager.shared.iCadeController?.refreshListener()
        }
    }
}


// Extension to make gesture.allowedPressTypes and gesture.allowedTouchTypes sane.
@available(iOS 9.0, *)
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

    private convenience init(pressType: UIPressType) {
        self.init(integerLiteral: pressType.rawValue)
    }
}

@available(iOS 9.0, *)
extension NSNumber {
    static var direct: NSNumber {
        return NSNumber(touchType: .direct)
    }
    static var indirect: NSNumber {
        return NSNumber(touchType: .indirect)
    }
    // MARK: - Private

    private convenience init(touchType: UITouchType) {
        self.init(integerLiteral: touchType.rawValue)
    }
}
