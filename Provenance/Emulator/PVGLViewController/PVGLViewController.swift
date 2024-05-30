//
//  PVGLViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import QuartzCore
import ReplayKit
import PVEmulatorCore
import Metal
#if os(macOS) || targetEnvironment(macCatalyst)
import OpenGL
import AppKit
import GLUT
#else
import OpenGLES
import UIKit
import GLKit
#endif
import Metal
import MetalKit


internal let SHADER_DIR = "GLES"
internal let VERTEX_DIR = SHADER_DIR + "/Vertex"
internal let BLITTER_DIR = SHADER_DIR + "/Blitters"
internal let FILTER_DIR = SHADER_DIR + "/Filters"

class PVGLViewController: PVGPUViewController, PVRenderDelegate {
    var presentationFramebuffer: AnyObject? {
        _presentationFramebuffer()
    }

    /// Returns the presentation framebuffer to use for rendering
    func _presentationFramebuffer() -> AnyObject? {
        let bufferID = emulatorCore?.isDoubleBuffered ?? false
        ? alternateThreadFramebufferBack
        : alternateThreadFramebufferFront
        return NSNumber(value: bufferID)
    }

    var mtlView: MTKView?
    

    weak var emulatorCore: PVEmulatorCore?

#if targetEnvironment(macCatalyst) || os(macOS)
    var isPaused: Bool = false
    var timeSinceLastDraw: TimeInterval = 0
    var framesPerSecond: Int = 0
#endif

    var alternateThreadFramebufferBack: GLuint = 0
    var alternateThreadColorTextureBack: GLuint = 0
    var alternateThreadDepthRenderbuffer: GLuint = 0

    var alternateThreadColorTextureFront: GLuint = 0
    var alternateThreadFramebufferFront: GLuint = 0

    var blitFragmentShader: GLuint = 0
    var blitShaderProgram: GLuint = 0
    var blitUniform_EmulatedImage: GLint = 0

    var crtFragmentShader: GLuint = 0
    var crtShaderProgram: GLuint = 0
    var crtUniform_DisplayRect: GLint = 0
    var crtUniform_EmulatedImage: GLint = 0
    var crtUniform_EmulatedImageSize: GLint = 0
    var crtUniform_FinalRes: GLint = 0

    var defaultVertexShader: GLuint = 0

    var indexVBO: GLuint = 0
    var vertexVBO: GLuint = 0

    var texture: GLuint = 0

    var renderSettings = RenderSettings()

#if USE_METAL
    var glContext: CIContext?
    var alternateThreadGLContext: CIContext?
    var alternateThreadBufferCopyGLContext: CIContext?
    var mtlView: MTKView?
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
#else
    var glContext: EAGLContext?
    var alternateThreadGLContext: EAGLContext?
    var alternateThreadBufferCopyGLContext: EAGLContext?
#endif

#if USE_DISPLAY_LINK
    var displayLink: CADisplayLink?
#endif
#if USE_EFFECT && !USE_METAL
    var effect: GLKBaseEffect?
#endif

    var glesVersion: GLESVersion = .version3

