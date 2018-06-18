//
//  PVControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import AudioToolbox
import GameController
import PVSupport
import QuartzCore
import UIKit

protocol JSButtonDisplayer {
    var dPad: JSDPad? { get set }
    var dPad2: JSDPad? { get set }
    var buttonGroup: UIView? { get set }
    var leftShoulderButton: JSButton? { get set }
    var rightShoulderButton: JSButton? { get set }
    var leftShoulderButton2: JSButton? { get set }
    var rightShoulderButton2: JSButton? { get set }
    var zTriggerButton: JSButton? { get set }
    var startButton: JSButton? { get set }
    var selectButton: JSButton? { get set }
}

private typealias Keys = SystemDictionaryKeys.ControllerLayoutKeys
private let kDPadTopMargin: CGFloat = 96.0

protocol StartSelectDelegate: class {
    func pressStart(forPlayer player: Int)
    func releaseStart(forPlayer player: Int)
    func pressSelect(forPlayer player: Int)
    func releaseSelect(forPlayer player: Int)
}

protocol ControllerVC: StartSelectDelegate, JSButtonDelegate, JSDPadDelegate where Self: UIViewController {
    associatedtype ResponderType: ResponderClient
    var emulatorCore: ResponderType {get}
    var system: PVSystem {get set}
    var controlLayout: [ControlLayoutEntry] {get set}

    var dPad: JSDPad? {get}
    var dPad2: JSDPad? {get}
    var buttonGroup: UIView? {get}
    var leftShoulderButton: JSButton? {get}
    var rightShoulderButton: JSButton? {get}
    var leftShoulderButton2: JSButton? {get}
    var rightShoulderButton2: JSButton? {get}
    var zTriggerButton: JSButton? { get set }
    var startButton: JSButton? {get}
    var selectButton: JSButton? {get}

    func layoutViews()
    func vibrate()
}

#if os(iOS)
let volume = SubtleVolume(style: .roundedLine)
let volumeHeight: CGFloat = 3
#endif

// Dummy implmentations
//extension ControllerVC {
//extension PVControllerViewController {
//    func layoutViews() {
//        ILOG("Dummy called")
//    }
//
//    func pressStart(forPlayer player: Int) {
//        vibrate()
//        ILOG("Dummy called")
//    }
//
//    func releaseStart(forPlayer player: Int) {
//        ILOG("Dummy called")
//    }
//
//    func pressSelect(forPlayer player: Int) {
//        vibrate()
//        ILOG("Dummy called")
//    }
//
//    func releaseSelect(forPlayer player: Int) {
//        ILOG("Dummy called")
//    }
//
//    // MARK: - JSButtonDelegate
//    func buttonPressed(_ button: JSButton) {
//        ILOG("Dummy called")
//    }
//
//    func buttonReleased(_ button: JSButton) {
//        ILOG("Dummy called")
//    }
//
//    // MARK: - JSDPadDelegate
//    func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
//        ILOG("Dummy called")
//    }
//    func dPadDidReleaseDirection(_ dPad: JSDPad) {
//        ILOG("Dummy called")
//    }
//}

class PVControllerViewController<T: ResponderClient> : UIViewController, ControllerVC {
    func layoutViews() {

    }

    func pressStart(forPlayer player: Int) {
        vibrate()
    }

    func releaseStart(forPlayer player: Int) {

    }

    func pressSelect(forPlayer player: Int) {
        vibrate()
    }

    func releaseSelect(forPlayer player: Int) {

    }

    func buttonPressed(_ button: JSButton) {
        vibrate()
    }

    func buttonReleased(_ button: JSButton) {

    }

