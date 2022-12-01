// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import OpenGLES.gltypes
import Metal
@_implementationOnly import Atomics
@_implementationOnly import os.log

class OpenGLES3GameRenderer: OpenGLGameRenderer {
    let gameCore: OEGameCore
    
    let texture: CoreVideoTexture
    
    // GL stuff
    var glContext: EAGLContext!
    var coreVideoFBO: GLuint = 0    // Framebuffer object which the Core Video pixel buffer is tied to
    var depthStencilRB: GLuint = 0  // FBO RenderBuffer Attachment for depth and stencil buffer
    
    // Double buffered FBO rendering (3D mode)
    var isDoubleBufferFBOMode = false
    var alternateFBO: GLuint = 0                    // 3D games may render into this FBO which is blit into the IOSurface.
    // Used if game accidentally syncs surface.
    var tempRB = [GLuint](repeating: 0, count: 2)   // Color and depth buffers backing alternate FBO.
    
    // Alternate-thread rendering (3D mode)
    var alternateContext: EAGLContext?
    var renderingThreadCanProceed = DispatchSemaphore(value: 0)
    var executeThreadCanProceed = DispatchSemaphore(value: 0)
    
    var isFPSLimiting = ManagedAtomic(0)
    
    init(withInteropTexture texture: CoreVideoTexture, gameCore: OEGameCore) {
        self.texture = texture
        self.gameCore = gameCore
    }
    
    deinit {
        if alternateContext != nil {
            renderingThreadCanProceed.signal()
        }
        destroyGLResources()
    }
    
    var surfaceSize: OEIntSize {
        .init(width: Int32(texture.size.width), height: Int32(texture.size.height))
    }
    
    func update() {
        destroyGLResources()
        setupVideo()
    }
    
    // 3D games can only change buffer size.
    
    // We'll be in trouble if a game core does software vector drawing.
    // TODO: Test alternate threads - might need to call glViewport() again on that thread.
    // TODO: Implement for double buffered FBO - need to reallocate alternateFBO.
    var canChangeBufferSize: Bool { true }
    
    var presentationFramebuffer: Any? {
        isDoubleBufferFBOMode ? alternateFBO : coreVideoFBO
    }
    
    private func setupVideo() {
        setupGLContext()
        setupFramebuffer()
        
        if gameCore.needsDoubleBufferedFBO {
            setupDoubleBufferedFBO()
        }
        
        if gameCore.hasAlternateRenderingThread {
            setupAlternateRenderingThread()
        }
        
        clearFramebuffer()
        glFlush()
    }
    
    func setupGLContext() {
        guard let context = EAGLContext(api: .openGLES3) else {
            fatalError("Unable to create OpenGLES 3 context")
        }
        
        glContext = context
        EAGLContext.setCurrent(glContext)
        texture.openGLContext = glContext
    }
    
    func setupFramebuffer() {
        fatalError("Not implemented")
    }
    
    func setupAlternateRenderingThread() {
        if alternateContext == nil {
            alternateContext = EAGLContext(api: .openGLES3)
        }
        
        os_log(.debug, log: .renderer, "Setup GL 3D 'alternate-threaded' rendering")
    }
    
    func setupDoubleBufferedFBO() {
        fatalError("Not implemented")
    }
    
    func clearFramebuffer() {
        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    
    func bindFBO(_ fbo: GLuint) {
        fatalError("Not implemented")
    }
    
    func presentDoubleBufferedFBO() {
        fatalError("Not implemented")
    }
    
    func destroyGLResources() {
        alternateContext        = nil
        texture.openGLContext   = nil
        glContext               = nil
    }
    
    func resumeFPSLimiting() {
        guard isFPSLimiting.load(ordering: .sequentiallyConsistent) != 1
        else { return }
        
        isFPSLimiting.wrappingIncrement(ordering: .sequentiallyConsistent)
    }
    
    func suspendFPSLimiting() {
        guard isFPSLimiting.load(ordering: .sequentiallyConsistent) != 0
        else { return }
        
        isFPSLimiting.wrappingDecrement(ordering: .sequentiallyConsistent)
    }
    
    func willExecuteFrame() {
        if alternateContext != nil {
            // Tell the rendering thread to go ahead.
            if isFPSLimiting.load(ordering: .sequentiallyConsistent) != 0 {
                renderingThreadCanProceed.signal()
            }
            return
        }
        
        EAGLContext.setCurrent(glContext)
        
        // Bind the FBO just in case that works.
        // Note that most GL3 cores will use their own FBOs and overwrite ours.
        // Their graphics plugins will need to be adapted to write to ours - see -presentationFramebuffer.
        bindFBO(isDoubleBufferFBOMode ? alternateFBO : coreVideoFBO)
    }
    
    func didExecuteFrame() {}
    
    func prepareFrameForRender(commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        texture.metalTexture
    }
    
    func willRenderFrameOnAlternateThread() {
        EAGLContext.setCurrent(alternateContext)
        bindFBO(isDoubleBufferFBOMode ? alternateFBO : coreVideoFBO)
    }
    
    func didRenderFrameOnAlternateThread() {
        // Update the IOSurface.
        glFlush()
        
        // Do FPS limiting, but only once setup is over.
        if isFPSLimiting.load(ordering: .sequentiallyConsistent) != 0 {
            // Technically the above should be a glFinish(), but I'm hoping the GPU work
            // is fast enough that it's not needed.
            executeThreadCanProceed.signal()
            
            // Wait to be allowed to start next frame.
            renderingThreadCanProceed.wait()
        }
    }
}