    init(withEmulatorCore emulatorCore: PVEmulatorCore) {
        self.emulatorCore = emulatorCore
        super.init(nibName: nil, bundle: nil)

        if emulatorCore.rendersToOpenGL {
            emulatorCore.renderDelegate = self
        }

        renderSettings.crtFilterEnabled = PVSettingsModel.shared.crtFilterEnabled
        renderSettings.lcdFilterEnabled = PVSettingsModel.shared.lcdFilterEnabled
        renderSettings.smoothingEnabled = PVSettingsModel.shared.imageSmoothing

        PVSettingsModel.shared.addObserver(self, forKeyPath: "crtFilterEnabled", options: .new, context: nil)
        PVSettingsModel.shared.addObserver(self, forKeyPath: "lcdFilterEnabled", options: .new, context: nil)
        PVSettingsModel.shared.addObserver(self, forKeyPath: "imageSmoothing", options: .new, context: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if alternateThreadDepthRenderbuffer > 0 {
            glDeleteRenderbuffers(1, &alternateThreadDepthRenderbuffer)
        }
        if alternateThreadColorTextureBack > 0 {
            glDeleteTextures(1, &alternateThreadColorTextureBack)
        }
        if alternateThreadFramebufferBack > 0 {
            glDeleteFramebuffers(1, &alternateThreadFramebufferBack)
        }
        if alternateThreadColorTextureFront > 0 {
            glDeleteTextures(1, &alternateThreadColorTextureFront)
        }
        if alternateThreadFramebufferFront > 0 {
            glDeleteFramebuffers(1, &alternateThreadFramebufferFront)
        }
        if crtShaderProgram > 0 {
            glDeleteProgram(crtShaderProgram)
        }
        if crtFragmentShader > 0 {
            glDeleteShader(crtFragmentShader)
        }
        if blitShaderProgram > 0 {
            glDeleteProgram(blitShaderProgram)
        }
        if blitFragmentShader > 0 {
            glDeleteShader(blitFragmentShader)
        }
        if defaultVertexShader > 0 {
            glDeleteShader(defaultVertexShader)
        }
        glDeleteTextures(1, &texture)

        PVSettingsModel.shared.removeObserver(self, forKeyPath: "crtFilterEnabled")
        PVSettingsModel.shared.removeObserver(self, forKeyPath: "lcdFilterEnabled")
        PVSettingsModel.shared.removeObserver(self, forKeyPath: "imageSmoothing")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "crtFilterEnabled" {
            renderSettings.crtFilterEnabled = PVSettingsModel.shared.crtFilterEnabled
        } else if keyPath == "lcdFilterEnabled" {
            renderSettings.lcdFilterEnabled = PVSettingsModel.shared.lcdFilterEnabled
        } else if keyPath == "imageSmoothing" {
            renderSettings.smoothingEnabled = PVSettingsModel.shared.imageSmoothing
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

#if USE_DISPLAY_LINK
    @objc func render() {
        emulatorCore?.executeFrame()
    }
#endif

    override func viewDidLoad() {
        super.viewDidLoad()

        updatePreferredFPS()

#if !USE_METAL
        glContext = bestContext

        guard let glContext = glContext else {
            // TODO: Alert NO gl here
            return
        }

        print("Initiated GLES version \(glContext.api.rawValue)")

        // TODO: Need to benchmark this
        glContext.isMultiThreaded = PVSettingsModel.shared.videoOptions.multiThreadedGL

        EAGLContext.setCurrent(glContext)

        let view = self.view as! GLKView
#else
        device = MTLCreateSystemDefaultDevice()

        let view = MTKView(frame: self.view.bounds, device: device)
        mtlView = view
        self.view.addSubview(view)
        view.device = device
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.depthStencilPixelFormat = .depth32Float_stencil8
        view.sampleCount = 4
        view.delegate = self
        commandQueue = device?.makeCommandQueue()

        view.isPaused = false
        view.enableSetNeedsDisplay = false
#endif

        view.isOpaque = true
        view.layer.isOpaque = true

        view.isUserInteractionEnabled = false

#if USE_DISPLAY_LINK
        displayLink = CADisplayLink(target: self, selector: #selector(render))
        displayLink?.add(to: .current, forMode: .default)
#endif

#if USE_EFFECT && !USE_METAL
        effect = GLKBaseEffect()
#endif

        guard let emulatorCore = emulatorCore else {
            return
        }

        let depthFormat: Int32 = Int32(emulatorCore.depthFormat)
        switch depthFormat {
        case GL_DEPTH_COMPONENT16:
#if USE_METAL
            view.depthStencilPixelFormat = .rg8Unorm_srgb
#else
            view.drawableDepthFormat = .format16
#endif
        case GL_DEPTH_COMPONENT24:
#if USE_METAL
            view.depthStencilPixelFormat = .x24_stencil8
#else
            view.drawableDepthFormat = .format24
#endif
        default:
            break
        }

        if PVSettingsModel.shared.nativeScaleEnabled {
            let scale = UIScreen.main.scale
            if scale != 1 {
                view.layer.contentsScale = scale
                view.layer.rasterizationScale = scale
                view.contentScaleFactor = scale
            }

            if PVSettingsModel.shared.videoOptions.multiSampling {
#if USE_METAL
                view.sampleCount = 4
#else
                view.drawableMultisample = .multisample4X
#endif
            }
        }

        setupVBOs()
        setupTexture()

#if !USE_METAL
        var error: Error?
        defaultVertexShader = compileShaderResource("\(VERTEX_DIR)/default_vertex", ofType: GLenum(GL_VERTEX_SHADER), error: &error)

        if let error = error {
            print("Error compiling default vertex shader: \(error.localizedDescription)")
        }
        assert(defaultVertexShader != GL_NO_ERROR, "Default vertex shader compilation failed")

        setupBlitShader()
        setupCRTShader()
#endif

        alternateThreadFramebufferBack = 0
        alternateThreadColorTextureBack = 0
        alternateThreadDepthRenderbuffer = 0

        alternateThreadFramebufferFront = 0
        alternateThreadColorTextureFront = 0
    }

#if !USE_METAL
    /// Chooses the best EAGLContext for the device
    private lazy var bestContext: EAGLContext? = {
        if let context = EAGLContext(api: .openGLES3) {
            glesVersion = .version3
            return context
        } else if let context = EAGLContext(api: .openGLES2) {
            glesVersion = .version2
            return context
        } else if let context = EAGLContext(api: .openGLES1) {
            glesVersion = .version1
            return context
        } else {
            return nil
        }
    }()
#endif

    /// Updates the preferred FPS based on the emulator core
    func updatePreferredFPS() {
        let preferredFPS = emulatorCore?.frameInterval ?? 60
        print("updatePreferredFPS (\(preferredFPS))")
        if preferredFPS < 10 {
            print("Core's frame interval (\(preferredFPS)) too low. Setting to 60")
#if !USE_METAL
            preferredFramesPerSecond = 60
#else
            setFramesPerSecond(60)
#endif
        } else {
#if !USE_METAL
            preferredFramesPerSecond = Int(preferredFPS)
#else
            setFramesPerSecond(preferredFPS)
#endif
        }
        print("Actual FPS: \(framesPerSecond)")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let emulatorCore = emulatorCore else {
            return
        }

        let parentSafeAreaInsets = parent?.view.safeAreaInsets ?? .zero

        if !emulatorCore.screenRect.isEmpty {
            let aspectSize = emulatorCore.aspectSize
            let ratio = aspectSize.width > aspectSize.height
            ? aspectSize.width / aspectSize.height
            : aspectSize.height / aspectSize.width

            var parentSize = parent?.view.bounds.size ?? .zero
            if let window = view.window {
                parentSize = window.bounds.size
            }

            var height: CGFloat = 0
            var width: CGFloat = 0

            if parentSize.width > parentSize.height {
                height = PVSettingsModel.shared.integerScaleEnabled
                ? floor(parentSize.height / aspectSize.height) * aspectSize.height
                : parentSize.height
                width = height * ratio
                if width > parentSize.width {
                    width = parentSize.width
                    height = width / ratio
                }
            } else {
                width = PVSettingsModel.shared.integerScaleEnabled
                ? floor(parentSize.width / aspectSize.width) * aspectSize.width
                : parentSize.width
                height = width / ratio
                if height > parentSize.height {
                    height = parentSize.height
                    width = height * ratio
                }
            }

            var origin = CGPoint(x: (parentSize.width - width) / 2, y: 0)
            if traitCollection.userInterfaceIdiom == .phone && parentSize.height > parentSize.width {
                origin.y = parentSafeAreaInsets.top + 40 // below menu button
            } else {
                origin.y = (parentSize.height - height) / 2 // centered
            }

            view.frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
        }

        updatePreferredFPS()
    }

    /// Sets up the GL texture for rendering
    func setupTexture() {
        guard let emulatorCore = emulatorCore else {
            return
        }

        glGenTextures(1, &texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)

        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(emulatorCore.internalPixelFormat),
                     GLsizei(emulatorCore.bufferSize.width), GLsizei(emulatorCore.bufferSize.height),
                     0, GLenum(emulatorCore.pixelFormat), GLenum(emulatorCore.pixelType), emulatorCore.videoBuffer)

        if renderSettings.smoothingEnabled {
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
        } else {
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_NEAREST))
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_NEAREST))
        }
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLint(GL_CLAMP_TO_EDGE))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLint(GL_CLAMP_TO_EDGE))
    }

    /// Sets up the vertex buffer objects (VBOs) for rendering
    func setupVBOs() {
        glGenBuffers(1, &vertexVBO)
        updateVBO(withScreenRect: emulatorCore?.screenRect ?? .zero, andVideoBufferSize: emulatorCore?.bufferSize ?? .zero)

        var indices: [GLushort] = [0, 1, 2, 0, 2, 3]
        glGenBuffers(1, &indexVBO)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexVBO)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<GLushort>.stride * indices.count, &indices, GLenum(GL_STATIC_DRAW))
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
    }

    /// Updates the VBO with the latest screen rectangle and buffer size
    func updateVBO(withScreenRect screenRect: CGRect, andVideoBufferSize videoBufferSize: CGSize) {
        let texLeft = screenRect.origin.x / videoBufferSize.width
        let texTop = screenRect.origin.y / videoBufferSize.height
        let texRight = (screenRect.origin.x + screenRect.width) / videoBufferSize.width
        let texBottom = (screenRect.origin.y + screenRect.height) / videoBufferSize.height

        var texCoordTop = texTop
        var texCoordBottom = texBottom
        if emulatorCore?.rendersToOpenGL ?? false {
            texCoordTop = (screenRect.origin.y + screenRect.height) / videoBufferSize.height
            texCoordBottom = screenRect.origin.y / videoBufferSize.height
        }

        var quadVertices = [
            PVVertex(x: -1, y: -1, z: 1, u: GLfloat(texLeft),  v: GLfloat(texCoordBottom)),
            PVVertex(x:  1, y: -1, z: 1, u: GLfloat(texRight), v: GLfloat(texCoordBottom)),
            PVVertex(x:  1, y:  1, z: 1, u: GLfloat(texRight), v: GLfloat(texCoordTop)),
            PVVertex(x: -1, y:  1, z: 1, u: GLfloat(texLeft),  v: GLfloat(texCoordTop))
        ]

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexVBO)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<PVVertex>.stride * quadVertices.count, &quadVertices, GLenum(GL_DYNAMIC_DRAW))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
    }

