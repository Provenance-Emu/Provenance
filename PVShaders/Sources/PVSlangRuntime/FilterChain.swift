// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import Metal
import MetalKit
import os.log

// swiftlint:disable type_body_length
public final class FilterChain {
    private static let signpostLog = OSLog(subsystem: "org.provenance-emu.provenance", category: .pointsOfInterest)
    enum InitError: Error {
        case invalidSamplerState
        /// A compiled shader/preset is malformed or exceeds fixed-capacity limits
        /// (too many passes, LUTs, or parameters). Thrown so callers can skip the
        /// filter gracefully instead of trapping on an out-of-bounds access.
        case invalidShader
    }

    private let device: MTLDevice
    private let library: MTLLibrary
    private let loader: MTKTextureLoader

    private var vertex = [
        Vertex(position: simd_float4(x: 0, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 1)),
        Vertex(position: simd_float4(x: 1, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 1)),
        Vertex(position: simd_float4(x: 0, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 0)),
        Vertex(position: simd_float4(x: 1, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 0)),
    ]
    private var vertexFlipped = [
        Vertex(position: simd_float4(x: 0, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 0)),
        Vertex(position: simd_float4(x: 0, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 1)),
        Vertex(position: simd_float4(x: 1, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 0)),
        Vertex(position: simd_float4(x: 1, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 1)),
    ]
    let vertexSizeBytes: Int

    private var samplers: SamplerFilterArray<MTLSamplerState>

    public var hasShader: Bool = false

    private var frameCount: UInt = 0
    private var passCount: Int = 0
    private var lastPassIndex: Int = 0
    private var historyCount: Int = 0

    /// The OriginalHistory(N) semantic
    private var historyTextures = [Texture](repeating: .init(), count: Constants.maxFrameHistory + 1)

    private struct OutputFrame {
        var viewport: MTLViewport
        var outputSize: TextureSize

        init() {
            viewport = .init()
            outputSize = .init()
        }
    }

    private var outputFrame: OutputFrame = .init()

    private struct Pass {
        var format = MTLPixelFormat.bgra8Unorm
        var buffers = [MTLBuffer?](repeating: nil, count: Constants.maxConstantBuffers)
        var vBuffers = [MTLBuffer?](
            repeating: nil,
            count: Constants.maxConstantBuffers
        ) // array used for vertex binding
        var fBuffers = [MTLBuffer?](
            repeating: nil,
            count: Constants.maxConstantBuffers
        ) // array used for fragment binding
        var renderTarget = Texture()
        var feedbackTarget = Texture()
        var frameCount = UInt32(0)
        var frameCountMod = UInt32(0)
        var frameDirection = Int32(0)
        var bindings: ShaderPassBindings?
        var viewport = MTLViewport()
        var state: MTLRenderPipelineState?
        var hasFeedback = false
        var scaleX: ShaderPassScale?
        var scaleY: ShaderPassScale?
        var isScaled: Bool {
            scaleX != nil && scaleY != nil
        }

        func getOutputSize(viewport: CGSize, source: CGSize) -> CGSize {
            let width: CGFloat = switch scaleX {
            case let .source(scale):
                source.width * scale
            case let .absolute(size):
                Double(size)
            case let .viewport(scale):
                viewport.width * scale
            default:
                source.width
            }

            let height: CGFloat = switch scaleY {
            case let .source(scale):
                source.height * scale
            case let .absolute(size):
                Double(size)
            case let .viewport(scale):
                viewport.height * scale
            default:
                source.height
            }

            return CGSize(width: width.rounded(), height: height.rounded())
        }
    }

    private var pass = [Pass](repeating: .init(), count: Constants.maxShaderPasses)
    private var luts = [Texture](repeating: .init(), count: Constants.maxTextures)

    /// Expected texture bindings (binding index, semantic name) per pass, built at load time for diagnostics
    private var expectedTextureBindingsPerPass: [[(Int, String)]] = []

    private var renderTargetsNeedResize = true
    private var historyNeedsInit = false

    public private(set) var sourceRect = CGRect.zero

    private var aspectSize = CGSize.zero

    public private(set) var outputBounds = CGRect.zero

    public var frameDirection: Int = 1

    // render target layer state
    private var pipelineState: MTLRenderPipelineState
    private var hdrPipelineState: MTLRenderPipelineState?
    /// HDR blit variant for shader-chain output: sRGB→linear with NO EDR boost.
    private var hdrLinearPipelineState: MTLRenderPipelineState?
    private var outputColorPixelFormat: MTLPixelFormat = .bgra8Unorm

    private var _rotation: Float = 0

    private var uniforms = Uniforms.empty
    private var uniformsNoRotate = Uniforms.empty

    /// One-shot logging guard
    private var didLogOnce: Bool = false

    /// De-duplicated error logging for shader-failure paths, so a per-frame
    /// failure logs once instead of flooding the console.
    private var loggedFilterFailures: Set<String> = []
    private func logFilterFailureOnce(_ message: String) {
        guard !loggedFilterFailures.contains(message) else { return }
        loggedFilterFailures.insert(message)
        os_log("%{public}@", log: OSLog(subsystem: "org.provenance-emu.provenance", category: "Shaders"), type: .error, message)
    }

    /// Used as a fallback image when a look-up texture cannot be loaded.
    private lazy var checkers: MTLTexture = {
        // swiftlint:disable identifier_name force_try
        let T0 = UInt32(0xFF00_0000)
        let T1 = UInt32(0xFFFF_FFFF)
        var checkerboard = [
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
        ]

        // Preferred path: an 8x8 checkerboard via CoreGraphics + the MetalKit
        // loader. Any of these can fail (CoreGraphics/loader), so don't force-
        // unwrap them in a property the render loop reads.
        if let ctx = CGContext(
            data: &checkerboard,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast
                .rawValue
        ),
            let img = ctx.makeImage(),
            let tex = try? loader.newTexture(cgImage: img)
        {
            return tex
        }

        // Fallback: a bare 1x1 texture straight from a descriptor, with no
        // CoreGraphics / MetalKit-loader dependency. This only returns nil if
        // Metal itself is unavailable — at which point nothing can render — so
        // the single remaining force-unwrap is not a realistic crash.
        logFilterFailureOnce("checkers fallback: CGImage/loader path failed; using 1x1 placeholder")
        let td = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        td.usage = [.shaderRead]
        return device.makeTexture(descriptor: td)!
    }()

    #if os(macOS)
        /// device behaviour
        private let deviceHasUnifiedMemory: Bool
    #endif

    // parameters state
    private var parameters = [Float](repeating: 0, count: Constants.maxParameters)
    private var parametersCount = 0
    private var parametersMap = [String: Int]()

    public init(device: MTLDevice) throws {
        self.didLogOnce = false
        self.device = device
        #if os(macOS)
            if #available(macOS 10.15, iOS 11, *) {
                deviceHasUnifiedMemory = device.hasUnifiedMemory
            } else {
                deviceHasUnifiedMemory = false
            }
        #endif

        library = try RuntimeLibrary.library(for: device, source: .shaders)
        loader = .init(device: device)
        pipelineState = try Self.makePipelineState(device, library, colorPixelFormat: outputColorPixelFormat)
        if outputColorPixelFormat == .rgba16Float {
            hdrPipelineState = try Self.makeHDRPipelineState(device, library, colorPixelFormat: outputColorPixelFormat)
            hdrLinearPipelineState = try Self.makeHDRPipelineState(
                device,
                library,
                colorPixelFormat: outputColorPixelFormat,
                fragment: "basic_fragment_proj_tex_hdr_linear"
            )
        }
        samplers = try Self.makeSamplers(device)
        vertexSizeBytes = MemoryLayout<Vertex>.stride * vertex.count

