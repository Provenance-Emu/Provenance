//
//  PVControllerViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/15/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

extension PVControllerViewController {
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    open override func didMove(toParentViewController parent: UIViewController?) {
        super.didMove(toParentViewController: parent)
        if let s = view.superview {
            view.frame = s.bounds
        }
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupTouchControls()
        if PVControllerManager.shared().hasControllers {
            if let p1 = PVControllerManager.shared().player1 {
                hideTouchControls(for: p1)
            }
            
            if let p2 = PVControllerManager.shared().player2 {
                hideTouchControls(for: p2)
            }
        }
    }
}

public extension PVControllerViewController {
    
    @objc
    func hideTouchControls(for controller: GCController) {
        dPad?.isHidden = true
        buttonGroup?.isHidden = true
        leftShoulderButton?.isHidden = true
        rightShoulderButton?.isHidden = true
        leftShoulderButton2?.isHidden = true
        rightShoulderButton2?.isHidden = true
        
            //Game Boy, Game Color, and Game Boy Advance can map Start and Select on a Standard Gamepad, so it's safe to hide them
        let useStandardGamepad : [SystemIdentifier] = [.GB, .GBC, .GBA]
        let useStandardGamepadString = useStandardGamepad.map { $0.rawValue }
        
        if (controller.extendedGamepad != nil) || useStandardGamepadString.contains(systemIdentifier) {
            startButton?.isHidden = true
            selectButton?.isHidden = true
        }
    }
    
    // MARK: - Controller Position And Size Editing
    func setupTouchControls() {
        #if os(iOS)
            
            var safeAreaInsets = UIEdgeInsets.zero
            if #available(iOS 11.0, *) {
                safeAreaInsets = view.safeAreaInsets
            }
            
            typealias Keys = SystemDictionaryKeys.ControllerLayoutKeys
            
