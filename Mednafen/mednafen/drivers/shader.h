#ifndef __DRIVERS_SHADER_H
#define __DRIVERS_SHADER_H

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
};

class OpenGL_Blitter;
class OpenGL_Blitter_Shader
{
 public:

 OpenGL_Blitter_Shader(OpenGL_Blitter *in_oblt, ShaderType pixshader);
 ~OpenGL_Blitter_Shader();

 void ShaderBegin(const int gl_screen_w, const int gl_screen_h, const MDFN_Rect *rect, const MDFN_Rect *dest_rect, int tw, int th, int orig_tw, int orig_th, unsigned rotated);
 void ShaderEnd(void);
 bool ShaderNeedsBTIP(void);

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
};

#endif