        rotation = 0
        setDefaultFilteringLinear(false)
    }

    // MARK: - Static helpers

    private static func makePipelineState(
        _ device: MTLDevice,
        _ library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat
    ) throws -> MTLRenderPipelineState {
        let vd = MTLVertexDescriptor()
        if let attr = vd.attributes[VertexAttribute.position.rawValue] {
            attr.offset = MemoryLayout<Vertex>.offset(of: \.position)!
            attr.format = .float4
            attr.bufferIndex = BufferIndex.positions.rawValue
        }
        if let attr = vd.attributes[VertexAttribute.texCoord.rawValue] {
            attr.offset = MemoryLayout<Vertex>.offset(of: \.texCoord)!
            attr.format = .float2
            attr.bufferIndex = BufferIndex.positions.rawValue
        }
        if let l = vd.layouts[BufferIndex.positions.rawValue] {
            l.stride = MemoryLayout<Vertex>.stride
        }

        let psd = MTLRenderPipelineDescriptor()
        psd.label = "Pipeline+No Alpha"

        if let ca = psd.colorAttachments[0] {
            ca.pixelFormat = colorPixelFormat // Match the current drawable's format
            ca.isBlendingEnabled = false
            ca.sourceAlphaBlendFactor = .sourceAlpha
            ca.sourceRGBBlendFactor = .sourceAlpha
            ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            ca.destinationRGBBlendFactor = .oneMinusSourceAlpha
        }

        psd.vertexDescriptor = vd
        psd.vertexFunction = library.makeFunction(name: "basic_vertex_proj_tex")
        psd.fragmentFunction = library.makeFunction(name: "basic_fragment_proj_tex")

        return try device.makeRenderPipelineState(descriptor: psd)
    }

    private static func makeHDRPipelineState(
        _ device: MTLDevice,
        _ library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        fragment fragmentName: String = "basic_fragment_proj_tex_hdr"
    ) throws
        -> MTLRenderPipelineState
    {
        let psd = MTLRenderPipelineDescriptor()
        psd.label = "HDR Pipeline (\(fragmentName))"
        if let ca = psd.colorAttachments[0] {
            ca.pixelFormat = colorPixelFormat
            ca.isBlendingEnabled = false
        }
        let vd = MTLVertexDescriptor()
        if let pos = vd
            .attributes[0]
        {
            pos.offset = MemoryLayout<Vertex>.offset(of: \.position)!; pos.format = .float4; pos
                .bufferIndex = BufferIndex.positions.rawValue
        }
        if let tex = vd
            .attributes[1]
        {
            tex.offset = MemoryLayout<Vertex>.offset(of: \.texCoord)!; tex.format = .float2; tex
                .bufferIndex = BufferIndex.positions.rawValue
        }
        if let l = vd.layouts[BufferIndex.positions.rawValue] {
            l.stride = MemoryLayout<Vertex>.stride
        }
        psd.vertexDescriptor = vd
        psd.vertexFunction = library.makeFunction(name: "basic_vertex_proj_tex")
        psd.fragmentFunction = library.makeFunction(name: fragmentName)
        return try device.makeRenderPipelineState(descriptor: psd)
    }

    /// Allow caller to update the output pixel format to match the current CAMetalDrawable.
    public func setOutputPixelFormat(_ pixelFormat: MTLPixelFormat) {
        guard pixelFormat != outputColorPixelFormat else { return }
        outputColorPixelFormat = pixelFormat
        do {
            pipelineState = try Self.makePipelineState(device, library, colorPixelFormat: outputColorPixelFormat)
            if pixelFormat == .rgba16Float {
                hdrPipelineState = try Self.makeHDRPipelineState(
                    device,
                    library,
                    colorPixelFormat: outputColorPixelFormat
                )
                hdrLinearPipelineState = try Self.makeHDRPipelineState(
                    device,
                    library,
                    colorPixelFormat: outputColorPixelFormat,
                    fragment: "basic_fragment_proj_tex_hdr_linear"
                )
            } else {
                hdrPipelineState = nil
                hdrLinearPipelineState = nil
            }
        } catch {
            // Fail fast, fail loud per user rules
            fatalError("Failed to recreate pipeline state for pixelFormat=\(pixelFormat): \(error)")
        }
        // Changing output format can enable direct-to-drawable on last pass if formats now match
        renderTargetsNeedResize = true
    }

    /// Set the user video grade (brightness/gamma) applied in the final-blit
    /// fragments (`applyGrade` in Shaders.metal) on every path — SDR, HDR, shader
    /// on/off — since the final blit always runs. Defaults are 1.0 (no-op). Clamped
    /// so an extreme value (especially with the HDR EDR boost) can't blow out or
    /// crush to black.
    public func setVideoGrade(brightness: Float, gamma: Float) {
        let b = min(max(brightness, 0.25), 2.0)
        let g = min(max(gamma, 0.5), 3.0)
        uniforms.brightness = b
        uniforms.gamma = g
        uniformsNoRotate.brightness = b
        uniformsNoRotate.gamma = g
    }

    private static func makeSamplers(_ device: MTLDevice) throws -> SamplerFilterArray<MTLSamplerState> {
        var samplers = [[MTLSamplerState?]](
            repeating: [MTLSamplerState?](
                repeating: nil,
                count: ShaderPassWrap.allCases.count
            ),
            count: ShaderPassFilter.allCases.count
        )
        let sd = MTLSamplerDescriptor()
        for i in ShaderPassWrap.allCases {
            var label = ""
            switch i {
            case .border:
                if #available(macOS 10.15, iOS 11, *) {
                    if device.supportsFamily(.apple1) {
                        label = "clamp_to_zero"
                        sd.sAddressMode = .clampToZero
                        break
                    }
                }
                if #available(macOS 10.12, iOS 14, *) {
                    label = "clamp_to_border"
                    sd.sAddressMode = .clampToBorderColor
                } else {
                    label = "clamp_to_zero"
                    sd.sAddressMode = .clampToZero
                }

            case .edge:
                label = "clamp_to_edge"
                sd.sAddressMode = .clampToEdge

            case .repeat:
                label = "repeat"
                sd.sAddressMode = .repeat

            case .mirroredRepeat:
                label = "mirrored_repeat"
                sd.sAddressMode = .mirrorRepeat
            }

            sd.tAddressMode = sd.sAddressMode
            sd.rAddressMode = sd.sAddressMode
            sd.minFilter = .linear
            sd.magFilter = .linear
            sd.label = "\(label) (linear)"
            if let ss = device.makeSamplerState(descriptor: sd) {
                samplers[.linear][i] = ss
            } else {
                throw InitError.invalidSamplerState
            }

            sd.minFilter = .nearest
            sd.magFilter = .nearest
            sd.label = label
            if let ss = device.makeSamplerState(descriptor: sd) {
                samplers[.nearest][i] = ss
            } else {
                throw InitError.invalidSamplerState
            }
        }

        // swiftlint:disable:next force_cast
        return samplers.map { $0.compactMap(\.self) } as! SamplerFilterArray<MTLSamplerState>
    }

    public var rotation: Float {
        get { _rotation }
        set {
            _rotation = newValue * 270

            uniformsNoRotate.projectionMatrix = .makeOrtho(left: 0, right: 1, top: 0, bottom: 1)

            let rot = simd_float4x4.makeRotated(z: (Float.pi * newValue) / 180.0)
            uniforms.projectionMatrix = rot * uniformsNoRotate.projectionMatrix
        }
    }

    /// Sets the default filtering mode when a shader pass leaves the value unspecified.
    ///
    /// - parameters:
    ///     - linear: `true` to use linear filtering
    public func setDefaultFilteringLinear(_ linear: Bool) {
        if linear {
            samplers[.unspecified] = samplers[.linear]
        } else {
            samplers[.unspecified] = samplers[.nearest]
        }
    }

    private func updateHistory() {
        guard historyCount > 0 else { return }

        if historyNeedsInit {
            initHistory()
        } else {
            // shift history and move last texture into first position
            let tmp = historyTextures[historyCount]
            for k in (1 ... historyCount).reversed() {
                historyTextures[k] = historyTextures[k - 1]
            }
            historyTextures[0] = tmp
        }
    }

    /**
     * Take the raw visible game rect and turn it into a smaller rect
     * which is centered inside 'bounds' and has aspect ratio 'aspectSize'.
     * Currently we try to fill the window, but maybe someday we'll support fixed zooms.
     */
    private static func fitAspectRectIntoRect(aspectSize: CGSize, size: CGSize) -> CGRect {
        let wantAspect = aspectSize.width / aspectSize.height
        let viewAspect = size.width / size.height

        var minFactor: CGFloat
        var outRectSize: CGSize

        if viewAspect >= wantAspect {
            // Raw image is too wide (normal case), squish inwards
            minFactor = wantAspect / viewAspect
            outRectSize = .init(width: size.width * minFactor, height: size.height)
        } else {
            // Raw image is too tall, squish upwards
            minFactor = viewAspect / wantAspect
            outRectSize = .init(width: size.width, height: size.height * minFactor)
        }

        let outRect = CGRect(
            origin: .init(
                x: (size.width - outRectSize.width) / 2,
                y: (size.height - outRectSize.height) / 2
            ),
            size: outRectSize
        )

        // This is going into a Nearest Neighbor, so the edges should be on pixels!
        return outRect.integral
    }

    /// Where the output area starts inside the render target (Provenance draws the
    /// picture into a sub-rect of the drawable while a skin's frame is pending).
    public var outputOffset: CGPoint = .zero {
        didSet {
            if outputOffset != oldValue { resize() }
        }
    }

    private func resize() {
        let bounds = Self.fitAspectRectIntoRect(aspectSize: aspectSize, size: drawableSize)
            .offsetBy(dx: outputOffset.x, dy: outputOffset.y)
        if outputBounds == bounds {
            return
        }

        outputBounds = bounds
        let size = outputBounds.size

        outputFrame.viewport = MTLViewport(
            originX: outputBounds.origin.x,
            originY: outputBounds.origin.y,
            width: size.width,
            height: size.height,
            znear: 0,
            zfar: 1
        )
        outputFrame.outputSize = .init(width: size.width, height: size.height)

        if hasShader {
            renderTargetsNeedResize = true
        }
    }

    public func setSourceRect(_ rect: CGRect, aspect: CGSize) {
        if sourceRect == rect, aspectSize == aspect {
            return
        }

        sourceRect = rect
        aspectSize = aspect
        resize()
    }

    public var drawableSize: CGSize = .zero {
        didSet {
            resize()
        }
    }

    /// A list of textures to be cleared before rendering begins.
    var _clearTextures = [MTLTexture]()

    private func clearTexturesWithCommandBuffer(_ commandBuffer: MTLCommandBuffer) {
        guard !_clearTextures.isEmpty else { return }

        defer { _clearTextures.removeAll(keepingCapacity: true) }

        guard #available(macOS 10.15, *) else { return }

        // Find the size of the largest texture, in order to allocate a buffer with at least enough space for all
        // textures.
        var sizeMax = 0
        for t in _clearTextures {
            let bytesPerPixel = t.pixelFormat.bytesPerPixel
            precondition(bytesPerPixel > 0, "Unable to determine bytes per pixel for pixel format \(t.pixelFormat)")

            let bytesPerRow = t.width * bytesPerPixel
            let bytesPerImage = t.height * bytesPerRow
            if bytesPerImage > sizeMax {
                sizeMax = bytesPerImage
            }
        }

        // Allocate a buffer over the entire heap and fill it with zeros
        if let bce = commandBuffer.makeBlitCommandEncoder(),
           let buf = device.makeBuffer(length: sizeMax, options: [.storageModePrivate])
        {
            bce.fill(buffer: buf, range: 0 ..< sizeMax, value: 0)

            // Use the cleared buffer to clear the destination texture.
            for t in _clearTextures {
                let bytesPerPixel = t.pixelFormat.bytesPerPixel
                let bytesPerRow = t.width * bytesPerPixel
                let bytesPerImage = t.height * bytesPerRow
                let sourceSize = MTLSize(width: t.width, height: t.height, depth: 1)
                bce.copy(
                    from: buf,
                    sourceOffset: 0,
                    sourceBytesPerRow: bytesPerRow,
                    sourceBytesPerImage: bytesPerImage,
                    sourceSize: sourceSize,
                    to: t,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: .init()
                )
            }
            bce.endEncoding()
        }
    }

    private func fetchNextHistoryTexture() -> MTLTexture? {
        precondition(historyCount > 0, "Current shader does not require history")

        // either no history, or we moved a texture of a different size in the front slot
        if historyTextures[0].size.x != Float(sourceRect.width) || historyTextures[0].size
            .y != Float(sourceRect.height)
        {
            let td = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: Int(sourceRect.width),
                height: Int(sourceRect.height),
                mipmapped: false
            )
            td.storageMode = .private
            td.usage = [.shaderRead, .shaderWrite]
            initTexture(&historyTextures[0], withDescriptor: td)
        }

        return historyTextures[0].view
    }

    private func prepareNextFrame(sourceTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        frameCount += 1

        resizeRenderTargets()
        updateHistory()
        clearTexturesWithCommandBuffer(commandBuffer)

        if historyCount == 0 {
            // No need to copy, set the sourceTexture to Original / OriginalHistory0 semantic
            initTexture(&historyTextures[0], withTexture: sourceTexture)
        } else if let texture = fetchNextHistoryTexture() {
            let orig = MTLOrigin(x: Int(sourceRect.origin.x), y: Int(sourceRect.origin.y), z: 0)
            let size = MTLSize(width: Int(sourceRect.width), height: Int(sourceRect.height), depth: 1)
            let zero = MTLOrigin()

            if let bce = commandBuffer.makeBlitCommandEncoder() {
                bce.copy(
                    from: sourceTexture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: orig,
                    sourceSize: size,
                    to: texture,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: zero
                )
                bce.endEncoding()
            }
        }
    }

    private func initTexture(_ t: inout Texture, withDescriptor td: MTLTextureDescriptor) {
        t.view = device.makeTexture(descriptor: td)
        t.size = .init(width: td.width, height: td.height)
    }

    private func initTexture(_ t: inout Texture, withTexture tex: MTLTexture) {
        t.view = tex
        t.size = .init(width: tex.width, height: tex.height)
    }

    private func initHistory() {
        let td = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(sourceRect.width),
            height: Int(sourceRect.height),
            mipmapped: false
        )
        td.storageMode = .private
        td.usage = [.shaderRead, .shaderWrite]

        for i in 0 ... historyCount {
            initTexture(&historyTextures[i], withDescriptor: td)
            if let view = historyTextures[i].view {
                _clearTextures.append(view)
            }
        }
        historyNeedsInit = false
    }

    /// Smooth (`true`) or nearest (`false`) upscaling where the app, not the
    /// preset, picks the sampler: i.e. Sharp Pixels turned OFF. `false` = nearest,
    /// the historical behaviour and still the default. It decides:
    /// - the plain final blit when NO shader is active (the pass-through that
    ///   stretches the game texture to the drawable);
    /// - every shader pass whose preset leaves `filter_linearN` unset, the same
    ///   role RetroArch gives its `video_smooth` setting. A preset that sets
    ///   `filter_linearN` explicitly keeps its choice;
    /// - the final blit after a preset whose last pass renders smaller than the
    ///   output (a scaled last pass). When the last pass is output-sized that
    ///   blit is 1:1 and the sampler makes no difference.
    /// Set per frame by `DOLShaderPostProcessor.renderSource`.
    public var finalBlitLinear = false {
        didSet {
            guard finalBlitLinear != oldValue else { return }
            setDefaultFilteringLinear(finalBlitLinear)
        }
    }

    private func renderTexture(
        _ texture: MTLTexture,
        renderCommandEncoder rce: MTLRenderCommandEncoder,
        useHDR: Bool = false,
        hdrBoost: Bool = true,
        linear: Bool = false
    ) {
        rce.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniforms.rawValue)
        // The final-blit fragments read `uniforms` (brightness/gamma/hdrBoost via
        // applyGrade) — bind it to the FRAGMENT stage too, or they sample an unbound
        // buffer (garbage / black screen). Defaults (1/1/2.5) are behavior-neutral.
        rce.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniforms.rawValue)
        // HDR (rgba16Float) drawable needs sRGB→linear. `hdrBoost` true = boosted
        // (EDR paper-white) for raw game output; false = linear-only (no boost) for
        // shader-chain output, which is already display-referred and would blow out
        // if boosted — but still needs the sRGB→linear or it washes out.
        if useHDR, let hdr = (hdrBoost ? hdrPipelineState : hdrLinearPipelineState) {
            rce.setRenderPipelineState(hdr)
        } else {
            rce.setRenderPipelineState(pipelineState)
        }
        let filter: ShaderPassFilter = linear ? .linear : .nearest
        rce.setFragmentSamplerState(samplers[filter][.edge], index: SamplerIndex.draw.rawValue)
        rce.setViewport(outputFrame.viewport)
        rce.setFragmentTexture(texture, index: TextureIndex.color.rawValue)
        rce.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    public func render(
        sourceTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor rpd: MTLRenderPassDescriptor,
        flipVertically: Bool = false
    ) {
        renderOffscreenPasses(sourceTexture: sourceTexture, commandBuffer: commandBuffer)
        if let rce = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
            if !didLogOnce {
                // Log a compact summary only once per load
                if UserDefaults.standard.object(forKey: "shader_debug_log_once") as? Bool ?? true {
                    var missingTotals = [Int](repeating: 0, count: passCount)
                    var missingDetail: [String] = []
                    for i in 0 ..< passCount {
                        var present: Set<Int> = []
                        let expected = (i < expectedTextureBindingsPerPass.count) ? expectedTextureBindingsPerPass[i] :
                            []
                        if let texs = pass[i].bindings?.textures {
                            for t in texs {
                                present.insert(Int(t.binding))
                            }
                        }
                        var m = 0
                        var names: [String] = []
                        for (b, n) in expected {
                            if !present.contains(Int(b)) {
                                m += 1; names.append(n)
                            }
                        }
                        missingTotals[i] = m
                        if m > 0 {
                            missingDetail.append("p\(i): \(names.joined(separator: ","))")
                        }
                    }
                    os_log(
                        "[Shaders] First render: drawable=%dx%d src=%dx%d fmt out=%d src=%d missing=%{public}@ details=%{public}@",
                        log: .default,
                        type: .info,
                        Int(outputFrame.outputSize.x),
                        Int(outputFrame.outputSize.y),
                        sourceTexture.width,
                        sourceTexture.height,
                        outputColorPixelFormat.rawValue,
                        sourceTexture.pixelFormat.rawValue,
                        String(describing: missingTotals),
                        missingDetail.joined(separator: " | ")
                    )
                }
                didLogOnce = true
            }
            renderFinalPass(withCommandEncoder: rce, flipVertically: flipVertically)
            rce.endEncoding()
        }
    }

    public func renderOffscreenPasses(sourceTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        prepareNextFrame(sourceTexture: sourceTexture, commandBuffer: commandBuffer)
        updateBuffersForPasses()

        guard hasShader, passCount > 0 else { return }

        // swap feedback render targets
        for i in 0 ..< passCount where pass[i].hasFeedback {
            (pass[i].renderTarget, pass[i].feedbackTarget) = (pass[i].feedbackTarget, pass[i].renderTarget)
        }

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        let lassPassIsDirect = pass[lastPassIndex].renderTarget.view == nil
        let count = lassPassIsDirect ? passCount - 1 : passCount

        for i in 0 ..< count {
            rpd.colorAttachments[0].texture = pass[i].renderTarget.view
            guard let rce = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { continue }
            rce.setVertexBytes(&vertex, length: vertexSizeBytes, index: BufferIndex.positions.rawValue)
            rce.setViewport(pass[i].viewport)
            renderPassIndex(i, renderCommandEncoder: rce)
            rce.endEncoding()
        }
    }

    // MARK: - Debug helpers

    public var debugPassCount: Int {
        passCount
    }

    public func debugRenderPass(
        index: Int,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor rpd: MTLRenderPassDescriptor
    ) -> Bool {
        guard index >= 0, index < passCount else { return false }
        guard let view = pass[index].renderTarget.view else { return false }
        guard let rce = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return false }
        renderTexture(view, renderCommandEncoder: rce)
        rce.endEncoding()
        return true
    }

    private func updateBuffersForPasses() {
        for i in 0 ..< passCount {
            pass[i].frameDirection = Int32(frameDirection)
            pass[i].frameCount = UInt32(frameCount)
            if pass[i].frameCountMod != 0 {
                pass[i].frameCount %= pass[i].frameCountMod
            }

            // Skip a pass whose shader failed to compile (bindings == nil)
            // instead of force-unwrapping and crashing in the render loop.
            guard let bindings = pass[i].bindings else {
                logFilterFailureOnce(
                    "updateBuffersForPasses: pass \(i) has no bindings (shader compile failed); skipping"
                )
                continue
            }

            for j in 0 ..< Constants.maxConstantBuffers {
                let sem = bindings.buffers[j]

                guard
                    sem.bindingVert != nil || sem.bindingFrag != nil,
                    !sem.uniforms.isEmpty
                else { continue }

                if let buffer = pass[i].buffers[j] {
                    let data = buffer.contents()
                    for uniform in sem.uniforms {
                        data.advanced(by: uniform.offset).copyMemory(from: uniform.data, byteCount: uniform.size)
                    }
                    #if os(macOS)
                        if !deviceHasUnifiedMemory {
                            buffer.didModifyRange(0 ..< buffer.length)
                        }
                    #endif
                }
            }
        }
    }

    // these fields are used as temporary storage when rendering each pass
    private var _renderTextures: [MTLTexture?] = .init(repeating: nil, count: Constants.maxShaderBindings)
    private var _renderSamplers: [MTLSamplerState?] = .init(repeating: nil, count: Constants.maxShaderBindings)
    private var _renderbOffsets: [Int] = .init(repeating: 0, count: Constants.maxConstantBuffers)

    private func renderPassIndex(_ i: Int, renderCommandEncoder rce: MTLRenderCommandEncoder) {
        defer {
            // clear references from temporary buffers
            for i in 0 ..< Constants.maxShaderBindings {
                _renderTextures[i] = nil
                _renderSamplers[i] = nil
            }
        }

        // A pass whose shader failed to compile has nil bindings/state. Skip it
        // (this pass goes undrawn — downstream passes may sample stale data,
        // visually wrong but not a crash) rather than force-unwrap in the loop.
        guard let bindings = pass[i].bindings, let state = pass[i].state else {
            logFilterFailureOnce("renderPassIndex: pass \(i) missing bindings/state (shader compile failed); skipping")
            return
        }

        for bind in bindings.textures {
            let binding = Int(bind.binding)
            _renderTextures[binding] = bind.texture.load(as: MTLTexture?.self)
            _renderSamplers[binding] = samplers[bind.filter][bind.wrap]
        }

        // Debug: force previous pass output at binding 0 (for passes > 0)
        if i > 0, UserDefaults.standard.bool(forKey: "shader_debug_force_prev_output_binding0") {
            if let prev = pass[i - 1].renderTarget.view {
                _renderTextures[0] = prev
                if _renderSamplers[0] == nil {
                    _renderSamplers[0] = samplers[.nearest][.edge]
                }
            }
        }

        // Debug: targeted mapping of 'source' semantics to expected binding
        if UserDefaults.standard.bool(forKey: "shader_debug_map_source_semantics") {
            let expected = (i < expectedTextureBindingsPerPass.count) ? expectedTextureBindingsPerPass[i] : []
            var targetBindings: [Int] = []
            for (b, n) in expected {
                let lower = n.lowercased()
                if lower.contains("source") || (i == 0 && lower.contains("original")) {
                    targetBindings.append(b)
                }
            }
            if !targetBindings.isEmpty {
                if i == 0 {
                    if let src = historyTextures[0].view {
                        for b in targetBindings {
                            _renderTextures[b] = src
                            if _renderSamplers[b] == nil {
                                _renderSamplers[b] = samplers[.nearest][.edge]
                            }
                        }
                    }
                } else {
                    if let prev = pass[i - 1].renderTarget.view {
                        for b in targetBindings {
                            _renderTextures[b] = prev
                            if _renderSamplers[b] == nil {
                                _renderSamplers[b] = samplers[.nearest][.edge]
                            }
                        }
                    }
                }
            }
        }

        // Compatibility fallback: ensure binding 0 carries a valid source
        let compatPass0 = (UserDefaults.standard.object(forKey: "shader_compat_pass0_source_b0") as? Bool) ?? true
        let compatPrev = (UserDefaults.standard.object(forKey: "shader_compat_prev_output_b0") as? Bool) ?? true
        if _renderTextures[0] == nil {
            if i == 0, compatPass0 {
                if let src = historyTextures[0].view {
                    _renderTextures[0] = src
                }
                if _renderSamplers[0] == nil {
                    _renderSamplers[0] = samplers[.nearest][.edge]
                }
            } else if i > 0, compatPrev {
                if let prev = pass[i - 1].renderTarget.view {
                    _renderTextures[0] = prev
                }
                if _renderSamplers[0] == nil {
                    _renderSamplers[0] = samplers[.nearest][.edge]
                }
            }
        }

        // Substitute missing textures with a known pattern for stability
        var missing = 0
        for idx in 0 ..< Constants.maxShaderBindings {
            if _renderTextures[idx] == nil {
                _renderTextures[idx] = checkers
                missing += 1
            }
        }
//        if missing > 0 {
//            os_log("pass %d: substituted %d missing textures with checker", log: .default, type: .debug, i, missing)
//        }

        // Debug: force binding 0 to checkerboard for pass 0 to validate sampling
        if i == 0, UserDefaults.standard.bool(forKey: "shader_debug_binding0_checker") {
            _renderTextures[0] = checkers
            os_log("pass %d: forced binding 0 to checkerboard", log: .default, type: .debug, i)
        }

        // Debug: force all textures to checker and patch size uniforms
        if UserDefaults.standard.bool(forKey: "shader_debug_force_all_checker") {
            for idx in 0 ..< Constants.maxShaderBindings {
                _renderTextures[idx] = checkers
            }
            let w = Float(checkers.width)
            let h = Float(checkers.height)
            let sizeVec: [Float] = [w, h, 1.0 / max(1, w), 1.0 / max(1, h)]
            for j in 0 ..< Constants.maxConstantBuffers {
                guard let buf = pass[i].buffers[j] else { continue }
                let dest = buf.contents()
                for uni in bindings.buffers[j].uniforms {
                    if uni.size == MemoryLayout<Float>.stride * 4, uni.name.lowercased().contains("size") {
                        sizeVec.withUnsafeBytes { src in
                            dest.advanced(by: uni.offset).copyMemory(from: src.baseAddress!, byteCount: uni.size)
                        }
                    }
                }
            }
            os_log("pass %d: forced all bindings to checker and patched size uniforms", log: .default, type: .debug, i)
        }

        // enqueue commands
        rce.setRenderPipelineState(state)
        rce.label = state.label

        rce.setVertexBuffers(pass[i].vBuffers, offsets: _renderbOffsets, range: 0 ..< Constants.maxConstantBuffers)
        rce.setFragmentBuffers(pass[i].fBuffers, offsets: _renderbOffsets, range: 0 ..< Constants.maxConstantBuffers)
        rce.setFragmentTextures(_renderTextures, range: 0 ..< Constants.maxShaderBindings)
        rce.setFragmentSamplerStates(_renderSamplers, range: 0 ..< Constants.maxShaderBindings)
        rce.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    public func renderFinalPass(withCommandEncoder rce: MTLRenderCommandEncoder, flipVertically: Bool) {
        rce.setViewport(outputFrame.viewport)
        if flipVertically {
            rce.setVertexBytes(&vertexFlipped, length: vertexSizeBytes, index: BufferIndex.positions.rawValue)
        } else {
            rce.setVertexBytes(&vertex, length: vertexSizeBytes, index: BufferIndex.positions.rawValue)
        }

        // When the output drawable is RGBA16Float (HDR/EDR), the final blit
        // must convert the sRGB-gamma-encoded shader/source output to linear,
        // otherwise sRGB values land in a linear buffer and blow out.
        let needHDR = outputColorPixelFormat == .rgba16Float

        if !hasShader || passCount == 0 {
            guard let texture = historyTextures[0].view else { return }
            // No shader active — use HDR pipeline for sRGB→linear conversion
            // when outputting to RGBA16Float drawable
            return renderTexture(texture, renderCommandEncoder: rce, useHDR: needHDR, linear: finalBlitLinear)
        }

        // Shader active on an HDR (rgba16Float) drawable: apply sRGB→linear but NOT
        // the EDR paper-white boost (hdrBoost: false). Earlier this skipped the HDR
        // pass entirely to fix blown-out CRT/bezel shaders — but that left the
        // shader's sRGB output un-linearized in the float drawable, which washes it
        // out (the regression). The shader already did its own gamma/tone work, so
        // we must NOT re-boost (that was the blow-out), but we DO still need the
        // sRGB→linear so colors land correctly on the EDR drawable. On SDR drawables
        // needHDR is false → straight 1:1 blit (unchanged; matches icube/RasterLab).
        if let view = pass[lastPassIndex].renderTarget.view {
            return renderTexture(
                view,
                renderCommandEncoder: rce,
                useHDR: needHDR,
                hdrBoost: false,
                linear: finalBlitLinear
            )
        } else {
            // last pass renders directly to the final render target. This path
            // only fires when the last-pass format matches the drawable format
            // (guarded in resizeRenderTargets), i.e. never for RGBA16Float, so
            // no HDR conversion hook is needed here.
            return renderPassIndex(lastPassIndex, renderCommandEncoder: rce)
        }
    }

    private func resizeRenderTargets() {
        guard renderTargetsNeedResize else { return }

        // current source size
        var sourceSize = sourceRect.size

        let viewportSize = CGSize(width: outputFrame.viewport.width, height: outputFrame.viewport.height)

        for i in 0 ..< passCount {
            let pass = pass[i]

            let passSize: CGSize = if !pass.isScaled {
                i == lastPassIndex ? viewportSize : sourceSize
            } else {
                pass.getOutputSize(viewport: viewportSize, source: sourceSize)
            }

            sourceSize = passSize // capture source size for next pass

            // Ensure per-pass viewport matches the render target size
            self.pass[i].viewport = MTLViewport(
                originX: 0,
                originY: 0,
                width: passSize.width,
                height: passSize.height,
                znear: 0,
                zfar: 1
            )

            // os_log("pass %d, render target size %0.0f x %0.0f", log: .default, type: .debug, i, passSize.width,
            // passSize.height)

            let fmt = self.pass[i].format
            if let tex = self.pass[i].renderTarget.view,
               tex.width == Int(passSize.width),
               tex.height == Int(passSize.height),
               tex.width != 0, tex.height != 0
            {
                os_log(
                    "pass %d: 🏎️🔥 skip resize, tex (w: %d, h: %d) == pass (w: %d, h: %d)",
                    log: .default,
                    type: .debug,
                    i,
                    tex.width,
                    tex.height,
                    Int(passSize.width),
                    Int(passSize.height)
                )
                let size = TextureSize(width: Int(passSize.width), height: Int(passSize.height))
                self.pass[i].renderTarget.size = size
                if self.pass[i].hasFeedback {
                    self.pass[i].feedbackTarget.size = size
                }
                continue
            }

            let width = Int(passSize.width)
            let height = Int(passSize.height)
            // If last pass fully matches the output viewport and the output
            // pixel format, render directly to the final target.
            if i == lastPassIndex, passSize == viewportSize, fmt == outputColorPixelFormat {
                self.pass[i].renderTarget.size = .init(width: width, height: height)
                self.pass[i].renderTarget.view = nil
            } else {
                let td = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: fmt,
                    width: width,
                    height: height,
                    mipmapped: false
                )
                td.storageMode = .private
                td.usage = [.shaderRead, .renderTarget]
                td.resourceOptions = .storageModePrivate
                td.allowGPUOptimizedContents = true
                initTexture(&self.pass[i].renderTarget, withDescriptor: td)
                // textures should be cleared before first use
                if let view = self.pass[i].renderTarget.view {
                    _clearTextures.append(view)
                }

                let label = String(format: "Pass %02d Output", i)
                self.pass[i].renderTarget.view?.label = label
                if self.pass[i].hasFeedback {
                    initTexture(&self.pass[i].feedbackTarget, withDescriptor: td)
                    self.pass[i].feedbackTarget.view?.label = label
                    if let fb = self.pass[i].feedbackTarget.view {
                        _clearTextures.append(fb)
                    }
                }
            }
        }

        renderTargetsNeedResize = false
    }

    private func freeShaderResources() {
        pass = .init(repeating: .init(), count: Constants.maxShaderPasses)
        luts = .init(repeating: .init(), count: Constants.maxTextures)
        historyTextures = .init(repeating: .init(), count: Constants.maxFrameHistory + 1)

        parameters = .init(repeating: 0, count: Constants.maxParameters)
        parametersMap = [:]
        parametersCount = 0

        historyCount = 0
        passCount = 0
        lastPassIndex = 0
        hasShader = false
    }

    public func setCompiledShader(_ container: CompiledShaderContainer) throws {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "ShaderCompile", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.signpostLog, name: "ShaderCompile", signpostID: signpostID) }
        freeShaderResources()

        _ = CACurrentMediaTime()

        let ss = container.shader

        // A malformed/oversized preset must fail GRACEFULLY, not trap. The callers
        // (DOLShaderPostProcessor) wrap setCompiledShader in do/catch and render
        // blank on a throw — but an out-of-bounds index or a duplicate-key
        // Dictionary init is an uncatchable Swift trap (EXC_BREAKPOINT) that
        // crashed the whole app while scrolling the filter preview. Guard the
        // fixed-capacity limits up front and throw instead.
        guard ss.passes.count > 0, ss.passes.count <= Constants.maxShaderPasses else {
            logFilterFailureOnce(
                "setCompiledShader: pass count \(ss.passes.count) out of range (1...\(Constants.maxShaderPasses)); skipping shader"
            )
            throw InitError.invalidShader
        }
        guard ss.luts.count <= Constants.maxTextures else {
            logFilterFailureOnce(
                "setCompiledShader: lut count \(ss.luts.count) exceeds \(Constants.maxTextures); skipping shader"
            )
            throw InitError.invalidShader
        }
        guard ss.parameters.count <= Constants.maxParameters else {
            logFilterFailureOnce(
                "setCompiledShader: parameter count \(ss.parameters.count) exceeds \(Constants.maxParameters); skipping shader"
            )
            throw InitError.invalidShader
        }

        passCount = ss.passes.count
        lastPassIndex = passCount - 1

        parametersCount = ss.parameters.count
        // Keep-first uniquing — `uniqueKeysWithValues:` fatalError-traps on a
        // duplicate parameter name (common in hand-authored / multi-pass presets),
        // which is the strongest candidate for the scroll-far-and-crash report.
        parametersMap = .init(
            ss.parameters.enumerated().map { index, param in (param.name, index) },
            uniquingKeysWith: { first, _ in first }
        )
        parameters = .init(ss.parameters.map { ($0.initial as NSDecimalNumber).floatValue })

        let texStride = MemoryLayout<Texture>.stride
        let texViewOffset = MemoryLayout<Texture>.offset(of: \.view)!
        let texSizeOffset = MemoryLayout<Texture>.offset(of: \.size)!

        // Determine required frame history from usage to avoid under-allocation by containers missing historyCount
        // metadata
        var requiredHistory = 0
        for pass in ss.passes {
            for t in pass.textures where t.semantic == .originalHistory {
                let needed = Int(t.index) + 1
                if needed > requiredHistory {
                    requiredHistory = needed
                }
            }
        }

        // Prepare expected texture bindings map for diagnostics
        expectedTextureBindingsPerPass = Array(repeating: [], count: passCount)

        for passNumber in 0 ..< passCount {
            let sem = ShaderPassSemantics()

            withUnsafePointer(to: &historyTextures[0]) {
                let p = UnsafeRawPointer($0)
                sem.addTexture(
                    p.advanced(by: texViewOffset),
                    size: p.advanced(by: texSizeOffset),
                    semantic: .original
                )

                sem.addTexture(
                    p.advanced(by: texViewOffset),
                    stride: texStride,
                    size: p.advanced(by: texSizeOffset),
                    stride: texStride,
                    semantic: .originalHistory
                )

                if passNumber == 0 {
                    // The source texture for first pass is the original input texture
                    sem.addTexture(
                        p.advanced(by: texViewOffset),
                        size: p.advanced(by: texSizeOffset),
                        semantic: .source
                    )
                }
            }

            if passNumber > 0 {
                // The source texture for passes 1..<n is the output of the previous pass
                withUnsafePointer(to: &pass[passNumber - 1].renderTarget) {
                    let p = UnsafeRawPointer($0)
                    sem.addTexture(
                        p.advanced(by: texViewOffset),
                        size: p.advanced(by: texSizeOffset),
                        semantic: .source
                    )
                }
            }

            withUnsafePointer(to: &pass[0]) {
                let p = UnsafeRawPointer($0)

                let rt = p.advanced(by: MemoryLayout<Pass>.offset(of: \.renderTarget)!)
                sem.addTexture(
                    rt.advanced(by: texViewOffset),
                    stride: MemoryLayout<Pass>.stride,
                    size: rt.advanced(by: texSizeOffset),
                    stride: MemoryLayout<Pass>.stride,
                    semantic: .passOutput
                )

                let ft = p.advanced(by: MemoryLayout<Pass>.offset(of: \.feedbackTarget)!)
                sem.addTexture(
                    ft.advanced(by: texViewOffset),
                    stride: MemoryLayout<Pass>.stride,
                    size: ft.advanced(by: texSizeOffset),
                    stride: MemoryLayout<Pass>.stride,
                    semantic: .passFeedback
                )
            }

            withUnsafePointer(to: &luts[0]) {
                let p = UnsafeRawPointer($0)
                sem.addTexture(
                    p.advanced(by: texViewOffset),
                    stride: texStride,
                    size: p.advanced(by: texSizeOffset),
                    stride: texStride,
                    semantic: .user
                )
            }

            if passNumber == lastPassIndex {
                withUnsafePointer(to: &uniforms.projectionMatrix) {
                    sem.addUniformData(UnsafeRawPointer($0), semantic: .mvp)
                }
            } else {
                withUnsafePointer(to: &uniformsNoRotate.projectionMatrix) {
                    sem.addUniformData(UnsafeRawPointer($0), semantic: .mvp)
                }
            }

            withUnsafePointer(to: &pass[passNumber]) {
                let p = UnsafeRawPointer($0)
                sem.addUniformData(
                    p.advanced(by: MemoryLayout<Pass>.offset(of: \.renderTarget.size)!),
                    semantic: .outputSize
                )
                sem.addUniformData(p.advanced(by: MemoryLayout<Pass>.offset(of: \.frameCount)!), semantic: .frameCount)
                sem.addUniformData(
                    p.advanced(by: MemoryLayout<Pass>.offset(of: \.frameDirection)!),
                    semantic: .frameDirection
                )
            }

            withUnsafePointer(to: &outputFrame.outputSize) {
                sem.addUniformData(UnsafeRawPointer($0), semantic: .finalViewportSize)
            }

            for i in 0 ..< parametersCount {
                withUnsafePointer(to: &parameters[i]) {
                    sem.addUniformData(UnsafeRawPointer($0), forParameterAt: i)
                }
            }

            let bindings = ShaderPassBindings()
            let pass = ss.passes[passNumber]
            // Capture expected bindings for diagnostics (binding index and semantic name)
            self.expectedTextureBindingsPerPass[passNumber] = pass.textures.map { (Int($0.binding), $0.name) }
            try updateBindings(
                passBindings: bindings,
                forPassNumber: passNumber,
                passSemantics: sem,
                pass: pass
            )
            self.pass[passNumber].bindings = bindings
            self.pass[passNumber].format = .init(pass.format)
            // Debug: force all pass formats to BGRA8Unorm
            if UserDefaults.standard.bool(forKey: "shader_debug_force_bgra8") {
                self.pass[passNumber].format = .bgra8Unorm
            }
            // HDR: shader-chain intermediates default to bgra8Unorm, which clamps
            // values >1.0 and discards the EDR signal before the final blit — the
            // reason HDR looked dead with post-processing shaders on. When the output
            // drawable is rgba16Float (HDR), promote every pass target to rgba16Float
            // so the >1.0 signal survives the chain. The pass pipeline below uses this
            // same `format` for its color attachment, so pipeline and render-target
            // stay in sync. Toggling a shader on with HDR already enabled re-runs this
            // (so that path promotes live); a live HDR on/off toggle rebuilds the
            // final-blit pipelines immediately (the EDR boost applies live) and the
            // intermediate promotion re-applies on the next shader (re)load.
            else if outputColorPixelFormat == .rgba16Float {
                self.pass[passNumber].format = .rgba16Float
            }
            self.pass[passNumber].frameCountMod = UInt32(pass.frameCountMod)

            // update scaling
            self.pass[passNumber].scaleX = .init(pass.scaleX)
            self.pass[passNumber].scaleY = .init(pass.scaleY)

            let vd = MTLVertexDescriptor()
            if let attr = vd.attributes[VertexAttribute.position.rawValue] {
                attr.offset = MemoryLayout<Vertex>.offset(of: \.position)!
                attr.format = .float4
                attr.bufferIndex = BufferIndex.positions.rawValue
            }
            if let attr = vd.attributes[VertexAttribute.texCoord.rawValue] {
                attr.offset = MemoryLayout<Vertex>.offset(of: \.texCoord)!
                attr.format = .float2
                attr.bufferIndex = BufferIndex.positions.rawValue
            }
            if let l = vd.layouts[BufferIndex.positions.rawValue] {
                l.stride = MemoryLayout<Vertex>.stride
            }

            let psd = MTLRenderPipelineDescriptor()
            if let alias = pass.alias {
                psd.label = "pass \(passNumber) (\(alias))"
            } else {
                psd.label = "pass \(passNumber)"
            }

            if let ca = psd.colorAttachments[0] {
                ca.pixelFormat = self.pass[passNumber].format
                ca.isBlendingEnabled = false
                ca.sourceAlphaBlendFactor = .sourceAlpha
                ca.sourceRGBBlendFactor = .sourceAlpha
                ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                ca.destinationRGBBlendFactor = .oneMinusSourceAlpha
            }

            // psd.sampleCount = 1
            psd.vertexDescriptor = vd

            let options = MTLCompileOptions()
            options.languageVersion = try MTLLanguageVersion(ss.languageVersion)
            // makeLibrary(source:) THROWS on a shader that fails to compile
            // (bad MSL, unsupported feature) — caught by the caller's do/catch.
            // makeFunction returns an OPTIONAL; if the compiled entry point isn't
            // named "main0", guard rather than feed nil into the descriptor.
            // Hand-written presets (Provenance's native-metal set) name their
            // vertex entry `vertex_main`; slang presets use `main0` for both stages.
            guard let vertexFunction = try MSLSource.makeFunction(
                device: device, source: pass.vertexSource, options: options, names: ["main0", "vertex_main"]
            ) else {
                logFilterFailureOnce(
                    "setCompiledShader: pass \(passNumber) vertex entry point not found; skipping shader"
                )
                throw InitError.invalidShader
            }
            psd.vertexFunction = vertexFunction

            guard let fragmentFunction = try MSLSource.makeFunction(
                device: device, source: pass.fragmentSource, options: options, names: ["main0", "fragment_main"]
            ) else {
                logFilterFailureOnce(
                    "setCompiledShader: pass \(passNumber) fragment entry point not found; skipping shader"
                )
                throw InitError.invalidShader
            }
            psd.fragmentFunction = fragmentFunction

            self.pass[passNumber].state = try device.makeRenderPipelineState(descriptor: psd)

            guard let passBindings = self.pass[passNumber].bindings else {
                logFilterFailureOnce("setCompiledShader: pass \(passNumber) has no bindings; skipping buffer setup")
                continue
            }
            for j in 0 ..< Constants.maxConstantBuffers {
                let sem = passBindings.buffers[j]

                let size = sem.size
                guard size > 0 else { continue }
                #if os(macOS)
                    let opts: MTLResourceOptions = deviceHasUnifiedMemory ? .storageModeShared : .storageModeManaged
                #else
                    let opts: MTLResourceOptions = .storageModeShared
                #endif
                let buf = device.makeBuffer(length: size, options: opts)
                self.pass[passNumber].buffers[j] = buf

                if let binding = sem.bindingVert {
                    self.pass[passNumber].vBuffers[binding] = buf
                }
                if let binding = sem.bindingFrag {
                    self.pass[passNumber].fBuffers[binding] = buf
                }
            }
        }

        // finalise remaining state
        historyCount = max(ss.historyCount, requiredHistory)
        for pass in ss.passes {
            // A malformed preset can carry a pass.index outside 0..<passCount;
            // indexing self.pass with it is an out-of-bounds trap the caller's
            // do/catch can't intercept. Skip the stray entry instead.
            guard pass.index >= 0, pass.index < passCount else {
                logFilterFailureOnce(
                    "setCompiledShader: pass.index \(pass.index) out of range 0..<\(passCount) for feedback flag; ignoring"
                )
                continue
            }
            self.pass[pass.index].hasFeedback = pass.isFeedback
        }

