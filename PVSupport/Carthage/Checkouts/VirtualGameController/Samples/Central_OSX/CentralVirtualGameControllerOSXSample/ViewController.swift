//
//  ViewController.swift
//  CentralVirtualGameControllerOSXSample
//
//  Created by Rob Reuss on 9/24/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Cocoa
import AppKit
import GameController
import VirtualGameController

class ViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)
        
        VgcController.startWirelessControllerDiscoveryWithCompletionHandler { () -> Void in
            
            vgcLogDebug("SAMPLE: Discovery completion handler executed")
            
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)

    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        self.view.window?.title = "\(VgcManager.centralServiceName) (\(VgcManager.appRole.description))"
        
    }
    
    @objc func controllerDidConnect(_ notification: Notification) {
        
        guard let controller: VgcController = notification.object as? VgcController else { return }
        
        // Refresh on all extended gamepad changes (Global handler)
        controller.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            print("[SAMPLE] LOCAL HANDLER: Profile level (Extended), Left thumbstick value: \(gamepad.leftThumbstick.xAxis.value)  ")
            
        }
        
        controller.extendedGamepad?.leftThumbstick.xAxis.valueChangedHandler = { (thumbstick, value) in
            
            
            print("[SAMPLE] LOCAL HANDLER: Left thumbstick (axis level): \(value)  \(thumbstick.value)")
            
        }
        
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            print("[SAMPLE] LOCAL HANDLER: Left Thumbstick (element level): \(xValue), \(yValue)")
            
        }
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


