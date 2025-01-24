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
import PVSettings
import PVUIObjC

#if os(macOS) || targetEnvironment(macCatalyst)
import OpenGL
#else
import OpenGLES
import OpenGLES.EAGL
import OpenGLES.EAGLDrawable
import OpenGLES.EAGLIOSurface
import OpenGLES.ES3
import OpenGLES.gltypes
#endif

fileprivate let BUFFER_COUNT: UInt = 3

extension GLenum {
    var toString: String {
        switch self {
        case GLenum(GL_UNSIGNED_BYTE): return "GL_UNSIGNED_BYTE"
        case GLenum(GL_BGRA): return "GL_BGRA"
        case GLenum(GL_RGBA): return "GL_RGBA"
        case GLenum(GL_RGB): return "GL_RGB"
        case GLenum(GL_RGB8): return "GL_RGB8"
        case GLenum(0x8367): return "GL_UNSIGNED_INT_8_8_8_8_REV"
            // Add more cases as needed
        default: return String(format: "0x%04X", self)
        }
    }
}

enum EffectFilterShaderError: Error {
    case emulatorCoreIsNil
    case deviceIsNIl
    case failedToCreateDefaultLibrary(Error)
    case noFillScreenShaderFound
    case errorCreatingVertexShader(Error)
    case errorCreatingFragmentShader(Error)
    case errorCreatingPipelineState(Error)
    case noBlitterShaderFound
    case noCurrentDrawableAvailable
}

final
class PVMetalViewController : PVGPUViewController, PVRenderDelegate, MTKViewDelegate {
    var presentationFramebuffer: AnyObject? = nil

    weak var emulatorCore: PVEmulatorCore? = nil

#if !os(visionOS)
    var mtlView: MTKView!
#endif

#if os(macOS) || targetEnvironment(macCatalyst)
    //    var isPaused: Bool = false
    //    var timeSinceLastDraw: TimeInterval = 0
    //    var framesPerSecond: Double = 0
#endif


    // MARK: Internal

    var alternateThreadFramebufferBack: GLuint = 0
    var alternateThreadColorTextureBack: GLuint = 0
    var alternateThreadDepthRenderbuffer: GLuint = 0

    var backingIOSurface: IOSurfaceRef?    // for OpenGL core support
    var backingMTLTexture: (any MTLTexture)?   // for OpenGL core support

    private var uploadBuffer: MTLBuffer? // Not an array
    var frameCount: UInt = 0

    var renderSettings: RenderSettings = .init()

    // MARK: Internal properties

    var  device: MTLDevice? = nil
    var  commandQueue: MTLCommandQueue? = nil
    var  blitPipeline: MTLRenderPipelineState? = nil

    var  effectFilterPipeline: MTLRenderPipelineState? = nil
    var  pointSampler: MTLSamplerState? = nil
    var  linearSampler: MTLSamplerState? = nil

    var  inputTexture: MTLTexture? = nil
    var  previousCommandBuffer: MTLCommandBuffer? = nil // used for scheduling with OpenGL context

#if !os(macOS) && !targetEnvironment(macCatalyst)
    var  glContext: EAGLContext?
    var  alternateThreadGLContext: EAGLContext?
    var  alternateThreadBufferCopyGLContext: EAGLContext?
#elseif !targetEnvironment(macCatalyst)
    var  glContext: NSOpenGLContext?
    var  alternateThreadGLContext: NSOpenGLContext?
    var  alternateThreadBufferCopyGLContext: NSOpenGLContext?
    var  caDisplayLink: CADisplayLink?
#endif

    var  glesVersion: GLESVersion = .version3
    var  effectFilterShader: Shader? = nil

    // MARK: Internal GL status

    var resolution_uniform: GLuint = 0
    var texture_uniform: GLuint = 0
    var previous_texture_uniform: GLuint = 0
    var frame_blending_mode_uniform: GLuint = 0

    var position_attribute: GLuint = 0
    var texture: GLuint = 0
    var previous_texture: GLuint = 0
    var program: GLuint = 0

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

        renderSettings.metalFilterMode = Defaults[.metalFilterMode]
        renderSettings.openGLFilterMode = Defaults[.openGLFilterMode]
        renderSettings.smoothingEnabled = Defaults[.imageSmoothing]

        Task {
            for await value in Defaults.updates([.metalFilterMode, .openGLFilterMode, .imageSmoothing]) {
                renderSettings.metalFilterMode = Defaults[.metalFilterMode]
                renderSettings.openGLFilterMode = Defaults[.openGLFilterMode]
                renderSettings.smoothingEnabled = Defaults[.imageSmoothing]
            }
        }
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
    }

    override func loadView() {
        /// Create MTKView with initial frame from screen bounds
        let screenBounds = UIScreen.main.bounds
        let metalView = MTKView(frame: screenBounds, device: device)
        metalView.autoresizingMask = [] // Disable autoresizing
        self.view = metalView
        self.mtlView = metalView

#if DEBUG
        ILOG("Initial MTKView frame: \(metalView.frame)")
#endif
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let metalView = view as? MTKView else {
            return
        }

        /// Setup OpenGL context if core renders to OpenGL
        if emulatorCore?.rendersToOpenGL ?? false {
#if os(macOS) || targetEnvironment(macCatalyst)
            if let context = createMacOpenGLContext() {
                glContext = context
                alternateThreadGLContext = createMacOpenGLContext()
                alternateThreadBufferCopyGLContext = createMacOpenGLContext()

#if DEBUG
                ILOG("Created macOS/Catalyst OpenGL contexts for core that renders to OpenGL")
#endif
            } else {
                ELOG("Failed to create macOS/Catalyst OpenGL context")
            }
#else
            if let context = bestContext {
                glContext = context
                alternateThreadGLContext = EAGLContext(api: context.api)
                alternateThreadBufferCopyGLContext = EAGLContext(api: context.api)

#if DEBUG
                ILOG("Created iOS OpenGL contexts for core that renders to OpenGL")
#endif
            } else {
                ELOG("Failed to create iOS OpenGL context")
            }
#endif
        }

        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.depthStencilPixelFormat = .depth32Float_stencil8
        metalView.sampleCount = 1
        metalView.delegate = self
        metalView.autoResizeDrawable = true

        // Set paused and only trigger redraw when needs display is set.
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false

        view.isOpaque = true
        view.layer.isOpaque = true
        view.isUserInteractionEnabled = false

#if DEBUG
        ILOG("MTKView frame after setup: \(metalView.frame)")
#endif

        frameCount = 0
        device = MTLCreateSystemDefaultDevice()

        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.depthStencilPixelFormat = .depth32Float_stencil8
        metalView.sampleCount = 1
        metalView.delegate = self
        metalView.autoResizeDrawable = true
        commandQueue = device?.makeCommandQueue()

        // Set paused and only trigger redraw when needs display is set.
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false

        view.isOpaque = true
        view.layer.isOpaque = true

        view.isUserInteractionEnabled = false

        updatePreferredFPS()

        if let emulatorCore = emulatorCore {
            let depthFormat: Int32 = Int32(emulatorCore.depthFormat)
            switch depthFormat {
            case GL_DEPTH_COMPONENT16:
                metalView.depthStencilPixelFormat = .depth16Unorm
            case GL_DEPTH_COMPONENT24:
                metalView.depthStencilPixelFormat = .x32_stencil8
#if !(targetEnvironment(macCatalyst) || os(iOS) || os(tvOS) || os(watchOS))
                if device?.isDepth24Stencil8PixelFormatSupported ?? false {
                    view.depthStencilPixelFormat = .x24_stencil8
                }
#endif
            default:
                break
            }
        }

        if Defaults[.nativeScaleEnabled] {
            let scale = UIScreen.main.scale
            if scale != 1 {
                view.layer.contentsScale = scale
                view.layer.rasterizationScale = scale
                view.contentScaleFactor = scale
            }
        }

        setupTexture()
        do {
            try setupBlitShader()
        } catch {
            ELOG("Setup blit shader creation error: \(error.localizedDescription)")
        }
        if let emulatorCore = emulatorCore {
            ILOG("Setting up shader for screen type: \(emulatorCore.screenType)")
            if let filterShader = MetalShaderManager.shared.filterShader(forOption: renderSettings.metalFilterMode,
                                                                         screenType: emulatorCore.screenType) {
                ILOG("Selected filter shader: \(filterShader.name)")
                do {
                    try setupEffectFilterShader(filterShader)
                } catch {
                    ELOG("Failed to setup effect filter shader: \(error)")
                }
            } else {
                ILOG("No filter shader selected for mode: \(renderSettings.metalFilterMode)")
            }
        }

        alternateThreadFramebufferBack = 0
        alternateThreadColorTextureBack = 0
        alternateThreadDepthRenderbuffer = 0
    }

