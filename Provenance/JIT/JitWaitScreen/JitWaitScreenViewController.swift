// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#if os(iOS)

import Foundation
@objc final class JitWaitScreenViewController : UIViewController {
  @objc weak var delegate: JitScreenDelegate?
  var cancellation_token = DOLCancellationToken()
  var is_presenting_alert = false
  
  override func viewDidLoad() {
    NotificationCenter.default.addObserver(self, selector: #selector(jitAcquired), name: NSNotification.Name.DOLJitAcquired, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(altJitFailed), name: NSNotification.Name.DOLJitAltJitFailure, object: nil)
    
    DOLJitManager.shared().attemptToAcquireJitByWaitingForDebugger(using: cancellation_token)
    
    let device_id = Bundle.main.object(forInfoDictionaryKey: "ALTDeviceID") as! String
    if (device_id != "dummy") {
      // ALTDeviceID has been set, so we should attempt to acquire by AltJIT instead
      // of just sitting around and waiting for a debugger.
      DOLJitManager.shared().attemptToAcquireJitByAltJIT()
    }
    
    // We can always try this. If the device is not connected to the VPN, then this request will just silently fail.
    DOLJitManager.shared().attemptToAcquireJitByJitStreamer()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    if let auxError = DOLJitManager.shared().getAuxiliaryError() {
      self.is_presenting_alert = true
      
      let controller = UIAlertController(title: "Failed to Activate Workaround", message: "Provenance attempted to enable JIT with a different workaround, but the following error was returned:\n\n\(auxError)\n\nProvenance will now fallback to waiting for a remote debugger.", preferredStyle: .alert)
      controller.addAction(UIAlertAction.init(title: "OK", style: .default, handler: { _ in
        self.is_presenting_alert = false
      }))
      
      self.present(controller, animated: true, completion: nil)
    }
  }
  
  @objc func jitAcquired(notification: Notification) {
    DispatchQueue.main.async {
      self.delegate?.didFinishJitScreen(result: true, sender: self)
    }
  }
  
  @objc func altJitFailed(notification: Notification) {
    let error_string: String
    
    if let error = notification.userInfo!["nserror"] as? NSError {
      error_string = error.localizedDescription
    }
    else {
      error_string = "No error message available."
    }
    
    while (self.is_presenting_alert) {
      // Wait for the alert to be dismissed.
      sleep(1)
    }
    
    DispatchQueue.main.async {
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
        
        self.delegate?.didFinishJitScreen(result: false, sender: self)
      }))
      
      self.is_presenting_alert = true
      
      self.present(alert, animated: true, completion: nil)
    }
  }
  
  @IBAction func helpPressed(_ sender: Any) {
    let url = URL.init(string: "https://wiki.provenance-emu/jit")
    UIApplication.shared.open(url!, options: [:], completionHandler: nil)
  }
  
  @IBAction func cancelPressed(_ sender: Any) {
    self.cancellation_token.cancel()
    
    self.delegate?.didFinishJitScreen(result: false, sender: self)
  }
}
#endif
