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

#include <metal_stdlib>
using namespace metal;

struct Inputs
{
    float2 fTexCoord [[user(TEXCOORD0)]];
};

struct CRT_Data
{
    float4 DisplayRect;
    float2 EmulatedImageSize;
    float2 FinalRes;
};

#define FINAL_RES cbData.FinalRes
// These are to convert input texture coordinates to UV (0-1) space and back.
#define INPUTCOORD_TO_UV( inputCoord, data ) ( inputCoord / data.DisplayRect.zw * data.EmulatedImageSize - data.DisplayRect.xy / data.DisplayRect.zw )
#define UV_TO_INPUTCOORD( uv, data ) ( data.DisplayRect.xy / data.EmulatedImageSize + uv / data.EmulatedImageSize * data.DisplayRect.zw )

#define USE_SCANLINES 1
#define USE_SHADOWMASK 1
#define USE_WARP 1

#define USE_POW_GAMMA 1
#ifdef TARGET_OS_TV
    #define DISPLAY_GAMMA 2.4 // Standard Display Gamma per ITU-R BT.1886
#else
    #define DISPLAY_GAMMA 2.2 // Measured Gamma response on a iPhone 12 Pro Max OLED Display
#endif

#define BLOOM_AMOUNT 2.0
#define MIN_BRIGHTNESS 0.0005
#define ROWS_OF_RESOLUTION 480.0
#define SCANLINES_ALLOWED ( FINAL_RES.y >= ROWS_OF_RESOLUTION / 2.0 * 4.0 )
#define SCANLINE_HARDNESS 4.0
#define SCANLINE_MIN_BRIGHTNESS float3( 0.25, 0.25, 0.25 )
#define SHADOW_MASK_HARDNESS 16.0

#define TVL 800.0

#define WARP_EDGE_HARDNESS 256.0
#define WARP_X ( 1.0 / 96.0 )
#define WARP_Y ( 1.0 / 36.0 )

#define INLINE inline __attribute__((always_inline))


#if USE_POW_GAMMA
    INLINE float ToLinear1(float c){return(pow(c, DISPLAY_GAMMA));}
    INLINE float3 ToLinear(float3 c){return float3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));}
    INLINE float ToDispGamma1(float c){return(pow(c, (1.0/DISPLAY_GAMMA)));}
    INLINE float3 ToDispGamma(float3 c){return float3(ToDispGamma1(c.r),ToDispGamma1(c.g),ToDispGamma1(c.b));}
#else
    INLINE float3 ToLinear(float3 c){return c*c;}
    INLINE float3 ToDispGamma(float3 c){return sqrt(c);}
#endif

INLINE
float2 Warp( float2 uv )
{
#if USE_WARP
    uv = uv * 2.0 - 1.0;
    uv *= float2( 1.0 + ( uv.y * uv.y ) * WARP_X, 1.0 + ( uv.x * uv.x ) * WARP_Y );
    return uv * 0.5 + 0.5;
#else
    return uv;
#endif
}

INLINE
float2 getShadowMaskRes(constant CRT_Data& cbData)
{
    float2 shadowMaskRes;
    if ( FINAL_RES.y / 3.0 < TVL * 2.0 )
    {
        shadowMaskRes = FINAL_RES / 3.0;
    }
    else
    {
        shadowMaskRes = float2( FINAL_RES.x / FINAL_RES.y * TVL, TVL );
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
#if USE_SHADOWMASK
    float2 shadowMaskRes = getShadowMaskRes(cbData);
    float2 pixelCoord = uv * shadowMaskRes * float2( 3.0, 3.0 );
    float3 shadowMaskCoord = float3( pixelCoord.x + 1.0, pixelCoord.x + 0.0, pixelCoord.x + 2.0 );
    float3 shadowMaskRGB = abs( mod( shadowMaskCoord, 3.0 ) - 1.5 ) / 1.5;
    shadowMaskRGB = exp2( shadowMaskRGB * shadowMaskRGB * -SHADOW_MASK_HARDNESS );
    return shadowMaskRGB;
#else
    return float3(1.0);
#endif
}

INLINE
float3 sampleRGB( texture2d<float> EmulatedImage, sampler Sampler, constant CRT_Data& cbData, float2 uv, float2 warpedUV )
{
    constexpr sampler SamplerF(address::clamp_to_zero, filter::linear);
    float3 inputSample = ToLinear( EmulatedImage.sample(SamplerF, UV_TO_INPUTCOORD( warpedUV, cbData )).rgb );
    
    float3 scanlineMultiplier = float3( 1.0 );
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        float scanlineY = mod( warpedUV.y, 2.0 / ROWS_OF_RESOLUTION ) / ( 2.0 / ROWS_OF_RESOLUTION );
        float scanlineDistance = abs( scanlineY - 0.5 ) / 0.5;
        float scanlineCoverage = exp2( scanlineDistance * scanlineDistance * -SCANLINE_HARDNESS );
        scanlineMultiplier = mix( SCANLINE_MIN_BRIGHTNESS, float3( 1.0 ), scanlineCoverage );
    }
#endif
    
    return max( inputSample * scanlineMultiplier, float3( MIN_BRIGHTNESS ) ) * getShadowMaskRGB( cbData, uv );
}

INLINE
float3 sampleRow( texture2d<float> EmulatedImage, sampler Sampler, constant CRT_Data& cbData, float2 uv, float3 centerTap )
{
    float2 leftUV = uv + float2( -1.0 / FINAL_RES.x, 0.0 );
    float2 rightUV = uv + float2( 1.0 / FINAL_RES.x, 0.0 );
    return centerTap * 0.5
    + sampleRGB( EmulatedImage, Sampler, cbData, leftUV, Warp( leftUV ) ) * 0.25
    + sampleRGB( EmulatedImage, Sampler, cbData, rightUV, Warp( rightUV ) ) * 0.25;
}

INLINE
float3 sampleCol( texture2d<float> EmulatedImage, sampler Sampler, constant CRT_Data& cbData, float2 uv, float3 centerTap )
{
    return sampleRow( EmulatedImage, Sampler, cbData, uv, centerTap );
}

INLINE
float3 crtFilter( texture2d<float> EmulatedImage, sampler Sampler, constant CRT_Data& cbData, float2 uv )
{
    float2 warpedUV = Warp( uv );
    float edgeMask = clamp( 1.0 - exp2( ( 1.0 - max( abs( warpedUV.x - 0.5 ), abs( warpedUV.y - 0.5 ) ) / 0.5 ) * -WARP_EDGE_HARDNESS ), 0.0, 1.0);
    float bloomAmount = BLOOM_AMOUNT;
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        bloomAmount *= 2.0;
    }
#endif
    float3 centerTap = sampleRGB( EmulatedImage, Sampler, cbData, uv, warpedUV );
    return ToDispGamma( ( centerTap + sampleCol( EmulatedImage, Sampler, cbData, uv, centerTap ) * bloomAmount ) * edgeMask );
}

fragment float4 crt_filter_ps(Inputs I [[stage_in]], texture2d<float> EmulatedImage [[texture(0)]], sampler Sampler [[sampler(0)]], constant CRT_Data& cbData [[buffer(0)]])
{
    float4 output;
    output.rgb = crtFilter( EmulatedImage, Sampler, cbData, INPUTCOORD_TO_UV( I.fTexCoord, cbData ) );
    output.a = 1.0;
    return output;
}
