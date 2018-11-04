/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"
#include "opengl.h"
#include "shader.h"

#include <mednafen/FileStream.h>
#include <mednafen/MemoryStream.h>

#define MDFN_GL_TRY(x, ...)								\
	{										\
	 x;										\
	 GLenum errcode = oblt->p_glGetError();						\
	 if(errcode != GL_NO_ERROR)							\
	 {										\
	  __VA_ARGS__;									\
											\
	  /* FIXME: Throw an error string and not an arcane number. */			\
	  throw MDFN_Error(0, _("OpenGL Error 0x%04x during \"%s\"."), (int)(long long)errcode, #x);	\
	 }										\
	}

static const char *vertexProg = "void main(void)\n{\ngl_Position = ftransform();\ngl_TexCoord[0] = gl_MultiTexCoord0;\n}";

static std::string MakeProgIpolate(unsigned ipolate_axis)	// X & 1, Y & 2, sharp & 4
{
 std::string ret;

 ret = std::string("\n\
	uniform sampler2D Tex0;\n\
	uniform vec2 TexSize;\n\
	uniform vec2 TexSizeInverse;\n\
	uniform float XSharp;\n\
	uniform float YSharp;\n\
	void main(void)\n\
	{\n\
	        vec2 texelIndex = vec2(gl_TexCoord[0]) * TexSize - float(0.5);\n\
	");

 if(ipolate_axis & 3)
 {
  ret += std::string("vec2 texelInt = floor(texelIndex);\n");
  ret += std::string("vec2 texelFract = texelIndex - texelInt - float(0.5);\n");

  switch(ipolate_axis & 3)
  {
   case 1:
	if(ipolate_axis & 4)
    	 ret += std::string("texelFract.s = clamp(texelFract.s * XSharp, -0.5, 0.5) + float(0.5);\n");
	else
	 ret += std::string("texelFract.s = texelFract.s + float(0.5);\n");

	ret += std::string("texelFract.t = floor(texelFract.t + float(1.0));\n");
	break;

   case 2:
	ret += std::string("texelFract.s = floor(texelFract.s + float(1.0));\n");

	if(ipolate_axis & 4)
    	 ret += std::string("texelFract.t = clamp(texelFract.t * YSharp, -0.5, 0.5) + float(0.5);\n");
	else
    	 ret += std::string("texelFract.t = texelFract.t + float(0.5);\n");
	break;

   case 3:
	if(ipolate_axis & 4)
	{
    	 ret += std::string("texelFract.s = clamp(texelFract.s * XSharp, -0.5, 0.5) + float(0.5);\n");
    	 ret += std::string("texelFract.t = clamp(texelFract.t * YSharp, -0.5, 0.5) + float(0.5);\n");
	}
	else
	{
	 ret += std::string("texelFract = texelFract + float(0.5);\n");
	}
	break;
  }
  ret += std::string("texelIndex = texelFract + texelInt;\n");
 }
 else
  ret += std::string("texelIndex = floor(texelIndex + float(0.5));\n");

 ret += std::string("texelIndex += float(0.5);\n");
 ret += std::string("texelIndex *= TexSizeInverse;\n");
 ret += std::string("gl_FragColor = vec4( texture2D(Tex0, texelIndex));\n");

 ret += std::string("}");

 return ret;
}

#include "shader_scale2x.inc"
#include "shader_sabr.inc"

static std::string BuildGoat(const bool slen)
{
 std::string ret;

ret += "\n\
uniform ivec2 MaskDim;\n\
uniform vec3 TexRGBAdj[400];\n\
uniform float TexXCoordAdj;\n\
uniform vec3 TexYCoordAdj;\n\
\n\
uniform sampler2D Tex0;\n\
uniform vec2 TexSize;\n\
uniform vec2 TexSizeInverse;\n\
uniform float XSharp;\n\
uniform float YSharp;\n\
\n\
void main(void)\n\
{\n\
 ivec2 fc = ivec2(gl_FragCoord);\n\
 ivec2 di = fc - MaskDim * (fc / MaskDim);\n\
\n\
 vec2 texelIndex = vec2(gl_TexCoord[0]) * TexSize - float(0.5);\n\
 vec3 texelIndexX = vec3(texelIndex.x - TexXCoordAdj, texelIndex.x, texelIndex.x + TexXCoordAdj);\n\
 vec3 texelIntX = floor(texelIndexX);\n\
 vec3 texelFractX = texelIndexX - texelIntX - float(0.5);\n\
\n\
 texelFractX = clamp(texelFractX * XSharp, -0.5, 0.5) + float(0.5);\n\
 texelIndexX = texelFractX + texelIntX;\n\
 texelIndexX += float(0.5);\n\
 texelIndexX *= TexSizeInverse.x;\n\
\n\
 vec3 texelIndexY = TexYCoordAdj + texelIndex.y;\n\
 vec3 texelIntY = floor(texelIndexY);\n\
 vec3 texelFractY = texelIndexY - texelIntY - float(0.5);\n\
\n";

 if(slen)
  ret += "vec3 slmul = min(abs(texelFractY) * float(2.0), float(1)) * float(0.40) + float(0.60);\n";

ret += "\n\
 texelFractY = clamp(texelFractY * YSharp, -0.5, 0.5) + float(0.5);\n\
 texelIndexY = texelFractY + texelIntY;\n\
 texelIndexY += float(0.5);\n\
 texelIndexY *= TexSizeInverse.y;\n\
\n\
 vec3 smoodged = vec3(texture2D(Tex0, vec2(texelIndexX.s, texelIndexY.s)).r,\n\
		      texture2D(Tex0, vec2(texelIndexX.t, texelIndexY.t)).g,\n\
		      texture2D(Tex0, vec2(texelIndexX.p, texelIndexY.p)).b);\n\
\n";

 ret += "smoodged = pow(smoodged, vec3(float(2.2) / float(1.0)));\n";
 ret += "smoodged *= TexRGBAdj[di.y * int(20) + di.x];\n";
 if(slen)
  ret += "smoodged *= slmul;\n";
 ret += "smoodged = pow(smoodged, vec3(float(1.0) / float(2.2)));\n";


 ret += "gl_FragColor = vec4(smoodged, float(0));\n";
 ret += "}\n";

 return ret;
}

void OpenGL_Blitter_Shader::SLP(GLhandleARB moe)
{
 char buf[1000];
 GLsizei buflen = 0;

 oblt->p_glGetInfoLogARB(moe, 999, &buflen, buf);
 buf[buflen] = 0;

 if(buflen)
 {
  throw MDFN_Error(0, "Shader compilation error:\n%s", buf);
 }
}

void OpenGL_Blitter_Shader::CompileShader(CompiledShader &s, const char *vertex_prog, const char *frag_prog)
{
	 int opi;

         oblt->p_glEnable(GL_FRAGMENT_PROGRAM_ARB);

         MDFN_GL_TRY(s.v = oblt->p_glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB));
	 s.v_valid = true;

         MDFN_GL_TRY(s.f = oblt->p_glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB));
	 s.f_valid = true;

         MDFN_GL_TRY(oblt->p_glShaderSourceARB(s.v, 1, &vertex_prog, NULL), SLP(s.v));
         MDFN_GL_TRY(oblt->p_glShaderSourceARB(s.f, 1, &frag_prog, NULL), SLP(s.f));

         MDFN_GL_TRY(oblt->p_glCompileShaderARB(s.v), SLP(s.v));
	 MDFN_GL_TRY(oblt->p_glGetObjectParameterivARB(s.v, GL_OBJECT_COMPILE_STATUS_ARB, &opi));
	 if(GL_FALSE == opi)
	 {
	  SLP(s.v);
	 }

         MDFN_GL_TRY(oblt->p_glCompileShaderARB(s.f), SLP(s.f));
         MDFN_GL_TRY(oblt->p_glGetObjectParameterivARB(s.f, GL_OBJECT_COMPILE_STATUS_ARB, &opi));
         if(GL_FALSE == opi)
	 {
	  SLP(s.f);
	 }

         MDFN_GL_TRY(s.p = oblt->p_glCreateProgramObjectARB(), SLP(s.p));
	 s.p_valid = true;

         MDFN_GL_TRY(oblt->p_glAttachObjectARB(s.p, s.v));
         MDFN_GL_TRY(oblt->p_glAttachObjectARB(s.p, s.f));

         MDFN_GL_TRY(oblt->p_glLinkProgramARB(s.p), SLP(s.p));

         MDFN_GL_TRY(oblt->p_glDisable(GL_FRAGMENT_PROGRAM_ARB));
}

