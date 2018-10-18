//
//  VirtualGameControllerSharedViews.swift
//
//
//  Created by Rob Reuss on 9/28/15.
//
//

import Foundation
import UIKit
import VirtualGameController
import AVFoundation

public let animationSpeed = 0.35

var peripheralManager = VgcManager.peripheral

// A simple mock-up of a game controller (Peripheral)
@objc open class PeripheralControlPadView: NSObject {

    var custom = VgcManager.elements.custom
    var elements = VgcManager.elements
    var parentView: UIView!
    var controlOverlay: UIView!
    var controlLabel: UILabel!
    #if !os(tvOS)
    var motionSwitch : UISwitch!
    #endif
    var activityIndicator : UIActivityIndicatorView!
    var leftShoulderButton: VgcButton!
    var rightShoulderButton: VgcButton!
    var leftTriggerButton: VgcButton!
    var rightTriggerButton: VgcButton!
    var centerTriggerButton: VgcButton!
    var playerIndexLabel: UILabel!
    var keyboardTextField: UITextField!
    var keyboardControlView: UIView!
    var keyboardLabel: UILabel!
    open var flashView: UIImageView!
    open var viewController: UIViewController!
    
    open var serviceSelectorView: ServiceSelectorView!
    
    @objc public init(vc: UIViewController) {
    
        super.init()
        
        viewController = vc
        parentView = viewController.view
        
        #if !os(tvOS)
        NotificationCenter.default.addObserver(self, selector: #selector(PeripheralControlPadView.peripheralDidDisconnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidDisconnectNotification), object: nil)
        #endif
        NotificationCenter.default.addObserver(self, selector: #selector(PeripheralControlPadView.peripheralDidConnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)        
        
        // Notification that a player index has been set
        NotificationCenter.default.addObserver(self, selector: #selector(PeripheralControlPadView.gotPlayerIndex(_:)), name: NSNotification.Name(rawValue: VgcNewPlayerIndexNotification), object: nil)
        
        parentView.backgroundColor = UIColor.darkGray
        
        flashView = UIImageView(frame: CGRect(x: 0, y: 0, width: parentView.bounds.size.width, height: parentView.bounds.size.height))
        flashView.backgroundColor = UIColor.red
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        parentView.addSubview(flashView)
        
        let buttonSpacing: CGFloat = 1.0
        let buttonHeight: CGFloat = (0.15 * parentView.bounds.size.height)
        
        let stickSideSize = parentView.bounds.size.height * 0.25
        var marginSize: CGFloat = parentView.bounds.size.width * 0.03
        
        if VgcManager.peripheral.deviceInfo.profileType != .MicroGamepad {
        
            leftShoulderButton = VgcButton(frame: CGRect(x: 0, y: 0, width: (parentView.bounds.width * 0.50) - buttonSpacing, height: buttonHeight), element: elements.leftShoulder)
            leftShoulderButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleRightMargin]
            parentView.addSubview(leftShoulderButton)
            
            rightShoulderButton = VgcButton(frame: CGRect(x: (parentView.bounds.width * 0.50), y: 0, width: (parentView.bounds.width * 0.50) - buttonSpacing, height: buttonHeight), element: elements.rightShoulder)
            rightShoulderButton.valueLabel.textAlignment = .left
            rightShoulderButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleLeftMargin]
            parentView.addSubview(rightShoulderButton)
            
            leftTriggerButton = VgcButton(frame: CGRect(x: 0, y: buttonHeight + buttonSpacing, width: (parentView.bounds.width * 0.50) - buttonSpacing, height: buttonHeight), element: elements.leftTrigger)
            leftTriggerButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleRightMargin]
            parentView.addSubview(leftTriggerButton)
            
            rightTriggerButton = VgcButton(frame: CGRect(x: (parentView.bounds.width * 0.50), y:  buttonHeight + buttonSpacing, width: parentView.bounds.width * 0.50, height: buttonHeight), element: elements.rightTrigger)
            rightTriggerButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleTopMargin]
            rightTriggerButton.valueLabel.textAlignment = .left
            parentView.addSubview(rightTriggerButton)
            
            /*
            // FOR TESTING CUSTOM ELEMENTS
            centerTriggerButton = VgcButton(frame: CGRect(x: (parentView.bounds.width * 0.25), y:  buttonHeight + buttonSpacing, width: parentView.bounds.width * 0.50, height: buttonHeight), element: custom[CustomElementType.FiddlestickX.rawValue]!)
            centerTriggerButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin]
            centerTriggerButton.valueLabel.textAlignment = .Center
            parentView.addSubview(centerTriggerButton)
            */

            var yPosition = (buttonHeight * 2) + (buttonSpacing * 2)
            
            let padHeightWidth = parentView.bounds.size.width * 0.50
            let abxyButtonPad = VgcAbxyButtonPad(frame: CGRect(x: (parentView.bounds.size.width * 0.50), y: yPosition, width: padHeightWidth, height: padHeightWidth))
            abxyButtonPad.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleRightMargin]
            parentView.addSubview(abxyButtonPad)
            
            
            let dpadPad = VgcStick(frame: CGRect(x: 0, y: yPosition, width: padHeightWidth - buttonSpacing, height: padHeightWidth), xElement: elements.dpadXAxis, yElement: elements.dpadYAxis)
            dpadPad.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleTopMargin]
            dpadPad.nameLabel.text = "dpad"
            dpadPad.valueLabel.textAlignment = .right
            dpadPad.layer.cornerRadius = 0
            dpadPad.controlView.layer.cornerRadius = 0
            parentView.addSubview(dpadPad)
            
            yPosition += padHeightWidth + 10
            
            let leftThumbstickPad = VgcStick(frame: CGRect(x: marginSize, y: yPosition, width: stickSideSize , height: stickSideSize), xElement: elements.leftThumbstickXAxis, yElement: elements.leftThumbstickYAxis)
            leftThumbstickPad.nameLabel.text = "L Thumb"
            parentView.addSubview(leftThumbstickPad)
            
            let rightThumbstickPad = VgcStick(frame: CGRect(x: parentView.bounds.size.width - stickSideSize - marginSize, y: yPosition, width: stickSideSize, height: stickSideSize), xElement: elements.rightThumbstickXAxis, yElement: elements.rightThumbstickYAxis)
            rightThumbstickPad.nameLabel.text = "R Thumb"
            parentView.addSubview(rightThumbstickPad)
            
            
            let cameraBackground = UIView(frame: CGRect(x: parentView.bounds.size.width * 0.50 - 25, y: parentView.bounds.size.height - 49, width: 50, height: 40))
            cameraBackground.backgroundColor = UIColor.lightGray
            cameraBackground.layer.cornerRadius = 5
            parentView.addSubview(cameraBackground)
            
            let cameraImage = UIImageView(image: UIImage(named: "camera"))
            cameraImage.contentMode = .center
            cameraImage.frame = CGRect(x: parentView.bounds.size.width * 0.50 - 25, y: parentView.bounds.size.height - 49, width: 50, height: 40)
            cameraImage.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleTopMargin]
            cameraImage.isUserInteractionEnabled = true
            parentView.addSubview(cameraImage)
            
            let gr = UITapGestureRecognizer(target: vc, action: Selector(("displayPhotoPicker:")))
            cameraImage.gestureRecognizers = [gr]

            playerIndexLabel = UILabel(frame: CGRect(x: parentView.bounds.size.width * 0.50 - 50, y: parentView.bounds.size.height - 75, width: 100, height: 25))
            playerIndexLabel.text = "Player: 0"
            playerIndexLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleTopMargin]
            playerIndexLabel.textColor = UIColor.gray
            playerIndexLabel.textAlignment = .center
            playerIndexLabel.font = UIFont(name: playerIndexLabel.font.fontName, size: 14)
            parentView.addSubview(playerIndexLabel)

            
            // This is hidden because it is only used to display the keyboard below in playerTappedToShowKeyboard
            keyboardTextField = UITextField(frame: CGRect(x: -10, y: parentView.bounds.size.height + 30, width: 10, height: 10))
            keyboardTextField.addTarget(self, action: #selector(PeripheralControlPadView.textFieldDidChange(_:)), for: .editingChanged)
            keyboardTextField.autocorrectionType = .no
            parentView.addSubview(keyboardTextField)
            
            
            // Set iCadeControllerMode when testing the use of an iCade controller
            // Instead of displaying the button to the user to display an on-screen keyboard
            // for string input, we make the hidden keyboardTextField the first responder so
            // it receives controller input
            if VgcManager.iCadeControllerMode != .Disabled {
                
                keyboardTextField.becomeFirstResponder()
                
            } else {
                
    //            let keyboardLabel = UIButton(frame: CGRect(x: marginSize, y: parentView.bounds.size.height - 46, width: 100, height: 44))
    //            keyboardLabel.backgroundColor = UIColor(white: CGFloat(0.76), alpha: 1.0)
    //            keyboardLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleTopMargin]
    //            keyboardLabel.setTitle("Keyboard", forState: .Normal)
    //            keyboardLabel.setTitleColor(UIColor.blackColor(), forState: .Normal)
    //            keyboardLabel.titleLabel!.font = UIFont(name: keyboardLabel.titleLabel!.font.fontName, size: 18)
    //            keyboardLabel.layer.cornerRadius = 2
    //            keyboardLabel.addTarget(self, action: "playerTappedToShowKeyboard:", forControlEvents: .TouchUpInside)
    //            keyboardLabel.userInteractionEnabled = true
    //            parentView.addSubview(keyboardLabel)
                
                let keyboardBackground = UIView(frame: CGRect(x: marginSize, y: parentView.bounds.size.height - 49, width: 89, height: 42))
                keyboardBackground.backgroundColor = UIColor.lightGray
                keyboardBackground.layer.cornerRadius = 5
                parentView.addSubview(keyboardBackground)
                
                let keyboardImage = UIImageView(image: UIImage(named: "keyboard"))
                keyboardImage.contentMode = .scaleAspectFill
                keyboardImage.frame = CGRect(x: marginSize - 6, y: parentView.bounds.size.height - 55, width: 100, height: 42)
                keyboardImage.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleTopMargin]
                keyboardImage.isUserInteractionEnabled = true
                parentView.addSubview(keyboardImage)
                
                let gr = UITapGestureRecognizer(target: self, action: #selector(PeripheralControlPadView.playerTappedToShowKeyboard(_:)))
                keyboardImage.gestureRecognizers = [gr]
                
            }

            /* Uncomment to sample software-based controller pause behavior, and comment out camera image
               above since the two icons occupy the same space.
            
            let pauseButtonSize = CGFloat(64.0)
            let pauseButtonLabel = UIButton(frame: CGRect(x: (parentView.bounds.size.width * 0.50) - (pauseButtonSize * 0.50), y: parentView.bounds.size.height - (parentView.bounds.size.height * 0.15), width: pauseButtonSize, height: pauseButtonSize))
            pauseButtonLabel.backgroundColor = UIColor(white: CGFloat(0.76), alpha: 1.0)
            pauseButtonLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleTopMargin]
            pauseButtonLabel.setTitle("||", forState: .Normal)
            pauseButtonLabel.setTitleColor(UIColor.blackColor(), forState: .Normal)
            pauseButtonLabel.titleLabel!.font = UIFont(name: pauseButtonLabel.titleLabel!.font.fontName, size: 35)
            pauseButtonLabel.layer.cornerRadius = 10
            pauseButtonLabel.addTarget(self, action: "playerTappedToPause:", forControlEvents: .TouchUpInside)
            pauseButtonLabel.userInteractionEnabled = true
            parentView.addSubview(pauseButtonLabel)
            */
            
            let motionLabel = UILabel(frame: CGRect(x: parentView.bounds.size.width - 63, y: parentView.bounds.size.height - 58, width: 50, height: 25))
            motionLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleTopMargin]
            motionLabel.text = "Motion"
            motionLabel.textAlignment = .center
            motionLabel.textColor = UIColor.white
            //motionLabel.backgroundColor = UIColor.redColor()
            motionLabel.font = UIFont(name: motionLabel.font.fontName, size: 10)
            parentView.addSubview(motionLabel)
            
            #if !(os(tvOS))
                motionSwitch = UISwitch(frame:CGRect(x: parentView.bounds.size.width - 63, y: parentView.bounds.size.height - 37, width: 45, height: 30))
                motionSwitch.isOn = false
                //motionSwitch.setOn(true, animated: false);
                motionSwitch.addTarget(self, action: #selector(PeripheralControlPadView.motionSwitchDidChange(_:)), for: .valueChanged);
                motionSwitch.backgroundColor = UIColor.lightGray
                motionSwitch.layer.cornerRadius = 15
                parentView.addSubview(motionSwitch);
            #endif
            
        } else {
            
            marginSize = 10
            
            parentView.backgroundColor = UIColor.black
            
            let dpadSize = parentView.bounds.size.height * 0.50
            let lightBlackColor = UIColor.init(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            
            let leftThumbstickPad = VgcStick(frame: CGRect(x: (parentView.bounds.size.width - dpadSize) * 0.50, y: 24, width: dpadSize, height: parentView.bounds.size.height * 0.50), xElement: elements.dpadXAxis, yElement: elements.dpadYAxis)
            leftThumbstickPad.nameLabel.text = "dpad"
            leftThumbstickPad.nameLabel.textColor = UIColor.lightGray
            leftThumbstickPad.nameLabel.font = UIFont(name: leftThumbstickPad.nameLabel.font.fontName, size: 15)
            leftThumbstickPad.valueLabel.textColor = UIColor.lightGray
            leftThumbstickPad.valueLabel.font = UIFont(name: leftThumbstickPad.nameLabel.font.fontName, size: 15)
            leftThumbstickPad.backgroundColor = lightBlackColor
            leftThumbstickPad.controlView.backgroundColor = lightBlackColor
            parentView.addSubview(leftThumbstickPad)
            
            let buttonHeight = parentView.bounds.size.height * 0.20
            
            let aButton = VgcButton(frame: CGRect(x: 0, y: parentView.bounds.size.height - (buttonHeight * 2) - 20, width: (parentView.bounds.width) - buttonSpacing, height: buttonHeight), element: elements.buttonA)
            aButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleRightMargin]
            aButton.nameLabel.font = UIFont(name: aButton.nameLabel.font.fontName, size: 40)
            aButton.valueLabel.font = UIFont(name: aButton.valueLabel.font.fontName, size: 20)
            aButton.baseGrayShade = 0.08
            aButton.nameLabel.textColor = UIColor.lightGray
            aButton.valueLabel.textColor = UIColor.lightGray
            parentView.addSubview(aButton)
            
            let xButton = VgcButton(frame: CGRect(x: 0, y: parentView.bounds.size.height - buttonHeight - 10, width: parentView.bounds.width, height: buttonHeight), element: elements.buttonX)
            xButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleTopMargin]
            xButton.valueLabel.textAlignment = .right
            xButton.nameLabel.font = UIFont(name: xButton.nameLabel.font.fontName, size: 40)
            xButton.valueLabel.font = UIFont(name: xButton.valueLabel.font.fontName, size: 20)
            xButton.baseGrayShade = 0.08
            xButton.nameLabel.textColor = UIColor.lightGray
            xButton.valueLabel.textColor = UIColor.lightGray
            parentView.addSubview(xButton)

        }
        
        controlOverlay = UIView(frame: CGRect(x: 0, y: 0, width: parentView.bounds.size.width, height: parentView.bounds.size.height))
        controlOverlay.backgroundColor = UIColor.black
        controlOverlay.alpha = 0.9
        parentView.addSubview(controlOverlay)
        
        controlLabel = UILabel(frame: CGRect(x: 0, y: controlOverlay.bounds.size.height * 0.35, width: controlOverlay.bounds.size.width, height: 25))
        controlLabel.autoresizingMask = [UIViewAutoresizing.flexibleRightMargin , UIViewAutoresizing.flexibleBottomMargin]
        controlLabel.text = "Seeking Centrals..."
        controlLabel.textAlignment = .center
        controlLabel.textColor = UIColor.white
        controlLabel.font = UIFont(name: controlLabel.font.fontName, size: 20)
        controlOverlay.addSubview(controlLabel)
        
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: controlOverlay.bounds.size.height * 0.40, width: controlOverlay.bounds.size.width, height: 50)) as UIActivityIndicatorView
        activityIndicator.autoresizingMask = [UIViewAutoresizing.flexibleRightMargin , UIViewAutoresizing.flexibleBottomMargin]
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.white
        controlOverlay.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        serviceSelectorView = ServiceSelectorView(frame: CGRect(x: 25, y: controlOverlay.bounds.size.height * 0.50, width: controlOverlay.bounds.size.width - 50, height: controlOverlay.bounds.size.height - 200))
        serviceSelectorView.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleRightMargin]
        controlOverlay.addSubview(serviceSelectorView)
        
        
    }
    
    @objc func peripheralDidConnect(_ notification: Notification) {
        vgcLogDebug("Animating control overlay up")
        UIView.animate(withDuration: animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
            self.controlOverlay.frame = CGRect(x: 0, y: -self.parentView.bounds.size.height, width: self.parentView.bounds.size.width, height: self.parentView.bounds.size.height)
            }, completion: { finished in

        })
        
        
    }
    
    #if !os(tvOS)
    @objc func peripheralDidDisconnect(_ notification: Notification) {
        vgcLogDebug("Animating control overlay down")
        UIView.animate(withDuration: animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
            self.controlOverlay.frame = CGRect(x: 0, y: 0, width: self.parentView.bounds.size.width, height: self.parentView.bounds.size.height)
            }, completion: { finished in
                self.serviceSelectorView.refresh()
                if self.motionSwitch != nil { self.motionSwitch.isOn = false }
        })
    }
    #endif
    
    @objc public func gotPlayerIndex(_ notification: Notification) {
        
        let playerIndex: Int = notification.object as! Int
        if playerIndexLabel != nil { playerIndexLabel.text = "Player \(playerIndex + 1)" }
    }
    
    @objc func playerTappedToPause(_ sender: AnyObject) {
        
        // Pause toggles, so we send both states at once
        elements.pauseButton.value = 1.0 as AnyObject
        VgcManager.peripheral.sendElementState(elements.pauseButton)
        
    }
    
    @objc func playerTappedToShowKeyboard(_ sender: AnyObject) {
        
        if VgcManager.iCadeControllerMode != .Disabled { return }
        
        keyboardControlView = UIView(frame: CGRect(x: 0, y: parentView.bounds.size.height, width: parentView.bounds.size.width, height: parentView.bounds.size.height))
        keyboardControlView.backgroundColor = UIColor.darkGray
        parentView.addSubview(keyboardControlView)
        
        let dismissKeyboardGR = UITapGestureRecognizer(target: self, action:#selector(PeripheralControlPadView.dismissKeyboard))
        keyboardControlView.gestureRecognizers = [dismissKeyboardGR]
        
        keyboardLabel = UILabel(frame: CGRect(x: 0, y: 0, width: keyboardControlView.bounds.size.width, height: keyboardControlView.bounds.size.height * 0.60))
        keyboardLabel.text = ""
        keyboardLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleTopMargin]
        keyboardLabel.textColor = UIColor.white
        keyboardLabel.textAlignment = .center
        keyboardLabel.font = UIFont(name: keyboardLabel.font.fontName, size: 40)
        keyboardLabel.adjustsFontSizeToFitWidth = true
        keyboardLabel.numberOfLines = 5
        keyboardControlView.addSubview(keyboardLabel)
        
        UIView.animate(withDuration: animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
            self.keyboardControlView.frame = self.parentView.bounds
            }, completion: { finished in
        })
        
        keyboardTextField.becomeFirstResponder()
        
    }
    
    @objc func dismissKeyboard() {
        
        keyboardTextField.resignFirstResponder()
        UIView.animate(withDuration: animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
            self.keyboardControlView.frame = CGRect(x: 0, y: self.parentView.bounds.size.height, width: self.parentView.bounds.size.width, height: self.parentView.bounds.size.height)
            }, completion: { finished in
        })
    }
    
    @objc func textFieldDidChange(_ sender: AnyObject) {
        
        if VgcManager.iCadeControllerMode != .Disabled {
            
            vgcLogDebug("[SAMPLE] Sending iCade character: \(String(describing: keyboardTextField.text)) using iCade mode: \(VgcManager.iCadeControllerMode.description)")

            var element: Element?
            var value: Int
            (element, value) = VgcManager.iCadePeripheral.elementForCharacter(keyboardTextField.text!, controllerElements: elements)
            keyboardTextField.text = ""
            if element == nil { return }
            element?.value = value as AnyObject
            VgcManager.peripheral.sendElementState(element!)
            
        } else {
            
            keyboardLabel.text = keyboardTextField.text!
            VgcManager.elements.custom[CustomElementType.Keyboard.rawValue]!.value = keyboardTextField.text! as AnyObject
            VgcManager.peripheral.sendElementState(VgcManager.elements.custom[CustomElementType.Keyboard.rawValue]!)
            keyboardTextField.text = ""
            
        }
        
    }
    
    #if !(os(tvOS))
    @objc func motionSwitchDidChange(_ sender:UISwitch!) {
        
        vgcLogDebug("[SAMPLE] User modified motion switch: \(sender.isOn)")
        
        if sender.isOn == true {

            VgcManager.peripheral.motion.start()
        } else {
            VgcManager.peripheral.motion.stop()
        }
        
    }
    #endif
}

