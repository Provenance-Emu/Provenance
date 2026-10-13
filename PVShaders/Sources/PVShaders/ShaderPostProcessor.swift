//
//  ShaderPostProcessor.swift
//  PVShaders
//
//  Applies the selected filter for cores that present from their own render
//  thread (Dolphin, native PPSSPP) instead of through PVMetalViewController.
//

import CoreGraphics
import Foundation
import Metal
import PVPrimitives
import PVSettings

/// Draws a `ResolvedShader` (native or library) over a core's frame.
///
/// The main thread publishes what to draw with `update(_:smoothing:)` whenever the
/// selection or parameters change; the core's render thread calls `render`. All
/// GPU state is used only by `render`, which must not run on two threads at once.
public final class ShaderPostProcessor: @unchecked Sendable {
    private let device: MTLDevice
    private let lock = NSLock()
    private var resolved: ResolvedShader?
    private var smoothing = false

    private let nativeRenderer = PVMetalFilterRenderer()
    private var nativePixelFormat: MTLPixelFormat?
    private let slangRenderer: SlangFilterRenderer

    public init(device: MTLDevice) {
        self.device = device
        slangRenderer = SlangFilterRenderer(device: device)
    }

    /// Sets the filter to draw (`nil` for none). Starts compiling a library preset
    /// right away so it is ready by the time frames ask for it.
    public func update(_ resolved: ResolvedShader?, smoothing: Bool) {
        lock.withLock {
            self.resolved = resolved
            self.smoothing = smoothing
        }
        if let entry = resolved?.entry, entry.id.kind == .slang {
            slangRenderer.prepare(entry)
        } else if slangRenderer.loadedID != nil {
            slangRenderer.unload()
        }
    }

    /// Whether a filter is selected (it may still be compiling).
    public var hasFilter: Bool { lock.withLock { resolved != nil } }

    /// Encodes the filter from `source` into `contentRect` of `target` (default: all of it),
    /// clearing the rest to black. Returns `false` when nothing was drawn (no filter, or a
    /// library preset still compiling), so the caller must fill `target` itself.
    ///
    /// - Parameter sourceIsBottomUp: the frame has an OpenGL (bottom-left) origin.
    public func render(source: MTLTexture,
                       target: MTLTexture,
                       commandBuffer: MTLCommandBuffer,
                       contentRect: CGRect? = nil,
                       screenType: ScreenTypeObjC = .crt,
                       sourceIsBottomUp: Bool = false) -> Bool {
        let (resolved, smoothing) = lock.withLock { (self.resolved, self.smoothing) }
        guard let resolved else { return false }
        let rect = contentRect ?? CGRect(x: 0, y: 0, width: target.width, height: target.height)
        if let option = resolved.entry.id.nativeOption {
            return renderNative(option, source: source, target: target, commandBuffer: commandBuffer,
                                rect: rect, screenType: screenType, smoothing: smoothing, flip: sourceIsBottomUp)
        }
        guard slangRenderer.prepare(resolved.entry) else { return false }
        slangRenderer.applyParameters(revision: resolved.revision,
                                      value: { resolved.values[$0.name] ?? $0.initial },
                                      parameters: resolved.entry.parameters)
        return slangRenderer.render(source: source, commandBuffer: commandBuffer, target: target,
                                    contentRect: rect, flipVertically: sourceIsBottomUp, linear: smoothing)
    }

    private func renderNative(_ option: MetalFilterSelectionOption,
                              source: MTLTexture,
                              target: MTLTexture,
                              commandBuffer: MTLCommandBuffer,
                              rect: CGRect,
                              screenType: ScreenTypeObjC,
                              smoothing: Bool,
                              flip: Bool) -> Bool {
        if nativePixelFormat != target.pixelFormat {
            nativeRenderer.configure(device: device, pixelFormat: target.pixelFormat, flipYAxis: flip)
            nativePixelFormat = target.pixelFormat
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.setViewport(MTLViewport(originX: Double(rect.minX), originY: Double(rect.minY),
                                        width: Double(rect.width), height: Double(rect.height),
                                        znear: 0, zfar: 1))
        let applied = nativeRenderer.encode(with: encoder,
                                            texture: source,
                                            drawableSize: rect.size,
                                            sourceSize: CGSize(width: source.width, height: source.height),
                                            screenType: screenType,
                                            smoothingEnabled: smoothing,
                                            setViewport: false,
                                            filter: option)
        encoder.endEncoding()
        return applied
    }
}
