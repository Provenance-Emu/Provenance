#ifndef __DRIVERS_SHADER_H
#define __DRIVERS_SHADER_H

#include <map>

enum ShaderType
{
	SHADER_NONE = 0,
	SHADER_SCALE2X,
	SHADER_SABR,
        SHADER_AUTOIP,
	SHADER_AUTOIPSHARPER,
	SHADER_IPSHARPER,
        SHADER_IPXNOTY,
        SHADER_IPXNOTYSHARPER,
        SHADER_IPYNOTX,
        SHADER_IPYNOTXSHARPER,

	SHADER_GOAT,
};

struct ShaderParams
{
	float goat_hdiv;
	float goat_vdiv;
	float goat_tp;
	enum
	{
	 GOAT_MASKPAT_BORG = 0,
	 GOAT_MASKPAT_GOATRON,
	 GOAT_MASKPAT_GOATRONPRIME,
	 GOAT_MASKPAT_SLENDERMAN,
	};
	unsigned goat_pat;
	bool goat_slen;
	bool goat_fprog;
};

class OpenGL_Blitter;
class OpenGL_Blitter_Shader
{
 public:

 OpenGL_Blitter_Shader(OpenGL_Blitter *in_oblt, ShaderType pixshader, const ShaderParams& in_params);
 ~OpenGL_Blitter_Shader();

 void ShaderBegin(const int gl_screen_w, const int gl_screen_h, const MDFN_Rect *rect, const MDFN_Rect *dest_rect, int tw, int th, int orig_tw, int orig_th, unsigned rotated);
 void ShaderEnd(void);
 bool ShaderNeedsBTIP(void);
 bool ShaderNeedsProperIlace(void);

 private:

 struct CompiledShader
 {
  GLhandleARB v, f, p;
  bool v_valid, f_valid, p_valid;
 };

 enum { CSP_COUNT = 8 };

 void Cleanup(void);
 void SLP(GLhandleARB moe);
 void CompileShader(CompiledShader &s, const char *vertex_prog, const char *frag_prog);

 ShaderType OurType;
 CompiledShader CSP[CSP_COUNT];
 OpenGL_Blitter* const oblt;

 const ShaderParams params;

 void UpdateGoatMask(const unsigned rotated);
 unsigned GoatMaskLastRot;
};

#endif
