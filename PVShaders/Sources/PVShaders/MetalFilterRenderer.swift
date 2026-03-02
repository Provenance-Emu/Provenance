import Foundation
import Metal
import simd
import CoreGraphics
import QuartzCore
import PVLogging
import PVPrimitives
import PVSettings
import Defaults

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
    private var startTime: CFTimeInterval = CACurrentMediaTime()

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
        startTime = CACurrentMediaTime()
    }

    public func encode(with encoder: MTLRenderCommandEncoder,
                       texture: MTLTexture,
                       drawableSize: CGSize,
                       sourceSize: CGSize,
                       screenType: ScreenTypeObjC,
                       smoothingEnabled: Bool,
                       setViewport: Bool = true) -> Bool {
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

        if setViewport {
            let viewport = MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(drawableSize.width),
                height: Double(drawableSize.height),
                znear: 0.0,
                zfar: 1.0
            )
            encoder.setViewport(viewport)
        }
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
                               texture: texture,
                               screenType: screenType)

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
                                        texture: MTLTexture,
                                        screenType: ScreenTypeObjC) {
        guard let shaderName = activeShader?.name else {
            return
        }

        let drawableWidth = max(Float(drawableSize.width), 1)
        let drawableHeight = max(Float(drawableSize.height), 1)
        let textureWidth = max(Float(texture.width), 1)
        let textureHeight = max(Float(texture.height), 1)
        let providedSourceWidth = Float(sourceSize.width)
        let providedSourceHeight = Float(sourceSize.height)
        let sourceWidth = providedSourceWidth > 0 ? providedSourceWidth : textureWidth
        let sourceHeight = providedSourceHeight > 0 ? providedSourceHeight : textureHeight
        let sourceVector = SIMD4<Float>(sourceWidth,
                                        sourceHeight,
                                        1.0 / sourceWidth,
                                        1.0 / sourceHeight)
        let outputVector = SIMD4<Float>(drawableWidth,
                                        drawableHeight,
                                        1.0 / drawableWidth,
                                        1.0 / drawableHeight)
        let elapsedTime = Float(CACurrentMediaTime() - startTime)

        switch shaderName {
        case "Simple CRT":
            // TODO: Cache these values when the dynamic shader parameter system is adopted;
            // reading Defaults per frame is acceptable for now given infrequent user changes.
            var uniforms = SimpleCRTUniforms(
                dstRect: SIMD4<Float>(textureWidth, textureHeight, drawableWidth, drawableHeight),
                srcRect: SIMD4<Float>(0, 0, sourceWidth, sourceHeight),
                curvVert: Defaults[.simpleCRTCurvVert],
                curvHoriz: Defaults[.simpleCRTCurvHoriz],
                curvStrength: Defaults[.simpleCRTCurvStrength],
                lightBoost: Defaults[.simpleCRTLightBoost],
                vignStrength: Defaults[.simpleCRTVignStrength],
                zoomOut: Defaults[.simpleCRTZoomOut],
                brightness: Defaults[.simpleCRTBrightness]
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SimpleCRTUniforms>.stride, index: 0)

        case "CRT", "Complex CRT":
            var uniforms = CRTUniforms(
                displayRect: SIMD4<Float>(0, 0, sourceWidth, sourceHeight),
                emulatedImageSize: SIMD2<Float>(textureWidth, textureHeight),
                finalRes: SIMD2<Float>(drawableWidth, drawableHeight),
                bloomAmount: Defaults[.complexCRTBloomAmount],
                scanlineHardness: Defaults[.complexCRTScanlineHardness],
                shadowMaskHardness: Defaults[.complexCRTShadowMaskHardness],
                rowsOfResolution: Defaults[.complexCRTRowsOfResolution],
                tvl: Defaults[.complexCRTTVL],
                warpX: Defaults[.complexCRTWarpX],
                warpY: Defaults[.complexCRTWarpY],
                displayGamma: Defaults[.complexCRTDisplayGamma],
                useScanlines: Defaults[.complexCRTUseScanlines] ? 1 : 0,
                useShadowMask: Defaults[.complexCRTUseShadowMask] ? 1 : 0,
                useWarp: Defaults[.complexCRTUseWarp] ? 1 : 0
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

        case "Mega Tron":
            var uniforms = MegaTronUniforms(
                sourceSize: sourceVector,
                outputSize: outputVector,
                mask: 1.0,
                maskIntensity: 0.25,
                scanlineThinness: 0.35,
                scanBlur: -0.45,
                curvature: 0.08,
                trinitronCurve: 0.12,
                corner: 0.012,
                crtGamma: 2.15
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MegaTronUniforms>.stride, index: 0)

        case "ulTron":
            var uniforms = UltronUniforms(
                sourceSize: sourceVector,
                outputSize: outputVector,
                hardScan: 3.2,
                hardPix: 1.6,
                warpX: 0.008,
                warpY: 0.012,
                maskDark: 0.7,
                maskLight: 1.05,
                shadowMask: 2.0,
                brightBoost: 0.95,
                hardBloomScan: 0.8,
                hardBloomPix: 0.7,
                bloomAmount: 0.08,
                shape: 1.35
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<UltronUniforms>.stride, index: 0)

        case "VHS":
            var uniforms = VHSUniforms(
                sourceSize: sourceVector,
                outputSize: outputVector,
                time: elapsedTime,
                noiseAmount: 0.06,
                scanlineJitter: 0.0025,
                colorBleed: 1.5,
                trackingNoise: 0.2,
                tapeWobble: 0.0035,
                ghosting: 0.35,
                vignette: 0.45
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VHSUniforms>.stride, index: 0)

        case "Game Boy":
            let palette = GameBoyPalette.defaultPalette(for: screenType)
            var uniforms = GameBoyUniforms(
                sourceSize: sourceVector,
                outputSize: outputVector,
                dotMatrix: 0.75,
                contrast: 1.25,
                ghost: 0.4,
                scanlineDepth: 0.25,
                padding: 0,
                palette0: palette[0],
                palette1: palette[1],
                palette2: palette[2],
                palette3: palette[3]
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GameBoyUniforms>.stride, index: 0)

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

/// Must match `CRT_Data` struct layout in crt_filter_ps.metal exactly.
/// All fields are 4-byte aligned; Int32 maps to Metal's `int`.
private struct CRTUniforms {
    var displayRect: SIMD4<Float>
    var emulatedImageSize: SIMD2<Float>
    var finalRes: SIMD2<Float>
    var bloomAmount: Float
    var scanlineHardness: Float
    var shadowMaskHardness: Float
    var rowsOfResolution: Float
    var tvl: Float
    var warpX: Float
    var warpY: Float
    var displayGamma: Float
    var useScanlines: Int32
    var useShadowMask: Int32
    var useWarp: Int32
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

private struct MegaTronUniforms {
    var sourceSize: SIMD4<Float>
    var outputSize: SIMD4<Float>
    var mask: Float
    var maskIntensity: Float
    var scanlineThinness: Float
    var scanBlur: Float
    var curvature: Float
    var trinitronCurve: Float
    var corner: Float
    var crtGamma: Float
}

private struct UltronUniforms {
    var sourceSize: SIMD4<Float>
    var outputSize: SIMD4<Float>
    var hardScan: Float
    var hardPix: Float
    var warpX: Float
    var warpY: Float
    var maskDark: Float
    var maskLight: Float
    var shadowMask: Float
    var brightBoost: Float
    var hardBloomScan: Float
    var hardBloomPix: Float
    var bloomAmount: Float
    var shape: Float
}

private struct VHSUniforms {
    var sourceSize: SIMD4<Float>
    var outputSize: SIMD4<Float>
    var time: Float
    var noiseAmount: Float
    var scanlineJitter: Float
    var colorBleed: Float
    var trackingNoise: Float
    var tapeWobble: Float
    var ghosting: Float
    var vignette: Float
}

private struct GameBoyUniforms {
    var sourceSize: SIMD4<Float>
    var outputSize: SIMD4<Float>
    var dotMatrix: Float
    var contrast: Float
    var ghost: Float
    var scanlineDepth: Float
    var padding: Float
    var palette0: SIMD4<Float>
    var palette1: SIMD4<Float>
    var palette2: SIMD4<Float>
    var palette3: SIMD4<Float>
}

public enum GameBoyPalette {
    public static func defaultPalette(for screenType: ScreenTypeObjC) -> [SIMD4<Float>] {
        // Slightly adjust palette for LCD-based systems
        let base: [SIMD3<Float>]
        if screenType == .dotMatrix || screenType == .monochromaticLCD {
            base = [
                SIMD3<Float>(0.039, 0.133, 0.086),
                SIMD3<Float>(0.184, 0.325, 0.2),
                SIMD3<Float>(0.502, 0.659, 0.369),
                SIMD3<Float>(0.824, 0.898, 0.549)
            ]
        } else {
            base = [
                SIMD3<Float>(0.05, 0.12, 0.1),
                SIMD3<Float>(0.25, 0.38, 0.18),
                SIMD3<Float>(0.55, 0.68, 0.4),
                SIMD3<Float>(0.86, 0.93, 0.58)
            ]
        }
        return base.map { SIMD4<Float>($0, 1.0) }
    }
}