#if !USE_METAL
    /// Compiles a shader from a resource file
    func compileShaderResource(_ shaderName: String, ofType shaderType: GLenum, error: inout Error?) -> GLuint {
        // load and compile shader code...
    }

    /// Links a vertex and fragment shader into a shader program
    func linkVertexShader(_ vertexShader: GLuint, withFragmentShader fragmentShader: GLuint) -> GLuint {
        let shaderProgram = glCreateProgram()
        guard shaderProgram != 0 else {
            return 0
        }

        glAttachShader(shaderProgram, vertexShader)
        glAttachShader(shaderProgram, fragmentShader)

        glBindAttribLocation(shaderProgram, GLuint(GLKVertexAttrib.position.rawValue), "vPosition")
        glBindAttribLocation(shaderProgram, GLuint(GLKVertexAttrib.texCoord0.rawValue), "vTexCoord")

        glLinkProgram(shaderProgram)

        var linkStatus: GLint = 0
        glGetProgramiv(shaderProgram, GLenum(GL_LINK_STATUS), &linkStatus)
        if linkStatus == 0 {
            var infoLength: GLint = 0
            glGetProgramiv(shaderProgram, GLenum(GL_INFO_LOG_LENGTH), &infoLength)
            if infoLength > 1 {
                let infoLog = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(infoLength))
                glGetProgramInfoLog(shaderProgram, infoLength, nil, infoLog)
                let errorString = String(cString: infoLog)
                print("Error linking shader program: \(errorString)")
                infoLog.deallocate()
            }

            glDeleteProgram(shaderProgram)
            return 0
        }

        return shaderProgram
    }

    /// Sets up the blit shader for rendering
    func setupBlitShader() {
        var error: Error?
        blitFragmentShader = compileShaderResource("\(BLITTER_DIR)/blit_fragment", ofType: GLenum(GL_FRAGMENT_SHADER), error: &error)
        assert(blitFragmentShader != GL_NO_ERROR, "Error compiling blit fragment shader: \(error?.localizedDescription ?? "")")

        blitShaderProgram = linkVertexShader(defaultVertexShader, withFragmentShader: blitFragmentShader)
        assert(blitShaderProgram != GL_NO_ERROR, "Error linking blit shader program")

        blitUniform_EmulatedImage = glGetUniformLocation(blitShaderProgram, "EmulatedImage")
    }

    /// Sets up the CRT shader for rendering
    func setupCRTShader() {
        var error: Error?
        crtFragmentShader = compileShaderResource("\(FILTER_DIR)/crt_fragment", ofType: GLenum(GL_FRAGMENT_SHADER), error: &error)
        assert(crtFragmentShader != GL_NO_ERROR, "Error compiling CRT fragment shader: \(error?.localizedDescription ?? "")")

        crtShaderProgram = linkVertexShader(defaultVertexShader, withFragmentShader: crtFragmentShader)
        assert(crtShaderProgram != GL_NO_ERROR, "Error linking CRT shader program")

        crtUniform_DisplayRect = glGetUniformLocation(crtShaderProgram, "DisplayRect")
        crtUniform_EmulatedImage = glGetUniformLocation(crtShaderProgram, "EmulatedImage")
        crtUniform_EmulatedImageSize = glGetUniformLocation(crtShaderProgram, "EmulatedImageSize")
        crtUniform_FinalRes = glGetUniformLocation(crtShaderProgram, "FinalRes")
    }