// Provides a view over the Peripheral control pad that allows the end user to
// select which Central/Bridge to connect to.
open class ServiceSelectorView: UIView, UITableViewDataSource, UITableViewDelegate {
    
    var tableView: UITableView!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        tableView.layer.cornerRadius = 20.0
        tableView.backgroundColor = UIColor.clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44.0
        self.addSubview(tableView)
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
    }
    
    open func refresh() {
        vgcLogDebug("[SAMPLE] Refreshing server selector view")
        self.tableView.reloadSections(IndexSet(integer: 0), with: UITableViewRowAnimation.automatic)
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: CGFloat(tableView.rowHeight) * CGFloat(VgcManager.peripheral.availableServices.count))
        return VgcManager.peripheral.availableServices.count
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
        let serviceName = VgcManager.peripheral.availableServices[indexPath.row].fullName
         cell.textLabel?.font = UIFont(name: cell.textLabel!.font.fontName, size: 16)
        cell.textLabel?.text = serviceName
        cell.backgroundColor = UIColor.gray
        cell.alpha = 1.0
        cell.textLabel?.textColor = UIColor.white

        return cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if VgcManager.peripheral.availableServices.count > 0 {
            let service = VgcManager.peripheral.availableServices[indexPath.row]
            VgcManager.peripheral.connectToService(service)
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// Basic button element, with support for 3d touch
class VgcButton: UIView {
    
    let element: Element!
    var nameLabel: UILabel!
    var valueLabel: UILabel!
    var _baseGrayShade: Float = 0.76
    var baseGrayShade: Float {
        get {
            return _baseGrayShade
        }
        set {
            _baseGrayShade = newValue
            self.backgroundColor = UIColor(white: CGFloat(_baseGrayShade), alpha: 1.0)
        }
    }
    
    var value: Float {
        get {
            return self.value
        }
        set {
            self.value = newValue
        }
    }
    
    init(frame: CGRect, element: Element) {
        
        self.element = element
        
        super.init(frame: frame)
        
        baseGrayShade = 0.76
        
        nameLabel = UILabel(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        nameLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight]
        nameLabel.text = element.name
        nameLabel.textAlignment = .center
        nameLabel.font = UIFont(name: nameLabel.font.fontName, size: 20)
        self.addSubview(nameLabel)
        
        valueLabel = UILabel(frame: CGRect(x: 10, y: frame.size.height * 0.70, width: frame.size.width - 20, height: frame.size.height * 0.30))
        valueLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleTopMargin]
        valueLabel.text = "0.0"
        valueLabel.textAlignment = .center
        valueLabel.font = UIFont(name: valueLabel.font.fontName, size: 10)
        valueLabel.textAlignment = .right
        self.addSubview(valueLabel)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func percentageForce(_ touch: UITouch) -> Float {
        let force = Float(touch.force)
        let maxForce = Float(touch.maximumPossibleForce)
        let percentageForce: Float
        if (force == 0) { percentageForce = 0 } else { percentageForce = force / maxForce }
        return percentageForce
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let touch = touches.first
        
        // If 3d touch is not supported, just send a "1" value
        if (self.traitCollection.forceTouchCapability == .available) {
            element.value = self.percentageForce(touch!) as Float as AnyObject
            valueLabel.text = "\(element.value)"
            let colorValue = CGFloat(baseGrayShade - (element.value as! Float / 10))
            self.backgroundColor = UIColor(red: colorValue, green: colorValue, blue: colorValue, alpha: 1)
        } else {
            element.value = 1.0 as Float as AnyObject
            valueLabel.text = "\(element.value)"
            self.backgroundColor = UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1)
        }
        VgcManager.peripheral.sendElementState(element)
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let touch = touches.first
        
        // If 3d touch is not supported, just send a "1" value
        if (self.traitCollection.forceTouchCapability == .available) {
            element.value = self.percentageForce(touch!) as Float as AnyObject
            valueLabel.text = "\(element.value)"
            let colorValue = CGFloat(baseGrayShade - (element.value as! Float) / 10)
            self.backgroundColor = UIColor(red: colorValue, green: colorValue, blue: colorValue, alpha: 1)
        } else {
            element.value = 1.0 as Float as AnyObject
            valueLabel.text = "\(element.value)"
            self.backgroundColor = UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1)
        }

        VgcManager.peripheral.sendElementState(element)
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            
        element.value = 0.0 as Float as AnyObject
        valueLabel.text = "\(element.value)"
        VgcManager.peripheral.sendElementState(element)
        self.backgroundColor = UIColor(white: CGFloat(baseGrayShade), alpha: 1.0)
        
    }
    
}

