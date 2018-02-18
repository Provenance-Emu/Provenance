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
                    let leftShoulderFrame = CGRect(x: xPadding, y: yPadding, width: controlSize.width, height: controlSize.height)
                    
                    if let leftShoulderButton = self.leftShoulderButton {
                        leftShoulderButton.frame = leftShoulderFrame
                    } else {
                        let leftShoulderButton = JSButton(frame: leftShoulderFrame)
                        self.leftShoulderButton = leftShoulderButton
                        leftShoulderButton.titleLabel?.text = control[Keys.ControlTitle] as? String
                        leftShoulderButton.backgroundImage = UIImage(named: "button-thin")
                        leftShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        leftShoulderButton.delegate = self
                        leftShoulderButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 4, 0)
                        leftShoulderButton.alpha = alpha
                        leftShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
                        view.addSubview(leftShoulderButton)
                    }
                }
                else if (controlType == Keys.RightShoulderButton) {
                    let xPadding: CGFloat = safeAreaInsets.right + 10
                    let yPadding: CGFloat = safeAreaInsets.top + 10
                    
                    if let rightShoulderButton = self.rightShoulderButton {
                        let rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: yPadding, width: controlSize.width, height: controlSize.height)
                        rightShoulderButton.frame = rightShoulderFrame
                    }
                    else {
                        let rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: yPadding, width: controlSize.width, height: controlSize.height)
                        let rightShoulderButton = JSButton(frame: rightShoulderFrame)
                        self.rightShoulderButton = rightShoulderButton
                        rightShoulderButton.titleLabel?.text = control[Keys.ControlTitle] as? String
                        rightShoulderButton.backgroundImage = UIImage(named: "button-thin")
                        rightShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed")
                        rightShoulderButton.delegate = self
                        rightShoulderButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 4, 0)
                        rightShoulderButton.alpha = alpha
                        rightShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
                        view.addSubview(rightShoulderButton)
                    }
                }
                else if (controlType == Keys.StartButton) {
                    let yPadding: CGFloat = max(safeAreaInsets.bottom, 10)
                    let startFrame = CGRect(x: (view.frame.size.width - controlSize.width) / 2, y: view.frame.size.height - controlSize.height - yPadding, width: controlSize.width, height: controlSize.height)
                    
                    if let startButton = self.startButton {
                        startButton.frame = startFrame
                    } else {
                        let startButton = JSButton(frame: startFrame)
                        self.startButton = startButton
                        startButton.titleLabel?.text = control[Keys.ControlTitle] as? String
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
                    let yPadding: CGFloat = max(safeAreaInsets.bottom, 10)
                    let ySeparation: CGFloat = 10
                    let selectFrame = CGRect(x: (view.frame.size.width - controlSize.width) / 2, y: view.frame.size.height - yPadding - (controlSize.height * 2) - ySeparation, width: controlSize.width, height: controlSize.height)
                    
                    if let selectButton = self.selectButton {
                        selectButton.frame = selectFrame
                    }
                    else {
                        let selectButton = JSButton(frame: selectFrame)
                        self.selectButton = selectButton
                        selectButton.titleLabel?.text = control[Keys.ControlTitle] as? String
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
