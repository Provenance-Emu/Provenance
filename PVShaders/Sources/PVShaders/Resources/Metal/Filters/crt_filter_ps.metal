// PUBLIC DOMAIN CRT SHADER
//
//   by Jay Mattis (Further tweaks by MrJs 02-2022)
//
// I'm a big fan of Timothy Lottes' shader, but it doesn't scale well and I was looking for something that
// was performant on my 4K TV and still looked decent on my phone. This takes a lot of inspiration from his
// shader but is 3 taps instead of 15, calculates the shadow/slot mask very differently, and bases a lot
// more on the input resolution rather than the output resolution (as long as the output resolution is
// high enough).
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.
//
// - Revert to original optimized shader from Jay Mattis by removing the machine optimizations previously used and re-exposing the original options.
// - Added in an option to disable CRT Warping.
// - Added in custom Display Gamma control and use that as opposed to the c2/sqrt2 optimization. Defaults to the accurate Gamma on TV's or the current Top iPhone Display tier using a Pow function.
// - Lowered min brightness level to visually match the minimum brightness level of a CRT. This may go away at one point and just be set to 0.0 .
// - Reduced warping effect by 1/3
// - Updated to support runtime-configurable parameters via uniforms (Provenance)

#include <metal_stdlib>
using namespace metal;

struct Inputs
{
    float2 fTexCoord [[user(TEXCOORD0)]];
};

/// All configurable parameters are passed as uniforms so users can adjust them at runtime.
struct CRT_Data
{
    float4 DisplayRect;
    float2 EmulatedImageSize;
    float2 FinalRes;
    /// Bloom/glow amount around bright pixels
    float BloomAmount;
    /// Scanline sharpness hardness
    float ScanlineHardness;
    /// Shadow mask phosphor dot hardness
    float ShadowMaskHardness;
    /// Simulated CRT vertical resolution lines
    float RowsOfResolution;
    /// TV lines (controls shadow mask density)
    float TVL;
    /// Horizontal screen warp amount
    float WarpX;
    /// Vertical screen warp amount
    float WarpY;
    /// Display gamma for tone mapping
    float DisplayGamma;
    /// 1 = enable scanlines, 0 = disable
    int UseScanlines;
    /// 1 = enable shadow mask, 0 = disable
    int UseShadowMask;
    /// 1 = enable screen warp, 0 = disable
    int UseWarp;
};

#define FINAL_RES cbData.FinalRes
// These are to convert input texture coordinates to UV (0-1) space and back.
#define INPUTCOORD_TO_UV( inputCoord, data ) ( inputCoord / data.DisplayRect.zw * data.EmulatedImageSize - data.DisplayRect.xy / data.DisplayRect.zw )
#define UV_TO_INPUTCOORD( uv, data ) ( data.DisplayRect.xy / data.EmulatedImageSize + uv / data.EmulatedImageSize * data.DisplayRect.zw )

#define WARP_EDGE_HARDNESS 256.0
#define MIN_BRIGHTNESS 0.0005
#define SCANLINE_MIN_BRIGHTNESS float3( 0.25, 0.25, 0.25 )

#define INLINE inline __attribute__((always_inline))

INLINE float ToLinear1(float c, float gamma) { return pow(c, gamma); }
INLINE float3 ToLinear(float3 c, float gamma) { return float3(ToLinear1(c.r, gamma), ToLinear1(c.g, gamma), ToLinear1(c.b, gamma)); }
INLINE float ToDispGamma1(float c, float gamma) { return pow(c, 1.0 / gamma); }
INLINE float3 ToDispGamma(float3 c, float gamma) { return float3(ToDispGamma1(c.r, gamma), ToDispGamma1(c.g, gamma), ToDispGamma1(c.b, gamma)); }

INLINE
float2 Warp( constant CRT_Data& cbData, float2 uv )
{
    if (cbData.UseWarp) {
        uv = uv * 2.0 - 1.0;
        uv *= float2( 1.0 + ( uv.y * uv.y ) * cbData.WarpX, 1.0 + ( uv.x * uv.x ) * cbData.WarpY );
        return uv * 0.5 + 0.5;
    }
    return uv;
}

