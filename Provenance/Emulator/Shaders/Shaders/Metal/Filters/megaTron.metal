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
#import "MetalViewShaders.h"

using namespace metal;

struct Push
{
    float4 SourceSize;
    float4 OutputSize;
    float MASK;
    float MASK_INTENSITY;
    float SCANLINE_THINNESS;
    float SCAN_BLUR;
    float CURVATURE;
    float TRINITRON_CURVE;
    float CORNER;
    float CRT_GAMMA;
};

static inline __attribute__((always_inline))
float4 megaTronTone(thread const float& contrast, thread const float& saturation, thread const float& thin, thread float& mask, constant Push& params)
{
    if (params.MASK == 0.0)
    {
        mask = 1.0;
    }
    if (params.MASK == 1.0)
    {
        mask = 0.5 + (mask * 0.5);
    }
    float midOut = 0.18 / ((1.5 - thin) * ((0.5 * mask) + 0.5));
    float pMidIn = pow(0.18, contrast);
    float4 ret;
    ret.x = contrast;
    ret.y = ((-pMidIn) + midOut) / ((1.0 - pMidIn) * midOut);
    ret.z = (((-pMidIn) * midOut) + pMidIn) / ((midOut * (-pMidIn)) + midOut);
    ret.w = contrast + saturation;
    return ret;
}

static inline __attribute__((always_inline))
float FromSrgbFunc(thread const float& c, constant Push& params)
{
    float _69;
    if (c <= 0.04045)
    {
        _69 = c * (1.0/12.92);
    }
    else
    {
        _69 = pow((abs(c) * (1.0/1.055)) + (0.055/1.055), params.CRT_GAMMA);
    }
    return _69;
}

static inline __attribute__((always_inline))
float3 FromSrgb(thread const float3& c, constant Push& params)
{
    float param = c.x;
    float param_1 = c.y;
    float param_2 = c.z;
    return float3(FromSrgbFunc(param, params), FromSrgbFunc(param_1, params), FromSrgbFunc(param_2, params));
}

static inline __attribute__((always_inline))
float3 megaTronFetch(thread float2& uv, constant Push& params, thread texture2d<float> texture, thread const sampler SourceSmplr)
{
    uv *= (float2(params.SourceSize.z, params.SourceSize.w) / params.SourceSize.zw);
    float3 param = texture.sample(SourceSmplr, uv, bias(-16.0)).xyz;
    return FromSrgb(param, params);
}

static inline __attribute__((always_inline))
float3 megaTronMask(thread float2& pos, thread const float& dark, constant Push& params)
{
    if (params.MASK == 2.0)
    {
        float3 m = float3(dark, dark, dark);
        float x = fract(pos.x * (1.0/3.0));
        if (x < (1.0/3.0))
        {
            m.x = 1.0;
        }
        else
        {
            if (x <(2.0/3.0))
            {
                m.y = 1.0;
            }
            else
            {
                m.z = 1.0;
            }
        }
        return m;
    }
    else
    {
        if (params.MASK == 1.0)
        {
            float3 m_1 = float3(1.0);
            float x_1 = fract(pos.x * (1.0/3.0));
            if (x_1 < (1.0/3.0))
            {
                m_1.x = dark;
            }
            else
            {
                if (x_1 <(2.0/3.0))
                {
                    m_1.y = dark;
                }
                else
                {
                    m_1.z = dark;
                }
            }
            return m_1;
        }
        else
        {
            if (params.MASK == 3.0)
            {
                pos.x += (pos.y * 2.9999);
                float3 m_2 = float3(dark, dark, dark);
                float x_2 = fract(pos.x * (1.0/6.0));
                if (x_2 < (1.0/3.0))
                {
                    m_2.x = 1.0;
                }
                else
                {
                    if (x_2 <(2.0/3.0))
                    {
                        m_2.y = 1.0;
                    }
                    else
                    {
                        m_2.z = 1.0;
                    }
                }
                return m_2;
            }
            else
            {
                return float3(1.0);
            }
        }
    }
}

