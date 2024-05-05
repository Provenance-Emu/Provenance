//
//  PVControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//
// Notes:
// This entire file is one ugly math hack with ordering mattering in parsing.
// TLDR; refactor this to SwiftUI or constraints

import AudioToolbox
import GameController
import PVLibrary
import PVSupport
import QuartzCore
import UIKit

protocol JSButtonDisplayer {
	var dPad: JSDPad? { get set }
	var dPad2: JSDPad? { get set }
    var joyPad: JSDPad? { get set }
    var joyPad2: JSDPad? { get set }
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
private let kDPadTopMargin: CGFloat = 48.0
private let gripControl = false

protocol StartSelectDelegate: AnyObject {
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
	var emulatorCore: ResponderType {get}
	var system: PVSystem {get set}
	var controlLayout: [ControlLayoutEntry] {get set}

	var dPad: JSDPad? {get}
	var dPad2: JSDPad? {get}
	var joyPad: JSDPad? { get }
    var joyPad2: JSDPad? { get }
	var buttonGroup: MovableButtonView? {get}
	var leftShoulderButton: JSButton? {get}
	var rightShoulderButton: JSButton? {get}
	var leftShoulderButton2: JSButton? {get}
	var rightShoulderButton2: JSButton? {get}
	var leftAnalogButton: JSButton? {get}
	var rightAnalogButton: JSButton? {get}
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

class PVControllerViewController<T: ResponderClient> : UIViewController, ControllerVC {
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

	func dPad(_: JSDPad, didRelease _: JSDPadDirection) {
	}

	func dPad(_: JSDPad, joystick _: JoystickValue) { }
    func dPad(_: JSDPad, joystick2 _: JoystickValue) { }

	typealias ResponderType = T
	var emulatorCore: ResponderType

	var system: PVSystem
	var controlLayout: [ControlLayoutEntry]

	var dPad: JSDPad?
	var dPad2: JSDPad?
	var joyPad: JSDPad?
    var joyPad2: JSDPad?
	var buttonGroup: MovableButtonView?
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

    var alwaysRightAlign = false
    var alwaysJoypadOverDpad = false
    var topRightJoyPad2 = false
    var joyPadScale:CGFloat = 0.5
    var joyPad2Scale:CGFloat = 0.5
    var lrAtBottom = false
#if os(iOS)
	private var _feedbackGenerator: AnyObject?
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
			$0.clearPauseHandler()
		}
	}

	func updateHideTouchControls() {
		if PVControllerManager.shared.hasControllers {
			if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
				hideTouchControls(for: controller)
			}
		}
	}

	var blurView : UIVisualEffectView?
	var moveLabel : UILabel?
	var inMoveMode : Bool = false {
		didSet {
			self.view.subviews.compactMap {
                if let _ = $0 as? UIView & Moveable {
                    return $0 as? UIView & Moveable ?? $0.subviews.compactMap {
                        $0 as? UIView & Moveable
                    }.first
                } else {
                    $0.isHidden = inMoveMode
                    return nil
                }
			}.forEach {
				let view = $0
                _ = inMoveMode ? view.makeMoveable() : view.makeUnmovable()
			}

			if inMoveMode {
                // Blur
				let blurEffect = UIBlurEffect(style: .light)
				let blurView = UIVisualEffectView(effect: blurEffect)
                blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				blurView.translatesAutoresizingMaskIntoConstraints = true
				blurView.frame = view.bounds
                // Vibrancy filter
				let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
				let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
				vibrancyView.translatesAutoresizingMaskIntoConstraints = false
                // Text label
				var labelFrame = view.bounds
				labelFrame.size.height = 88.0
				labelFrame.origin.y = 158.0
				let label = UILabel(frame: labelFrame)
				label.adjustsFontSizeToFitWidth = true
				label.translatesAutoresizingMaskIntoConstraints = false
				label.contentMode = .center
				label.numberOfLines = 0
                #if !os(tvOS)
                let size = UIFont.labelFontSize * 2
                label.textColor = UIColor.darkText
                #else
                let size: CGFloat = 28
                #endif
				label.font = UIFont.italicSystemFont(ofSize: size)
				label.text = "Drag buttons to Move.\nTap 2 fingers 4 times to close."
				moveLabel = label
                // Build the view heirachry
				vibrancyView.contentView.addSubview(label)
				blurView.contentView.addSubview(vibrancyView)
                // Layout constraints
                NSLayoutConstraint.activate([
                    vibrancyView.heightAnchor.constraint(equalTo: blurView.contentView.heightAnchor),
                    vibrancyView.widthAnchor.constraint(equalTo: blurView.contentView.widthAnchor),
                    vibrancyView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
                    vibrancyView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor)
                ])
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: vibrancyView.contentView.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: vibrancyView.contentView.centerYAnchor),
                    label.heightAnchor.constraint(equalTo: vibrancyView.contentView.heightAnchor),
                    label.widthAnchor.constraint(equalTo: vibrancyView.contentView.widthAnchor),
                ])
                NSLayoutConstraint.activate([
                    vibrancyView.centerXAnchor.constraint(equalTo: label.centerXAnchor),
                    vibrancyView.centerYAnchor.constraint(equalTo: label.centerYAnchor)
                ])
				self.blurView = blurView
                if let emuCore = emulatorCore as? PVEmulatorCore, emuCore.skipLayout {
                    // Skip Layout
                } else {
                    view.insertSubview(blurView, at: 0)
                }
			} else {
				self.blurView?.removeFromSuperview()
			}
			if let emuCore = emulatorCore as? PVEmulatorCore {
				emuCore.setPauseEmulation(inMoveMode)
			}
		}
	}

	public override func viewDidLoad() {
		super.viewDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.hideTouchControls(_:)), name:  Notification.Name("HideTouchControls"), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.showTouchControls(_:)), name: Notification.Name("ShowTouchControls"), object: nil)
