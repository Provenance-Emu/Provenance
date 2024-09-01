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
    open var alwaysUseMetal: Bool { false }
    open var aspectSize: CGSize { .zero }

    open var emulationFPS: Double {
        0.0
    }

    open var isDoubleBuffered: Bool {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.isDoubleBuffered
        } else {
            return false
        }
    }
    
#if canImport(OpenGL) || canImport(OpenGLES)
    open var depthFormat: GLenum { 0 }
    open var internalPixelFormat: GLenum  {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.internalPixelFormat
        } else {
            return GLenum(GL_UNSIGNED_SHORT_5_6_5)
        }
    }

    
    open var pixelFormat: GLenum  {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.pixelFormat
        } else {
            return GLenum(GL_RGBA)
        }
    }
    
    open var pixelType: GLenum {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.pixelType
        } else {
            return GLenum(GL_UNSIGNED_SHORT_5_6_5)
        }
    }
#endif
    
    open var renderFPS: Double { 0.0 }
    
    open var rendersToOpenGL: Bool {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.rendersToOpenGL
        } else {
            return false
        }
    }
   
    open var screenRect: CGRect {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.screenRect
        } else {
            return .zero
        }
    }

    @objc
    @MainActor
    open var videoBuffer: UnsafeMutableRawPointer? {
        if let objcBridge = self as? ObjCCoreBridge {
            return objcBridge.videoBuffer
        } else {
            return nil
        }
    }

//    @MainActor
    open var videoBufferSize: CGSize { .zero }

    // Requires Override
    @objc
    open func executeFrame() {
        if let objcBridge = self as? ObjCCoreBridge {
            objcBridge.executeFrame()
        } else {
            assertionFailure("Should be implimented in subclasses")
        }
    }

    @objc
    open func swapBuffers() {
        if let objcBridge = self as? ObjCCoreBridge, self.isDoubleBuffered {
            objcBridge.swapBuffers()
        } else {
            assert(!self.isDoubleBuffered, "Cores that are double-buffered must implement swapBuffers!")
        }
    }
}
