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

    weak var emulatorCore: PVEmulatorCore?

    // Custom filter properties
    private var ciContext: CIContext? = nil

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

    /// Tracks the number of buffer allocations for performance monitoring
    private var bufferCreationCount: Int = 0

    // Add this property to the class
    private var customPipeline: MTLRenderPipelineState?

    /// Controls whether VSync is enabled (synchronizes rendering with display refresh rate)
    public var vsyncEnabled: Bool = true

    // Track recovery attempts to prevent infinite loops
    private var recoveryAttempts: Int = 0
    private let maxRecoveryAttempts: Int = 3
    private var lastRecoveryTime: TimeInterval = 0

    // Add a property to store shader constants
    private var shaderConstants = MTLFunctionConstantValues()

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

        DLOG("View will transition to size: \(size)")

        // Invalidate cached values to force recalculation of the viewport on rotation.
        lastScreenBounds = .zero
        lastBufferSize = .zero
        lastNativeScaleEnabled = false

        // Schedule a texture update after the rotation completes
        coordinator.animate(alongsideTransition: { _ in
            self.view.setNeedsLayout()
        }, completion: { _ in
            DLOG("Rotation completed")
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

        // Create a Metal device
        device = MTLCreateSystemDefaultDevice()

        // Load VSync setting from user defaults
        vsyncEnabled = Defaults[.vsyncEnabled]

        if device == nil {
            ELOG("Failed to create Metal device")
            // No recovery here since we're in initialization
            return
        }

        // Initialize OpenGL context if core renders to OpenGL
        if let emulatorCore = emulatorCore, emulatorCore.rendersToOpenGL {
            ILOG("Initializing OpenGL context for OpenGL core")
            initializeOpenGLContext()
        }

        // Create a command queue
        commandQueue = device?.makeCommandQueue()

        if commandQueue == nil {
            ELOG("Failed to create command queue")
            // No recovery here since we're in initialization
            return
        }

        // Initialize CIContext for filters
        if let device = device {
            ciContext = CIContext(mtlDevice: device)
            DLOG("Created CIContext for filters")
        }

        // Set up the Metal view
        mtlView.device = device
        mtlView.delegate = self
        mtlView.framebufferOnly = true
        mtlView.colorPixelFormat = .bgra8Unorm
        mtlView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Configure VSync settings
        updateVsyncSettings()

        // Try to set up shaders using different approaches
        createBasicShaders()

        // If that didn't work, try the default library approach
        if customPipeline == nil && blitPipeline == nil {
            createBasicShadersWithDefaultLibrary()
        }

        // Add notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(emulatorCoreDidInitialize),
            name: Notification.Name("EmulatorCoreDidInitialize"),
            object: nil
        )

        // Add a colored border to the MTKView for debugging
        //        mtlView.layer.borderWidth = 5.0
        //        mtlView.layer.borderColor = UIColor.cyan.cgColor

        DLOG("Metal view controller view did load")
    }

    @objc private func emulatorCoreDidInitialize() {
        DLOG("Emulator core did initialize, updating texture...")

        // Update the texture now that the emulator core has initialized
        DispatchQueue.main.async {
            do {
                try self.updateInputTexture()

                // Force a redraw
                self.draw(in: self.mtlView)
            } catch {
                ELOG("Error updating texture after emulator core initialization: \(error)")
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
            ELOG("Error updating texture: \(error)")

            // Try to create a default texture
            do {
                try createDefaultTexture()

                // Force a redraw
                draw(in: mtlView)
            } catch {
                ELOG("Error creating default texture: \(error)")
                // Attempt recovery
                recoverFromGPUError()
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

    /// Initialize OpenGL context for cores that render to OpenGL
    private func initializeOpenGLContext() {
        ILOG("Initializing OpenGL context")

        // Get the best available OpenGL context
        glContext = bestContext

        guard let glContext = glContext else {
            ELOG("Failed to create OpenGL context")
            return
        }

        // Configure multi-threading support if enabled in settings
        glContext.isMultiThreaded = Defaults[.multiThreadedGL]

        // Set the current context
        EAGLContext.setCurrent(glContext)

        ILOG("Successfully initialized OpenGL context with API version \(glContext.api.rawValue)")
    }
#endif

    func updatePreferredFPS() {
        let preferredFPS: Int = Int(emulatorCore?.frameInterval ?? 0)
        ILOG("updatePreferredFPS (\(preferredFPS))")

        if preferredFPS < 10 {
            WLOG("Cores frame interval (\(preferredFPS)) too low. Setting to 60")
            mtlView.preferredFramesPerSecond = 60
        } else {
            if vsyncEnabled {
                // With VSync enabled, we synchronize with the display's refresh rate
                // but still set the preferred FPS as a hint to the system
                mtlView.preferredFramesPerSecond = preferredFPS
            } else {
                // With VSync disabled, we try to run at the exact core rate
                // Note: This may not be fully honored by Metal on all platforms
                mtlView.preferredFramesPerSecond = preferredFPS
            }
        }

        ILOG("Set MTKView preferred FPS to \(mtlView.preferredFramesPerSecond) (VSync: \(vsyncEnabled))")
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

        DLOG("viewDidLayoutSubviews called")

        guard let emulatorCore = emulatorCore else {
            return
        }

#if DEBUG
        ILOG("Before layout - MTKView frame: \(mtlView.frame)")
#endif

        if emulatorCore.skipLayout {
            return
        }

        // IMPORTANT: If custom positioning is being used, respect it and don't override
        if useCustomPositioning && !customFrame.isEmpty {
            DLOG("Using custom positioning: \(customFrame)")
            mtlView.frame = customFrame
            view.frame = customFrame
            updatePreferredFPS()
            return
        }

        let parentSafeAreaInsets = parent?.view.safeAreaInsets ?? .zero

        // Get screen rect and buffer size
        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Check if screen rect is valid (has reasonable dimensions)
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10

        // Use effective dimensions when screen rect is invalid
        let effectiveRect = isScreenRectValid ? screenRect : CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)

        DLOG("""
             Layout calculations:
             Screen rect: \(screenRect)
             Buffer size: \(bufferSize)
             Is screen rect valid: \(isScreenRectValid)
             Using effective rect: \(effectiveRect)
            """)

        if !effectiveRect.isEmpty {
            // Use the effective dimensions for aspect ratio calculation
            let effectiveSize = CGSize(width: effectiveRect.width, height: effectiveRect.height)
            var ratio: CGFloat = 0
            if effectiveSize.width > effectiveSize.height {
                ratio = effectiveSize.width / effectiveSize.height
            } else {
                ratio = effectiveSize.height / effectiveSize.width
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
                    height = floor(parentSize.height / effectiveSize.height) * effectiveSize.height
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
                    width = floor(parentSize.width / effectiveSize.width) * effectiveSize.width
                } else {
                    width = parentSize.width
                }
                height = width / ratio
                if height > parentSize.height {
                    height = parentSize.height
                    width = height * ratio
                }
            }

            DLOG("Calculated dimensions: \(width)x\(height) with ratio: \(ratio)")

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
            ILOG("""
                View: \(type(of: view))
                Frame: \(view.frame)
                Bounds: \(view.bounds)
                Transform: \(view.transform)
                AutoresizingMask: \(view.autoresizingMask)
                Constraints: \(view.constraints)
                SuperView: \(String(describing: view.superview))
                ----------------
                """)
            currentView = view.superview
        }
    }
#endif

    func updateInputTexture() throws {
        guard let emulatorCore = emulatorCore else {
            throw MetalViewControllerError.emulatorCoreIsNil
        }

        // Get the screen rect and buffer size from the emulator core
        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Check if screen rect is valid (has reasonable dimensions)
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10

        // Use effective dimensions - if screen rect is invalid, use buffer size instead
        let effectiveWidth = isScreenRectValid ? screenRect.width : bufferSize.width
        let effectiveHeight = isScreenRectValid ? screenRect.height : bufferSize.height

        // Log the current buffer size and screen rect when updating the texture
        DLOG("""
             Updating input texture with:
             Buffer size: \(bufferSize)
             Screen rect: \(screenRect)
             Effective dimensions: \(effectiveWidth)x\(effectiveHeight)
             Screen rect valid: \(isScreenRectValid)
             Pixel format: \(GLenum(emulatorCore.pixelFormat).toString)
             Pixel type: \(GLenum(emulatorCore.pixelType).toString)
            """)

        guard let device = device else {
            throw MetalViewControllerError.deviceIsNil
        }

        // Only update if necessary
        if !isTextureUpdateNeeded() {
            return
        }

        // Check if effective dimensions are valid
        if effectiveWidth <= 0 || effectiveHeight <= 0 {
            DLOG("Warning: Invalid dimensions: \(effectiveWidth) x \(effectiveHeight)")
            throw MetalViewControllerError.invalidBufferSize(width: effectiveWidth, height: effectiveHeight)
        }

        // Determine the pixel format
#if targetEnvironment(simulator)
        let mtlPixelFormat: MTLPixelFormat = .rgba8Unorm
#else
        let mtlPixelFormat: MTLPixelFormat = emulatorCore.rendersToOpenGL ? .rgba8Unorm : getMTLPixelFormat(from: emulatorCore.pixelFormat, type: emulatorCore.pixelType)
#endif

        // Create a texture descriptor - always use the effective dimensions
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: mtlPixelFormat,
            width: Int(effectiveWidth),
            height: Int(effectiveHeight),
            mipmapped: false
        )

        // Set usage options
        textureDescriptor.usage = [.shaderRead, .renderTarget]

        // Create the texture
        inputTexture = device.makeTexture(descriptor: textureDescriptor)

        if inputTexture == nil {
            throw MetalViewControllerError.failedToCreateTexture("input texture")
        }

        // Create an upload buffer if needed - always use buffer size for this
        let bytesPerPixel = getByteWidth(for: Int32(emulatorCore.pixelFormat), type: Int32(emulatorCore.pixelType))
        let bytesPerRow = Int(bufferSize.width) * Int(bytesPerPixel)
        let totalBytes = bytesPerRow * Int(bufferSize.height)

        if uploadBuffer == nil || uploadBuffer!.length < totalBytes, totalBytes > 0 {
            uploadBuffer = device.makeBuffer(length: totalBytes, options: .storageModeShared)
            if uploadBuffer == nil {
                throw MetalViewControllerError.failedToCreateTexture("upload buffer")
            }
        }

        ILOG("Created input texture: \(effectiveWidth)x\(effectiveHeight), format: \(mtlPixelFormat)")
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

        DLOG("Created point sampler: \(String(describing: pointSampler))")

        // Create linear sampler
        let linearDesc = MTLSamplerDescriptor()
        linearDesc.minFilter = .linear
        linearDesc.magFilter = .linear
        linearDesc.mipFilter = .linear // .nearest
        linearDesc.sAddressMode = .clampToZero
        linearDesc.tAddressMode = .clampToZero
        linearDesc.rAddressMode = .clampToZero
        linearDesc.label = "Linear Sampler"

        linearSampler = device.makeSamplerState(descriptor: linearDesc)

        if linearSampler == nil {
            throw MetalViewControllerError.failedToCreateSamplerState("linear sampler")
        }

        DLOG("Created linear sampler: \(String(describing: linearSampler))")
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
        case (GLenum(GL_RGB5_A1), GLenum(GL_UNSIGNED_SHORT)): // VecX core uses RGB555 with 1-bit alpha
            return .a1bgr5Unorm
#if !targetEnvironment(macCatalyst) && !os(macOS)
        case (GLenum(GL_RGB565), _):
            return .b5g6r5Unorm
#else
        case (GLenum(GL_UNSIGNED_SHORT_5_6_5), _):
            return .b5g6r5Unorm
#endif
        case (GLenum(GL_UNSIGNED_SHORT_5_6_5), _): // Handle when pixel type is incorrectly passed as format
            WLOG("GL_UNSIGNED_SHORT_5_6_5 passed as pixelFormat instead of pixelType, using RGB565 format")
            return .b5g6r5Unorm
        case (GLenum(GL_UNSIGNED_SHORT_4_4_4_4), _): // Handle RGBA4444 pixel type as format
            WLOG("GL_UNSIGNED_SHORT_4_4_4_4 passed as pixelFormat instead of pixelType, using RGBA4444 format")
            return .abgr4Unorm
        case (GLenum(GL_UNSIGNED_SHORT_5_5_5_1), _): // Handle RGB5551 pixel type as format
            WLOG("GL_UNSIGNED_SHORT_5_5_5_1 passed as pixelFormat instead of pixelType, using RGB5551 format")
            return .a1bgr5Unorm
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
        DLOG("Error: Unknown GL pixelFormat. Add pixelFormat: \(pixelFormat) pixelType: \(pixelType)")
        assertionFailure("Unknown GL pixelFormat. Add pixelFormat: \(pixelFormat) pixelType: \(pixelType)")
        return .invalid
    }

    private func setupBlitShader() throws {
        guard let device = device else {
            throw MetalViewControllerError.deviceIsNil
        }

        // Create a simple vertex shader that accepts a flipY parameter
        let vertexShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut blit_vertex(uint vertexID [[vertex_id]], constant bool &flipY [[buffer(1)]]) {
            // Define positions for a fullscreen quad
            const float2 positions[4] = {
                float2(-1.0, -1.0),
                float2(1.0, -1.0),
                float2(-1.0, 1.0),
                float2(1.0, 1.0)
            };

            // Define standard texture coordinates
            float2 texCoords[4] = {
                float2(0.0, 0.0),
                float2(1.0, 0.0),
                float2(0.0, 1.0),
                float2(1.0, 1.0)
            };

            VertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            
            // Apply Y-flip if needed (for OpenGL textures)
            if (flipY) {
                // Flip the Y coordinate
                texCoords[0].y = 1.0 - texCoords[0].y;
                texCoords[1].y = 1.0 - texCoords[1].y;
                texCoords[2].y = 1.0 - texCoords[2].y;
                texCoords[3].y = 1.0 - texCoords[3].y;
            }
            
            out.texCoord = texCoords[vertexID];
            return out;
        }
        """

        // Create a simple fragment shader
        let fragmentShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        fragment float4 blit_fragment(VertexOut in [[stage_in]],
                                     texture2d<float> texture [[texture(0)]],
                                     sampler textureSampler [[sampler(0)]]) {
            return texture.sample(textureSampler, in.texCoord);
        }
        """

        // Create a Metal library from the shader source
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: vertexShaderSource + fragmentShaderSource, options: nil)
            DLOG("Successfully created Metal library")
        } catch {
            ELOG("Error creating Metal library: \(error)")
            throw error
        }

        // Get the vertex and fragment functions
        guard let vertexFunction = library.makeFunction(name: "blit_vertex") else {
            ELOG("Failed to create vertex function")
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        guard let fragmentFunction = library.makeFunction(name: "blit_fragment") else {
            ELOG("Failed to create fragment function")
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        // Create a render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtlView.colorPixelFormat

        // Create the render pipeline state
        do {
            blitPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            DLOG("Successfully created blit pipeline state")
        } catch {
            ELOG("Failed to create blit pipeline state: \(error)")
            throw error
        }

        // Create a sampler descriptor
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest

        // Create the sampler state
        pointSampler = device.makeSamplerState(descriptor: samplerDescriptor)

        if pointSampler == nil {
            ELOG("Failed to create point sampler state")
            throw MetalViewControllerError.failedToCreateSamplerState("point sampler")
        }

        // Create a linear sampler descriptor
        let linearSamplerDescriptor = MTLSamplerDescriptor()
        linearSamplerDescriptor.minFilter = .linear
        linearSamplerDescriptor.magFilter = .linear

        // Create the linear sampler state
        linearSampler = device.makeSamplerState(descriptor: linearSamplerDescriptor)

        if linearSampler == nil {
            ELOG("Failed to create linear sampler state")
            throw MetalViewControllerError.failedToCreateSamplerState("linear sampler")
        }

        DLOG("Successfully set up blit shader and samplers")
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

        // Get screen rect and buffer size
        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Check if screen rect is valid (has reasonable dimensions)
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10

        // Use effective dimensions when screen rect is invalid
        let effectiveRect = isScreenRectValid ? screenRect : CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)

        // Log frame draw at a lower frequency to avoid log spam
//        if frameCount % 60 == 0 {
//            VLOG("""
//                 Drawing frame \(frameCount):
//                 Buffer size: \(bufferSize)
//                 Screen rect: \(screenRect)
//                 Effective rect: \(effectiveRect)
//                 Is screen rect valid: \(isScreenRectValid)
//                 View size: \(view.frame.size)
//                 Drawable size: \(view.drawableSize)
//                """)
//        }

        // Check if the texture needs to be created or updated
        if inputTexture == nil {
            do {
                try updateInputTexture()
                DLOG("Created input texture")
            } catch {
                ELOG("Error creating texture in draw: \(error)")

                // Use our recovery method instead of just retrying
                recoverFromGPUError()
                return
            }
        }

        if emulatorCore.skipEmulationLoop {
            return
        }

        // Check if we have a valid pipeline
        if customPipeline == nil && blitPipeline == nil {
            DLOG("No valid pipeline available, trying to set up shaders directly")
            createBasicShaders()

            // If that didn't work, try the default library approach
            if customPipeline == nil && blitPipeline == nil {
                createBasicShadersWithDefaultLibrary()
            }
        }

        // Handle rendering based on the core type
        if emulatorCore.rendersToOpenGL {
            // For OpenGL cores, we need to handle the front buffer synchronization
            if !emulatorCore.isSpeedModified
                && (!emulatorCore.isEmulationPaused || emulatorCore.isFrontBufferReady)
                && !emulatorCore.skipLayout { // Skip layout is mostly for Retroarch
                emulatorCore.frontBufferCondition.lock()
                while !emulatorCore.isFrontBufferReady && !emulatorCore.isEmulationPaused {
                    emulatorCore.frontBufferCondition.wait()
                }
                let isFrontBufferReady = emulatorCore.isFrontBufferReady
                emulatorCore.frontBufferCondition.unlock()

                if isFrontBufferReady {
                    // For OpenGL cores, the texture is updated in didRenderFrameOnAlternateThread
                    // We just need to render it here
                    directRender(in: view)

                    emulatorCore.frontBufferCondition.lock()
                    emulatorCore.isFrontBufferReady = false
                    emulatorCore.frontBufferCondition.signal()
                    emulatorCore.frontBufferCondition.unlock()
                }
            } else {
                // Not speed modifed or paused, just keep rendering
                // TODO: We should only render when the front buffer is ready perhaps?
                directRender(in: view)
            }
        } else {
            // For non-OpenGL cores, we need to update the texture from the core's buffer
            let updated = updateTextureFromCore()
            if updated {
                // Render the updated texture
                directRender(in: view)
            } else {
                WLOG("Failed to update texture from core")
            }
        }

        // Schedule the next frame if needed
        if !isPaused {
            // Request another draw on the next frame
            view.setNeedsDisplay()
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

        // Reuse command buffers efficiently
        let commandBuffer: MTLCommandBuffer
        if let queue = self.commandQueue {
            commandBuffer = queue.makeCommandBuffer()!
            self.previousCommandBuffer = commandBuffer
        } else {
            DLOG("Error: Command queue is nil")
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
            DLOG("Error: Could not create render encoder")
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
                ELOG("Error: Effect filter pipeline is nil")
                renderEncoder.endEncoding()
                return
            }
            pipelineState = effectFilterPipeline
            DLOG("Using effect filter pipeline")
        } else {
            guard let blitPipeline = blitPipeline else {
                ELOG("Error: Blit pipeline is nil")
                renderEncoder.endEncoding()
                return
            }
            pipelineState = blitPipeline
            DLOG("Using blit pipeline")
        }

        DLOG("Blit pipeline state: \(blitPipeline != nil)")

        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        DLOG("🔬 Drawing primitives with pipeline state: \(pipelineState)")

        // Set the vertex buffer with conditional texture coordinates based on the core type
        let vertices: [Float]

        // For both OpenGL and non-OpenGL cores, we use the same vertex positions
        // but the shader will handle the Y-flip based on the flipY parameter
        vertices = [
            -1.0, -1.0, 0.0, 0.0, 0.0, // bottom-left: (u=0, v=0)
             1.0, -1.0, 0.0, 1.0, 0.0, // bottom-right: (u=1, v=0)
            -1.0,  1.0, 0.0, 0.0, 1.0, // top-left: (u=0, v=1)
             1.0,  1.0, 0.0, 1.0, 1.0  // top-right: (u=1, v=1)
        ]
        
        DLOG("Using standard texture coordinates, flipY will be handled by shader")

        let vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: .storageModeShared)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Set the texture
        guard let inputTexture = inputTexture else {
            DLOG("Error: Input texture is nil")
            renderEncoder.endEncoding()
            return
        }

        // Apply custom filter if available
        if let filter = self.filter, let ciContext = self.ciContext {
            // Create CIImage from the input texture
            let ciImage = CIImage(mtlTexture: inputTexture, options: nil)

            if let ciImage = ciImage, let filteredImage = filter.apply(to: ciImage, in: CGRect(x: 0, y: 0, width: inputTexture.width, height: inputTexture.height)) {
                // Create a temporary texture for the filtered image
                let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: inputTexture.pixelFormat,
                    width: inputTexture.width,
                    height: inputTexture.height,
                    mipmapped: false
                )
                textureDescriptor.usage = [.shaderRead, .renderTarget]

                if let filteredTexture = device?.makeTexture(descriptor: textureDescriptor) {
                    // Render the filtered image to the texture
                    ciContext.render(filteredImage, to: filteredTexture, commandBuffer: nil, bounds: CGRect(x: 0, y: 0, width: inputTexture.width, height: inputTexture.height), colorSpace: CGColorSpaceCreateDeviceRGB())

                    // Use the filtered texture instead
                    renderEncoder.setFragmentTexture(filteredTexture, index: 0)
                } else {
                    // Fall back to original texture if filtering fails
                    renderEncoder.setFragmentTexture(inputTexture, index: 0)
                }
            } else {
                // Fall back to original texture if filtering fails
                renderEncoder.setFragmentTexture(inputTexture, index: 0)
            }
        } else {
            // No filter, use original texture
            renderEncoder.setFragmentTexture(inputTexture, index: 0)
        }

        // Set the sampler state - THIS IS THE KEY FIX
        if let pointSampler = pointSampler {
            renderEncoder.setFragmentSamplerState(pointSampler, index: 0)
            DLOG("Set point sampler at index 0")
        } else if let linearSampler = linearSampler {
            renderEncoder.setFragmentSamplerState(linearSampler, index: 0)
            DLOG("Set linear sampler at index 0")
        } else {
            DLOG("Error: No sampler state available")
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

        // Ensure we have an OpenGL context for OpenGL cores
        if glContext == nil, let emulatorCore = emulatorCore, emulatorCore.rendersToOpenGL {
            ILOG("OpenGL context not initialized yet, initializing now")
            initializeOpenGLContext()
        }

#if !(targetEnvironment(macCatalyst) || os(macOS))
        guard let glContext = self.glContext else {
            ELOG("glContext was nil, cannot start rendering on alternate thread")
            return
        }

        // Create contexts for alternate thread rendering
        alternateThreadBufferCopyGLContext = EAGLContext(api: glContext.api,
                                                         sharegroup: glContext.sharegroup)
        alternateThreadGLContext = EAGLContext(api: glContext.api,
                                               sharegroup: glContext.sharegroup)
        EAGLContext.setCurrent(alternateThreadGLContext)
        ILOG("Successfully initialized alternate thread GL contexts")
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
        /// Ensure we have a valid backing texture
        guard let backingTexture = backingMTLTexture else {
            ELOG("backingMTLTexture was nil")
            recoverFromGPUError()
            return
        }

        /// Ensure OpenGL commands are flushed before using the shared texture
        glFlush()

        /// Lock the front buffer to prevent concurrent access
        emulatorCore?.frontBufferLock.lock()

        /// Wait for any previous command buffer to be scheduled
        previousCommandBuffer?.waitUntilScheduled()

        /// Create a new command buffer
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            ELOG("commandBuffer was nil")
            emulatorCore?.frontBufferLock.unlock()
            recoverFromGPUError()
            return
        }

        /// Create a blit encoder for copying textures
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            ELOG("encoder was nil")
            emulatorCore?.frontBufferLock.unlock()
            recoverFromGPUError()
            return
        }

        // Get the screen rect or use a default
        guard let emulatorCore = emulatorCore else {
            ELOG("Emulator core is nil")
            encoder.endEncoding()
            commandBuffer.commit()
            return
        }

        let screenRect = emulatorCore.screenRect

        // For OpenGL cores, create the input texture on demand if needed
        if inputTexture == nil ||
           (inputTexture != nil &&
            (inputTexture!.width != Int(screenRect.width) ||
             inputTexture!.height != Int(screenRect.height))) {

            ILOG("Creating/updating input texture for OpenGL core: \(Int(screenRect.width))x\(Int(screenRect.height))")

            do {
                try updateInputTexture()
            } catch {
                ELOG("Failed to create input texture for OpenGL core: \(error)")
                encoder.endEncoding()
                commandBuffer.commit()
                emulatorCore.frontBufferLock.unlock()
                return
            }
        }

        // Ensure we have a valid input texture after potential creation
        guard let destTexture = inputTexture else {
            ELOG("Input texture is still nil after creation attempt")
            encoder.endEncoding()
            commandBuffer.commit()
            emulatorCore.frontBufferLock.unlock()
            return
        }

        // Verify dimensions to avoid crashes
        let isValidRect = screenRect.width > 0 && screenRect.height > 0 &&
                          Int(screenRect.width) <= backingTexture.width &&
                          Int(screenRect.height) <= backingTexture.height

        if !isValidRect {
            WLOG("Invalid screen rect for OpenGL texture copy: \(screenRect)")
            WLOG("Backing texture size: \(backingTexture.width)x\(backingTexture.height)")

            // Use the entire backing texture as fallback
            let safeWidth = min(backingTexture.width, destTexture.width)
            let safeHeight = min(backingTexture.height, destTexture.height)

            DLOG("Using fallback texture copy: size=(\(safeWidth),\(safeHeight))")

            encoder.copy(from: backingTexture,
                         sourceSlice: 0, sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: safeWidth, height: safeHeight, depth: 1),
                         to: destTexture,
                         destinationSlice: 0, destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        } else {
            /// Use safe dimensions that won't exceed the texture bounds
            let safeX = max(0, Int(screenRect.origin.x))
            let safeY = max(0, Int(screenRect.origin.y))
            let safeWidth = min(Int(screenRect.width), backingTexture.width - safeX)
            let safeHeight = min(Int(screenRect.height), backingTexture.height - safeY)

            DLOG("OpenGL texture copy: origin=(\(safeX),\(safeY)), size=(\(safeWidth),\(safeHeight))")

            /// Copy from the backing texture to the input texture
            encoder.copy(from: backingTexture,
                         sourceSlice: 0, sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: safeX, y: safeY, z: 0),
                         sourceSize: MTLSize(width: safeWidth, height: safeHeight, depth: 1),
                         to: destTexture,
                         destinationSlice: 0, destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        }

        /// End encoding and commit the command buffer
        encoder.endEncoding()
        commandBuffer.commit()

        /// Unlock the front buffer
        emulatorCore.frontBufferLock.unlock()

        /// Signal that the front buffer is ready
        emulatorCore.frontBufferCondition.lock()
        emulatorCore.isFrontBufferReady = true
        emulatorCore.frontBufferCondition.signal()
        emulatorCore.frontBufferCondition.unlock()
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

            // Log state change for debugging
            ILOG("Metal view isPaused changing from \(oldValue) to \(isPaused)")

