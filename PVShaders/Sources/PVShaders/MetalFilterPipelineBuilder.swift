import Foundation
import Metal

public enum MetalFilterPipelineBuilder {
    public static func makePipeline(
        device: MTLDevice,
        shader: Shader,
        vertexShader: Shader,
        pixelFormat: MTLPixelFormat,
        flipY: Bool
    ) throws -> MTLRenderPipelineState {
        let constants = MTLFunctionConstantValues()
        var flipValue = flipY
        constants.setConstantValue(&flipValue, type: .bool, withName: "FlipY")

        let library = try device.makeDefaultLibrary(bundle: MetalShaderManager.shared.shaderBundle)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = try library.makeFunction(name: vertexShader.function, constantValues: constants)
        descriptor.fragmentFunction = library.makeFunction(name: shader.function)
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}
