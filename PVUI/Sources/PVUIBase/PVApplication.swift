//
//  PVApplication.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//
//
#if canImport(UIKit)
import UIKit
import PVEmulatorCore

public
final class PVApplication: UIApplication {
    public override func sendEvent(_ event: UIEvent) {
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }
        super.sendEvent(event)
    }
    
    public override func sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }
        return super.sendAction(action, to: target, from: sender, for: event)
    }
}
#endif