#endif

#if USE_METAL
    // MARK: - MTKViewDelegate

    /// Called whenever the drawable size of the view will change
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // no-op
    }

    /// Called when the view needs to render
    func draw(in view: MTKView) {
        guard let emulatorCore = emulatorCore else {
            return
        }

        if emulatorCore.skipEmulationLoop {
            return
        }

        weak var weakSelf = self

        let renderBlock = { [weak self] in
            guard let self = self else {
                return
            }

            let screenRect = self.emulatorCore?.screenRect ?? .zero

            var frontBufferTex: GLuint = 0
            if self.emulatorCore?.rendersToOpenGL ?? false {
                frontBufferTex = self.alternateThreadColorTextureFront
                self.emulatorCore?.frontBufferLock.lock()
            } else {
                glBindTexture(GLenum(GL_TEXTURE_2D), self.texture)
                glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0,
                                GLsizei(self.renderSettings.videoBufferSize.width),
                                GLsizei(self.renderSettings.videoBufferSize.height),
                                GLenum(self.renderSettings.videoBufferPixelFormat),
                                GLenum(self.renderSettings.videoBufferPixelType),
                                self.renderSettings.videoBuffer)
                frontBufferTex = self.texture
            }

            if frontBufferTex != 0 {
                glActiveTexture(GLenum(GL_TEXTURE0))
                glBindTexture(GLenum(GL_TEXTURE_2D), frontBufferTex)
            }

            autoreleasepool {
                guard let device = self.device,
                      let commandQueue = self.commandQueue,
                      let view = self.mtlView,
                      let descriptor = view.currentRenderPassDescriptor,
                      let commandBuffer = commandQueue.makeCommandBuffer(),
                      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                    return
                }

                let crtEnabled = self.renderSettings.crtFilterEnabled && !(self.emulatorCore?.screenType.lowercased().contains("lcd") ?? false)
                let lcdEnabled = self.renderSettings.lcdFilterEnabled && (self.emulatorCore?.screenType.lowercased().contains("lcd") ?? false)

                if crtEnabled {
                    guard let pipeline = self.crtPipeline,
                          let shader = pipeline.vertexFunction else {
                        return
                    }

                    renderEncoder.setRenderPipelineState(pipeline)
                    renderEncoder.setVertexFunction(shader)

                    var displayRect = self.renderSettings.screenRect
                    renderEncoder.setFragmentBytes(&displayRect, length: MemoryLayout<CGRect>.stride, index: 0)

                    renderEncoder.setFragmentTexture(self.texture, index: 0)

                    var imageSize = self.renderSettings.videoBufferSize
                    renderEncoder.setFragmentBytes(&imageSize, length: MemoryLayout<CGSize>.stride, index: 1)

                    var finalRes = CGSize(width: CGFloat(view.drawableSize.width),
                                          height: CGFloat(view.drawableSize.height))
                    renderEncoder.setFragmentBytes(&finalRes, length: MemoryLayout<CGSize>.stride, index: 2)
                } else if lcdEnabled {
                    // Similar setup for lcdPipeline as crtPipeline above
                } else {
                    guard let pipeline = self.blitPipeline else {
                        return
                    }

                    renderEncoder.setRenderPipelineState(pipeline)
                    renderEncoder.setFragmentTexture(self.texture, index: 0)
                }

                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                renderEncoder.endEncoding()

                guard let drawable = view.currentDrawable else {
                    return
                }

                commandBuffer.present(drawable)
                commandBuffer.commit()
            }

            if self.emulatorCore?.rendersToOpenGL ?? false {
                self.emulatorCore?.frontBufferLock.unlock()
            }
        }

        if emulatorCore.rendersToOpenGL {
            if (!emulatorCore.isSpeedModified && !emulatorCore.isEmulationPaused) || emulatorCore.isFrontBufferReady {
                emulatorCore.frontBufferCondition.lock()
                while !emulatorCore.isFrontBufferReady && !emulatorCore.isEmulationPaused {
                    emulatorCore.frontBufferCondition.wait()
                }
                let isFrontBufferReady = emulatorCore.isFrontBufferReady
                emulatorCore.frontBufferCondition.unlock()

                if isFrontBufferReady {
                    renderBlock()
                    emulatorCore.frontBufferCondition.lock()
                    emulatorCore.isFrontBufferReady = false
                    emulatorCore.frontBufferCondition.signal()
                    emulatorCore.frontBufferCondition.unlock()
                }
            }
        } else {
            if emulatorCore.isSpeedModified {
                renderBlock()
            } else if emulatorCore.isDoubleBuffered {
                emulatorCore.frontBufferCondition.lock()
                while !emulatorCore.isFrontBufferReady && !emulatorCore.isEmulationPaused {
                    emulatorCore.frontBufferCondition.wait()
                }
                emulatorCore.isFrontBufferReady = false
                emulatorCore.frontBufferLock.lock()
                renderBlock()
                emulatorCore.frontBufferLock.unlock()
                emulatorCore.frontBufferCondition.unlock()
            } else {
                objc_sync_enter(emulatorCore)
                renderBlock()
                objc_sync_exit(emulatorCore)
            }
        }
    }
