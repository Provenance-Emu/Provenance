//
//  PVAppDelegate+Helpers.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//
#if canImport(PVJIT)
import PVJIT
import Foundation
import UIKit
import PVSettings
import JITManager
import PVLogging

// MARK: - JIT
extension PVAppDelegate {
    public func enableJIT() {
        #if os(iOS) || os(tvOS)
        guard !DOLJitManager.shared.appHasAcquiredJit() else {
            ILOG("JIT: JIT already enabled")
            return
        }
        if Defaults[.autoJIT] {
            _enableJIT()
        }
        #else
        // The app-side JIT onboarding and wait UI is only wired up for iOS/tvOS today.
        WLOG("JIT: JIT not supported on this system yet.")
        #endif
    }

    #if os(iOS) || os(tvOS)
    public func showJITWaitScreen() {
        if Defaults[.autoJIT] {
            guard !DOLJitManager.shared.appHasAcquiredJit() else {
                ILOG("JIT: JIT already enabled")
                return
            }
            _showJITWaitScreen()
        }
    }

    fileprivate func _showJITWaitScreen() {
        let controller = JitWaitScreenViewController()
        jitWaitScreenVC = controller
        controller.delegate = self
        jitScreenDelegate = self
        controller.isModalInPresentation = true

        guard let rootNavigation = jitPresentingViewController else {
            fatalError("JIT: No root nav controller")
        }
        (rootNavigation.presentedViewController ?? rootNavigation).present(controller, animated: true)
    }

    fileprivate func _enableJIT() {
        guard !DOLJitManager.shared.appHasAcquiredJit() else {
            ILOG("JIT: JIT already enabled")
            return
        }

        NotificationCenter.default.addObserver(self, selector: #selector(jitAcquired), name: NSNotification.Name.DOLJitAcquired, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(altJitFailed), name: NSNotification.Name.DOLJitAltJitFailure, object: nil)
        jitScreenDelegate = self

        DOLJitManager.shared.attemptToAcquireJitByWaitingForDebugger(using: cancellation_token)

        let deviceID = Bundle.main.object(forInfoDictionaryKey: "ALTDeviceID") as? String
        if let deviceID, deviceID != "dummy" {
            // ALTDeviceID has been set, so we should attempt to acquire by AltJIT instead
            // of just sitting around and waiting for a debugger.
            DOLJitManager.shared.attemptToAcquireJitByAltJIT()
        }

        // We can always try this. If the device is not connected to the VPN, then this request will just silently fail.
        DOLJitManager.shared.attemptToAcquireJitByJitStreamer()
    }

    @objc func jitAcquired(notification: Notification) {
        DispatchQueue.main.async { [unowned self] in
            jitScreenDelegate?.didFinishJitScreen(result: true, sender: self)
        }
    }

    @objc func altJitFailed(notification: Notification) {
        let errorString: String
        if let error = notification.userInfo?["nserror"] as? NSError {
            errorString = error.localizedDescription
        } else {
            errorString = "No error message available."
        }

        while is_presenting_alert {
            // Wait for the alert to be dismissed.
            sleep(1)
        }

        DispatchQueue.main.async { [unowned self] in
            print("Error: Failed to Contact AltJIT\n")
            let alert = UIAlertController(title: "Failed to Contact AltJIT", message: errorString, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Wait for Other Debugger", style: .default) { _ in
                self.is_presenting_alert = false
            })

            alert.addAction(UIAlertAction(title: "Retry AltJIT", style: .default) { _ in
                self.is_presenting_alert = false
                DOLJitManager.shared.attemptToAcquireJitByAltJIT()
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.is_presenting_alert = false
                self.cancellation_token.cancel()
                self.jitScreenDelegate?.didFinishJitScreen(result: false, sender: self)
            })

            self.is_presenting_alert = true

            guard let vc = self.jitPresentingViewController else {
                ELOG("JIT: No VC to present from")
                return
            }

            vc.present(alert, animated: true)
        }
    }

    @IBAction func helpPressed(_ sender: Any) {
        guard let url = URL(string: "https://wiki.provenance-emu.com/jit-help") else {
            ELOG("JIT: Invalid help URL")
            return
        }
        UIApplication.shared.open(url)
    }

    @IBAction func cancelPressed(_ sender: Any) {
        cancellation_token.cancel()
        jitScreenDelegate?.didFinishJitScreen(result: false, sender: self)
    }

    private var jitPresentingViewController: UIViewController? {
        gameLibraryViewController?.presentedViewController ?? gameLibraryViewController ?? rootNavigationVC?.presentedViewController ?? rootNavigationVC
    }
    #endif
}

    #if os(iOS) || os(tvOS)
    // MARK: - JIT Screen Delegate
    extension PVAppDelegate: JitScreenDelegate {
        public func didFinishJitScreen(result: Bool, sender: Any) {
            ILOG("JIT: Result: \(result) Sender: \(String(describing: sender))")
            if let jitWaitScreenVC {
                VLOG("JIT: jitWaitScreenVC being dismissed")
                jitWaitScreenVC.dismiss(animated: true)
            } else if let sender = sender as? UIViewController {
                VLOG("JIT: sender as? UIViewController")
                sender.dismiss(animated: true)
            } else {
                DLOG("JIT: No vc to dismiss?")
                // rootNavigationVC?.presentedViewController?.dismiss(animated: true)
            }

            guard result else {
                return
            }
        }
    }
    #endif
#endif // If can import
