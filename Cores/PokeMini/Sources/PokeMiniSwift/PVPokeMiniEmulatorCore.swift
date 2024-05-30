//
//  PVPokeMiniEmulatorCore.swift
//  PVPokeMini
//
//  Created by Joseph Mattiello on 5/25/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation

@_exported import PVEmulatorCore
@_exported import PVCoreBridge
import PokeMiniC

@objc
@objcMembers
public final class PokeMFiState: NSObject {
    public var a: Bool = false
    public var b: Bool = false
    public var c: Bool = false
    public var d: Bool = false
    public var up: Bool = false
    public var down: Bool = false
    public var left: Bool = false
    public var right: Bool = false
    public var menu: Bool = false
    public var power: Bool = false
    public var shake: Bool = false
}

@objc
@objcMembers
public class PVPokeMiniEmulatorCore: PVEmulatorCore {

    @objc
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    public var controllerState: PokeMFiState = .init()

    @objc
    public var audioStream: UnsafeMutablePointer<UInt8>?

    public var _videoBuffer: UnsafeMutablePointer<UInt32>? = nil
    public var videoWidth: Int = 0
    public var videoHeight: Int = 0
    public var romPath: String?
}