#else
    // MARK: - GLKViewDelegate

    /// GLKView delegate method, called when the view needs to draw
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        guard let emulatorCore = emulatorCore else {
            return
        }

        if emulatorCore.skipEmulationLoop {
            return
        }

//        weak var weakSelf = self

        var screenRect: CGRect = .zero
        var videoBuffer: UnsafeRawPointer? = nil
        var videoBufferPixelFormat: GLenum = 0
        var videoBufferPixelType: GLenum = 0
        var videoBufferSize: CGSize = .zero

        let fetchVideoBuffer = {
            screenRect = emulatorCore.screenRect
            videoBufferPixelFormat = emulatorCore.pixelFormat
            videoBufferPixelType = emulatorCore.pixelType
            videoBufferSize = emulatorCore.bufferSize
            videoBuffer = emulatorCore.videoBuffer
        }

        let renderBlock = { [weak self] in
            guard let self = self else {
                return
            }

            guard let emulatorCore = self.emulatorCore else {
                return
            }

#if DEBUG
            glClearColor(1.0, 1.0, 1.0, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
#endif

            let rendersToOpenGL = emulatorCore.rendersToOpenGL
            let crtEnabled = self.renderSettings.crtFilterEnabled && ((emulatorCore.screenType?.lowercased().contains("lcd")) == nil)
            let lcdEnabled = self.renderSettings.lcdFilterEnabled && ((emulatorCore.screenType?.lowercased().contains("lcd")) != nil)

            var frontBufferTex: GLuint = 0

            if rendersToOpenGL {
                frontBufferTex = self.alternateThreadColorTextureFront
                emulatorCore.frontBufferLock.lock()
            } else {
                glBindTexture(GLenum(GL_TEXTURE_2D), self.texture)
                glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0,
                                GLsizei(videoBufferSize.width),
                                GLsizei(videoBufferSize.height),
                                GLenum(videoBufferPixelFormat),
                                GLenum(videoBufferPixelType),
                                videoBuffer)

                frontBufferTex = self.texture

#if USE_EFFECT
                if self.texture != 0 {
                    self.effect?.texture2d0.envMode = .replace
                    self.effect?.texture2d0.target = .texture2D
                    self.effect?.texture2d0.name = self.texture
                    self.effect?.texture2d0.enabled = true
                    self.effect?.useConstantColor = true
                }

                self.effect?.prepareToDraw()
#endif
            }

            if frontBufferTex != 0 {
                glActiveTexture(GLenum(GL_TEXTURE0))
                glBindTexture(GLenum(GL_TEXTURE_2D), frontBufferTex)
            }

            if crtEnabled {
                glUseProgram(self.crtShaderProgram)
                glUniform4f(self.crtUniform_DisplayRect,
                            GLfloat(screenRect.origin.x), GLfloat(screenRect.origin.y),
                            GLfloat(screenRect.size.width), GLfloat(screenRect.size.height))
                glUniform1i(self.crtUniform_EmulatedImage, 0)
                glUniform2f(self.crtUniform_EmulatedImageSize,
                            GLfloat(videoBufferSize.width), GLfloat(videoBufferSize.height))

                let finalResWidth = GLfloat(view.drawableWidth)
                let finalResHeight = GLfloat(view.drawableHeight)
                glUniform2f(self.crtUniform_FinalRes, finalResWidth, finalResHeight)
            } else if lcdEnabled {
                glUseProgram(self.crtShaderProgram)
                glUniform4f(self.crtUniform_DisplayRect,
                            GLfloat(screenRect.origin.x), GLfloat(screenRect.origin.y),
                            GLfloat(screenRect.size.width), GLfloat(screenRect.size.height))
                glUniform1i(self.crtUniform_EmulatedImage, 0)
                glUniform2f(self.crtUniform_EmulatedImageSize,
                            GLfloat(videoBufferSize.width), GLfloat(videoBufferSize.height))

                let finalResWidth = GLfloat(view.drawableWidth)
                let finalResHeight = GLfloat(view.drawableHeight)
                glUniform2f(self.crtUniform_FinalRes, finalResWidth, finalResHeight)
            } else {
                glUseProgram(self.blitShaderProgram)
                glUniform1i(self.blitUniform_EmulatedImage, 0)
            }

            glDisable(GLenum(GL_DEPTH_TEST))
            glDisable(GLenum(GL_CULL_FACE))

            self.updateVBO(withScreenRect: screenRect, andVideoBufferSize: videoBufferSize)

            glBindBuffer(GLenum(GL_ARRAY_BUFFER), self.vertexVBO)

            glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
            glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue),
                                  3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<PVVertex>.stride), nil)

            glEnableVertexAttribArray(GLuint(GLKVertexAttrib.texCoord0.rawValue))
            let texCoordOffset = MemoryLayout<GLfloat>.stride * 3
            glVertexAttribPointer(GLuint(GLKVertexAttrib.texCoord0.rawValue),
                                  2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<PVVertex>.stride),
                                  UnsafeRawPointer(bitPattern: texCoordOffset))

            glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)

            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), self.indexVBO)
            glDrawElements(GLenum(GL_TRIANGLES), 6, GLenum(GL_UNSIGNED_SHORT), nil)
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)

            glDisableVertexAttribArray(GLuint(GLKVertexAttrib.texCoord0.rawValue))
            glDisableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))

            glBindTexture(GLenum(GL_TEXTURE_2D), 0)

            if rendersToOpenGL {
                glFlush()
                emulatorCore.frontBufferLock.unlock()
            }
        }

        if emulatorCore.rendersToOpenGL {
            if (!emulatorCore.isSpeedModified && !emulatorCore.isEmulationPaused) || emulatorCore.isFrontBufferReady {
                emulatorCore.frontBufferCondition.lock()
                while !emulatorCore.isFrontBufferReady && !emulatorCore.isEmulationPaused {
                    emulatorCore.frontBufferCondition.wait()
                }
                let isFrontBufferReady = emulatorCore.isFrontBufferReady
                emulatorCore.frontBufferCondition.unlock()

                if isFrontBufferReady {
                    fetchVideoBuffer()
                    renderBlock()

                    emulatorCore.frontBufferCondition.lock()
                    emulatorCore.isFrontBufferReady = false
                    emulatorCore.frontBufferCondition.signal()
                    emulatorCore.frontBufferCondition.unlock()
                }
            }
        } else {
            if emulatorCore.isSpeedModified {
                fetchVideoBuffer()
                renderBlock()
            } else if emulatorCore.isDoubleBuffered {
                emulatorCore.frontBufferCondition.lock()
                while !emulatorCore.isFrontBufferReady && !emulatorCore.isEmulationPaused {
                    emulatorCore.frontBufferCondition.wait()
                }
                emulatorCore.isFrontBufferReady = false
                emulatorCore.frontBufferLock.lock()
                fetchVideoBuffer()
                renderBlock()
                emulatorCore.frontBufferLock.unlock()
                emulatorCore.frontBufferCondition.unlock()
            } else {
                objc_sync_enter(emulatorCore)
                fetchVideoBuffer()
                renderBlock()
                objc_sync_exit(emulatorCore)
            }
        }
    }