class VgcStick: UIView {
    
    let xElement: Element!
    let yElement: Element!
    
    var nameLabel: UILabel!
    var valueLabel: UILabel!
    var controlView: UIView!
    var touchesView: UIView!
    
    var value: Float {
        get {
            return self.value
        }
        set {
            self.value = newValue
        }
    }
    
    init(frame: CGRect, xElement: Element, yElement: Element) {
        
        self.xElement = xElement
        self.yElement = yElement
        
        super.init(frame: frame)
        
        nameLabel = UILabel(frame: CGRect(x: 0, y: frame.size.height - 20, width: frame.size.width, height: 15))
        nameLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight]
        nameLabel.textAlignment = .center
        nameLabel.font = UIFont(name: nameLabel.font.fontName, size: 10)
        self.addSubview(nameLabel)
        
        valueLabel = UILabel(frame: CGRect(x: 10, y: 10, width: frame.size.width - 20, height: 15))
        valueLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleTopMargin]
        valueLabel.text = "0.0/0.0"
        valueLabel.font = UIFont(name: valueLabel.font.fontName, size: 10)
        valueLabel.textAlignment = .center
        self.addSubview(valueLabel)
        
        let controlViewSide = frame.height * 0.40
        controlView = UIView(frame: CGRect(x: controlViewSide, y: controlViewSide, width: controlViewSide, height: controlViewSide))
        controlView.layer.cornerRadius = controlView.bounds.size.width / 2
        controlView.backgroundColor = UIColor.black
        self.addSubview(controlView)
        
        self.backgroundColor = peripheralBackgroundColor
        self.layer.cornerRadius = frame.width / 2
        
        self.centerController(0.0)
        
        if VgcManager.peripheral.deviceInfo.profileType == .MicroGamepad {
            touchesView = self
            controlView.isUserInteractionEnabled = false
            controlView.isHidden = true
        } else {
            touchesView = controlView
            controlView.isUserInteractionEnabled = true
            controlView.isHidden = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func percentageForce(_ touch: UITouch) -> Float {
        let force = Float(touch.force)
        let maxForce = Float(touch.maximumPossibleForce)
        let percentageForce: Float
        if (force == 0) { percentageForce = 0 } else { percentageForce = force / maxForce }
        return percentageForce
    }
    
    // Manage the frequency of updates
    var lastMotionRefresh: Date = Date()
    
    func processTouch(_ touch: UITouch!) {
        
        if touch!.view == touchesView {
            
            // Avoid updating too often
            if lastMotionRefresh.timeIntervalSinceNow > -(1 / 60) { return } else { lastMotionRefresh = Date() }
            
            // Prevent the stick from leaving the view center area
            var newX = touch!.location(in: self).x
            var newY = touch!.location(in: self).y
            let movementMarginSize = self.bounds.size.width * 0.25
            if newX < movementMarginSize { newX = movementMarginSize}
            if newX > self.bounds.size.width - movementMarginSize { newX = self.bounds.size.width - movementMarginSize }
            if newY < movementMarginSize { newY = movementMarginSize }
            if newY > self.bounds.size.height - movementMarginSize { newY = self.bounds.size.height - movementMarginSize }
            controlView.center = CGPoint(x: newX, y: newY)
            
            // Regularize the value between -1 and 1
            let rangeSize = self.bounds.size.height - (movementMarginSize * 2.0)
            let xValue = (((newX / rangeSize) - 0.5) * 2.0) - 1.0
            var yValue = (((newY / rangeSize) - 0.5) * 2.0) - 1.0
            yValue = -(yValue)
            
            xElement.value = Float(xValue) as AnyObject
            yElement.value = Float(yValue) as AnyObject
            VgcManager.peripheral.sendElementState(xElement)
            VgcManager.peripheral.sendElementState(yElement)
            
            valueLabel.text = "\(round(xValue * 100.0) / 100)/\(round(yValue * 100.0) / 100)"
            
        }
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        self.processTouch(touch)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        if touch!.view == touchesView {
            self.centerController(0.1)
        }
        xElement.value = Float(0) as AnyObject
        yElement.value = Float(0) as AnyObject
        VgcManager.peripheral.sendElementState(xElement)
        VgcManager.peripheral.sendElementState(yElement)
    }
    
    // Re-center the control element
    func centerController(_ duration: Double) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: {
            self.controlView.center = CGPoint(x: ((self.bounds.size.height * 0.50)), y: ((self.bounds.size.width * 0.50)))
            }, completion: { finished in
                self.valueLabel.text = "0/0"
        })
    }
}