//        let end = CACurrentMediaTime() - start
//        os_log("Shader load completed in %{xcode:interval}f seconds", log: .default, type: .debug, end)

        loadLuts(container)
        hasShader = true
        renderTargetsNeedResize = true
        historyNeedsInit = true

        if historyCount > 0, historyTextures.count < (historyCount + 1) {
            historyTextures = .init(repeating: .init(), count: Constants.maxFrameHistory + 1)
        }

        if !didLogOnce {
            if UserDefaults.standard.object(forKey: "shader_debug_log_once") as? Bool ?? true {
                let lutsCount = container.shader.luts.count
                os_log(
                    "[Shaders] Loaded: passes=%d history=%d luts=%d",
                    log: .default,
                    type: .info,
                    passCount,
                    historyCount,
                    lutsCount
                )
            }
        }
    }

    private func loadLuts(_ cc: CompiledShaderContainer) {
        let opts: [MTKTextureLoader.Option: Any] = [
            .generateMipmaps: false,
            .allocateMipmaps: false,
            .SRGB: false,
            .textureStorageMode: MTLStorageMode.private.rawValue,
        ]

        let images = cc.shader.luts

        var i = 0
        for lut in images {
            let t: MTLTexture
            do {
                let data = try cc.getLUTByName(lut.name)
                if let cgImg = CGContext.makeForTexture(data: data)?.makeImage() {
                    t = try loader.newTexture(cgImage: cgImg, options: opts)
                } else {
                    t = checkers
                }
            } catch {
                os_log(
                    "Unable to load LUT texture, using default. Path '%{public}@: %{public}@",
                    log: .default,
                    type: .error,
                    lut.url.absoluteString,
                    error.localizedDescription
                )
                t = checkers
            }
            initTexture(&luts[i], withTexture: t)
            i += 1
        }
    }

    func updateBindings(
        passBindings: ShaderPassBindings,
        forPassNumber passNumber: Int,
        passSemantics: ShaderPassSemantics,
        pass: Compiled.ShaderPass
    ) throws {
        /// NOTE: every lookup below used to `fatalError`/force-unwrap on a
        /// malformed preset (a uniform referencing a missing parameter index, a
        /// semantic with no registered source, a texture semantic that was never
        /// added). Those are UNCATCHABLE Swift traps — the do/catch around
        /// setCompiledShader can't intercept them, so a single bad shader crashed
        /// the whole app while building its preview in the shader grid. Convert to
        /// a thrown `invalidShader` so the caller skips the shader gracefully.
        func addUniforms(bufferIndex: Int) throws {
            // pass.buffers is a variable-length decoded array (not guaranteed to
            // hold both UBO + Push). An out-of-bounds ARRAY SUBSCRIPT is a fatal
            // trap that `throws` cannot intercept, so guard the count the same way
            // we skip an empty buffer below. A short/malformed preset simply has
            // no descriptor for this slot — skip it.
            guard bufferIndex < pass.buffers.count else { return }
            let desc = pass.buffers[bufferIndex]
            guard desc.size > 0 else { return }

            let bind = passBindings.buffers[bufferIndex]
            bind.bindingVert = desc.bindingVert
            bind.bindingFrag = desc.bindingFrag
            bind.size = (desc.size + 0xF) & ~0xF // round up to nearest 16 bytes

            for u in desc.uniforms {
                switch u.semantic {
                case .floatParameter:
                    guard let index = u.index, let param = passSemantics.parameter(at: index) else {
                        logFilterFailureOnce(
                            "updateBindings: pass \(passNumber) references missing float parameter (index=\(String(describing: u.index)), name=\(u.name)); skipping shader"
                        )
                        throw InitError.invalidShader
                    }
                    bind.addUniformData(
                        param.data,
                        size: u.size,
                        offset: u.offset,
                        name: u.name
                    )

                case .mvp, .outputSize, .finalViewportSize, .frameCount, .frameDirection:
                    guard let sem = passSemantics.uniforms[u.semantic] else {
                        logFilterFailureOnce(
                            "updateBindings: pass \(passNumber) missing uniform semantic \(u.semantic) (name=\(u.name)); skipping shader"
                        )
                        throw InitError.invalidShader
                    }
                    bind.addUniformData(
                        sem.data,
                        size: u.size,
                        offset: u.offset,
                        name: u.name
                    )

                case .originalSize, .sourceSize, .originalHistorySize, .passOutputSize, .passFeedbackSize, .userSize:
                    // Unindexed semantics (SourceSize, OriginalSize) carry no index:
                    // hand-written presets omit it, so treat nil as slot 0.
                    let index = u.index ?? 0
                    guard let tex = passSemantics.textureUniforms[u.semantic] else {
                        logFilterFailureOnce(
                            "updateBindings: pass \(passNumber) missing texture-size semantic \(u.semantic) (index=\(String(describing: u.index)), name=\(u.name)); skipping shader"
                        )
                        throw InitError.invalidShader
                    }
                    bind.addUniformData(
                        tex.size.advanced(by: index * tex.stride),
                        size: u.size,
                        offset: u.offset,
                        name: u.name
                    )
                }
            }
        }

        // UBO
        try addUniforms(bufferIndex: 0)
        // Push
        try addUniforms(bufferIndex: 1)

        for t in pass.textures {
            guard let tex = passSemantics.textures[t.semantic] else {
                logFilterFailureOnce(
                    "updateBindings: pass \(passNumber) references unregistered texture semantic \(t.semantic) (binding=\(t.binding), name=\(t.name)); skipping shader"
                )
                throw InitError.invalidShader
            }
            let bind = passBindings.addTexture(
                tex.texture.advanced(by: t.index * tex.stride),
                binding: t.binding,
                name: t.name
            )
            bind.wrap = .init(t.wrap)
            bind.filter = .init(t.filter)
        }
    }

    public func setValue(_ value: CGFloat, forParameterName name: String) {
        if let index = parametersMap[name] {
            parameters[index] = Float(value)
        }
    }

    public func setValue(_ value: CGFloat, forParameterIndex index: Int) {
        if case 0 ..< parametersCount = index {
            parameters[index] = Float(value)
        }
    }

    public func getValue(forParameterIndex index: Int) -> CGFloat {
        if case 0 ..< parametersCount = index {
            return CGFloat(parameters[index])
        }
        return 0
    }

    typealias SamplerWrapArray<Element> = [Element]
    typealias SamplerFilterArray<Element> = [SamplerWrapArray<Element>]
}

