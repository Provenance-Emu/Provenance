//
//  lineTron.metal
//
//  This shader does Vector emulation using
//  Metal that should run on all of the supported
//  devices that MAME4iOS supports.
//
//  Feel free to tweak, mod, or whatever
//
#include <metal_stdlib>
#import "../MetalViewShaders.h"

using namespace metal;

struct LineTronUniforms {
    float4 SourceSize;      /// x,y = size, z,w = 1/size
    float4 OutputSize;      /// x,y = size, z,w = 1/size
    float width_scale;      /// Line width multiplier
    float line_time;        /// Time in seconds (0 = now, 1 = 1sec ago)
    float falloff;          /// Line edge falloff
    float strength;         /// Line brightness
};

fragment float4
lineTron(Outputs in [[stage_in]],
         constant LineTronUniforms& uniforms [[buffer(0)]],
         texture2d<float> texture [[texture(0)]],
         sampler textureSampler [[sampler(0)]])
{
    float2 uv = in.fTexCoord;
    float4 color = texture.sample(textureSampler, uv);

    // Calculate line effect
    float2 pos = uv * uniforms.SourceSize.xy;
    float lineWidth = uniforms.width_scale / uniforms.SourceSize.y;
    float line = fmod(pos.y, 1.0);
    line = smoothstep(0.5 - lineWidth, 0.5 + lineWidth, line);

    // Apply time-based fade
    float fade = 1.0;
    if (uniforms.line_time > 0.0) {
        fade = exp(-uniforms.line_time * uniforms.falloff);
    }

    // Combine effects
    color.rgb *= mix(1.0, line * fade, uniforms.strength);

    return color;
}