    func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        vibrate()
    }

    func dPadDidReleaseDirection(_ dPad: JSDPad) {

    }

    typealias ResponderType = T
    var emulatorCore: ResponderType

    var system: PVSystem
    var controlLayout: [ControlLayoutEntry]

    var dPad: JSDPad?
    var dPad2: JSDPad?
    var buttonGroup: UIView?
    var leftShoulderButton: JSButton?
    var rightShoulderButton: JSButton?
    var leftShoulderButton2: JSButton?
    var rightShoulderButton2: JSButton?
    var zTriggerButton: JSButton?
    var startButton: JSButton?
    var selectButton: JSButton?

    let alpha: CGFloat = PVSettingsModel.shared.controllerOpacity

    #if os(iOS)
    private var _feedbackGenerator: AnyObject?
    @available(iOS 10.0, *)
    var feedbackGenerator: UISelectionFeedbackGenerator? {
        get {
            return _feedbackGenerator as? UISelectionFeedbackGenerator
        }
        set {
            _feedbackGenerator = newValue
        }
    }
    #endif

    required init(controlLayout: [ControlLayoutEntry], system: PVSystem, responder: T) {
        self.emulatorCore = responder
        self.controlLayout = controlLayout
        self.system = system
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        GCController.controllers().forEach {
            $0.controllerPausedHandler = nil
        }
    }

    func updateHideTouchControls() {
        if PVControllerManager.shared.hasControllers {
            PVControllerManager.shared.allLiveControllers.forEach({ (key, controller) in
                self.hideTouchControls(for: controller)
            })
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        #if os(iOS)
            if #available(iOS 10.0, *) {
                feedbackGenerator = UISelectionFeedbackGenerator()
                feedbackGenerator?.prepare()
            }
            updateHideTouchControls()

        if PVSettingsModel.shared.volumeHUD {
            volume.barTintColor = .white
            volume.barBackgroundColor = UIColor.white.withAlphaComponent(0.3)
            volume.animation = .slideDown
            view.addSubview(volume)
        }

        NotificationCenter.default.addObserver(volume, selector: #selector(SubtleVolume.resume), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)

        #endif
    }

    // MARK: - GameController Notifications
    @objc func controllerDidConnect(_ note: Notification?) {
        #if os(iOS)
            if PVControllerManager.shared.hasControllers {
                PVControllerManager.shared.allLiveControllers.forEach({ (key, controller) in
                    self.hideTouchControls(for: controller)
                })
            } else {
                dPad?.isHidden = false
                dPad2?.isHidden = traitCollection.verticalSizeClass == .compact
                buttonGroup?.isHidden = false
                leftShoulderButton?.isHidden = false
                rightShoulderButton?.isHidden = false
                leftShoulderButton2?.isHidden = false
                rightShoulderButton2?.isHidden = false
                zTriggerButton?.isHidden = false
                startButton?.isHidden = false
                selectButton?.isHidden = false
            }
        setupTouchControls()
        #endif
    }

    @objc func controllerDidDisconnect(_ note: Notification?) {
        #if os(iOS)
            if PVControllerManager.shared.hasControllers {
                if PVControllerManager.shared.hasControllers {
                    PVControllerManager.shared.allLiveControllers.forEach({ (key, controller) in
                        self.hideTouchControls(for: controller)
                    })
                }
            } else {
                dPad?.isHidden = false
                dPad2?.isHidden = traitCollection.verticalSizeClass == .compact
                buttonGroup?.isHidden = false
                leftShoulderButton?.isHidden = false
                rightShoulderButton?.isHidden = false
                leftShoulderButton2?.isHidden = false
                rightShoulderButton2?.isHidden = false
                zTriggerButton?.isHidden = false
                startButton?.isHidden = false
                selectButton?.isHidden = false
            }
        setupTouchControls()
        #endif
    }

    func vibrate() {
        #if os(iOS)
            if PVSettingsModel.shared.buttonVibration {
                // only iPhone 7 and 7 Plus support the taptic engine APIs for now.
                // everything else should fall back to the vibration motor.
                if #available(iOS 10.0, *), UIDevice.hasTapticMotor {
                    feedbackGenerator?.selectionChanged()
                } else {
                    AudioServicesStopSystemSound(Int32(kSystemSoundID_Vibrate))
                    let vibrationLength: Int = 30
                    let pattern: [Any] = [false, 0, true, vibrationLength]
                    var dictionary = [AnyHashable: Any]()
                    dictionary["VibePattern"] = pattern
                    dictionary["Intensity"] = 1
                    AudioServicesPlaySystemSoundWithVibration(Int32(kSystemSoundID_Vibrate), nil, dictionary)
                }
            }
        #endif
    }

    #if os(iOS)
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    #endif

    open override func didMove(toParentViewController parent: UIViewController?) {
        super.didMove(toParentViewController: parent)
        if let s = view.superview {
            view.frame = s.bounds
        }
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    #if os(iOS)
        setupTouchControls()
        layoutViews()
        if PVSettingsModel.shared.volumeHUD {
            layoutVolume()
        }
        updateHideTouchControls()
    #endif
    }

    #if os(iOS)
    func layoutVolume() {
        let volumeYPadding: CGFloat = 10
        let volumeXPadding = UIScreen.main.bounds.width * 0.4 / 2

        volume.superview?.bringSubview(toFront: volume)
        volume.layer.cornerRadius = volumeHeight / 2
        volume.frame = CGRect(x: safeAreaInsets.left + volumeXPadding, y: safeAreaInsets.top + volumeYPadding, width: UIScreen.main.bounds.width - (volumeXPadding * 2) - safeAreaInsets.left - safeAreaInsets.right, height: volumeHeight)
    }
    #endif

    @objc
    func hideTouchControls(for controller: GCController) {
        dPad?.isHidden = true
        buttonGroup?.isHidden = true
        leftShoulderButton?.isHidden = true
        rightShoulderButton?.isHidden = true
        leftShoulderButton2?.isHidden = true
        rightShoulderButton2?.isHidden = true
        zTriggerButton?.isHidden = true

        //Game Boy, Game Color, and Game Boy Advance can map Start and Select on a Standard Gamepad, so it's safe to hide them
        let useStandardGamepad: [SystemIdentifier] = [.GB, .GBC, .GBA]

        if ((controller.extendedGamepad != nil) || (controller.gamepad != nil) || useStandardGamepad.contains(system.enumValue)) && !PVSettingsModel.shared.startSelectAlwaysOn {
            startButton?.isHidden = true
            selectButton?.isHidden = true
        } else if PVSettingsModel.shared.startSelectAlwaysOn {
            startButton?.isHidden = false
            selectButton?.isHidden = false
        }
        setupTouchControls()
    }

    var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, tvOS 11.0, *) {
            return view.safeAreaInsets
        } else {
            return UIEdgeInsets.zero
        }
    }

    // MARK: - Controller Position And Size Editing
    func setupTouchControls() {
        #if os(iOS)
            let alpha = self.alpha

            for control in controlLayout {
				let controlType: String = control.PVControlType
                let controlSize: CGSize = CGSizeFromString(control.PVControlSize)
                let compactVertical: Bool = traitCollection.verticalSizeClass == .compact
                let controlOriginY: CGFloat = compactVertical ? view.bounds.size.height - controlSize.height : view.frame.width + (kDPadTopMargin / 2)

                if (controlType == Keys.DPad) {
                    let xPadding: CGFloat = safeAreaInsets.left + 5
                    let bottomPadding: CGFloat = 16
                    let dPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                    var dPadFrame = CGRect(x: xPadding, y: dPadOriginY, width: controlSize.width, height: controlSize.height)

                    if dPad2 == nil && (control.PVControlTitle == "Y") {
                        dPadFrame.origin.y = dPadOriginY - controlSize.height - bottomPadding
                        let dPad2 = JSDPad(frame: dPadFrame)
                        if let tintColor = control.PVControlTint {
                            dPad2.tintColor = UIColor(hex: tintColor)
                        }
                        self.dPad2 = dPad2
                        dPad2.delegate = self
                        dPad2.alpha = alpha
                        dPad2.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                        view.addSubview(dPad2)
                    } else if dPad == nil {
                        let dPad = JSDPad(frame: dPadFrame)
                        if let tintColor = control.PVControlTint {
                            dPad.tintColor = UIColor(hex: tintColor)
                        }
                        self.dPad = dPad
                        dPad.delegate = self
                        dPad.alpha = alpha
                        dPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                        view.addSubview(dPad)
                    } else {
                        dPad?.frame = dPadFrame
                    }
                    dPad2?.isHidden = compactVertical
                } else if (controlType == Keys.ButtonGroup) {
                    let xPadding: CGFloat = safeAreaInsets.right + 5
                    let bottomPadding: CGFloat = 16
                    let buttonsOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                    let buttonsFrame = CGRect(x: view.bounds.maxX - controlSize.width - xPadding, y: buttonsOriginY, width: controlSize.width, height: controlSize.height)

                    if let buttonGroup = self.buttonGroup {
                        buttonGroup.frame = buttonsFrame
                    } else {
                        let buttonGroup = UIView(frame: buttonsFrame)
                        self.buttonGroup = buttonGroup
                        buttonGroup.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]

                        var buttons = [JSButton]()

                        let groupedButtons = control.PVGroupedButtons
                        groupedButtons?.forEach { groupedButton in
                            let buttonFrame: CGRect = CGRectFromString(groupedButton.PVControlFrame)
                            let button = JSButton(frame: buttonFrame)
                            button.titleLabel?.text = groupedButton.PVControlTitle

                            if let tintColor = groupedButton.PVControlTint {
                                button.tintColor = UIColor(hex: tintColor)
                            }

                            button.backgroundImage = UIImage(named: "button")
                            button.backgroundImagePressed = UIImage(named: "button-pressed")
                            button.delegate = self
                            buttonGroup.addSubview(button)
                            buttons.append(button)
                        }

                        let buttonOverlay = PVButtonGroupOverlayView(buttons: buttons)
                        buttonOverlay.setSize(buttonGroup.bounds.size)
                        buttonGroup.addSubview(buttonOverlay)
                        buttonGroup.alpha = alpha
                        view.addSubview(buttonGroup)
                    }
                } else if (controlType == Keys.RightShoulderButton) {
                    layoutRightShoulderButtons(control: control)
                } else if (controlType == Keys.ZTriggerButton) {
                    layoutZTriggerButton(control: control)
                } else if (controlType == Keys.LeftShoulderButton) {
                    layoutLeftShoulderButtons(control: control)
                } else if (controlType == Keys.SelectButton) {
                    layoutSelectButton(control: control)
                } else if (controlType == Keys.StartButton) {
                    layoutStartButton(control: control)
                }
            }
        #endif
    }

    #if os(iOS)
    func layoutRightShoulderButtons(control: ControlLayoutEntry) {
        let controlSize: CGSize = CGSizeFromString(control.PVControlSize)
        let xPadding: CGFloat = safeAreaInsets.right + 10
        let yPadding: CGFloat = safeAreaInsets.bottom + 10
        var rightShoulderFrame: CGRect!

        if (buttonGroup != nil) && !(buttonGroup?.isHidden)! {
            rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: (buttonGroup?.frame.minY)! - (controlSize.height * 2) - 4, width: controlSize.width, height: controlSize.height)

            if PVSettingsModel.shared.allRightShoulders && (system.shortName == "GBA" || system.shortName == "VB") {
                rightShoulderFrame.origin.y += ((buttonGroup?.frame.height)! / 2 - controlSize.height)
            }

        } else {
            rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.size.height - (controlSize.height * 2) - yPadding, width: controlSize.width, height: controlSize.height)
        }

        if rightShoulderButton == nil {
            let rightShoulderButton = JSButton(frame: rightShoulderFrame)
            if let tintColor = control.PVControlTint {
                rightShoulderButton.tintColor = UIColor(hex: tintColor)
            }
            self.rightShoulderButton = rightShoulderButton
            rightShoulderButton.titleLabel?.text = control.PVControlTitle
            rightShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            rightShoulderButton.backgroundImage = UIImage(named: "button-thin")
            rightShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            rightShoulderButton.delegate = self
            rightShoulderButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            rightShoulderButton.alpha = alpha
            rightShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            view.addSubview(rightShoulderButton)
        } else if rightShoulderButton2 == nil, let title = control.PVControlTitle, title == "R2" {
            let rightShoulderButton2 = JSButton(frame: rightShoulderFrame)
            if let tintColor = control.PVControlTint {
                rightShoulderButton2.tintColor = UIColor(hex: tintColor)
            }
            self.rightShoulderButton2 = rightShoulderButton2
            rightShoulderButton2.titleLabel?.text = control.PVControlTitle
            rightShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            rightShoulderButton2.backgroundImage = UIImage(named: "button-thin")
            rightShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            rightShoulderButton2.delegate = self
            rightShoulderButton2.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            rightShoulderButton2.alpha = alpha
            rightShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            rightShoulderFrame.origin.y += controlSize.height
            view.addSubview(rightShoulderButton2)
        } else {
            rightShoulderButton2?.frame = rightShoulderFrame
            rightShoulderFrame.origin.y += rightShoulderButton!.frame.size.height
            rightShoulderButton?.frame = rightShoulderFrame
        }
    }

    func layoutZTriggerButton(control: ControlLayoutEntry) {
        let controlSize: CGSize = CGSizeFromString(control.PVControlSize)
        let xPadding: CGFloat = safeAreaInsets.right + 10
        let yPadding: CGFloat = safeAreaInsets.bottom + 10
        var zTriggerFrame: CGRect!

        if rightShoulderButton != nil {
            zTriggerFrame = CGRect(x: (rightShoulderButton?.frame.minX)! - controlSize.width, y: (rightShoulderButton?.frame.minY)!, width: controlSize.width, height: controlSize.height)
        } else {
            zTriggerFrame = CGRect(x: view.frame.size.width - (controlSize.width * 2) - xPadding, y: view.frame.size.height - (controlSize.height * 2)
                - yPadding, width: controlSize.width, height: controlSize.height)
        }

        if let zTriggerButton = self.zTriggerButton {
            zTriggerButton.frame = zTriggerFrame
        } else {
            let zTriggerButton = JSButton(frame: zTriggerFrame)
            if let tintColor = control.PVControlTint {
                zTriggerButton.tintColor = UIColor(hex: tintColor)
            }
            self.zTriggerButton = zTriggerButton
            zTriggerButton.titleLabel?.text = control.PVControlTitle
            zTriggerButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            zTriggerButton.backgroundImage = UIImage(named: "button-thin")
            zTriggerButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            zTriggerButton.delegate = self
            zTriggerButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            zTriggerButton.alpha = alpha
            zTriggerButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            view.addSubview(zTriggerButton)
        }
    }

    func layoutLeftShoulderButtons(control: ControlLayoutEntry) {
        let controlSize: CGSize = CGSizeFromString(control.PVControlSize)
        let xPadding: CGFloat = safeAreaInsets.left + 10
        let yPadding: CGFloat = safeAreaInsets.bottom + 10
        var leftShoulderFrame: CGRect!
        if (buttonGroup != nil) && !(buttonGroup?.isHidden)! {
            leftShoulderFrame = CGRect(x: xPadding, y: (buttonGroup?.frame.minY)! - (controlSize.height * 2) - 4, width: controlSize.width, height: controlSize.height)
        } else {
            leftShoulderFrame = CGRect(x: xPadding, y: view.frame.size.height - (controlSize.height * 2) - yPadding, width: controlSize.width, height: controlSize.height)
        }

        if PVSettingsModel.shared.allRightShoulders {
            if zTriggerButton != nil {
                leftShoulderFrame.origin.x = (zTriggerButton?.frame.origin.x)! - controlSize.width
            } else if zTriggerButton == nil && rightShoulderButton != nil {
                leftShoulderFrame.origin.x = (rightShoulderButton?.frame.origin.x)! - controlSize.width

                if system.shortName == "GBA" || system.shortName == "VB" {
                    leftShoulderFrame.origin.y += ((buttonGroup?.frame.height)! / 2 - controlSize.height)
                }
            }
        }

        if leftShoulderButton == nil {
            let leftShoulderButton = JSButton(frame: leftShoulderFrame)
            self.leftShoulderButton = leftShoulderButton
            leftShoulderButton.titleLabel?.text = control.PVControlTitle
            leftShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            if let tintColor = control.PVControlTint {
                leftShoulderButton.tintColor = UIColor(hex: tintColor)
            }
            leftShoulderButton.backgroundImage = UIImage(named: "button-thin")
            leftShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            leftShoulderButton.delegate = self
            leftShoulderButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            leftShoulderButton.alpha = alpha
            leftShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
            view.addSubview(leftShoulderButton)
        } else if leftShoulderButton2 == nil, let title = control.PVControlTitle, title == "L2" {

            let leftShoulderButton2 = JSButton(frame: leftShoulderFrame)
            if let tintColor = control.PVControlTint {
                leftShoulderButton2.tintColor = UIColor(hex: tintColor)
            }
            self.leftShoulderButton2 = leftShoulderButton2
            leftShoulderButton2.titleLabel?.text = control.PVControlTitle
            leftShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            leftShoulderButton2.backgroundImage = UIImage(named: "button-thin")
            leftShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            leftShoulderButton2.delegate = self
            leftShoulderButton2.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            leftShoulderButton2.alpha = alpha
            leftShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
            view.addSubview(leftShoulderButton2)

        } else {
            leftShoulderButton2?.frame = leftShoulderFrame
            leftShoulderFrame.origin.y += leftShoulderButton!.frame.size.height
            leftShoulderButton?.frame = leftShoulderFrame
        }
    }

    func layoutSelectButton( control: ControlLayoutEntry ) {
        let controlSize: CGSize = CGSizeFromString(control.PVControlSize)
        let yPadding: CGFloat = safeAreaInsets.bottom + 10
        let xPadding: CGFloat = safeAreaInsets.left + 10
        let spacing: CGFloat = 20
        var selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)

        if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            if (dPad != nil) && !(dPad?.isHidden)! {
                selectFrame = CGRect(x: (dPad?.frame.origin.x)! + (dPad?.frame.size.width)! - (controlSize.width / 3), y: (buttonGroup?.frame.maxY)! - controlSize.height, width: controlSize.width, height: controlSize.height)
            } else if (dPad != nil) && (dPad?.isHidden)! {
                selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
            }

        } else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
			let x: CGFloat = (view.frame.size.width / 2) - controlSize.width - (spacing / 2)
			let y: CGFloat = (buttonGroup?.frame.maxY ?? 0) + spacing
            selectFrame = CGRect(x: x, y: y, width: controlSize.width, height: controlSize.height)
        }

        if let selectButton = self.selectButton {
            selectButton.frame = selectFrame
        } else {
            let selectButton = JSButton(frame: selectFrame)
            if let tintColor = control.PVControlTint {
                selectButton.tintColor = UIColor(hex: tintColor)
            }
            self.selectButton = selectButton
            selectButton.titleLabel?.text = control.PVControlTitle
            selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            selectButton.backgroundImage = UIImage(named: "button-thin")
            selectButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            selectButton.delegate = self
            selectButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            selectButton.alpha = alpha
            selectButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
            view.addSubview(selectButton)
        }
    }

    func layoutStartButton(control: ControlLayoutEntry) {
        let controlSize: CGSize = CGSizeFromString(control.PVControlSize)
        let yPadding: CGFloat = safeAreaInsets.bottom + 10
        let xPadding: CGFloat = safeAreaInsets.right + 10
        let spacing: CGFloat = 20
        var startFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)

        if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            if (buttonGroup != nil) && !(buttonGroup?.isHidden)! {
                startFrame = CGRect(x: (buttonGroup?.frame.origin.x)! - controlSize.width + (controlSize.width / 3), y: (buttonGroup?.frame.maxY)! - controlSize.height, width: controlSize.width, height: controlSize.height)
                if system.shortName == "SG" || system.shortName == "SCD" || system.shortName == "32X" || system.shortName == "PCFX" {
                    startFrame.origin.x -= (controlSize.width / 2)
                }
            } else if (buttonGroup != nil) && (buttonGroup?.isHidden)! {
                startFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
            }
        } else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
            startFrame = CGRect(x: (view.frame.size.width / 2) + (spacing / 2), y: (buttonGroup?.frame.maxY)! + spacing, width: controlSize.width, height: controlSize.height)
            if selectButton == nil {
                startFrame.origin.x -= (spacing / 2) + (controlSize.width / 2)
            }
        }

        if let startButton = self.startButton {
            startButton.frame = startFrame
        } else {
            let startButton = JSButton(frame: startFrame)
            if let tintColor = control.PVControlTint {
                startButton.tintColor = UIColor(hex: tintColor)
            }
            self.startButton = startButton
            startButton.titleLabel?.text = control.PVControlTitle
            startButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            startButton.backgroundImage = UIImage(named: "button-thin")
            startButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
            startButton.delegate = self
            startButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            startButton.alpha = alpha
            startButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
            view.addSubview(startButton)
        }
    }

    #endif
}