extension FilterChain.SamplerWrapArray {
    subscript(x: ShaderPassWrap) -> Element {
        get { self[x.rawValue] }
        set { self[x.rawValue] = newValue }
    }
}

extension FilterChain.SamplerFilterArray {
    subscript(x: ShaderPassFilter) -> Element {
        get { self[x.rawValue] }
        set { self[x.rawValue] = newValue }
    }
}

// MARK: - Types shared between Metal shaders and Swift

extension FilterChain {
    enum BufferIndex: Int {
        case uniforms = 1
        case positions = 4
    }

    enum VertexAttribute: Int {
        case position = 0
        case texCoord = 1
    }

    enum TextureIndex: Int {
        case color = 0
    }

    enum SamplerIndex: Int {
        case draw = 0
    }

    @frozen @usableFromInline struct Vertex {
        let position: simd_float4
        let texCoord: simd_float2
    }

    @frozen @usableFromInline struct Uniforms {
        /// Field order MUST match the Metal `Uniforms` struct in Shaders.metal
        /// (trailing floats, same order) or the buffer upload misaligns.
        static let empty: Uniforms = .init(
            projectionMatrix: simd_float4x4(),
            outputSize: simd_float2(),
            time: 0,
            brightness: 1,
            gamma: 1,
            hdrBoost: 2.5
        )

