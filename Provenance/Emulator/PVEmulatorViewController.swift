//
//  PVEmulatorViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 2/13/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

extension PVEmulatorViewController {
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        //Notifies UIKit that your view controller updated its preference regarding the visual indicator
        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        #if os(iOS)
        stopVolumeControl()
        #endif
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if os(iOS)
            startVolumeControl()
            UIApplication.shared.setStatusBarHidden(true, with: .fade)
        #endif
    }
}

// Inherits the default behaviour
extension PVEmulatorViewController : VolumeController {
    
}
