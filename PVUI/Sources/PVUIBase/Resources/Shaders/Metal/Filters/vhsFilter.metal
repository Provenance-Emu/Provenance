//
//  vhsFilter.metal
//  Provenance
//
//  Created by Joseph Mattiello on 2024.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

#include <metal_stdlib>
#import "../MetalViewShaders.h"

using namespace metal;

struct VHSUniforms {
    float4 SourceSize;      /// x,y = size, z,w = 1/size
    float4 OutputSize;      /// x,y = size, z,w = 1/size
    float time;            /// Current time for animated effects
    float noiseAmount;     /// Static noise intensity
    float scanlineJitter;  /// Horizontal line displacement
    float colorBleed;      /// Vertical color bleeding
    float trackingNoise;   /// Vertical noise bands
    float tapeWobble;      /// Horizontal wobble amount
    float ghosting;        /// Double-image effect
    float vignette;        /// Screen edge darkening
};

// Hash function for noise generation
float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(443.897, 441.423, 437.195));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

// Generate noise pattern
float noise(float2 p, float time) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float2 pos = i + f;
    return hash(pos * time);
}

fragment float4
vhsFilter(Outputs in [[stage_in]],
          constant VHSUniforms& uniforms [[buffer(0)]],
          texture2d<float> texture [[texture(0)]],
          sampler textureSampler [[sampler(0)]])
{
    float2 texCoord = in.fTexCoord;

    // Add tape wobble
    float wobble = sin(uniforms.time * 5.0 + texCoord.y * 20.0) * uniforms.tapeWobble;
    texCoord.x += wobble;

    // Add horizontal jitter/scanline displacement
    float jitter = hash(float2(uniforms.time * 0.01, floor(texCoord.y * uniforms.SourceSize.y))) * 2.0 - 1.0;
    texCoord.x += jitter * uniforms.scanlineJitter;

    // Add vertical color bleeding
    float4 color = float4(0.0);
    for (int i = 0; i < 3; i++) {
        float offset = float(i - 1) * uniforms.colorBleed / uniforms.SourceSize.y;
        float2 sampleCoord = texCoord + float2(0.0, offset);
        color[i] = texture.sample(textureSampler, sampleCoord)[i];
    }
    color.a = 1.0;

    // Add ghosting/double image effect
    float2 ghostOffset = float2(uniforms.ghosting * 0.01, 0.0);
    float4 ghostColor = texture.sample(textureSampler, texCoord + ghostOffset);
    color = mix(color, ghostColor, 0.2);

    // Add tracking noise
    float tracking = noise(float2(texCoord.y * 10.0, uniforms.time), uniforms.time);
    if (tracking < uniforms.trackingNoise) {
        float noiseLine = hash(float2(floor(texCoord.y * uniforms.SourceSize.y), uniforms.time));
        color.rgb = mix(color.rgb, float3(noiseLine), 0.5);
    }

    // Add static noise
    float staticNoise = hash(texCoord * uniforms.time) * uniforms.noiseAmount;
    color.rgb += float3(staticNoise);

    // Add vignette effect
    float2 vignetteCoord = (texCoord - 0.5) * 2.0;
    float vignette = 1.0 - dot(vignetteCoord, vignetteCoord) * uniforms.vignette;
    color.rgb *= vignette;

    return color;
}