#if os(macOS) || targetEnvironment(macCatalyst)
    /// Create OpenGL context for macOS/Catalyst
    private func createMacOpenGLContext() -> NSOpenGLContext? {
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAlphaSize), 8,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), 16,
            NSOpenGLPixelFormatAttribute(0)
        ]

        guard let pixelFormat = NSOpenGLPixelFormat(attributes: attributes) else {
            ELOG("Failed to create NSOpenGLPixelFormat")
            return nil
        }

        return NSOpenGLContext(format: pixelFormat, share: nil)
    }
#else
    /// iOS OpenGL context getter
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
        ILOG("updatePreferredFPS (\(preferredFPS))")
        if preferredFPS < 10 {
            WLOG("Cores frame interval (\(preferredFPS)) too low. Setting to 60")
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
    override var framesPerSecond: Double {
        get { super.framesPerSecond }
        set { super.framesPerSecond = newValue }
    }
#endif

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let emulatorCore = emulatorCore else {
            return
        }

#if DEBUG
        ILOG("Before layout - MTKView frame: \(mtlView.frame)")
#endif

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

            /// Get parent size in points (not scaled)
            var parentSize = parent?.view.bounds.size ?? CGSize.zero
            if let window = view.window {
                parentSize = window.bounds.size
            }

#if DEBUG
            ILOG("Parent size for calculations: \(parentSize)")
#endif

            var height: CGFloat = 0
            var width: CGFloat = 0

            /// Calculate dimensions in points first
            if parentSize.width > parentSize.height {
                if Defaults[.integerScaleEnabled] {
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
                if Defaults[.integerScaleEnabled] {
                    width = floor(parentSize.width / aspectSize.width) * aspectSize.width
                } else {
                    width = parentSize.width
                }
                height = width / ratio
                if height > parentSize.height {
                    height = parentSize.height
                    width = height * ratio
                }
            }

            /// Calculate center position
            let x = (parentSize.width - width) / 2
            let y = traitCollection.userInterfaceIdiom == .phone && parentSize.height > parentSize.width ?
            parentSafeAreaInsets.top + 40 : // below menu button
            (parentSize.height - height) / 2 // centered

            /// Create frame with calculated position and size
            let frame = CGRect(x: x, y: y, width: width, height: height)

#if DEBUG
            ILOG("Calculated frame: \(frame)")
#endif

            if Defaults[.nativeScaleEnabled] {
                let scale = UIScreen.main.scale

                /// Apply frame to main view
                view.frame = frame

                /// Position MTKView using frame directly
                mtlView.frame = CGRect(x: x, y: y, width: width, height: height)
                mtlView.contentScaleFactor = scale

#if DEBUG
                ILOG("Applied scale factor: \(scale)")
                ILOG("Final MTKView frame: \(mtlView.frame)")
#endif
            } else {
                view.frame = frame
                mtlView.frame = frame
                mtlView.contentScaleFactor = 1.0

#if DEBUG
                ILOG("Final MTKView frame (no scale): \(mtlView.frame)")
#endif
            }
        }

        updatePreferredFPS()
    }

#if DEBUG
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        /// Print full view hierarchy for debugging
        ILOG("Full view hierarchy:")
        var currentView: UIView? = mtlView
        while let view = currentView {
            ILOG("View: \(type(of: view))")
            ILOG("Frame: \(view.frame)")
            ILOG("Bounds: \(view.bounds)")
            ILOG("Transform: \(view.transform)")
            ILOG("AutoresizingMask: \(view.autoresizingMask)")
            ILOG("Constraints: \(view.constraints)")
            ILOG("SuperView: \(String(describing: view.superview))")
            ILOG("----------------")
            currentView = view.superview
        }
    }
