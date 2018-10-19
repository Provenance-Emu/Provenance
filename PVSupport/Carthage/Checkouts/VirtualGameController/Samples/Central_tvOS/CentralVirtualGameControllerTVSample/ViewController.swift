//
//  ViewController.swift
//  CentralVirtualGameControllerTVSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import VirtualGameController

class ViewController: VgcCentralViewController {
    
    override func viewDidLoad() {
        
        // Use a compiler flag to control the logging level, dropping it to just errors if this
        // is a release build.
        #if Release
            VgcManager.loggerLogLevel = .Error // Minimal logging
        #else
            VgcManager.loggerLogLevel = .Debug // Robust logging
        #endif
        
        VgcManager.loggerUseNSLog = true
        
        // Publishes the central service
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false)

        super.viewDidLoad()
        
    }

}