class VgcAbxyButtonPad: UIView {

    let elements = VgcManager.elements
    var aButton: VgcButton!
    var bButton: VgcButton!
    var xButton: VgcButton!
    var yButton: VgcButton!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        self.backgroundColor = peripheralBackgroundColor
        
        let buttonWidth = frame.size.width * 0.33333
        let buttonHeight = frame.size.height * 0.33333
        let buttonMargin: CGFloat = 10.0
        
        let fontSize: CGFloat = 35.0
        
        yButton = VgcButton(frame: CGRect(x: buttonWidth, y: buttonMargin, width: buttonWidth, height: buttonHeight), element: elements.buttonY)
        yButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleBottomMargin]
        yButton.nameLabel.textAlignment = .center
        yButton.valueLabel.textAlignment = .center
        yButton.layer.cornerRadius =  yButton.bounds.size.width / 2
        yButton.nameLabel.textColor = UIColor.blue
        yButton.baseGrayShade = 0.0
        yButton.valueLabel.textColor = UIColor.white
        yButton.nameLabel.font = UIFont(name: yButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(yButton)
        
        xButton = VgcButton(frame: CGRect(x: buttonMargin, y: buttonHeight, width: buttonWidth, height: buttonHeight), element: elements.buttonX)
        xButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleBottomMargin]
        xButton.nameLabel.textAlignment = .center
        xButton.valueLabel.textAlignment = .center
        xButton.layer.cornerRadius =  xButton.bounds.size.width / 2
        xButton.nameLabel.textColor = UIColor.yellow
        xButton.baseGrayShade = 0.0
        xButton.valueLabel.textColor = UIColor.white
        xButton.nameLabel.font = UIFont(name: xButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(xButton)
        
        bButton = VgcButton(frame: CGRect(x: frame.size.width - buttonWidth - buttonMargin, y: buttonHeight, width: buttonWidth, height: buttonHeight), element: elements.buttonB)
        bButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleBottomMargin]
        bButton.nameLabel.textAlignment = .center
        bButton.valueLabel.textAlignment = .center
        bButton.layer.cornerRadius =  bButton.bounds.size.width / 2
        bButton.nameLabel.textColor = UIColor.green
        bButton.baseGrayShade = 0.0
        bButton.valueLabel.textColor = UIColor.white
        bButton.nameLabel.font = UIFont(name: bButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(bButton)
        
        aButton = VgcButton(frame: CGRect(x: buttonWidth, y: buttonHeight * 2.0 - buttonMargin, width: buttonWidth, height: buttonHeight), element: elements.buttonA)
        aButton.autoresizingMask = [UIViewAutoresizing.flexibleWidth , UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleTopMargin]
        aButton.nameLabel.textAlignment = .center
        aButton.valueLabel.textAlignment = .center
        aButton.layer.cornerRadius =  aButton.bounds.size.width / 2
        aButton.nameLabel.textColor = UIColor.red
        aButton.baseGrayShade = 0.0
        aButton.valueLabel.textColor = UIColor.white
        aButton.nameLabel.font = UIFont(name: aButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(aButton)
        
        
    }
}