#if !os(visionOS)
            // Set the MTKView's paused state, but only if we have a stable view
            if let view = mtlView, view.superview != nil {
                // We're going to intentionally defer the paused state change to avoid race conditions
                DispatchQueue.main.async { [weak self, isPaused] in
                    guard let self = self else { return }

                    if isPaused {
                        // When pausing, wait for any pending renders to complete first
                        self.previousCommandBuffer?.waitUntilCompleted()
                        DLOG("Setting MTKView isPaused = true after waiting for command buffer")
                        self.mtlView?.isPaused = true
                    } else {
                        // When unpausing, reset the frame count and request a redraw through the proper channels
                        self.frameCount = 0
                        DLOG("Setting MTKView isPaused = false and requesting redraw")
                        self.mtlView?.isPaused = false

                        // Request a redraw through proper CADisplayLink/timer mechanisms
                        // instead of directly calling draw()
                        self.mtlView?.setNeedsDisplay()
                    }
                }
            } else {
                WLOG("MTKView is nil or not in view hierarchy during isPaused change")
            }
#endif
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
    /// Determines if a texture update is needed based on changes in dimensions, format, or settings
    /// This optimized version includes additional checks for valid screen rects and effective dimensions
    private func isTextureUpdateNeeded() -> Bool {
        guard let emulatorCore = emulatorCore else { return false }

        // Get current state
        let bufferSize = emulatorCore.bufferSize
        let screenRect = emulatorCore.screenRect
        let currentNativeScaleEnabled = renderSettings.nativeScaleEnabled

        // Check if screen rect is valid (has reasonable dimensions)
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10

        // Use effective dimensions when screen rect is invalid
        let effectiveRect = isScreenRectValid ? screenRect :
        CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)

        // Log the current state for debugging
        DLOG("isTextureUpdateNeeded: bufferSize=\(bufferSize), currentNativeScaleEnabled=\(currentNativeScaleEnabled)")

        // If no texture exists, we definitely need to create one
        if inputTexture == nil {
            DLOG("isTextureUpdateNeeded: inputTexture is nil")
            return true
        }

        // Check if texture dimensions match effective dimensions
        if inputTexture?.width != Int(effectiveRect.width) ||
            inputTexture?.height != Int(effectiveRect.height) {
            DLOG("isTextureUpdateNeeded: texture size doesn't match effective dimensions")
            return true
        }

        // Check if pixel format has changed
