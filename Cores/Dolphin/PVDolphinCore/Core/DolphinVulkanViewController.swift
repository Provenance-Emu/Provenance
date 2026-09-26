//
//  MTLViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 9/12/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import MetalKit
import QuartzCore
import os
import PVLogging
import PVShaders
import PVSettings
import Defaults
import PVPrimitives

@objc public class DolphinVulkanViewController: UIViewController {
    private var core: PVDolphinCoreBridge!
    /// Host view for the render layer - uses a separate CAMetalLayer sublayer like native DolphiniOS
    private var renderHostView: UIView!
    /// Standalone CAMetalLayer for Vulkan/Metal rendering - NOT the view's backing layer
    private var renderLayer: CAMetalLayer!
    private var dev: MTLDevice!
    private var filterObservationTask: Task<Void, Never>?
    private var isResuming: Bool = false
    /// Tracks whether the VM has been started - delays VM start until after first layout
    private var hasStartedVM: Bool = false
    /// Tracks last drawable size to detect changes
    private var lastDrawableSize: CGSize = .zero

	@objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVDolphinCoreBridge) {
		super.init(nibName: nil, bundle: nil)
		self.core = core;

		/// Use shared Metal device
		self.dev = MTLCreateSystemDefaultDevice()!
		ILOG("Metal device created: \(dev.name)")

        /// Create a regular host view - NOT using layerClass for CAMetalLayer
        /// This matches the native DolphiniOS architecture
        renderHostView = UIView(frame: .zero)
        renderHostView.backgroundColor = .black
        renderHostView.isUserInteractionEnabled = false
        renderHostView.translatesAutoresizingMaskIntoConstraints = false
        renderHostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        /// Create a standalone CAMetalLayer - NOT as the view's backing layer
        /// This gives us full control over the layer's frame and drawableSize
        renderLayer = CAMetalLayer()
        renderLayer.device = dev
        /// When shaders are on, Dolphin's Metal backend routes frames through
        /// `DolphinShaderPostProcessor` and blits into the drawable (on its fallback and
        /// shader toggle-off frames), which a framebuffer-only drawable does not allow.
        renderLayer.framebufferOnly = !isMetalBackend
        renderLayer.allowsNextDrawableTimeout = false
        renderLayer.isOpaque = true
        renderLayer.presentsWithTransaction = false
        renderLayer.maximumDrawableCount = 3  // Triple buffering
        renderLayer.pixelFormat = .bgra8Unorm
        renderLayer.colorspace = CGColorSpaceCreateDeviceRGB()
        renderLayer.contentsScale = UIScreen.main.scale
        /// NOTE: Do NOT set drawableSize here - wait until viewDidLayoutSubviews
        /// when we have correct bounds for the current orientation

        /// Add the metal layer as a sublayer of the host view's layer
        renderHostView.layer.addSublayer(renderLayer)

		/// Add observers for app lifecycle to handle pause/resume more reliably
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(appWillResignActive),
			name: UIApplication.willResignActiveNotification,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(appDidBecomeActive),
			name: UIApplication.didBecomeActiveNotification,
			object: nil
		)
	}
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	required init?(coder: NSCoder) {
		super.init(coder:coder)
	}

	deinit {
		/// Clean up Metal resources to prevent GPU memory leaks
		ILOG("DolphinVulkanViewController deinit - cleaning up Metal resources")

        filterObservationTask?.cancel()
        filterObservationTask = nil
		NotificationCenter.default.removeObserver(self)

        /// Clean up render layer
        renderLayer?.removeFromSuperlayer()
        renderLayer = nil

        if let hostView = self.renderHostView {
            hostView.removeFromSuperview()
            self.renderHostView = nil
        }

		/// Clear Metal device reference
		self.dev = nil
		self.core = nil

		ILOG("DolphinVulkanViewController deinit complete")
	}

	@objc public override func viewDidLoad() {
		ILOG("View Did Load\n")
		self.view = renderHostView
        super.viewDidLoad()

        /// Sync before the VM starts (first layout) so the first frame already honours the filter.
        syncShaderPostProcessing()
        startFilterPreferenceObservation()

        /// VM start is deferred to viewDidLayoutSubviews to ensure
        /// the CAMetalLayer has correct dimensions for the current orientation
        ILOG("VM start deferred until first layout\n")

		/// Observe window visibility changes to handle cases where sheets appear
		/// without triggering view lifecycle methods
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(windowDidBecomeKey),
			name: UIWindow.didBecomeKeyNotification,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(windowDidResignKey),
			name: UIWindow.didResignKeyNotification,
			object: nil
		)
	}

	@objc private func windowDidBecomeKey(_ notification: Notification) {
		/// Only handle if this is our window
		guard let window = notification.object as? UIWindow,
			  window == self.view.window else {
			return
		}
		ILOG("DolphinVulkanViewController windowDidBecomeKey - resuming rendering")
		resumeRendering()
	}

	@objc private func windowDidResignKey(_ notification: Notification) {
		/// Only handle if this is our window
		guard let window = notification.object as? UIWindow,
			  window == self.view.window else {
			return
		}
		ILOG("DolphinVulkanViewController windowDidResignKey")
	}

	@objc public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		resumeRendering()
	}

	@objc public override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		ILOG("DolphinVulkanViewController viewDidAppear")

		/// Additional check when view becomes fully visible
		/// This helps catch cases where viewWillAppear didn't properly synchronize
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			guard let self = self, self.view.window != nil else { return }
			/// Only resume if view is actually visible
			if self.view.window?.isKeyWindow == true {
				self.resumeRendering()
			}
		}
	}

	@objc public override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		ILOG("DolphinVulkanViewController viewWillDisappear - pausing rendering")
	}

	@objc private func appWillResignActive() {
		ILOG("DolphinVulkanViewController appWillResignActive")
	}

	@objc private func appDidBecomeActive() {
		ILOG("DolphinVulkanViewController appDidBecomeActive - resuming rendering")
		resumeRendering()
	}

	private func resumeRendering() {
		/// Prevent multiple simultaneous resume operations
		guard !isResuming else {
			ILOG("DolphinVulkanViewController resumeRendering - already resuming, skipping")
			return
		}

        let originalDrawableSize = renderLayer.drawableSize
		guard originalDrawableSize.width > 0 && originalDrawableSize.height > 0 else {
			ILOG("DolphinVulkanViewController resumeRendering - invalid drawable size, skipping")
			return
		}

        /// Metal rebuilds its surface from the layer's bounds, not its `drawableSize`
        /// (`Metal::Gfx::SetupSurface` / `GetSurfaceInfo` in MTLGfx.mm), and writes `drawableSize`
        /// back itself, so the Vulkan swapchain-rebuild dance below does nothing useful there. It
        /// only hides the layer, lets Dolphin's GPU thread grab a 1x1 drawable mid-frame, and
        /// toggles pause behind the pause menu's back. Flagging a resize is all Metal needs.
        guard !isMetalBackend else {
            ILOG("DolphinVulkanViewController resumeRendering - Metal: refreshing surface size only")
            core.refreshScreenSize()
            return
        }

		isResuming = true
		ILOG("DolphinVulkanViewController resumeRendering - forcing complete swapchain recreation")

        /// Pause emulation briefly to avoid presenting mid-recreation, then restore whatever the
        /// user had: resuming unconditionally would unpause a game under an open pause menu.
        let wasPaused = core.isEmulationPaused
        if !wasPaused {
            core.setPauseEmulation(true)
        }

        renderLayer.removeAllAnimations()
        let wasHidden = renderLayer.isHidden

        /// Hide layer immediately to prevent any flickering
        renderLayer.isHidden = true

        /// Drastically change drawable size to force complete swapchain destruction
        renderLayer.drawableSize = CGSize(width: 1, height: 1)

		/// Force immediate swapchain destruction
		core.refreshScreenSize()

		/// Wait to ensure swapchain is completely destroyed
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			guard let self = self else { return }

			/// Restore correct drawable size - this triggers new swapchain creation
            self.renderLayer.drawableSize = originalDrawableSize

			/// Trigger swapchain recreation
			self.core.refreshScreenSize()

			/// Wait for swapchain to be fully recreated
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
				guard let self = self else { return }

				self.core.refreshScreenSize()

				DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
					guard let self = self else { return }

					self.core.refreshScreenSize()

					/// Restore layer visibility after swapchain is fully recreated
                    self.renderLayer.isHidden = wasHidden

					/// Final synchronization pass
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
						guard let self = self else { return }
						self.core.refreshScreenSize()
						self.isResuming = false
                        if !wasPaused {
                            self.core.setPauseEmulation(false)
                        }
						ILOG("DolphinVulkanViewController resumeRendering - complete swapchain recreation finished")
					}
				}
			}
		}
	}

	@objc public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let viewBounds = view.bounds
        let scale = UIScreen.main.scale

        /// A transient zero-size layout (e.g. while the view leaves the window under a full-screen
        /// presentation) must not reach the running core: Dolphin sizes its backbuffer from the
        /// layer's bounds and would rebuild the surface at 0x0. Keep the last good surface.
        guard viewBounds.width > 0, viewBounds.height > 0 else {
            ILOG("viewDidLayoutSubviews: ignoring empty bounds \(viewBounds)")
            return
        }

        /// Update the standalone renderLayer to match view bounds and orientation
        /// This is critical for correct landscape rendering
        renderLayer.frame = viewBounds
        renderLayer.contentsScale = scale

        /// Calculate drawable size based on actual view bounds (respects current orientation)
        let drawableWidth = viewBounds.width * scale
        let drawableHeight = viewBounds.height * scale
        let newDrawableSize = CGSize(width: drawableWidth, height: drawableHeight)

        /// Only update if size actually changed
        if newDrawableSize != lastDrawableSize {
            renderLayer.drawableSize = newDrawableSize
            lastDrawableSize = newDrawableSize
            ILOG("viewDidLayoutSubviews: view.bounds=\(viewBounds), drawableSize=\(newDrawableSize)")
        }

        /// Start VM on first layout when layer has correct dimensions for current orientation
        if !hasStartedVM {
            hasStartedVM = true
            ILOG("Starting VM after first layout with bounds: \(viewBounds), drawableSize: \(renderLayer.drawableSize)\n")

            /// Set the render layer directly - this bypasses view.layer and uses our standalone layer
            /// with correct dimensions for the current orientation
            core.setRenderLayer(renderLayer)

            /// Start the VM (view parameter is now just for lifecycle management)
            core.startVM(renderHostView)

            /// Force a delayed swapchain refresh after VM initializes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                ILOG("Post-VM-start refresh: view.bounds=\(self.view.bounds), drawableSize=\(self.renderLayer.drawableSize)")
                self.core.refreshScreenSize()
            }
        } else {
            /// VM already running - just refresh screen size for the new dimensions
            core.refreshScreenSize()
        }
	}

    /// Dolphin's post-process hook exists only in its Metal backend (`gsPreference`), which
    /// this view controller also hosts; Vulkan ignores the routing flag.
    private var isMetalBackend: Bool {
        Int(core.gsPreference) == PVDolphinCoreOptions.GraphicsBackend.metal.rawValue
    }

    private func startFilterPreferenceObservation() {
        filterObservationTask = Task { [weak self] in
            for await _ in Defaults.updates([.metalFilterMode]) {
                await MainActor.run {
                    self?.syncShaderPostProcessing()
                }
            }
        }
    }

    /// Tells Dolphin's Metal backend whether to hand each frame to `DolphinShaderPostProcessor`.
    /// Off unless a shader actually resolves for GameCube/Wii (`none`, or an `auto` mode whose CRT
    /// slot is empty), so the default path keeps rendering straight into the drawable.
    @MainActor
    private func syncShaderPostProcessing() {
        let enabled = isMetalBackend && DolphinShaderPostProcessor.hasShaderToApply
        UserDefaults.standard.set(enabled, forKey: DolphinShaderPostProcessor.enabledDefaultsKey)
        ILOG("Dolphin shader post-processing \(enabled ? "enabled" : "disabled")")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
@objc public class PVMTLView: MTKView, MTKViewDelegate {
	private let queue: DispatchQueue = DispatchQueue.init(label: "renderQueue", qos: .userInteractive)
	private var hasSuspended: Bool = false
	private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
	private let context: CIContext
	private let commandQueue: MTLCommandQueue
	private var nearestNeighborRendering: Bool
	private var integerScaling: Bool
	private var checkForRedundantFrames: Bool
	private var currentScale: CGFloat = 1.0
	private var viewportOffset: CGPoint = CGPoint.zero
	private var lastDrawableSize: CGSize = CGSize.zero
	private var tNesScreen: CGAffineTransform = CGAffineTransform.identity
	private var gameScreenSize: CGSize = CGSize.zero
	private var resolutionFactor: Int8 = 1
	static private let elementLength: Int = 4
	static private let bitsPerComponent: Int = 8

	required init(coder: NSCoder) {
		let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
        // Check if the GPU is at least the A9
        let featureSet: MTLFeatureSet
    #if os(tvOS)
        featureSet = .tvOS_GPUFamily2_v2
    #else
        featureSet = .iOS_GPUFamily3_v2
    #endif
        guard dev.supportsFeatureSet(featureSet) else {
            assertionFailure("GPU doesn't support required MTL feature set.")
            fatalError("GPU doesn't support required MTL feature set.")
        }

		let commandQueue = dev.makeCommandQueue()!
		self.context = CIContext.init(mtlCommandQueue: commandQueue, options: [.cacheIntermediates: false])
		self.commandQueue = commandQueue
		self.nearestNeighborRendering = true
		self.checkForRedundantFrames = true
		self.integerScaling = true
		super.init(coder: coder)
	}

	init(gameScreenSize: CGSize, resolutionFactor: Int8) {
		let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
        // Check if the GPU is at least the A9
        let featureSet: MTLFeatureSet
    #if os(tvOS)
        featureSet = .tvOS_GPUFamily2_v2
    #else
        featureSet = .iOS_GPUFamily3_v4
    #endif
        guard dev.supportsFeatureSet(featureSet) else {
            assertionFailure("GPU doesn't support required MTL feature set.")
            fatalError("GPU doesn't support required MTL feature set.")
        }
		self.gameScreenSize = gameScreenSize
		self.resolutionFactor = resolutionFactor
		self.commandQueue = dev.makeCommandQueue()!
		self.context = CIContext.init(mtlCommandQueue: self.commandQueue, options: [.cacheIntermediates: false])
		self.nearestNeighborRendering = true
		self.checkForRedundantFrames = true
		self.integerScaling = true
		let videoBounds = CGRect( x: 0,
							y: 0,
							width: (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)),
							height: (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)))
		super.init(frame: videoBounds, device: dev)
		self.device = dev
		self.isPaused = true
		self.enableSetNeedsDisplay = false
		self.framebufferOnly = false
		self.delegate = self
		self.isOpaque = true
		self.clearsContextBeforeDrawing = true
		/* Dolphin Parameters */
		self.isUserInteractionEnabled=false;
		self.contentMode = .scaleToFill;
		self.colorPixelFormat = .bgra8Unorm;
		self.depthStencilPixelFormat = .depth32Float
		self.translatesAutoresizingMaskIntoConstraints = false
		self.setResolution()
		NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive), name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	func setResolution() {
		let scale:CGFloat = UIScreen.main.scale
		if (scale != 1.0) {
			self.layer.contentsScale = scale;
			self.layer.rasterizationScale = scale;
			self.contentScaleFactor = scale;
		}
		let screenBounds=UIScreen.main.bounds
		// Resize masks
		self.layer.anchorPoint=CGPoint(x: 0, y: 0)
		let gameFrameSize = CGRect(x: 0,
								   y: 0,
								   width: (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)),
								   height: (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)))
		self.layer.frame = gameFrameSize
		self.drawableSize=CGSize(width: gameFrameSize.width, height: gameFrameSize.height)

		self.autoResizeDrawable = true
		self.autoresizingMask  = [.flexibleHeight, .flexibleWidth,
								  .flexibleRightMargin,
								  .flexibleLeftMargin]
		// Adjust to Resolution Upscaled Vulkan Render
		let xScale = screenBounds.width / (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)) ;
		let yScale = screenBounds.height / (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)) ;
		self.layer.setAffineTransform(
			CGAffineTransform(scaleX: xScale,
							  y: yScale)
		)
		self.autoresizesSubviews = true
		self.contentMode = .scaleToFill
	}

	var buffer: [UInt32] = [UInt32]() {
		didSet {
			guard !self.checkForRedundantFrames || self.drawableSize != self.lastDrawableSize || !self.buffer.elementsEqual(oldValue)
			else {
				return
			}

			self.queue.async { [weak self] in
				self?.draw()
			}
		}
	}

	// MARK: - MTKViewDelegate
	public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
	}

	public func draw(in view: MTKView) {
	}

	@objc private func appResignedActive() {
		self.queue.suspend()
		self.hasSuspended = true
	}

	@objc private func appBecameActive() {
		if self.hasSuspended {
			self.queue.resume()
			self.hasSuspended = false
		}
	}
}