        var projectionMatrix: simd_float4x4
        var outputSize: simd_float2
        var time: simd_float1
        var brightness: simd_float1
        var gamma: simd_float1
        var hdrBoost: simd_float1
    }
}

private typealias TextureSize = SIMD4<Float>

extension TextureSize {
    static let zero: Self = .init(x: 0, y: 0, z: 0, w: 0)

    init(width w: Int, height h: Int) {
        self.init(width: CGFloat(w), height: CGFloat(h))
    }

    init(width w: CGFloat, height h: CGFloat) {
        let width = Float(w)
        let height = Float(h)
        self = .init(x: width, y: height, z: 1.0 / width, w: 1.0 / height)
    }
}

private struct Texture {
    var view: MTLTexture?
    var size: TextureSize = .zero
}

public enum MTLLangageVersionError: LocalizedError {
    case versionUnavailable

    public var errorDescription: String? {
        switch self {
        case .versionUnavailable:
            "The specified Metal version is unavailable for this OS or version of OpenEmuShaders"
        }
    }
}

extension MTLLanguageVersion {
    init(_ languageVersion: Compiled.LanguageVersion) throws {
        switch languageVersion {
        case .version2_4:
            if #available(macOS 12.0, iOS 15.0, *) {
                self = .version2_4
            } else {
                throw MTLLangageVersionError.versionUnavailable
            }
        case .version2_3:
            if #available(macOS 11.0, iOS 14.0, *) {
                self = .version2_3
            } else {
                throw MTLLangageVersionError.versionUnavailable
            }
        case .version2_2:
            if #available(macOS 10.15, iOS 13.0, *) {
                self = .version2_2
            } else {
                throw MTLLangageVersionError.versionUnavailable
            }
        case .version2_1:
            self = .version2_1
        }
    }
}