#if targetEnvironment(simulator)
        let mtlPixelFormat: MTLPixelFormat = .rgba8Unorm
#else
        let mtlPixelFormat: MTLPixelFormat = emulatorCore.rendersToOpenGL ? .rgba8Unorm : getMTLPixelFormat(from: emulatorCore.pixelFormat, type: emulatorCore.pixelType)
#endif

        if inputTexture?.pixelFormat != mtlPixelFormat {
            DLOG("isTextureUpdateNeeded: pixel format changed")
            return true
        }

        // Check if other relevant properties have changed
        if lastBufferSize != bufferSize ||
            lastScreenBounds != screenRect ||
            lastPixelFormat != emulatorCore.pixelFormat ||
            lastPixelType != emulatorCore.pixelType ||
            lastNativeScaleEnabled != currentNativeScaleEnabled {
            DLOG("isTextureUpdateNeeded: core properties changed")
            return true
        }

        // No update needed
        return false
    }

    // Add this method to the PVMetalViewController class
    private func fallbackRender(_ emulatorCore: PVEmulatorCore, in view: MTKView) {
        DLOG("Using fallback rendering method")

        guard let device = device,
              let commandQueue = commandQueue,
              let drawable = view.currentDrawable,
              let inputTexture = inputTexture else {
            DLOG("Missing required resources for fallback rendering")
            return
        }

        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            DLOG("Failed to create command buffer")
            return
        }

        // Create a blit command encoder
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            DLOG("Failed to create blit encoder")
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

        DLOG("Fallback rendering completed")
    }

    // Add this method to create a custom shader that doesn't require a sampler
    private func setupCustomShader() throws {
        guard let device = device else {
            throw MetalViewControllerError.deviceIsNil
        }

        // Create a simple vertex shader
        let vertexShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut custom_vertex(uint vertexID [[vertex_id]], constant bool &flipY [[buffer(1)]]) {
            // Define positions for a fullscreen quad
            const float2 positions[4] = {
                float2(-1.0, -1.0),
                float2(1.0, -1.0),
                float2(-1.0, 1.0),
                float2(1.0, 1.0)
            };

            // Define standard texture coordinates
            float2 texCoords[4] = {
                float2(0.0, 0.0),
                float2(1.0, 0.0),
                float2(0.0, 1.0),
                float2(1.0, 1.0)
            };

            VertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            
            // Apply Y-flip if needed (for OpenGL textures)
            if (flipY) {
                // Flip the Y coordinate
                texCoords[0].y = 1.0 - texCoords[0].y;
                texCoords[1].y = 1.0 - texCoords[1].y;
                texCoords[2].y = 1.0 - texCoords[2].y;
                texCoords[3].y = 1.0 - texCoords[3].y;
            }
            
            out.texCoord = texCoords[vertexID];
            return out;
        }
        """

        // Create a simple fragment shader with built-in sampler
        let fragmentShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        fragment float4 custom_fragment(VertexOut in [[stage_in]],
                                      texture2d<float> texture [[texture(0)]]) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            return texture.sample(textureSampler, in.texCoord);
        }
        """

        // Create a Metal library from the shader source
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: vertexShaderSource + fragmentShaderSource, options: nil)
            DLOG("Successfully created custom Metal library")
        } catch {
            ELOG("Error creating custom Metal library: \(error)")
            throw error
        }

        // Get the vertex and fragment functions
        guard let vertexFunction = library.makeFunction(name: "custom_vertex") else {
            ELOG("Failed to create custom vertex function")
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        guard let fragmentFunction = library.makeFunction(name: "custom_fragment") else {
            ELOG("Failed to create custom fragment function")
            throw EffectFilterShaderError.noBlitterShaderFound
        }

        // Create a render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtlView.colorPixelFormat

        // Create the render pipeline state
        do {
            customPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            DLOG("Successfully created custom pipeline state")
        } catch {
            ELOG("Failed to create custom pipeline state: \(error)")
            throw error
        }
    }

    private func directRender(in view: MTKView) {
        guard let device = device,
              let commandQueue = commandQueue,
              let drawable = view.currentDrawable,
              let inputTexture = inputTexture,
              let emulatorCore = emulatorCore else {
            ELOG("Missing required resources for direct rendering")
            // Call the recovery method when resources are missing
            recoverFromGPUError()
            return
        }

        // Log the current rendering dimensions for debugging
//        VLOG("""
//             DirectRender dimensions:
//             Input texture: \(inputTexture.width)x\(inputTexture.height)
//             Drawable size: \(drawable.texture.width)x\(drawable.texture.height)
//             View size: \(view.frame.size)
//             Buffer size: \(emulatorCore.bufferSize)
//             Screen rect: \(emulatorCore.screenRect)
//            """)

        // Validate screen rect dimensions
        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Check if screen rect is valid (has reasonable dimensions)
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10

        // If screen rect is invalid or unusually small, use the full buffer size instead
        let effectiveScreenRect = isScreenRectValid ? screenRect : CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)

        // Check if input texture dimensions match effective dimensions
        let textureMatchesEffective = inputTexture.width == Int(effectiveScreenRect.width) &&
        inputTexture.height == Int(effectiveScreenRect.height)

        // If texture doesn't match effective dimensions, recreate it
        if !textureMatchesEffective {
            ILOG("Texture dimensions (\(inputTexture.width)x\(inputTexture.height)) don't match effective dimensions (\(effectiveScreenRect.width)x\(effectiveScreenRect.height))")
            do {
                try updateInputTexture()
            } catch {
                ELOG("Failed to update texture: \(error)")
                recoverFromGPUError()
                return
            }
        }

