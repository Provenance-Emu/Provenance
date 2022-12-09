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

#ifdef GL_ES
precision highp float;
#endif

#if __VERSION__ < 300
#define texture texture2D
#endif

varying highp vec2 fTexCoord;

uniform vec4 DisplayRect;
uniform sampler2D EmulatedImage;
uniform vec2 EmulatedImageSize;
uniform vec2 FinalRes;

#define FINAL_RES FinalRes
#define INPUT_SAMPLER EmulatedImage
// These are to convert input texture coordinates to UV (0-1) space and back.
#define INPUTCOORD_TO_UV( inputCoord ) ( inputCoord / DisplayRect.zw * EmulatedImageSize - DisplayRect.xy / DisplayRect.zw )
#define UV_TO_INPUTCOORD( uv ) ( DisplayRect.xy / EmulatedImageSize + uv / EmulatedImageSize * DisplayRect.zw )

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
#define SCANLINE_MIN_BRIGHTNESS vec3( 0.25, 0.25, 0.25 )
#define SHADOW_MASK_HARDNESS 16.0

#define TVL 800.0

#define WARP_EDGE_HARDNESS 256.0
#define WARP_X ( 1.0 / 96.0 )
#define WARP_Y ( 1.0 / 36.0 )

#if USE_POW_GAMMA
    float ToLinear1(float c){return(pow(c, DISPLAY_GAMMA));}
    vec3 ToLinear(vec3 c){return vec3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));}

    float ToDispGamma1(float c){return(pow(c, (1.0/DISPLAY_GAMMA)));}
    vec3 ToDispGamma(vec3 c){return vec3(ToDispGamma1(c.r),ToDispGamma1(c.g),ToDispGamma1(c.b));}
#else
    vec3 ToLinear(vec3 c){return c*c;}
    vec3 ToDispGamma(vec3 c){return sqrt(c);}
#endif

highp vec2 Warp( highp vec2 uv )
{
#if USE_WARP
    uv = uv * 2.0 - 1.0;
    uv *= vec2( 1.0 + ( uv.y * uv.y ) * WARP_X, 1.0 + ( uv.x * uv.x ) * WARP_Y );
    return uv * 0.5 + 0.5;
#else
   return uv;
#endif
}

vec2 getShadowMaskRes()
{
    vec2 shadowMaskRes;
    if ( FINAL_RES.y / 3.0 < TVL * 2.0 )
    {
        shadowMaskRes = FINAL_RES / 3.0;
    }
    else
    {
        shadowMaskRes = vec2( FINAL_RES.x / FINAL_RES.y * TVL, TVL );
    }
    return shadowMaskRes;
}

vec3 getShadowMaskRGB( highp vec2 uv )
{
#if USE_SHADOWMASK
    vec2 shadowMaskRes = getShadowMaskRes();
    highp vec2 pixelCoord = uv * shadowMaskRes * vec2( 3.0, 3.0 );
    highp vec3 shadowMaskCoord = vec3( pixelCoord.x + 1.0, pixelCoord.x + 0.0, pixelCoord.x + 2.0 );
    vec3 shadowMaskRGB = abs( mod( shadowMaskCoord, 3.0 ) - 1.5 ) / 1.5;
    shadowMaskRGB = exp2( shadowMaskRGB * shadowMaskRGB * -SHADOW_MASK_HARDNESS );
    return shadowMaskRGB;
#else
    return vec3(1.0);
#endif
}

vec3 sampleRGB( highp vec2 uv, highp vec2 warpedUV )
{
    vec3 inputSample = ToLinear( texture( INPUT_SAMPLER, UV_TO_INPUTCOORD( warpedUV ) ).rgb );
    
    vec3 scanlineMultiplier = vec3( 1.0 );
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        float scanlineY = mod( warpedUV.y, 2.0 / ROWS_OF_RESOLUTION ) / ( 2.0 / ROWS_OF_RESOLUTION );
        float scanlineDistance = abs( scanlineY - 0.5 ) / 0.5;
        float scanlineCoverage = exp2( scanlineDistance * scanlineDistance * -SCANLINE_HARDNESS );
        scanlineMultiplier = mix( SCANLINE_MIN_BRIGHTNESS, vec3( 1.0 ), scanlineCoverage );
    }
#endif
    
    return max( inputSample * scanlineMultiplier, vec3( MIN_BRIGHTNESS ) ) * getShadowMaskRGB( uv );
}

vec3 sampleRow( highp vec2 uv, vec3 centerTap )
{
    highp vec2 leftUV = uv + vec2( -1.0 / FINAL_RES.x, 0.0 );
    highp vec2 rightUV = uv + vec2( 1.0 / FINAL_RES.x, 0.0 );
    return centerTap * 0.5
    + sampleRGB( leftUV, Warp( leftUV ) ) * 0.25
    + sampleRGB( rightUV, Warp( rightUV ) ) * 0.25;
}

vec3 sampleCol( highp vec2 uv, vec3 centerTap )
{
    return sampleRow( uv, centerTap );
}

vec3 crtFilter( highp vec2 uv )
{
    highp vec2 warpedUV = Warp( uv );
    float edgeMask = clamp( 1.0 - exp2( ( 1.0 - max( abs( warpedUV.x - 0.5 ), abs( warpedUV.y - 0.5 ) ) / 0.5 ) * -WARP_EDGE_HARDNESS ), 0.0, 1.0);
    float bloomAmount = BLOOM_AMOUNT;
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        bloomAmount *= 2.0;
    }
#endif
    vec3 centerTap = sampleRGB( uv, warpedUV );
    return ToDispGamma( ( centerTap + sampleCol( uv, centerTap ) * bloomAmount ) * edgeMask );
}

void main( void )
{
    gl_FragColor.rgb = crtFilter( INPUTCOORD_TO_UV( fTexCoord ) );
    gl_FragColor.a = 1.0;
}
