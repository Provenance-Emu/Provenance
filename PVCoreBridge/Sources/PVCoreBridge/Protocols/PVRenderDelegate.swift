//
//  PVRenderDelegate.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

// MARK: Delegate Protocols

import Foundation
#if canImport(IOSurface)
import IOSurface
#endif
import Metal
#if canImport(MetalKit)
import MetalKit
#endif

@objc public protocol PVRenderDelegate: NSObjectProtocol {
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
#if canImport(MetalKit)
    @objc optional var mtlView: MTKView? { get set }
#endif

#if canImport(OpenGLES)
    @objc optional var glContext: EAGLContext? { get }
    @objc optional var alternateThreadGLContext: EAGLContext? { get }
    @objc optional var alternateThreadBufferCopyGLContext: EAGLContext? { get }
#endif
}

#if canImport(IOSurface)
/// IOSurface-backed render target properties for HW-accelerated cores.
/// Emu-thread GL contexts create their own FBO and bind a texture backed
/// by this IOSurface for zero-copy rendering into the Metal display path.
@objc public protocol PVRenderDelegateIOSurface {
    @objc optional var renderIOSurface: IOSurfaceRef? { get }
    @objc optional var renderIOSurfaceSize: CGSize { get }
}
#endif

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
