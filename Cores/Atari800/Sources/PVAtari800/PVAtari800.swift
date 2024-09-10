//
//  ATR800GameCore.swift
//  PVAtari800
//
//  Created by Joseph Mattiello on 5/23/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVSupport
import PVAtari800Bridge
#if canImport(GameController)
import GameController
#endif

@objc
@objcMembers
public final class PVAtari800: PVEmulatorCore, ObjCBridgedCore, @unchecked Sendable {
    
    // PVEmulatorCoreBridged
    public typealias Bridge = PVAtari800Bridge
    public lazy var bridge: Bridge = {
        let core = PVAtari800Bridge()
        return core
    }()

#if canImport(GameController)
    @MainActor
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
#endif
    @MainActor
    public var mouseMovedHandler: GCExtendedGamepadValueChangedHandler? = nil
    @MainActor
    public var keyChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
}
