//
//  PVMetalViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import IOSurface
import PVSupport
import PVEmulatorCore
import PVLogging

#if os(macOS) || targetEnvironment(macCatalyst)
import OpenGL
#else
import OpenGLES
#endif


fileprivate let BUFFER_COUNT = 3


final
class PVMetalViewController : PVGPUViewController, PVRenderDelegate, MTKViewDelegate {
    var presentationFramebuffer: AnyObject? = nil
    
    weak var emulatorCore: PVEmulatorCore? = nil
    var mtlView: MTKView!

#if os(macOS) || targetEnvironment(macCatalyst)
    var isPaused: Bool = false
    var timeSinceLastDraw: TimeInterval = 0
    var framesPerSecond: Int = 0
#endif


    // MARK: Internal

    var alternateThreadFramebufferBack: GLuint
    var alternateThreadColorTextureBack: GLuint
    var alternateThreadDepthRenderbuffer: GLuint

    var backingIOSurface: IOSurfaceRef?    // for OpenGL core support
    var backingMTLTexture: (any MTLTexture)?   // for OpenGL core support

    var uploadBuffer: [MTLBuffer] // BUFFER_COUNT
    var frameCount: UInt

    var renderSettings: RenderSettings

    // MARK: Internal properties

    var  device: MTLDevice?
    var  commandQueue: MTLCommandQueue?
    var  blitPipeline: MTLRenderPipelineState?
    
    var  effectFilterPipeline: MTLRenderPipelineState?
    var  pointSampler: MTLSamplerState?
    var  linearSampler: MTLSamplerState?

    var  inputTexture: MTLTexture?
    var  previousCommandBuffer: MTLCommandBuffer? // used for scheduling with OpenGL context

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    var  glContext: EAGLContext?
    var  alternateThreadGLContext: EAGLContext?
    var  alternateThreadBufferCopyGLContext: EAGLContext?
#else
    var  glContext: NSOpenGLContext?
    var  alternateThreadGLContext: NSOpenGLContext?
    var  alternateThreadBufferCopyGLContext: NSOpenGLContext?
    var  caDisplayLink: CADisplayLink?
#endif

    var  glesVersion: GLESVersion = .version3
    var  effectFilterShader: Shader? = nil

    // MARK: Internal GL status

    var resolution_uniform: GLuint
    var texture_uniform: GLuint
    var previous_texture_uniform: GLuint
    var frame_blending_mode_uniform: GLuint

    var position_attribute: GLuint
    var texture: GLuint
    var previous_texture: GLuint
    var program: GLuint

    // MARK: Methods

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required
    init(withEmulatorCore emulatorCore: PVEmulatorCore) {
        self.emulatorCore = emulatorCore
        super.init(nibName: nil, bundle: nil)

        if emulatorCore.rendersToOpenGL {
            emulatorCore.renderDelegate = self
        }

        renderSettings.crtFilterEnabled = filterShaderEnabled()
        renderSettings.smoothingEnabled = PVSettingsModel.shared.imageSmoothing

        PVSettingsModel.shared.addObserver(self, forKeyPath: "metalFilter", options: .new, context: nil)
        PVSettingsModel.shared.addObserver(self, forKeyPath: "imageSmoothing", options: .new, context: nil)
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

        backingMTLTexture = nil
        if let backingIOSurface = backingIOSurface {
            IOSurfaceDecrementUseCount(backingIOSurface)
        }

        PVSettingsModel.shared.removeObserver(self, forKeyPath: "metalFilter")
        PVSettingsModel.shared.removeObserver(self, forKeyPath: "imageSmoothing")
    }