static inline __attribute__((always_inline))
float megaTronMax3F1(thread const float& a, thread const float& b, thread const float& c)
{
    return fast::max(a, fast::max(b, c));
}

static inline __attribute__((always_inline))
float3 megaTronFilter(thread const float2& ipos,
                  thread const float2& inputSizeDivOutputSize,
                  thread const float2& halfInputSize,
                  thread const float2& rcpInputSize,
                  thread const float2& rcpOutputSize,
                  thread const float2& twoDivOutputSize,
                  thread const float& inputHeight,
                  thread const float2& warp,
                  thread const float& thin,
                  thread const float& blur,
                  thread const float& mask,
                  thread const float4& tone,
                  constant Push& params,
                  thread texture2d<float> texture,
                  thread const sampler SourceSmplr
                  )
{
    float2 pos = (ipos * twoDivOutputSize) - float2(1.0);
    pos *= float2(1.0 + ((pos.y * pos.y) * warp.x), 1.0 + ((pos.x * pos.x) * warp.y));
    float vin = (1.0 - ((1.0 - fast::clamp(pos.x * pos.x, 0.0, 1.0)) * (1.0 - fast::clamp(pos.y * pos.y, 0.0, 1.0)))) * (0.998 + (0.001 * params.CORNER));
    vin = fast::clamp(((-vin) * inputHeight) + inputHeight, 0.0, 1.0);
    pos = (pos * halfInputSize) + halfInputSize;
    float y0 = floor(pos.y - 0.5) + 0.5;
    float x0 = floor(pos.x - 1.5) + 0.5;
    float2 p = float2(x0 * rcpInputSize.x, y0 * rcpInputSize.y);
    float2 param = p;
    float3 _443 = megaTronFetch(param, params, texture, SourceSmplr);
    float3 colA0 = _443;
    p.x += rcpInputSize.x;
    float2 param_1 = p;
    float3 _453 = megaTronFetch(param_1, params, texture, SourceSmplr);
    float3 colA1 = _453;
    p.x += rcpInputSize.x;
    float2 param_2 = p;
    float3 _463 = megaTronFetch(param_2, params, texture, SourceSmplr);
    float3 colA2 = _463;
    p.x += rcpInputSize.x;
    float2 param_3 = p;
    float3 _473 = megaTronFetch(param_3, params, texture, SourceSmplr);
    float3 colA3 = _473;
    p.y += rcpInputSize.y;
    float2 param_4 = p;
    float3 _483 = megaTronFetch(param_4, params, texture, SourceSmplr);
    float3 colB3 = _483;
    p.x -= rcpInputSize.x;
    float2 param_5 = p;
    float3 _493 = megaTronFetch(param_5, params, texture, SourceSmplr);
    float3 colB2 = _493;
    p.x -= rcpInputSize.x;
    float2 param_6 = p;
    float3 _503 = megaTronFetch(param_6, params, texture, SourceSmplr);
    float3 colB1 = _503;
    p.x -= rcpInputSize.x;
    float2 param_7 = p;
    float3 _513 = megaTronFetch(param_7, params, texture, SourceSmplr);
    float3 colB0 = _513;
    float off = pos.y - y0;
    float pi2 = 6.283185482025146484375;
    float hlf = 0.5;
    float scanA = (cos(fast::min(0.5, off * thin) * pi2) * hlf) + hlf;
    float scanB = (cos(fast::min(0.5, ((-off) * thin) + thin) * pi2) * hlf) + hlf;
    float off0 = pos.x - x0;
    float off1 = off0 - 1.0;
    float off2 = off0 - 2.0;
    float off3 = off0 - 3.0;
    float pix0 = exp2((blur * off0) * off0);
    float pix1 = exp2((blur * off1) * off1);
    float pix2 = exp2((blur * off2) * off2);
    float pix3 = exp2((blur * off3) * off3);
    float pixT = 1.0 / (((pix0 + pix1) + pix2) + pix3);
    pixT *= vin;
    scanA *= pixT;
    scanB *= pixT;
    float3 color = (((((colA0 * pix0) + (colA1 * pix1)) + (colA2 * pix2)) + (colA3 * pix3)) * scanA) + (((((colB0 * pix0) + (colB1 * pix1)) + (colB2 * pix2)) + (colB3 * pix3)) * scanB);
    float2 param_8 = ipos;
    float param_9 = mask;
    float3 _649 = megaTronMask(param_8, param_9, params);
    color *= _649;
    float param_10 = color.x;
    float param_11 = color.y;
    float param_12 = color.z;
    float peak = fast::max((1.0/(256.0*65536.0)), megaTronMax3F1(param_10, param_11, param_12));
    float3 ratio = color * (1.0 / peak);
    peak = pow(peak, tone.x);
    peak *= (1.0 / ((peak * tone.y) + tone.z));
    ratio = pow(ratio, float3(tone.w, tone.w, tone.w));
    return ratio * peak;
}

