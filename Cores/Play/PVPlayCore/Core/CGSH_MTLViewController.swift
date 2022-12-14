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

@objc public class CGSH_MTLViewController: UIViewController {
    private var metalView: PVMTLView!
    
    @objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat) {
        super.init(nibName: nil, bundle: nil)
        metalView = PVMTLView(gameScreenSize: CGSize(width: videoWidth, height: videoHeight),
                              resolutionFactor: resFactor);
        self.view=metalView;
    }
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
    }
    required init?(coder: NSCoder) {
        super.init(coder:coder);
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
        self.autoResizeDrawable = true
        self.autoresizingMask  = [.flexibleHeight, .flexibleWidth,
                                  .flexibleRightMargin,
                                  .flexibleLeftMargin]
        self.layer.anchorPoint=CGPoint(x: 0, y: 0)
        let gameFrameSize = CGRect(x: 0,
                                   y: 0,
                                   width: (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)),
                                   height: (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)))
        self.layer.frame = gameFrameSize
        // Adjust to Resolution Upscaled Vulkan Render
        let xScale = screenBounds.width / (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)) ;
        let yScale = screenBounds.height / (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)) ;
        self.layer.setAffineTransform(
            CGAffineTransform(scaleX: xScale,
                              y: yScale)
        )
        self.drawableSize=CGSize(width: gameFrameSize.width, height: gameFrameSize.height)
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
