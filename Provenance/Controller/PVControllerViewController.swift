//
//  PVControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import AudioToolbox
import GameController
import PVLibrary
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
    var leftAnalogButton: JSButton? { get set }
    var rightAnalogButton: JSButton? { get set }
    var zTriggerButton: JSButton? { get set }
    var startButton: JSButton? { get set }
    var selectButton: JSButton? { get set }
}

private typealias Keys = SystemDictionaryKeys.ControllerLayoutKeys
private let kDPadTopMargin: CGFloat = 96.0
private let gripControl = false

protocol StartSelectDelegate: class {
    func pressStart(forPlayer player: Int)
    func releaseStart(forPlayer player: Int)
    func pressSelect(forPlayer player: Int)
    func releaseSelect(forPlayer player: Int)
    func pressAnalogMode(forPlayer player: Int)
    func releaseAnalogMode(forPlayer player: Int)
    func pressL3(forPlayer player: Int)
    func releaseL3(forPlayer player: Int)
    func pressR3(forPlayer player: Int)
    func releaseR3(forPlayer player: Int)
}

protocol ControllerVC: StartSelectDelegate, JSButtonDelegate, JSDPadDelegate where Self: UIViewController {
    associatedtype ResponderType: ResponderClient
    var emulatorCore: ResponderType { get }
    var system: PVSystem { get set }
    var controlLayout: [ControlLayoutEntry] { get set }

    var dPad: JSDPad? { get }
    var dPad2: JSDPad? { get }
    var buttonGroup: UIView? { get }
    var leftShoulderButton: JSButton? { get }
    var rightShoulderButton: JSButton? { get }
    var leftShoulderButton2: JSButton? { get }
    var rightShoulderButton2: JSButton? { get }
    var leftAnalogButton: JSButton? { get }
    var rightAnalogButton: JSButton? { get }
    var zTriggerButton: JSButton? { get set }
    var startButton: JSButton? { get }
    var selectButton: JSButton? { get }

    func layoutViews()
    func vibrate()
}

#if os(iOS)
    let volume = SubtleVolume(style: .roundedLine)
    let volumeHeight: CGFloat = 3
#endif

// Dummy implmentations
// extension ControllerVC {
// extension PVControllerViewController {
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
// }

class PVControllerViewController<T: ResponderClient>: UIViewController, ControllerVC {
    func layoutViews() {}

    func pressStart(forPlayer _: Int) {
        vibrate()
    }

    func releaseStart(forPlayer _: Int) {}

    func pressSelect(forPlayer _: Int) {
        vibrate()
    }

    func releaseSelect(forPlayer _: Int) {}

    func pressAnalogMode(forPlayer _: Int) {}

    func releaseAnalogMode(forPlayer _: Int) {}

    func pressL3(forPlayer _: Int) {}

    func releaseL3(forPlayer _: Int) {}

    func pressR3(forPlayer _: Int) {}

    func releaseR3(forPlayer _: Int) {}

    func buttonPressed(_: JSButton) {
        vibrate()
    }

    func buttonReleased(_: JSButton) {}

    func dPad(_: JSDPad, didPress _: JSDPadDirection) {
        vibrate()
    }

    func dPadDidReleaseDirection(_: JSDPad) {}

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
    var leftAnalogButton: JSButton?
    var rightAnalogButton: JSButton?

