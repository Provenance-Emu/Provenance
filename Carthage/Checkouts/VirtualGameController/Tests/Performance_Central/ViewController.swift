//
//  ViewController.swift
//  Performance_Central
//
//  Created by Rob Reuss on 10/4/17.
//  Copyright © 2017 Rob Reuss. All rights reserved.
//

import UIKit
import VirtualGameController

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
   
        VgcManager.loggerUseNSLog = true
        
        // General etwork performance info
        VgcManager.performanceSamplingDisplayFrequency = 30.0
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
        
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false)
       
    }

    @objc func controllerDidConnect(notification: NSNotification) {
        
        if VgcManager.appRole == .EnhancementBridge { return }
        
        guard let newController: VgcController = notification.object as? VgcController else {
            vgcLogDebug("[TESTING] Got nil controller in controllerDidConnect")
            return
        }

        // Bounce in-coming data from the Peripheral back to the Peripheral
        newController.motion?.valueChangedHandler = { (input: VgcMotion) in

            newController.elements.motionAttitudeX.value = input.attitude.x as AnyObject
            VgcController.sendElementStateToAllPeripherals(newController.elements.motionAttitudeX)
            
        }

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

