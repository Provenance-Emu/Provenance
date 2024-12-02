//
//  EmulationState.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import PVEmulatorCore
import PVCoreBridge
import SwiftUI
import PVLogging
import Perception

@MainActor
//@Observable
@Perceptible
public final class EmulationState: ObservableObject {
    public var core: PVEmulatorCore? {
        didSet {
            DLOG("Set core to \(core?.debugDescription ?? "nil")")
        }
    }
    public var emulator: PVEmulatorViewController?
    public var isInBackground: Bool = false
}
