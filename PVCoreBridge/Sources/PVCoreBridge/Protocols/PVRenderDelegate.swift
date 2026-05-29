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
/// Frame delivery flow (callback order varies per core):
///   1. Core calls set_image and/or set_command_buffers in any order
///   2. Frontend submits command buffers (if any) to VkQueue via vkQueueSubmit
///   3. Frontend waits for GPU completion (vkQueueWaitIdle) to ensure the image is safe to export
///   4. Frontend extracts MTLTexture via vkGetMTLTextureMVK / vkExportMetalObjectsEXT
///   5. Frontend calls didRenderFrameWithMTLTexture(_:) → presenter blits to display
/// Note: set_image is called before set_command_buffers in some cores (e.g. libretro-test-vulkan).
///       Async-compute cores may call only set_image with no set_command_buffers at all.
@objc public protocol PVRenderDelegateMetal: NSObjectProtocol {
    /// Called from the emulation thread when a Vulkan core has finished rendering
    /// a frame. The texture is backed by MoltenVK's internal Metal resources.
    /// The receiver should blit or display this texture on the next draw call.
    ///
    /// - Warning: The passed texture aliases the core's *live* VkImage. The
    ///   receiver MUST NOT retain it past the call and MUST NOT sample it on
    ///   another thread — the core may recycle the VkImage on its next frame.
    ///   For Vulkan cores prefer `didRenderVulkanFrameWithMTLTexture(_:)`, which
    ///   defines an explicit copy-and-decouple contract that is safe across the
    ///   emulation/main-thread boundary.
    @objc optional func didRenderFrameWithMTLTexture(_ texture: MTLTexture)

    /// Called from the **emulation thread** when a Vulkan (MoltenVK) core has
    /// finished a frame and its `vkQueueSubmit` has been waited on (the VkImage
    /// is GPU-coherent and safe to read on this thread *right now*).
    ///
    /// The supplied `texture` aliases the core's live VkImage. Unlike
    /// `didRenderFrameWithMTLTexture(_:)`, the implementation of this method MUST,
    /// before returning:
    ///   1. Copy `texture` into a presenter-owned private `MTLTexture` via a Metal
    ///      blit on the emulation thread.
    ///   2. Wait for that blit to complete on the GPU (`waitUntilCompleted`) so the
    ///      core may safely recycle/realloc its VkImage on the next frame — this is
    ///      the GPU-side backpressure that prevents a use-after-free of the VkImage
    ///      while Metal is still sampling it on the main thread.
    ///   3. Publish the private copy as the texture the main-thread `draw(in:)`
    ///      path samples, under the same `frontBufferLock` used by the OpenGL path.
    ///
    /// This mirrors the proven OpenGL `didRenderFrameOnAlternateThread()` handshake
    /// (blit the live HW surface into a private texture under `frontBufferLock`,
    /// then signal `frontBufferCondition`) for the Vulkan→Metal interop path.
    @objc optional func didRenderVulkanFrameWithMTLTexture(_ texture: MTLTexture)
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
