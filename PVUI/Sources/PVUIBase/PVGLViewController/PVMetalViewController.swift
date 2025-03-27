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

// MARK: - GLenum Extensions
extension GLenum {
    /// Convert GLenum to String
    var toString: String {
        switch self {
        case GLenum(GL_UNSIGNED_BYTE): return "GL_UNSIGNED_BYTE"
        case GLenum(GL_BGRA): return "GL_BGRA"
        case GLenum(GL_RGBA): return "GL_RGBA"
        case GLenum(GL_RGB): return "GL_RGB"
        case GLenum(GL_RGB8): return "GL_RGB8"
        case GLenum(GL_RGB565): return "GL_RGB565"
        case GLenum(GL_RGB5_A1): return "GL_RGB5_A1"
        case GLenum(GL_RGB10_A2): return "GL_RGB10_A2"
        case GLenum(GL_RGB10_A2UI): return "GL_RGB10_A2UI"
            // Add more cases as needed
        default: return String(format: "0x%04X", self)
        }
    }
}

// MARK: - EffectFilterShaderError
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

// MARK: - PVMetalViewController
final
class PVMetalViewController : PVGPUViewController, PVRenderDelegate, MTKViewDelegate {
    func setPreferredRefreshRate(_ rate: Float) {
        ILOG("Setting preferred refresh rate to \(rate) Hz")

//        #if os(iOS) || os(tvOS)
//        if #available(iOS 15.0, tvOS 15.0, *) {
//            if let window = view.window {
//                let preferredFrameRateRange: CAFrameRateRange
//
//                if rate > 0 {
//                    // Create a range with the specified rate as the preferred rate
//                    preferredFrameRateRange = CAFrameRateRange(minimum: max(30, rate/2),
//                                                              maximum: rate * 1.1,
//                                                              preferred: rate)
//                } else {
//                    // Default to device capabilities if rate is 0 or negative
//                    preferredFrameRateRange = CAFrameRateRange(minimum: 30,
//                                                              maximum: 120,
//                                                              preferred: 60)
//                }
//
//                window.windowScene?.screen.maximumFramesPerSecond = Int(rate)
//
//                // Apply the frame rate range to the display
//                CATransaction.begin()
//                window.windowScene?.screen.preferredFrameRateRange = preferredFrameRateRange
//                CATransaction.commit()
//
//                ILOG("Set display refresh rate range: \(preferredFrameRateRange.minimum)-\(preferredFrameRateRange.maximum) Hz (preferred: \(preferredFrameRateRange.preferred) Hz)")
//            } else {
//                WLOG("Cannot set refresh rate - window is nil")
//            }
//        } else {
//            WLOG("Setting refresh rate not supported on this iOS/tvOS version")
//        }
//        #else
//        WLOG("Setting refresh rate not supported on this platform")
//        #endif

        // Also update the MTKView's preferred FPS
        if let mtlView = self.mtlView {
            let fps = rate > 0 ? Int(rate) : 60
            mtlView.preferredFramesPerSecond = fps
            ILOG("Set MTKView preferred FPS to \(fps)")
        }
    }

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

    // Add these properties to the class
    private var commandBufferPool: [MTLCommandBuffer] = []
    private var commandBufferPoolLock = NSLock()
    private var renderPassDescriptor: MTLRenderPassDescriptor?
    private var lastBufferSize: CGSize = .zero
    private var lastPixelFormat: GLenum = 0
    private var lastPixelType: GLenum = 0
    private var lastScreenBounds: CGRect = .zero
    private var lastNativeScaleEnabled: Bool = false

    // Add this property to the class
    private var customPipeline: MTLRenderPipelineState?

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
        renderSettings.nativeScaleEnabled = Defaults[.nativeScaleEnabled]

