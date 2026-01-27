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
    private var filteredView: MTKView!
    private var commandQueue: MTLCommandQueue?
    private let metalFilterRenderer = PVMetalFilterRenderer()
    private var blitter: MetalBlitter?
    private var filterObservationTask: Task<Void, Never>?
    private var filterMode: MetalFilterModeOption = Defaults[.metalFilterMode]
    private var smoothingEnabled: Bool = Defaults[.imageSmoothing]
    private var currentFilterPixelFormat: MTLPixelFormat?
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

        commandQueue = dev.makeCommandQueue()
        blitter = MetalBlitter(device: dev)

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
        renderLayer.framebufferOnly = true
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

        filteredView = MTKView(frame: .zero, device: dev)
        filteredView.translatesAutoresizingMaskIntoConstraints = false
        filteredView.isUserInteractionEnabled = false
        filteredView.isPaused = true
        filteredView.enableSetNeedsDisplay = false
        filteredView.framebufferOnly = true
        filteredView.autoResizeDrawable = true
        filteredView.colorPixelFormat = .bgra8Unorm

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
        commandQueue = nil
        blitter = nil
		self.dev = nil
		self.core = nil

		ILOG("DolphinVulkanViewController deinit complete")
	}

	@objc public override func viewDidLoad() {
		ILOG("View Did Load\n")
		self.view = renderHostView
        super.viewDidLoad()

        installFilteredView()
        configureFilterRendererIfNeeded(reason: "viewDidLoad")
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

		isResuming = true
		ILOG("DolphinVulkanViewController resumeRendering - forcing complete swapchain recreation")

		/// Pause emulation briefly to avoid presenting mid-recreation
		core.setPauseEmulation(true)

        /// Get current state before manipulation
        let originalDrawableSize = renderLayer.drawableSize
		var wasHidden = renderLayer.isHidden

		guard originalDrawableSize.width > 0 && originalDrawableSize.height > 0 else {
			ILOG("DolphinVulkanViewController resumeRendering - invalid drawable size, skipping")
			isResuming = false
			return
		}

        renderLayer.removeAllAnimations()
        wasHidden = renderLayer.isHidden

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
						self.core.setPauseEmulation(false)
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

        if let displayLayer = filteredView.layer as? CAMetalLayer {
            filteredView.frame = viewBounds
            filteredView.drawableSize = newDrawableSize
            displayLayer.drawableSize = newDrawableSize
        }

        /// Start VM on first layout when layer has correct dimensions for current orientation
        if !hasStartedVM {
            /// Verify we have valid dimensions before starting
            guard viewBounds.width > 0 && viewBounds.height > 0 else {
                ILOG("viewDidLayoutSubviews: skipping VM start - invalid bounds")
                return
            }

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

    private func installFilteredView() {
        guard filteredView.superview == nil else { return }
        renderHostView.addSubview(filteredView)
        NSLayoutConstraint.activate([
            filteredView.topAnchor.constraint(equalTo: renderHostView.topAnchor),
            filteredView.bottomAnchor.constraint(equalTo: renderHostView.bottomAnchor),
            filteredView.leadingAnchor.constraint(equalTo: renderHostView.leadingAnchor),
            filteredView.trailingAnchor.constraint(equalTo: renderHostView.trailingAnchor)
        ])
        filteredView.backgroundColor = .black
    }

    private func startFilterPreferenceObservation() {
        if #available(iOS 15.0, tvOS 15.0, *) {
            filterObservationTask = Task { [weak self] in
                for await _ in Defaults.updates([.metalFilterMode, .imageSmoothing]) {
                    await MainActor.run {
                        self?.reloadFilterPreferences()
                    }
                }
            }
        }
    }

    @MainActor
    private func reloadFilterPreferences() {
        filterMode = Defaults[.metalFilterMode]
        smoothingEnabled = Defaults[.imageSmoothing]
    }

    private func configureFilterRendererIfNeeded(reason: String) {
        configureFilterRendererIfNeeded(pixelFormat: filteredView.colorPixelFormat, reason: reason)
    }

    private func configureFilterRendererIfNeeded(pixelFormat: MTLPixelFormat, reason: String) {
        guard let device = dev else { return }
        guard currentFilterPixelFormat != pixelFormat else { return }
        metalFilterRenderer.configure(device: device,
                                      pixelFormat: pixelFormat,
                                      flipYAxis: false)
        currentFilterPixelFormat = pixelFormat
        ILOG("Configured Metal filter renderer (\(reason))")
    }

    private func presentFilteredDrawable(baseDrawable: CAMetalDrawable,
                                         timing: FilterPresentationTiming) {
        guard
            let displayLayer = filteredView.layer as? CAMetalLayer,
            let displayDrawable = displayLayer.nextDrawable(),
            let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            presentBaseDrawable(baseDrawable, timing: timing)
            return
        }

        let displayTexture = displayDrawable.texture
        let sourceTexture = baseDrawable.texture

        var filterApplied = false
        if filterMode != .none {
            configureFilterRendererIfNeeded(pixelFormat: displayTexture.pixelFormat, reason: "frame")
            let descriptor = makeRenderPassDescriptor(for: displayTexture)
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
                let drawableSize = CGSize(width: displayTexture.width, height: displayTexture.height)
                let textureSourceSize = CGSize(width: max(sourceTexture.width, 1),
                                               height: max(sourceTexture.height, 1))
                let fallbackSize = core?.preferredDrawableSize ?? textureSourceSize
                let sourceSize = (sourceTexture.width > 0 && sourceTexture.height > 0) ? textureSourceSize : fallbackSize
                let screenType: ScreenTypeObjC = .crt
                filterApplied = metalFilterRenderer.encode(with: encoder,
                                                           texture: sourceTexture,
                                                           drawableSize: drawableSize,
                                                           sourceSize: sourceSize,
                                                           screenType: screenType,
                                                           smoothingEnabled: smoothingEnabled)
                encoder.endEncoding()
            }
        }

        if !filterApplied {
            guard blitter?.encode(commandBuffer: commandBuffer,
                                  destinationTexture: displayTexture,
                                  sourceTexture: sourceTexture,
                                  smoothing: smoothingEnabled,
                                  flipY: false) == true else {
                commandBuffer.commit()
                presentBaseDrawable(baseDrawable, timing: timing)
                return
            }
        }

        schedulePresent(on: commandBuffer, drawable: displayDrawable, timing: timing)
        commandBuffer.commit()
        presentBaseDrawable(baseDrawable, timing: timing)
    }

    private func makeRenderPassDescriptor(for texture: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return descriptor
    }

    private func schedulePresent(on commandBuffer: MTLCommandBuffer,
                                 drawable: CAMetalDrawable,
                                 timing: FilterPresentationTiming) {
        switch timing {
        case .immediate:
            commandBuffer.present(drawable)
        case .atTime(let time):
            commandBuffer.present(drawable, atTime: time)
        case .afterMinimumDuration(let duration):
            commandBuffer.present(drawable, afterMinimumDuration: duration)
        }
    }

    private func presentBaseDrawable(_ drawable: CAMetalDrawable,
                                     timing: FilterPresentationTiming) {
        switch timing {
        case .immediate:
            drawable.present()
        case .atTime(let time):
            drawable.present(at: time)
        case .afterMinimumDuration(let duration):
            drawable.present(afterMinimumDuration: duration)
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
fileprivate final class DolphinFilterHostingView: UIView {
    private let deviceRef: MTLDevice
    weak var filterDelegate: FilterDrawableDelegate? {
        didSet {
            interceptingLayer?.filterDelegate = filterDelegate
        }
    }

    private var interceptingLayer: FilterInterceptingLayer? {
        return layer as? FilterInterceptingLayer
    }

    override public class var layerClass: AnyClass { FilterInterceptingLayer.self }

    init(frame: CGRect, device: MTLDevice) {
        self.deviceRef = device
        super.init(frame: frame)
        guard let metalLayer = interceptingLayer else { return }
        metalLayer.device = deviceRef
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.isOpaque = true
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
        metalLayer.allowsNextDrawableTimeout = false
        metalLayer.maximumDrawableCount = 3
        metalLayer.colorspace = CGColorSpaceCreateDeviceRGB()
        let scale = UIScreen.main.scale
        contentScaleFactor = scale
        metalLayer.contentsScale = scale
        /// Only set drawableSize if we have valid bounds
        /// Otherwise defer to viewDidLayoutSubviews when bounds are available
        if bounds.width > 0 && bounds.height > 0 {
            metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PVDolphinCoreBridge {
    var preferredDrawableSize: CGSize {
        let factor = max(Int(resFactor), 1)
        let baseWidth = max(Int(videoWidth), 1)
        let baseHeight = max(Int(videoHeight), 1)
        let width = max(CGFloat(baseWidth * factor), 1)
        let height = max(CGFloat(baseHeight * factor), 1)
        return CGSize(width: width, height: height)
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

extension DolphinVulkanViewController: FilterDrawableDelegate {
    fileprivate func filterDrawable(baseDrawable: CAMetalDrawable, timing: FilterPresentationTiming) {
        presentFilteredDrawable(baseDrawable: baseDrawable, timing: timing)
    }
}

fileprivate enum FilterPresentationTiming {
    case immediate
    case atTime(CFTimeInterval)
    case afterMinimumDuration(CFTimeInterval)
}

fileprivate protocol FilterDrawableDelegate: AnyObject {
    func filterDrawable(baseDrawable: CAMetalDrawable, timing: FilterPresentationTiming)
}

private final class FilterInterceptingLayer: CAMetalLayer {
    weak var filterDelegate: FilterDrawableDelegate?

    override func nextDrawable() -> CAMetalDrawable? {
        guard let drawable = super.nextDrawable() else {
            return nil
        }
        guard let filterDelegate else {
            return drawable
        }
        return FilterProxyDrawable(baseDrawable: drawable, delegate: filterDelegate)
    }
}

private final class FilterProxyDrawable: NSObject, CAMetalDrawable {
    private let baseDrawable: CAMetalDrawable
    private weak var delegate: FilterDrawableDelegate?

    init(baseDrawable: CAMetalDrawable, delegate: FilterDrawableDelegate) {
        self.baseDrawable = baseDrawable
        self.delegate = delegate
    }

    var texture: MTLTexture { baseDrawable.texture }
    var layer: CAMetalLayer { baseDrawable.layer }
    var presentedTime: CFTimeInterval { baseDrawable.presentedTime }
    var drawableID: Int { Int(baseDrawable.drawableID) }

    func addPresentedHandler(_ block: @escaping MTLDrawablePresentedHandler) {
        baseDrawable.addPresentedHandler(block)
    }

    func present() {
        delegate?.filterDrawable(baseDrawable: baseDrawable, timing: .immediate)
    }

    func present(afterMinimumDuration duration: CFTimeInterval) {
        delegate?.filterDrawable(baseDrawable: baseDrawable, timing: .afterMinimumDuration(duration))
    }

    func present(at presentationTime: CFTimeInterval) {
        delegate?.filterDrawable(baseDrawable: baseDrawable, timing: .atTime(presentationTime))
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
