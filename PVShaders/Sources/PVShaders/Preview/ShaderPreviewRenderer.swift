//
//  ShaderPreviewRenderer.swift
//  PVShaders
//
//  Renders one catalog filter over a preview source into an offscreen image.
//

import CoreGraphics
import Foundation
import Metal
import PVLogging
import PVPrimitives
import PVSettings
import PVSlangRuntime

/// Why a preview could not be produced.
public enum ShaderPreviewError: Error, Equatable {
    case invalidSize
    case commandQueueUnavailable
    case textureCreationFailed
    /// The filter has no slang directory and is not a native filter either.
    case unsupportedFilter
    /// The native filter's pipeline could not be built.
    case pipelineUnavailable
    /// The slang preset compiled to no passes.
    case emptyChain
    case gpuFailure
    case imageConversionFailed
}

/// Draws filter previews on its own command queue.
///
/// A preview never touches the live renderer or the user's selection: native
/// filters run through a private `PVMetalFilterRenderer`, slang presets through
/// private `FilterChain`s. Native filters read their parameters from `Defaults`
/// (as the live renderer does); slang parameters come from the `parameterValue`
/// closure.
///
/// Compiled chains without history or feedback are kept for reuse (at most
/// `maxCachedChains`, least recently used first out). A chain is checked out while it renders, so two concurrent
/// renders of the same preset never share one.
public actor ShaderPreviewRenderer {
    /// Compiled slang chains kept between renders.
    public static let maxCachedChains = 4
    /// Largest preview edge accepted, in pixels.
    public static let maxEdge = 4096

    private static let pixelFormat = MTLPixelFormat.bgra8Unorm
    private static let bytesPerPixel = 4

    /// Unchecked box so a chain compiled on a background queue can enter the actor.
    private struct ChainBox: @unchecked Sendable {
        let chain: FilterChain
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let native = PVMetalFilterRenderer()
    /// Idle chains, least recently used first.
    private var idleChains: [(id: ShaderID, box: ChainBox)] = []
    private let compileQueue = DispatchQueue(label: "org.provenance-emu.shaders.preview-compile",
                                             qos: .utility, attributes: .concurrent)

    public init(device: MTLDevice) throws {
        guard let queue = device.makeCommandQueue() else { throw ShaderPreviewError.commandQueueUnavailable }
        self.device = device
        self.queue = queue
        native.configure(device: device, pixelFormat: Self.pixelFormat, flipYAxis: false)
    }

    /// Renders `entry` over `source` into an image of exactly `size` pixels. The
    /// source keeps its aspect and is centred; the rest is black.
    ///
    /// - Parameter parameterValue: the value to render each parameter with.
    ///   Slang presets only; callers typically pass the store's values or the defaults.
    public func render(entry: ShaderCatalogEntry,
                       source: ShaderPreviewSource,
                       size: CGSize,
                       parameterValue: @Sendable (ShaderParameterDescriptor) -> Float) async throws -> CGImage {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard (1 ... Self.maxEdge).contains(width), (1 ... Self.maxEdge).contains(height) else {
            throw ShaderPreviewError.invalidSize
        }
        let sourceTexture = try source.makeTexture(device: device)
        let output = try makeOutputTexture(width: width, height: height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let contentRect = RenderGeometry.aspectFit(aspect: source.displayAspect(of: sourceTexture), in: bounds).integral
            .intersection(bounds)
        guard let commandBuffer = queue.makeCommandBuffer() else { throw ShaderPreviewError.commandQueueUnavailable }

        var checkedOut: (id: ShaderID, box: ChainBox)?
        switch entry.id.kind {
        case .native:
            guard let option = entry.id.nativeOption else { throw ShaderPreviewError.unsupportedFilter }
            try encodeNative(option, source: sourceTexture, output: output, contentRect: contentRect,
                             commandBuffer: commandBuffer)
        case .slang:
            guard let directory = entry.directory else { throw ShaderPreviewError.unsupportedFilter }
            let box = try await takeChain(id: entry.id, directory: directory)
            checkedOut = (entry.id, box)
            for parameter in entry.parameters where !parameter.isHeading {
                box.chain.setValue(CGFloat(parameterValue(parameter)), forParameterName: parameter.name)
            }
            encode(box.chain, source: sourceTexture, output: output, contentRect: contentRect,
                   commandBuffer: commandBuffer)
        case nil:
            throw ShaderPreviewError.unsupportedFilter
        }

        try await complete(commandBuffer)
        // A chain with history or feedback keeps the last picture in its textures; reusing it
        // would bleed one source into the next preview, so only stateless chains are kept.
        if let checkedOut, entry.historyFrames == 0, !entry.usesFeedback { returnChain(checkedOut) }
        return try Self.makeImage(from: output)
    }

    // MARK: - Encoding

    private func makeOutputTexture(width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: width,
                                                                  height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw ShaderPreviewError.textureCreationFailed
        }
        return texture
    }

    private func passDescriptor(for output: MTLTexture) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return pass
    }

    /// Encodes without suspending, so the shared native renderer is never used by two renders at once.
    private func encodeNative(_ option: MetalFilterSelectionOption, source: MTLTexture, output: MTLTexture,
                              contentRect: CGRect, commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor(for: output)) else {
            throw ShaderPreviewError.commandQueueUnavailable
        }
        encoder.setViewport(MTLViewport(originX: contentRect.minX, originY: contentRect.minY,
                                        width: contentRect.width, height: contentRect.height, znear: 0, zfar: 1))
        // Game Boy picks its palette from the screen type.
        let screenType: ScreenTypeObjC = option == .gameBoy ? .dotMatrix : .unknown
        let drew = native.encode(with: encoder, texture: source, drawableSize: contentRect.size,
                                 sourceSize: CGSize(width: source.width, height: source.height),
                                 screenType: screenType, smoothingEnabled: false, setViewport: false,
                                 filter: option)
        encoder.endEncoding()
        guard drew else { throw ShaderPreviewError.pipelineUnavailable }
    }

    private func encode(_ chain: FilterChain, source: MTLTexture, output: MTLTexture, contentRect: CGRect,
                        commandBuffer: MTLCommandBuffer) {
        chain.finalBlitLinear = true
        chain.drawableSize = contentRect.size
        chain.outputOffset = contentRect.origin
        chain.setSourceRect(CGRect(x: 0, y: 0, width: source.width, height: source.height),
                            aspect: contentRect.size)
        chain.render(sourceTexture: source, commandBuffer: commandBuffer,
                     renderPassDescriptor: passDescriptor(for: output), flipVertically: false)
    }

    /// Commits and suspends until the GPU is done, without blocking a thread.
    private func complete(_ commandBuffer: MTLCommandBuffer) async throws {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            commandBuffer.addCompletedHandler { _ in continuation.resume() }
            commandBuffer.commit()
        }
        if let error = commandBuffer.error {
            ELOG("Shader preview: GPU error: \(error)")
            throw ShaderPreviewError.gpuFailure
        }
        guard commandBuffer.status == .completed else { throw ShaderPreviewError.gpuFailure }
    }

    // MARK: - Chains

    /// An idle chain for `id`, or a freshly compiled one. Compiling runs off the actor.
    private func takeChain(id: ShaderID, directory: URL) async throws -> ChainBox {
        if let index = idleChains.firstIndex(where: { $0.id == id }) {
            return idleChains.remove(at: index).box
        }
        let device = device
        return try await withCheckedThrowingContinuation { continuation in
            compileQueue.async {
                continuation.resume(with: Result {
                    let chain = try FilterChain(device: device)
                    try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: directory))
                    guard chain.hasShader else { throw ShaderPreviewError.emptyChain }
                    return ChainBox(chain: chain)
                })
            }
        }
    }

    private func returnChain(_ entry: (id: ShaderID, box: ChainBox)) {
        idleChains.append(entry)
        if idleChains.count > Self.maxCachedChains {
            idleChains.removeFirst(idleChains.count - Self.maxCachedChains)
        }
    }

    // MARK: - Readback

    /// `.bgra8Unorm` read back as little-endian BGRX. Alpha is ignored: many
    /// presets leave the final pass's alpha at 0, which would make the image invisible.
    private static func makeImage(from texture: MTLTexture) throws -> CGImage {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&pixels, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                                  bitsPerPixel: bytesPerPixel * 8, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo,
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw ShaderPreviewError.imageConversionFailed
        }
        return image
    }
}
