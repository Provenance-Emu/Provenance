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

@objc public class DolphinVulkanViewController: UIViewController {
    private var core: PVDolphinCoreBridge!
    private var metalView: UIView!
    private var dev: MTLDevice!
    private var isResuming: Bool = false

	@objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVDolphinCoreBridge) {
		super.init(nibName: nil, bundle: nil)
		self.core = core;

		// Use shared Metal device to avoid conflicts
		self.dev = MTLCreateSystemDefaultDevice()!

		// Disable Metal validation to test if rendering works despite buffer size warnings
		// This helps determine if it's a validation issue or actual rendering problem
		if let device = self.dev {
			// Note: Metal validation can only be disabled via environment variables or build settings
			// For now, we'll proceed with validation enabled but log the issue
			ILOG("Metal device created: \(device.name)")
		}

        metalView = CAMetalHostingView(frame: UIScreen.main.bounds, device: dev)

        // Configure hosting view/layer for Vulkan/Metal interop
        metalView.isUserInteractionEnabled = false
        metalView.contentMode = .scaleToFill
        metalView.translatesAutoresizingMaskIntoConstraints = false
        if let metalLayer = metalView.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = true
            metalLayer.allowsNextDrawableTimeout = false
            metalLayer.isOpaque = true
            metalLayer.presentsWithTransaction = false
            metalLayer.maximumDrawableCount = 3  // Triple buffering
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.colorspace = CGColorSpaceCreateDeviceRGB()
            metalLayer.contentsScale = UIScreen.main.scale
            let scale = UIScreen.main.scale
            metalLayer.drawableSize = CGSize(width: metalView.bounds.width * scale,
                                             height: metalView.bounds.height * scale)
        }

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
		// Critical: Clean up Metal resources to prevent GPU memory leaks
		ILOG("DolphinVulkanViewController deinit - cleaning up Metal resources")

		NotificationCenter.default.removeObserver(self)

        if let metalView = self.metalView {
            // Remove from superview to break retain cycles
            metalView.removeFromSuperview()
            self.metalView = nil
        }

		// Clear Metal device reference
		self.dev = nil
		self.core = nil

		ILOG("DolphinVulkanViewController deinit complete")
	}
	@objc public override func viewDidLoad() {
		ILOG("View Did Load\n")
		self.view=metalView;
        ILOG("Starting VM\n")
		core.startVM(self.view)

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
        var originalDrawableSize = CGSize.zero
        if let metalLayer = metalView.layer as? CAMetalLayer {
            originalDrawableSize = metalLayer.drawableSize
        }
		var wasHidden = false

		guard originalDrawableSize.width > 0 && originalDrawableSize.height > 0 else {
			ILOG("DolphinVulkanViewController resumeRendering - invalid drawable size, skipping")
			isResuming = false
			return
		}

		if let metalLayer = metalView.layer as? CAMetalLayer {
			metalLayer.removeAllAnimations()
			wasHidden = metalLayer.isHidden

			/// Hide layer immediately to prevent any flickering
			metalLayer.isHidden = true

			/// Drastically change drawable size to force complete swapchain destruction
			/// This mimics what happens during reset - forces Vulkan to completely destroy old swapchain
			metalLayer.drawableSize = CGSize(width: 1, height: 1)
		}

		/// Force immediate swapchain destruction
		core.refreshScreenSize()

		/// Wait longer to ensure swapchain is completely destroyed
		/// Multiple frame delays ensure Vulkan has processed the destruction
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			guard let self = self else { return }

			/// Restore correct drawable size - this triggers new swapchain creation
			if let metalLayer = self.metalView.layer as? CAMetalLayer {
				metalLayer.drawableSize = originalDrawableSize
			}

			/// Trigger swapchain recreation
			self.core.refreshScreenSize()

			/// Wait longer for swapchain to be fully recreated (similar to reset timing)
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
				guard let self = self else { return }

				/// Multiple refreshes to ensure swapchain is fully synchronized
				self.core.refreshScreenSize()

				DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
					guard let self = self else { return }

					self.core.refreshScreenSize()

					/// Now restore layer visibility after swapchain is fully recreated
					if let metalLayer = self.metalView.layer as? CAMetalLayer {
						metalLayer.isHidden = wasHidden
					}

					/// Final synchronization pass
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
						guard let self = self else { return }
						self.core.refreshScreenSize()
						self.isResuming = false
						/// Resume emulation now that the swapchain is synchronized
						self.core.setPauseEmulation(false)
						ILOG("DolphinVulkanViewController resumeRendering - complete swapchain recreation finished")
					}
				}
			}
		}
	}

	@objc public override func viewDidLayoutSubviews() {
        ILOG("View Size Changed\n")
		if let metalLayer = metalView.layer as? CAMetalLayer {
			let scale = UIScreen.main.scale
			metalLayer.contentsScale = scale
			metalLayer.drawableSize = CGSize(width: metalView.bounds.width * scale,
											height: metalView.bounds.height * scale)
		}
		core.refreshScreenSize()
	}
}

@available(iOS 13.0, tvOS 13.0, *)
@objc public final class CAMetalHostingView: UIView {
    private let deviceRef: MTLDevice
    override public class var layerClass: AnyClass { CAMetalLayer.self }

    init(frame: CGRect, device: MTLDevice) {
        self.deviceRef = device
        super.init(frame: frame)
        guard let metalLayer = self.layer as? CAMetalLayer else { return }
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
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
