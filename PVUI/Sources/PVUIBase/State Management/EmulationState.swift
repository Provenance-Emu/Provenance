//
//  EmulationState.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import PVEmulatorCore
import PVCoreBridge
import SwiftUI

@MainActor
public final class EmulationState: ObservableObject {
    public var core: PVEmulatorCore?
    public var emulator: PVEmulatorViewController?
    public var isInBackground: Bool = false
}
