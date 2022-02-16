//
//  MetalViewShaders.metal
//  Wombat
//
//  Created by Todd Laney on 5/18/20.
//  Copyright © 2020 Wombat. All rights reserved.
//
#include <metal_stdlib>
#import "MetalViewShaders.h"

using namespace metal;

// default vertex shader(2D)
// map the input 2D point into NDC, copy texture u,v and color
vertex VertexOutput
vertex_default(unsigned int index [[ vertex_id ]],
               constant VertexInput* vertex_array [[buffer(0)]],
               constant VertexUniforms &uniforms  [[buffer(1)]])
{
    VertexInput  vin = vertex_array[index];
    VertexOutput vout;
    vout.position =  uniforms.matrix * float4(vin.position,0,1);
    vout.tex = vin.tex;
    vout.color = vin.color;

    return vout;
}

// default fragment shader
// just copy the color from the vertex, no texture, no lighting, no nuth'n
fragment float4
fragment_default(VertexOutput v [[stage_in]])
{
    return v.color;
}

// default fragment shader for a texture
// sample the texture using the passed in sampler, and multiply by the vertex color
fragment float4
fragment_texture(VertexOutput v [[stage_in]], texture2d<float> texture [[texture(0)]], sampler texture_sampler [[sampler(0)]])
{
    float4 color = texture.sample(texture_sampler, v.tex);
    return color * v.color;
}


// test fragment shader
// convert the color to greyscale and multiply by passed in color.
// and mix with a cos() based on the current timecode (aka frame number)
struct TestUniforms {
    float  frame_num;
    packed_float3 color;
};
fragment float4
fragment_test(VertexOutput v [[stage_in]], constant TestUniforms &uniforms [[buffer(0)]])
{
    float Y = v.color.r * 0.2126 + v.color.g * 0.7152 + v.color.b * 0.0722;
    float t = uniforms.frame_num / 60.0;
    float f = abs(cos(t * 2*M_PI_F * 0.25));
    float4 color = float4(uniforms.color * Y * f, v.color.a);
    
    return color;
}




