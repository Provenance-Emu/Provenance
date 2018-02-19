#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ < 300
#define texture texture2D
#endif

uniform sampler2D EmulatedImage;

varying highp vec2 fTexCoord;

void main( void )
{
    gl_FragColor.rgb = texture( EmulatedImage, fTexCoord ).rgb;
    gl_FragColor.a = 1.0;
}