INLINE
float2 getShadowMaskRes(constant CRT_Data& cbData)
{
    float2 shadowMaskRes;
    if ( FINAL_RES.y / 3.0 < cbData.TVL * 2.0 )
    {
        shadowMaskRes = FINAL_RES / 3.0;
    }
    else
    {
        shadowMaskRes = float2( FINAL_RES.x / FINAL_RES.y * cbData.TVL, cbData.TVL );
    }
    return shadowMaskRes;
}

template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

INLINE
float3 getShadowMaskRGB( constant CRT_Data& cbData, float2 uv )
{
    if (cbData.UseShadowMask) {
        float2 shadowMaskRes = getShadowMaskRes(cbData);
        float2 pixelCoord = uv * shadowMaskRes * float2( 3.0, 3.0 );
        float3 shadowMaskCoord = float3( pixelCoord.x + 1.0, pixelCoord.x + 0.0, pixelCoord.x + 2.0 );
        float3 shadowMaskRGB = abs( mod( shadowMaskCoord, 3.0 ) - 1.5 ) / 1.5;
        shadowMaskRGB = exp2( shadowMaskRGB * shadowMaskRGB * -cbData.ShadowMaskHardness );
        return shadowMaskRGB;
    }
    return float3(1.0);
}

INLINE
float3 sampleRGB( texture2d<float> EmulatedImage, constant CRT_Data& cbData, float2 uv, float2 warpedUV )
{
    constexpr sampler SamplerF(address::clamp_to_zero, filter::linear);
    float3 inputSample = ToLinear( EmulatedImage.sample(SamplerF, UV_TO_INPUTCOORD( warpedUV, cbData )).rgb, cbData.DisplayGamma );

    float3 scanlineMultiplier = float3( 1.0 );
    if (cbData.UseScanlines) {
        float scanlineY = mod( warpedUV.y, 2.0 / cbData.RowsOfResolution ) / ( 2.0 / cbData.RowsOfResolution );
        float scanlineDistance = abs( scanlineY - 0.5 ) / 0.5;
        float scanlineCoverage = exp2( scanlineDistance * scanlineDistance * -cbData.ScanlineHardness );
        scanlineMultiplier = mix( SCANLINE_MIN_BRIGHTNESS, float3( 1.0 ), scanlineCoverage );
    }

    return max( inputSample * scanlineMultiplier, float3( MIN_BRIGHTNESS ) ) * getShadowMaskRGB( cbData, uv );
}

INLINE
float3 sampleRow( texture2d<float> EmulatedImage, constant CRT_Data& cbData, float2 uv, float3 centerTap )
{
    float2 leftUV = uv + float2( -1.0 / FINAL_RES.x, 0.0 );
    float2 rightUV = uv + float2( 1.0 / FINAL_RES.x, 0.0 );
    return centerTap * 0.5
    + sampleRGB( EmulatedImage, cbData, leftUV, Warp( cbData, leftUV ) ) * 0.25
    + sampleRGB( EmulatedImage, cbData, rightUV, Warp( cbData, rightUV ) ) * 0.25;
}

INLINE
float3 sampleCol( texture2d<float> EmulatedImage, constant CRT_Data& cbData, float2 uv, float3 centerTap )
{
    return sampleRow( EmulatedImage, cbData, uv, centerTap );
}

INLINE
float3 crtFilter( texture2d<float> EmulatedImage, constant CRT_Data& cbData, float2 uv )
{
    float2 warpedUV = Warp( cbData, uv );
    float edgeMask = clamp( 1.0 - exp2( ( 1.0 - max( abs( warpedUV.x - 0.5 ), abs( warpedUV.y - 0.5 ) ) / 0.5 ) * -WARP_EDGE_HARDNESS ), 0.0, 1.0);
    float bloomAmount = cbData.BloomAmount;
    if (cbData.UseScanlines) {
        bloomAmount *= 2.0;
    }
    float3 centerTap = sampleRGB( EmulatedImage, cbData, uv, warpedUV );
    return ToDispGamma( ( centerTap + sampleCol( EmulatedImage, cbData, uv, centerTap ) * bloomAmount ) * edgeMask, cbData.DisplayGamma );
}

fragment float4 crt_filter_ps(Inputs I [[stage_in]], texture2d<float> EmulatedImage [[texture(0)]], constant CRT_Data& cbData [[buffer(0)]])
{
    float4 output;
    output.rgb = crtFilter( EmulatedImage, cbData, INPUTCOORD_TO_UV( I.fTexCoord, cbData ) );
    output.a = 1.0;
    return output;
}
