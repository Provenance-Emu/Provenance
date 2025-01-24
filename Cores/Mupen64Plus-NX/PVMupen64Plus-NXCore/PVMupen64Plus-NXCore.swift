//
//  MupenGameCore.swift
//  PVMupenGameCore
//
//  Created by Joseph Mattiello on 8/18/24.
//
import Foundation
import GameController
import PVSupport
import PVCoreBridge
import PVLogging
import PVEmulatorCore
import PVSettings
import Defaults
import PVMupen64PlusBridge

//#if SWIFT_MODULE
//import PVMupen64PlusCore
//#endif

#if os(iOS)
import UIKit
#endif

#if os(macOS) || targetEnvironment(macCatalyst)
import OpenGL.GL3
import GLUT
#elseif !os(watchOS)
import OpenGLES
import GLKit
#endif

//#if os(tvOS)
//let RESIZE_TO_FULLSCREEN: Bool = true
//#else
//let RESIZE_TO_FULLSCREEN: Bool = Defaults[.nativeScaleEnabled]
//#endif
//
//extension m64p_core_param: @retroactive Hashable, @retroactive Equatable, @retroactive Codable {
//    
//}

@objc public class PVMupen64PlusNXCore: PVEmulatorCore, @unchecked Sendable {
    
    // MARK: - Initialization
    
    public var _bridge: PVMupen64PlusNXCoreBridge = .init()
    
    required init() {
        super.init()
        self.bridge = (PVMupen64PlusNXCoreBridge() as! any ObjCBridgedCoreBridge)
    }
}

// MARK: - Extensions

extension PVMupen64PlusNXCore: PVN64SystemResponderClient {
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: PVCoreBridge.PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didPush(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVMupen64PlusNXCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVMupen64PlusNXCoreOptions.options
    }
}

//
//#if !os(macOS)
//extension MupenGameCore: GLKViewDelegate {
//#warning("Finish me")
//    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
//        
//    }
//}
//#endif