open class ElementDebugView: UIView {
    
    var elementLabelLookup = Dictionary<Int, UILabel>()
    var elementBackgroundLookup = Dictionary<Int, UIView>()
    var controllerVendorName: UILabel!
    var scrollView: UIScrollView!
    var controller: VgcController!
    var titleRegion: UIView!
    var imageView: UIImageView!
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init(frame: CGRect, controller: VgcController) {
        
        self.controller = controller
        
        super.init(frame: frame)
        
        let debugViewDoubleTapGR = UITapGestureRecognizer(target: self, action: #selector(ElementDebugView.receivedDebugViewDoubleTap))
        debugViewDoubleTapGR.numberOfTapsRequired = 2
        
        let debugViewTapGR = UITapGestureRecognizer(target: self, action: #selector(ElementDebugView.receivedDebugViewTap))
        debugViewTapGR.require(toFail: debugViewDoubleTapGR)
        
        self.gestureRecognizers = [debugViewTapGR, debugViewDoubleTapGR]

        self.backgroundColor = UIColor.white
        
        //self.layer.cornerRadius = 15
        self.layer.shadowOffset = CGSize(width: 5, height: 5)
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowRadius = 3.0
        self.layer.shadowOpacity = 0.3
        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.main.scale
        
        titleRegion = UIView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 140))
        titleRegion.autoresizingMask = [UIViewAutoresizing.flexibleWidth]
        titleRegion.backgroundColor = UIColor.lightGray
        titleRegion.clipsToBounds = true
        self.addSubview(titleRegion)
        
        imageView = UIImageView(frame: CGRect(x: self.bounds.size.width - 110, y: 150, width: 100, height: 100))
        imageView.contentMode = .scaleAspectFit
        self.addSubview(imageView)
        
        controllerVendorName = UILabel(frame: CGRect(x: 0, y: 0, width: titleRegion.frame.size.width, height: 50))
        controllerVendorName.backgroundColor = UIColor.lightGray
        controllerVendorName.autoresizingMask = [UIViewAutoresizing.flexibleWidth]
        controllerVendorName.text = controller.deviceInfo.vendorName
        controllerVendorName.textAlignment = .center
        controllerVendorName.font = UIFont(name: controllerVendorName.font.fontName, size: 20)
        controllerVendorName.clipsToBounds = true
        titleRegion.addSubview(controllerVendorName)
        
        var labelHeight: CGFloat = 20.0
        let deviceDetailsFontSize: CGFloat = 14.0
        let leftMargin: CGFloat = 40.0
        var yPosition = controllerVendorName.bounds.size.height
        
        let controllerTypeLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        controllerTypeLabel.backgroundColor = UIColor.lightGray
        controllerTypeLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth]
        controllerTypeLabel.text = "Controller Type: " + controller.deviceInfo.controllerType.description
        controllerTypeLabel.textAlignment = .left
        controllerTypeLabel.font = UIFont(name: controllerTypeLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(controllerTypeLabel)
        
        yPosition += labelHeight
        let profileTypeLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        profileTypeLabel.backgroundColor = UIColor.lightGray
        profileTypeLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth]
        profileTypeLabel.text = "Profile Type: " + controller.profileType.description
        profileTypeLabel.textAlignment = .left
        profileTypeLabel.font = UIFont(name: profileTypeLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(profileTypeLabel)
        
        yPosition += labelHeight
        
        let attachedLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        attachedLabel.backgroundColor = UIColor.lightGray
        attachedLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth]
        attachedLabel.text = "Attached to Device: " + "\(controller.deviceInfo.attachedToDevice)"
        attachedLabel.textAlignment = .left
        attachedLabel.font = UIFont(name: profileTypeLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(attachedLabel)
        
        yPosition += labelHeight
        
        let supportsMotionLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        supportsMotionLabel.backgroundColor = UIColor.lightGray
        supportsMotionLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth]
        supportsMotionLabel.text = "Supports Motion: " + "\(controller.deviceInfo.supportsMotion)"
        supportsMotionLabel.textAlignment = .left
        supportsMotionLabel.font = UIFont(name: supportsMotionLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(supportsMotionLabel)
        
        // Scrollview allows the element values to scroll vertically, especially important on phones
        scrollView = UIScrollView(frame: CGRect(x: 0, y: titleRegion.bounds.size.height + 10, width: frame.size.width, height: frame.size.height - titleRegion.bounds.size.height - 10))
        scrollView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        self.addSubview(scrollView)
        
        labelHeight = CGFloat(22.0)
        yPosition = CGFloat(10.0)
        
        if deviceIsTypeOfBridge() && VgcManager.bridgeRelayOnly {
            let elementLabel = UILabel(frame: CGRect(x: 10, y: yPosition, width: frame.size.width - 20, height: labelHeight * 2))
            elementLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleBottomMargin, UIViewAutoresizing.flexibleRightMargin]
            elementLabel.text = "In relay-only mode - no data will display here."
            elementLabel.textAlignment = .center
            elementLabel.font = UIFont(name: controllerVendorName.font.fontName, size: 16)
            elementLabel.numberOfLines = 2
            scrollView.addSubview(elementLabel)
            
            return
        }
        
