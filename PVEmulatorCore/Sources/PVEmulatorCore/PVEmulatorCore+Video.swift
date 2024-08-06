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
#elseif canImport(OpenGLES)
import OpenGLES
#endif

@objc
extension PVEmulatorCore: EmulatorCoreVideoDelegate {
    open var alwaysUseMetal: Bool { false }
    @MainActor
    open var aspectSize: CGSize { .zero }
    open var depthFormat: GLenum { 0 }
    open var emulationFPS: Double { 0.0 }
    open var internalPixelFormat: GLenum  { 0 }
    open var isDoubleBuffered: Bool { false }
    open var pixelFormat: GLenum  { 0 }
    open var pixelType: GLenum {  0 }
    open var renderFPS: Double { 0.0 }
    open var rendersToOpenGL: Bool { false }
    open var screenRect: CGRect { .zero }

    @objc
    @MainActor
    open var videoBuffer: UnsafeMutableRawPointer? { nil }

    @MainActor
    open var videoBufferSize: CGSize { .zero }

    // Requires Override
    @objc
    open func executeFrame() {
        assertionFailure("Should be implimented in subclasses")
    }

    @objc
    open func swapBuffers() {
        assert(!self.isDoubleBuffered, "Cores that are double-buffered must implement swapBuffers!")
    }
}
