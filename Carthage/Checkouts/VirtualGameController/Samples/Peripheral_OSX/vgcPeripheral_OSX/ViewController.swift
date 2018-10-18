//
//  ViewController.swift
//  vgcPeripheral_OSX
//
//  Created by Rob Reuss on 10/17/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Cocoa
import GameController
import VirtualGameController

let peripheral = VgcManager.peripheral
let elements = VgcManager.elements

class ViewController: NSViewController {
    
    @IBOutlet weak var playerIndexLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // This is triggered by the developer on the Central side, by setting the playerIndex value on the controller, triggering a
        // system message being sent over the wire to this Peripheral, resulting in this notification.
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.gotPlayerIndex(_:)), name: NSNotification.Name(rawValue: VgcNewPlayerIndexNotification), object: nil)
        
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)

        // REQUIRED: Set device info
        peripheral?.deviceInfo = DeviceInfo(deviceUID: UUID().uuidString, vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: false)
        
        print(peripheral?.deviceInfo)
        
        VgcManager.peripheral.browseForServices()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)

    }
    
    @objc func foundService(_ notification: Notification) {
        if VgcManager.peripheral.haveConnectionToCentral == true { return }
        let service = notification.object as! VgcService
        vgcLogDebug("Automatically connecting to service \(service.fullName) because Central-selecting functionality is not implemented in this project")
        VgcManager.peripheral.connectToService(service)
    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        self.view.window?.title = VgcManager.appRole.description
        
    }
    
    
    func sendButtonPush(_ element: Element) {
        
        element.value = Float(1) as AnyObject
        peripheral?.sendElementState(element)
        
        let delayTime = DispatchTime.now() + Double(Int64(0.2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            element.value = Float(0) as AnyObject
            peripheral?.sendElementState(element)
        }
 
    }
        
    @objc open func gotPlayerIndex(_ notification: Notification) {
        
        let playerIndex: Int = notification.object as! Int
        playerIndexLabel.stringValue = "Player: \(playerIndex + 1)"
        
    }
    
    @IBAction func rightShoulderPush(_ sender: NSButton) { sendButtonPush(elements.rightShoulder) }
    @IBAction func leftShoulderPush(_ sender: NSButton) { sendButtonPush(elements.leftShoulder) }
    @IBAction func rightTriggerPush(_ sender: NSButton) { sendButtonPush(elements.rightTrigger) }
    @IBAction func leftTriggerPush(_ sender: NSButton) { sendButtonPush(elements.leftTrigger) }

    @IBAction func yPush(_ sender: NSButton) { sendButtonPush(elements.buttonY) }
    @IBAction func xPush(_ sender: NSButton) { sendButtonPush(elements.buttonX) }
    @IBAction func aPush(_ sender: NSButton) { sendButtonPush(elements.buttonA) }
    @IBAction func bPush(_ sender: NSButton) { sendButtonPush(elements.buttonB) }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