        for element in VgcManager.elements.elementsForController(controller) {
            
            let elementBackground = UIView(frame: CGRect(x: (frame.size.width * 0.50) + 15, y: yPosition, width: 0, height: labelHeight))
            elementBackground.backgroundColor = UIColor.lightGray
            elementBackground.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleLeftMargin]
            scrollView.addSubview(elementBackground)
            
            let elementLabel = UILabel(frame: CGRect(x: 10, y: yPosition, width: frame.size.width * 0.50, height: labelHeight))
            elementLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleRightMargin]
            elementLabel.text = "\(element.name):"
            elementLabel.textAlignment = .right
            elementLabel.font = UIFont(name: controllerVendorName.font.fontName, size: 16)
            scrollView.addSubview(elementLabel)
            
            let elementValue = UILabel(frame: CGRect(x: (frame.size.width * 0.50) + 15, y: yPosition, width: frame.size.width * 0.50, height: labelHeight))
            elementValue.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleLeftMargin]
            elementValue.text = "0"
            elementValue.font = UIFont(name: controllerVendorName.font.fontName, size: 16)
            scrollView.addSubview(elementValue)
            
            elementBackgroundLookup[element.identifier] = elementBackground
            
            elementLabelLookup[element.identifier] = elementValue
            
            yPosition += labelHeight
            
        }
        
        scrollView.contentSize = CGSize(width: frame.size.width, height: yPosition + 40)
        
    }
    
    // Demonstrate bidirectional communication using a simple tap on the
    // Central debug view to send a message to one or all Peripherals.
    // Use of a custom element is demonstrated; both standard and custom
    // are supported.
    @objc open func receivedDebugViewTap() {

       controller.vibrateDevice()
        
        let imageElement = VgcManager.elements.elementFromIdentifier(ElementType.image.rawValue)
        if let image = UIImage(named: "digit.jpg") {
            let imageData = UIImageJPEGRepresentation(image, 1.0)
            imageElement?.value = imageData! as AnyObject
            imageElement?.clearValueAfterTransfer = true
            controller.sendElementStateToPeripheral(imageElement!)
        }
        return
        
        // This will flash to peripheral interface blue.  Look for the handler in the Peripheral
        // app View Controller
        if let tapElement = controller.elements.custom[CustomElementType.DebugViewTap.rawValue] {
            tapElement.value = 1.0 as AnyObject
            controller.sendElementStateToPeripheral(tapElement)
            VgcController.sendElementStateToAllPeripherals(tapElement)
        }
        
        // Test vibrate using custom element
        /*
        let element = controller.elements.custom[CustomElementType.VibrateDevice.rawValue]!
        element.value = 1
        VgcController.sendElementStateToAllPeripherals(element)
        */
    }
    
    @objc open func receivedDebugViewDoubleTap() {

        self.controller.disconnect()
        
    }
    
    open func receivedDebugViewTripleTap() {
       
        /*
        let imageElement = VgcManager.elements.elementFromIdentifier(ElementType.image.rawValue)
        if let image = UIImage(named: "digit.jpg") {
            let imageData = UIImageJPEGRepresentation(image, 1.0)
            imageElement?.value = imageData! as AnyObject
            imageElement?.clearValueAfterTransfer = true
            controller.sendElementStateToPeripheral(imageElement!)
        }
        // Test simple float mode
        //let rightShoulder = controller.elements.rightShoulder
        //rightShoulder.value = 1.0
        //controller.sendElementStateToPeripheral(rightShoulder)
        //VgcController.sendElementStateToAllPeripherals(rightShoulder)
        
        // Test string mode
        let keyboard = controller.elements.custom[CustomElementType.Keyboard.rawValue]!
        keyboard.value = "1 2 3 4 5 6 7 8" as AnyObject
        keyboard.value = "Before newline\nAfter newline\n\n\n" as AnyObject
        controller.sendElementStateToPeripheral(keyboard)
        //VgcController.sendElementStateToAllPeripherals(keyboard)
 
 */
        
    }
    
    // The Central is in charge of managing the toggled state of the
    // pause button on a controller; we're doing that here just using
    // the current background color to track state.
    open func togglePauseState() {
        if (self.backgroundColor == UIColor.white) {
            self.backgroundColor = UIColor.lightGray
        } else {
            self.backgroundColor = UIColor.white
        }
    }
    
    // Instead of refreshing individual values by setting up handlers, we use a
    // global handler and refresh all the values.
    open func refresh(_ controller: VgcController) {
        
        self.controllerVendorName.text = controller.deviceInfo.vendorName
        
        for element in controller.elements.elementsForController(controller) {
            if let label = self.elementLabelLookup[element.identifier] {
                let keypath = element.getterKeypath(controller)
                var value: AnyObject
                if element.type == .custom {
                    if element.dataType == .Data {
                        value = "" as AnyObject
                    } else {
                        value = (controller.elements.custom[element.identifier]?.value)!
                    }
                    //if element.dataType == .String && (value as! NSObject) as! NSNumber == 0 { value = "" as AnyObject }
                } else if keypath != "" {
                    value = controller.value(forKeyPath: keypath)! as AnyObject

                } else {
                    value = "" as AnyObject
                }
                // PlayerIndex uses enumerated values that are offset by 1
                if element == controller.elements.playerIndex {
                    label.text = "\(controller.playerIndex.rawValue + 1)"
                    continue
                }
                label.text = "\(value)"
                let stringValue = "\(value)"
                
                // Pause will be empty
                if stringValue == "" { continue }

                if element.dataType == .Float || element.dataType == .Double {
                    
                    let valFloat = Float(stringValue)! as Float
                    
                    if let backgroundView = self.elementBackgroundLookup[element.identifier] {
                        var width = label.bounds.size.width * CGFloat(valFloat)
                        if (width > 0 && width < 0.1) || (width < 0 && width > -0.1) { width = 0 }
                        backgroundView.frame = CGRect(x: (label.bounds.size.width) + 15, y: backgroundView.frame.origin.y, width: width, height: backgroundView.bounds.size.height)
                    }
                    
                } else if element.dataType == .Int {

                    let valInt = Int(stringValue)! as Int

                    if let backgroundView = self.elementBackgroundLookup[element.identifier] {
                        var width = label.bounds.size.width * CGFloat(valInt)
                        if (width > 0 && width < 0.1) || (width < 0 && width > -0.1) { width = 0 }
                        backgroundView.frame = CGRect(x: (label.bounds.size.width) + 15, y: backgroundView.frame.origin.y, width: width, height: backgroundView.bounds.size.height)
                    }
                } else if element.dataType == .String {
                    
                    if stringValue != "" {
                        label.backgroundColor = UIColor.lightGray
                    } else {
                        label.backgroundColor = UIColor.clear
                    }
                    
                }
            }
        }
    }
}

