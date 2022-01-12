//
//  ulTron.metal
//
//  Created by MrJs 06/2020
//  v09062020a
//
//  Ultron (/ˈʌltrɒn/) is a fictional supervillain appearing in American comic books published by Marvel Comics.
//  He is most recognized as a nemesis of the Avengers superhero group and his quasi-familial relationship with his creator Hank Pym.
//  He was the first Marvel Comics character to wield the fictional metal alloy adamantium.
//
//  Feel free to tweak, mod, or whatever
//
//
//  ulTron.metal
//
//  Created by MrJs 06/2020
//  v21062020a
//
//  Ultron (/ˈʌltrɒn/) is a fictional supervillain appearing in American comic books published by Marvel Comics.
//  He is most recognized as a nemesis of the Avengers superhero group and his quasi-familial relationship with his creator Hank Pym.
//  He was the first Marvel Comics character to wield the fictional metal alloy adamantium.
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
    float hardScan;
    float hardPix;
    float warpX;
    float warpY;
    float maskDark;
    float maskLight;
    float shadowMask;
    float brightBoost;
    float hardBloomScan;
    float hardBloomPix;
    float bloomAmount;
    float shape;
};

static inline __attribute__((always_inline))
float2 Warp(thread float2& pos, constant Push& params)
{
    pos = (pos * 2.0) - float2(1.0);
    pos *= float2(1.0 + ((pos.y * pos.y) * params.warpX), 1.0 + ((pos.x * pos.x) * params.warpY));
    return (pos * 0.5) + float2(0.5);
}

static inline __attribute__((always_inline))
float ToLinear1(thread const float& c, constant Push& params)
{

    float _93;
    if (c <= 0.04045)
    {
        _93 = c / 12.92;
    }
    else
    {
        _93 = pow((c + 0.055) / 1.055, 2.4);
    }
    return _93;
}

static inline __attribute__((always_inline))
float3 ToLinear(thread const float3& c, constant Push& params)
{

    float param = c.x;
    float param_1 = c.y;
    float param_2 = c.z;
    return float3(ToLinear1(param, params), ToLinear1(param_1, params), ToLinear1(param_2, params));
}


static inline __attribute__((always_inline))
float3 Fetch(thread float2& pos, thread const float2& off, constant Push& params, thread texture2d<float> Source, thread const sampler SourceSmplr)
{
    pos = (floor((pos * params.SourceSize.zw) + off) + float2(0.5)) / params.SourceSize.zw;
    float3 param = Source.sample(SourceSmplr, pos).xyz * params.brightBoost;
    return ToLinear(param, params);
}

static inline __attribute__((always_inline))
float2 Dist(thread float2& pos, constant Push& params)
{
    pos *= params.SourceSize.zw;
    return -((pos - floor(pos)) - float2(0.5));
}

static inline __attribute__((always_inline))
float Gaus(thread const float& pos, thread const float& scale, constant Push& params)
{
    return exp2(scale * pow(abs(pos), params.shape));
}

static inline __attribute__((always_inline))
float3 Horz3(thread const float2& pos, thread const float& off, constant Push& params, thread texture2d<float> Source, thread const sampler SourceSmplr)
{
    float2 param = pos;
    float2 param_1 = float2(-1.0, off);
    float3 _250 = Fetch(param, param_1, params, Source, SourceSmplr);
    float3 b = _250;
    float2 param_2 = pos;
    float2 param_3 = float2(0.0, off);
    float3 _257 = Fetch(param_2, param_3, params, Source, SourceSmplr);
    float3 c = _257;
    float2 param_4 = pos;
    float2 param_5 = float2(1.0, off);
    float3 _265 = Fetch(param_4, param_5, params, Source, SourceSmplr);
    float3 d = _265;
    float2 param_6 = pos;
    float2 _269 = Dist(param_6, params);
    float dst = _269.x;
    float scale = params.hardPix;
    float param_7 = dst - 1.0;
    float param_8 = scale;
    float wb = Gaus(param_7, param_8, params);
    float param_9 = dst + 0.0;
    float param_10 = scale;
    float wc = Gaus(param_9, param_10, params);
    float param_11 = dst + 1.0;
    float param_12 = scale;
    float wd = Gaus(param_11, param_12, params);
    return (((b * wb) + (c * wc)) + (d * wd)) / float3((wb + wc) + wd);
}

