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

class MTLViewController: UIViewController {

}

extension MTLViewController: PVRenderDelegate {
	func startRenderingOnAlternateThread() {

	}

	func didRenderFrameOnAlternateThread() {

	}
}

class PVMTLView: MTKView, MTKViewDelegate {
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
	static private let elementLength: Int = 4
	static private let bitsPerComponent: Int = 8
	static private let imageSize: CGSize = CGSize(width: 480, height: 640)

	required init(coder: NSCoder) {
		let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
		let commandQueue = dev.makeCommandQueue()!
		self.context = CIContext.init(mtlCommandQueue: commandQueue, options: [.cacheIntermediates: false])
		self.commandQueue = commandQueue
		self.nearestNeighborRendering = true
		self.checkForRedundantFrames = true
		self.integerScaling = true
		super.init(coder: coder)
		self.device = dev
		self.autoResizeDrawable = true
		self.drawableSize = PVMTLView.imageSize
		self.isPaused = true
		self.enableSetNeedsDisplay = false
		self.framebufferOnly = false
		self.delegate = self
		self.isOpaque = true
		self.clearsContextBeforeDrawing = false
		NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive), name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
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

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let exactScale: CGFloat = size.width / CGFloat(640)
		self.currentScale = self.integerScaling ? floor(exactScale) : exactScale
		self.viewportOffset = self.integerScaling ? CGPoint(x: (size.width - (CGFloat(640) * self.currentScale)) * 0.5, y: (size.height - (CGFloat(480) * self.currentScale)) * 0.5) : CGPoint.zero

		let t1: CGAffineTransform = CGAffineTransform(scaleX: self.currentScale, y: self.currentScale)
		let t2: CGAffineTransform = self.integerScaling ? CGAffineTransform(translationX: self.viewportOffset.x, y: self.viewportOffset.y) : CGAffineTransform.identity
		self.tNesScreen = t1.concatenating(t2)
	}

	func draw(in view: MTKView) {
		guard let safeCurrentDrawable = self.currentDrawable,
			  let safeCommandBuffer = self.commandQueue.makeCommandBuffer()
		else {
			return
		}

		let image: CIImage
		let baseImage: CIImage = CIImage(bitmapData: NSData(bytes: &self.buffer, length: 640 * 480 * PVMTLView.elementLength) as Data, bytesPerRow: 640 * PVMTLView.elementLength, size: PVMTLView.imageSize, format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)

		if self.nearestNeighborRendering {
			image = baseImage.samplingNearest().transformed(by: self.tNesScreen)
		} else {
			image = baseImage.transformed(by: self.tNesScreen)
		}

		let renderDestination = CIRenderDestination(width: Int(self.drawableSize.width), height: Int(self.drawableSize.height), pixelFormat: self.colorPixelFormat, commandBuffer: safeCommandBuffer) {
			() -> MTLTexture in return safeCurrentDrawable.texture
		}

		do {
			_ = try self.context.startTask(toRender: image, to: renderDestination)
		} catch {
			os_log("%@", error.localizedDescription)
		}

		safeCommandBuffer.present(safeCurrentDrawable)
		safeCommandBuffer.commit()

		self.lastDrawableSize = self.drawableSize
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
