// PUBLIC DOMAIN CRT SHADER
//
//   by Jay Mattis
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

#ifdef GL_ES
precision mediump float;
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

#define BLOOM_AMOUNT 2.0
#define MIN_BRIGHTNESS 0.003
#define ROWS_OF_RESOLUTION 480.0
#define SCANLINES_ALLOWED ( FINAL_RES.y >= ROWS_OF_RESOLUTION / 2.0 * 4.0 )
#define SCANLINE_HARDNESS 4.0
#define SCANLINE_MIN_BRIGHTNESS vec3( 0.25, 0.25, 0.25 )
#define SHADOW_MASK_HARDNESS 16.0
#define TVL 360.0
#define WARP_EDGE_HARDNESS 256.0
#define WARP_X ( 1.0 / 64.0 )
#define WARP_Y ( 1.0 / 24.0 )

float ToLinear1(float c){return(c<=0.04045)?c/12.92:pow((c+0.055)/1.055,2.4);}
vec3 ToLinear(vec3 c){return c*c;}//return vec3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));}

float ToSrgb1(float c){return(c<0.0031308?c*12.92:1.055*pow(c,0.41666)-0.055);}
vec3 ToSrgb(vec3 c){return sqrt(c);}//return vec3(ToSrgb1(c.r),ToSrgb1(c.g),ToSrgb1(c.b));}

highp vec2 Warp( highp vec2 uv )
{
    uv = uv * 2.0 - 1.0;
    uv *= vec2( 1.0 + ( uv.y * uv.y ) * WARP_X, 1.0 + ( uv.x * uv.x ) * WARP_Y );
    return uv * 0.5 + 0.5;
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
    //vec3 shadowMaskRGB = clamp( abs( mod( shadowMaskCoord, 3.0 ) - 1.5 ) - 0.5, 0.0, 1.0 );
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
    float edgeMask = 1.0 - exp2( ( 1.0 - max( abs( warpedUV.x - 0.5 ), abs( warpedUV.y - 0.5 ) ) / 0.5 ) * -WARP_EDGE_HARDNESS );
    float bloomAmount = BLOOM_AMOUNT;
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        bloomAmount *= 2.0;
    }
#endif
    vec3 centerTap = sampleRGB( uv, warpedUV );
    return ToSrgb( ( centerTap + sampleCol( uv, centerTap ) * bloomAmount ) * edgeMask );
}

void main( void )
{
    gl_FragColor.rgb = crtFilter( INPUTCOORD_TO_UV( fTexCoord ) );
    gl_FragColor.a = 1.0;
}