static inline __attribute__((always_inline))
float3 Horz5(thread const float2& pos, thread const float& off, constant Push& params, thread texture2d<float> Source, thread const sampler SourceSmplr)
{
    float2 param = pos;
    float2 param_1 = float2(-2.0, off);
    float3 _322 = Fetch(param, param_1, params, Source, SourceSmplr);
    float3 a = _322;
    float2 param_2 = pos;
    float2 param_3 = float2(-1.0, off);
    float3 _329 = Fetch(param_2, param_3, params, Source, SourceSmplr);
    float3 b = _329;
    float2 param_4 = pos;
    float2 param_5 = float2(0.0, off);
    float3 _336 = Fetch(param_4, param_5, params, Source, SourceSmplr);
    float3 c = _336;
    float2 param_6 = pos;
    float2 param_7 = float2(1.0, off);
    float3 _343 = Fetch(param_6, param_7, params, Source, SourceSmplr);
    float3 d = _343;
    float2 param_8 = pos;
    float2 param_9 = float2(2.0, off);
    float3 _351 = Fetch(param_8, param_9, params, Source, SourceSmplr);
    float3 e = _351;
    float2 param_10 = pos;
    float2 _355 = Dist(param_10, params);
    float dst = _355.x;
    float scale = params.hardPix;
    float param_11 = dst - 2.0;
    float param_12 = scale;
    float wa = Gaus(param_11, param_12, params);
    float param_13 = dst - 1.0;
    float param_14 = scale;
    float wb = Gaus(param_13, param_14, params);
    float param_15 = dst + 0.0;
    float param_16 = scale;
    float wc = Gaus(param_15, param_16, params);
    float param_17 = dst + 1.0;
    float param_18 = scale;
    float wd = Gaus(param_17, param_18, params);
    float param_19 = dst + 2.0;
    float param_20 = scale;
    float we = Gaus(param_19, param_20, params);
    return (((((a * wa) + (b * wb)) + (c * wc)) + (d * wd)) + (e * we)) / float3((((wa + wb) + wc) + wd) + we);
}

static inline __attribute__((always_inline))
float Scan(thread const float2& pos, thread const float& off, constant Push& params)
{
    float2 param = pos;
    float2 _583 = Dist(param, params);
    float dst = _583.y;
    float param_1 = dst + off;
    float param_2 = params.hardScan;
    return Gaus(param_1, param_2, params);
}

static inline __attribute__((always_inline))
float3 Tri(thread const float2& pos, constant Push& params, thread texture2d<float> Source, thread const sampler SourceSmplr)
{
    float2 param = pos;
    float param_1 = -1.0;
    float3 a = Horz3(param, param_1, params, Source, SourceSmplr);
    float2 param_2 = pos;
    float param_3 = 0.0;
    float3 b = Horz5(param_2, param_3, params, Source, SourceSmplr);
    float2 param_4 = pos;
    float param_5 = 1.0;
    float3 c = Horz3(param_4, param_5, params, Source, SourceSmplr);
    float2 param_6 = pos;
    float param_7 = -1.0;
    float wa = Scan(param_6, param_7, params);
    float2 param_8 = pos;
    float param_9 = 0.0;
    float wb = Scan(param_8, param_9, params);
    float2 param_10 = pos;
    float param_11 = 1.0;
    float wc = Scan(param_10, param_11, params);
    return ((a * wa) + (b * wb)) + (c * wc);
}