    func filterShaderEnabled() -> Bool {
        let value = PVSettingsModel.shared.metalFilter.lowercased()
        return !(value == "" || value == "off")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "metalFilter" {
            renderSettings.crtFilterEnabled = filterShaderEnabled()
        } else if keyPath == "imageSmoothing" {
            renderSettings.smoothingEnabled = PVSettingsModel.shared.imageSmoothing
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updatePreferredFPS()

        if emulatorCore?.rendersToOpenGL ?? false {
#if !(targetEnvironment(macCatalyst) || os(macOS))
            glContext = bestContext

            print("Initiated GLES version \(String(describing: glContext?.api))")

            glContext?.isMultiThreaded = PVSettingsModel.shared.videoOptions.multiThreadedGL

            EAGLContext.setCurrent(glContext)
#endif
        }

        frameCount = 0
        device = MTLCreateSystemDefaultDevice()

        let view = MTKView(frame: view.bounds, device: device)
        self.mtlView = view
        view.addSubview(mtlView)
        view.device = device
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.depthStencilPixelFormat = .depth32Float_stencil8
        view.sampleCount = 1
        view.delegate = self
        view.autoResizeDrawable = true
        commandQueue = device?.makeCommandQueue()

        view.isPaused = false
        view.enableSetNeedsDisplay = false

        view.isOpaque = true
        view.layer.isOpaque = true

        view.isUserInteractionEnabled = false

        if let emulatorCore = emulatorCore {
            let depthFormat: Int32 = Int32(emulatorCore.depthFormat)
            switch depthFormat {
            case GL_DEPTH_COMPONENT16:
                view.depthStencilPixelFormat = .depth16Unorm
            case GL_DEPTH_COMPONENT24:
                view.depthStencilPixelFormat = .x32_stencil8
#if !(targetEnvironment(macCatalyst) || os(iOS))
                if device?.isDepth24Stencil8PixelFormatSupported ?? false {
                    view.depthStencilPixelFormat = .x24_stencil8
                }
#endif
            default:
                break
            }
        }

        if PVSettingsModel.shared.nativeScaleEnabled {
            let scale = UIScreen.main.scale
            if scale != 1 {
                view.layer.contentsScale = scale
                view.layer.rasterizationScale = scale
                view.contentScaleFactor = scale
            }
        }

        setupTexture()
        setupBlitShader()

        let metalFilter = PVSettingsModel.shared.metalFilter
        if let filterShader = MetalShaderManager.shared.filterShader(forName: metalFilter) {
            setupEffectFilterShader(filterShader)
        }

        alternateThreadFramebufferBack = 0
        alternateThreadColorTextureBack = 0
        alternateThreadDepthRenderbuffer = 0
    }

#if !(targetEnvironment(macCatalyst) || os(macOS))

    lazy var bestContext: EAGLContext? = {
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

    func updatePreferredFPS() {
        let preferredFPS: Int = Int(emulatorCore?.frameInterval ?? 0)
        print("updatePreferredFPS (\(preferredFPS))")
        if preferredFPS < 10 {
            print("Cores frame interval (\(preferredFPS)) too low. Setting to 60")
            mtlView.preferredFramesPerSecond = 60
        } else {
            mtlView.preferredFramesPerSecond = preferredFPS
        }
    }

#if !(targetEnvironment(macCatalyst) || os(macOS))
//    override func preferredFramesPerSecond(_ preferredFramesPerSecond: Int) {
//        super.preferredFramesPerSecond(preferredFramesPerSecond)
//    }
#else
    override var framesPerSecond: Int {
        get { super.framesPerSecond }
        set { super.framesPerSecond = newValue }
    }
#endif

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let emulatorCore = emulatorCore else {
            return
        }

        if emulatorCore.skipLayout {
            return
        }

        let parentSafeAreaInsets = parent?.view.safeAreaInsets ?? .zero

        if !emulatorCore.screenRect.isEmpty {
            let aspectSize = emulatorCore.aspectSize
            var ratio: CGFloat = 0
            if aspectSize.width > aspectSize.height {
                ratio = aspectSize.width / aspectSize.height
            } else {
                ratio = aspectSize.height / aspectSize.width
            }

            var parentSize = parent?.view.bounds.size ?? CGSize.zero
            if let window = view.window {
                parentSize = window.bounds.size
            }

            var height: CGFloat = 0
            var width: CGFloat = 0

            if parentSize.width > parentSize.height {
                if PVSettingsModel.shared.integerScaleEnabled {
                    height = floor(parentSize.height / aspectSize.height) * aspectSize.height
                } else {
                    height = parentSize.height
                }
                width = height * ratio
                if width > parentSize.width {
                    width = parentSize.width
                    height = width / ratio
                }
            } else {
                if PVSettingsModel.shared.integerScaleEnabled {
                    width = floor(parentSize.width / aspectSize.width) * aspectSize.width
                } else {
                    width = parentSize.width
                }
                height = width / ratio
                if height > parentSize.height {
                    height = parentSize.width
                    width = height / ratio
                }
            }

            var origin = CGPoint(x: (parentSize.width - width) / 2, y: 0)
            if traitCollection.userInterfaceIdiom == .phone && parentSize.height > parentSize.width {
                origin.y = parentSafeAreaInsets.top + 40 // below menu button
            } else {
                origin.y = (parentSize.height - height) / 2 // centered
            }

            view.frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
            mtlView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        }

        updatePreferredFPS()
    }

    func updateInputTexture() {
        let screenRect = emulatorCore?.screenRect ?? .zero
        let pixelFormat = getMTLPixelFormat(from: emulatorCore?.pixelFormat ?? 0,
                                            type: emulatorCore?.pixelType ?? 0)

        var mtlPixelFormat = pixelFormat
        if emulatorCore?.rendersToOpenGL ?? false {
            mtlPixelFormat = .rgba8Unorm
        }

        if inputTexture == nil ||
            inputTexture?.width != Int(screenRect.width) ||
            inputTexture?.height != Int(screenRect.height) ||
            inputTexture?.pixelFormat != mtlPixelFormat {

            let desc = MTLTextureDescriptor()
            desc.textureType = .type2D
            desc.pixelFormat = mtlPixelFormat
            desc.width = Int(screenRect.width)
            desc.height = Int(screenRect.height)
            desc.storageMode = .private
            desc.usage = .shaderRead

            inputTexture = device?.makeTexture(descriptor: desc)
        }
    }

    func setupTexture() {
        updateInputTexture()

        if !(emulatorCore?.rendersToOpenGL ?? false) {
            let formatByteWidth = getByteWidth(for: emulatorCore?.pixelFormat ?? 0,
                                               type: emulatorCore?.pixelType ?? 0)

            for i in 0..<BUFFER_COUNT {
                let length = emulatorCore!.bufferSize.width * emulatorCore!.bufferSize.height * CGFloat(formatByteWidth)
                if length != 0 {
                    uploadBuffer[i] = device!.makeBuffer(length: Int(length), options: .storageModeShared)!
                } else {
                    let bufferSize = emulatorCore?.bufferSize ?? .zero
                    print("Invalid buffer size: Should be non-zero. Is <\(bufferSize.width),\(bufferSize.height)>")
                }
            }
        }

        let pointDesc = MTLSamplerDescriptor()
        pointDesc.minFilter = .nearest
        pointDesc.magFilter = .nearest
        pointDesc.mipFilter = .nearest
        pointDesc.sAddressMode = .clampToZero
        pointDesc.tAddressMode = .clampToZero
        pointDesc.rAddressMode = .clampToZero

        pointSampler = device?.makeSamplerState(descriptor: pointDesc)

        let linearDesc = MTLSamplerDescriptor()
        linearDesc.minFilter = .linear
        linearDesc.magFilter = .linear
        linearDesc.mipFilter = .nearest
        linearDesc.sAddressMode = .clampToZero
        linearDesc.tAddressMode = .clampToZero
        linearDesc.rAddressMode = .clampToZero

        linearSampler = device?.makeSamplerState(descriptor: linearDesc)
    }

    func getByteWidth(for pixelFormat: UInt32, type: UInt32) -> UInt {
        // implementation...
    }

    func getMTLPixelFormat(from glFormat: UInt32, type: UInt32) -> MTLPixelFormat {
        // implementation...
    }

    func setupBlitShader() {
        // implementation...
    }

    func setupEffectFilterShader(_ filterShader: Shader) {
        effectFilterShader = filterShader
        // rest of implementation...
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // no-op
    }

    func draw(in view: MTKView) {
        guard let emulatorCore = emulatorCore else {
            return
        }

        if emulatorCore.skipEmulationLoop {
            return
        }

        weak var weakSelf = self

        let renderBlock = {
            guard let self = weakSelf else {
                return
            }

            guard let outputTexture = view.currentDrawable?.texture else {
                return
            }

            if emulatorCore.rendersToOpenGL {
                emulatorCore.frontBufferLock.lock()
            }

            guard let commandBuffer = self.commandQueue?.makeCommandBuffer() else {
                return
            }
            self.previousCommandBuffer = commandBuffer

            let screenRect = emulatorCore.screenRect

            self.updateInputTexture()

            if !emulatorCore.rendersToOpenGL {
                let videoBuffer = emulatorCore.videoBuffer
                let videoBufferSize = emulatorCore.bufferSize
                let formatByteWidth = self.getByteWidth(for: emulatorCore.pixelFormat, type: emulatorCore.pixelType)
                let inputBytesPerRow = videoBufferSize.width * formatByteWidth

                let uploadBuffer = self.uploadBuffer[Int(self.frameCount % BUFFER_COUNT)]
                let uploadAddress = uploadBuffer?.contents()

                var outputBytesPerRow: UInt
                if screenRect.origin.x == 0 && (screenRect.width * 2 >= videoBufferSize.width) {
                    outputBytesPerRow = inputBytesPerRow
                    let inputAddress = videoBuffer + UInt(screenRect.origin.y) * inputBytesPerRow
                    memcpy(uploadAddress, inputAddress, screenRect.height * inputBytesPerRow)
                } else {
                    outputBytesPerRow = UInt(screenRect.width) * formatByteWidth
                    for i in 0..<UInt(screenRect.height) {
                        let inputRow = screenRect.origin.y + CGFloat(i)
                        let inputAddress = videoBuffer + (inputRow * CGFloat(inputBytesPerRow)) + (screenRect.origin.x * CGFloat(formatByteWidth))
                        let outputAddress = uploadAddress! + i * Int(outputBytesPerRow)
                        memcpy(outputAddress, inputAddress, Int(outputBytesPerRow))
                    }
                }

                guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
                    return
                }

                encoder.copy(from: uploadBuffer!,
                             sourceOffset: 0,
                             sourceBytesPerRow: Int(outputBytesPerRow),
                             sourceBytesPerImage: 0,
                             sourceSize: MTLSize(width: Int(screenRect.width), height: Int(screenRect.height), depth: 1),
                             to: self.inputTexture!,
                             destinationSlice: 0,
                             destinationLevel: 0,
                             destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))

                encoder.endEncoding()
            }

            let desc = MTLRenderPassDescriptor()
            desc.colorAttachments[0].texture = outputTexture
            desc.colorAttachments[0].loadAction = .clear
            desc.colorAttachments[0].storeAction = .store
            desc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else {
                return
            }

            if self.renderSettings.lcdFilterEnabled && emulatorCore.screenType.lowercased().contains("lcd") {
                // TODO
            } else if self.renderSettings.crtFilterEnabled && emulatorCore.screenType.lowercased().contains("crt") {
                if self._effectFilterShader?.name == "CRT" {
                    var cbData = CRT_Data()
                    cbData.displayRect = SIMD4<Float>(screenRect.origin.x, screenRect.origin.y,
                                                      Float(screenRect.width), Float(screenRect.height))
                    cbData.emulatedImageSize = SIMD2<Float>(Float(self.inputTexture!.width),
                                                            Float(self.inputTexture!.height))
                    cbData.finalRes = SIMD2<Float>(Float(view.drawableSize.width),
                                                   Float(view.drawableSize.height))

                    encoder.setFragmentBytes(&cbData, length: MemoryLayout<CRT_Data>.stride, index: 0)
                    encoder.setRenderPipelineState(self.effectFilterPipeline!)
                } else if self._effectFilterShader?.name == "Simple CRT" {
                    // set up Simple CRT uniform data
                    // ...
                } else if self._effectFilterShader?.name.contains(".fsh") {
                    // set up FSH shader uniform data
                    // ...
                }
            } else {
                encoder.setRenderPipelineState(self.blitPipeline!)
            }

            encoder.setFragmentTexture(self.inputTexture, index: 0)
            encoder.setFragmentSamplerState(self.renderSettings.smoothingEnabled ? self.linearSampler : self.pointSampler,
                                            index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()

            commandBuffer.present(view.currentDrawable!)
            commandBuffer.commit()

            if emulatorCore.rendersToOpenGL {
                emulatorCore.frontBufferLock.unlock()
            }
        }

        if emulatorCore.rendersToOpenGL {
            if !emulatorCore.isSpeedModified && !emulatorCore.isEmulationPaused || emulatorCore.isFrontBufferReady {
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

    // MARK: - PVRenderDelegate
    func startRenderingOnAlternateThread() {
        emulatorCore?.glesVersion = glesVersion

#if !(targetEnvironment(macCatalyst) || os(macOS))
        guard let glContext = glContext else {
            ELOG("glContext was nil, cannot start rendering on alternate thread")
            return
        }
        alternateThreadBufferCopyGLContext = EAGLContext(api: glContext.api,
                                                         sharegroup: glContext.sharegroup)
        alternateThreadGLContext = EAGLContext(api: glContext.api,
                                               sharegroup: glContext.sharegroup)
        EAGLContext.setCurrent(alternateThreadGLContext)
#endif

        if alternateThreadFramebufferBack == 0 {
            glGenFramebuffers(1, &alternateThreadFramebufferBack)
        }
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), alternateThreadFramebufferBack)

        if alternateThreadColorTextureBack == 0 {
            let width = emulatorCore?.bufferSize.width ?? 0
            let height = emulatorCore?.bufferSize.height ?? 0

            let dict: [CFString: Any] = [
                kIOSurfaceWidth: width,
                kIOSurfaceHeight: height,
                kIOSurfaceBytesPerElement: 4
            ]

            backingIOSurface = IOSurfaceCreate(dict as CFDictionary)
            IOSurfaceLock(backingIOSurface!, IOSurfaceLockOptions(rawValue: 0), nil)

            glGenTextures(1, &alternateThreadColorTextureBack)
            glBindTexture(GLenum(GL_TEXTURE_2D), alternateThreadColorTextureBack)

#if !(targetEnvironment(macCatalyst) || os(macOS))
            glContext.texImageIOSurface(backingIOSurface!, target: Int(GLenum(GL_TEXTURE_2D)),
                                         internalFormat: Int(GL_RGBA), width: UInt32(GLsizei(width)), height: UInt32(GLsizei(height)),
                                         format: Int(GLenum(GL_RGBA)), type: Int(GLenum(GL_UNSIGNED_BYTE)), plane: 0)
#else
            // TODO: This?
#endif

            glBindTexture(GLenum(GL_TEXTURE_2D), 0)

            IOSurfaceUnlock(backingIOSurface!, IOSurfaceLockOptions(rawValue: 0), nil)

            let mtlDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                   width: Int(width),
                                                                   height: Int(height),
                                                                   mipmapped: false)
            backingMTLTexture = device?.makeTexture(descriptor: mtlDesc, iosurface: backingIOSurface!, plane: 0)
        }
        glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
                               GLenum(GL_TEXTURE_2D), alternateThreadColorTextureBack, 0)

