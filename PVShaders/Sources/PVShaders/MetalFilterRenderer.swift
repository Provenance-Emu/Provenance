import Foundation
import Metal
import simd
import CoreGraphics
import PVLogging
import PVPrimitives

@objcMembers
public final class PVMetalFilterRenderer: NSObject {
    private var device: MTLDevice?
    private var pixelFormat: MTLPixelFormat = .bgra8Unorm
    private var flipY: Bool = false

    private var pipelineState: MTLRenderPipelineState?
    private var activeShader: Shader?
    private var vertexShader: Shader?
    private var samplerLinear: MTLSamplerState?
    private var samplerNearest: MTLSamplerState?

    private var cachedScreenType: ScreenTypeObjC = .unknown

    private let quadVertices: [Float] = [
        -1.0, -1.0, 0.0, 0.0, 0.0,
         1.0, -1.0, 0.0, 1.0, 0.0,
        -1.0,  1.0, 0.0, 0.0, 1.0,
         1.0,  1.0, 0.0, 1.0, 1.0
    ]

    public func configure(device: MTLDevice, pixelFormat: MTLPixelFormat, flipYAxis: Bool) {
        self.device = device
        self.pixelFormat = pixelFormat
        self.flipY = flipYAxis
        self.vertexShader = MetalShaderManager.shared.vertexShaders.first(where: { $0.name == "Fullscreen" })
        pipelineState = nil
        activeShader = nil
        samplerLinear = nil
        samplerNearest = nil
        cachedScreenType = .unknown
    }

    public func encode(with encoder: MTLRenderCommandEncoder,
                       texture: MTLTexture,
                       drawableSize: CGSize,
                       sourceSize: CGSize,
                       screenType: ScreenTypeObjC,
                       smoothingEnabled: Bool) -> Bool {
        guard let device = device else {
            return false
        }

        guard configurePipelineIfNeeded(screenType: screenType) else {
            return false
        }

        guard let pipelineState = pipelineState else {
            return false
        }

        ensureSamplersIfNeeded(device: device)

        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(drawableSize.width),
            height: Double(drawableSize.height),
            znear: 0.0,
            zfar: 1.0
        )
        encoder.setViewport(viewport)
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBytes(quadVertices,
                               length: quadVertices.count * MemoryLayout<Float>.size,
                               index: 0)
        encoder.setFragmentTexture(texture, index: 0)

        if smoothingEnabled, let sampler = samplerLinear {
            encoder.setFragmentSamplerState(sampler, index: 0)
        } else if let sampler = samplerNearest {
            encoder.setFragmentSamplerState(sampler, index: 0)
        }

        encodeUniformsIfNeeded(encoder: encoder,
                               drawableSize: drawableSize,
                               sourceSize: sourceSize,
                               texture: texture)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        return true
    }

    private func ensureSamplersIfNeeded(device: MTLDevice) {
        if samplerLinear == nil {
            let descriptor = MTLSamplerDescriptor()
            descriptor.minFilter = .linear
            descriptor.magFilter = .linear
            descriptor.sAddressMode = .clampToEdge
            descriptor.tAddressMode = .clampToEdge
            samplerLinear = device.makeSamplerState(descriptor: descriptor)
        }

        if samplerNearest == nil {
            let descriptor = MTLSamplerDescriptor()
            descriptor.minFilter = .nearest
            descriptor.magFilter = .nearest
            descriptor.sAddressMode = .clampToEdge
            descriptor.tAddressMode = .clampToEdge
            samplerNearest = device.makeSamplerState(descriptor: descriptor)
        }
    }

    private func configurePipelineIfNeeded(screenType: ScreenTypeObjC) -> Bool {
        guard let device = device else {
            return false
        }

        guard let shader = MetalShaderManager.shared.currentFilterShader(for: screenType) else {
            pipelineState = nil
            activeShader = nil
            cachedScreenType = screenType
            return false
        }

        let needsRebuild = shader.name != activeShader?.name
            || pipelineState == nil
            || cachedScreenType != screenType

        guard needsRebuild else {
            return true
        }

        guard let vertexShader = vertexShader else {
            return false
        }

        do {
            pipelineState = try MetalFilterPipelineBuilder.makePipeline(
                device: device,
                shader: shader,
                vertexShader: vertexShader,
                pixelFormat: pixelFormat,
                flipY: flipY
            )
            activeShader = shader
            cachedScreenType = screenType
            return true
        } catch {
            ELOG("Failed to create filter pipeline: \(error)")
            pipelineState = nil
            activeShader = nil
            return false
        }
    }

    private func encodeUniformsIfNeeded(encoder: MTLRenderCommandEncoder,
                                        drawableSize: CGSize,
                                        sourceSize: CGSize,
                                        texture: MTLTexture) {
        guard let shaderName = activeShader?.name else {
            return
        }

        let drawableWidth = Float(drawableSize.width)
        let drawableHeight = Float(drawableSize.height)
        let sourceWidth = Float(sourceSize.width)
        let sourceHeight = Float(sourceSize.height)
        let textureWidth = Float(texture.width)
        let textureHeight = Float(texture.height)

        switch shaderName {
        case "Simple CRT":
            var uniforms = SimpleCRTUniforms(
                dstRect: SIMD4<Float>(textureWidth, textureHeight, drawableWidth, drawableHeight),
                srcRect: SIMD4<Float>(0, 0, sourceWidth, sourceHeight),
                curvVert: 5.0,
                curvHoriz: 4.0,
                curvStrength: 0.25,
                lightBoost: 1.3,
                vignStrength: 0.05,
                zoomOut: 1.1,
                brightness: 1.0
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SimpleCRTUniforms>.stride, index: 0)

        case "CRT", "Complex CRT":
            var uniforms = CRTUniforms(
                displayRect: SIMD4<Float>(0, 0, sourceWidth, sourceHeight),
                emulatedImageSize: SIMD2<Float>(textureWidth, textureHeight),
                finalRes: SIMD2<Float>(drawableWidth, drawableHeight)
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CRTUniforms>.stride, index: 0)

        case "LCD":
            var uniforms = LCDFilterUniforms(
                screenRect: SIMD4<Float>(0, 0, sourceWidth, sourceHeight),
                textureSize: SIMD2<Float>(textureWidth, textureHeight),
                gridDensity: 1.0,
                gridBrightness: 0.35,
                contrast: 1.2,
                saturation: 1.1,
                ghosting: 0.1,
                scanlineDepth: 0.25,
                bloomAmount: 0.15,
                colorLow: 0.45,
                colorHigh: 1.0
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LCDFilterUniforms>.stride, index: 0)

        default:
            break
        }
    }
}

private struct SimpleCRTUniforms {
    var dstRect: SIMD4<Float>
    var srcRect: SIMD4<Float>
    var curvVert: Float
    var curvHoriz: Float
    var curvStrength: Float
    var lightBoost: Float
    var vignStrength: Float
    var zoomOut: Float
    var brightness: Float
}

private struct CRTUniforms {
    var displayRect: SIMD4<Float>
    var emulatedImageSize: SIMD2<Float>
    var finalRes: SIMD2<Float>
}

private struct LCDFilterUniforms {
    var screenRect: SIMD4<Float>
    var textureSize: SIMD2<Float>
    var gridDensity: Float
    var gridBrightness: Float
    var contrast: Float
    var saturation: Float
    var ghosting: Float
    var scanlineDepth: Float
    var bloomAmount: Float
    var colorLow: Float
    var colorHigh: Float
}
