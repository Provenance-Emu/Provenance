import Foundation
import Metal
import MetalKit
import Accelerate
import SwiftUI
import PVCoreAudio

/// A Metal-based renderer for audio waveform visualization with retrowave aesthetics
@available(iOS 14.0, *)
public class MetalWaveformRenderer {
    // Metal objects
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    
    // Audio data
    private var audioData: [Float] = []
    private var processedData: [Float] = []
    private var fftData: [Float] = []
    
    // Configuration
    private let maxPoints: Int
    private let amplificationFactor: Float
    
    // FFT setup
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int
    
    // Time-based animation
    private var time: Float = 0
    
    // Shader uniforms
    struct Uniforms {
        var time: Float
        var amplification: Float
        var primaryColor: SIMD4<Float>
        var secondaryColor: SIMD4<Float>
    }
    
    public init(maxPoints: Int = 128, amplificationFactor: Float = 1.0) {
        self.maxPoints = maxPoints
        self.amplificationFactor = amplificationFactor
        self.fftSize = maxPoints * 2
        
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Initialize FFT
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(fftSize), .FORWARD)
        
        // Create pipeline state with embedded shaders
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        // Shader uniforms
        struct Uniforms {
            float time;
            float amplification;
            float4 primaryColor;
            float4 secondaryColor;
        };
        
        // Vertex shader output and fragment shader input
        struct VertexOut {
            float4 position [[position]];
            float4 color;
            float2 texCoord;
        };
        