void OpenGL_Blitter_Shader::Cleanup(void)
{
        oblt->p_glUseProgramObjectARB(0);

	for(unsigned i = 0; i < CSP_COUNT; i++)
	{
	 if(CSP[i].p_valid)
	 {
	  if(CSP[i].f_valid)
	   oblt->p_glDetachObjectARB(CSP[i].p, CSP[i].f);
	  if(CSP[i].v_valid)
  	   oblt->p_glDetachObjectARB(CSP[i].p, CSP[i].v);
	 }
	 if(CSP[i].f_valid)
	  oblt->p_glDeleteObjectARB(CSP[i].f);
	 if(CSP[i].v_valid)
	  oblt->p_glDeleteObjectARB(CSP[i].v);
	 if(CSP[i].p_valid)
	  oblt->p_glDeleteObjectARB(CSP[i].p);

	 CSP[i].f_valid = CSP[i].v_valid = CSP[i].p_valid = false;
	}

        oblt->p_glDisable(GL_FRAGMENT_PROGRAM_ARB);
}

OpenGL_Blitter_Shader::OpenGL_Blitter_Shader(OpenGL_Blitter *in_oblt, ShaderType shader_type, const ShaderParams& in_params) : oblt(in_oblt), params(in_params)
{
	OurType = shader_type;

	memset(&CSP, 0, sizeof(CSP));

	try
	{
	 switch(OurType)
	 {
	  case SHADER_SCALE2X:
		CompileShader(CSP[0], vertexProg, fragScale2X);
		break;

	  case SHADER_SABR:
		CompileShader(CSP[0], vertSABR, fragSABR);
		break;

	  case SHADER_GOAT:
		{
#if 0
		 MemoryStream foof(new FileStream("goat.txt", FileStream::MODE_READ));

		 foof.seek(0, SEEK_END);
		 foof.put_u8(0);

		 CompileShader(CSP[0], vertexProg, (const char*)foof.map());
#endif
		 std::string fragGoat = BuildGoat(params.goat_slen);

		 CompileShader(CSP[0], vertexProg, fragGoat.c_str());
		 GoatMaskLastRot = ~0U;
		}
		break;

	  default:
		for(unsigned i = 0; i < 8; i++)
		{
		 CompileShader(CSP[i], vertexProg, MakeProgIpolate(i).c_str());
		}
		break;
	 }
	}
	catch(...)
	{
	 Cleanup();
	 throw;
	}
}