//        DLOG("""
//             Using effective screen rect: \(effectiveScreenRect)
//             Original screen rect: \(screenRect)
//             Is screen rect valid: \(isScreenRectValid)
//             Texture matches effective: \(textureMatchesEffective)
//            """)

        // Check if we have a valid pipeline
        if customPipeline == nil && blitPipeline == nil {
            WLOG("No valid pipeline available in directRender, trying to set up shaders directly")
            createBasicShaders()

            // If we still don't have a pipeline, attempt recovery
            if customPipeline == nil && blitPipeline == nil {
                ELOG("Failed to create a pipeline, cannot render")
                recoverFromGPUError()
                return
            }
        }

        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            ELOG("Failed to create command buffer")
            recoverFromGPUError()
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
            ELOG("Failed to create render encoder")
            return
        }

        // Set the viewport to match the drawable size
        // Ensure we're using the proper aspect ratio based on the effective screen rect
        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(drawable.texture.width),
            height: Double(drawable.texture.height),
            znear: 0.0,
            zfar: 1.0
        )
        renderEncoder.setViewport(viewport)

        // Get the flipY parameter - set to true for non-OpenGL cores, false for OpenGL cores
        var flipY: Bool = !emulatorCore.rendersToOpenGL

        // Use the custom pipeline if available, otherwise fall back to the blit pipeline
        if let customPipeline = customPipeline {
            renderEncoder.setRenderPipelineState(customPipeline)

            // Set the texture
            renderEncoder.setFragmentTexture(inputTexture, index: 0)

            // Pass the flipY parameter to the vertex shader
            let flipYBuffer = device.makeBuffer(bytes: &flipY, length: MemoryLayout<Bool>.size, options: .storageModeShared)
            renderEncoder.setVertexBuffer(flipYBuffer, offset: 0, index: 1)

            // Draw the primitives
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        } else if let blitPipeline = blitPipeline {
            // Fall back to the blit pipeline
            renderEncoder.setRenderPipelineState(blitPipeline)

            // Set the texture
            renderEncoder.setFragmentTexture(inputTexture, index: 0)

            // Pass the flipY parameter to the vertex shader
            let flipYBuffer = device.makeBuffer(bytes: &flipY, length: MemoryLayout<Bool>.size, options: .storageModeShared)
            renderEncoder.setVertexBuffer(flipYBuffer, offset: 0, index: 1)

            // Set the sampler state - use the appropriate sampler based on smoothing setting
            let sampler = renderSettings.smoothingEnabled ? linearSampler : pointSampler
            if let sampler = sampler {
                renderEncoder.setFragmentSamplerState(sampler, index: 0)
            }

            // Draw the primitives
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        } else {
            ELOG("No pipeline available")
        }

        // End encoding
        renderEncoder.endEncoding()

        // Present the drawable
        commandBuffer.present(drawable)

        // Add completion handler to detect GPU errors
        commandBuffer.addCompletedHandler { [weak self] buffer in
            if let error = buffer.error {
                ELOG("GPU error during rendering: \(error)")
                self?.recoverFromGPUError()
            }
        }

        // Commit the command buffer
        commandBuffer.commit()

        // Store the command buffer for synchronization
        previousCommandBuffer = commandBuffer

        // Increment frame count
        frameCount += 1
    }

    // Helper method to update texture from core's buffer
    /// Updates the texture from the emulator core's video buffer
    /// Returns true if the update was successful, false otherwise
    private func updateTextureFromCore() -> Bool {
        guard let emulatorCore = emulatorCore,
              let device = device else {
            DLOG("Missing required resources for texture update")
            // Don't call recovery here as this is often a normal initial state
            return false
        }

        // Skip texture update for OpenGL cores - they use a different path
        if emulatorCore.rendersToOpenGL {
            DLOG("Skipping texture update for OpenGL core - handled in didRenderFrameOnAlternateThread")
            return true
        }

        // Track changes in buffer size and screen rect for debugging
        let currentBufferSize = emulatorCore.bufferSize
        let currentScreenRect = emulatorCore.screenRect
        let currentPixelFormat = emulatorCore.pixelFormat
        let currentPixelType = emulatorCore.pixelType

        // Check if screen rect is valid (has reasonable dimensions)
        let isScreenRectValid = currentScreenRect.width > 10 && currentScreenRect.height > 10

        // Use effective screen rect when the original is invalid
        let effectiveScreenRect = isScreenRectValid ? currentScreenRect :
        CGRect(x: 0, y: 0, width: currentBufferSize.width, height: currentBufferSize.height)

        // Check if we need to update the texture
        let dimensionsChanged = currentBufferSize != lastBufferSize ||
        currentScreenRect != lastScreenBounds ||
        currentPixelFormat != lastPixelFormat ||
        currentPixelType != lastPixelType

        // Check if texture exists and has correct dimensions
        let textureNeedsUpdate = inputTexture == nil ||
        (inputTexture != nil &&
         (inputTexture!.width != Int(effectiveScreenRect.width) ||
          inputTexture!.height != Int(effectiveScreenRect.height)))

        // Log if any of these values have changed since last frame
        if dimensionsChanged {
            DLOG("""
                 Core rendering parameters changed:
                 Previous buffer size: \(lastBufferSize), Current: \(currentBufferSize)
                 Previous screen rect: \(lastScreenBounds), Current: \(currentScreenRect)
                 Effective screen rect: \(effectiveScreenRect)
                 Previous pixel format: \(GLenum(lastPixelFormat).toString), Current: \(GLenum(currentPixelFormat).toString)
                 Previous pixel type: \(GLenum(lastPixelType).toString), Current: \(GLenum(currentPixelType).toString)
                 Input texture size: \(inputTexture?.width ?? 0)x\(inputTexture?.height ?? 0)
                 Metal view size: \(mtlView.drawableSize.width)x\(mtlView.drawableSize.height)
                 Native scale enabled: \(renderSettings.nativeScaleEnabled)
                 Screen rect valid: \(isScreenRectValid)
                 Texture needs update: \(textureNeedsUpdate)
                """)
        }

        // If we need to update the texture, do it before proceeding
        if textureNeedsUpdate {
            ILOG("Detected texture needs update, recreating texture with dimensions: \(effectiveScreenRect.width)x\(effectiveScreenRect.height)")
            do {
                try updateInputTexture()
                ILOG("Successfully recreated texture with dimensions: \(effectiveScreenRect.width)x\(effectiveScreenRect.height)")
            } catch {
                ELOG("Failed to recreate texture: \(error)")
                return false
            }
        }

        // Update the stored values if dimensions changed
        if dimensionsChanged {
            lastBufferSize = currentBufferSize
            lastScreenBounds = currentScreenRect
            lastPixelFormat = currentPixelFormat
            lastPixelType = currentPixelType
        }

        // Get the video buffer from the core
        guard let videoBuffer = emulatorCore.videoBuffer,
              let inputTexture = inputTexture else {
            DLOG("Missing video buffer or input texture")
            return false
        }

        // Verify texture dimensions match effective screen rect
        if inputTexture.width != Int(effectiveScreenRect.width) ||
            inputTexture.height != Int(effectiveScreenRect.height) {
            ELOG("Texture dimensions (\(inputTexture.width)x\(inputTexture.height)) don't match effective dimensions (\(effectiveScreenRect.width)x\(effectiveScreenRect.height))")
            return false
        }

        let bufferSize = emulatorCore.bufferSize

        // Calculate buffer size
        let bytesPerPixel = getByteWidth(for: Int32(emulatorCore.pixelFormat), type: Int32(emulatorCore.pixelType))
        let bytesPerRow = Int(bufferSize.width) * Int(bytesPerPixel)
        let totalBytes = bytesPerRow * Int(bufferSize.height)

        // Use a buffer pool to reduce allocations and improve performance
        let tempBuffer: MTLBuffer
        if let uploadBuffer = uploadBuffer, uploadBuffer.length >= totalBytes {
            // Reuse existing buffer if it's large enough
            tempBuffer = uploadBuffer
        } else {
            // Create a new buffer with some extra capacity to avoid frequent reallocations
            let paddedSize = Int(Double(totalBytes) * 1.2) // Add 20% extra capacity
            DLOG("Creating new upload buffer of size \(paddedSize) (requested: \(totalBytes))")

            guard let newBuffer = device.makeBuffer(length: paddedSize, options: .storageModeShared) else {
                ELOG("Failed to create upload buffer")
                recoverFromGPUError()
                return false
            }

            // Track buffer creation for debugging
            bufferCreationCount += 1
            DLOG("Buffer creation count: \(bufferCreationCount)")

            uploadBuffer = newBuffer
            tempBuffer = newBuffer
        }

        // Copy the video buffer to the upload buffer
        let uploadContents = tempBuffer.contents()
        memcpy(uploadContents, videoBuffer, totalBytes)

        // Create a command buffer
        guard let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            DLOG("Failed to create command buffer")
            return false
        }

        // Create a blit command encoder
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            DLOG("Failed to create blit encoder")
            return false
        }

        defer {
            blitEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()  // Wait for the copy to complete
        }

        // Calculate effective source size using the effective screen rect
        let effectiveWidth = Int(effectiveScreenRect.width)
        let effectiveHeight = Int(effectiveScreenRect.height)

        // Verify the dimensions match the texture
        guard effectiveWidth == inputTexture.width && effectiveHeight == inputTexture.height else {
            ELOG("""
                 Dimension mismatch during buffer copy:
                 Effective dimensions: \(effectiveWidth)x\(effectiveHeight)
                 Input texture size: \(inputTexture.width)x\(inputTexture.height)
                 This would cause a crash - aborting copy operation
                """)
            return false
        }

        // Calculate safe source offset if we're using a portion of the buffer
        let xOffset = Int(effectiveScreenRect.origin.x)
        let yOffset = Int(effectiveScreenRect.origin.y)

        // Ensure offsets are non-negative and within buffer bounds
        let safeXOffset = max(0, min(xOffset, Int(bufferSize.width) - 1))
        let safeYOffset = max(0, min(yOffset, Int(bufferSize.height) - 1))

        // Calculate maximum allowed width and height from the offset
        let maxWidth = Int(bufferSize.width) - safeXOffset
        let maxHeight = Int(bufferSize.height) - safeYOffset

        // Calculate safe dimensions that won't exceed the buffer
        let safeWidth = min(effectiveWidth, maxWidth)
        let safeHeight = min(effectiveHeight, maxHeight)

        // Calculate source offset with safety bounds
        let sourceOffset = (safeYOffset * bytesPerRow) + (safeXOffset * Int(bytesPerPixel))

        // Verify source offset and dimensions are valid
        if sourceOffset >= totalBytes || sourceOffset < 0 || safeWidth <= 0 || safeHeight <= 0 {
            ELOG("""
                 Invalid source offset during buffer copy:
                 Source offset: \(sourceOffset)
                 Max valid offset: \(totalBytes > 0 ? totalBytes - 1 : 0)
                 Buffer size: \(totalBytes) bytes
                 Effective dimensions: \(effectiveWidth)x\(effectiveHeight)
                 This would cause a crash - aborting copy operation
                """)
            return false
        }

