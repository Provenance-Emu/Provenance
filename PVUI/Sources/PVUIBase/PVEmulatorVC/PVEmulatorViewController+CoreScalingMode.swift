//
//  PVEmulatorViewController+CoreScalingMode.swift
//  PVUIBase
//

import Combine
import Foundation
import PVCoreBridge
import PVSettings

extension PVEmulatorViewController {

    /// Cores that draw into their own view (Dolphin, PPSSPP, the RetroArch wrapper)
    /// never get their frame from the host's scaling-mode maths, so hand them the
    /// mode to apply with their own renderer settings: once now, then on every change.
    func forwardScalingModeToCoreIfNeeded() {
        guard scalingModeCancellable == nil,
              let target = core.bridge as? EmulatorCoreScalingModeApplying else { return }
        target.applyUserScalingMode()
        scalingModeCancellable = Defaults.publisher(.scalingMode)
            .receive(on: DispatchQueue.main)
            .sink { [weak target] _ in
                target?.applyUserScalingMode()
            }
    }
}
