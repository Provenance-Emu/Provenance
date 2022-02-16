//
//  simpleCRT.metal
//
//  Created by MrJs 06/2020
//  v06062020a
//
//  This shader does a very simple CRT emulation using
//  Metal that should run on all of the supported
//  devices that MAME4iOS supports.
//
//  Feel free to tweak, mod, or whatever
//
#include <metal_stdlib>
#import "MetalViewShaders.h"

using namespace metal;

#pragma pack(push,4)
struct simpleCrtUniforms {
    float4 mame_screen_dst_rect;
    float4 mame_screen_src_rect;
    float curv_vert;    // 5.0 default  1.0, 10.0
    float curv_horiz;   // 4.0 default 1.0, 10.0
    float curv_strength;// 0.25 default 0.0, 1.0
    float light_boost;  // 1.3 default 0.1, 3.0
    float vign_strength;// 0.05 default 0.0, 1.0
    float zoom_out;     // 1.1 default 0.01, 5.0
    float brightness;   // 1.0 default 0.666, 1.333
};
#pragma pack(pop)

fragment float4
simpleCRT(VertexOutput v [[stage_in]],
                texture2d<float> texture [[texture(0)]],
                constant simpleCrtUniforms &uniforms [[buffer(0)]])
{
    float4 dst_rect = uniforms.mame_screen_dst_rect;
    float4 src_rect = uniforms.mame_screen_src_rect;
    // HUD parameters for simpleCRT
    float curv_vert     = uniforms.curv_vert;
    float curv_horiz    = uniforms.curv_horiz;
    float curv_strength = uniforms.curv_strength;
    float light_boost   = uniforms.light_boost;
    float vign_strength = uniforms.vign_strength;
    float zoom_out      = uniforms.zoom_out;
    float brightness    = uniforms.brightness;

    float2 uv = ((v.tex - float2(0.5))*2.0)*zoom_out;  // add in simple curvature to uv's
    uv.x *= (1.0 + pow(abs(uv.y) / curv_vert, 2.0)); // tweak vertical curvature
    uv.y *= (1.0 + pow(abs(uv.x) / curv_horiz, 2.0)); // tweak horizontal curvature
    uv = (uv/float2(2.0))+float2(0.5); // correct curvature
    uv = mix(v.tex, uv, curv_strength); // mix back curvature process to 25% of original strength
    float evenLines = (1.0 - abs(fract(v.tex.y*(src_rect.w * ( (dst_rect.w / src_rect.w) / floor((dst_rect.w / src_rect.w)+0.5))))*2 - 1)); // generate very, very simple scanlines that respect both integer and default scaling
    constexpr sampler crtTexSampler(address::clamp_to_zero, filter::linear); // set up custom Metal texture sampler using cheap linear filtering
    float4 col = texture.sample(crtTexSampler, uv); // sample texture with our modified curvature uv's
    float4 colmod = ((col*col)*evenLines)*light_boost; // simple gamma boost in linear to compensate for darkening due to scanlines
    float vign = pow((0.0 + 1.0*16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y)), vign_strength); // create simple soft vignette and apply it across screen
    float4 simple_crt = (sqrt(colmod*vign)); // reapply gamma and vignette treatment
    return simple_crt * brightness;
}
