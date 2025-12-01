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
import PVShaders
import PVSettings
import Defaults
import PVPrimitives

@objc public class PPSSPPVulkanViewController: UIViewController {
	private var core: PVPPSSPPCoreBridge!
	private var metalView: PPSSPPFilterHostingView!
	private var dev: MTLDevice!
    private var filteredView: MTKView!
    private var commandQueue: MTLCommandQueue?
    private let metalFilterRenderer = PVMetalFilterRenderer()
    private var blitter: PPSSPPMetalBlitter?
    private var filterObservationTask: Task<Void, Never>?
    private var filterMode: MetalFilterModeOption = Defaults[.metalFilterMode]
    private var smoothingEnabled: Bool = Defaults[.imageSmoothing]
    private var currentFilterPixelFormat: MTLPixelFormat?

    @objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVPPSSPPCoreBridge) {
		super.init(nibName: nil, bundle: nil)
		self.core = core;
		self.dev = MTLCreateSystemDefaultDevice()!
        commandQueue = dev.makeCommandQueue()
        blitter = PPSSPPMetalBlitter(device: dev)

		metalView = PPSSPPFilterHostingView(frame: UIScreen.main.bounds, device: dev)
        metalView.filterDelegate = self
		metalView.isUserInteractionEnabled = false
		metalView.contentMode = .scaleToFill
		metalView.translatesAutoresizingMaskIntoConstraints = false

        if let metalLayer = metalView.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = true
            metalLayer.allowsNextDrawableTimeout = false
            metalLayer.isOpaque = true
            metalLayer.presentsWithTransaction = false
            metalLayer.maximumDrawableCount = 3
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.colorspace = CGColorSpaceCreateDeviceRGB()
            let scale = UIScreen.main.scale
            metalLayer.drawableSize = CGSize(width: metalView.bounds.width * scale,
                                             height: metalView.bounds.height * scale)
        }

        filteredView = MTKView(frame: UIScreen.main.bounds, device: dev)
        filteredView.translatesAutoresizingMaskIntoConstraints = false
        filteredView.isUserInteractionEnabled = false
        filteredView.isPaused = true
        filteredView.enableSetNeedsDisplay = false
        filteredView.framebufferOnly = true
        filteredView.autoResizeDrawable = true
        filteredView.colorPixelFormat = .bgra8Unorm
	}

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

	}
	required init?(coder: NSCoder) {
		super.init(coder:coder);
	}

    deinit {
        filterObservationTask?.cancel()
        filterObservationTask = nil
        commandQueue = nil
        blitter = nil
	}

	@objc public override func viewDidLoad() {
		NSLog("View Did Load\n")
		self.view = metalView
        super.viewDidLoad()

        installFilteredView()
        configureFilterRendererIfNeeded(reason: "viewDidLoad")
        startFilterPreferenceObservation()

		NSLog("Starting VM\n")
        core.startVM(metalView)
	}

	@objc public override func viewDidLayoutSubviews() {
		NSLog("View Size Changed\n")
        if let metalLayer = metalView.layer as? CAMetalLayer {
            let scale = UIScreen.main.scale
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(width: metalView.bounds.width * scale,
                                             height: metalView.bounds.height * scale)
        }
        if let displayLayer = filteredView.layer as? CAMetalLayer {
            let scale = UIScreen.main.scale
            filteredView.frame = metalView.bounds
            filteredView.drawableSize = CGSize(width: metalView.bounds.width * scale,
                                              height: metalView.bounds.height * scale)
            displayLayer.drawableSize = filteredView.drawableSize
        }
        core.refreshScreenSize()
	}

    private func installFilteredView() {
        guard filteredView.superview == nil else { return }
        metalView.addSubview(filteredView)
        NSLayoutConstraint.activate([
            filteredView.topAnchor.constraint(equalTo: metalView.topAnchor),
            filteredView.bottomAnchor.constraint(equalTo: metalView.bottomAnchor),
            filteredView.leadingAnchor.constraint(equalTo: metalView.leadingAnchor),
            filteredView.trailingAnchor.constraint(equalTo: metalView.trailingAnchor)
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
        guard currentFilterPixelFormat != pixelFormat else { return }
        metalFilterRenderer.configure(device: dev,
                                      pixelFormat: pixelFormat,
                                      flipYAxis: false)
        currentFilterPixelFormat = pixelFormat
        NSLog("Configured PPSSPP Metal filter renderer (\(reason))")
    }

    private func presentFilteredDrawable(baseDrawable: CAMetalDrawable,
                                         timing: PPSSPPFilterPresentationTiming) {
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
                                 timing: PPSSPPFilterPresentationTiming) {
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
                                     timing: PPSSPPFilterPresentationTiming) {
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

fileprivate enum PPSSPPFilterPresentationTiming {
    case immediate
    case atTime(CFTimeInterval)
    case afterMinimumDuration(CFTimeInterval)
}

fileprivate protocol PPSSPPFilterDrawableDelegate: AnyObject {
    func filterDrawable(baseDrawable: CAMetalDrawable, timing: PPSSPPFilterPresentationTiming)
}

fileprivate final class PPSSPPFilterInterceptingLayer: CAMetalLayer {
    weak var filterDelegate: PPSSPPFilterDrawableDelegate?

    override func nextDrawable() -> CAMetalDrawable? {
        guard let drawable = super.nextDrawable() else {
            return nil
        }
        guard let filterDelegate else {
            return drawable
        }
        return PPSSPPFilterProxyDrawable(baseDrawable: drawable, delegate: filterDelegate)
    }
}

fileprivate final class PPSSPPFilterProxyDrawable: NSObject, CAMetalDrawable {
    private let baseDrawable: CAMetalDrawable
    private weak var delegate: PPSSPPFilterDrawableDelegate?

    init(baseDrawable: CAMetalDrawable, delegate: PPSSPPFilterDrawableDelegate) {
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

fileprivate final class PPSSPPFilterHostingView: UIView {
    private let deviceRef: MTLDevice
    weak var filterDelegate: PPSSPPFilterDrawableDelegate? {
        didSet {
            interceptingLayer?.filterDelegate = filterDelegate
        }
    }

    private var interceptingLayer: PPSSPPFilterInterceptingLayer? {
        return layer as? PPSSPPFilterInterceptingLayer
    }

    override class var layerClass: AnyClass { PPSSPPFilterInterceptingLayer.self }

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
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate final class PPSSPPMetalBlitter {
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
            ELOG("Failed to build PPSSPP blit shader library: \(error)")
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
            ELOG("Failed to create sampler states for PPSSPP blitter")
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
            ELOG("Failed to create PPSSPP blit pipeline: \(error)")
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

private extension PVPPSSPPCoreBridge {
    var preferredDrawableSize: CGSize {
        let factor = max(Int(resFactor), 1)
        let baseWidth = max(Int(videoWidth), 1)
        let baseHeight = max(Int(videoHeight), 1)
        let width = max(CGFloat(baseWidth * factor), 1)
        let height = max(CGFloat(baseHeight * factor), 1)
        return CGSize(width: width, height: height)
    }
}

extension PPSSPPVulkanViewController: PPSSPPFilterDrawableDelegate {
    fileprivate func filterDrawable(baseDrawable: CAMetalDrawable, timing: PPSSPPFilterPresentationTiming) {
        presentFilteredDrawable(baseDrawable: baseDrawable, timing: timing)
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
		featureSet = .iOS_GPUFamily3_v2
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
							height: (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)));
		super.init(frame: videoBounds, device: dev)
		self.device = dev
		self.isPaused = true
		self.enableSetNeedsDisplay = false
		self.framebufferOnly = false
		self.delegate = self
		self.isOpaque = true
		self.clearsContextBeforeDrawing = true
		/* PPSSPP Parameters */
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