    let alpha: CGFloat = CGFloat(PVSettingsModel.shared.controllerOpacity)

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
        emulatorCore = responder
        self.controlLayout = controlLayout
        self.system = system
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        GCController.controllers().forEach {
            if #available(iOS 13, *) {
                $0.extendedGamepad?.buttonMenu.pressedChangedHandler = nil
            } else {
                $0.controllerPausedHandler = nil
            }
        }
    }

    func updateHideTouchControls() {
        if PVControllerManager.shared.hasControllers {
            if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                hideTouchControls(for: controller)
            }
        }
    }

    public override func viewDidLoad() {
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

            NotificationCenter.default.addObserver(volume, selector: #selector(SubtleVolume.resume), name: UIApplication.didBecomeActiveNotification, object: nil)

        #endif
    }

    // MARK: - GameController Notifications

    @objc func controllerDidConnect(_: Notification?) {
        #if os(iOS)
            if PVControllerManager.shared.hasControllers {
                if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                    hideTouchControls(for: controller)
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
                leftAnalogButton?.isHidden = false
                rightAnalogButton?.isHidden = false
            }
            setupTouchControls()
        #endif
    }

    @objc func controllerDidDisconnect(_: Notification?) {
        #if os(iOS)
            if PVControllerManager.shared.hasControllers {
                if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                    hideTouchControls(for: controller)
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
                leftAnalogButton?.isHidden = false
                rightAnalogButton?.isHidden = false
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

    open override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let s = view.superview {
            view.frame = s.bounds
        }
    }

    open override func viewDidLayoutSubviews() {
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

            volume.superview?.bringSubviewToFront(volume)
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

        if !PVSettingsModel.shared.missingButtonsAlwaysOn {
            selectButton?.isHidden = true
            startButton?.isHidden = true
            leftAnalogButton?.isHidden = true
            rightAnalogButton?.isHidden = true
        } else if controller.supportsThumbstickButtons() {
            leftAnalogButton?.isHidden = true
            rightAnalogButton?.isHidden = true
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
                let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
                let compactVertical: Bool = traitCollection.verticalSizeClass == .compact
                let controlOriginY: CGFloat = compactVertical ? view.bounds.size.height - controlSize.height : view.frame.width + (kDPadTopMargin / 2)

                if controlType == Keys.DPad {
                    let xPadding: CGFloat = safeAreaInsets.left + 5
                    let bottomPadding: CGFloat = 16
                    let dPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                    var dPadFrame = CGRect(x: xPadding, y: dPadOriginY, width: controlSize.width, height: controlSize.height)

                    if dPad2 == nil, (control.PVControlTitle == "Y") {
                        dPadFrame.origin.y = dPadOriginY - controlSize.height - bottomPadding
                        let dPad2 = JSDPad(frame: dPadFrame)
                        if let tintColor = control.PVControlTint {
                            dPad2.tintColor = UIColor(hex: tintColor)
                        }
                        dPad2.isDPad = true
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
                        dPad.isDPad = true
                        self.dPad = dPad
                        dPad.delegate = self
                        dPad.alpha = alpha
                        dPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                        view.addSubview(dPad)
                    } else {
                        dPad?.frame = dPadFrame
                    }
                    if dPad != nil {
                        dPad?.transform = .identity
                    }
                    dPad2?.isHidden = compactVertical
                } else if controlType == Keys.ButtonGroup {
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
                            let buttonFrame: CGRect = NSCoder.cgRect(for: groupedButton.PVControlFrame)
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
                    if buttonGroup != nil {
                        buttonGroup?.transform = .identity
                    }
                } else if controlType == Keys.RightShoulderButton {
                    layoutRightShoulderButtons(control: control)
                } else if controlType == Keys.ZTriggerButton {
                    layoutZTriggerButton(control: control)
                } else if controlType == Keys.LeftShoulderButton {
                    layoutLeftShoulderButtons(control: control)
                } else if controlType == Keys.SelectButton {
                    layoutSelectButton(control: control)
                } else if controlType == Keys.StartButton {
                    layoutStartButton(control: control)
                } else if controlType == Keys.LeftAnalogButton {
                    //layoutLeftAnalogButton(control: control)
                } else if controlType == Keys.RightAnalogButton {
                    //layoutRightAnalogButton(control: control)
                }
            }
        
            // Fix overlapping buttons on old/smaller iPhones
            if super.view.bounds.size.width < super.view.bounds.size.height {
                if UIScreen.main.bounds.height <= 568 || UIScreen.main.bounds.width <= 320 {
                    let scaleDPad = CGFloat(0.85)
                    let scaleButtons = CGFloat(0.75)
                    if dPad != nil {
                        dPad?.transform = CGAffineTransform(scaleX: scaleDPad, y: scaleDPad)
                        dPad?.frame.origin.x -= 20
                        dPad?.frame.origin.y -= 5
                    }
                    if buttonGroup != nil {
                        buttonGroup?.transform = CGAffineTransform(scaleX: scaleButtons, y: scaleButtons)
                        buttonGroup?.frame.origin.x += 30
                        buttonGroup?.frame.origin.y += 15
                        if system.shortName == "SG" || system.shortName == "SCD" || system.shortName == "32X" || system.shortName == "SS" || system.shortName == "PCFX" {
                            buttonGroup?.frame.origin.x += 15
                            buttonGroup?.frame.origin.y += 5
                        } else if system.shortName == "N64" {
                            buttonGroup?.frame.origin.x += 33
                        } else {
                            buttonGroup?.frame.origin.y += 4
                        }
                    }
                    let shoulderYOffset = CGFloat(35)
                    if leftShoulderButton != nil {
                        leftShoulderButton?.frame.origin.y += shoulderYOffset
                    }
                    if leftShoulderButton2 != nil {
                        leftShoulderButton2?.frame.origin.y += shoulderYOffset
                    }
                    if rightShoulderButton != nil {
                        rightShoulderButton?.frame.origin.y += shoulderYOffset
                    }
                    if rightShoulderButton2 != nil {
                        rightShoulderButton2?.frame.origin.y += shoulderYOffset
                    }
                    if zTriggerButton != nil {
                        zTriggerButton?.frame.origin.y += shoulderYOffset
                    }
                }
            }
        #endif
    }

    #if os(iOS)
        func layoutRightShoulderButtons(control: ControlLayoutEntry) {
            if rightShoulderButton == nil {
                let rightShoulderButton = JSButton(frame: .zero)
                if let tintColor = control.PVControlTint {
                    rightShoulderButton.tintColor = UIColor(hex: tintColor)
                }
                
                rightShoulderButton.translatesAutoresizingMaskIntoConstraints = false
                rightShoulderButton.titleLabel?.text = control.PVControlTitle
                rightShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                rightShoulderButton.backgroundColor = .clear
                rightShoulderButton.isSelectStart = true
                rightShoulderButton.delegate = self
                rightShoulderButton.alpha = alpha
                view.addSubview(rightShoulderButton)
                self.rightShoulderButton = rightShoulderButton
                
                self.rightShoulderButton?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
                self.rightShoulderButton?.topAnchor.constraint(equalTo: buttonGroup!.topAnchor, constant: -48).isActive = true
                self.rightShoulderButton?.widthAnchor.constraint(equalToConstant: 64).isActive = true
                self.rightShoulderButton?.heightAnchor.constraint(equalToConstant: 24).isActive = true
                
            } else if rightShoulderButton2 == nil, let title = control.PVControlTitle, title == "R2" {
                let rightShoulderButton2 = JSButton(frame: .zero)
                if let tintColor = control.PVControlTint {
                    rightShoulderButton2.tintColor = UIColor(hex: tintColor)
                }
                
                rightShoulderButton2.translatesAutoresizingMaskIntoConstraints = false
                rightShoulderButton2.titleLabel?.text = control.PVControlTitle
                rightShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                rightShoulderButton2.backgroundColor = .clear
                rightShoulderButton2.isSelectStart = true
                rightShoulderButton2.delegate = self
                rightShoulderButton2.alpha = alpha
                view.addSubview(rightShoulderButton2)
                self.rightShoulderButton2 = rightShoulderButton2
                
                self.rightShoulderButton2?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
                self.rightShoulderButton2?.bottomAnchor.constraint(equalTo: self.rightShoulderButton!.topAnchor, constant: -8).isActive = true
                self.rightShoulderButton2?.widthAnchor.constraint(equalToConstant: 64).isActive = true
                self.rightShoulderButton2?.heightAnchor.constraint(equalToConstant: 24).isActive = true
            }
            
            self.updateViewConstraints()
        }

        func layoutZTriggerButton(control: ControlLayoutEntry) {
            if zTriggerButton == nil {
                let zTriggerButton = JSButton(frame: .zero)
                if let tintColor = control.PVControlTint {
                    zTriggerButton.tintColor = UIColor(hex: tintColor)
                }
            
                zTriggerButton.translatesAutoresizingMaskIntoConstraints = false
                zTriggerButton.titleLabel?.text = control.PVControlTitle
                zTriggerButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                zTriggerButton.backgroundColor = .clear
                zTriggerButton.isSelectStart = true
                zTriggerButton.delegate = self
                zTriggerButton.alpha = alpha
                view.addSubview(zTriggerButton)
                self.zTriggerButton = zTriggerButton
            
                self.zTriggerButton?.trailingAnchor.constraint(equalTo: rightShoulderButton!.leadingAnchor, constant: -20).isActive = true
                self.zTriggerButton?.topAnchor.constraint(equalTo: buttonGroup!.topAnchor, constant: -48).isActive = true
                self.zTriggerButton?.widthAnchor.constraint(equalToConstant: 64).isActive = true
                self.zTriggerButton?.heightAnchor.constraint(equalToConstant: 24).isActive = true
            }
            
            self.updateViewConstraints()
        }

        func layoutLeftShoulderButtons(control: ControlLayoutEntry) {
            if leftShoulderButton == nil {
                let leftShoulderButton = JSButton(frame: .zero)
                if let tintColor = control.PVControlTint {
                    leftShoulderButton.tintColor = UIColor(hex: tintColor)
                }
                
                leftShoulderButton.translatesAutoresizingMaskIntoConstraints = false
                leftShoulderButton.titleLabel?.text = control.PVControlTitle
                leftShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                leftShoulderButton.backgroundColor = .clear
                leftShoulderButton.isSelectStart = true
                leftShoulderButton.delegate = self
                leftShoulderButton.alpha = alpha
                view.addSubview(leftShoulderButton)
                self.leftShoulderButton = leftShoulderButton
                
                self.leftShoulderButton?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
                self.leftShoulderButton?.topAnchor.constraint(equalTo: buttonGroup!.topAnchor, constant: -48).isActive = true
                self.leftShoulderButton?.widthAnchor.constraint(equalToConstant: 64).isActive = true
                self.leftShoulderButton?.heightAnchor.constraint(equalToConstant: 24).isActive = true
                
            } else if leftShoulderButton2 == nil, let title = control.PVControlTitle, title == "L2" {
                let leftShoulderButton2 = JSButton(frame: .zero)
                if let tintColor = control.PVControlTint {
                    leftShoulderButton2.tintColor = UIColor(hex: tintColor)
                }
                
                leftShoulderButton2.translatesAutoresizingMaskIntoConstraints = false
                leftShoulderButton2.titleLabel?.text = control.PVControlTitle
                leftShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                leftShoulderButton2.backgroundColor = .clear
                leftShoulderButton2.isSelectStart = true
                leftShoulderButton2.delegate = self
                leftShoulderButton2.alpha = alpha
                view.addSubview(leftShoulderButton2)
                self.leftShoulderButton2 = leftShoulderButton2
                
                self.leftShoulderButton2?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
                self.leftShoulderButton2?.bottomAnchor.constraint(equalTo: self.leftShoulderButton!.topAnchor, constant: -8).isActive = true
                self.leftShoulderButton2?.widthAnchor.constraint(equalToConstant: 64).isActive = true
                self.leftShoulderButton2?.heightAnchor.constraint(equalToConstant: 24).isActive = true
            }
            
            self.updateViewConstraints()
        }

        func layoutSelectButton(control: ControlLayoutEntry) {
            let selectButton = JSButton(frame: .zero)
            if let tintColor = control.PVControlTint {
                selectButton.tintColor = UIColor(hex: tintColor)
            }
            
            selectButton.translatesAutoresizingMaskIntoConstraints = false
            selectButton.titleLabel?.text = control.PVControlTitle
            selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
            selectButton.backgroundColor = .clear
            selectButton.isSelectStart = true
            selectButton.delegate = self
            selectButton.alpha = alpha
            view.addSubview(selectButton)
            self.selectButton = selectButton
            
            selectButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -8).isActive = true
            selectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16).isActive = true
            selectButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
            selectButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            
            /*
            let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
            let yPadding: CGFloat = safeAreaInsets.bottom + 10
            let xPadding: CGFloat = safeAreaInsets.left + 10
            //let spacing: CGFloat = 20
            var selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
            
            let selectButton = JSButton(frame: .zero)
            if let tintColor = control.PVControlTint {
                selectButton.tintColor = UIColor(hex: tintColor)
            }
                
            selectButton.translatesAutoresizingMaskIntoConstraints = false
            selectButton.titleLabel?.text = control.PVControlTitle
            selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            selectButton.backgroundColor = .clear
            selectButton.isSelectStart = true
            selectButton.delegate = self
            selectButton.alpha = alpha
            view.addSubview(selectButton)
            self.selectButton = selectButton
            

            if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
                if dPad != nil, !(dPad?.isHidden)! {
                    selectFrame = CGRect(x: (dPad?.frame.origin.x)! + (dPad?.frame.size.width)! - (controlSize.width / 3), y: (buttonGroup?.frame.maxY)! - controlSize.height, width: controlSize.width, height: controlSize.height)
                } else if dPad != nil, (dPad?.isHidden)! {
                    selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
                    if gripControl {
                        selectFrame.origin.y = (UIScreen.main.bounds.height / 2)
                    }
                }

            } else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
                selectButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -20).isActive = true
                selectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
                selectButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
                selectButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            }

            if selectFrame.maxY >= view.frame.size.height {
                selectFrame.origin.y -= (selectFrame.maxY - view.frame.size.height) + yPadding
            }*/
            
            self.updateViewConstraints()
        }

        func layoutStartButton(control: ControlLayoutEntry) {
            let startButton = JSButton(frame: .zero)
            if let tintColor = control.PVControlTint {
                startButton.tintColor = UIColor(hex: tintColor)
            }
            
            startButton.translatesAutoresizingMaskIntoConstraints = false
            startButton.titleLabel?.text = control.PVControlTitle
            startButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
            startButton.backgroundColor = .clear
            startButton.isSelectStart = true
            startButton.delegate = self
            startButton.alpha = alpha
            view.addSubview(startButton)
            self.startButton = startButton
            
            
            let leading = NSLayoutConstraint(item: startButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 8)
            let horizontal = NSLayoutConstraint(item: startButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0)
            
            // startButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 8).isActive = true
            if system.shortName == "N64" {
                view.removeConstraint(leading)
                view.addConstraint(horizontal)
            } else {
                view.removeConstraint(horizontal)
                view.addConstraint(leading)
            }
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16).isActive = true
            startButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
            startButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            
            /*
            let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
            let yPadding: CGFloat = safeAreaInsets.bottom + 10
            let xPadding: CGFloat = safeAreaInsets.right + 10
            //let spacing: CGFloat = 20
            var startFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
            
            let startButton = JSButton(frame: startFrame)
            if let tintColor = control.PVControlTint {
                startButton.tintColor = UIColor(hex: tintColor)
            }
            
            startButton.translatesAutoresizingMaskIntoConstraints = false
            startButton.titleLabel?.text = control.PVControlTitle
            startButton.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            startButton.backgroundColor = .clear
            startButton.isSelectStart = true
            startButton.delegate = self
            startButton.alpha = alpha
            view.addSubview(startButton)
            self.startButton = startButton
            

            if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
                if buttonGroup != nil, !(buttonGroup?.isHidden)! {
                    startFrame = CGRect(x: (buttonGroup?.frame.origin.x)! - controlSize.width + (controlSize.width / 3), y: (buttonGroup?.frame.maxY)! - controlSize.height, width: controlSize.width, height: controlSize.height)
                    if system.shortName == "SG" || system.shortName == "SCD" || system.shortName == "32X" || system.shortName == "SS" || system.shortName == "PCFX" {
                        startFrame.origin.x -= (controlSize.width / 2)
                    }
                } else if buttonGroup != nil, (buttonGroup?.isHidden)! {
                    startFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
                    if gripControl {
                        startFrame.origin.y = (UIScreen.main.bounds.height / 2)
                    }
                }
            } else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
                startButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 20).isActive = true
                startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
                startButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
                startButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            }

            if startFrame.maxY >= view.frame.size.height {
                startFrame.origin.y -= (startFrame.maxY - view.frame.size.height) + yPadding
            }*/
            
            self.updateViewConstraints()
        }

        func layoutLeftAnalogButton(control: ControlLayoutEntry) {
            let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
            let xPadding: CGFloat = safeAreaInsets.left + 10
            let yPadding: CGFloat = safeAreaInsets.bottom + 10
            let spacing: CGFloat = 10
            var layoutIsLandscape = false
            var leftAnalogFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)

            if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
                layoutIsLandscape = true
            }

            if !layoutIsLandscape {
                leftAnalogFrame = (selectButton?.frame.offsetBy(dx: 0, dy: (controlSize.height + spacing / 2)))!
            } else if buttonGroup?.isHidden ?? true, PVSettingsModel.shared.missingButtonsAlwaysOn {
                leftAnalogFrame = (selectButton?.frame.offsetBy(dx: 0, dy: -(controlSize.height + spacing / 2)))!
                var selectButtonFrame = selectButton?.frame
                swap(&leftAnalogFrame, &selectButtonFrame!)
                selectButton?.frame = selectButtonFrame!
            } else {
                leftAnalogFrame = (selectButton?.frame.offsetBy(dx: (controlSize.width + spacing), dy: 0))!
            }

            if let leftAnalogButton = self.leftAnalogButton {
                leftAnalogButton.frame = leftAnalogFrame
            } else {
                let leftAnalogButton = JSButton(frame: leftAnalogFrame)
                if let tintColor = control.PVControlTint {
                    leftAnalogButton.tintColor = UIColor(hex: tintColor)
                }
                self.leftAnalogButton = leftAnalogButton
                leftAnalogButton.titleLabel?.text = control.PVControlTitle
                leftAnalogButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
                leftAnalogButton.backgroundImage = UIImage(named: "button-thin")
                leftAnalogButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                leftAnalogButton.delegate = self
                leftAnalogButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
                leftAnalogButton.alpha = alpha
                leftAnalogButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
                view.addSubview(leftAnalogButton)
            }
        }

        func layoutRightAnalogButton(control: ControlLayoutEntry) {
            let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
            let xPadding: CGFloat = safeAreaInsets.left + 10
            let yPadding: CGFloat = safeAreaInsets.bottom + 10
            let spacing: CGFloat = 10
            var layoutIsLandscape = false
            var rightAnalogFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)

            if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
                layoutIsLandscape = true
            }

            if !layoutIsLandscape {
                rightAnalogFrame = (startButton?.frame.offsetBy(dx: 0, dy: (controlSize.height + spacing / 2)))!
            } else if buttonGroup?.isHidden ?? true, PVSettingsModel.shared.missingButtonsAlwaysOn {
                rightAnalogFrame = (startButton?.frame.offsetBy(dx: 0, dy: -(controlSize.height + spacing / 2)))!
                var startButtonFrame = startButton?.frame
                swap(&rightAnalogFrame, &startButtonFrame!)
                startButton?.frame = startButtonFrame!
            } else {
                rightAnalogFrame = (startButton?.frame.offsetBy(dx: -(controlSize.width + spacing), dy: 0))!
            }

            if let rightAnalogButton = self.rightAnalogButton {
                rightAnalogButton.frame = rightAnalogFrame
            } else {
                let rightAnalogButton = JSButton(frame: rightAnalogFrame)
                if let tintColor = control.PVControlTint {
                    rightAnalogButton.tintColor = UIColor(hex: tintColor)
                }
                self.rightAnalogButton = rightAnalogButton
                rightAnalogButton.titleLabel?.text = control.PVControlTitle
                rightAnalogButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
                rightAnalogButton.backgroundImage = UIImage(named: "button-thin")
                rightAnalogButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                rightAnalogButton.delegate = self
                rightAnalogButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
                rightAnalogButton.alpha = alpha
                rightAnalogButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
                view.addSubview(rightAnalogButton)
            }
        }

    #endif
}