#endif

    func updateInputTexture() {
        guard let emulatorCore = emulatorCore else {
            ELOG("emulatorCore is nil in updateInputTexture()")
            return
        }


        let screenRect = emulatorCore.screenRect
        guard screenRect != .zero else {
            ELOG("Screenrect was zero, exiting early")
            return
        }

        let pixelFormat = getMTLPixelFormat(from: emulatorCore.pixelFormat,
                                            type: emulatorCore.pixelType)

        //        VLOG("Updating input texture with screenRect: \(screenRect), pixelFormat: \(pixelFormat)")

#if targetEnvironment(simulator)
        var mtlPixelFormat: MTLPixelFormat = .astc_6x5_srgb
#else
        var mtlPixelFormat: MTLPixelFormat = pixelFormat
#endif
        if emulatorCore.rendersToOpenGL {
            mtlPixelFormat = .rgba8Unorm
            // TODO: Part of this is a copy paste,
            // one version was working with gles cores,
            // the but crashed on jaguar non-gl, so i made
            // it the gles only version
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

                if let inputTexture = inputTexture {
//                    ILOG("Created new input texture with size: \(inputTexture.width)x\(inputTexture.height), format: \(inputTexture.pixelFormat)")
                } else {
                    ELOG("Failed to create input texture")
                }
            }
        } else {
            if inputTexture == nil ||
                inputTexture?.width != Int(screenRect.width) ||
                inputTexture?.height != Int(screenRect.height) ||
                inputTexture?.pixelFormat != mtlPixelFormat {

                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.width = Int(screenRect.width)
                textureDescriptor.height = Int(screenRect.height)

                // Handle different pixel formats
                if emulatorCore.pixelFormat == GLenum(GL_RGB565) ||
                   emulatorCore.pixelType == GLenum(GL_UNSIGNED_SHORT_5_6_5) {
                    textureDescriptor.pixelFormat = .b5g6r5Unorm  // Use BGR565 for RGB565 input
//                    ILOG("Using B5G6R5 format for RGB565 input")
                } else if emulatorCore.pixelFormat == GLenum(GL_BGRA) {
                    textureDescriptor.pixelFormat = .bgra8Unorm
//                    ILOG("Using BGRA8 format")
                } else {
                    textureDescriptor.pixelFormat = .rgba8Unorm
//                    ILOG("Using RGBA8 format")
                }

                textureDescriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
                textureDescriptor.storageMode = .private

//                ILOG("""
//                Creating new input texture:
//                - Size: \(screenRect.width)x\(screenRect.height)
//                - Core pixel format: \(emulatorCore.pixelFormat.toString)
//                - Core pixel type: \(emulatorCore.pixelType.toString)
//                - MTL pixel format: \(textureDescriptor.pixelFormat)
//                """)

                inputTexture = device?.makeTexture(descriptor: textureDescriptor)
            }
        }
    }

    // TODO: Make throw
    func setupTexture() {
        precondition(emulatorCore != nil)
        precondition(device != nil)

        guard let emulatorCore = emulatorCore else {
            ELOG("emulatorCore is nil")
            return
        }

        guard let device = device else {
            ELOG("device is nil")
            return
        }

        updateInputTexture()

        if !emulatorCore.rendersToOpenGL {
            let formatByteWidth = getByteWidth(for: Int32(emulatorCore.pixelFormat),
                                               type: Int32(emulatorCore.pixelType))

            let width = emulatorCore.bufferSize.width
            let height = emulatorCore.bufferSize.height
            let length = Int(width * height) * Int(formatByteWidth)

            if length > 0 {
                uploadBuffer = device.makeBuffer(length: length,
                                               options: .storageModeShared)
                ILOG("Created upload buffer with length: \(length)")
            } else {
                ELOG("Invalid buffer size: Should be non-zero. Is <\(width),\(height)>")
            }
        }

        let pointDesc = MTLSamplerDescriptor()
        pointDesc.minFilter = .nearest
        pointDesc.magFilter = .nearest
        pointDesc.mipFilter = .nearest
        pointDesc.sAddressMode = .clampToZero
        pointDesc.tAddressMode = .clampToZero
        pointDesc.rAddressMode = .clampToZero

        pointSampler = device.makeSamplerState(descriptor: pointDesc)

        let linearDesc = MTLSamplerDescriptor()
        linearDesc.minFilter = .linear
        linearDesc.magFilter = .linear
        linearDesc.mipFilter = .nearest
        linearDesc.sAddressMode = .clampToZero
        linearDesc.tAddressMode = .clampToZero
        linearDesc.rAddressMode = .clampToZero

        linearSampler = device  .makeSamplerState(descriptor: linearDesc)
    }

    func getByteWidth(for pixelFormat: Int32, type pixelType: Int32) -> UInt {
        return getByteWidthNeo(for: pixelFormat, type: pixelType)
    }
    func getByteWidthLegacy(for pixelFormat: Int32, type pixelType: Int32) -> UInt {
        var typeWidth: UInt = 0
        switch pixelType {
        case GL_BYTE, GL_UNSIGNED_BYTE:
            typeWidth = 2
        case GL_UNSIGNED_SHORT_5_5_5_1, GL_SHORT, GL_UNSIGNED_SHORT, GL_UNSIGNED_SHORT_5_6_5:
            typeWidth = 2
        case GL_INT, GL_UNSIGNED_INT, GL_FLOAT, GL_FLOAT_32_UNSIGNED_INT_24_8_REV, 0x8367: // GL_UNSIGNED_INT_8_8_8_8_REV:
            typeWidth = 4
        default:
            assertionFailure("Unknown GL pixelType. Add me")
        }

        switch pixelFormat {
        case GL_BGRA, GL_RGBA:
            switch pixelType {
            case GL_UNSIGNED_BYTE:
                return 2 * typeWidth
            case GL_UNSIGNED_SHORT_4_4_4_4, GL_UNSIGNED_SHORT_5_5_5_1, GL_UNSIGNED_SHORT_5_6_5:
                return 2 * typeWidth
            default:
                return 4 * typeWidth
            }
            //    #if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        case GL_RGB565, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, GL_RGB:
            //    #else
            //          case GL_UNSIGNED_SHORT_5_6_5, GL_RGB:
            //    #endif
            switch pixelType {
            case GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_4_4_4_4, GL_UNSIGNED_SHORT_5_5_5_1, GL_UNSIGNED_SHORT_5_6_5:
                return typeWidth
            default:
                return 4 * typeWidth
            }
        case GL_RGB5_A1:
            return 4 * typeWidth
        case GL_RGB8, GL_RGBA8:
            return 8 * typeWidth
        default:
            break;
        }

        assertionFailure("Unknown GL pixelFormat %x. Add me: \(pixelFormat)")
        return 1
    }

    func getByteWidthNeo(for pixelFormat: Int32, type pixelType: Int32) -> UInt {
        // Determine component size
        let componentSize: Int
        switch pixelType {
        case GL_BYTE, GL_UNSIGNED_BYTE:
            componentSize = 1
        case GL_SHORT, GL_UNSIGNED_SHORT, GL_UNSIGNED_SHORT_5_6_5, GL_UNSIGNED_SHORT_4_4_4_4, GL_UNSIGNED_SHORT_5_5_5_1:
            componentSize = 2
        case GL_INT, GL_UNSIGNED_INT, GL_FLOAT, GL_FLOAT_32_UNSIGNED_INT_24_8_REV:
            componentSize = 4
        case 0x8367: // GL_UNSIGNED_INT_8_8_8_8_REV
            return 4 // This is always 4 bytes per pixel
        default:
            WLOG("Warning: Unknown GL pixelType: \(pixelType)")
            return 0
        }

        // Handle special cases first
        switch (pixelFormat, pixelType) {
        case (_, GL_UNSIGNED_SHORT_5_6_5),
            (_, GL_UNSIGNED_SHORT_4_4_4_4),
            (_, GL_UNSIGNED_SHORT_5_5_5_1):
            return 2
        case (GL_RGBA8, _):
            return 4
        case (GL_RGB8, _):
            return 3 // Note: This might be 4 in practice due to alignment, but technically it's 3 bytes
        case (GL_RGB5_A1, _):
            return 2
        default:
            break
        }

        // Determine components per pixel
        let componentsPerPixel: Int
        switch pixelFormat {
        case GL_RGBA, GL_BGRA, GL_RGBA8:
            componentsPerPixel = 4
        case GL_RGB, GL_RGB565, GL_RGB8:
            componentsPerPixel = 3
        case GL_LUMINANCE_ALPHA:
            componentsPerPixel = 2
        case GL_LUMINANCE, GL_ALPHA:
            componentsPerPixel = 1
        case GL_R8:
            componentsPerPixel = 1
        case GL_RG8:
            componentsPerPixel = 2
        default:
            WLOG("Warning: Unknown GL pixelFormat: \(pixelFormat)")
            assertionFailure("Warning: Unknown GL pixelFormat: \(pixelFormat)")
            return 1
        }

        return UInt(componentSize * componentsPerPixel)
    }


    func getMTLPixelFormat(from pixelFormat: GLenum, type pixelType: GLenum) -> MTLPixelFormat {
        return getMTLPixelFormatNeo(from: pixelFormat, type: pixelType)
    }

    func getMTLPixelFormatNeo(from pixelFormat: GLenum, type pixelType: GLenum) -> MTLPixelFormat {
        //        VLOG("Getting MTLPixelFormat for pixelFormat: \(pixelFormat.toString), pixelType: \(pixelType.toString)")
        switch (pixelFormat, pixelType) {
        case (GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE)),
            (GLenum(GL_BGRA), GLenum(0x8367)): // GL_UNSIGNED_INT_8_8_8_8_REV
            return .bgra8Unorm
        case (GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT)):
            return .bgra8Unorm
        case (GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE)),
            (GLenum(GL_RGBA8), GLenum(GL_UNSIGNED_BYTE)):
            return .rgba8Unorm
        case (GLenum(GL_RGBA), GLenum(GL_BYTE)):
            return .rgba8Snorm
        case (GLenum(GL_RGB), GLenum(GL_UNSIGNED_BYTE)),
            (GLenum(GL_RGB8), GLenum(GL_UNSIGNED_BYTE)):
            // Note: Metal doesn't have a direct RGB8 format, using RGBA8 and ignoring alpha
            return .rgba8Unorm
        case (GLenum(GL_RGB), GLenum(GL_UNSIGNED_SHORT)):
            return .rgb10a2Unorm // Better match for RGB unsigned short
        case (GLenum(GL_RGB), GLenum(GL_UNSIGNED_SHORT_5_6_5)),
            (GLenum(GL_BGRA), GLenum(GL_UNSIGNED_SHORT_5_6_5)),
            (GLenum(GL_UNSIGNED_SHORT_5_6_5), GLenum(GL_UNSIGNED_BYTE)):
            return .b5g6r5Unorm
        case (GLenum(GL_RGB), GLenum(GL_UNSIGNED_INT)):
            return .rgba32Uint // Approximation, might lose precision
        case (_, GLenum(GL_UNSIGNED_SHORT_8_8_APPLE)):
            return .rg8Unorm // Approximation, might need custom handling
        case (_, GLenum(GL_UNSIGNED_SHORT_5_5_5_1)):
            return .a1bgr5Unorm
        case (_, GLenum(GL_UNSIGNED_SHORT_4_4_4_4)):
            return .abgr4Unorm
        case (GLenum(GL_RGBA8), GLenum(GL_UNSIGNED_SHORT)):
            return .rgba16Uint
        case (GLenum(GL_RGBA8), GLenum(GL_UNSIGNED_INT)):
            return .rgba32Uint
        case (GLenum(GL_R8), _):
            return .r8Unorm
        case (GLenum(GL_RG8), _):
            return .rg8Unorm
