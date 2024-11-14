//
//  lcdFilter.metal
//  Provenance
//
//  Created by Assistant on 2024.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

#include <metal_stdlib>
#import "../MetalViewShaders.h"

using namespace metal;

/// LCD filter uniforms for customizing the effect
#pragma pack(push,4)
struct LCDFilterUniforms {
    float4 screenRect;           /// x,y,width,height of the screen
    float2 textureSize;         /// Size of the input texture
    float gridDensity;         /// Controls how visible the LCD grid is (0.5-2.0)
    float gridBrightness;      /// Controls the brightness of grid lines (0.0-1.0)
    float contrast;            /// Image contrast adjustment (1.0-2.0)
    float saturation;          /// Color saturation adjustment (0.0-2.0)
    float ghosting;            /// LCD ghosting/response time effect (0.0-1.0)
    float scanlineDepth;       /// Scanline depth effect (0.0-1.0)
    float bloomAmount;         /// Bloom effect amount (0.0-1.0)
    float colorLow;            /// Low color threshold for subpixel layout
    float colorHigh;           /// High color threshold for subpixel layout
};
#pragma pack(pop)

/// Improved subpixel simulation based on LCD.fsh
float3 applySubpixelLayout(float2 uv, float2 texelSize, texture2d<float> inputTexture,
                          sampler textureSampler, float colorLow, float colorHigh) {
    float2 pos = fract(uv * texelSize * 6.0);

    float4 center = inputTexture.sample(textureSampler, uv);
    float4 left = inputTexture.sample(textureSampler, uv - float2(texelSize.x, 0));
    float4 right = inputTexture.sample(textureSampler, uv + float2(texelSize.x, 0));

    float4 midleft = mix(left, center, 0.5);
    float4 midright = mix(right, center, 0.5);

    if (pos.x < 1.0 / 6.0) {
        return float3(colorHigh * center.r, colorLow * center.g, colorHigh * left.b);
    } else if (pos.x < 2.0 / 6.0) {
        return float3(colorHigh * center.r, colorLow * center.g, colorLow * midleft.b);
    } else if (pos.x < 3.0 / 6.0) {
        return float3(colorHigh * center.r, colorHigh * center.g, colorLow * center.b);
    } else if (pos.x < 4.0 / 6.0) {
        return float3(colorLow * midright.r, colorHigh * center.g, colorHigh * center.b);
    } else if (pos.x < 5.0 / 6.0) {
        return float3(colorLow * right.r, colorLow * midright.g, colorHigh * center.b);
    } else {
        return float3(colorHigh * right.r, colorLow * right.g, colorHigh * center.b);
    }
}

/// Scanline effect from MonoLCD
float applyScanlines(float2 uv, float2 texelSize, float scanlineDepth) {
    float2 pos = fract(uv * texelSize * 6.0);
    float multiplier = 1.0;

    if (pos.y < 1.0 / 6.0) {
        multiplier *= pos.y * scanlineDepth + (1.0 - scanlineDepth);
    } else if (pos.y > 5.0 / 6.0) {
        multiplier *= (1.0 - pos.y) * scanlineDepth + (1.0 - scanlineDepth);
    }

    return multiplier;
}

/// Main fragment shader
fragment float4
lcdFilter(Outputs in [[stage_in]],
          texture2d<float> inputTexture [[texture(0)]],
          constant LCDFilterUniforms &uniforms [[buffer(0)]])
{
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    float2 texelSize = uniforms.textureSize;

    // Apply subpixel layout
    float3 color = applySubpixelLayout(in.fTexCoord, texelSize, inputTexture, textureSampler,
                                     uniforms.colorLow, uniforms.colorHigh);

    // Apply scanlines
    float scanline = applyScanlines(in.fTexCoord, texelSize, uniforms.scanlineDepth);
    color *= scanline;

    // Apply bloom effect
    float4 bloomColor = inputTexture.sample(textureSampler, in.fTexCoord);
    color = mix(color, bloomColor.rgb, uniforms.bloomAmount);

    // Apply contrast and saturation
    color = mix(float3(0.5), color, uniforms.contrast);
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    color = mix(float3(luminance), color, uniforms.saturation);

    // Apply ghosting effect
    if (uniforms.ghosting > 0.0) {
        float2 ghostOffset = float2(texelSize.x * 0.5, 0.0);
        float3 ghostColor = inputTexture.sample(textureSampler, in.fTexCoord - ghostOffset).rgb;
        color = mix(color, ghostColor, uniforms.ghosting * 0.3);
    }

    return float4(color, 1.0);
}
