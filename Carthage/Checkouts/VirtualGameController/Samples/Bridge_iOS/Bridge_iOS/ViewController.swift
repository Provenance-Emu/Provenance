//
//  ViewController.swift
//  vgcBridge
//
//  Created by Rob Reuss on 9/29/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import UIKit
import VirtualGameController
          
class ViewController: VgcCentralViewController {
    
    var peripheralControlPadView: PeripheralControlPadView!
    
    override func viewDidLoad() {
        
        // .Bridge publishes both a Peripheral and Central service
        VgcManager.startAs(.Bridge, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings())
        
        super.viewDidLoad()

        // Optionally display the built-in basic game control pad. This can be used to demonstrate
        // how in Bridge mode controller forwarding permits augmenting a hardware or software controller
        // with additional controls.  For example, if an iPhone in .Bridge mode is inserted into a form-fitting
        // controller, both the hardware elements and on-screen elements will be forwarded to the Central.

        if VgcManager.appRole == .EnhancementBridge {
            
            self.peripheralControlPadView = PeripheralControlPadView(vc: self)
            
        }

    }


}