#if os(iOS)
		feedbackGenerator = UISelectionFeedbackGenerator()
		feedbackGenerator?.prepare()
		updateHideTouchControls()

		if PVSettingsModel.shared.debugOptions.movableButtons {
			let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(PVControllerViewController.tripleTapRecognized(_:)))

			tripleTapGesture.numberOfTapsRequired = 3
			tripleTapGesture.numberOfTouchesRequired = 2
			view.addGestureRecognizer(tripleTapGesture)
		}
		if PVSettingsModel.shared.volumeHUD {
			volume.barTintColor = .white
			volume.barBackgroundColor = UIColor.white.withAlphaComponent(0.3)
			volume.animation = .slideDown
			view.addSubview(volume)
		}

		NotificationCenter.default.addObserver(volume, selector: #selector(SubtleVolume.resume), name: UIApplication.didBecomeActiveNotification, object: nil)

#endif // os(iOS)
	}

	@objc func tripleTapRecognized(_ gesture : UITapGestureRecognizer) {
		self.inMoveMode = !self.inMoveMode
	}

	// MARK: - GameController Notifications
	@objc func hideTouchControls(_: Notification?) {
#if os(iOS)
        if PVControllerManager.shared.hasControllers {
            if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                hideTouchControls(for: controller)
            }
        } else {
            allButtons.forEach {
                $0.isHidden = true
            }
            dPad2?.isHidden = true
            setupTouchControls()
        }
#endif // os(iOS)
	}
	@objc func showTouchControls(_: Notification?) {
#if os(iOS)
        var isHidden=false
        if PVControllerManager.shared.hasControllers {
            if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                hideTouchControls(for: controller)
            }
            isHidden=true
        } else {
            allButtons.forEach {
                $0.isHidden = isHidden
                $0.alpha = CGFloat(PVSettingsModel.shared.controllerOpacity)
            }
            print("Controller Alpha Set ", CGFloat(PVSettingsModel.shared.controllerOpacity))
            dPad2?.isHidden = isHidden
            setupTouchControls()
        }
#endif
	}

	@objc func controllerDidConnect(_: Notification?) {
#if os(iOS)
		if PVControllerManager.shared.hasControllers {
			if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
				hideTouchControls(for: controller)
			}
		} else {
			allButtons.forEach {
				$0.isHidden = false
                $0.alpha = CGFloat(PVSettingsModel.shared.controllerOpacity)
			}
            print("Controller Alpha Set ", CGFloat(PVSettingsModel.shared.controllerOpacity))
			dPad2?.isHidden = traitCollection.verticalSizeClass == .compact
		}
		setupTouchControls()
#endif // os(iOS)
	}

	var allButtons: [UIView] {
		return [dPad, dPad2, joyPad, joyPad2, buttonGroup, selectButton, startButton, leftShoulderButton, rightShoulderButton, leftShoulderButton2, rightShoulderButton2, zTriggerButton, leftAnalogButton, rightAnalogButton].compactMap {$0}
	}
	@objc func controllerDidDisconnect(_: Notification?) {
#if os(iOS)
		if PVControllerManager.shared.hasControllers {
			if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
				hideTouchControls(for: controller)
			}
		} else {
			allButtons.forEach {
				$0.isHidden = false
                $0.alpha = CGFloat(PVSettingsModel.shared.controllerOpacity)
			}
            print("Controller Alpha Set", CGFloat(PVSettingsModel.shared.controllerOpacity))
			dPad2?.isHidden = traitCollection.verticalSizeClass == .compact
		}
		setupTouchControls()
#endif
	}

	func vibrate() {
#if os(iOS) && !targetEnvironment(macCatalyst)
		if PVSettingsModel.shared.buttonVibration {
				// only iPhone 7 and 7 Plus support the taptic engine APIs for now.
				// everything else should fall back to the vibration motor.
            if UIDevice.hasTapticMotor {
                feedbackGenerator?.selectionChanged()
            }
//			} else if UIDevice.current.systemName == "iOS" {
// #if !targetEnvironment(macCatalyst) && !os(macOS)
//				AudioServicesStopSystemSound(Int32(kSystemSoundID_Vibrate))
//				let vibrationLength: Int = 30
//				let pattern: [Any] = [false, 0, true, vibrationLength]
//				var dictionary = [AnyHashable: Any]()
//				dictionary["VibePattern"] = pattern
//				dictionary["Intensity"] = 1
//				AudioServicesPlaySystemSoundWithVibration(Int32(kSystemSoundID_Vibrate), nil, dictionary)
// #endif
//			}
		}
#endif
	}

