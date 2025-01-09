// Scale2x GLslang shader - ported by Pete Bernert
//
// Scale2x Homepage: http://scale2x.sourceforge.net/
//
// Scale2X is using the GPL, so feel free to use this shader in your work, but
// publish the source as well, for other interested coders to see and/or modify.

/*
 Modified for usage in Mednafen.
*/

static const char *fragScale2X =
"uniform vec2 TexSize;\n\
uniform vec2 TexSizeInverse;\n\
uniform sampler2D Tex0;\n\
void main()\n\
{\n\
 vec4 colD,colF,colB,colH,col,tmp;\n\
 vec2 sel;\n\
 vec4 chewx = vec4(TexSizeInverse.x, 0, 0, 0);\n\
 vec4 chewy = vec4(0, TexSizeInverse.y, 0, 0);\n\
 vec4 MeowCoord = gl_TexCoord[0];\n\
 col  = texture2DProj(Tex0, MeowCoord);	\n\
 colD = texture2DProj(Tex0, MeowCoord - chewx);	\n\
 colF = texture2DProj(Tex0, MeowCoord + chewx);	\n\
 colB = texture2DProj(Tex0, MeowCoord - chewy);	\n\
 colH = texture2DProj(Tex0, MeowCoord + chewy);	\n\
 sel=fract(gl_TexCoord[0].xy * TexSize.xy);		\n\
 if(sel.y>=0.5)  {tmp=colB;colB=colH;colH=tmp;}		\n\
 if(sel.x>=0.5)  {tmp=colF;colF=colD;colD=tmp;}		\n\
 if(colB == colD && colB != colF && colD!=colH) 	\n\
  col=colD;\n\
 gl_FragColor = col;\n\
}";