/// Applies the user's Provenance Metal screen filter to Dolphin's output.
///
/// Dolphin presents to its own `CAMetalLayer`, bypassing `PVMetalViewController`. iCube's Metal
/// backend (`Metal::Gfx::BindBackbuffer` / `PresentBackbuffer` in
/// `dolphin-ios/Source/Core/VideoBackends/Metal/MTLGfx.mm`) instead renders into an offscreen
/// target while `enabledDefaultsKey` is set in `UserDefaults.standard`, then looks this class up
/// by its Objective-C name and calls `shared`, `configureWithDevice:` and
/// `renderSource:commandBuffer:drawable:` on Dolphin's GPU thread before presenting the drawable.
/// All state here is touched only on that thread.
@objc(DOLShaderPostProcessor)
final class DolphinShaderPostProcessor: NSObject {
    /// `standardUserDefaults` key iCube's Metal backend reads to route frames through this class.
    static let enabledDefaultsKey = "shader_enabled"
    /// GameCube/Wii output CRT-era video, so an `auto` filter mode resolves to its CRT shader.
    private static let screenType: ScreenTypeObjC = .crt

    @objc static let shared = DolphinShaderPostProcessor()

    private let filterRenderer = PVMetalFilterRenderer()
    private var device: MTLDevice?
    private var blitter: MetalBlitter?
    private var configuredPixelFormat: MTLPixelFormat?

