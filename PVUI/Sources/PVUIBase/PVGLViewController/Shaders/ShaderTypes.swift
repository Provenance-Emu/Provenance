import Foundation
import simd
import Metal
import MetalKit

struct LCDFilterUniforms {
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