bool OpenGL_Blitter_Shader::ShaderNeedsBTIP(void)
{
 if(OurType != SHADER_SCALE2X && OurType != SHADER_SABR)
  return(true);

 return(false);
}

bool OpenGL_Blitter_Shader::ShaderNeedsProperIlace(void)
{
 return (OurType == SHADER_GOAT) && !params.goat_fprog;
}

void OpenGL_Blitter_Shader::UpdateGoatMask(const unsigned rotated)
{
 bool hblack;
 bool vblack;
 unsigned mask_w, mask_h;

 if(params.goat_pat == ShaderParams::GOAT_MASKPAT_GOATRON)
 {
  mask_w = 3;
  mask_h = 1;
  hblack = false;
  vblack = false;
 }
 else if(params.goat_pat == ShaderParams::GOAT_MASKPAT_GOATRONPRIME)
 {
  mask_w = 4;
  mask_h = 1;
  hblack = true;
  vblack = false;
 }
 else if(params.goat_pat == ShaderParams::GOAT_MASKPAT_SLENDERMAN)
 {
  mask_w = 20;
  mask_h = 10;
  hblack = true;
  vblack = true;
 }
 else
 {
  mask_w = 8;
  mask_h = 4;
  hblack = true;
  vblack = true;
 }

 float rgbadj[20][20][3];

 for(unsigned y = 0; y < mask_h; y++)
 {
  for(unsigned x = 0; x < mask_w; x++)	
  {
   const unsigned jx = x;
   const unsigned jy = y;

   for(unsigned i = 0; i < 3; i++)
   {
    float tmp;
    bool in_black = false;

    if(((jx & 0x3) == 0x3) && hblack)
     in_black = true;

    if(vblack)
    {
     if(params.goat_pat == ShaderParams::GOAT_MASKPAT_SLENDERMAN)
     {
      if(((jy + ((jx / 4) * 2)) % 5) == 4)
       in_black = true;
     }
     else
     {
      if(jy == ((mask_h >> (jx >= (mask_w / 2))) - 1))
       in_black = true;
     }
    }

    if(in_black)
     tmp = params.goat_tp;
    else if(jx % (hblack ? 4 : 3) == i)
     tmp = 1.0;
    else
     tmp = params.goat_tp;

    //
    unsigned adx = x;
    unsigned ady = y;

    if(rotated == MDFN_ROTATE90)
     rgbadj[adx][ady][i] = tmp;
    else if(rotated == MDFN_ROTATE270)
     rgbadj[mask_w - 1 - adx][mask_h - 1 - ady][i] = tmp;
    else
     rgbadj[mask_h - 1 - ady][adx][i] = tmp;
   }
  }
 }

#if 0
	 printf("Pattern %dx%d:\n", mask_w, mask_h);
	 for(unsigned y = 0; y < mask_h; y++)
	 {
          for(unsigned x = 0; x < mask_w; x++)
	  {
	   printf("[%.1f %.1f %.1f] ", rgbadj[y][x][0], rgbadj[y][x][1], rgbadj[y][x][2]);
	  }
	  printf("\n");
	 }
	 printf("\n\n");
#endif
 oblt->p_glUniform3fvARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexRGBAdj"), 400, (const float*)rgbadj);

 {
  unsigned smw = mask_w, smh = mask_h;

  if(rotated == MDFN_ROTATE90 || rotated == MDFN_ROTATE270)
   std::swap(smw, smh);

  oblt->p_glUniform2iARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "MaskDim"), smw, smh);
 }
 GoatMaskLastRot = rotated;
}

