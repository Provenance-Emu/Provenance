//
//  SlangFilterRenderer.swift
//  PVShaders
//
//  Runs a library preset (multi-pass slang chain) over the emulator frame.
//

import CoreGraphics
import Foundation
import Metal
import PVLogging
import PVSlangRuntime

/// Owns one `FilterChain` for the preset currently on screen.
///
/// Compiling a preset builds two Metal libraries per pass from source, which can
/// take a noticeable fraction of a second, so `prepare` compiles on a background
/// queue and the chain is swapped in on the main thread once ready. Until then
/// callers draw without the filter.
@MainActor
public final class SlangFilterRenderer {
    private let device: MTLDevice
    private var chain: FilterChain?
    /// The preset the current chain runs.
    public private(set) var loadedID: ShaderID?
    private var loadingID: ShaderID?
    /// Presets that failed to compile on this device; not retried this session.
    public private(set) var failedIDs: Set<ShaderID> = []
    private var generation = 0
    private var appliedParameterRevision: Int?
    private let loadQueue = DispatchQueue(label: "org.provenance-emu.shaders.load", qos: .userInitiated)

    public init(device: MTLDevice) {
        self.device = device
    }

    /// Unchecked box so a chain built on the load queue can be handed to the main thread.
    private struct ChainBox: @unchecked Sendable {
        let chain: FilterChain
    }

    private enum LoadError: Error {
        case noPasses
    }

    /// Returns `true` when `entry`'s chain is ready to render; otherwise starts loading it
    /// (once) and returns `false`. Call on the main thread.
    @discardableResult
    public func prepare(_ entry: ShaderCatalogEntry) -> Bool {
        if loadedID == entry.id { return true }
        guard loadingID != entry.id, !failedIDs.contains(entry.id), let directory = entry.directory else {
            return false
        }
        loadingID = entry.id
        generation += 1
        let token = generation
        let device = device
        let id = entry.id
        loadQueue.async { [weak self] in
            let result: Result<ChainBox, Error> = Result {
                let chain = try FilterChain(device: device)
                try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: directory))
                guard chain.hasShader else { throw LoadError.noPasses }
                return ChainBox(chain: chain)
            }
            DispatchQueue.main.async { MainActor.assumeIsolated {
                guard let self, token == self.generation else { return }
                self.loadingID = nil
                switch result {
                case .success(let box):
                    self.chain = box.chain
                    self.loadedID = id
                    self.appliedParameterRevision = nil
                    ILOG("Shader library: loaded \(id)")
                case .failure(let error):
                    self.failedIDs.insert(id)
                    ELOG("Shader library: \(id) failed to load: \(error)")
                }
            } }
        }
        return false
    }

    /// Drops the loaded chain (for example when no library filter is selected).
    public func unload() {
        generation += 1
        chain = nil
        loadedID = nil
        loadingID = nil
        appliedParameterRevision = nil
    }

    /// Pushes parameter values into the chain when `revision` changed since the last call.
    public func applyParameters(revision: Int, value: (ShaderParameterDescriptor) -> Float,
                                parameters: [ShaderParameterDescriptor]) {
        guard let chain, appliedParameterRevision != revision else { return }
        appliedParameterRevision = revision
        for parameter in parameters where !parameter.isHeading {
            chain.setValue(CGFloat(value(parameter)), forParameterName: parameter.name)
        }
    }

    /// Encodes the chain: offscreen passes, then the final pass into `contentRect` of
    /// `target` (cleared to black around it). Returns `false` when no chain is loaded.
    ///
    /// - Parameters:
    ///   - flipVertically: the source is bottom-up (OpenGL origin).
    ///   - linear: smooth sampling where a preset leaves filtering unspecified.
    public func render(source: MTLTexture,
                       commandBuffer: MTLCommandBuffer,
                       target: MTLTexture,
                       contentRect: CGRect,
                       flipVertically: Bool,
                       linear: Bool) -> Bool {
        guard let chain else { return false }
        chain.finalBlitLinear = linear
        chain.drawableSize = contentRect.size
        chain.outputOffset = contentRect.origin
        chain.setSourceRect(CGRect(x: 0, y: 0, width: source.width, height: source.height),
                            aspect: contentRect.size)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        chain.render(sourceTexture: source, commandBuffer: commandBuffer, renderPassDescriptor: pass,
                     flipVertically: flipVertically)
        return true
    }
}
