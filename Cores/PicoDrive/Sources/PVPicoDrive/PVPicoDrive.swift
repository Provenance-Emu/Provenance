//
//  PVPicoDrive.swift
//
//
//  Created by Joseph Mattiello on 5/27/24.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVPicoDriveBridge
#if canImport(GameController)
import GameController
#endif

@objc
@objcMembers
public class PVPicoDrive: PVEmulatorCore, ObjCBridgedCore, @unchecked Sendable {

    // PVEmulatorCoreBridged
    public typealias Bridge = PVPicoDriveBridge
    public lazy var bridge: Bridge = {
        let core = PVPicoDriveBridge()
        return core
    }()
    
#if canImport(GameController)
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
#endif
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