        Task {
            for await value in Defaults.updates([.metalFilterMode, .openGLFilterMode, .imageSmoothing]) {
                renderSettings.metalFilterMode = Defaults[.metalFilterMode]
                renderSettings.openGLFilterMode = Defaults[.openGLFilterMode]
                renderSettings.smoothingEnabled = Defaults[.imageSmoothing]
                renderSettings.nativeScaleEnabled = Defaults[.nativeScaleEnabled]
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

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Invalidate cached values to force recalculation of the viewport on rotation.
        lastScreenBounds = .zero
        lastBufferSize = .zero
        lastNativeScaleEnabled = false

        coordinator.animate(alongsideTransition: { _ in
            self.view.setNeedsLayout()
        })
    }

    override func loadView() {
        /// Create MTKView with initial frame from screen bounds
        let screenBounds = UIScreen.main.bounds
        let metalView = MTKView(frame: screenBounds, device: device)
        metalView.autoresizingMask = [] // Disable autoresizing
        self.view = metalView
        self.mtlView = metalView

#if DEBUG
        DLOG("Initial MTKView frame: \(metalView.frame)")
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

        if Defaults[.nativeScaleEnabled]  || renderSettings.nativeScaleEnabled {
            let scale = UIScreen.main.scale
            if scale != 1 {
                view.layer.contentsScale = scale
                view.layer.rasterizationScale = scale
                view.contentScaleFactor = scale
            }
        }

        do {
            try setupTexture()
        } catch {
            ELOG("Setup texture shader creation error: \(error.localizedDescription)")
        }

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
                WLOG("No filter shader selected for mode: \(renderSettings.metalFilterMode)")
            }
        }

        alternateThreadFramebufferBack = 0
        alternateThreadColorTextureBack = 0
        alternateThreadDepthRenderbuffer = 0

