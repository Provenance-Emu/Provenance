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

/// Metal-texture render delegate for Vulkan→Metal bridge.
/// Implemented by the Metal view controller to receive per-frame MTLTextures
/// from Vulkan cores running via MoltenVK (PVThinLibretroFrontend).
///
/// Flow:
///   1. Core calls set_image and/or set_command_buffers (order varies per core)
///   2. Frontend submits command buffers to VkQueue via vkQueueSubmit
///   3. Frontend extracts MTLTexture via vkGetMTLTextureMVK / vkExportMetalObjectsEXT
///   4. Frontend calls didRenderFrameWithMTLTexture(_:) → presenter blits to display
/// Note: set_image may be called before or after set_command_buffers depending on the core.
@objc public protocol PVRenderDelegateMetal: NSObjectProtocol {
    /// Called from the emulation thread when a Vulkan core has finished rendering
    /// a frame. The texture is backed by MoltenVK's internal Metal resources.
    /// The receiver should blit or display this texture on the next draw call.
    @objc optional func didRenderFrameWithMTLTexture(_ texture: MTLTexture)
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
