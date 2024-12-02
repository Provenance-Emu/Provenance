//
//  megaTron.metal
//
//  Created by MrJs 06/2020
//  v09062020a
//
//  This shader does a more complex CRT emulation using
//  Metal that should run on all of the supported
//  devices that MAME4iOS supports.
//
//  Feel free to tweak, mod, or whatever
//
#include <metal_stdlib>
#import "../MetalViewShaders.h"

using namespace metal;

struct MegaTronUniforms {
    float4 SourceSize;      /// x,y = size, z,w = 1/size
    float4 OutputSize;      /// x,y = size, z,w = 1/size
    float MASK;            /// 0=none, 1=RGB, 2=RGB(2), 3=RGB(3)
    float MASK_INTENSITY;  /// Mask intensity (0.0-1.0)
    float SCANLINE_THINNESS; /// Scanline thickness
    float SCAN_BLUR;       /// Scanline blur
    float CURVATURE;       /// Screen curvature
    float TRINITRON_CURVE; /// 0=normal curve, 1=trinitron style
    float CORNER;          /// Corner size
    float CRT_GAMMA;       /// CRT gamma correction
};

// Trinitron-style curve (cylindrical)
float2 trinitronCurve(float2 uv) {
    uv = (uv - 0.5) * 2.0;
    // Only curve horizontally
    uv.x *= 1.0 + pow(abs(uv.y), 2.0) * 0.3;
    return (uv / 2.0) + 0.5;
}

// Aperture grille mask
float3 trinitronMask(float2 pos, constant MegaTronUniforms& uniforms) {
    float3 mask = float3(1.0);
    float mask_pixel = fract(pos.x * uniforms.SourceSize.x / 3.0);

    // Vertical RGB stripes
    if (mask_pixel < 0.333)
        mask = float3(1.0, 0.2, 0.2);
    else if (mask_pixel < 0.666)
        mask = float3(0.2, 1.0, 0.2);
    else
        mask = float3(0.2, 0.2, 1.0);

    // Add damping wire
    float wire = smoothstep(0.3, 0.4, abs(fract(pos.y * uniforms.SourceSize.y / 8.0) - 0.5));
    mask *= wire;

    return mask;
}

fragment float4
megaTron(Outputs in [[stage_in]],
         constant MegaTronUniforms& uniforms [[buffer(0)]],
         texture2d<float> texture [[texture(0)]],
         sampler textureSampler [[sampler(0)]])
{
    float2 uv = in.fTexCoord;
    float2 curved_uv = mix(uv, trinitronCurve(uv), uniforms.CURVATURE);

    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Sample with slight vertical bleeding
    float4 color = texture.sample(textureSampler, curved_uv);
    float4 bleed = texture.sample(textureSampler, curved_uv + float2(0.0, 1.0/uniforms.SourceSize.y));
    color = mix(color, bleed, 0.2);

    // Apply aperture grille
    float3 mask = trinitronMask(curved_uv, uniforms);
    color.rgb *= mix(float3(1.0), mask, uniforms.MASK_INTENSITY);

    // Sharp scanlines
    float scanline = fract(curved_uv.y * uniforms.SourceSize.y);
    scanline = smoothstep(0.0, uniforms.SCANLINE_THINNESS, scanline) *
               smoothstep(1.0, uniforms.SCANLINE_THINNESS, scanline);
    color.rgb *= 0.6 + 0.4 * scanline;

    // Trinitron-style gamma and brightness
    color.rgb = pow(color.rgb, float3(1.0 / uniforms.CRT_GAMMA));
    color.rgb *= 1.2; // Trinitrons were known for brightness

    return color;
}