extension MTLPixelFormat {
    // swiftlint:disable cyclomatic_complexity
    init(_ pixelFormat: Compiled.PixelFormat) {
        switch pixelFormat {
        case .r8Unorm:
            self = .r8Unorm
        case .r8Uint:
            self = .r8Uint
        case .r8Sint:
            self = .r8Sint
        case .rg8Unorm:
            self = .rg8Unorm
        case .rg8Uint:
            self = .rg8Uint
        case .rg8Sint:
            self = .rg8Sint
        case .rgba8Unorm:
            self = .rgba8Unorm
        case .rgba8Uint:
            self = .rgba8Uint
        case .rgba8Sint:
            self = .rgba8Sint
        case .rgba8Unorm_srgb:
            self = .rgba8Unorm_srgb
        case .rgb10a2Unorm:
            self = .rgb10a2Unorm
        case .rgb10a2Uint:
            self = .rgb10a2Uint
        case .r16Uint:
            self = .r16Uint
        case .r16Sint:
            self = .r16Sint
        case .r16Float:
            self = .r16Float
        case .rg16Uint:
            self = .rg16Uint
        case .rg16Sint:
            self = .rg16Sint
        case .rg16Float:
            self = .rg16Float
        case .rgba16Uint:
            self = .rgba16Uint
        case .rgba16Sint:
            self = .rgba16Sint
        case .rgba16Float:
            self = .rgba16Float
        case .r32Uint:
            self = .r32Uint
        case .r32Sint:
            self = .r32Sint
        case .r32Float:
            self = .r32Float
        case .rg32Uint:
            self = .rg32Uint
        case .rg32Sint:
            self = .rg32Sint
        case .rg32Float:
            self = .rg32Float
        case .rgba32Uint:
            self = .rgba32Uint
        case .rgba32Sint:
            self = .rgba32Sint
        case .rgba32Float:
            self = .rgba32Float
        case .bgra8Unorm_srgb:
            self = .bgra8Unorm_srgb
        case .bgra8Unorm:
            self = .bgra8Unorm
        }
    }