#if !targetEnvironment(macCatalyst) && !os(macOS)
        case (GLenum(GL_RGB565), _):
            return .b5g6r5Unorm
#else
        case (GLenum(GL_UNSIGNED_SHORT_5_6_5), _):
            return .b5g6r5Unorm
#endif
            // Add more cases as needed for your specific use cases
        default:
            WLOG("Unknown GL pixelFormat: \(pixelFormat.toString), pixelType: \(pixelType.toString). Defaulting to .rgba8Unorm")
            return .rgba8Unorm
        }
    }

    func getMTLPixelFormatLegacy(from pixelFormat: GLenum, type pixelType: GLenum) -> MTLPixelFormat {
        if pixelFormat == GLenum(GL_BGRA),
           pixelType == GLenum(GL_UNSIGNED_BYTE) ||
            pixelType == GLenum(0x8367) {
            return .bgra8Unorm
        }
        else if pixelFormat == GLenum(GL_BGRA),
                pixelType == GLenum(GL_UNSIGNED_BYTE) {
            return .bgra8Unorm
        }
        else if pixelFormat == GLenum(GL_BGRA),
                pixelType == GLenum(GL_UNSIGNED_INT) {
            return .bgra8Unorm_srgb
        }
        else if pixelFormat == GLenum(GL_BGRA),
                pixelType == GLenum(GL_FLOAT_32_UNSIGNED_INT_24_8_REV) {
            return .bgra8Unorm_srgb
        }
        else if pixelFormat == GLenum(GL_RGBA),
                pixelType == GLenum(GL_UNSIGNED_BYTE) {
            return .rgba8Unorm
        }
        else if pixelFormat == GLenum(GL_RGBA),
                pixelType == GLenum(GL_BYTE) {
            return .rgba8Snorm
        }
        else if pixelFormat == GLenum(GL_RGB),
                pixelType == GLenum(GL_UNSIGNED_BYTE) {
            return .rgba8Unorm
        }
        else if pixelFormat == GLenum(GL_RGB),
                pixelType == GLenum(GL_UNSIGNED_SHORT) {
            return .rgba16Uint
        }
        else if pixelFormat == GLenum(GL_RGB),
                pixelType == GLenum(GL_UNSIGNED_SHORT_5_6_5) {
            return .b5g6r5Unorm
        }
        else if pixelFormat == GLenum(GL_RGB),
                pixelType == GLenum(GL_UNSIGNED_INT) {
            return .rgba16Unorm
        }
        else if pixelType == GLenum(GL_UNSIGNED_SHORT_8_8_APPLE) {
            return .rgba16Unorm
        }
        else if pixelType == GLenum(GL_UNSIGNED_SHORT_5_5_5_1) {
            return .a1bgr5Unorm
        }
        else if pixelType == GLenum(GL_UNSIGNED_SHORT_4_4_4_4) {
            return .abgr4Unorm
        }
        else if pixelFormat == GLenum(GL_RGBA8) {
            if pixelType == GLenum(GL_UNSIGNED_BYTE) {
                return .rgba8Unorm
            } else if pixelType == GLenum(GL_UNSIGNED_SHORT) {
                return .rgba16Uint
            } else if pixelType == GLenum(GL_UNSIGNED_INT) {
                return .rgba32Uint
            }
        }
#if !targetEnvironment(macCatalyst) && !os(macOS)
        if pixelFormat == GLenum(GL_RGB565) {
            return .b5g6r5Unorm //.rgba16Unorm
        }
#else
        if pixelFormat == GLenum(GL_UNSIGNED_SHORT_5_6_5) {
            return .rgba16Unorm
        }
#endif
        print("Error: Unknown GL pixelFormat. Add pixelFormat: \(pixelFormat) pixelType: \(pixelType)")
        assertionFailure("Unknown GL pixelFormat. Add pixelFormat: \(pixelFormat) pixelType: \(pixelType)")
        return .invalid
    }

    // TODO: Make this throw
    func setupBlitShader() throws {
        guard let emulatorCore = emulatorCore else {
            ELOG("emulatorCore is nil in setupBlitShader()")
            throw EffectFilterShaderError.emulatorCoreIsNil
        }

        guard let device = device else {
            ELOG("device is nil in setupBlitShader()")
            throw EffectFilterShaderError.deviceIsNIl
        }

        let constants = MTLFunctionConstantValues()
        var flipY = emulatorCore.rendersToOpenGL
        constants.setConstantValue(&flipY, type: .bool, withName: "FlipY")

        let lib: MTLLibrary
        do {
            lib = try device.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            ELOG("Failed to create default library")
            throw EffectFilterShaderError.failedToCreateDefaultLibrary(error)
        }

        let desc = MTLRenderPipelineDescriptor()
        guard let fillScreenShader = MetalShaderManager.shared.vertexShaders.first else {
            ELOG("No fill screen shader found")
            throw EffectFilterShaderError.noFillScreenShaderFound
        }

        do {
            desc.vertexFunction = try lib.makeFunction(name: fillScreenShader.function, constantValues: constants)
        } catch let error {
            ELOG("Error creating vertex function: \(error)")
            throw EffectFilterShaderError.errorCreatingVertexShader(error)
        }

        guard let blitterShader = MetalShaderManager.shared.blitterShaders.first else {
            ELOG("No blitter shader found")
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        desc.fragmentFunction = lib.makeFunction(name: blitterShader.function)

        if let currentDrawable = mtlView.currentDrawable {
            desc.colorAttachments[0].pixelFormat = currentDrawable.texture.pixelFormat
        } else {
            ELOG("No current drawable available")
            throw EffectFilterShaderError.noCurrentDrawableAvailable
        }

        do {
            blitPipeline = try device.makeRenderPipelineState(descriptor: desc)
            ILOG("Successfully created blit pipeline state")
        } catch let error {
            ELOG("Error creating render pipeline state: \(error)")
            throw EffectFilterShaderError.errorCreatingPipelineState(error)
        }
    }

    func setupEffectFilterShader(_ filterShader: Shader) throws {
        ILOG("Setting up effect filter shader: \(filterShader.name)")

        guard let emulatorCore = emulatorCore else {
            ELOG("emulatorCore is nil")
            throw EffectFilterShaderError.emulatorCoreIsNil
        }

        guard let device = device else {
            ELOG("device is nil")
            throw EffectFilterShaderError.deviceIsNIl
        }

        effectFilterShader = filterShader

        let constants = MTLFunctionConstantValues()
        var flipY = emulatorCore.rendersToOpenGL
        constants.setConstantValue(&flipY, type: .bool, withName: "FlipY")
        ILOG("FlipY value: \(flipY)")

        let lib: MTLLibrary
        do {
            lib = try device.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            ELOG("Failed to create default library")
            throw EffectFilterShaderError.failedToCreateDefaultLibrary(error)
        }

        let desc = MTLRenderPipelineDescriptor()
        guard let fillScreenShader = MetalShaderManager.shared.vertexShaders.first else {
            ELOG("No fill screen shader found")
            throw EffectFilterShaderError.noFillScreenShaderFound
        }

        ILOG("Creating vertex function: \(fillScreenShader.function)")
        do {
            desc.vertexFunction = try lib.makeFunction(name: fillScreenShader.function, constantValues: constants)
        } catch let error {
            ELOG("Error creating vertex function: \(error)")
            throw EffectFilterShaderError.errorCreatingVertexShader(error)
        }

        ILOG("Creating fragment function: \(filterShader.function)")
        desc.fragmentFunction = lib.makeFunction(name: filterShader.function)

        if let currentDrawable = mtlView.currentDrawable {
            desc.colorAttachments[0].pixelFormat = currentDrawable.texture.pixelFormat
            ILOG("Set pixel format: \(currentDrawable.texture.pixelFormat.rawValue)")
        } else {
            ELOG("No current drawable available")
            throw EffectFilterShaderError.noCurrentDrawableAvailable
        }

        do {
            ILOG("Creating pipeline state...")
            effectFilterPipeline = try device.makeRenderPipelineState(descriptor: desc)
            ILOG("Successfully created effect filter pipeline state")
        } catch let error {
            ELOG("Error creating render pipeline state: \(error)")
            throw EffectFilterShaderError.errorCreatingPipelineState(error)
        }
    }


    class func shader(withContents contents: String, type: GLenum) -> GLuint {
        let source = (contents as NSString).utf8String

        // Create the shader object
        let shader = glCreateShader(type)

        // Load the shader source
        var sourcePointer = source
        glShaderSource(shader, 1, &sourcePointer, nil)

        // Compile the shader
        glCompileShader(shader)

        // Check for errors
        var status: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)

        if status == GLint(GL_FALSE) {
            var messages = [GLchar](repeating: 0, count: 1024)
            glGetShaderInfoLog(shader, GLsizei(messages.count), nil, &messages)
            let messageString = String(cString: messages)
            ELOG("\(Self.self) - GLSL Shader Error: \(messageString)")
        }

        return shader
    }

    class func program(vertexShader vsh: String, fragmentShader fsh: String) -> GLuint {
        // Build shaders
        let vertexShader = Self.shader(withContents: vsh, type: GLenum(GL_VERTEX_SHADER))
        let fragmentShader = Self.shader(withContents: fsh, type: GLenum(GL_FRAGMENT_SHADER))

        // Create program
        let program = glCreateProgram()

        // Attach shaders
        glAttachShader(program, vertexShader)
        glAttachShader(program, fragmentShader)

        // Link program
        glLinkProgram(program)

        // Check for errors
        var status: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)

        if status == GLint(GL_FALSE) {
            var messages = [GLchar](repeating: 0, count: 1024)
            glGetProgramInfoLog(program, GLsizei(messages.count), nil, &messages)
            let messageString = String(cString: messages)
            ELOG("\(Self.self) - GLSL Program Error: \(messageString)")
        }

        // Delete shaders
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)

        return program
    }


    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // no-op
        DLOG("drawableSizeWillChange: \(size), UNSUPPORTED")
    }

    @inlinable
    func draw(in view: MTKView) {
        guard let emulatorCore = emulatorCore else {
            ELOG("EmulatorCore is nil")
            return
        }

        if emulatorCore.skipEmulationLoop {
            return
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
                    calculateViewportIfNeeded()
                    glViewport(GLint(cachedViewportX),
                               GLint(cachedViewportY),
                               GLsizei(cachedViewportWidth),
                               GLsizei(cachedViewportHeight))

                    self._render(emulatorCore, in: view)
                    emulatorCore.frontBufferCondition.lock()
                    emulatorCore.isFrontBufferReady = false
                    emulatorCore.frontBufferCondition.signal()
                    emulatorCore.frontBufferCondition.unlock()
                }
            }
        } else {
            if emulatorCore.isSpeedModified {
                self._render(emulatorCore, in: view)
            } else if emulatorCore.isDoubleBuffered {
                emulatorCore.frontBufferCondition.lock()
                while !emulatorCore.isFrontBufferReady && !emulatorCore.isEmulationPaused {
                    emulatorCore.frontBufferCondition.wait()
                }
                emulatorCore.isFrontBufferReady = false
                emulatorCore.frontBufferLock.lock()
                self._render(emulatorCore, in: view)
                emulatorCore.frontBufferLock.unlock()
                emulatorCore.frontBufferCondition.unlock()
            } else {
                objc_sync_enter(emulatorCore)
                self._render(emulatorCore, in: view)
                objc_sync_exit(emulatorCore)
            }
        }
    }

    @inlinable
    @inline(__always)
    func _render(_ emulatorCore: PVEmulatorCore, in view: MTKView) {
        guard let outputTexture = view.currentDrawable?.texture else {
            return
        }

        if emulatorCore.rendersToOpenGL {
            emulatorCore.frontBufferLock.lock()
        }

        //        VLOG("Drawing frame with pixelFormat: \(emulatorCore.pixelFormat.toString), pixelType: \(emulatorCore.pixelType.toString), internalPixelFormat: \(emulatorCore.internalPixelFormat.toString)")

        guard let commandBuffer = self.commandQueue?.makeCommandBuffer() else {
            ELOG("Failed to create command buffer")
            return
        }
        self.previousCommandBuffer = commandBuffer

        let screenRect = emulatorCore.screenRect

        self.updateInputTexture()

        if !emulatorCore.rendersToOpenGL, let videoBuffer: UnsafeMutableRawPointer = emulatorCore.videoBuffer {
            
            let bufferSize = emulatorCore.bufferSize
            let actualSize = emulatorCore.aspectSize  // This is the actual visible area
            let bytesPerPixel = emulatorCore.pixelType == GLenum(GL_UNSIGNED_BYTE) ? 4 : 4
            
            // Calculate aligned bytes per row for the full buffer width
            let sourceBytesPerRow = alignedBytesPerRow(Int(bufferSize.width), bytesPerPixel: bytesPerPixel)
            let totalBufferSize = sourceBytesPerRow * Int(bufferSize.height)
            
            // Ensure upload buffer is large enough for the full buffer
            if uploadBuffer == nil || uploadBuffer?.length ?? 0 < totalBufferSize,
               let device = device {
                uploadBuffer = device.makeBuffer(length: totalBufferSize,
                                                 options: .storageModeShared)
                ILOG("Created new upload buffer with size: \(totalBufferSize)")
            }
            
            // Copy the video buffer to the upload buffer
            if let videoBuffer = emulatorCore.videoBuffer,
               let uploadBuffer = uploadBuffer {
                memcpy(uploadBuffer.contents(),
                       videoBuffer,
                       totalBufferSize)
            }
            
            // Create a blit command encoder instead of using render command encoder
            if let blitEncoder = commandBuffer.makeBlitCommandEncoder(),
               let uploadBuffer = uploadBuffer {
                let sourceSize = MTLSize(width: Int(screenRect.width),
                                         height: Int(screenRect.height),
                                         depth: 1)
                
                // Calculate bytes per pixel based on format
                let bytesPerPixel: Int
                if emulatorCore.pixelFormat == GLenum(GL_RGB565) ||
                    emulatorCore.pixelType == GLenum(GL_UNSIGNED_SHORT_5_6_5) {
                    bytesPerPixel = 2  // RGB565 is 16-bit (2 bytes) per pixel
                } else {
                    bytesPerPixel = 4  // RGBA/BGRA is 32-bit (4 bytes) per pixel
                }
                
                // Calculate the actual bytes per row of the source buffer
                let actualBytesPerRow = Int(bufferSize.width) * bytesPerPixel
                // Align it for Metal and match the core's pitch
                let alignedSourceBytesPerRow = Int(emulatorCore.bufferSize.width) * bytesPerPixel  // Use videoWidth instead of bufferSize.width
                
                // Calculate offsets
                let xOffset = Int(screenRect.origin.x)
                let yOffset = Int(screenRect.origin.y)
                
                // Calculate the source offset in bytes
                let sourceOffset = (yOffset * actualBytesPerRow) + (xOffset * bytesPerPixel)
                
//                ILOG("""
//            Metal copy details:
//            - Buffer size: \(bufferSize)
//            - Screen rect: \(screenRect)
//            - Source offset: (\(xOffset), \(yOffset))
//            - Bytes per pixel: \(bytesPerPixel)
//            - Core pitch: \(emulatorCore.bufferSize.width * CGFloat(bytesPerPixel))
//            - Actual bytes per row: \(actualBytesPerRow)
//            - Buffer size: \(totalBufferSize)
//            - Source size: \(sourceSize)
//            - Source offset in bytes: \(sourceOffset)
//            """)
                
                blitEncoder.copy(from: uploadBuffer,
                                 sourceOffset: sourceOffset,
                                 sourceBytesPerRow: Int(emulatorCore.bufferSize.width) * bytesPerPixel,  // Use core's buffer width
                                 sourceBytesPerImage: totalBufferSize,
                                 sourceSize: sourceSize,
                                 to: inputTexture!,
                                 destinationSlice: 0,
                                 destinationLevel: 0,
                                 destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                
                blitEncoder.endEncoding()
            }
        }

        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = outputTexture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        desc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else {
            ELOG("Failed to create render command encoder")
            return
        }

        var pipelineState: MTLRenderPipelineState?

        let metalFilterOption: MetalFilterModeOption = self.renderSettings.metalFilterMode
        let useLCD: Bool
        let useCRT: Bool
        switch metalFilterOption {
        case .none:
            useLCD = false
            useCRT = false
        case .always(let filter):
            switch filter {
            case .none:
                useCRT = false
                useLCD = false
            case .complexCRT, .simpleCRT:
                useLCD = false
                useCRT = true
            case .lcd:
                useLCD = true
                useCRT = false
                //            case .lineTron:
                //                useLCD = false
                //                useCRT = true
            case .megaTron:
                useLCD = false
                useCRT = true
                //            case .ulTron:
                //                useLCD = false
                //                useCRT = true
            case .gameBoy:
                useLCD = true
                useCRT = false
            case .vhs:
                useLCD = false
                useCRT = true
            }
        case .auto(let crt, let lcd):
            useLCD = emulatorCore.screenType.isLCD
            useCRT = emulatorCore.screenType.isCRT
        }


        if useLCD {
            let sourceSize = SIMD4<Float>(
                Float(inputTexture!.width),
                Float(inputTexture!.height),
                1.0 / Float(inputTexture!.width),
                1.0 / Float(inputTexture!.height)
            )
            let outputSize = SIMD4<Float>(
                Float(view.drawableSize.width),
                Float(view.drawableSize.height),
                1.0 / Float(view.drawableSize.width),
                1.0 / Float(view.drawableSize.height)
            )

            /// Check which LCD filter to use
            if self.effectFilterShader?.name == "Game Boy" {
                /// Classic Game Boy green palette
                let darkestGreen = SIMD4<Float>(0.0588, 0.2196, 0.0588, 1.0)  /// #0F380F
                let darkGreen = SIMD4<Float>(0.1882, 0.3882, 0.1882, 1.0)     /// #306230
                let lightGreen = SIMD4<Float>(0.5451, 0.6745, 0.0588, 1.0)    /// #8BAC0F
                let lightestGreen = SIMD4<Float>(0.6078, 0.7373, 0.0588, 1.0) /// #9BBC0F

                var uniforms = GameBoyUniforms(
                    SourceSize: sourceSize,
                    OutputSize: outputSize,
                    dotMatrix: 0.7,        /// Dot matrix effect intensity (0.0-1.0)
                    contrast: 1.2,         /// Contrast adjustment
                    palette: (darkestGreen, darkGreen, lightGreen, lightestGreen)
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GameBoyUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
            } else {
                /// Default LCD filter
                let displayRect = SIMD4<Float>(Float(screenRect.origin.x), Float(screenRect.origin.y),
                                               Float(screenRect.width), Float(screenRect.height))
                let textureSize = SIMD2<Float>(Float(self.inputTexture!.width),
                                               Float(self.inputTexture!.height))

                var uniforms = LCDFilterUniforms(
                    screenRect:     displayRect,
                    textureSize:    textureSize,
                    gridDensity:    1.75,    /// Adjust these values to taste
                    gridBrightness: 0.25,    /// Lower value = more subtle effect
                    contrast:       1.2,     /// Slight contrast boost
                    saturation:     1.1,     /// Slight saturation boost
                    ghosting:       0.15,    /// Subtle ghosting effect
                    scanlineDepth:  0.20,    /// From MonoLCD
                    bloomAmount:    0.2,     /// From MonoLCD
                    colorLow:       0.8,     /// From LCD.fsh
                    colorHigh:      1.05     /// From LCD.fsh
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LCDFilterUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
            }
        } else if useCRT {
            if self.effectFilterShader?.name == "Complex CRT" {
                let displayRect = SIMD4<Float>(Float(screenRect.origin.x), Float(screenRect.origin.y),
                                               Float(screenRect.width), Float(screenRect.height))
                let emulatedImageSize = SIMD2<Float>(Float(self.inputTexture!.width),
                                                     Float(self.inputTexture!.height))
                let finalRes = SIMD2<Float>(Float(view.drawableSize.width),
                                            Float(view.drawableSize.height))
                var cbData = CRT_Data(
                    DisplayRect: displayRect,
                    EmulatedImageSize: emulatedImageSize,
                    FinalRes: finalRes)

                encoder.setFragmentBytes(&cbData, length: MemoryLayout<CRT_Data>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
            } else if self.effectFilterShader?.name == "Simple CRT" {
                ILOG("Setting up Simple CRT pipeline")
                let mameScreenSrcRect: SIMD4<Float> = SIMD4<Float>.init(0, 0, Float(screenRect.size.width), Float(screenRect.size.height))
                let mameScreenDstRect: SIMD4<Float> = SIMD4<Float>.init(Float(inputTexture!.width), Float(inputTexture!.height), Float(view.drawableSize.width), Float(view.drawableSize.height))

                var cbData = SimpleCrtUniforms(
                    mame_screen_dst_rect: mameScreenDstRect,
                    mame_screen_src_rect: mameScreenSrcRect,
                    curv_vert: 5.0,
                    curv_horiz: 4.0,
                    curv_strength: 0.25,
                    light_boost: 1.3,
                    vign_strength: 0.05,
                    zoom_out: 1.1,
                    brightness: 1.0
                )

                encoder.setFragmentBytes(&cbData, length: MemoryLayout<SimpleCrtUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
                ILOG("Effect filter pipeline state: \(self.effectFilterPipeline != nil)")
            } else if self.effectFilterShader?.name == "Line Tron" {
                let time = Float(CACurrentMediaTime())
                let sourceSize = SIMD4<Float>(
                    Float(inputTexture!.width),
                    Float(inputTexture!.height),
                    1.0 / Float(inputTexture!.width),
                    1.0 / Float(inputTexture!.height)
                )
                let outputSize = SIMD4<Float>(
                    Float(view.drawableSize.width),
                    Float(view.drawableSize.height),
                    1.0 / Float(view.drawableSize.width),
                    1.0 / Float(view.drawableSize.height)
                )

                var uniforms = LineTronUniforms(
                    SourceSize: sourceSize,
                    OutputSize: outputSize,
                    width_scale: 1.0,    /// Line width multiplier
                    line_time: time,     /// Current time in seconds
                    falloff: 2.0,        /// Line edge falloff
                    strength: 1.0        /// Line brightness
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LineTronUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline

            } else if self.effectFilterShader?.name == "Mega Tron" {
                let sourceSize = SIMD4<Float>(
                    Float(inputTexture!.width),
                    Float(inputTexture!.height),
                    1.0 / Float(inputTexture!.width),
                    1.0 / Float(inputTexture!.height)
                )
                let outputSize = SIMD4<Float>(
                    Float(view.drawableSize.width),
                    Float(view.drawableSize.height),
                    1.0 / Float(view.drawableSize.width),
                    1.0 / Float(view.drawableSize.height)
                )

                var uniforms = MegaTronUniforms(
                    SourceSize: sourceSize,
                    OutputSize: outputSize,
                    MASK: 3.0,              /// 0=none, 1=RGB, 2=RGB(2), 3=RGB(3)
                    MASK_INTENSITY: 0.25,    /// Mask intensity (0.0-1.0)
                    SCANLINE_THINNESS: 0.5, /// Scanline thickness
                    SCAN_BLUR: 2.5,         /// Scanline blur
                    CURVATURE: 0.02,        /// Screen curvature
                    TRINITRON_CURVE: 1.0,   /// 0=normal curve, 1=trinitron style
                    CORNER: 0.02,           /// Corner size
                    CRT_GAMMA: 2.4          /// CRT gamma correction
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MegaTronUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline

            } else if self.effectFilterShader?.name == "ulTron" {
                let sourceSize = SIMD4<Float>(
                    Float(inputTexture!.width),
                    Float(inputTexture!.height),
                    1.0 / Float(inputTexture!.width),
                    1.0 / Float(inputTexture!.height)
                )
                let outputSize = SIMD4<Float>(
                    Float(view.drawableSize.width),
                    Float(view.drawableSize.height),
                    1.0 / Float(view.drawableSize.width),
                    1.0 / Float(view.drawableSize.height)
                )

                var uniforms = UlTronUniforms(
                    SourceSize: sourceSize,
                    OutputSize: outputSize,
                    hardScan: -8.0,        /// Scanline intensity
                    hardPix: -3.0,         /// Pixel sharpness
                    warpX: 0.031,          /// Horizontal curvature
                    warpY: 0.041,          /// Vertical curvature
                    maskDark: 0.5,         /// Dark color mask
                    maskLight: 1.5,        /// Light color mask
                    shadowMask: 3,         /// Mask type (0-4)
                    brightBoost: 1.0,      /// Brightness boost
                    hardBloomScan: -2.0,   /// Bloom scanline
                    hardBloomPix: -1.5,    /// Bloom pixel
                    bloomAmount: 0.15,     /// Bloom strength
                    shape: 2.0            /// Curvature shape
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<UlTronUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
            } else if self.effectFilterShader?.name == "Game Boy" {
                let sourceSize = SIMD4<Float>(
                    Float(inputTexture!.width),
                    Float(inputTexture!.height),
                    1.0 / Float(inputTexture!.width),
                    1.0 / Float(inputTexture!.height)
                )
                let outputSize = SIMD4<Float>(
                    Float(view.drawableSize.width),
                    Float(view.drawableSize.height),
                    1.0 / Float(view.drawableSize.width),
                    1.0 / Float(view.drawableSize.height)
                )

                // Classic Game Boy green palette
                let darkestGreen = SIMD4<Float>(0.0588, 0.2196, 0.0588, 1.0)  // #0F380F
                let darkGreen = SIMD4<Float>(0.1882, 0.3882, 0.1882, 1.0)     // #306230
                let lightGreen = SIMD4<Float>(0.5451, 0.6745, 0.0588, 1.0)    // #8BAC0F
                let lightestGreen = SIMD4<Float>(0.6078, 0.7373, 0.0588, 1.0) // #9BBC0F

                var uniforms = GameBoyUniforms(
                    SourceSize: sourceSize,
                    OutputSize: outputSize,
                    dotMatrix: 0.7,        /// Dot matrix effect intensity (0.0-1.0)
                    contrast: 1.2,         /// Contrast adjustment
                    palette: (darkestGreen, darkGreen, lightGreen, lightestGreen)
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GameBoyUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
            } else if self.effectFilterShader?.name == "VHS" {
                let sourceSize = SIMD4<Float>(
                    Float(inputTexture!.width),
                    Float(inputTexture!.height),
                    1.0 / Float(inputTexture!.width),
                    1.0 / Float(inputTexture!.height)
                )
                let outputSize = SIMD4<Float>(
                    Float(view.drawableSize.width),
                    Float(view.drawableSize.height),
                    1.0 / Float(view.drawableSize.width),
                    1.0 / Float(view.drawableSize.height)
                )

                var uniforms = VHSUniforms(
                    SourceSize: sourceSize,
                    OutputSize: outputSize,
                    time: Float(CACurrentMediaTime()),  /// Current time for animated effects
                    noiseAmount: 0.05,                 /// Static noise intensity
                    scanlineJitter: 0.003,             /// Horizontal line displacement
                    colorBleed: 0.5,                   /// Vertical color bleeding
                    trackingNoise: 0.1,                /// Vertical noise bands
                    tapeWobble: 0.001,                /// Horizontal wobble amount
                    ghosting: 0.1,                     /// Double-image effect
                    vignette: 0.2                      /// Screen edge darkening
                )

                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VHSUniforms>.stride, index: 0)
                pipelineState = self.effectFilterPipeline
            }
        } else {
            //            DLOG("Using blit pipeline")
            pipelineState = self.blitPipeline
            //            DLOG("Blit pipeline state: \(self.blitPipeline != nil)")
        }

        if let pipelineState = pipelineState {
            // DLOG("Drawing with pipeline state")
            encoder.setRenderPipelineState(pipelineState)

            encoder.setFragmentTexture(self.inputTexture, index: 0)
            encoder.setFragmentSamplerState(self.renderSettings.smoothingEnabled ? self.linearSampler : self.pointSampler, index: 0)

            //            VLOG("Drawing primitives with pipeline state: \(pipelineState)")
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()

            commandBuffer.present(view.currentDrawable!)
            commandBuffer.commit()
        } else {
            ELOG("No valid pipeline state selected. Skipping draw call.")
            encoder.endEncoding()
            commandBuffer.commit()
        }

        if emulatorCore.rendersToOpenGL {
            emulatorCore.frontBufferLock.unlock()
        }
    }

    // MARK: - PVRenderDelegate
    func startRenderingOnAlternateThread() {
        emulatorCore?.glesVersion = glesVersion

#if !(targetEnvironment(macCatalyst) || os(macOS))
        guard let glContext = self.glContext else {
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

#if targetEnvironment(macCatalyst) || os(macOS)
            // TODO: This?
#warning("macOS incomplete")
#else
            EAGLContext.current()?.texImageIOSurface(backingIOSurface!,
                                                     target: UInt(GLenum(GL_TEXTURE_2D)),
                                                     internalFormat: UInt(GLenum(GL_RGBA)),
                                                     width: UInt32(GLsizei(width)),
                                                     height: UInt32(GLsizei(height)),
                                                     format: UInt(GLenum(GL_RGBA)),
                                                     type: UInt(GLenum(GL_UNSIGNED_BYTE)),
                                                     plane: 0)
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
        
        defer {
            emulatorCore?.frontBufferLock.unlock()

            emulatorCore?.frontBufferCondition.lock()
            emulatorCore?.isFrontBufferReady = true
            emulatorCore?.frontBufferCondition.signal()
            emulatorCore?.frontBufferCondition.unlock()
        }

        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            ELOG("commandBuffer was nil")
            return
        }

        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            ELOG("encoder was nil")
            return
        }

        if let backingMTLTexture = backingMTLTexture {
            let screenRect = emulatorCore?.screenRect ?? .zero

            encoder.copy(from: backingMTLTexture,
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

        } else {
            ELOG("backingMTLTexture was nil")
            return
        }
    }

    /// Cached viewport values
    private var cachedViewportWidth: CGFloat = 0
    private var cachedViewportHeight: CGFloat = 0
    private var cachedViewportX: CGFloat = 0
    private var cachedViewportY: CGFloat = 0
    private var lastBufferSize: CGSize = .zero
    private var lastScreenBounds: CGRect = .zero
    private var lastNativeScaleEnabled: Bool = false

    private func calculateViewportIfNeeded() {
        guard let emulatorCore = emulatorCore else { return }

#if os(iOS) || os(tvOS)
        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale
        let useNativeScale = Defaults[.nativeScaleEnabled]
#else
        let screenBounds = view.bounds
        let screenScale = view.window?.screen?.backingScaleFactor ?? 1.0
        let useNativeScale = true
#endif

        // Check if we need to recalculate
        let bufferSize = emulatorCore.bufferSize
        if bufferSize == lastBufferSize &&
            screenBounds == lastScreenBounds &&
            useNativeScale == lastNativeScaleEnabled {
            return
        }

        // Cache the current values
        lastBufferSize = bufferSize
        lastScreenBounds = screenBounds
        lastNativeScaleEnabled = useNativeScale

#if DEBUG
        ILOG("Recalculating viewport values:")
        ILOG("EmulatorCore sizes:")
        ILOG("- bufferSize: \(bufferSize)")
        ILOG("Screen bounds: \(screenBounds)")
        ILOG("Screen scale: \(screenScale)")
        ILOG("Native scale enabled: \(useNativeScale)")
#endif

        /// Calculate viewport size based on native scale setting
        if useNativeScale {
            cachedViewportWidth = CGFloat(bufferSize.width) * screenScale
            cachedViewportHeight = CGFloat(bufferSize.height) * screenScale
        } else {
            cachedViewportWidth = CGFloat(bufferSize.width)
            cachedViewportHeight = CGFloat(bufferSize.height)
        }

        /// Calculate center position based on native scale setting
        let scaleFactor = useNativeScale ? screenScale : 1.0
        cachedViewportX = ((screenBounds.width * scaleFactor) - cachedViewportWidth) / scaleFactor
        cachedViewportY = ((screenBounds.height * scaleFactor) - cachedViewportHeight) / scaleFactor

#if DEBUG
        ILOG("Cached viewport values:")
        ILOG("Size: \(cachedViewportWidth)x\(cachedViewportHeight)")
        ILOG("Position: \(cachedViewportX),\(cachedViewportY)")
#endif
    }

    override var isPaused: Bool {
        didSet {
            guard oldValue != isPaused else { return }

#if !os(visionOS)
            mtlView?.isPaused = isPaused
#endif

            if isPaused {
                // Ensure we finish any pending renders
                previousCommandBuffer?.waitUntilCompleted()
            } else {
                // Force a new frame when unpausing
                frameCount = 0
                draw(in: mtlView)
            }
        }
    }

    // Add this helper function to calculate aligned bytes per row
    private func alignedBytesPerRow(_ width: Int, bytesPerPixel: Int) -> Int {
        let bytesPerRow = width * bytesPerPixel
        // Align to 256 bytes for optimal Metal performance
        let alignment = 256
        let remainder = bytesPerRow % alignment
        return remainder == 0 ? bytesPerRow : bytesPerRow + (alignment - remainder)
    }
}
