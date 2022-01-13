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
#import "MetalViewShaders.h"

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
__lineTron(VertexOutput v[[stage_in]], constant Push& params [[buffer(0)]])
{
    float a = exp(-pow(v.tex.y * params.falloff, 2));
    return float4((v.color.rgb*params.strength), a);
}

fragment float4
lineTron(VertexOutput v [[stage_in]], constant Push& params [[buffer(0)]])
{
    float t = params.line_time;
    float4 color = v.color;
    
    // if t==0.0, just use color as is. else fade out color in time, and alpha edge
    if (t != 0.0)
        color = float4(color.rgb * exp(-pow(t * params.falloff, 2)) * params.strength, mix(1.0, 0.0, abs(v.tex.y)));

    return color;
}
