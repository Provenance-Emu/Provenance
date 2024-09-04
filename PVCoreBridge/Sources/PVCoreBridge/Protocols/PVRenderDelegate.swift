//
//  PVRenderDelegate.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

// MARK: Delegate Protocols

import Foundation
#if USE_METAL
import Metal
import MetalKit
#endif

@objc public protocol PVRenderDelegate {
    // Required methods
    @objc optional dynamic func startRenderingOnAlternateThread()
    @objc optional dynamic func didRenderFrameOnAlternateThread()

    /*!
     * @property presentationFramebuffer
     * @discussion
     * 2D - Not used.
     * 3D - For cores which can directly render to a GL FBO or equivalent,
     * this will return the FBO which game pixels eventually go to. This
     * allows porting of cores that overwrite GL_DRAW_FRAMEBUFFER.
     */
    @objc optional dynamic var presentationFramebuffer: AnyObject? { get }

    // Optional property
#if USE_METAL
    @objc(optional) dynamic var mtlView: MTKView? { get set }
#endif
}

public extension PVRenderDelegate {
    // Optional method
    func startRenderingOnAlternateThread() {}
    func didRenderFrameOnAlternateThread() {}
    var presentationFramebuffer: AnyObject? { return nil }
    
#if USE_METAL
    var mtlView: MTKView? { return nil }
#endif
}


public
extension PVRenderDelegate where Self: ObjCBridedCore {
    func startRenderingOnAlternateThread() {
        (self as PVRenderDelegate).startRenderingOnAlternateThread()
        core.startRenderingOnAlternateThread()
    }
    
    func didRenderFrameOnAlternateThread() {
        (self as PVRenderDelegate).didRenderFrameOnAlternateThread()
        core.didRenderFrameOnAlternateThread()
    }
    
    var presentationFramebuffer: AnyObject? {
        return (self as PVRenderDelegate).presentationFramebuffer ?? core.presentationFramebuffer
    }
    
#if USE_METAL
    var mtlView: MTKView? {
        return (self as PVRenderDelegate).mtlView ?? core.mtlView
    }
#endif
}