        // Add notification observer for emulator core initialization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(emulatorCoreDidInitialize),
            name: Notification.Name("EmulatorCoreDidInitialize"),
            object: nil
        )

        // Set up the custom shader
        do {
            try setupCustomShader()
        } catch {
            ELOG("Custom shader setup error: \(error)")
        }

        // Add notification observer for emulator core initialization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshTexture),
            name: Notification.Name("RefreshGPUView"),
            object: nil
        )

        // Add a colored border to the MTKView for debugging
        mtlView.layer.borderWidth = 5.0
        mtlView.layer.borderColor = UIColor.cyan.cgColor
    }

    @objc private func emulatorCoreDidInitialize() {
        print("Emulator core did initialize, updating texture...")

        // Update the texture now that the emulator core has initialized
        DispatchQueue.main.async {
            do {
                try self.updateInputTexture()

                // Force a redraw
                self.draw(in: self.mtlView)
            } catch {
                print("Error updating texture after emulator core initialization: \(error)")
            }
        }
    }

    @objc private func refreshTexture() {
        // Update the texture
        do {
            try updateInputTexture()

            // Force a redraw
            draw(in: mtlView)
        } catch {
            print("Error updating texture: \(error)")

            // Try to create a default texture
            do {
                try createDefaultTexture()

                // Force a redraw
                draw(in: mtlView)
            } catch {
                print("Error creating default texture: \(error)")
            }
        }
    }

    private func createDefaultTexture() throws {
        guard let device = device else {
            throw MetalViewControllerError.deviceIsNil
        }

        // Use a default size
        let defaultWidth: Int = 256
        let defaultHeight: Int = 240

        // Create a texture descriptor with the default size
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: defaultWidth,
            height: defaultHeight,
            mipmapped: false
        )

        textureDescriptor.usage = [.shaderRead, .renderTarget]

        // Create the texture
        inputTexture = device.makeTexture(descriptor: textureDescriptor)

        if inputTexture == nil {
            throw MetalViewControllerError.failedToCreateTexture("default texture")
        }

        // Fill the texture with a solid color
        if let texture = inputTexture {
            let region = MTLRegionMake2D(0, 0, defaultWidth, defaultHeight)
            let bytesPerRow = 4 * defaultWidth
            let totalBytes = bytesPerRow * defaultHeight

            // Create a buffer with a solid color (black with alpha)
            var buffer = [UInt8](repeating: 0, count: totalBytes)
            for i in stride(from: 0, to: totalBytes, by: 4) {
                buffer[i] = 0     // R
                buffer[i+1] = 0   // G
                buffer[i+2] = 0   // B
                buffer[i+3] = 255 // A
            }

            // Replace the texture contents
            texture.replace(region: region, mipmapLevel: 0, withBytes: buffer, bytesPerRow: bytesPerRow)
        }
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

            if renderSettings.nativeScaleEnabled {
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

    func updateInputTexture() throws {
        guard let emulatorCore = emulatorCore else {
            throw MetalViewControllerError.emulatorCoreIsNil
        }

        guard let device = device else {
            throw MetalViewControllerError.deviceIsNil
        }

        // Only update if necessary
        if !isTextureUpdateNeeded() {
            return
        }

        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Check if buffer size is valid
        if bufferSize.width <= 0 || bufferSize.height <= 0 {
            print("Warning: Invalid buffer size: \(bufferSize.width) x \(bufferSize.height)")

            // Use a default size if the buffer size is invalid
            let defaultWidth: Int = 256
            let defaultHeight: Int = 240

            // Create a texture descriptor with the default size
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: defaultWidth,
                height: defaultHeight,
                mipmapped: false
            )

            textureDescriptor.usage = [.shaderRead, .renderTarget]

            // Create the texture
            inputTexture = device.makeTexture(descriptor: textureDescriptor)

            return
        }

        #if targetEnvironment(simulator)
        let mtlPixelFormat: MTLPixelFormat = .astc_6x5_srgb
        #else
        let mtlPixelFormat: MTLPixelFormat = emulatorCore.rendersToOpenGL ? .rgba8Unorm : getMTLPixelFormat(from: emulatorCore.pixelFormat, type: emulatorCore.pixelType)
        #endif

        if emulatorCore.rendersToOpenGL {
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

                inputTexture = device.makeTexture(descriptor: desc)

                if inputTexture == nil {
                    throw MetalViewControllerError.failedToCreateTexture("input texture")
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
                } else if emulatorCore.pixelFormat == GLenum(GL_BGRA) {
                    textureDescriptor.pixelFormat = .bgra8Unorm
                } else {
                    textureDescriptor.pixelFormat = .rgba8Unorm
                }

                textureDescriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
                textureDescriptor.storageMode = .private

                inputTexture = device.makeTexture(descriptor: textureDescriptor)

                if inputTexture == nil {
                    throw MetalViewControllerError.failedToCreateTexture("input texture")
                }
            }
        }
    }

    // TODO: Make throw
    func setupTexture() throws {
        guard let emulatorCore = emulatorCore else {
            throw MetalViewControllerError.emulatorCoreIsNil
        }

        guard let device = device else {
            throw MetalViewControllerError.deviceIsNil
        }

        try updateInputTexture()

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
                throw MetalViewControllerError.invalidBufferSize(width: width, height: height)
            }
        }

        // Create point sampler
        let pointDesc = MTLSamplerDescriptor()
        pointDesc.minFilter = .nearest
        pointDesc.magFilter = .nearest
        pointDesc.mipFilter = .nearest
        pointDesc.sAddressMode = .clampToZero
        pointDesc.tAddressMode = .clampToZero
        pointDesc.rAddressMode = .clampToZero
        pointDesc.label = "Point Sampler"

        pointSampler = device.makeSamplerState(descriptor: pointDesc)

        if pointSampler == nil {
            throw MetalViewControllerError.failedToCreateSamplerState("point sampler")
        }

        print("Created point sampler: \(String(describing: pointSampler))")

        // Create linear sampler
        let linearDesc = MTLSamplerDescriptor()
        linearDesc.minFilter = .linear
        linearDesc.magFilter = .linear
        linearDesc.mipFilter = .linear
        linearDesc.sAddressMode = .clampToZero
        linearDesc.tAddressMode = .clampToZero
        linearDesc.rAddressMode = .clampToZero
        linearDesc.label = "Linear Sampler"

        linearSampler = device.makeSamplerState(descriptor: linearDesc)

        if linearSampler == nil {
            throw MetalViewControllerError.failedToCreateSamplerState("linear sampler")
        }

        print("Created linear sampler: \(String(describing: linearSampler))")
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

    func setupBlitShader() throws {
        guard let device = device else {
            throw EffectFilterShaderError.deviceIsNIl
        }

        // Create a default library
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        // Get the vertex and fragment functions
        guard let vertexFunction = defaultLibrary.makeFunction(name: "blit_vs") else {
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        print("Found vertex function: blit_vs")

        guard let fragmentFunction = defaultLibrary.makeFunction(name: "blit_ps") else {
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        print("Found fragment function: blit_ps")

        // Create a render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Print the pipeline descriptor for debugging
        print("Pipeline descriptor: \(pipelineDescriptor)")

        // Create the render pipeline state
        do {
            blitPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("Successfully created blit pipeline state")
        } catch {
            print("Failed to create blit pipeline state: \(error)")
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
        DLOG("FlipY value: \(flipY)")

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
        guard let emulatorCore = emulatorCore, !isPaused else {
            return
        }

        // Check if the texture needs to be created or updated
        if inputTexture == nil {
            do {
                try updateInputTexture()
            } catch {
                print("Error creating texture in draw: \(error)")

                // Schedule a retry after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.draw(in: view)
                }

                return
            }
        }

        if emulatorCore.skipEmulationLoop {
            return
        }

        // Always update the texture from the core's buffer
        _ = updateTextureFromCore()

        // Use the direct rendering method which is safer
        directRender(in: view)
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

        // Fix #1 & #2: Reuse command buffers efficiently
        let commandBuffer: MTLCommandBuffer
        if let queue = self.commandQueue {
            commandBuffer = queue.makeCommandBuffer()!
            self.previousCommandBuffer = commandBuffer
        } else {
            print("Error: Command queue is nil")
            return
        }

        // Create a render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        // Create a render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Error: Could not create render encoder")
            return
        }

        // Set the viewport
        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(outputTexture.width),
            height: Double(outputTexture.height),
            znear: 0.0,
            zfar: 1.0
        )
        renderEncoder.setViewport(viewport)

        // Choose the appropriate pipeline state
        let pipelineState: MTLRenderPipelineState
        let useEffectFilter = effectFilterPipeline != nil && renderSettings.metalFilterMode != .none

        if useEffectFilter {
            guard let effectFilterPipeline = effectFilterPipeline else {
                print("Error: Effect filter pipeline is nil")
                renderEncoder.endEncoding()
                return
            }
            pipelineState = effectFilterPipeline
            print("Using effect filter pipeline")
        } else {
            guard let blitPipeline = blitPipeline else {
                print("Error: Blit pipeline is nil")
                renderEncoder.endEncoding()
                return
            }
            pipelineState = blitPipeline
            print("Using blit pipeline")
        }

        print("Blit pipeline state: \(blitPipeline != nil)")

        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        print("🔬 Drawing primitives with pipeline state: \(pipelineState)")

        // Set the vertex buffer
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 0.0, 1.0,
             1.0, -1.0, 0.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0, 0.0,
             1.0,  1.0, 0.0, 1.0, 0.0
        ]

        let vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: .storageModeShared)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Set the texture
        guard let inputTexture = inputTexture else {
            print("Error: Input texture is nil")
            renderEncoder.endEncoding()
            return
        }

        renderEncoder.setFragmentTexture(inputTexture, index: 0)

        // Set the sampler state - THIS IS THE KEY FIX
        if let pointSampler = pointSampler {
            renderEncoder.setFragmentSamplerState(pointSampler, index: 0)
            print("Set point sampler at index 0")
        } else if let linearSampler = linearSampler {
            renderEncoder.setFragmentSamplerState(linearSampler, index: 0)
            print("Set linear sampler at index 0")
        } else {
            print("Error: No sampler state available")
            renderEncoder.endEncoding()
            return
        }

        // Draw the primitives
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        // End encoding
        renderEncoder.endEncoding()

        // Present the drawable
        commandBuffer.present(view.currentDrawable!)

        // Commit the command buffer
        commandBuffer.commit()

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
        guard backingMTLTexture != nil else {
            ELOG("backingMTLTexture was nil")
            return
        }
        glFlush()

        emulatorCore?.frontBufferLock.lock()

        previousCommandBuffer?.waitUntilScheduled()

        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            ELOG("commandBuffer was nil")
            return
        }

        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            ELOG("encoder was nil")
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

    /// Cached viewport values
    private var cachedViewportWidth: CGFloat = 0
    private var cachedViewportHeight: CGFloat = 0
    private var cachedViewportX: CGFloat = 0
    private var cachedViewportY: CGFloat = 0

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

    // Add this helper method to check if texture update is needed
    private func isTextureUpdateNeeded() -> Bool {
        guard let emulatorCore = emulatorCore else {
            print("isTextureUpdateNeeded: emulatorCore is nil")
            return false
        }

        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        print("isTextureUpdateNeeded: screenRect=\(screenRect), bufferSize=\(bufferSize)")

        let currentScreenBounds = CGRect(x: screenRect.origin.x,
                                        y: screenRect.origin.y,
                                        width: screenRect.width,
                                        height: screenRect.height)
        let currentNativeScaleEnabled = renderSettings.nativeScaleEnabled

        // Check if screen bounds or native scale setting has changed
        if currentScreenBounds != lastScreenBounds ||
           currentNativeScaleEnabled != lastNativeScaleEnabled {
            print("isTextureUpdateNeeded: screen bounds or native scale changed")
            lastScreenBounds = currentScreenBounds
            lastNativeScaleEnabled = currentNativeScaleEnabled
            return true
        }

        if inputTexture == nil {
            print("isTextureUpdateNeeded: inputTexture is nil")
            return true
        }

        if inputTexture?.width != Int(screenRect.width) ||
           inputTexture?.height != Int(screenRect.height) {
            print("isTextureUpdateNeeded: texture size doesn't match screen size")
            return true
        }

        #if targetEnvironment(simulator)
        let mtlPixelFormat: MTLPixelFormat = .astc_6x5_srgb
        #else
        let mtlPixelFormat: MTLPixelFormat = emulatorCore.rendersToOpenGL ? .rgba8Unorm : getMTLPixelFormat(from: emulatorCore.pixelFormat, type: emulatorCore.pixelType)
        #endif

        if inputTexture?.pixelFormat != mtlPixelFormat {
            print("isTextureUpdateNeeded: pixel format changed")
            return true
        }

        print("isTextureUpdateNeeded: no update needed")
        return false
    }

    // Add this method to the PVMetalViewController class
    private func fallbackRender(_ emulatorCore: PVEmulatorCore, in view: MTKView) {
        print("Using fallback rendering method")

        guard let device = device,
              let commandQueue = commandQueue,
              let drawable = view.currentDrawable,
              let inputTexture = inputTexture else {
            print("Missing required resources for fallback rendering")
            return
        }

        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer")
            return
        }

        // Create a blit command encoder
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            print("Failed to create blit encoder")
            return
        }

        // Copy the input texture to the drawable texture
        blitEncoder.copy(
            from: inputTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(
                width: inputTexture.width,
                height: inputTexture.height,
                depth: 1
            ),
            to: drawable.texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        // End encoding
        blitEncoder.endEncoding()

        // Present the drawable
        commandBuffer.present(drawable)

        // Commit the command buffer
        commandBuffer.commit()

        print("Fallback rendering completed")
    }

    // Add this method to create a custom shader that doesn't require a sampler
    private func setupCustomShader() throws {
        guard let device = device else {
            throw EffectFilterShaderError.deviceIsNIl
        }

        // Create a simple vertex shader
        let vertexShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float4 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
        };

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
            const float4 positions[4] = {
                float4(-1.0, -1.0, 0.0, 1.0),
                float4( 1.0, -1.0, 0.0, 1.0),
                float4(-1.0,  1.0, 0.0, 1.0),
                float4( 1.0,  1.0, 0.0, 1.0)
            };

            const float2 texCoords[4] = {
                float2(0.0, 1.0),
                float2(1.0, 1.0),
                float2(0.0, 0.0),
                float2(1.0, 0.0)
            };

            VertexOut out;
            out.position = positions[vertexID];
            out.texCoord = texCoords[vertexID];
            return out;
        }
        """

        // Create a simple fragment shader that doesn't use a sampler
        let fragmentShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                     texture2d<float> texture [[texture(0)]]) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            return texture.sample(textureSampler, in.texCoord);
        }
        """

        // Create a Metal library from the shader source
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: vertexShaderSource + fragmentShaderSource, options: nil)
        } catch {
            print("Error creating Metal library: \(error)")
            throw error
        }

        // Get the vertex and fragment functions
        guard let vertexFunction = library.makeFunction(name: "vertex_main") else {
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        guard let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        // Create a render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Create the render pipeline state
        do {
            customPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("Successfully created custom pipeline state")
        } catch {
            print("Failed to create custom pipeline state: \(error)")
            throw error
        }
    }

    private func directRender(in view: MTKView) {
        guard let emulatorCore = emulatorCore,
              let device = device,
              let commandQueue = commandQueue,
              let drawable = view.currentDrawable,
              let inputTexture = inputTexture else {
            print("Missing required resources for direct rendering")
            return
        }

        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer")
            return
        }

        // Create a render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        // Create a render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Failed to create render encoder")
            return
        }

        // Set the viewport
        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(drawable.texture.width),
            height: Double(drawable.texture.height),
            znear: 0.0,
            zfar: 1.0
        )
        renderEncoder.setViewport(viewport)

        // Use the custom pipeline if available, otherwise fall back to the blit pipeline
        if let customPipeline = customPipeline {
            renderEncoder.setRenderPipelineState(customPipeline)

            // Set the texture
            renderEncoder.setFragmentTexture(inputTexture, index: 0)

            // Draw the primitives
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        } else if let blitPipeline = blitPipeline {
            // Fall back to the blit pipeline
            renderEncoder.setRenderPipelineState(blitPipeline)

            // Set the texture
            renderEncoder.setFragmentTexture(inputTexture, index: 0)

            // Set the sampler state
            if let pointSampler = pointSampler {
                renderEncoder.setFragmentSamplerState(pointSampler, index: 0)
            }

            // Draw the primitives
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        } else {
            print("No pipeline available")
        }

        // End encoding
        renderEncoder.endEncoding()

        // Present the drawable
        commandBuffer.present(drawable)

        // Commit the command buffer
        commandBuffer.commit()
    }

    // Helper method to update texture from core's buffer
    private func updateTextureFromCore() -> Bool {
        guard let emulatorCore = emulatorCore,
              let device = device,
              let inputTexture = inputTexture else {
            return false
        }

        // Get the video buffer from the core
        guard let videoBuffer = emulatorCore.videoBuffer else {
            return false
        }

        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Calculate buffer size
        let bytesPerPixel = getByteWidth(for: Int32(emulatorCore.pixelFormat), type: Int32(emulatorCore.pixelType))
        let bytesPerRow = Int(bufferSize.width) * Int(bytesPerPixel)
        let totalBytes = bytesPerRow * Int(bufferSize.height)

        // Create a temporary buffer if needed
        let tempBuffer: MTLBuffer
        if let uploadBuffer = uploadBuffer, uploadBuffer.length >= totalBytes {
            tempBuffer = uploadBuffer
        } else {
            guard let newBuffer = device.makeBuffer(length: totalBytes, options: .storageModeShared) else {
                return false
            }
            tempBuffer = newBuffer
        }

        // Copy the video buffer to the upload buffer
        let uploadContents = tempBuffer.contents()
        memcpy(uploadContents, videoBuffer, totalBytes)

        // Create a command buffer
        guard let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return false
        }

        // Create a blit command encoder
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return false
        }

        // Copy from the upload buffer to the texture
        blitEncoder.copy(
            from: tempBuffer,
            sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: totalBytes,
            sourceSize: MTLSizeMake(Int(bufferSize.width), Int(bufferSize.height), 1),
            to: inputTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOriginMake(0, 0, 0)
        )

        blitEncoder.endEncoding()
        commandBuffer.commit()

        return true
    }
}

/// Error types for Metal view controller operations
enum MetalViewControllerError: Error {
    case emulatorCoreIsNil
    case deviceIsNil
    case invalidBufferSize(width: CGFloat, height: CGFloat)
    case failedToCreateTexture(String)
    case failedToCreateSamplerState(String)
    case failedToCreateCommandQueue
    case failedToCreateRenderPipelineState(Error)
}

extension MetalViewControllerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emulatorCoreIsNil:
            return "Emulator core is nil"
        case .deviceIsNil:
            return "Metal device is nil"
        case .invalidBufferSize(let width, let height):
            return "Invalid buffer size: Should be non-zero. Is <\(width),\(height)>"
        case .failedToCreateTexture(let name):
            return "Failed to create \(name)"
        case .failedToCreateSamplerState(let name):
            return "Failed to create \(name)"
        case .failedToCreateCommandQueue:
            return "Failed to create command queue"
        case .failedToCreateRenderPipelineState(let error):
            return "Failed to create render pipeline state: \(error.localizedDescription)"
        }
    }
}