        // Vertex shader
        vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                     constant float* vertices [[buffer(0)]],
                                     constant Uniforms& uniforms [[buffer(1)]]) {
            VertexOut out;
        
            // Get vertex position
            float x = vertices[vertexID * 2];
            float y = vertices[vertexID * 2 + 1] * uniforms.amplification;
            float2 position = float2(x, y);
        
            // Apply some animation based on time
            float wave = sin(uniforms.time * 2.0 + position.x * 10.0) * 0.05;
            position.y += wave;
        
            // Output position
            out.position = float4(position.x, position.y, 0.0, 1.0);
        
            // Calculate color based on position and time
            float colorMix = (sin(uniforms.time + position.x * 3.0) + 1.0) * 0.5;
            out.color = mix(uniforms.primaryColor, uniforms.secondaryColor, colorMix);
        
            // Pass texture coordinates
            float x_coord = (position.x + 1.0) * 0.5;
            float y_coord = (position.y + 1.0) * 0.5;
            out.texCoord = float2(x_coord, y_coord);
        
            return out;
        }
        
        // Helper function for creating a neon glow effect
        float neonGlow(float dist, float thickness, float glow) {
            float innerGlow = smoothstep(thickness, 0.0, dist) * 0.5;
            float outerGlow = smoothstep(thickness + glow, thickness, dist) * 0.5;
            return innerGlow + outerGlow;
        }
        
        // Fragment shader
        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                      constant Uniforms& uniforms [[buffer(0)]]) {
            // Base color from vertex shader
            float4 color = in.color;
        
            // Add time-based pulsing effect
            float pulse = (sin(uniforms.time * 3.0) + 1.0) * 0.5 * 0.3 + 0.7;
            color.rgb *= pulse;
        
            // Add scanline effect for retrowave look
            float scanline = sin(in.texCoord.y * 100.0 + uniforms.time * 5.0) * 0.5 + 0.5;
            color.rgb *= mix(0.8, 1.0, scanline);
        
            // Add grid effect
            float2 grid = fract(in.texCoord * 20.0);
            float gridLine = step(0.95, grid.x) + step(0.95, grid.y);
            color.rgb = mix(color.rgb, float3(1.0, 0.5, 1.0), gridLine * 0.1);
        
            // Add glow effect
            float dist = length(float2(0.5) - fract(in.texCoord * 10.0));
            float glow = neonGlow(dist, 0.1, 0.3);
            color.rgb += uniforms.secondaryColor.rgb * glow * 0.5;
        
            return color;
        }
        """
        
        // Create a custom library with our shader code
        var library: MTLLibrary?
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("Error creating Metal library: \(error)")
            fatalError("Failed to create Metal library")
        }
        
        guard let vertexFunction = library?.makeFunction(name: "vertexShader"),
              let fragmentFunction = library?.makeFunction(name: "fragmentShader") else {
            fatalError("Failed to create shader functions")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
        
        // Initialize buffers
        createBuffers()
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
    
    private func createBuffers() {
        // Create vertex buffer
        let vertexData = [Float](repeating: 0, count: maxPoints * 2)
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.stride, options: [])
        
        // Create uniform buffer
        let uniforms = Uniforms(
            time: 0,
            amplification: amplificationFactor,
            primaryColor: SIMD4<Float>(1.0, 0.2, 0.8, 1.0), // Pink
            secondaryColor: SIMD4<Float>(0.0, 0.8, 1.0, 1.0) // Cyan
        )
        uniformBuffer = device.makeBuffer(bytes: [uniforms], length: MemoryLayout<Uniforms>.stride, options: [])
    }
    
    /// Update the audio data and process it for visualization
    public func updateAudioData(_ waveformData: WaveformData) {
        // Convert to Float array
        audioData = waveformData.amplitudes.map { Float($0) }
        
        // Ensure we have enough data
        if audioData.count < maxPoints {
            audioData = Array(repeating: 0, count: maxPoints)
        } else if audioData.count > maxPoints {
            audioData = Array(audioData.prefix(maxPoints))
        }
        
        // Apply FFT to get frequency data
        performFFT()
        
        // Process the data for visualization
        processAudioData()
        
        // Update the vertex buffer with new data
        updateVertexBuffer()
    }
    
    /// Perform Fast Fourier Transform on the audio data
    private func performFFT() {
        // Prepare real and imaginary parts
        var realParts = audioData
        var imaginaryParts = [Float](repeating: 0, count: fftSize)
        
        // Apply window function to reduce spectral leakage
        var window = [Float](repeating: 0, count: audioData.count)
        vDSP_hann_window(&window, vDSP_Length(audioData.count), Int32(0))
        vDSP_vmul(audioData, 1, window, 1, &realParts, 1, vDSP_Length(audioData.count))
        
        // Perform FFT
        if let fftSetup = fftSetup {
            // Create temporary arrays for output to avoid overlapping accesses
            var outputReal = [Float](repeating: 0, count: fftSize)
            var outputImag = [Float](repeating: 0, count: fftSize)
            
            // Execute FFT with separate input and output buffers
            vDSP_DFT_Execute(fftSetup, &realParts, &imaginaryParts, &outputReal, &outputImag)
            
            // Copy results back
            realParts = outputReal
            imaginaryParts = outputImag
        }
        
        // Create a DSPSplitComplex structure for magnitude calculation
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imaginaryParts)
        
        // Calculate magnitude
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // Convert to dB scale and normalize
        var normalizedMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_vdbcon(magnitudes, 1, [1.0], &normalizedMagnitudes, 1, vDSP_Length(fftSize / 2), 1)
        
        // Clip to reasonable range and normalize to 0-1
        var min: Float = -50.0
        var max: Float = 0.0
        vDSP_vclip(normalizedMagnitudes, 1, &min, &max, &normalizedMagnitudes, 1, vDSP_Length(fftSize / 2))
        vDSP_vsmsa(normalizedMagnitudes,
                   1,
                   [Float(1.0 / 50.0)],
                   [1.0],
                   &normalizedMagnitudes,
                   1,
                   vDSP_Length(fftSize / 2))
        
        // Store FFT data
        fftData = normalizedMagnitudes
    }
    
    /// Process the audio data for visualization
    private func processAudioData() {
        // The audio data now contains frequency spectrum information
        // We need to process it for visualization
        processedData = [Float](repeating: 0, count: maxPoints)
        
        // Apply amplification to make the visualization more visible
        for i in 0..<min(maxPoints, audioData.count) {
            // Apply non-linear scaling to emphasize both low and high values
            // This helps make the visualization more dynamic
            let value = audioData[i]
            let scaledValue = pow(value, 0.5) * amplificationFactor
            processedData[i] = scaledValue
        }
        
        // Apply smoothing between adjacent frequency bins
        var smoothedData = [Float](repeating: 0, count: maxPoints)
        let smoothingFactor: Float = 0.3
        
        for i in 0..<maxPoints {
            if i == 0 {
                smoothedData[i] = processedData[i]
            } else {
                smoothedData[i] = smoothedData[i-1] * (1 - smoothingFactor) + processedData[i] * smoothingFactor
            }
        }
        
        // Apply temporal smoothing to prevent rapid changes
        let temporalSmoothingFactor: Float = 0.7
        for i in 0..<maxPoints {
            if i < processedData.count {
                processedData[i] = processedData[i] * temporalSmoothingFactor + smoothedData[i] * (1 - temporalSmoothingFactor)
            }
        }
    }
    
    /// Update the vertex buffer with new audio data
    private func updateVertexBuffer() {
        guard let vertexBuffer = vertexBuffer else { return }
        
        var vertices = [Float](repeating: 0, count: maxPoints * 2)
        
        // Convert processed data to vertices
        for i in 0..<maxPoints {
            let x = Float(i) / Float(maxPoints - 1) * 2 - 1 // -1 to 1
            let y = processedData[i]
            
            vertices[i * 2] = x
            vertices[i * 2 + 1] = y
        }
        
        // Copy to buffer
        let bufferPointer = vertexBuffer.contents().bindMemory(to: Float.self, capacity: vertices.count)
        for i in 0..<vertices.count {
            bufferPointer[i] = vertices[i]
        }
    }
    
    /// Update time-based animation
    public func update(deltaTime: Float) {
        time += deltaTime
        
        // Update uniform buffer with new time
        guard let uniformBuffer = uniformBuffer else { return }
        let bufferPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        bufferPointer.pointee.time = time
    }
    
    /// Render the waveform to the provided Metal texture
    public func render(to texture: MTLTexture) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        // Set up render pass
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Create encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set pipeline state and buffers
        renderEncoder.setRenderPipelineState(pipelineState)
        if let vertexBuffer = vertexBuffer {
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        }
        if let uniformBuffer = uniformBuffer {
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        }
        
        // Draw line strip
        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: maxPoints)
        
        // End encoding and commit
        renderEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    /// Set the colors for the waveform visualization
    public func setColors(primary: Color, secondary: Color) {
        guard let uniformBuffer = uniformBuffer else { return }
        
        let primaryComponents = primary.cgColor?.components ?? [1, 0.2, 0.8, 1]
        let secondaryComponents = secondary.cgColor?.components ?? [0, 0.8, 1, 1]
        
        let primaryColor = SIMD4<Float>(
            Float(primaryComponents[0]),
            Float(primaryComponents[1]),
            Float(primaryComponents[2]),
            Float(primaryComponents[3])
        )
        
        let secondaryColor = SIMD4<Float>(
            Float(secondaryComponents[0]),
            Float(secondaryComponents[1]),
            Float(secondaryComponents[2]),
            Float(secondaryComponents[3])
        )
        
        let bufferPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        bufferPointer.pointee.primaryColor = primaryColor
        bufferPointer.pointee.secondaryColor = secondaryColor
    }
}
