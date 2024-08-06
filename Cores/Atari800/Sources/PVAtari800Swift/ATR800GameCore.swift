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
public final class ATR800GameCore: PVEmulatorCore {
    @MainActor
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    @MainActor
    public var mouseMovedHandler: GCExtendedGamepadValueChangedHandler? = nil
    @MainActor
    public var keyChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
}
