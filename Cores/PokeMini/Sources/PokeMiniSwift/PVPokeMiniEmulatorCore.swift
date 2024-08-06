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
public final class PokeMFiState: NSObject, @unchecked Sendable {
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
public final class PVPokeMiniEmulatorCore: PVEmulatorCore {

    @objc
    @MainActor
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    public let controllerState: PokeMFiState = .init()

    @objc
    @MainActor
    public var audioStream: UnsafeMutablePointer<UInt8>?

    @MainActor
    public var _videoBuffer: UnsafeMutablePointer<UInt32>? = nil

//    @objc
//    public var videoBuffer: UnsafeMutableBufferPointer<UInt32> {
//        get {
//            _videoBuffer?.bindMemory(to: UInt32.self, capacity: videoWidth * videoHeight) ?? UnsafeMutableBufferPointer<UInt32>.init(start: nil, count: 0)
//        }
//    }


    /// Width in pixels
    /// Bindable

    @MainActor
    @objc
    public var videoWidth: Int = 0
    @MainActor
    public var videoHeight: Int = 0
    @MainActor
    public var romPath: String?
}
