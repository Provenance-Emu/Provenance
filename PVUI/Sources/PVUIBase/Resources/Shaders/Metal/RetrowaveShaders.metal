#include <metal_stdlib>
#import <simd/SIMD.h>

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