static inline __attribute__((always_inline))
float3 Horz7(thread const float2& pos, thread const float& off, constant Push& params, thread texture2d<float> Source, thread const sampler SourceSmplr)
{
    float2 param = pos;
    float2 param_1 = float2(-3.0, off);
    float3 _434 = Fetch(param, param_1, params,  Source, SourceSmplr);
    float3 a = _434;
    float2 param_2 = pos;
    float2 param_3 = float2(-2.0, off);
    float3 _441 = Fetch(param_2, param_3, params,  Source, SourceSmplr);
    float3 b = _441;
    float2 param_4 = pos;
    float2 param_5 = float2(-1.0, off);
    float3 _448 = Fetch(param_4, param_5, params,  Source, SourceSmplr);
    float3 c = _448;
    float2 param_6 = pos;
    float2 param_7 = float2(0.0, off);
    float3 _455 = Fetch(param_6, param_7, params,  Source, SourceSmplr);
    float3 d = _455;
    float2 param_8 = pos;
    float2 param_9 = float2(1.0, off);
    float3 _462 = Fetch(param_8, param_9, params,  Source, SourceSmplr);
    float3 e = _462;
    float2 param_10 = pos;
    float2 param_11 = float2(2.0, off);
    float3 _469 = Fetch(param_10, param_11, params,  Source, SourceSmplr);
    float3 f = _469;
    float2 param_12 = pos;
    float2 param_13 = float2(3.0, off);
    float3 _477 = Fetch(param_12, param_13, params,  Source, SourceSmplr);
    float3 g = _477;
    float2 param_14 = pos;
    float2 _481 = Dist(param_14, params);
    float dst = _481.x;
    float scale = params.hardBloomPix;
    float param_15 = dst - 3.0;
    float param_16 = scale;
    float wa = Gaus(param_15, param_16, params);
    float param_17 = dst - 2.0;
    float param_18 = scale;
    float wb = Gaus(param_17, param_18, params);
    float param_19 = dst - 1.0;
    float param_20 = scale;
    float wc = Gaus(param_19, param_20, params);
    float param_21 = dst + 0.0;
    float param_22 = scale;
    float wd = Gaus(param_21, param_22, params);
    float param_23 = dst + 1.0;
    float param_24 = scale;
    float we = Gaus(param_23, param_24, params);
    float param_25 = dst + 2.0;
    float param_26 = scale;
    float wf = Gaus(param_25, param_26, params);
    float param_27 = dst + 3.0;
    float param_28 = scale;
    float wg = Gaus(param_27, param_28, params);
    return (((((((a * wa) + (b * wb)) + (c * wc)) + (d * wd)) + (e * we)) + (f * wf)) + (g * wg)) / float3((((((wa + wb) + wc) + wd) + we) + wf) + wg);
}

static inline __attribute__((always_inline))
float BloomScan(thread const float2& pos, thread const float& off, constant Push& params)
{
    float2 param = pos;
    float2 _599 = Dist(param, params);
    float dst = _599.y;
    float param_1 = dst + off;
    float param_2 = params.hardBloomScan;
    return Gaus(param_1, param_2, params);
}

static inline __attribute__((always_inline))
float3 Bloom(thread const float2& pos, constant Push& params, thread texture2d<float> Source, thread const sampler SourceSmplr)
{
    float2 param = pos;
    float param_1 = -2.0;
    float3 a = Horz5(param, param_1, params, Source, SourceSmplr);
    float2 param_2 = pos;
    float param_3 = -1.0;
    float3 b = Horz7(param_2, param_3, params, Source, SourceSmplr);
    float2 param_4 = pos;
    float param_5 = 0.0;
    float3 c = Horz7(param_4, param_5, params, Source, SourceSmplr);
    float2 param_6 = pos;
    float param_7 = 1.0;
    float3 d = Horz7(param_6, param_7, params, Source, SourceSmplr);
    float2 param_8 = pos;
    float param_9 = 2.0;
    float3 e = Horz5(param_8, param_9, params, Source, SourceSmplr);
    float2 param_10 = pos;
    float param_11 = -2.0;
    float wa = BloomScan(param_10, param_11, params);
    float2 param_12 = pos;
    float param_13 = -1.0;
    float wb = BloomScan(param_12, param_13, params);
    float2 param_14 = pos;
    float param_15 = 0.0;
    float wc = BloomScan(param_14, param_15, params);
    float2 param_16 = pos;
    float param_17 = 1.0;
    float wd = BloomScan(param_16, param_17, params);
    float2 param_18 = pos;
    float param_19 = 2.0;
    float we = BloomScan(param_18, param_19, params);
    return ((((a * wa) + (b * wb)) + (c * wc)) + (d * wd)) + (e * we);
}

