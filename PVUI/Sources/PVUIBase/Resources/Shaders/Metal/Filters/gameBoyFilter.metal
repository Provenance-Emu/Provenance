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
    float4 palette[4];      /// Classic Game Boy green palette
};

fragment float4
gameBoyFilter(Outputs in [[stage_in]],
              constant GameBoyUniforms& uniforms [[buffer(0)]],
              texture2d<float> texture [[texture(0)]],
              sampler textureSampler [[sampler(0)]])
{
    float2 texCoord = in.fTexCoord;

    // Create dot matrix effect
    float2 dots = fract(texCoord * uniforms.SourceSize.xy * 0.5);
    float dotMask = step(length(dots - 0.5), 0.4);

    // Sample and convert to grayscale
    float4 color = texture.sample(textureSampler, texCoord);
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));

    // Apply contrast
    gray = clamp((gray - 0.5) * uniforms.contrast + 0.5, 0.0, 1.0);

    // Quantize to 4 levels (Classic Game Boy style)
    int index = int(gray * 3.99);  // Multiply by 3.99 instead of 4 to avoid overflow
    float4 gbColor = uniforms.palette[index];

    // Apply dot matrix effect
    gbColor *= mix(1.0, dotMask, uniforms.dotMatrix);

    return gbColor;
}