    override private init() {
        super.init()
    }

    @objc(configureWithDevice:)
    func configure(with device: MTLDevice) {
        guard self.device?.registryID != device.registryID else { return }
        self.device = device
        blitter = MetalBlitter(device: device)
        configuredPixelFormat = nil
    }

    /// Whether the user's filter setting resolves to a shader for GameCube/Wii output.
    /// Read from Dolphin's GPU thread as well as the main thread; it only reads `Defaults`.
    static var hasShaderToApply: Bool {
        MetalShaderManager.shared.currentFilterShader(for: screenType) != nil
    }

    /// Encodes `source` into `drawable`'s texture on `commandBuffer`. Dolphin presents the drawable
    /// right after this returns, so it must always be filled and must never be presented here.
    @objc(renderSource:commandBuffer:drawable:)
    func render(source: MTLTexture, commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable) {
        let target = drawable.texture
        let smoothing = Defaults[.imageSmoothing]
        if Self.hasShaderToApply,
           encodeFilter(source: source, target: target, commandBuffer: commandBuffer, smoothing: smoothing) {
            return
        }
        /// No shader resolved (e.g. the filter was switched off mid-frame) or pipeline creation
        /// failed: copy the frame through untouched so the drawable is never presented blank.
        if copyThrough(source: source, target: target, commandBuffer: commandBuffer) {
            return
        }
        let drawn = blitter?.encode(commandBuffer: commandBuffer,
                                    destinationTexture: target,
                                    sourceTexture: source,
                                    smoothing: smoothing,
                                    flipY: false) ?? false
        if !drawn {
            ELOG("Dolphin shader post-process: failed to copy frame into drawable")
        }
    }

