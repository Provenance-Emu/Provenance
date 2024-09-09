//
//  PVPicoDrive.swift
//
//
//  Created by Joseph Mattiello on 5/27/24.
//

import Foundation
@_exported import PVEmulatorCore
@_exported import PVCoreBridge
@_exported import GameController

@objc
@objcMembers
public class PicodriveGameCore: PVEmulatorCore, @unchecked Sendable {

    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    public var audioStream: UnsafeMutablePointer<UInt8>?

    public var _videoBuffer: UnsafeMutablePointer<UInt16>? = nil
    public var _videoBufferA: UnsafeMutablePointer<UInt16>? = nil
    public var _videoBufferB: UnsafeMutablePointer<UInt16>? = nil

    public var videoWidth: Int = 0
    public var videoHeight: Int = 0
    public var romPath: String? = nil //    NSString *romName;

    public var _sampleRate: Double = 0
    public var _frameInterval: TimeInterval = 0

//    @objc
//    public var pad: [[UInt16]]?
    //    int16_t _pad[2][12];
}
