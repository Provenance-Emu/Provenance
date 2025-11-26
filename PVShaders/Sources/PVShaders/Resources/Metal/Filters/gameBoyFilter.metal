//
//  gameBoyFilter.metal
//  Provenance
//
//  Created by Joseph Mattiello on 2024.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

#include <metal_stdlib>
#import "../MetalViewShaders.h"

using namespace metal;

struct GameBoyUniforms {
    float4 SourceSize;      /// x,y = size, z,w = 1/size
    float4 OutputSize;      /// x,y = size, z,w = 1/size
    float dotMatrix;        /// Dot matrix effect intensity (0.0-1.0)
    float contrast;         /// Screen contrast adjustment
    float ghost;            /// Horizontal ghosting amount
    float scanlineDepth;    /// Scanline strength
    float padding;          /// Alignment padding
    float4 palette[4];      /// Classic Game Boy palette entries
};

inline float hashNoise(float2 coord) {
    return fract(sin(dot(coord, float2(12.9898, 78.233))) * 43758.5453);
}

fragment float4
gameBoyFilter(Outputs in [[stage_in]],
              constant GameBoyUniforms& uniforms [[buffer(0)]],
              texture2d<float> texture [[texture(0)]],
              sampler textureSampler [[sampler(0)]])
{
    float2 pixelPos = in.fTexCoord * uniforms.SourceSize.xy;
    float2 sampleCoord = (floor(pixelPos) + 0.5) * uniforms.SourceSize.zw;
    float4 baseSample = texture.sample(textureSampler, sampleCoord);

    // Horizontal ghosting
    float2 ghostCoord = sampleCoord - float2(uniforms.SourceSize.z * 1.5, 0.0);
    float ghostSample = texture.sample(textureSampler, ghostCoord).r;

    // Convert to grayscale with ghost blending
    float gray = dot(baseSample.rgb, float3(0.299, 0.587, 0.114));
    gray = mix(gray, (gray + ghostSample) * 0.5, saturate(uniforms.ghost));

    // Apply contrast curve
    gray = clamp((gray - 0.5) * uniforms.contrast + 0.5, 0.0, 1.0);

    // Quantize to four palette entries
    int index = int(clamp(gray * 3.999, 0.0, 3.999));
    float4 gbColor = uniforms.palette[index];

    // Apply scanline shading
    const float PI = 3.14159265358979323846;
    float scanPhase = sin(pixelPos.y * PI);
    float scan = mix(1.0, 0.7 + 0.3 * scanPhase * scanPhase, uniforms.scanlineDepth);
    gbColor.rgb *= scan;

    // Dot matrix mask
    float2 dotPhase = fract(pixelPos * 0.5);
    float dotMask = smoothstep(0.35, 0.1, distance(dotPhase, float2(0.5)));
    gbColor.rgb *= mix(1.0, dotMask, uniforms.dotMatrix);

    // Subtle LCD noise
    float noise = (hashNoise(pixelPos + uniforms.SourceSize.xy) - 0.5) * 0.05;
    gbColor.rgb += noise;

    return saturate(gbColor);
}
