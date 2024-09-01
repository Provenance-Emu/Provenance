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
public final class PVPokeMiniEmulatorCore: PVEmulatorCore, @unchecked Sendable {

    #if canImport(GameController)
    @objc
    @MainActor
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
    #endif
    public let controllerState: PokeMFiState = .init()

    // MARK: Video
    
    @objc dynamic public override var rendersToOpenGL: Bool { false }
    @MainActor public var _videoBuffer: UnsafeMutablePointer<UInt32>? = nil

//    @objc dynamic public override var videoBuffer: UnsafeMutableBufferPointer<UInt32> {
//        get {
//            _videoBuffer?.withMemoryRebound(to: UInt32.self, capacity: videoWidth * videoHeight) {
//                UnsafeMutableBufferPointer(start: $0, count: videoWidth * videoHeight)
//            }
//        }
//    }

    // MARK: Audio
    
    @objc dynamic public override var audioBufferCount: UInt { 1 }
    
    @objc @MainActor
    public var audioStream: UnsafeMutablePointer<UInt8>?

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