static inline __attribute__((always_inline))
float3 Mask(thread float2& pos, constant Push& params)
{
    float3 mask = float3(params.maskDark, params.maskDark, params.maskDark);
    if (params.shadowMask == 1.0)
    {
        float line = params.maskLight;
        float odd = 0.0;
        if (fract(pos.x * (1.0/6.0)) < 0.5)
        {
            odd = 1.0;
        }
        if (fract((pos.y + odd) * 0.5) < 0.5)
        {
            line = params.maskDark;
        }
        pos.x = fract(pos.x * (1.0/3.0));
        if (pos.x < (1.0/3.0))
        {
            mask.x = params.maskLight;
        }
        else
        {
            if (pos.x < (2.0/3.0))
            {
                mask.y = params.maskLight;
            }
            else
            {
                mask.z = params.maskLight;
            }
        }
        mask *= line;
    }
    else
    {
        if (params.shadowMask == 2.0)
        {
            pos.x = fract(pos.x * (1.0/3.0));
            if (pos.x < (1.0/3.0))
            {
                mask.x = params.maskLight;
            }
            else
            {
                if (pos.x < (2.0/3.0))
                {
                    mask.y = params.maskLight;
                }
                else
                {
                    mask.z = params.maskLight;
                }
            }
        }
        else
        {
            if (params.shadowMask == 3.0)
            {
                pos.x += (pos.y * 2.999);
                pos.x = fract(pos.x * (1.0/6.0));
                if (pos.x < (1.0/3.0))
                {
                    mask.x = params.maskLight;
                }
                else
                {
                    if (pos.x < (2.0/3.0))
                    {
                        mask.y = params.maskLight;
                    }
                    else
                    {
                        mask.z = params.maskLight;
                    }
                }
            }
            else
            {
                if (params.shadowMask == 4.0)
                {
                    pos = floor(pos * float2(1.0, 0.5));
                    pos.x += (pos.y * 3.0);
                    pos.x = fract(pos.x *(1.0/6.0));
                    if (pos.x < (1.0/3.0))
                    {
                        mask.x = params.maskLight;
                    }
                    else
                    {
                        if (pos.x < (2.0/3.0))
                        {
                            mask.y = params.maskLight;
                        }
                        else
                        {
                            mask.z = params.maskLight;
                        }
                    }
                }
            }
        }
    }
    return mask;
}

static inline __attribute__((always_inline))
float ToSrgb1(thread const float& c, constant Push& params)
{
    float _146;
    if (c < 0.0031308)
    {
        _146 = c * 12.92;
    }
    else
    {
        _146 = (1.055 * pow(c, 0.41666)) - 0.055;
    }
    return _146;
}

static inline __attribute__((always_inline))
float3 ToSrgb(thread const float3& c, constant Push& params)
{
    float param = c.x;
    float param_1 = c.y;
    float param_2 = c.z;
    return float3(ToSrgb1(param, params), ToSrgb1(param_1, params), ToSrgb1(param_2, params));
}

fragment float4
ultron(VertexOutput v[[stage_in]],
                         constant Push& params [[buffer(0)]],
                         texture2d<float> Source [[texture(0)]],
                         sampler SourceSmplr [[sampler(0)]])
{
    float2 param = v.tex.xy;
    float2 _953 = Warp(param, params);
    float2 pos = _953;
    float2 param_1 = pos;
    float3 outColor = Tri(param_1, params, Source, SourceSmplr);
    float2 param_2 = pos;
    outColor += (Bloom(param_2, params, Source, SourceSmplr) * params.bloomAmount);
    if (params.shadowMask > 0.0)
    {
        float2 param_3 = (v.tex.xy / (1.0/params.OutputSize.zw)) * 1.0;
        float3 _980 = Mask(param_3, params);
        outColor *= _980;
    }
    float3 param_4 = outColor;
    float4 out = float4(ToSrgb(param_4, params), 1.0);
    return out;
}
