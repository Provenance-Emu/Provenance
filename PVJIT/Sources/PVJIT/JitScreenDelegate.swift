// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation

@objc
protocol JitScreenDelegate : AnyObject {
  func didFinishJitScreen(result: Bool, sender: Any)
}