        if alternateThreadDepthRenderbuffer == 0 {
            glGenRenderbuffers(1, &alternateThreadDepthRenderbuffer)
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), alternateThreadDepthRenderbuffer)
            glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16),
                                  GLsizei(emulatorCore?.bufferSize.width ?? 0),
                                  GLsizei(emulatorCore?.bufferSize.height ?? 0))
            glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT),
                                      GLenum(GL_RENDERBUFFER), alternateThreadDepthRenderbuffer)
        }

        glViewport(GLint(emulatorCore?.screenRect.origin.x ?? 0),
                   GLint(emulatorCore?.screenRect.origin.y ?? 0),
                   GLsizei(emulatorCore?.screenRect.size.width ?? 0),
                   GLsizei(emulatorCore?.screenRect.size.height ?? 0))
    }

    func didRenderFrameOnAlternateThread() {
        glFlush()

        emulatorCore?.frontBufferLock.lock()

        previousCommandBuffer?.waitUntilScheduled()

        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            return
        }

        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            return
        }

        let screenRect = emulatorCore?.screenRect ?? .zero

        encoder.copy(from: backingMTLTexture!,
                     sourceSlice: 0, sourceLevel: 0,
                     sourceOrigin: MTLOrigin(x: Int(screenRect.origin.x),
                                             y: Int(screenRect.origin.y), z: 0),
                     sourceSize: MTLSize(width: Int(screenRect.width),
                                         height: Int(screenRect.height), depth: 1),
                     to: inputTexture!,
                     destinationSlice: 0, destinationLevel: 0,
                     destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))

        encoder.endEncoding()
        commandBuffer.commit()

        emulatorCore?.frontBufferLock.unlock()

        emulatorCore?.frontBufferCondition.lock()
        emulatorCore?.isFrontBufferReady = true
        emulatorCore?.frontBufferCondition.signal()
        emulatorCore?.frontBufferCondition.unlock()
    }
}

import ObjectiveC
//// Helper C functions
//func objc_sync_enter(_ obj: Any) {
//    objc_sync_enter(obj)
//}
//
//func objc_sync_exit(_ obj: Any) {
//    objc_sync_exit(obj)
//}