    /// Returns the number of bytes per pixel for the given format; otherwise, 0 if the format is not supported
    var bytesPerPixel: Int {
        switch self {
        case .a8Unorm, .r8Unorm, .r8Unorm_srgb, .r8Snorm, .r8Uint, .r8Sint:
            1

        case .r16Unorm, .r16Snorm, .r16Uint, .r16Sint, .r16Float:
            2

        case .rg8Unorm, .rg8Unorm_srgb, .rg8Snorm, .rg8Uint, .rg8Sint, .b5g6r5Unorm, .a1bgr5Unorm, .abgr4Unorm,
             .bgr5A1Unorm:
            2

        case .r32Uint, .r32Sint, .r32Float, .rg16Unorm, .rg16Snorm, .rg16Uint, .rg16Sint, .rg16Float, .rgba8Unorm,
             .rgba8Unorm_srgb, .rgba8Snorm, .rgba8Uint, .rgba8Sint, .bgra8Unorm, .bgra8Unorm_srgb, .rgb10a2Unorm,
             .rgb10a2Uint, .rg11b10Float, .rgb9e5Float, .bgr10a2Unorm, .bgr10_xr, .bgr10_xr_srgb:
            4

        case .rg32Uint, .rg32Sint, .rg32Float, .rgba16Unorm, .rgba16Snorm, .rgba16Uint, .rgba16Sint, .rgba16Float,
             .bgra10_xr, .bgra10_xr_srgb:
            8

        case .rgba32Uint, .rgba32Sint, .rgba32Float:
            16

        case .invalid:
            0

        default:
            0
        }
    }
}

extension CGContext {
    /// Returns a context using the dimensions and contents from the image identified by the data.
    /// The context data format is compatible with BGRA8
    /// - Parameter data: The data of the source image.
    /// - Returns: a new ``CGContext`` with dimensions and contents matching the source image.
    static func makeForTexture(data: Data) -> CGContext? {
        guard
            let src = CGImageSourceCreateWithData(data as CFData, nil),
            let img = CGImageSourceCreateImageAtIndex(src, CGImageSourceGetPrimaryImageIndex(src), nil)
        else { return nil }

        guard let context = CGContext(
            data: nil,
            width: img.width,
            height: img.height,
            bitsPerComponent: 8,
            bytesPerRow: img.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo
                .premultipliedFirst.rawValue
        )
        else { return nil }

        context.interpolationQuality = .none
        context.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))

        return context
    }
}
