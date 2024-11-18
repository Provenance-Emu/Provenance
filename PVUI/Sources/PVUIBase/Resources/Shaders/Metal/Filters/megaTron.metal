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

// Helper functions
float2 curve(float2 uv, float curvature) {
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv = (uv / 2.0) + 0.5;
    return uv;
}

float3 mask_weights(float2 pos, float mask_type) {
    float3 mask = float3(1.0, 1.0, 1.0);

    if (mask_type == 1.0) {  // RGB mask
        pos.x = fract(pos.x / 3.0);
        if (pos.x < 0.333)
            mask = float3(1.0, 0.0, 0.0);
        else if (pos.x < 0.666)
            mask = float3(0.0, 1.0, 0.0);
        else
            mask = float3(0.0, 0.0, 1.0);
    }
    else if (mask_type == 2.0) {  // RGB mask variant
        pos.x = fract(pos.x / 3.0);
        float phase = pos.x * 3.0;
        mask = float3(
            smoothstep(1.0, 0.0, abs(phase - 0.0)),
            smoothstep(1.0, 0.0, abs(phase - 1.0)),
            smoothstep(1.0, 0.0, abs(phase - 2.0))
        );
    }

    return mask;
}

float scanline(float y, float width) {
    float scan = smoothstep(width, 0.0, abs(y));
    return scan;
}

fragment float4
megaTron(Outputs in [[stage_in]],
         constant MegaTronUniforms& uniforms [[buffer(0)]],
         texture2d<float> texture [[texture(0)]],
         sampler textureSampler [[sampler(0)]])
{
    float2 uv = in.fTexCoord;

    // Apply screen curvature
    if (uniforms.CURVATURE > 0.0) {
        uv = curve(uv, uniforms.CURVATURE);
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
            return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Sample the texture
    float4 color = texture.sample(textureSampler, uv);

    // Apply gamma correction
    color.rgb = pow(color.rgb, float3(uniforms.CRT_GAMMA));

    // Apply scanlines
    float scan_line = scanline(fract(uv.y * uniforms.SourceSize.y), uniforms.SCANLINE_THINNESS);
    color.rgb *= mix(1.0, scan_line, uniforms.SCAN_BLUR);

    // Apply mask
    if (uniforms.MASK > 0.0) {
        float2 mask_pos = uv * uniforms.SourceSize.xy;
        float3 mask = mask_weights(mask_pos, uniforms.MASK);
        color.rgb *= mix(float3(1.0), mask, uniforms.MASK_INTENSITY);
    }

    // Apply corner darkening
    if (uniforms.CORNER > 0.0) {
        float2 corner = abs(uv - 0.5) * 2.0;
        float corner_dark = 1.0 - (corner.x * corner.x * corner.y * corner.y) * uniforms.CORNER;
        color.rgb *= corner_dark;
    }

    // Convert back from gamma space
    color.rgb = pow(color.rgb, float3(1.0 / uniforms.CRT_GAMMA));

    return color;
}