//        VLOG("""
//             Copying buffer to texture:
//             Effective dimensions: \(effectiveWidth)x\(effectiveHeight)
//             Source offset: \(sourceOffset) (x:\(xOffset), y:\(yOffset))
//             Bytes per row: \(bytesPerRow)
//             Input texture size: \(inputTexture.width)x\(inputTexture.height)
//             Total buffer size: \(totalBytes) bytes
//            """)

        // Copy from the upload buffer to the texture
        // Always use a safe source offset (either valid calculated offset or 0)
        let finalSourceOffset = (isScreenRectValid && sourceOffset < totalBytes && sourceOffset >= 0) ? sourceOffset : 0

        // Log the final copy parameters for debugging
//        VLOG("Final copy parameters: sourceOffset=\(finalSourceOffset), bytesPerRow=\(bytesPerRow)")

        // Calculate final safe dimensions based on the source offset and buffer size
        // Ensure we don't exceed the buffer boundaries
        let finalWidth = min(safeWidth, (totalBytes - finalSourceOffset) / Int(bytesPerPixel) / effectiveHeight * bytesPerRow)
        let finalHeight = min(safeHeight, (totalBytes - finalSourceOffset) / bytesPerRow)

        // Ensure we have valid dimensions
        if finalWidth <= 0 || finalHeight <= 0 {
            ELOG("Invalid dimensions for texture copy: width=\(finalWidth), height=\(finalHeight)")
            return false
        }

        DLOG("Copying buffer to texture: size=(\(finalWidth)x\(finalHeight)), offset=\(finalSourceOffset)")

        // Copy from the upload buffer to the texture with safe dimensions
        blitEncoder.copy(
            from: tempBuffer,
            sourceOffset: finalSourceOffset,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: totalBytes,
            sourceSize: MTLSizeMake(finalWidth, finalHeight, 1),
            to: inputTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOriginMake(0, 0, 0)
        )



        //        DLOG("Updated texture from core: \(bufferSize.width)x\(bufferSize.height), bytes per pixel: \(bytesPerPixel)")
        return true
    }

    /// Enhanced debug method to provide comprehensive information about the current rendering state
    /// This is useful for diagnosing rendering issues and understanding the state of the Metal pipeline
    internal func dumpTextureInfo() {
        guard let emulatorCore = emulatorCore else {
            ELOG("Cannot dump texture info - missing emulator core")
            return
        }

        // Get screen rect and buffer size
        let screenRect = emulatorCore.screenRect
        let bufferSize = emulatorCore.bufferSize

        // Check if screen rect is valid
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10

        // Calculate effective dimensions
        let effectiveRect = isScreenRectValid ? screenRect :
        CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)

        ILOG("""
             ===== Texture Debug Info =====
             Input Texture: \(inputTexture != nil ? "Valid" : "Nil")
             Width: \(inputTexture?.width ?? 0)
             Height: \(inputTexture?.height ?? 0)
             Pixel Format: \(inputTexture?.pixelFormat.rawValue ?? 0)

             Emulator Core: \(type(of: emulatorCore))
             Buffer Size: \(bufferSize)
             Screen Rect: \(screenRect)
             Effective Rect: \(effectiveRect)
             Screen Rect Valid: \(isScreenRectValid)
             Pixel Format: \(GLenum(emulatorCore.pixelFormat).toString) (\(emulatorCore.pixelFormat))
             Pixel Type: \(GLenum(emulatorCore.pixelType).toString) (\(emulatorCore.pixelType))

             Metal View: \(mtlView.frame.size)
             Drawable Size: \(mtlView.drawableSize)
             Content Scale: \(mtlView.contentScaleFactor)
             Native Scale Enabled: \(renderSettings.nativeScaleEnabled)

             Last Buffer Size: \(lastBufferSize)
             Last Screen Bounds: \(lastScreenBounds)
             Last Pixel Format: \(GLenum(lastPixelFormat).toString)
             Last Pixel Type: \(GLenum(lastPixelType).toString)
            """)

        if let videoBuffer = emulatorCore.videoBuffer {
            // Calculate buffer size
            let bytesPerPixel = getByteWidth(for: Int32(emulatorCore.pixelFormat), type: Int32(emulatorCore.pixelType))
            let bytesPerRow = Int(bufferSize.width) * Int(bytesPerPixel)
            let totalBytes = bytesPerRow * Int(bufferSize.height)

            // Calculate source offset
            let xOffset = Int(effectiveRect.origin.x)
            let yOffset = Int(effectiveRect.origin.y)
            let sourceOffset = (yOffset * bytesPerRow) + (xOffset * Int(bytesPerPixel))

            // Check if offset is valid
            let isOffsetValid = sourceOffset < totalBytes

            ILOG("""
                 Video Buffer Details:
                 Address: \(videoBuffer)
                 Bytes Per Pixel: \(bytesPerPixel)
                 Bytes Per Row: \(bytesPerRow)
                 Total Bytes: \(totalBytes)
                 Source Offset: \(sourceOffset) (x:\(xOffset), y:\(yOffset))
                 Offset Valid: \(isOffsetValid)
                """)

            // Check first few bytes of the buffer
            let buffer = videoBuffer.assumingMemoryBound(to: UInt8.self)
            var byteSample = "First 16 bytes: "
            for i in 0..<min(16, totalBytes) {
                byteSample += String(format: "%02X ", buffer[i])
            }
            DLOG("  \(byteSample)")

            // If source offset is valid, show bytes at that position too
            if isOffsetValid && sourceOffset > 0 && sourceOffset + 16 < totalBytes {
                var offsetSample = "Bytes at offset \(sourceOffset): "
                for i in 0..<16 {
                    offsetSample += String(format: "%02X ", buffer[sourceOffset + i])
                }
                DLOG("  \(offsetSample)")
            }
        }

        // Check for potential issues and provide warnings
        var issues: [String] = []

        if inputTexture == nil {
            issues.append("Input texture is nil")
        } else if let inputTexture = inputTexture {
            if let effectiveWidth = Int(exactly: effectiveRect.width),
               let effectiveHeight = Int(exactly: effectiveRect.height),
               inputTexture.width != effectiveWidth || inputTexture.height != effectiveHeight {
                issues.append("Texture dimensions (\(inputTexture.width)x\(inputTexture.height)) don't match effective dimensions (\(effectiveRect.width)x\(effectiveRect.height))")
            }
        }

        if !isScreenRectValid {
            issues.append("Screen rect is invalid (\(screenRect.width)x\(screenRect.height))")
        }

        if !issues.isEmpty {
            WLOG("Potential rendering issues detected:")
            for (index, issue) in issues.enumerated() {
                WLOG("  \(index + 1). \(issue)")
            }
        }
    }

    private func setupShaders() {
        DLOG("Setting up shaders...")

        // Set up the blit shader
        do {
            try setupBlitShader()
            DLOG("Successfully set up blit shader")
        } catch {
            ELOG("Failed to set up blit shader: \(error)")
        }

        // Set up the custom shader
        do {
            try setupCustomShader()
            DLOG("Successfully set up custom shader")
        } catch {
            ELOG("Failed to set up custom shader: \(error)")
        }
    }

    /// Updates the VSync settings for the Metal renderer
    private func updateVsyncSettings() {
        guard let mtlView = mtlView else { return }

        // In Metal, VSync is controlled through the displaySyncEnabled property
        mtlView.isPaused = false

        #if os(iOS) || os(tvOS)
        if #available(iOS 16.0, tvOS 16.0, *) {
            // On iOS/tvOS 16+, we can directly control display sync
            mtlView.preferredFramesPerSecond = vsyncEnabled ? Int(emulatorCore?.frameInterval ?? 60) : 0
            ILOG("Setting VSync to \(vsyncEnabled ? "enabled" : "disabled")")
        } else {
            // On older iOS versions, we can only provide hints through preferredFramesPerSecond
            updatePreferredFPS()
            ILOG("VSync control limited on older iOS versions")
        }
        #else
        // For other platforms, update preferred FPS
        updatePreferredFPS()
        #endif
    }

    /// Toggle VSync on/off
    public func toggleVSync() {
        vsyncEnabled = !vsyncEnabled
        ILOG("VSync \(vsyncEnabled ? "enabled" : "disabled")")
        updateVsyncSettings()
    }

    private func createBasicShaders() {
        DLOG("Creating basic shaders directly...")

        guard let device = device else {
            ELOG("No Metal device available")
            return
        }

        // Create a simple vertex shader with proper OpenGL texture orientation handling
        let vertexSource = """
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

        vertex VertexOut basic_vertex(uint vertexID [[vertex_id]], constant bool &flipY [[buffer(1)]]) {
            // Define positions and texture coordinates directly
            float2 positions[4] = {
                float2(-1.0, -1.0),
                float2(1.0, -1.0),
                float2(-1.0, 1.0),
                float2(1.0, 1.0)
            };

            // Define standard texture coordinates
            float2 texCoords[4] = {
                float2(0.0, 0.0),  // Bottom-left
                float2(1.0, 0.0),  // Bottom-right
                float2(0.0, 1.0),  // Top-left
                float2(1.0, 1.0)   // Top-right
            };
            
            // Apply Y-flip if needed (for OpenGL textures)
            if (flipY) {
                // Flip the Y coordinate
                texCoords[0].y = 1.0 - texCoords[0].y;
                texCoords[1].y = 1.0 - texCoords[1].y;
                texCoords[2].y = 1.0 - texCoords[2].y;
                texCoords[3].y = 1.0 - texCoords[3].y;
            }

            VertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            out.texCoord = texCoords[vertexID];
            return out;
        }
        """

        // Create a separate fragment shader
        let fragmentSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        fragment float4 basic_fragment(VertexOut in [[stage_in]],
                                     texture2d<float> texture [[texture(0)]]) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            return texture.sample(textureSampler, in.texCoord);
        }
        """

        // Try to create the vertex shader library
        do {
            let vertexLibrary = try device.makeLibrary(source: vertexSource, options: nil)
            DLOG("Successfully created vertex shader library")

            // Try to create the fragment shader library
            do {
                let fragmentLibrary = try device.makeLibrary(source: fragmentSource, options: nil)
                DLOG("Successfully created fragment shader library")

                // Get the vertex function
                guard let vertexFunction = vertexLibrary.makeFunction(name: "basic_vertex") else {
                    ELOG("Failed to get vertex function")
                    return
                }

                // Get the fragment function
                guard let fragmentFunction = fragmentLibrary.makeFunction(name: "basic_fragment") else {
                    ELOG("Failed to get fragment function")
                    return
                }

                // Set up the flipY constant for OpenGL textures
                var flipY = !(emulatorCore?.rendersToOpenGL ?? false)
                let constants = MTLFunctionConstantValues()
                constants.setConstantValue(&flipY, type: .bool, index: 0)
                
                // Get the vertex function with constants
                let vertexFunctionWithConstants: MTLFunction
                do {
                    vertexFunctionWithConstants = try vertexLibrary.makeFunction(name: "basic_vertex", constantValues: constants)
                } catch {
                    ELOG("Failed to create vertex function with constants: \(error)")
                    vertexFunctionWithConstants = vertexFunction
                }
                
                // Create a render pipeline descriptor
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunctionWithConstants
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = mtlView.colorPixelFormat

                // Create the render pipeline state
                do {
                    customPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                    DLOG("Successfully created custom pipeline state")

                    // Create a sampler descriptor for linear filtering
                    let linearSamplerDescriptor = MTLSamplerDescriptor()
                    linearSamplerDescriptor.minFilter = .linear
                    linearSamplerDescriptor.magFilter = .linear

                    // Create the linear sampler state
                    linearSampler = device.makeSamplerState(descriptor: linearSamplerDescriptor)

                    // Create a sampler descriptor for point filtering
                    let pointSamplerDescriptor = MTLSamplerDescriptor()
                    pointSamplerDescriptor.minFilter = .nearest
                    pointSamplerDescriptor.magFilter = .nearest

                    // Create the point sampler state
                    pointSampler = device.makeSamplerState(descriptor: pointSamplerDescriptor)

                    DLOG("Successfully created sampler states")
                } catch {
                    ELOG("Failed to create pipeline state: \(error)")
                    // Recovery might be needed here
                    recoverFromGPUError()
                }
            } catch {
                ELOG("Failed to create fragment shader library: \(error)")
                // Recovery might be needed here
                recoverFromGPUError()
            }
        } catch {
            ELOG("Failed to create vertex shader library: \(error)")
            // Recovery might be needed here
            recoverFromGPUError()
        }
    }

    private func createBasicShadersWithDefaultLibrary() {
        DLOG("Creating basic shaders with default library...")

        guard let device = device else {
            ELOG("No Metal device available")
            return
        }

        // Create a simple shader source
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertexShader(uint vid [[vertex_id]]) {
            const float2 vertices[] = {
                float2(-1, -1),
                float2(-1,  1),
                float2( 1, -1),
                float2( 1,  1)
            };

            const float2 texCoords[] = {
                float2(0, 1),
                float2(0, 0),
                float2(1, 1),
                float2(1, 0)
            };

            VertexOut out;
            out.position = float4(vertices[vid], 0, 1);
            out.texCoord = texCoords[vid];
            return out;
        }

        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                      texture2d<float> tex [[texture(0)]]) {
            constexpr sampler s(address::clamp_to_edge, filter::linear);
            return tex.sample(s, in.texCoord);
        }
        """

        do {
            // Create a library from the shader source
            let library = try device.makeLibrary(source: shaderSource, options: nil)

            // Get the vertex and fragment functions
            guard let vertexFunction = library.makeFunction(name: "vertexShader"),
                  let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                ELOG("Failed to get shader functions")
                recoverFromGPUError()
                return
            }

            // Create a render pipeline descriptor
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtlView.colorPixelFormat

            // Create the render pipeline state
            do {
                customPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                DLOG("Successfully created custom pipeline state with default library")
            } catch {
                ELOG("Failed to create pipeline state with default library: \(error)")
                recoverFromGPUError()
            }
        } catch {
            ELOG("Failed to create shader library with default library: \(error)")
            recoverFromGPUError()
        }
    }

    @objc private func handleOrientationChange() {
        DLOG("Orientation changed, updating view and texture")

        // Reset cached values to force recalculation
        lastScreenBounds = .zero
        lastBufferSize = .zero
        lastNativeScaleEnabled = false

        // Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()

        // Update the texture
        do {
            // Force recreation of the texture
            inputTexture = nil
            try updateInputTexture()

            // Force a redraw
            draw(in: mtlView)

            // Post a notification to refresh the GPU view
            //    /        NotificationCenter.default.post(name: Notification.Name("RefreshGPUView"), object: nil)
        } catch {
            ELOG("Error updating texture after orientation change: \(error)")
        }
    }

    // Add this method to check and refresh the texture if needed
    func checkAndRefreshTextureIfNeeded() {
        //        // Check if we have a valid input texture
        //        if inputTexture == nil {
        //            DLOG("Input texture is nil, attempting to recreate")
        //            do {
        //                // Just call the existing updateInputTexture method without modifying it
        //                try updateInputTexture()
        //                DLOG("Successfully recreated input texture")
        //
        //                // Force a redraw using the existing draw method, but with a delay to avoid GPU overload
        //                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        //                    guard let self = self, let mtlView = self.mtlView else { return }
        //                    self.draw(in: mtlView)
        //                }
        //            } catch {
        //                ELOG("Failed to recreate input texture: \(error)")
        //            }
        //        }
    }

    // Add this method to recover from GPU errors
    private func recoverFromGPUError() {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastRecovery = currentTime - lastRecoveryTime

        // If we've tried recovery recently, increment counter
        if timeSinceLastRecovery < 5.0 {
            recoveryAttempts += 1
        } else {
            // Reset counter if it's been a while since last recovery attempt
            recoveryAttempts = 1
        }

        lastRecoveryTime = currentTime

        ELOG("Attempting to recover from GPU error (attempt \(recoveryAttempts) of \(maxRecoveryAttempts))")

        // If we've tried too many times in succession, just log and return
        if recoveryAttempts > maxRecoveryAttempts {
            ELOG("Too many recovery attempts (\(recoveryAttempts)). Giving up until next render cycle.")
            return
        }

        // Reset the command queue
        commandQueue = device?.makeCommandQueue()

        // Reset the texture
        inputTexture = nil

        // Reset the pipelines
        blitPipeline = nil
        customPipeline = nil
        effectFilterPipeline = nil

        // Reset samplers
        pointSampler = nil
        linearSampler = nil

        // Wait a bit before trying to recreate everything, with increasing delay for repeated attempts
        let delay = 0.5 * Double(recoveryAttempts)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            do {
                // Recreate the texture
                try self.updateInputTexture()

                // Recreate the shaders
                self.createBasicShaders()

                if self.customPipeline == nil && self.blitPipeline == nil {
                    self.createBasicShadersWithDefaultLibrary()
                }

                // Create samplers if needed
                if self.pointSampler == nil || self.linearSampler == nil {
                    do {
                        try self.setupTexture()
                    } catch {
                        ELOG("Failed to recreate samplers during recovery: \(error)")
                    }
                }

                // Force a redraw after another delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let mtlView = self.mtlView {
                        self.draw(in: mtlView)
                    }
                }

                // Log success
                ILOG("Successfully recovered from GPU error on attempt \(self.recoveryAttempts)")
            } catch {
                ELOG("Failed to recover from GPU error: \(error)")

                // Try one more time with a longer delay if we haven't reached max attempts
                if self.recoveryAttempts < self.maxRecoveryAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.recoverFromGPUError()
                    }
                }
            }
        }
    }

    // Public method to allow recovery to be triggered from outside
    func triggerGPUErrorRecovery() {
        ILOG("Manual GPU error recovery triggered")
        // Reset recovery attempts to ensure we start fresh
        recoveryAttempts = 0
        lastRecoveryTime = 0
        recoverFromGPUError()
    }

    // MARK: - Public Methods for Safe GPU View Management

    /// Attempts to reset the Metal rendering pipeline to a clean state
    private func resetRenderingPipeline() {
        ILOG("Attempting to reset Metal rendering pipeline")

        // Reset state that could be corrupted
        frameCount = 0
        previousCommandBuffer = nil

        // Release and recreate resources
        do {
            // Release existing resources
            inputTexture = nil
            commandQueue = nil

            // Recreate device if needed
            if device == nil {
                device = MTLCreateSystemDefaultDevice()
                DLOG("Recreated Metal device")
            }

            // Recreate command queue
            if let device = device {
                commandQueue = device.makeCommandQueue()
                DLOG("Recreated Metal command queue")
            }

            // Recreate the MTKView if needed
            if mtlView?.superview == nil || mtlView == nil {
                DLOG("MTKView is nil or detached, recreating...")
                // TODO: Shouldn't use UIScreen.main instead use the current scene screen
                // Instead of calling setupMTKView, recreate MTKView directly
                let screenBounds = UIScreen.main.bounds
                let metalView = MTKView(frame: screenBounds, device: device)
                metalView.autoresizingMask = [] // Disable autoresizing
                
                if Defaults[.nativeScaleEnabled] {
                    let scale = UIScreen.main.scale
                    if scale != 1.0 {
                        mtlView.layer.contentsScale = scale;
                        mtlView.layer.rasterizationScale = scale;
                        mtlView.contentScaleFactor = scale;
                    }
                }

                self.view = metalView
                self.mtlView = metalView
                DLOG("Recreated MTKView")
            }

            // Recreate input texture
            if let emulatorCore = emulatorCore, emulatorCore.bufferSize.width > 0, emulatorCore.bufferSize.height > 0 {
                try setupTexture()
                try updateInputTexture()
                DLOG("Recreated and updated input texture")
            } else {
                ELOG("Cannot recreate input texture: Invalid buffer size or nil emulator core")
            }

            // Reset the MTKView's paused state
            mtlView?.isPaused = false
            mtlView?.enableSetNeedsDisplay = true

            // Request a redraw
            mtlView?.setNeedsDisplay()

            ILOG("Metal rendering pipeline reset successful")
        } catch {
            ELOG("Failed to reset Metal rendering pipeline: \(error)")
        }
    }

    /// Safely refreshes the GPU view without directly setting isPaused.
    /// This method should be called after the menu is dismissed to ensure proper rendering.
    public func safelyRefreshGPUView() {
        ILOG("Safely refreshing GPU view")

        // Make sure the view is visible
        view.alpha = 1.0
        view.isHidden = false

        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.safelyRefreshGPUView()
            }
            return
        }

        // Reset frame count to force a fresh render
        frameCount = 0

        // Update input texture if needed
        do {
            if isTextureUpdateNeeded() {
                DLOG("Recreating input texture during GPU view refresh")
                try setupTexture()
                try updateInputTexture()
            } else {
                DLOG("Updating existing input texture during GPU view refresh")
                try updateInputTexture()
            }

            // Request a redraw through proper channels
            mtlView?.setNeedsDisplay()

            ILOG("GPU view refresh completed successfully")
        } catch {
            ELOG("Failed to refresh GPU view: \(error)")

            // If an error occurs, try to reset the rendering pipeline
            resetRenderingPipeline()
        }
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