#if os(iOS) && !targetEnvironment(macCatalyst)
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
        if inMoveMode { return }
        PVControllerManager.shared.hasLayout=false
#if os(iOS)
		setupTouchControls()
        layoutViews()
		if PVSettingsModel.shared.volumeHUD {
			layoutVolume()
		}
		updateHideTouchControls()
#endif
	}
    
    func prelayoutSettings() {
    }

#if os(iOS)
	func layoutVolume() {
		let volumeYPadding: CGFloat = 10
		let volumeXPadding = UIScreen.main.bounds.width * 0.4 / 2

		volume.superview?.bringSubviewToFront(volume)
		volume.layer.cornerRadius = volumeHeight / 2
        volume.frame = CGRect(x: view.safeAreaInsets.left + volumeXPadding, y: view.safeAreaInsets.top + volumeYPadding, width: UIScreen.main.bounds.width - (volumeXPadding * 2) - view.safeAreaInsets.left - view.safeAreaInsets.right, height: volumeHeight)
	}
#endif

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if inMoveMode {
            inMoveMode = false
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

	@objc
	func hideTouchControls(for controller: GCController) {
		dPad?.isHidden = true
        joyPad?.isHidden = true
        joyPad2?.isHidden = true
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
		} else if controller.supportsThumbstickButtons {
			leftAnalogButton?.isHidden = true
			rightAnalogButton?.isHidden = true
		}

		setupTouchControls()
	}

		// MARK: - Controller Position And Size Editing
#if !os(iOS)
	func setupTouchControls() { }
