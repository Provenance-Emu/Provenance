//
//  PVAppDelegate+Helpers.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import UIKit

// MARK: - JIT
extension PVAppDelegate {
    public func enableJIT() {
#if os(iOS)
        guard !DOLJitManager.shared().appHasAcquiredJit() else {
            ILOG("JIT: JIT already enabled")
            return
        }
        if PVSettingsModel.shared.debugOptions.autoJIT {
            _enableJIT()
        }
#else
        WLOG("JIT: JIT not supported on this system yet.")
#endif
    }
    
#if os(iOS)
    public func showJITWaitScreen() {
        if PVSettingsModel.shared.debugOptions.autoJIT {
            guard !DOLJitManager.shared().appHasAcquiredJit() else {
                ILOG("JIT: JIT already enabled")
                return
            }
            _showJITWaitScreen()
        }
    }
    
    fileprivate func _showJITWaitScreen() {
        let controller = JitWaitScreenViewController(nibName: "JitWaitScreen", bundle: nil)
        self.jitWaitScreenVC = controller
        controller.delegate = self
        jitScreenDelegate = self
        controller.isModalInPresentation = true
        
        guard let rootNavigation = gameLibraryViewController ?? rootNavigationVC ?? (window?.rootViewController as? UIViewController) else {
            fatalError("JIT: No root nav controller")
        }
        (rootNavigation.presentedViewController ?? rootNavigation).present(controller, animated: true)
    }
    
    fileprivate func _enableJIT() {
        guard !DOLJitManager.shared().appHasAcquiredJit() else {
            ILOG("JIT: JIT already enabled")
            return
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(jitAcquired), name: NSNotification.Name.DOLJitAcquired, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(altJitFailed), name: NSNotification.Name.DOLJitAltJitFailure, object: nil)
        jitScreenDelegate = self

        DOLJitManager.shared().attemptToAcquireJitByWaitingForDebugger(using: self.cancellation_token)

        let device_id = Bundle.main.object(forInfoDictionaryKey: "ALTDeviceID") as! String
        if (device_id != "dummy") {
            // ALTDeviceID has been set, so we should attempt to acquire by AltJIT instead
            // of just sitting around and waiting for a debugger.
            DOLJitManager.shared().attemptToAcquireJitByAltJIT()
        }

        // We can always try this. If the device is not connected to the VPN, then this request will just silently fail.
        DOLJitManager.shared().attemptToAcquireJitByJitStreamer()
    }
    
    @objc func jitAcquired(notification: Notification) {
        DispatchQueue.main.async { [unowned self] in
            self.jitScreenDelegate?.didFinishJitScreen(result: true, sender: self)
        }
    }
    
    @objc func altJitFailed(notification: Notification) {
        let error_string: String
        
        if let error = notification.userInfo!["nserror"] as? NSError {
            error_string = error.localizedDescription
        } else {
            error_string = "No error message available."
        }
        
        while (self.is_presenting_alert) {
            // Wait for the alert to be dismissed.
            sleep(1)
        }
        
        DispatchQueue.main.async { [unowned self] in
            print("Error: Failed to Contact AltJIT\n")
            let alert = UIAlertController.init(title: "Failed to Contact AltJIT", message: error_string, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction.init(title: "Wait for Other Debugger", style: .default, handler: { _ in
                self.is_presenting_alert = false
            }))
            
            alert.addAction(UIAlertAction.init(title: "Retry AltJIT", style: .default, handler: { _ in
                self.is_presenting_alert = false
                
                DOLJitManager.shared().attemptToAcquireJitByAltJIT()
            }))
            
            alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: { _ in
                self.is_presenting_alert = false
                
                self.cancellation_token.cancel()
                
                self.jitScreenDelegate?.didFinishJitScreen(result: false, sender: self)
            }))
            
            self.is_presenting_alert = true
            
            guard let vc: UIViewController = gameLibraryViewController?.presentedViewController ?? gameLibraryViewController ?? rootNavigationVC?.presentedViewController ?? rootNavigationVC else {
                ELOG("JIT: No VC to present from")
                return
            }

            vc.present(alert, animated: true)
        }
    }
    
    @IBAction func helpPressed(_ sender: Any) {
        let url = URL.init(string: "https://wiki.provenance-emu.com/jit-help")!
        UIApplication.shared.open(url)
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        self.cancellation_token.cancel()
        
        self.jitScreenDelegate?.didFinishJitScreen(result: false, sender: self)
    }
#endif
}

#if os(iOS)
// MARK: - JIT Screen Delegate
extension PVAppDelegate: JitScreenDelegate {
    func didFinishJitScreen(result: Bool, sender: Any) {
        ILOG("JIT: Result: \(result) Sender: \(String(describing: sender))")
        if let jitWaitScreenVC = jitWaitScreenVC {
            VLOG("JIT: jitWaitScreenVC being dismissed")
            jitWaitScreenVC.dismiss(animated: true)
        } else if let sender = sender as? UIViewController {
            VLOG("JIT: sender as? UIViewController")
            sender.dismiss(animated: true)
        } else {
            DLOG("JIT: No vc to dismiss?")
//            rootNavigationVC?.presentedViewController?.dismiss(animated: true)
        }
        
        guard result else {
            return
        }
    }
}
#endif