    /// Straight texture copy, as iCube's own post-processor does. Dolphin sizes its post source from
    /// the drawable, so sizes and formats normally match; the Metal render layer is created
    /// non-framebuffer-only, which a blit into the drawable requires.
    private func copyThrough(source: MTLTexture, target: MTLTexture, commandBuffer: MTLCommandBuffer) -> Bool {
        guard !target.isFramebufferOnly,
              source.width == target.width,
              source.height == target.height,
              source.pixelFormat == target.pixelFormat,
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            return false
        }
        blit.copy(from: source,
                  sourceSlice: 0,
                  sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
                  to: target,
                  destinationSlice: 0,
                  destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        return true
    }

    private func encodeFilter(source: MTLTexture,
                              target: MTLTexture,
                              commandBuffer: MTLCommandBuffer,
                              smoothing: Bool) -> Bool {
        guard let device else { return false }
        if configuredPixelFormat != target.pixelFormat {
            /// Dolphin's Metal textures are top-left origin, like the drawable: no Y flip.
            filterRenderer.configure(device: device, pixelFormat: target.pixelFormat, flipYAxis: false)
            configuredPixelFormat = target.pixelFormat
        }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = target
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return false
        }
        let applied = filterRenderer.encode(with: encoder,
                                            texture: source,
                                            drawableSize: CGSize(width: target.width, height: target.height),
                                            sourceSize: CGSize(width: source.width, height: source.height),
                                            screenType: Self.screenType,
                                            smoothingEnabled: smoothing)
        encoder.endEncoding()
        return applied
    }
}