void OpenGL_Blitter_Shader::ShaderBegin(const int gl_screen_w, const int gl_screen_h, const MDFN_Rect *rect, const MDFN_Rect *dest_rect, int tw, int th, int orig_tw, int orig_th, unsigned rotated)
{
        oblt->p_glEnable(GL_FRAGMENT_PROGRAM_ARB);

	//printf("%d:%d, %d:%d\n", tw, th, orig_tw, orig_th);
	//printf("%f\n", (double)dest_rect->w / rect->w);
        //printf("%f\n", (double)dest_rect->h / rect->h);
	if(OurType == SHADER_SCALE2X)
	{
 	 oblt->p_glUseProgramObjectARB(CSP[0].p);

         oblt->p_glUniform1iARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "Tex0"), 0);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexSize"), tw, th);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexSizeInverse"), (float)1 / tw, (float) 1 / th);
	}
	else if(OurType == SHADER_SABR)
	{
 	 oblt->p_glUseProgramObjectARB(CSP[0].p);

         oblt->p_glUniform1iARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "rubyTexture"), 0);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "rubyTextureSize"), tw, th);
	}
	else if(OurType == SHADER_GOAT)
	{
 	 oblt->p_glUseProgramObjectARB(CSP[0].p);

         oblt->p_glUniform1iARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "Tex0"), 0);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexSize"), tw, th);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexSizeInverse"), (float)1 / tw, (float) 1 / th);


	 float ipc_drw = dest_rect->w;
	 float ipc_drh = dest_rect->h;

	 if(rotated == MDFN_ROTATE90 || rotated == MDFN_ROTATE270)
 	  std::swap(ipc_drw, ipc_drh);

         oblt->p_glUniform1fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "XSharp"), std::max<float>(1.0, ipc_drw / rect->w * 0.25));
         oblt->p_glUniform1fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "YSharp"), std::max<float>(1.0, ipc_drh / rect->h * 0.25));

	 float xpp = (float)1.0 / dest_rect->w;
	 float ypp = (float)1.0 / dest_rect->h;

	 oblt->p_glUniform1fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexXCoordAdj"), tw * xpp * params.goat_hdiv);
	 {
	  float ycab = th * ypp * params.goat_vdiv;

	  oblt->p_glUniform3fARB(oblt->p_glGetUniformLocationARB(CSP[0].p, "TexYCoordAdj"), -ycab, -ycab / 2, ycab);
	 }

	 if(rotated != GoatMaskLastRot)
	  UpdateGoatMask(rotated);
	}
	else
	{
	 unsigned csi;
	 float sharpness = 2.0;
	 float xsh;
	 float ysh;
	 unsigned ip_x;
	 unsigned ip_y;
	 double drw_div_rw;
	 double drh_div_rh;

	 if(rotated == MDFN_ROTATE90 || rotated == MDFN_ROTATE270)
	 {
          drw_div_rw = (double)dest_rect->h / rect->w;
          drh_div_rh = (double)dest_rect->w / rect->h;
	 }
	 else
	 {
          drw_div_rw = (double)dest_rect->w / rect->w;
          drh_div_rh = (double)dest_rect->h / rect->h;
	 }

	 ip_x = 1;
	 ip_y = 1;

	 if(OurType == SHADER_AUTOIP)
	 {
	  xsh = 1;
	  ysh = 1;
	 }
	 else
	 {
	  xsh = drw_div_rw / sharpness;
	  ysh = drh_div_rh / sharpness;
	 }

	 if(OurType == SHADER_IPXNOTY || OurType == SHADER_IPXNOTYSHARPER)
	 {
	  if(OurType == SHADER_IPXNOTY)
	  {
	   xsh = 0;
	  }
	  ysh = 0;
	  ip_x = 1;
	  ip_y = 0;
	 }
	 else if(OurType == SHADER_IPYNOTX || OurType == SHADER_IPYNOTXSHARPER)
	 {
	  if(OurType == SHADER_IPYNOTX)
	  {
	   ysh = 0;
	  }
	  xsh = 0;
 	  ip_x = 0;
	  ip_y = 1;
	 }
	 else if(OurType == SHADER_IPSHARPER)
	 {
	  ip_x = true;
	  ip_y = true;
	 }
	 else
	 {
	  // Scaling X by an integer?
	  if(floor(drw_div_rw) == drw_div_rw)
	  {
	   xsh = 0;
	   ip_x = 0;
	  }

	  // Scaling Y by an integer?
	  if(floor(drh_div_rh) == drh_div_rh)
	  {
	   ysh = 0;
	   ip_y = 0;
	  }
	 }

	 if(xsh < 1)
	  xsh = 1;

	 if(ysh < 1)
	  ysh = 1;

	 csi = (ip_y << 1) | ip_x;
	 if(xsh > 1 && ip_x)
	  csi |= 4;
	 if(ysh > 1 && ip_y)
	  csi |= 4;

 	 oblt->p_glUseProgramObjectARB(CSP[csi].p);

//	printf("%d:%d, %d\n", ip_x, ip_y, csi);

         oblt->p_glUniform1iARB(oblt->p_glGetUniformLocationARB(CSP[csi].p, "Tex0"), 0);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[csi].p, "TexSize"), tw, th);
         oblt->p_glUniform2fARB(oblt->p_glGetUniformLocationARB(CSP[csi].p, "TexSizeInverse"), (float)1 / tw, (float) 1 / th);

         oblt->p_glUniform1fARB(oblt->p_glGetUniformLocationARB(CSP[csi].p, "XSharp"), xsh);
         oblt->p_glUniform1fARB(oblt->p_glGetUniformLocationARB(CSP[csi].p, "YSharp"), ysh);
	}
}

void OpenGL_Blitter_Shader::ShaderEnd(void)
{
	oblt->p_glUseProgramObjectARB(0);
	oblt->p_glDisable(GL_FRAGMENT_PROGRAM_ARB);
}

OpenGL_Blitter_Shader::~OpenGL_Blitter_Shader()
{
	Cleanup();
}

