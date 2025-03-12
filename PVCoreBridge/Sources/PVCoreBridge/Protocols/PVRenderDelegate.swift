//
//  PVRenderDelegate.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

// MARK: Delegate Protocols

import Foundation
//#if USE_METAL
import Metal
import MetalKit
//#endif

@objc public protocol PVRenderDelegate: AnyObject {
    // Required methods
    @objc optional func startRenderingOnAlternateThread()
    @objc optional func didRenderFrameOnAlternateThread()

    /*!
     * @property presentationFramebuffer
     * @discussion
     * 2D - Not used.
     * 3D - For cores which can directly render to a GL FBO or equivalent,
     * this will return the FBO which game pixels eventually go to. This
     * allows porting of cores that overwrite GL_DRAW_FRAMEBUFFER.
     */
    @objc optional var presentationFramebuffer: AnyObject? { get } // GLuint

    @objc func setPreferredRefreshRate(_ : Float)
    // Optional property
//#if USE_METAL
    @objc optional var mtlView: MTKView? { get set }
//#endif
    
    @objc optional var glContext: EAGLContext? { get }
    @objc optional var alternateThreadGLContext: EAGLContext? { get }
    @objc optional var alternateThreadBufferCopyGLContext: EAGLContext? { get }
}

//public extension PVRenderDelegate {
//
//    // Optional method
//    func startRenderingOnAlternateThread() {}
//    func didRenderFrameOnAlternateThread() {}
//
//    var presentationFramebuffer: AnyObject? { return nil }
//    
//#if USE_METAL
//    var mtlView: MTKView? { return nil }
//#endif
//}


//public
//extension PVRenderDelegate where Self: ObjCBridgedCore, Self.Bridge: PVRenderDelegate {
//    func startRenderingOnAlternateThread() {
//        if let startRenderingOnAlternateThread = bridge.startRenderingOnAlternateThread {
//            startRenderingOnAlternateThread()
//        } else {
//            (self as PVRenderDelegate).startRenderingOnAlternateThread?()
//        }
//    }
//    
//    func didRenderFrameOnAlternateThread() {
//        if let didRenderFrameOnAlternateThread = bridge.didRenderFrameOnAlternateThread {
//            didRenderFrameOnAlternateThread()
//        } else {
//            (self as PVRenderDelegate).didRenderFrameOnAlternateThread?()
//        }
//    }
//    
//    var presentationFramebuffer: AnyObject? {
//        if let presentationFramebuffer = bridge.presentationFramebuffer {
//            return presentationFramebuffer
//        } else {
//            return (self as PVRenderDelegate).presentationFramebuffer ?? nil
//        }
//    }
//    
//#if USE_METAL
//    var mtlView: MTKView? {
//        return bridge.mtlView ?? (self as PVRenderDelegate).mtlView ?? nil
//    }
//#endif
//}