private final class MetalBlitter {
    private let device: MTLDevice
    private let library: MTLLibrary
    private let linearSampler: MTLSamplerState
    private let pointSampler: MTLSamplerState
    private var pipelineCache: [MTLPixelFormat: MTLRenderPipelineState] = [:]

    init?(device: MTLDevice) {
        self.device = device

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut pv_fullscreen_vertex(uint vertexID [[vertex_id]], constant bool &flipY [[buffer(0)]]) {
            const float2 positions[4] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };

            float2 texCoords[4] = {
                float2(0.0, 1.0),
                float2(1.0, 1.0),
                float2(0.0, 0.0),
                float2(1.0, 0.0)
            };

            if (flipY) {
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

        fragment float4 pv_fullscreen_fragment(VertexOut in [[stage_in]],
                                              texture2d<float> colorTexture [[texture(0)]],
                                              sampler colorSampler [[sampler(0)]]) {
            return colorTexture.sample(colorSampler, in.texCoord);
        }
        """

        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            ELOG("Failed to build blit shader library: \(error)")
            return nil
        }

        let linearDescriptor = MTLSamplerDescriptor()
        linearDescriptor.minFilter = .linear
        linearDescriptor.magFilter = .linear

        let pointDescriptor = MTLSamplerDescriptor()
        pointDescriptor.minFilter = .nearest
        pointDescriptor.magFilter = .nearest

        guard
            let linearSampler = device.makeSamplerState(descriptor: linearDescriptor),
            let pointSampler = device.makeSamplerState(descriptor: pointDescriptor)
        else {
            ELOG("Failed to create sampler states for blitter")
            return nil
        }

        self.linearSampler = linearSampler
        self.pointSampler = pointSampler
    }

    func encode(commandBuffer: MTLCommandBuffer,
                destinationTexture: MTLTexture,
                sourceTexture: MTLTexture,
                smoothing: Bool,
                flipY: Bool) -> Bool {
        guard let pipeline = pipeline(for: destinationTexture.pixelFormat) else {
            return false
        }

        guard let descriptor = makeRenderPassDescriptor(for: destinationTexture),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return false
        }

        encoder.setRenderPipelineState(pipeline)
        var localFlip = flipY
        encoder.setVertexBytes(&localFlip, length: MemoryLayout<Bool>.size, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentSamplerState(smoothing ? linearSampler : pointSampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        return true
    }

    private func pipeline(for pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        if let cached = pipelineCache[pixelFormat] {
            return cached
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.vertexFunction = library.makeFunction(name: "pv_fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "pv_fullscreen_fragment")

        do {
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            pipelineCache[pixelFormat] = pipeline
            return pipeline
        } catch {
            ELOG("Failed to create blit pipeline: \(error)")
            return nil
        }
    }

    private func makeRenderPassDescriptor(for texture: MTLTexture) -> MTLRenderPassDescriptor? {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .dontCare
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
}
