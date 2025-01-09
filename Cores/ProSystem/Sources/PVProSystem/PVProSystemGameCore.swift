//
//  PVJaguarGameCore.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 5/21/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
#if canImport(GameController)
import GameController
#endif
#if canImport(OpenGLES)
import OpenGLES
import OpenGLES.ES3
#endif
import PVLogging
import PVAudio
import PVEmulatorCore
import PVCoreObjCBridge
import PVProSystemBridge

@objc
@objcMembers
open class PVProSystemCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Lifecycle
    lazy var _bridge: PVProSystemGameCore = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVProSystemCore: PV7800SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV7800Button, forPlayer player: Int) {
        (_bridge as! PV7800SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PV7800Button, forPlayer player: Int) {
        (_bridge as! PV7800SystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func mouseMoved(at point: CGPoint) {
        (_bridge as! PV7800SystemResponderClient).mouseMoved(at: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        (_bridge as! PV7800SystemResponderClient).leftMouseDown(at: point)
    }
    public func leftMouseUp() {
        (_bridge as! PV7800SystemResponderClient).leftMouseUp()
    }
}

@objc
public extension PVProSystemCore {

    @objc(BUTTON_SWIFT) enum BUTTON: Int {
        case u = 0
        case d = 1
        case l = 2
        case r = 3
        case s = 4
        case seven = 5
        case four = 6
        case one = 7
        case zero = 8
        case eight = 9
        case five = 10
        case two = 11
        case d_ = 12
        case nine = 13
        case six = 14
        case three = 15
        case a = 16
        case b = 17
        case c = 18
        case option = 19
        case pause = 20

        static var first: BUTTON { u }
        static var last: BUTTON { .pause }
    }

    @objc func getIndexForPVJaguarButton(_ btn: PVJaguarButton) -> Int {
        switch btn {
        case .up:
            return BUTTON.u.rawValue
        case .down:
            return BUTTON.d.rawValue
        case .left:
            return BUTTON.l.rawValue
        case .right:
            return BUTTON.r.rawValue
        case .a:
            return BUTTON.a.rawValue
        case .b:
            return BUTTON.b.rawValue
        case .c:
            return BUTTON.c.rawValue
        case .pause:
            return BUTTON.pause.rawValue
        case .option:
            return BUTTON.option.rawValue
        case .button1:
            return BUTTON.one.rawValue
        case .button2:
            return BUTTON.two.rawValue
        case .button3:
            return BUTTON.three.rawValue
        case .button4:
            return BUTTON.four.rawValue
        case .button5:
            return BUTTON.five.rawValue
        case .button6:
            return BUTTON.six.rawValue
        case .button7:
            return BUTTON.seven.rawValue
        case .button8:
            return BUTTON.eight.rawValue
        case .button9:
            return BUTTON.nine.rawValue
        case .button0:
            return BUTTON.zero.rawValue
        case .asterisk:
            return BUTTON.s.rawValue
        case .pound:
            return BUTTON.d_.rawValue
        case .count:
            return -1
        }
    }
    
    @objc override var supportsSaveStates: Bool { return true }
    
#if canImport(OpenGLES) || canImport(OpenGL)
    @objc override var pixelFormat: GLenum { GLenum(GL_BGRA) }
    @objc override var pixelType: GLenum { GLenum(GL_UNSIGNED_BYTE) }
    @objc override var internalPixelFormat: GLenum { GLenum(GL_RGBA) }
#endif
//    @objc override open var frameInterval: TimeInterval {
//        return vjs.hardwareTypeNTSC ? 60.0 : 50.0
//    }
    
//    @objc override public var videoBuffer: UnsafeMutableRawPointer<UInt16>? {
//        guard let jagVideoBuffer = jagVideoBuffer else {
//            return nil
//        }
//        return UnsafeMutableRawPointer(jagVideoBuffer.pointee.sampleBuffer)
//    }
}