            let alpha: CGFloat = PVSettingsModel.sharedInstance().controllerOpacity
            for control: [String: Any] in controlLayout {
                let controlType = control[Keys.ControlType] as? String
                let controlSize: CGSize = CGSizeFromString(control[Keys.ControlSize] as! String)
                let compactVertical: Bool = traitCollection.verticalSizeClass == .compact
                let kDPadTopMargin: CGFloat = 96.0
                let controlOriginY: CGFloat = compactVertical ? view.bounds.size.height - controlSize.height : view.frame.width + (kDPadTopMargin / 2)
                if (controlType == Keys.DPad) {
                    let xPadding: CGFloat = safeAreaInsets.left + 5
                    let bottomPadding: CGFloat = 16
                    let dPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                    var dPadFrame = CGRect(x: xPadding, y: dPadOriginY, width: controlSize.width, height: controlSize.height)

                    if dPad2 == nil && (control[Keys.ControlTitle] as? String == "Y") {
                        dPadFrame.origin.y = dPadOriginY - controlSize.height - bottomPadding
                        let dPad2 = JSDPad(frame: dPadFrame)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            dPad2.tintColor = UIColor(hex: tintColor)
                        }
                        self.dPad2 = dPad2
                        dPad2.delegate = self
                        dPad2.alpha = alpha
                        dPad2.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                        view.addSubview(dPad2)
                    } else if dPad == nil {
                        let dPad = JSDPad(frame: dPadFrame)
                        self.dPad = dPad
                        dPad.delegate = self
                        dPad.alpha = alpha
                        dPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                        view.addSubview(dPad)
                    } else {
                        dPad?.frame = dPadFrame
                    }
                    dPad2?.isHidden = compactVertical
                }
                else if (controlType == Keys.ButtonGroup) {
                    let xPadding: CGFloat = safeAreaInsets.right + 5
                    let bottomPadding: CGFloat = 16
                    let buttonsOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                    let buttonsFrame = CGRect(x: view.bounds.maxX - controlSize.width - xPadding, y: buttonsOriginY, width: controlSize.width, height: controlSize.height)
                    
                    if let buttonGroup = self.buttonGroup {
                        buttonGroup.frame = buttonsFrame
                    }
                    else {
                        let buttonGroup = UIView(frame: buttonsFrame)
                        self.buttonGroup = buttonGroup
                        buttonGroup.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
                        
                        var buttons = [JSButton]()
                        
                        let groupedButtons = control[Keys.GroupedButtons] as? [[String:Any]]
                        groupedButtons?.forEach { groupedButton in
                            let buttonFrame: CGRect = CGRectFromString(groupedButton[Keys.ControlFrame] as! String)
                            let button = JSButton(frame: buttonFrame)
                            button.titleLabel?.text = groupedButton[Keys.ControlTitle] as? String
                            
                            if let tintColor = groupedButton[Keys.ControlTint] as? String {
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
                }
                else if (controlType == Keys.LeftShoulderButton) {
                    let xPadding: CGFloat = safeAreaInsets.left + 10
                    let yPadding: CGFloat = safeAreaInsets.top + 10
                    var leftShoulderFrame = CGRect(x: xPadding, y: yPadding, width: controlSize.width, height: controlSize.height)
                    
                    if leftShoulderButton == nil {
                        let leftShoulderButton = JSButton(frame: leftShoulderFrame)
                        self.leftShoulderButton = leftShoulderButton
                        leftShoulderButton.titleLabel?.text = control[Keys.ControlTitle] as? String
                        leftShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 8)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            leftShoulderButton.tintColor = UIColor(hex: tintColor)
                        }
                        leftShoulderButton.backgroundImage = UIImage(named: "button-thin")
                        leftShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        leftShoulderButton.delegate = self
                        leftShoulderButton.titleEdgeInsets = UIEdgeInsetsMake(2, 2, 4, 2)
                        leftShoulderButton.alpha = alpha
                        leftShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
                        view.addSubview(leftShoulderButton)
                    } else if leftShoulderButton2 == nil, let title = control[Keys.ControlTitle] as? String, title == "L2" {
                        leftShoulderFrame.origin.y += leftShoulderButton!.frame.size.height + 20
                        
                        let leftShoulderButton2 = JSButton(frame: leftShoulderFrame)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            leftShoulderButton2.tintColor = UIColor(hex: tintColor)
                        }
                        self.leftShoulderButton2 = leftShoulderButton2
                        leftShoulderButton2.titleLabel?.text = control[Keys.ControlTitle] as? String
                        leftShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 8)
                        leftShoulderButton2.backgroundImage = UIImage(named: "button-thin")
                        leftShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        leftShoulderButton2.delegate = self
                        leftShoulderButton2.titleEdgeInsets = UIEdgeInsetsMake(2, 2, 4, 2)
                        leftShoulderButton2.alpha = alpha
                        leftShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
                        view.addSubview(leftShoulderButton2)

                    } else {
                        leftShoulderButton?.frame = leftShoulderFrame
                        leftShoulderFrame.origin.y += leftShoulderButton!.frame.size.height + 20
                        leftShoulderButton2?.frame = leftShoulderFrame
                    }
                }
                else if (controlType == Keys.RightShoulderButton) {
                    let xPadding: CGFloat = safeAreaInsets.right + 10
                    let yPadding: CGFloat = safeAreaInsets.top + 10
                    var rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: yPadding, width: controlSize.width, height: controlSize.height)

                    if rightShoulderButton == nil {
                        let rightShoulderButton = JSButton(frame: rightShoulderFrame)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            rightShoulderButton.tintColor = UIColor(hex: tintColor)
                        }
                        self.rightShoulderButton = rightShoulderButton
                        rightShoulderButton.titleLabel?.text = control[Keys.ControlTitle] as? String
                        rightShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 8)
                        rightShoulderButton.backgroundImage = UIImage(named: "button-thin")
                        rightShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        rightShoulderButton.delegate = self
                        rightShoulderButton.titleEdgeInsets = UIEdgeInsetsMake(2, 2, 4, 2)
                        rightShoulderButton.alpha = alpha
                        rightShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
                        view.addSubview(rightShoulderButton)
                    } else if rightShoulderButton2 == nil ,let title = control[Keys.ControlTitle] as? String, title == "R2"{
                        rightShoulderFrame.origin.y += leftShoulderButton!.frame.size.height + 20
                        
                        let rightShoulderButton2 = JSButton(frame: rightShoulderFrame)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            rightShoulderButton2.tintColor = UIColor(hex: tintColor)
                        }
                        self.rightShoulderButton2 = rightShoulderButton2
                        rightShoulderButton2.titleLabel?.text = control[Keys.ControlTitle] as? String
                        rightShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 8)
                        rightShoulderButton2.backgroundImage = UIImage(named: "button-thin")
                        rightShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        rightShoulderButton2.delegate = self
                        rightShoulderButton2.titleEdgeInsets = UIEdgeInsetsMake(2, 2, 4, 2)
                        rightShoulderButton2.alpha = alpha
                        rightShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
                        view.addSubview(rightShoulderButton2)
                    } else {
                        rightShoulderButton?.frame = rightShoulderFrame
                        rightShoulderFrame.origin.y += rightShoulderButton!.frame.size.height + 20
                        rightShoulderButton2?.frame = rightShoulderFrame
                    }
                }
                else if (controlType == Keys.StartButton) {
                    let yPadding: CGFloat = safeAreaInsets.bottom + 10
                    let xPadding: CGFloat = safeAreaInsets.right + 10
                    let xSpacing: CGFloat = 20
                    var startFrame: CGRect
                    if UIDevice.current.orientation.isLandscape {
                        if (buttonGroup != nil) {
                            startFrame = CGRect(x: (buttonGroup?.frame.origin.x)! - controlSize.width + (controlSize.width / 2), y: (buttonGroup?.frame.origin.y)! + (buttonGroup?.frame.height)! - controlSize.height, width: controlSize.width, height: controlSize.height)
                        } else {
                            startFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
                        }

                    } else {
                        startFrame = CGRect(x: (view.frame.size.width / 2) + (xSpacing / 2), y: (buttonGroup?.frame.origin.y)! + (buttonGroup?.frame.height)! + yPadding, width: controlSize.width, height: controlSize.height)
                    }
                    if let startButton = self.startButton {
                        startButton.frame = startFrame
                    } else {
                        let startButton = JSButton(frame: startFrame)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            startButton.tintColor = UIColor(hex: tintColor)
                        }
                        self.startButton = startButton
                        //startButton.titleLabel?.text = control[Keys.ControlTitle] as? String
                        startButton.backgroundImage = UIImage(named: "button-thin")
                        startButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        startButton.delegate = self
                        startButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 4, 0)
                        startButton.alpha = alpha
                        startButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
                        view.addSubview(startButton)
                    }
                }
                else if (controlType == Keys.SelectButton) {
                    let yPadding: CGFloat = safeAreaInsets.bottom + 10
                    let xPadding: CGFloat = safeAreaInsets.left + 10
                    let xSpacing: CGFloat = 20
                    var selectFrame: CGRect
                    if UIDevice.current.orientation.isLandscape {
                        if (dPad != nil) {
                            selectFrame = CGRect(x: (dPad?.frame.origin.x)! + (dPad?.frame.size.width)! - (controlSize.width / 2), y: (buttonGroup?.frame.origin.y)! + (buttonGroup?.frame.height)! - controlSize.height, width: controlSize.width, height: controlSize.height)
                        } else {
                            selectFrame = CGRect(x: safeAreaInsets.left + xPadding, y: yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
                        }

                    } else {
                        selectFrame = CGRect(x: (view.frame.size.width / 2) - controlSize.width - (xSpacing / 2), y: (buttonGroup?.frame.origin.y)! + (buttonGroup?.frame.height)! + yPadding, width: controlSize.width, height: controlSize.height)
                    }
                    if let selectButton = self.selectButton {
                        selectButton.frame = selectFrame
                    }
                    else {
                        let selectButton = JSButton(frame: selectFrame)
                        if let tintColor = control[Keys.ControlTint] as? String {
                            selectButton.tintColor = UIColor(hex: tintColor)
                        }
                        self.selectButton = selectButton
                        //selectButton.titleLabel?.text = control[Keys.ControlTitle] as? String
                        selectButton.backgroundImage = UIImage(named: "button-thin")
                        selectButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        selectButton.delegate = self
                        selectButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 4, 0)
                        selectButton.alpha = alpha
                        selectButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
                        view.addSubview(selectButton)
                    }
                }
            }
        #endif
    }

}