#else
	func setupTouchControls() {
        if inMoveMode { return }
        prelayoutSettings()
        if (PVControllerManager.shared.hasLayout) { return }
        PVControllerManager.shared.hasLayout=true
		let alpha = self.alpha
        for control in controlLayout {
			let controlType: String = control.PVControlType
			let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
			let compactVertical: Bool = traitCollection.verticalSizeClass == .compact
			let controlOriginY: CGFloat = compactVertical ? view.bounds.size.height - controlSize.height : view.frame.width + (kDPadTopMargin / 2)
			if controlType == Keys.DPad {
                if let dPad = dPad, dPad.isCustomMoved { continue }
				let xPadding: CGFloat = 0 // safeAreaInsets.left
				let bottomPadding: CGFloat = 16
				let dPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
				var dPadFrame = CGRect(x: xPadding, y: dPadOriginY, width: controlSize.width, height: controlSize.height)
				if dPad2 == nil, (control.PVControlTitle == "Y") {
					dPadFrame.origin.y = dPadOriginY - controlSize.height - bottomPadding
				}
				if dPad2 == nil && (control.PVControlTitle == "Y") {
                    let dPad2 = JSDPad(frame: dPadFrame)
                    if let tintColor = control.PVControlTint {
                        dPad2.tintColor = UIColor(hex: tintColor)
                    }
                    self.dPad2 = dPad2
                    dPad2.delegate = self
                    dPad2.alpha = alpha
                    dPad2.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                    view.addSubview(dPad2)
                } else if let dPad = dPad {
                    if !dPad.isCustomMoved {
                        dPad.frame = dPadFrame
                    }
                } else {
                    let dPad = JSDPad(frame: dPadFrame)
                    if let tintColor = control.PVControlTint {
                        dPad.tintColor = UIColor(hex: tintColor)
                    }
                    self.dPad = dPad
                    dPad.delegate = self
                    dPad.alpha = alpha
                    dPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                    view.addSubview(dPad)
                }
                if let dPad = dPad {
                    dPad.transform = .identity
                }
                if let dPad2 = dPad2 {
                    dPad2.isHidden = compactVertical
                }
            } else if controlType == Keys.JoyPad, PVSettingsModel.shared.debugOptions.onscreenJoypad {
                var xPadding: CGFloat = 0 // view.safeAreaInsets.left
                let bottomPadding: CGFloat = 16
                let joyPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                var joyPadFrame = CGRect(x: xPadding, y: joyPadOriginY, width: controlSize.width, height: controlSize.height)
                xPadding += 10
                joyPadFrame.origin.y += joyPadFrame.height * joyPadScale + bottomPadding
                joyPadFrame.origin.x += xPadding
                if dPad != nil {
                    let bounds = dPad!.frame
                    joyPadFrame.origin.x = bounds.origin.x + bounds.width / 2 - controlSize.width / 2
                }
                let joyPad: JSDPad = self.joyPad ?? JSDPad.JoyPad(frame: joyPadFrame, scale:joyPadScale)
                if !joyPad.isCustomMoved {
                    joyPad.frame = joyPadFrame
                }
                
				if let tintColor = control.PVControlTint {
					joyPad.tintColor = UIColor(hex: tintColor)
				}
				self.joyPad = joyPad
				joyPad.delegate = self
				joyPad.alpha = alpha
				joyPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
				view.addSubview(joyPad)
			} else if controlType == Keys.JoyPad2, PVSettingsModel.shared.debugOptions.onscreenJoypad {
                var xPadding: CGFloat = 0 // view.safeAreaInsets.left
                let bottomPadding: CGFloat = 16
                let joyPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                var joyPad2Frame = CGRect(x: view.frame.width - controlSize.width - xPadding, y: joyPadOriginY, width: controlSize.width, height: controlSize.height)
                xPadding += 10
                joyPad2Frame.origin.x -= xPadding
                let joyPad2: JSDPad = self.joyPad2 ?? JSDPad.JoyPad2(frame: joyPad2Frame, scale:joyPad2Scale)
                if !joyPad2.isCustomMoved {
                    joyPad2.frame = joyPad2Frame
                }
                self.joyPad2 = joyPad2
                joyPad2.delegate = self
                joyPad2.alpha = alpha
                joyPad2.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                view.addSubview(joyPad2)
            } else if controlType == Keys.ButtonGroup {
                let xPadding: CGFloat = view.safeAreaInsets.right + 5
				let bottomPadding: CGFloat = 16
				let buttonsOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
				let buttonsFrame = CGRect(x: view.bounds.maxX - controlSize.width - xPadding, y: buttonsOriginY, width: controlSize.width, height: controlSize.height)
				if let buttonGroup = self.buttonGroup {
                    if buttonGroup.isCustomMoved { continue }
					if let buttonGroup = buttonGroup as? PVButtonGroupOverlayView, buttonGroup.isCustomMoved {
					} else {
						buttonGroup.frame = buttonsFrame
					}
				} else {
					let buttonGroup = MovableButtonView(frame: buttonsFrame)
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
			} else if controlType == Keys.RightShoulderButton2 {
                layoutRightShoulderButtons(control: control)
            } else if controlType == Keys.ZTriggerButton {
				layoutZTriggerButton(control: control)
			} else if controlType == Keys.LeftShoulderButton {
				layoutLeftShoulderButtons(control: control)
			} else if controlType == Keys.LeftShoulderButton2 {
                layoutLeftShoulderButtons(control: control)
            } else if controlType == Keys.SelectButton {
				layoutSelectButton(control: control)
			} else if controlType == Keys.StartButton {
				layoutStartButton(control: control)
			} else if controlType == Keys.LeftAnalogButton {
				layoutLeftAnalogButton(control: control)
			} else if controlType == Keys.RightAnalogButton {
				layoutRightAnalogButton(control: control)
			}
		}
        // Fix overlapping buttons on old/smaller iPhones
        if self.joyPad == nil && super.view.bounds.size.width < super.view.bounds.size.height {
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
        adjustJoystick()
        if let joyPad2 = joyPad2 {
            self.view.bringSubviewToFront(joyPad2)
        }
		if let dPad2 = dPad2 {
			self.view.bringSubviewToFront(dPad2)
		}
        if let buttonGroup = buttonGroup {
            self.view.bringSubviewToFront(buttonGroup)
        }
        if let joyPad = joyPad {
            self.view.bringSubviewToFront(joyPad)
        }
        if let dPad = dPad {
            self.view.bringSubviewToFront(dPad)
        }
        if let startButton = startButton {
            self.view.bringSubviewToFront(startButton)
        }
        if let selectButton = selectButton {
            self.view.bringSubviewToFront(selectButton)
        }
        if let leftShoulderButton = leftShoulderButton {
            self.view.bringSubviewToFront(leftShoulderButton)
        }
        if let rightShoulderButton =  rightShoulderButton{
            self.view.bringSubviewToFront(rightShoulderButton)
        }
	}
#endif // os(iOS)

#if os(iOS)
	func layoutRightShoulderButtons(control: ControlLayoutEntry) {
		let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.right + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
		var rightShoulderFrame: CGRect!
		if buttonGroup != nil, !(buttonGroup?.isHidden)! {
			rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: (buttonGroup?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if dPad != nil, !(dPad?.isHidden)! {
                rightShoulderFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
			if PVSettingsModel.shared.allRightShoulders, (system.shortName == "GBA" || system.shortName == "VB") {
				rightShoulderFrame.origin.y += ((buttonGroup?.frame.height)! / 2 - controlSize.height)
			}
		} else {
			rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.size.height - (controlSize.height * 2) - yPadding, width: controlSize.width, height: controlSize.height)
		}
        rightShoulderFrame.origin.y -= controlSize.height
        if leftShoulderButton != nil {
            rightShoulderFrame.origin.y = (leftShoulderButton?.frame)!.origin.y
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
		} else {
            if let rightShoulderButton = rightShoulderButton {
                if rightShoulderButton.isCustomMoved { return }
                rightShoulderButton.frame = rightShoulderFrame
            }
        }
        if rightShoulderButton2 == nil, (control.PVControlType == Keys.RightShoulderButton2 || control.PVControlTitle  == "R2") {
            var rightShoulderFrame2 = rightShoulderFrame
            rightShoulderFrame2!.origin.y -= controlSize.height
            let rightShoulderButton2 = JSButton(frame: rightShoulderFrame2!)
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
            if let rightShoulderButton2 = rightShoulderButton2 {
                if rightShoulderButton2.isCustomMoved { return }
                var rightShoulderFrame2 = rightShoulderFrame
                rightShoulderFrame2!.origin.y -= controlSize.height
				rightShoulderButton2.frame = rightShoulderFrame2!
			}
		}
	}

	func layoutZTriggerButton(control: ControlLayoutEntry) {
		let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.right + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
		var zTriggerFrame: CGRect!

		if rightShoulderButton != nil {
			zTriggerFrame = CGRect(x: (rightShoulderButton?.frame.minX)! - controlSize.width, y: (rightShoulderButton?.frame.minY)!, width: controlSize.width, height: controlSize.height)
		} else {
			let x: CGFloat = view.frame.size.width - (controlSize.width * 2) - xPadding
			let y: CGFloat = view.frame.size.height - (controlSize.height * 2) - yPadding
			zTriggerFrame = CGRect(x: x, y: y, width: controlSize.width, height: controlSize.height)
		}

		if let zTriggerButton = self.zTriggerButton {
			if !zTriggerButton.isCustomMoved {
				zTriggerButton.frame = zTriggerFrame
			}
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
		let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
		var leftShoulderFrame: CGRect!
		if dPad != nil {
            leftShoulderFrame = CGRect(x: xPadding, y: (dPad?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if buttonGroup != nil, !(buttonGroup?.isHidden)! {
                leftShoulderFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
		} else {
			leftShoulderFrame = CGRect(x: xPadding, y: view.frame.size.height - (controlSize.height * 10), width: controlSize.width, height: controlSize.height)
		}
		if PVSettingsModel.shared.allRightShoulders || alwaysRightAlign {
			if zTriggerButton != nil {
				leftShoulderFrame.origin.x = (zTriggerButton?.frame.origin.x)! - controlSize.width
			} else if zTriggerButton == nil, rightShoulderButton != nil {
				leftShoulderFrame.origin.x = (rightShoulderButton?.frame.origin.x)! - controlSize.width
				if system.shortName == "GBA" || system.shortName == "VB" {
					leftShoulderFrame.origin.y += ((buttonGroup?.frame.height)! / 2 - controlSize.height)
				}
			}
		}
        leftShoulderFrame.origin.y -= controlSize.height
		if leftShoulderButton == nil {
			let leftShoulderButton = JSButton(frame: leftShoulderFrame)
			self.leftShoulderButton = leftShoulderButton
			leftShoulderButton.titleLabel?.text = control.PVControlTitle
			leftShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 8)
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
        } else {
            if let leftShoulderButton = leftShoulderButton, !leftShoulderButton.isCustomMoved {
                leftShoulderButton.frame = leftShoulderFrame
            }
        }
        if leftShoulderButton2 == nil, (control.PVControlType == Keys.LeftShoulderButton2 || control.PVControlTitle  == "L2") {
            var leftShoulderFrame2 = leftShoulderFrame;
            leftShoulderFrame2!.origin.y -= controlSize.height
            let leftShoulderButton2 = JSButton(frame: leftShoulderFrame2!)
			if let tintColor = control.PVControlTint {
				leftShoulderButton2.tintColor = UIColor(hex: tintColor)
			}
			self.leftShoulderButton2 = leftShoulderButton2
			leftShoulderButton2.titleLabel?.text = control.PVControlTitle
			leftShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 8)
			leftShoulderButton2.backgroundImage = UIImage(named: "button-thin")
			leftShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed")
			leftShoulderButton2.delegate = self
			leftShoulderButton2.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
			leftShoulderButton2.alpha = alpha
			leftShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
			view.addSubview(leftShoulderButton2)

        } else {
			if let leftShoulderButton2 = leftShoulderButton2, !leftShoulderButton2.isCustomMoved {
				leftShoulderFrame.origin.y -= leftShoulderButton!.frame.size.height
				leftShoulderButton2.frame = leftShoulderFrame
			}
		}
	}
#endif

	#if os(iOS)
	func layoutSelectButton( control: ControlLayoutEntry ) {
		let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let yPadding: CGFloat = view.safeAreaInsets.bottom
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
		let spacing: CGFloat = 20
		var selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)

		if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
			if dPad != nil, !(dPad?.isHidden)! {
				selectFrame = CGRect(x: (dPad?.frame.origin.x)! + (dPad?.frame.size.width)! - (controlSize.width / 3), y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
			} else if dPad != nil, (dPad?.isHidden)! {
				selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
				if gripControl {
					selectFrame.origin.y = (UIScreen.main.bounds.height / 2)
				}
			}
		} else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
			let x: CGFloat = (view.frame.size.width / 2) - controlSize.width - (spacing / 2)
			let y: CGFloat = view.frame.height - yPadding - controlSize.height
			selectFrame = CGRect(x: x, y: y, width: controlSize.width, height: controlSize.height)
		}

		if selectFrame.maxY >= view.frame.size.height {
			selectFrame.origin.y -= (selectFrame.maxY - view.frame.size.height) + yPadding
		}

        	if (view.frame.width > view.frame.height) {
			selectFrame.origin.x = (view.frame.size.width / 2) - controlSize.width - (spacing / 2)
		}
		if alwaysRightAlign {
 			selectFrame.origin.x += 80
 			if let dPad = dPad {
 				selectFrame.origin.x = dPad.frame.maxX + (xPadding * 2)
 			}
 		}
        
		if let selectButton = self.selectButton {
			if !selectButton.isCustomMoved {
				selectButton.frame = selectFrame
			}
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
		let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let yPadding: CGFloat = view.safeAreaInsets.bottom
		let spacing: CGFloat = 20
		var startFrame = CGRect(x: (view.frame.size.width / 2) + controlSize.width + (spacing / 2),
								y: view.frame.height - yPadding - controlSize.height,
								width: controlSize.width,
								height: controlSize.height)

		if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            if let selectButton = selectButton {
                startFrame = CGRect(x: selectButton.frame.maxX + spacing,
                                    y: selectButton.frame.origin.y,
                                    width: controlSize.width,
                                    height: controlSize.height)
            } else if let buttonGroup = buttonGroup {
				if buttonGroup.isHidden {
					startFrame = CGRect(x: (view.frame.size.width / 2) + controlSize.width + (spacing / 2), y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
					if gripControl {
						startFrame.origin.y = (UIScreen.main.bounds.height / 2)
					}
				} else {
					startFrame = CGRect(x: buttonGroup.frame.origin.x - controlSize.width + (controlSize.width / 3),
										y: view.frame.height - yPadding - controlSize.height,
										width: controlSize.width,
										height: controlSize.height)
					if ["SG", "SCD", "32X", "SS", "PCFX"].contains(system.shortName.uppercased()) {
						startFrame.origin.x -= (controlSize.width / 2)
					}
				}
			}
		} else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
			startFrame = CGRect(x: (view.frame.size.width / 2) + controlSize.width + (spacing / 2),
                                y: view.frame.height - yPadding - controlSize.height,
                                width: controlSize.width,
                                height: controlSize.height)
			if selectButton != nil {
				startFrame.origin.x = (selectButton?.frame.maxX)! + spacing
			}
		}
		if startFrame.maxY >= view.frame.size.height {
			startFrame.origin.y -= (startFrame.maxY - view.frame.size.height) + yPadding
		}
		if let startButton = self.startButton {
			if !startButton.isCustomMoved {
				startButton.frame = startFrame
			}
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

	func layoutLeftAnalogButton(control: ControlLayoutEntry) {
		let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
		let spacing: CGFloat = 10
		var layoutIsLandscape = false
		var leftAnalogFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
		if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
			layoutIsLandscape = true
		}
        
		if !layoutIsLandscape {
			if let selectButton = selectButton {
				leftAnalogFrame = selectButton.frame.offsetBy(dx: 0, dy: (controlSize.height + spacing / 2))
			}
		} else if buttonGroup?.isHidden ?? true, PVSettingsModel.shared.missingButtonsAlwaysOn {
			if let selectButton = selectButton {
				leftAnalogFrame = selectButton.frame.offsetBy(dx: 0, dy: -(controlSize.height + spacing / 2))
				var selectButtonFrame = selectButton.frame
				swap(&leftAnalogFrame, &selectButtonFrame)
				selectButton.frame = selectButtonFrame
			}
		} else {
			leftAnalogFrame = (selectButton?.frame.offsetBy(dx: (controlSize.width + spacing), dy: 0))!
		}
        if dPad != nil, !(dPad?.isHidden)! {
            leftAnalogFrame = CGRect(x: xPadding, y: (dPad?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if buttonGroup != nil, !(buttonGroup?.isHidden)! {
                leftAnalogFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
        }
        if PVSettingsModel.shared.allRightShoulders || alwaysRightAlign {
            if zTriggerButton != nil {
                leftAnalogFrame.origin.x = (zTriggerButton?.frame.origin.x)! - controlSize.width
            } else if zTriggerButton == nil, rightShoulderButton != nil {
                leftAnalogFrame.origin.x = (rightShoulderButton?.frame.origin.x)! - controlSize.width
            }
        }
        leftAnalogFrame.origin.y -= controlSize.height * 3
        if let leftAnalogButton = self.leftAnalogButton {
			if !leftAnalogButton.isCustomMoved {
				leftAnalogButton.frame = leftAnalogFrame
			}
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
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
		let spacing: CGFloat = 10
		var layoutIsLandscape = false
		var rightAnalogFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
		if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
			layoutIsLandscape = true
		}
		if !layoutIsLandscape {
			rightAnalogFrame = (startButton?.frame.offsetBy(dx: 0, dy: (controlSize.height + spacing / 2)))!
		} else if buttonGroup?.isHidden ?? true, PVSettingsModel.shared.missingButtonsAlwaysOn {
			if let startButton = startButton {
				rightAnalogFrame = startButton.frame.offsetBy(dx: 0, dy: -(controlSize.height + spacing / 2))
				var startButtonFrame = startButton.frame
				swap(&rightAnalogFrame, &startButtonFrame)
				startButton.frame = startButtonFrame
			} else {
				ELOG("startButton is nil")
			}
		} else {
			rightAnalogFrame = (startButton?.frame.offsetBy(dx: -(controlSize.width + spacing), dy: 0))!
		}
        if buttonGroup != nil, !(buttonGroup?.isHidden)! {
            rightAnalogFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: (buttonGroup?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if dPad != nil, !(dPad?.isHidden)! {
                rightAnalogFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
        }
        rightAnalogFrame.origin.y -= controlSize.height * 3
        if leftShoulderButton != nil, !(leftShoulderButton?.isHidden)! {
            rightAnalogFrame.origin.y = (leftShoulderButton?.frame)!.origin.y - controlSize.height * 2
        }
		if let rightAnalogButton = self.rightAnalogButton {
			if !rightAnalogButton.isCustomMoved {
				rightAnalogButton.frame = rightAnalogFrame
			}
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

    fileprivate func adjustJoystick() {
        guard  let joyPad = joyPad else {
            return
        }

//        guard PVSettingsModel.shared.debugOptions.onscreenJoypad else {
//            DLOG("onscreenJoypad false, hiding")
//            joyPad.isHidden = true
//            return
//        }
//
//        if PVControllerManager.shared.isKeyboardConnected && !PVSettingsModel.shared.debugOptions.onscreenJoypadWithKeyboard {
//            DLOG("`isKeyboardConnected` true and `onscreenJoypadWithKeyboard` false, hiding")
//            joyPad.isHidden = true
//            return
//        }
//
//        joyPad.isHidden = false
        guard let dPad = dPad, !dPad.isCustomMoved, !joyPad.isCustomMoved else {
            return
        }
        var joyPadFrame = joyPad.frame
        var dPadFrame = dPad.frame
        var minY = dPad.frame.minY
        var minX = dPad.frame.minX
        let spacing:CGFloat = 10
        let joystickOverDPad = alwaysJoypadOverDpad
        let overlap = (dPadFrame.maxY + joyPadFrame.height) - view.frame.height
        if overlap > 1 {
            dPadFrame.origin.y -= overlap
        }
        joyPadFrame.origin.y = dPadFrame.maxY
        // landscape joystick settings
        if (view.frame.width > view.frame.height) {
            if buttonGroup != nil {
                if joystickOverDPad {
                    dPadFrame.origin.y = view.frame.height - dPadFrame.size.height
                    joyPadFrame.origin.y = view.frame.height - dPadFrame.size.height - joyPadFrame.size.height * joyPadScale
                    minY = joyPadFrame.origin.y
                } else {
                    // Place DPad little more than halfway above JoyPad at the bottom
                    dPadFrame.origin.y = view.frame.height - dPadFrame.size.height - joyPadFrame.size.height * joyPadScale / 2 - spacing * 6
                    minY = dPadFrame.origin.y
                    if buttonGroup != nil, let buttonGroup = buttonGroup {
                        var buttonGroupFrame = buttonGroup.frame
                        // Place Button at the Bottom
                        buttonGroupFrame.origin.y = view.frame.height - buttonGroupFrame.size.height
                        // If Buttons are below DPad, Align with Dpad
                        if (buttonGroupFrame.origin.y >= dPadFrame.origin.y) {
                            buttonGroupFrame.origin.y = dPadFrame.origin.y
                        } else {
                            // If DPads are below Buttons, Align with Buttons
                            dPadFrame.origin.y = buttonGroupFrame.origin.y
                            joyPadFrame.origin.y = dPadFrame.maxY + spacing
                            minY = buttonGroupFrame.origin.y
                        }
                        if !(buttonGroup.isCustomMoved) { buttonGroup.frame = buttonGroupFrame }
                    }
                }
            }
            // Align Joypad Little more than halfway of Dpad Horizontally
            joyPadFrame.origin.x = dPad.frame.maxX - joyPadFrame.size.width * joyPadScale + spacing * 6
            joyPadFrame.origin.y -= spacing * 2
        } else {
            // portrait joystick settings
            if joystickOverDPad {
                joyPadFrame.origin.y = (buttonGroup?.frame.minY)! - joyPadFrame.size.height
                joyPadFrame.origin.x = dPad.frame.origin.x + spacing * 3
                minY = joyPadFrame.origin.y
            } else {
                joyPadFrame.origin.y = view.frame.height - joyPadFrame.size.height
                // if active control at bottom, provide smaller spacing
                if (lrAtBottom) {
                    joyPadFrame.origin.y -= spacing * 3
                } else {
                    // large bottom space
                    joyPadFrame.origin.y -= spacing * 10
                }
                // Center Align JoyPad w/ DPad
                joyPadFrame.origin.x = dPad.frame.origin.x + dPadFrame.size.width / 2 - (joyPadFrame.size.width) / 2
                // Place DPad 1 spacing above JoyPad
                dPadFrame.origin.y =  joyPadFrame.origin.y - dPadFrame.size.height - spacing
                // Store TopMost Y Coordinate to place rest of the buttons
                minY = dPadFrame.origin.y
                if buttonGroup != nil, let buttonGroup = buttonGroup {
                    var buttonGroupFrame = buttonGroup.frame
                    // Place Buttons 1 spacing above JoyPad
                    buttonGroupFrame.origin.y = joyPadFrame.origin.y - buttonGroupFrame.size.height - spacing
                    minY = buttonGroupFrame.origin.y < dPadFrame.origin.y ? buttonGroupFrame.origin.y : dPadFrame.origin.y
                    // If Buttons are above Dpad, move up Dpad to Button Position
                    if (buttonGroupFrame.origin.y <= dPadFrame.origin.y) {
                        dPadFrame.origin.y = buttonGroupFrame.origin.y
                        // Place JoyPad 2 spacing below DPad that was aligned with buttons
                        joyPadFrame.origin.y = dPadFrame.maxY + spacing * 2
                        minY = buttonGroupFrame.origin.y
                    }
                    if !(buttonGroup.isCustomMoved) { buttonGroup.frame = buttonGroupFrame }
                }
            }
        }
        // Keep layout the same for rest of the buttons
        if !dPad.isCustomMoved { dPad.frame = dPadFrame }
        if !joyPad.isCustomMoved { joyPad.frame = joyPadFrame }
        if leftShoulderButton != nil && !(leftShoulderButton?.isCustomMoved)! {
            if (lrAtBottom) {
                minY = view.frame.height
            }
            leftShoulderButton?.frame.origin.y = minY - (leftShoulderButton?.frame.size.height)!
            minX = (leftShoulderButton?.frame.origin.x)!
        }
        if leftShoulderButton2 != nil && !(leftShoulderButton2?.isCustomMoved)! {
            leftShoulderButton2?.frame.origin.y = minY - (leftShoulderButton?.frame.size.height)! - (leftShoulderButton2?.frame.size.height)!
            leftShoulderButton2?.frame.origin.x = minX
        }
        if leftAnalogButton != nil && !(leftAnalogButton?.isCustomMoved)! {
            leftAnalogButton?.frame.origin.y = minY  - (leftShoulderButton?.frame.size.height)! - (leftShoulderButton2?.frame.size.height)! - (leftAnalogButton?.frame.size.height)!
            leftAnalogButton?.frame.origin.x = minX
        }
        if selectButton != nil && !(selectButton?.isCustomMoved)! {
            selectButton?.frame.origin.y = view.frame.size.height - (selectButton?.frame.size.height)! * 2
            selectButton?.frame.origin.x = minX
        }
        if rightShoulderButton != nil && !(rightShoulderButton?.isCustomMoved)! {
            if (lrAtBottom) {
                minY = view.frame.height
            }
            rightShoulderButton?.frame.origin.y = minY - (rightShoulderButton?.frame.size.height)!
            minX = (rightShoulderButton?.frame.origin.x)!
        }
        if rightShoulderButton2 != nil && !(rightShoulderButton2?.isCustomMoved)! {
            rightShoulderButton2?.frame.origin.y = minY - (rightShoulderButton?.frame.size.height)! - (rightShoulderButton2?.frame.size.height)!
            rightShoulderButton2?.frame.origin.x = minX
        }
        if rightAnalogButton != nil && !(rightAnalogButton?.isCustomMoved)! {
            rightAnalogButton?.frame.origin.y = minY - (rightShoulderButton?.frame.size.height)! - (rightShoulderButton2?.frame.size.height)! - (rightAnalogButton?.frame.size.height)!
            rightAnalogButton?.frame.origin.x = minX
        }
        if startButton != nil && !(startButton?.isCustomMoved)! {
            startButton?.frame.origin.y = view.frame.size.height - (startButton?.frame.size.height)! * 2
            if (selectButton == nil) {
                if (lrAtBottom) {
                    startButton?.frame.origin.y = view.frame.size.height - (startButton?.frame.size.height)!
                }
                startButton?.frame.origin.x = view.frame.size.width / 2 - (startButton?.frame.size.width)! / 2
            } else {
                startButton?.frame.origin.x = view.frame.size.width - (startButton?.frame.size.width)!
            }
        }
        guard let joyPad2 = joyPad2, !joyPad2.isCustomMoved else {
            return
        }
        var joyPad2Frame = joyPad2.frame
        if buttonGroup != nil {
            let xPadding = CGFloat(10);
            joyPad2Frame = CGRect(x: view.frame.size.width -  joyPad2.frame.width - xPadding, y: (buttonGroup?.frame.minY)!, width:  joyPad2.frame.width, height:  joyPad2.frame.height)
            joyPad2Frame.origin.y = joyPad.frame.origin.y
            if (view.frame.width > view.frame.height) {
                if joystickOverDPad {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! - joyPad2Frame.size.width * joyPad2Scale
                } else {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! - joyPad2Frame.size.width * joyPad2Scale - spacing * 6
                    if buttonGroup != nil, let buttonGroup = buttonGroup {
                        var buttonGroupFrame = buttonGroup.frame
                        buttonGroupFrame.origin.y = view.frame.height - buttonGroupFrame.size.height - joyPad2Frame.size.height * joyPad2Scale / 2 - spacing * 6
                        if !(buttonGroup.isCustomMoved) { buttonGroup.frame = buttonGroupFrame }
                    }
                }
                if (topRightJoyPad2) {
                    joyPad2Frame.origin.x = view.frame.width - joyPad2Frame.size.width
                    var minY:CGFloat = (buttonGroup?.frame.minY)!;
                    if (rightShoulderButton != nil) { minY = (rightShoulderButton?.frame.minY)! }
                    if (rightShoulderButton2 != nil) { minY = (rightShoulderButton2?.frame.minY)! }
                    if (rightAnalogButton != nil) { minY = (rightAnalogButton?.frame.minY)! }
                    joyPad2Frame.origin.y = minY - joyPad2Frame.size.height + spacing * 3
                }
            } else {
                if joystickOverDPad {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! + (buttonGroup?.frame.size.width)!/2 - (joyPad2Frame.size.width * joyPad2Scale) - spacing
                } else {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! + (buttonGroup?.frame.size.width)!/2 - (joyPad2Frame.size.width * joyPad2Scale)
                }
            }
        }
        if !joyPad2.isCustomMoved { joyPad2.frame = joyPad2Frame }
    }
	#endif // os(iOS)
}
