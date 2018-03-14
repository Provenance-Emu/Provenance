//
//  PVEmulatorViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 2/13/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport

extension PVEmulatorViewController {
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        //Notifies UIKit that your view controller updated its preference regarding the visual indicator
		
        #if os(iOS)
        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
        #endif
		
		//Ignore Smart Invert
		self.view.ignoresInvertColors = true
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

    @objc
    public func updatePlayedDuration() {
        guard let startTime = game.lastPlayed else {
            return
        }
        
        let duration = startTime.timeIntervalSinceNow * -1
        let totalTimeSpent = game.timeSpentInGame + Int(duration)

        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.timeSpentInGame = totalTimeSpent
                game.lastPlayed = Date()
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }
    
    @objc public func updateLastPlayedTime() {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.lastPlayed = Date()
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }
}

public extension PVEmulatorViewController {
    @objc
    func showSwapDiscsMenu() {
        guard let emulatorCore = self.emulatorCore as? (PVEmulatorCore & DiscSwappable) else {
            ELOG("No core?")
            return
        }
        
        let numberOfDiscs = emulatorCore.numberOfDiscs
        guard numberOfDiscs > 1 else {
            ELOG("Only 1 disc?")
            return
        }
        
        // Add action for each disc
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for index in 1...numberOfDiscs {
            actionSheet.addAction(UIAlertAction(title: "\(index)", style: .default, handler: {[unowned self] (sheet) in

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    emulatorCore.swapDisc(number: index)
                })
                
                emulatorCore.setPauseEmulation(false)

                self.isShowingMenu = false
                #if os(tvOS)
                    self.controllerUserInteractionEnabled = false
                #endif
            }))
        }

        // Add cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {[unowned self] (sheet) in
            emulatorCore.setPauseEmulation(false)
            self.isShowingMenu = false
            #if os(tvOS)
                self.controllerUserInteractionEnabled = false
            #endif
        }))

        // Present
		if traitCollection.userInterfaceIdiom == .pad {
			actionSheet.popoverPresentationController?.sourceView = menuButton
			actionSheet.popoverPresentationController?.sourceRect = menuButton?.bounds ?? .zero
		}
		
        self.present(actionSheet, animated: true) {
            PVControllerManager.shared().iCadeController?.refreshListener()
        }
    }
}

// Inherits the default behaviour
#if os(iOS)
extension PVEmulatorViewController : VolumeController {
    
}
#endif
