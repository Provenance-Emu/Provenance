//
//  MameShaders.metal
//  Wombat
//
//  Created by Todd Laney on 5/18/20.
//  Copyright © 2020 Wombat. All rights reserved.
//
#include <metal_stdlib>
#import "MetalViewShaders.h"

using namespace metal;

// Shader to draw the MAME game SCREEN....
struct MameScreenTestUniforms {
    float2 mame_screen_size;
    float frame_num;
    float rate;
    float factor_u;
    float factor_v;
};
fragment float4
mame_screen_test(VertexOutput v [[stage_in]],
                texture2d<float> texture [[texture(0)]],
                sampler texture_sampler [[sampler(0)]],
                constant MameScreenTestUniforms &uniforms [[buffer(0)]])
{
    // ignore the passed in sampler, and use our own
    //constexpr sampler linear_texture_sampler(mag_filter::linear, min_filter::linear);
    
    float  t = (uniforms.frame_num / 60.0) * uniforms.rate * 2.0 * M_PI_F;
    float2 uv = float2(v.tex.x + cos(t) * uniforms.factor_u * (1.0 / uniforms.mame_screen_size.x),
                       v.tex.y + sin(t) * uniforms.factor_v * (1.0 / uniforms.mame_screen_size.y));
    float4 color = texture.sample(texture_sampler, uv) * v.color;
    return color;
}


// Shader to draw the MAME game SCREEN....
struct MameScreenDotUniforms {
    float2x2 mame_screen_matrix;  // matrix to convert texture coordinates (u,v) to crt scanlines (x,y)
};
fragment float4
mame_screen_dot(VertexOutput v [[stage_in]],
                texture2d<float> texture [[texture(0)]],
                sampler tsamp [[sampler(0)]],
                constant MameScreenDotUniforms &uniforms [[buffer(0)]])
{
    float2 uv = uniforms.mame_screen_matrix * v.tex;
    float2 xy = fract(uv)*2 - float2(1,1);
    float  f = 1.0 - min(1.0, length(xy));
    float4 color = texture.sample(tsamp, v.tex) * f;
    return color;
}

// Shader to draw the MAME game SCREEN....
struct MameScreenLineUniforms {
    float2x2 mame_screen_matrix;  // matrix to convert texture coordinates (u,v) to crt scanlines (x,y)
};
fragment float4
mame_screen_line(VertexOutput v [[stage_in]],
                texture2d<float> texture [[texture(0)]],
                sampler tsamp [[sampler(0)]],
                constant MameScreenLineUniforms &uniforms [[buffer(0)]])
{
    float2 uv = uniforms.mame_screen_matrix * v.tex;
    float  y = fract(uv.y)*2 - 1;
    float  f = cos(y * M_PI_F * 0.5);
    float4 color = texture.sample(tsamp, v.tex) * f;
    return color;
}

// [six colors](https://commons.wikimedia.org/wiki/File:Apple_Computer_Logo_rainbow.svg)
constant float4 six_colors[] = {
    float4(94, 189, 62, 255),
    float4(255, 185, 0, 255),
    float4(247, 130, 0, 255),
    float4(226, 56, 56, 255),
    float4(151, 57, 153, 255),
    float4(0, 156, 223, 255),
};

float4 rainbow(float f) {
    float4 color0 = six_colors[(int)floor(f) % 6] * (1.0/255.0);
    float4 color1 = six_colors[(int) ceil(f) % 6] * (1.0/255.0);

    return mix(color0, color1, fract(f));
}

// test Shader to draw the VECTOR lines
//
// width_scale must always be the first uniform, it is the amount the line width is expanded by.
//
// color.rgb is the line color
// color.a is itterated from 1.0 on center line to 0.25 on the line edge.
//
// texture x is itterated along the length of the line 0 ... length (the length is in model cordinates)
// texture y is itterated along the width of the line, -1 .. +1, with 0 being the center line
//
struct MameTestVectorDash {
    float   width_scale;
    float   frame_count;
    float   dash_length;
    float   speed;
};
fragment float4
mame_test_vector_dash(VertexOutput v [[stage_in]],
                constant MameTestVectorDash &uniforms [[buffer(0)]])
{
    float t = (uniforms.frame_count / 60.0) * uniforms.speed * 8.0;
    float d = v.tex.x;      // distance along the line
//    float w = v.tex.y;      // position across the line
//    float a = 1.0 - abs(w);
    int n = floor((d + t) / uniforms.dash_length);

    if (n & 1)
        return float4(rainbow(n/2).rgb, 1 /*a*/);
    else
        return  float4(0,0,0,0);
}

struct MameTestVectorPulse {
    float   width_scale;
    float   frame_count;
    float   rate;
};
fragment float4
mame_test_vector_pulse(VertexOutput v [[stage_in]],
                constant MameTestVectorPulse &uniforms [[buffer(0)]])
{
    float t = (uniforms.frame_count / 60.0);
    float f = sin(t * M_PI_F * 2.0 / uniforms.rate) * 0.33 + 0.67;
    return v.color * f;
}

struct MameTestVectorFade {
    float   width_scale;
    float   line_time;  // time (in seconds) of the line: 0.0 = now, +1.0 = 1sec in the past
    float   falloff;
    float   strength;
};
fragment float4
mame_test_vector_fade(VertexOutput v [[stage_in]],
                constant MameTestVectorFade &uniforms [[buffer(0)]])
{
    float t = uniforms.line_time;
    float4 color = v.color;
    
    if (t == 0.0) {
        // current line, just use color as is, but scale alpha back to a 1.0 width line.
    }
    else {
        color = color * exp(-pow(t * uniforms.falloff, 2)) * uniforms.strength;
    }
    return color;
}

// Shader to draw the MAME game SCREEN....
struct MameScreenRainbowUniforms {
    float2x2 mame_screen_matrix;  // matrix to convert texture coordinates (u,v) to crt scanlines (x,y)
    float    frame_count;
    float    rainbow_height;
    float    rainbow_speed;
};
fragment float4
mame_screen_rainbow(VertexOutput v [[stage_in]],
                texture2d<float> texture [[texture(0)]],
                sampler tsamp [[sampler(0)]],
                constant MameScreenRainbowUniforms &uniforms [[buffer(0)]])
{
    float2 uv = uniforms.mame_screen_matrix * v.tex;
    float4 shade = rainbow(uv.y/uniforms.rainbow_height + uniforms.frame_count/60 * uniforms.rainbow_speed);
    float4 color = (texture.sample(tsamp, v.tex) + shade) * 0.5;
    return color;
}












