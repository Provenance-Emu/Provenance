//
//  VgcCentralViewController.swift
//
//
//  Created by Rob Reuss on 11/1/15.
//
//

import Foundation
import UIKit
import GameController
import AVFoundation
import VirtualGameController

@objc public class VgcCentralViewController: UIViewController {
    
    var elementDebugViewLookup = Dictionary<VgcController, UIView>()
    var scrollview: UIScrollView!
    var debugViewWidth: CGFloat!
    var iCadeTextField: UITextField!
    var imageView: UIImageView!
    
    public override func viewDidLoad() {
        
        super.viewDidLoad()
 
        self.view.backgroundColor = UIColor.darkGray
        
        let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 20, width: self.view.bounds.size.width, height: 60))
        titleLabel.text = "\(VgcManager.centralServiceName) (\(VgcManager.appRole.description))"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont(name: titleLabel.font.fontName, size: 20)
        titleLabel.textColor = UIColor.lightGray
        titleLabel.adjustsFontSizeToFitWidth = true
        self.view.addSubview(titleLabel)
        
        // Horizontal scrollview that contains the debug views
        scrollview = UIScrollView(frame: CGRect(x: 0, y: 70, width: self.view.bounds.width, height: self.view.bounds.size.height - 70))
        scrollview.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleBottomMargin]
        scrollview.contentSize = CGSize(width: scrollview.bounds.size.width, height: scrollview.bounds.size.height)
        scrollview.backgroundColor = UIColor.gray
        self.view.addSubview(scrollview)
        
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width  * 0.20, height: self.view.bounds.size.height * 0.20))
        imageView.center = self.view.center
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = UIColor.clear
        self.view.addSubview(imageView)
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(VgcCentralViewController.clearImage))
        imageView.gestureRecognizers = [gr]

        // Make debug view width suitable for a given device type
        if (UIDevice.current.userInterfaceIdiom == .phone) {
            self.debugViewWidth = scrollview.bounds.size.width * 0.80
        } else if (UIDevice.current.userInterfaceIdiom == .pad) {
            self.debugViewWidth = scrollview.bounds.size.width * 0.40
            if debugViewWidth > 500 { debugViewWidth = 300 }
        } else {
            self.debugViewWidth = scrollview.bounds.size.width * 0.17
        }
        
        #if !os(tvOS)
            // Hidden text field to receive iCade controller input
            iCadeTextField = UITextField(frame: CGRect(x:-1, y: -1, width: 1, height: 1))
            iCadeTextField.addTarget(self, action: #selector(self.receivedIcadeInput(sender:)), for: .editingChanged)
            //iCadeTextField.autocorrectionType = .No
            self.view.addSubview(iCadeTextField)
        #endif
        
        // I have never been able to get this method to discover a controller
        // Here's the Apple documentation for this method:
        // https://developer.apple.com/documentation/gamecontroller/gccontroller/1458879-startwirelesscontrollerdiscovery?language=objc
        VgcController.startWirelessControllerDiscoveryWithCompletionHandler { () -> Void in
            
            vgcLogDebug("[SAMPLE] Discovery completion handler executed")
            
        }
        
        // These notifications function just like their GCController counter-parts, resulting from new connections by
        // both software and hardware controllers
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidDisconnect), name: NSNotification.Name(rawValue: VgcControllerDidDisconnectNotification), object: nil)
        
        
        // Used to determine if an external keyboard (an iCade controller) is paired
