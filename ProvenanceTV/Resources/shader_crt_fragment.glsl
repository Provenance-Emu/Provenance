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
precision highp float;
#endif

#if __VERSION__ < 300
#define texture texture2D
#endif

varying vec2 fTexCoord;

uniform sampler2D EmulatedImage;
uniform vec4 EmulatedImageRes;
uniform vec2 FinalRes;

#define FINAL_RES FinalRes
#define INPUT_RES EmulatedImageRes.xy
#define INPUT_SAMPLER EmulatedImage
#define UV_TO_INPUTCOORD( uv ) ( uv / EmulatedImageRes.zw * EmulatedImageRes.xy )

#define USE_SCANLINES 1
#define USE_SHADOWMASK 1

#define BLOOM_AMOUNT 2.0
#define MIN_BRIGHTNESS 0.003
#define SCANLINES_ALLOWED ( FINAL_RES.y >= INPUT_RES.y * 3.0 )
#define SCANLINE_HARDNESS 4.0
#define SCANLINE_MIN_BRIGHTNESS vec3( 0.25, 0.0, 0.25 )
#define SHADOW_MASK_HARDNESS 16.0
#define WARP_EDGE_HARDNESS 256.0
#define WARP_X ( 1.0 / 64.0 )
#define WARP_Y ( 1.0 / 24.0 )

float ToLinear1(float c){return(c<=0.04045)?c/12.92:pow((c+0.055)/1.055,2.4);}
vec3 ToLinear(vec3 c){return vec3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));}

float ToSrgb1(float c){return(c<0.0031308?c*12.92:1.055*pow(c,0.41666)-0.055);}
vec3 ToSrgb(vec3 c){return vec3(ToSrgb1(c.r),ToSrgb1(c.g),ToSrgb1(c.b));}

vec2 Warp( vec2 uv )
{
    uv = uv * 2.0 - 1.0;
    uv *= vec2( 1.0 + ( uv.y * uv.y ) * WARP_X, 1.0 + ( uv.x * uv.x ) * WARP_Y );
    return uv * 0.5 + 0.5;
}

vec3 getShadowMaskRGB( vec2 uv )
{
#if USE_SHADOWMASK
    vec2 shadowMaskRes;
    if ( FINAL_RES.y / 3.0 < 480.0 )
    {
        shadowMaskRes = FINAL_RES / 3.0;
    }
    else
    {
        shadowMaskRes = vec2( FINAL_RES.x / FINAL_RES.y * 480.0, 480.0 );
    }
    vec2 pixelCoord = uv * shadowMaskRes * vec2( 3.0, 3.0 );
    
    vec3 shadowMaskRGB;
    shadowMaskRGB.r = abs( mod( pixelCoord.x + 1.5, 3.0 ) - 1.5 ) / 1.5;
    shadowMaskRGB.g = abs( mod( pixelCoord.x + 0.5, 3.0 ) - 1.5 ) / 1.5;
    shadowMaskRGB.b = abs( mod( pixelCoord.x + 2.5, 3.0 ) - 1.5 ) / 1.5;
    shadowMaskRGB = min( shadowMaskRGB, 1.0 );
    shadowMaskRGB = exp2( shadowMaskRGB * shadowMaskRGB * -SHADOW_MASK_HARDNESS );
    return shadowMaskRGB;
#else
    return vec3(1.0);
#endif
}

vec3 sampleRGB( vec2 uv )
{
    vec2 warpedUV = Warp( uv );
    float edgeMask = 1.0 - exp2( ( 1.0 - max( abs( warpedUV.x - 0.5 ), abs( warpedUV.y - 0.5 ) ) / 0.5 ) * -WARP_EDGE_HARDNESS );
    float inputSpaceY = warpedUV.y * INPUT_RES.y;
    
    vec3 inputSample = ToLinear( texture( INPUT_SAMPLER, UV_TO_INPUTCOORD( warpedUV ) ).rgb );
    
    vec3 scanlineMultiplier = vec3( 1.0 );
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        float scanlineY = mod( inputSpaceY, 1.0 );
        float scanlineDistance = abs( scanlineY - 0.5 ) / 0.5;
        float scanlineCoverage = exp2( scanlineDistance * scanlineDistance * -SCANLINE_HARDNESS );
        scanlineMultiplier = mix( SCANLINE_MIN_BRIGHTNESS, vec3( 1.0 ), scanlineCoverage );
    }
#endif
    
    return max( inputSample * scanlineMultiplier, vec3( MIN_BRIGHTNESS ) ) * getShadowMaskRGB( uv ) * edgeMask;
}

vec3 sampleRow( vec2 uv )
{
    return sampleRGB( uv ) * 0.5
    + sampleRGB( uv + vec2( -1.0 / FINAL_RES.x, 0.0 ) ) * 0.25
    + sampleRGB( uv + vec2( 1.0 / FINAL_RES.x, 0.0 ) ) * 0.25;
}

vec3 sampleCol( vec2 uv )
{
    return sampleRow( uv );
}

vec3 crtFilter( vec2 uv )
{
    float bloomAmount = BLOOM_AMOUNT;
#if USE_SCANLINES
    if ( SCANLINES_ALLOWED )
    {
        bloomAmount *= 2.0;
    }
#endif
    return ToSrgb( sampleRGB( uv ) + sampleCol( uv ) * bloomAmount );
}

void main( void )
{
    vec2 uv = fTexCoord / EmulatedImageRes.xy * EmulatedImageRes.zw;
    gl_FragColor.rgb = crtFilter( uv );
    gl_FragColor.a = 1.0;
}
