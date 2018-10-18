//
//  ViewController.swift
//  CentralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/14/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import VirtualGameController
import GameController
import Foundation

// Note that sample apps for both Bridge and Central descend from a common
// ancestor class that contains much of the functionality.
class ViewController: VgcCentralViewController {
    
    
    override func viewDidLoad() {
        
        // Publishes the central service simplest form
        //VgcManager.startAs(.Central, appIdentifier: "vgc")
        
        // Use a compiler flag to control the logging level, dropping it to just errors if this
        // is a release build.
        #if Release
            VgcManager.loggerLogLevel = .Error // Minimal logging
        #else
            VgcManager.loggerLogLevel = .Debug // Robust logging
        #endif
        
        VgcManager.loggerUseNSLog = true
        
        // Network performance info
        VgcManager.performanceSamplingDisplayFrequency = 10.0

        // Include custom elements
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false)
        
        // Enable running as a "Local" game controller as well, used in combination with running as a PERIPHERAL to
        // have the controller both process it's own control activity in a game and forward that activity to another
        // device
         //VgcManager.startAs(.MultiplayerPeer, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false, enableLocalController: false)
         //NotificationCenter.default.addObserver(self, selector: #selector(ViewController.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)
         //VgcManager.peripheral.browseForServices()
        
        super.viewDidLoad()
        
    }
    
    // Used for testing connecting the sample apps in multipeer mode -
    // uncomment above and here to play with this functionality
     
    // Auto-connect to opposite device
    /*
    @objc func foundService(_ notification: Notification) {
        let vgcService = notification.object as! VgcService
        VgcManager.peripheral.connectToService(vgcService)
        
        VgcManager.peripheral.motion.updateInterval = 1/60
        
        VgcManager.peripheral.motion.enableAttitude = true
        VgcManager.peripheral.motion.enableGravity = true
        VgcManager.peripheral.motion.enableRotationRate = true
        VgcManager.peripheral.motion.enableUserAcceleration = true
        
        VgcManager.peripheral.motion.enableAdaptiveFilter = true
        VgcManager.peripheral.motion.enableLowPassFilter = true
        
        VgcManager.peripheral.motion.start()
        
    }
 */

    
}