//        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        // This is a little convienance thing for the purpose of keeping the debug views refreshed when a change is
        // made to the playerIndex
        NotificationCenter.default.addObserver(self, selector: #selector(VgcCentralViewController.gotPlayerIndex), name: NSNotification.Name(rawValue: VgcNewPlayerIndexNotification), object: nil)

        #if !os(tvOS)
            // To enable iCade, this must be after the notification observers are defined. The connect notification should be used
            // to setup the controller for use.
            //VgcManager.iCadeControllerMode = .ICadeMobile
            if VgcManager.iCadeControllerMode != .Disabled { iCadeTextField.becomeFirstResponder() }
        #endif
    }
    

    func isExternalKeyboardFrame(keyboardFrame: CGRect) -> Bool {
        
        let keyboard = self.view.convert(keyboardFrame, from: self.view.window)
        let height = self.view.frame.size.height
        return keyboard.origin.y + keyboard.size.height > height
        
    }
    

    func testForPairedExternalKeyboard(aNotification:NSNotification) {
        
        vgcLogDebug("T[SAMPLE] esting for external keyboard (iCade controller)")
        
        if let keyboardFrame = aNotification.userInfo?[NSNotification.Name("UIKeyboardFrameBeginUserInfoKey")] as? CGRect {
                
                if isExternalKeyboardFrame(keyboardFrame: keyboardFrame) {
                    
                    vgcLogDebug("[SAMPLE] External keyboard found, displaying iCade controller")
                    
                    // Confirm we are in iCade controller mode
                    if VgcManager.iCadeControllerMode != .Disabled {
                        
                        // Add an iCade controller to our set of controllers
                        #if !os(watchOS)
                            VgcController.enableIcadeController()
                        #endif
                    }
                    
                } else {
                    
                    vgcLogDebug("[SAMPLE] No external keyboard (iCade controller), resigning to hide virtual keyboard")
                    iCadeTextField.resignFirstResponder()
                }
            } else {
            // no UIKeyboardFrameBeginUserInfoKey entry in userInfo
        }
    }


    @objc func keyboardWillShow(notification: NSNotification) {
        testForPairedExternalKeyboard(aNotification: notification)
    }
    @objc func keyboardWillHide(notification: NSNotification) {
        
        testForPairedExternalKeyboard(aNotification: notification)
    }
    
    
    // iCade controller-generated characters are received into the hidden iCadeTextField, which calls this function.
    // In turn, the appropriate element can be obtained using elementForCharacter, and then the handlers called on the
    // controller.  If this were a Peripheral-side implementation, then the element would be used to send the value to
    // the Central.
    @objc func receivedIcadeInput(sender: AnyObject) {
        
        if VgcManager.iCadeControllerMode != .Disabled && VgcController.iCadeController != nil {
            
            
            vgcLogDebug("Sending iCade character: \(iCadeTextField.text) using iCade mode: \(VgcManager.iCadeControllerMode.description)")
            var element: Element?
            var value: Int
            (element, value) = VgcManager.iCadePeripheral.elementForCharacter( iCadeTextField.text!, controllerElements: VgcController.iCadeController.elements)
            iCadeTextField.text = ""
            if element == nil { return }
            element?.value = value as AnyObject
            VgcController.iCadeController.triggerElementHandlers(element!, value: Float(value) as AnyObject)
 
        }
    }
    
    //let lockQueueRefreshDebugView = dispatch_queue_create("net.simplyformed.lockRefreshDebugView", nil)

    // This will result in a given debug view having all of it's values updated.
    func refreshDebugViewForController(controller: VgcController) {

            if let elementDebugView: ElementDebugView = self.elementDebugViewLookup[controller] as? ElementDebugView {
                elementDebugView.refresh(controller)
            }

    }
    
    // Call refresh on all of the debug views
    func refreshAllDebugViews() {
        
        vgcLogDebug("[SAMPLE] Refreshing all debug views")
        for controller in VgcController.controllers() {
            refreshDebugViewForController(controller: controller)
        }
        
    }
    
    @objc func clearImage() {
        imageView.image = nil
    }
    
    @objc public func gotPlayerIndex(notification: NSNotification) {
        
        refreshAllDebugViews()
        
    }
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
        // If we're enhancing a limited hardware controller (e.g. with motion), we should display the Peripheral UI
        // instead of the debug view UI
        if VgcManager.appRole == .EnhancementBridge { return }
        
        // Notification passes the new controller, allowing us to set it's properties below
        guard let newController: VgcController = notification.object as? VgcController else {
            vgcLogDebug("[SAMPLE] Got nil controller in controllerDidConnect")
            return
        }
        
        // This is actually the default in the framework - shown here for illustrative purposes
        newController.handlerQueue = DispatchQueue.main
        
        /*
        // Send configuration information to the peripheral, which is normally set on the Peripheral side
        VgcManager.peripheralSetup.motionActive = true
        VgcManager.peripheralSetup.enableMotionAttitude = true
        VgcManager.peripheralSetup.enableMotionGravity = true
        VgcManager.peripheralSetup.enableMotionUserAcceleration = true
        VgcManager.peripheralSetup.enableMotionRotationRate = true
        VgcManager.peripheralSetup.sendToController(newController)
         */
        
        // Debug views are the UI element representing each controller
        let elementDebugView = ElementDebugView(frame: CGRect(x: -(self.debugViewWidth), y: 0, width: self.debugViewWidth, height: scrollview.bounds.size.height - 50), controller: newController)
        elementDebugView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleRightMargin, UIViewAutoresizing.flexibleLeftMargin]
        scrollview.addSubview(elementDebugView)
        
        if !newController.isHardwareController {
            
            /*
            // DEMONSTRATES SENDING CONFIGURATION INFO TO THE PERIPHERAL ON CONNECTION
            // Set a random color on the Peripheral and Debug View,
            // turn on motion automatically - setup to work with iOS Centeral sample
            // app and the Scenekit sample app
            

            // Generate a dark color...
            let randomRed = CGFloat(Float(arc4random()) / (Float(UINT32_MAX))) / 2.0
            let randomGreen = CGFloat(Float(arc4random()) / (Float(UINT32_MAX))) / 2.0
            let randomBlue = CGFloat(Float(arc4random()) / (Float(UINT32_MAX))) / 2.0
            let peripheralBackgroundColor = UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)
            VgcManager.peripheralSetup = VgcPeripheralSetup(profileType: .ExtendedGamepad, backgroundColor: peripheralBackgroundColor)
            
            // Turn on motion to demonstrate that it can be done remotely
            VgcManager.peripheralSetup.motionActive = true
            VgcManager.peripheralSetup.sendToController(controller)
            
            // Set debug view to reflect same color
            elementDebugView.controllerVendorName.backgroundColor = peripheralBackgroundColor
            
            // Use light color to contrast with dark background
            elementDebugView.controllerVendorName.textColor = UIColor.lightGrayColor()
*/
            
        }
     
        elementDebugViewLookup[newController] = elementDebugView
        
        self.refreshElementDebugViewPositions()
        
        // Update the debug view after giving the player index time to arrive
        let triggerTime = DispatchTime.now() + .seconds(6)
        DispatchQueue.main.asyncAfter(deadline: triggerTime) {
            elementDebugView.refresh(newController)
        }

        // What follows are a serious of handler that assign blocks to the new controller that
        // are executed in response to receiving controller input from either a software-based Peripheral
        // or a hardware-based MFI controller.  This is where you put game logic that is driven by controllers.
        // NOTE: you can also poll the element values if you want to associate your controller input with
        // rendering.
        
        // Refresh on all extended gamepad changes (Global handler)
        newController.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            self.refreshDebugViewForController(controller: newController)
            
        }
        
        newController.extendedGamepad?.leftThumbstick.xAxis.valueChangedHandler = { (thumbstick, value) in
            
            //print("HANDLER: Left thumbstick xAxis: \(value)")
        }
        
        newController.extendedGamepad?.buttonA.valueChangedHandler = { (button, value, pressed) in
            
            print("[SAMPLE] HANDLER:Button A value: \(pressed), \(value)")
            
        }
        
        newController.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            //print("HANDLER: Left thumbstick: \(xValue), \(yValue)")
            
        }


        // Refresh on all gamepad changes (Global handler)
        newController.gamepad?.valueChangedHandler = { (gamepad: GCGamepad, element: GCControllerElement) in
            
            self.refreshDebugViewForController(controller: newController)
            
        }

        #if os(tvOS)
            // Refresh on all micro gamepad changes (Global handler)
            newController.microGamepad?.valueChangedHandler = { (gamepad: GCMicroGamepad, element: GCControllerElement) in
                
                self.refreshDebugViewForController(controller: newController)
                
            }
        #endif
        
        // Avoiding updating the UI too frequently for motion changes
        var lastMotionRefresh: NSDate = NSDate()
        
        // Refresh on all motion changes
        newController.motion?.valueChangedHandler = { (input: VgcMotion) in
            
            // Avoid updating too often or the UI will freeze up
            if lastMotionRefresh.timeIntervalSinceNow > -0.01 { return } else { lastMotionRefresh = NSDate() }
            self.refreshDebugViewForController(controller: newController)
            
        }
        
        // Toggle pause button display value.  Note that the toggle state of the pause button is the
        // responsibility of the app (the game) to manage
        newController.controllerPausedHandler = { (controller: VgcController) in

            if let elementDebugView: ElementDebugView = self.elementDebugViewLookup[controller] as? ElementDebugView {
                elementDebugView.togglePauseState()
            }
            
        }
        
        // Responds if any custom elements change
        Elements.customElements.valueChangedHandler = { (controller, element) in
            
            self.refreshDebugViewForController(controller: controller)
            
        }
        
        // Test receiving an image
        newController.elements.image.valueChangedHandler = { (controller, element) in

            vgcLogDebug("[SAMPLE] Handler fired for Send Image")

            if let elementDebugView: ElementDebugView = self.elementDebugViewLookup[controller] as? ElementDebugView {
                
                if let image = UIImage(data: (element.value as! NSData) as Data) {
                    elementDebugView.imageView.image = image
                    element.value = NSData()
                }
            }
            
            
        }
        
        // Test of custom element "keyboard" handler
        newController.elements.custom[CustomElementType.Keyboard.rawValue]!.valueChangedHandler = { (controller, element) in
            
            let stringValue = String(describing: controller.elements.custom[CustomElementType.Keyboard.rawValue]!.value)
            if stringValue.characters.count > 1 {
                let synthesizer = AVSpeechSynthesizer()
                let utterance = AVSpeechUtterance(string: (stringValue))
                utterance.rate = AVSpeechUtteranceMaximumSpeechRate / 3.0
                utterance.postUtteranceDelay = 0.0
                utterance.preUtteranceDelay = 0.0
                synthesizer.speak(utterance)
            }
            
        }
        
        // Another custom element test
        newController.elements.custom[CustomElementType.FiddlestickX.rawValue]!.valueChangedHandler = { (controller, element) in
            
            self.refreshDebugViewForController(controller: controller)
            
        }
        
        // Demonstrates receiving a message as a Bridge from a Central
        VgcManager.elements.rightTrigger.valueChangedHandlerForPeripheral = { (element) in
            
            vgcLogDebug("[SAMPLE] Got right trigger")
            
        }
        
    }
    
    @objc func controllerDidDisconnect(notification: NSNotification) {
        
        guard let controller: VgcController = notification.object as? VgcController else { return }
        
        // Remove element debug view
        let elementDebugView = elementDebugViewLookup.removeValue(forKey: controller)
        
        if elementDebugView != nil {
            
            // Send to back so it animates off-screen behind other debug views
            self.scrollview.sendSubview(toBack: elementDebugView!)
            
            UIView.animate(withDuration: animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
                elementDebugView!.frame = CGRect(x: -(self.debugViewWidth), y: 5, width: self.debugViewWidth, height: self.scrollview.bounds.size.height - 5)
                }, completion: { finished in
                    elementDebugView?.removeFromSuperview()
            })
        }
        self.refreshElementDebugViewPositions()
        
    }
    
    func refreshElementDebugViewPositions() {
   
        let controllerCount = CGFloat(VgcController.controllers().count)
        
        vgcLogDebug("[SAMPLE] Refreshing debug view positions with controller count of \(controllerCount), debug view count \(self.elementDebugViewLookup.count)")
        
        let elementViewSpacing = CGFloat(20.0)
        var xPosition = CGFloat(5)
        var playerIndex = 0
         
        for controller in VgcController.controllers() {
            
            if let elementDebugView = self.elementDebugViewLookup[controller] {
                
                if !deviceIsTypeOfBridge() {
                    controller.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex)!
                    playerIndex += 1
                }
                
                UIView.animate(withDuration: animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
                    
                    elementDebugView.frame = CGRect(x: xPosition, y: 5, width: self.debugViewWidth, height: self.scrollview.bounds.size.height - 20)
                    
                    }, completion: { finished in
                        
                })
                xPosition += self.debugViewWidth + elementViewSpacing
                
            } else {
                vgcLogError("[SAMPLE] Controller \(controller.vendorName) has no DEBUG view")
            }
            
        }
        
        self.scrollview.contentSize = CGSize(width: (self.debugViewWidth + elementViewSpacing) * controllerCount, height: self.scrollview.bounds.size.height - 120)

    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
}
