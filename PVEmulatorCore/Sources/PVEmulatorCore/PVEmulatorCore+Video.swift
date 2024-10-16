//
//  PVEmulatorCore+Video.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import PVLogging

#if canImport(OpenGL)
import OpenGL
import OpenGL.GL3
#elseif canImport(OpenGLES)
import OpenGLES
import OpenGLES.ES3
#endif

@objc
extension PVEmulatorCore: EmulatorCoreVideoDelegate {
    
    open var alwaysUseMetal: Bool {
        return bridge.alwaysUseMetal
    }
    
    open var alwaysUseGL: Bool {
        return bridge.alwaysUseGL
    }
    
    open var aspectSize: CGSize {
        return bridge.aspectSize
    }

    open var emulationFPS: Double {
        bridge.emulationFPS
    }

    open var isDoubleBuffered: Bool {
        bridge.isDoubleBuffered
    }
    
#if canImport(OpenGL) || canImport(OpenGLES)
    open var depthFormat: GLenum {
        bridge.depthFormat
    }
    
    open var internalPixelFormat: GLenum  {
        bridge.internalPixelFormat
    }
    
    open var pixelFormat: GLenum  {
        bridge.pixelFormat
    }
    
    open var pixelType: GLenum {
        bridge.pixelType
    }
#endif
    
    open var renderFPS: Double {
        bridge.renderFPS
    }
    
    open var rendersToOpenGL: Bool {
        bridge.rendersToOpenGL
    }
   
    open var screenRect: CGRect {
        bridge.screenRect
    }

//    @MainActor
    @objc
    open var videoBuffer: UnsafeMutableRawPointer? {
        bridge.videoBuffer
    }

//    @MainActor
    open var bufferSize: CGSize {
        bridge.bufferSize
    }

    // Requires Override
    @objc
    open func executeFrame() {
        bridge.executeFrame()
    }

    @objc
    open func swapBuffers() {
        guard  self.isDoubleBuffered else {
            assert(!self.isDoubleBuffered, "Cores that are double-buffered must implement swapBuffers!")
            return
        }
        
        if let objcBridge: any ObjCBridgedCore = self as? (any ObjCBridgedCore),
            let bridge = objcBridge.bridge as? any ObjCBridgedCoreBridge & EmulatorCoreVideoDelegate,
            bridge.responds(to: #selector(bridge.swapBuffers)) {
            bridge.swapBuffers?()
        } else {
            assertionFailure("Should be implimented in subclasses")
        }
    }
}
