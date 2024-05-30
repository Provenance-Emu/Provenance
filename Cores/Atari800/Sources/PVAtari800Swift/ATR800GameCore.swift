//
//  ATR800GameCore.swift
//  PVAtari800
//
//  Created by Joseph Mattiello on 5/23/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
@_exported import PVEmulatorCore
@_exported import PVSupport

@objc
@objcMembers
open class ATR800GameCore: PVEmulatorCore {
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    public var mouseMovedHandler: GCExtendedGamepadValueChangedHandler? = nil
    public var keyChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
}