#endif

    // MARK: - PVRenderDelegate

    /// Called when rendering should start on an alternate thread
    func startRenderingOnAlternateThread() {
        guard let emulatorCore = emulatorCore else {
            return
        }

        emulatorCore.glesVersion = glesVersion

        let bufferCopyContext = EAGLContext(api: glContext!.api, sharegroup: glContext!.sharegroup)
        alternateThreadBufferCopyGLContext = bufferCopyContext
        EAGLContext.setCurrent(bufferCopyContext)

        // setup double buffering...
    }

    /// Called after a frame has been rendered on the alternate thread
    func didRenderFrameOnAlternateThread() {
        guard let emulatorCore = emulatorCore else {
            return
        }

        // Blit back buffer to front buffer
        emulatorCore.frontBufferLock.lock()

        EAGLContext.setCurrent(alternateThreadBufferCopyGLContext)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), alternateThreadFramebufferFront)

        let screenRect = emulatorCore.screenRect
        glViewport(GLint(screenRect.origin.x), GLint(screenRect.origin.y),
                   GLsizei(screenRect.width), GLsizei(screenRect.height))

        glBindTexture(GLenum(GL_TEXTURE_2D), alternateThreadColorTextureBack)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexVBO)

        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<PVVertex>.stride), nil)

        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.texCoord0.rawValue))
        let texCoordOffset = MemoryLayout<Float>.stride * 3
        glVertexAttribPointer(GLuint(GLKVertexAttrib.texCoord0.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<PVVertex>.stride), UnsafeRawPointer(bitPattern: texCoordOffset))

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexVBO)
        glDrawElements(GLenum(GL_TRIANGLES), 6, GLenum(GL_UNSIGNED_SHORT), nil)

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)

        glBindTexture(GLenum(GL_TEXTURE_2D), 0)

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        glFlush()

        emulatorCore.frontBufferLock.unlock()

        // Notify render thread that the front buffer is ready
        emulatorCore.frontBufferCondition.lock()
        emulatorCore.isFrontBufferReady = true
        emulatorCore.frontBufferCondition.signal()
        emulatorCore.frontBufferCondition.unlock()

        // Switch context back to emulator's
        EAGLContext.setCurrent(alternateThreadGLContext)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), alternateThreadFramebufferBack)
    }
}

import ObjectiveC
//// Helper functions for ObjC synchronization
//func objc_sync_enter(_ obj: AnyObject) {
//    objc_sync_enter(obj)
//}
//
//func objc_sync_exit(_ obj: AnyObject) {
//    objc_sync_exit(obj)
//}