static inline __attribute__((always_inline))
float ToSrgbFunc(thread const float& c)
{
    float _116;
    if (c < 0.0031308)
    {
        _116 = c * 12.92;
    }
    else
    {
        _116 = (1.055 * pow(c, 0.41666)) - 0.055;
    }
    return _116;
}

static inline __attribute__((always_inline))
float3 ToSrgb(thread const float3& c)
{
    float param = c.x;
    float param_1 = c.y;
    float param_2 = c.z;
    return float3(ToSrgbFunc(param), ToSrgbFunc(param_1), ToSrgbFunc(param_2));
}

fragment float4
megaTron(VertexOutput v[[stage_in]],
       constant Push& params [[buffer(0)]],
       texture2d<float> texture [[texture(0)]],
       sampler SourceSmplr [[sampler(0)]])
{
    float2 warp_factor;
    warp_factor.x = params.CURVATURE;
    warp_factor.y = (3.0 / 4.0) * warp_factor.x;
    warp_factor.x *= (1.0 - params.TRINITRON_CURVE);
    float param = 1.0;
    float param_1 = 0.0;
    float param_2 = 0.5 + (0.5 * params.SCANLINE_THINNESS);
    float param_3 = 1.0 - params.MASK_INTENSITY;
    float4 _767 = megaTronTone(param, param_1, param_2, param_3, params);
    float2 ipos = v.tex * params.OutputSize.zw;
    float2 inputSizeDivOutputSize = params.SourceSize.zw / params.OutputSize.zw;
    float2 halfInputSize = params.SourceSize.zw * float2(0.5);
    float2 rcpInputSize = (1.0/params.SourceSize.zw);
    float2 rcpOutputSize = (1.0/params.OutputSize.zw);
    float2 twoDivOutputSize = 2.0 / params.OutputSize.zw;
    float inputHeight = params.SourceSize.w;
    float2 warp = warp_factor;
    float thin = 0.5 + (0.5 * params.SCANLINE_THINNESS);
    float blur = (-1.0) * params.SCAN_BLUR;
    float mask = 1.0 - params.MASK_INTENSITY;
    float4 tone = _767;
    float3 megaTronRGB = megaTronFilter(ipos,
                                 inputSizeDivOutputSize,
                                 halfInputSize,
                                 rcpInputSize,
                                 rcpOutputSize,
                                 twoDivOutputSize,
                                 inputHeight,
                                 warp,
                                 thin,
                                 blur,
                                 mask,
                                 tone,
                                 params,
                                 texture,
                                 SourceSmplr);
    float3 _795 = ToSrgb(megaTronRGB);
    float4 megaTron_out = float4(_795.x, _795.y, _795.z, 1.0);
    return megaTron_out;
}
