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
import os
import PVLogging

@objc public class DolphinVulkanViewController: UIViewController {
	private var core: PVDolphinCoreBridge!
	private var metalView: MTKView!
	private var dev: MTLDevice!

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
		
		metalView = MTKView(frame: UIScreen.main.bounds, device: dev)
		
		// Configure MTKView for Vulkan/Metal interop
		metalView.isUserInteractionEnabled = false
		metalView.contentMode = .scaleToFill
		metalView.colorPixelFormat = .bgra8Unorm
		metalView.depthStencilPixelFormat = .depth32Float
		metalView.translatesAutoresizingMaskIntoConstraints = false
		metalView.preferredFramesPerSecond = 60  // Reduced from 120 to prevent GPU overload
		
		// Critical: Prevent MTKView from interfering with Vulkan rendering
		metalView.isPaused = true
		metalView.enableSetNeedsDisplay = false
		metalView.autoResizeDrawable = false  // Let Vulkan control drawable size
		metalView.framebufferOnly = true      // Optimize for rendering only
		metalView.delegate = nil              // No MTKView delegate to avoid conflicts
		
		// Ensure Metal layer is properly configured for Vulkan
		if let metalLayer = metalView.layer as? CAMetalLayer {
			metalLayer.framebufferOnly = true
			metalLayer.allowsNextDrawableTimeout = false
			metalLayer.maximumDrawableCount = 3  // Triple buffering
		}
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
		
		if let metalView = self.metalView {
			// Stop any ongoing rendering
			metalView.isPaused = true
			metalView.delegate = nil
			
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
	}
	@objc public override func viewDidLayoutSubviews() {
        ILOG("View Size Changed\n")
		core.refreshScreenSize()
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
