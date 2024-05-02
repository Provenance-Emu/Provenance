// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.
#if os(iOS)

import Foundation

@objc class JitFailedJailbreakScreenViewController : UIViewController
{
  @objc weak var delegate: JitScreenDelegate?
  @IBOutlet weak var specificErrorLabel: UILabel!
  
  override func viewDidLoad()
  {
    let auxError = DOLJitManager.shared().getAuxiliaryError()
    if (auxError != nil)
    {
      self.specificErrorLabel.text = auxError
    }
  }
  
  @IBAction func okPressed(_ sender: Any)
  {
    // Always return false so that emulation never starts
    self.delegate?.didFinishJitScreen(result: false, sender: self)
  }
  
}
#endif
