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

// test Shader to draw the VECTOR lines
//
// width_scale must always be the first uniform, it is the amount the line width is expanded by.
//
// color.a is itterated from 1.0 on center line to 0.25 on the line edge.
//
// texture x is itterated along the length of the line 0 ... length (the length is in model cordinates)
// texture y is itterated along the width of the line, -1 .. +1, with 0 being the center line
//
struct Push
{
    float   width_scale;
    float   line_time;  // time (in seconds) of the line: 0.0 = now, +1.0 = 1sec in the past
    float   falloff;
    float   strength;
};

fragment float4
lineTron(Outputs in [[stage_in]],
         constant Push& params [[buffer(0)]],
         texture2d<float> texture [[texture(0)]],
         sampler textureSampler [[sampler(0)]])
{
    float4 color = texture.sample(textureSampler, in.fTexCoord);
    float t = params.line_time;

    // Simplified vector line effect
    color.rgb *= params.strength;

    // Apply falloff if time is non-zero
    if (t > 0.0) {
        float fade = exp(-pow(t * params.falloff, 2));
        color.rgb *= fade;
        color.a = mix(1.0, 0.0, abs(in.fTexCoord.y));
    }

    return color;
}
