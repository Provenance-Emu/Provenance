#include <math.h>
#include "gles.h"
#include "rend/TexCache.h"
#include "cfg/cfg.h"

#ifdef TARGET_PANDORA
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/fb.h>

#ifndef FBIO_WAITFORVSYNC
	#define FBIO_WAITFORVSYNC _IOW('F', 0x20, __u32)
#endif
int fbdev = -1;
#endif

#ifndef GLES
#if HOST_OS != OS_DARWIN
#include <GL3/gl3w.c>
#pragma comment(lib,"Opengl32.lib")
#endif
#endif

/*
GL|ES 2
Slower, smaller subset of gl2

*Optimisation notes*
Keep stuff in packed ints
Keep data as small as possible
Keep vertex programs as small as possible
The drivers more or less suck. Don't depend on dynamic allocation, or any 'complex' feature
as it is likely to be problematic/slow
Do we really want to enable striping joins?

*Design notes*
Follow same architecture as the d3d renderer for now
Render to texture, keep track of textures in GL memory
Direct flip to screen (no vlbank/fb emulation)
Do we really need a combining shader? it is needlessly expensive for openGL | ES
Render contexts
Free over time? we actually care about ram usage here?
Limit max resource size? for psp 48k verts worked just fine

FB:
Pixel clip, mapping

SPG/VO:
mapping

TA:
Tile clip

*/

#include "oslib/oslib.h"
#include "rend/rend.h"
#include "hw/pvr/Renderer_if.h"

void GenSorted();

float fb_scale_x,fb_scale_y;

#ifndef GLES
#define attr "in"
#define vary "out"
#else
#define attr "attribute"
#define vary "varying"
#endif
#if 1

//Fragment and vertex shaders code
//pretty much 1:1 copy of the d3d ones for now
const char* VertexShaderSource =
#ifndef GLES
	"#version 140 \n"
#endif
"\
/* Vertex constants*/  \n\
uniform highp vec4      scale; \n\
uniform highp vec4      depth_scale; \n\
uniform highp float sp_FOG_DENSITY; \n\
/* Vertex input */ \n\
" attr " highp vec4    in_pos; \n\
" attr " lowp vec4     in_base; \n\
" attr " lowp vec4     in_offs; \n\
" attr " mediump vec2  in_uv; \n\
/* output */ \n\
" vary " lowp vec4 vtx_base; \n\
" vary " lowp vec4 vtx_offs; \n\
" vary " mediump vec2 vtx_uv; \n\
" vary " highp vec3 vtx_xyz; \n\
void main() \n\
{ \n\
	vtx_base=in_base; \n\
	vtx_offs=in_offs; \n\
	vtx_uv=in_uv; \n\
	vec4 vpos=in_pos; \n\
	vtx_xyz.xy = vpos.xy;  \n\
	vtx_xyz.z = vpos.z*sp_FOG_DENSITY;  \n\
	vpos.w=1.0/vpos.z;  \n"
#ifndef GLES
	"\
	if (vpos.w < 0.0) { \n\
		gl_Position = vec4(0.0, 0.0, 0.0, vpos.w); \n\
		return; \n\
	} \n\
	vpos.z = vpos.w; \n"
#else
	"\
	vpos.z=depth_scale.x+depth_scale.y*vpos.w;  \n"
#endif
	"\
	vpos.xy=vpos.xy*scale.xy-scale.zw;  \n\
	vpos.xy*=vpos.w;  \n\
	gl_Position = vpos; \n\
}";


#else



const char* VertexShaderSource =
				""
				"/* Test Projection Matrix */"
				""
				"uniform highp mat4  Projection;"
				""
				""
				"/* Vertex constants */"
				""
				"uniform highp float sp_FOG_DENSITY;"
				"uniform highp vec4  scale;"
				""
				"/* Vertex output */"
				""
				"attribute highp   vec4 in_pos;"
				"attribute lowp    vec4 in_base;"
				"attribute lowp    vec4 in_offs;"
				"attribute mediump vec2 in_uv;"
				""
				"/* Transformed input */"
				""
				"varying lowp    vec4 vtx_base;"
				"varying lowp    vec4 vtx_offs;"
				"varying mediump vec2 vtx_uv;"
				"varying highp   vec3 vtx_xyz;"
				""
				"void main()"
				"{"
				"  vtx_base = in_base;"
				"  vtx_offs = in_offs;"
				"  vtx_uv   = in_uv;"
				""
				"  vec4 vpos  = in_pos;"
				"  vtx_xyz.xy = vpos.xy; "
				"  vtx_xyz.z  = vpos.z*sp_FOG_DENSITY; "
				""
				"  vpos.w     = 1.0/vpos.z; "
				"  vpos.z    *= -scale.w; "
				"  vpos.xy    = vpos.xy*scale.xy-sign(scale.xy); "
				"  vpos.xy   *= vpos.w; "
				""
				"  gl_Position = vpos;"
			//	"  gl_Position = vpos * Projection;"
				"}"
				;


#endif






/*

cp_AlphaTest 0 1        2 2
pp_ClipTestMode -1 0 1  3 6
pp_UseAlpha  0 1        2 12
pp_Texture 1
	pp_IgnoreTexA 0 1       2   2
	pp_ShadInstr 0 1 2 3    4   8
	pp_Offset 0 1           2   16
	pp_FogCtrl 0 1 2 3      4   64
pp_Texture 0
	pp_FogCtrl 0 2 3        4   4

pp_Texture: off -> 12*4=48 shaders
pp_Texture: on  -> 12*64=768 shaders
Total: 816 shaders

highp float fdecp(highp float flt,out highp float e)  \n\
{  \n\
	highp float lg2=log2(flt);  //ie , 2.5  \n\
	highp float frc=fract(lg2); //ie , 0.5  \n\
	e=lg2-frc;                  //ie , 2.5-0.5=2 (exp)  \n\
	return pow(2.0,frc);        //2^0.5 (manitsa)  \n\
}  \n\
lowp float fog_mode2(highp float invW)  \n\
{  \n\
	highp float foginvW=invW;  \n\
	foginvW=clamp(foginvW,1.0,255.0);  \n\
	  \n\
	highp float fogexp;                                 //0 ... 7  \n\
	highp float fogman=fdecp(foginvW, fogexp);          //[1,2) mantissa bits. that is 1.m  \n\
	  \n\
	highp float fogman_hi=fogman*16.0-16.0;             //[16,32) -16 -> [0,16)  \n\
	highp float fogman_idx=floor(fogman_hi);            //[0,15]  \n\
	highp float fogman_blend=fract(fogman_hi);          //[0,1) -- can also be fogman_idx-fogman_idx !  \n\
	highp float fog_idx_fr=fogexp*16.0+fogman_idx;      //[0,127]  \n\
	  \n\
	highp float fog_idx_pixel_fr=fog_idx_fr+0.5;  \n\
	highp float fog_idx_pixel_n=fog_idx_pixel_fr/128.0;//normalise to [0.5/128,127.5/128) coordinates  \n\
  \n\
	//fog is 128x1 texure  \n\
	lowp vec2 fog_coefs=texture2D(fog_table,vec2(fog_idx_pixel_n)).rg;  \n\
  \n\
	lowp float fog_coef=mix(fog_coefs.r,fog_coefs.g,fogman_blend);  \n\
	  \n\
	return fog_coef;  \n\
} \n\
*/

#ifndef GLES
#define FRAGCOL "FragColor"
#define TEXLOOKUP "texture"
#define vary "in"
#else
#define FRAGCOL "gl_FragColor"
#define TEXLOOKUP "texture2D"
#endif


const char* PixelPipelineShader =
#ifndef GLES
	"#version 140 \n"
	"out vec4 FragColor; \n"
#endif
"\
\
#define cp_AlphaTest %d \n\
#define pp_ClipTestMode %d \n\
#define pp_UseAlpha %d \n\
#define pp_Texture %d \n\
#define pp_IgnoreTexA %d \n\
#define pp_ShadInstr %d \n\
#define pp_Offset %d \n\
#define pp_FogCtrl %d \n\
/* Shader program params*/ \n\
/* gles has no alpha test stage, so its emulated on the shader */ \n\
uniform lowp float cp_AlphaTestValue; \n\
uniform lowp vec4 pp_ClipTest; \n\
uniform lowp vec3 sp_FOG_COL_RAM,sp_FOG_COL_VERT; \n\
uniform highp vec2 sp_LOG_FOG_COEFS; \n\
uniform sampler2D tex,fog_table; \n\
/* Vertex input*/ \n\
" vary " lowp vec4 vtx_base; \n\
" vary " lowp vec4 vtx_offs; \n\
" vary " mediump vec2 vtx_uv; \n\
" vary " highp vec3 vtx_xyz; \n\
lowp float fog_mode2(highp float val) \n\
{ \n\
	highp float fog_idx=clamp(val,0.0,127.99); \n\
	return clamp(sp_LOG_FOG_COEFS.y*log2(fog_idx)+sp_LOG_FOG_COEFS.x,0.001,1.0); //the clamp is required due to yet another bug !\n\
} \n\
void main() \n\
{ \n\
	// Clip outside the box \n\
	#if pp_ClipTestMode==1 \n\
		if (gl_FragCoord.x < pp_ClipTest.x || gl_FragCoord.x > pp_ClipTest.z \n\
				|| gl_FragCoord.y < pp_ClipTest.y || gl_FragCoord.y > pp_ClipTest.w) \n\
			discard; \n\
	#endif \n\
	// Clip inside the box \n\
	#if pp_ClipTestMode==-1 \n\
		if (gl_FragCoord.x >= pp_ClipTest.x && gl_FragCoord.x <= pp_ClipTest.z \n\
				&& gl_FragCoord.y >= pp_ClipTest.y && gl_FragCoord.y <= pp_ClipTest.w) \n\
			discard; \n\
	#endif \n\
	\n\
	lowp vec4 color=vtx_base; \n\
	#if pp_UseAlpha==0 \n\
		color.a=1.0; \n\
	#endif\n\
	#if pp_FogCtrl==3 \n\
		color=vec4(sp_FOG_COL_RAM.rgb,fog_mode2(vtx_xyz.z)); \n\
	#endif\n\
	#if pp_Texture==1 \n\
	{ \n\
		lowp vec4 texcol=" TEXLOOKUP "(tex,vtx_uv); \n\
		\n\
		#if pp_IgnoreTexA==1 \n\
			texcol.a=1.0;	 \n\
		#endif\n\
		\n\
		#if pp_ShadInstr==0 \n\
		{ \n\
			color.rgb=texcol.rgb; \n\
			color.a=texcol.a; \n\
		} \n\
		#endif\n\
		#if pp_ShadInstr==1 \n\
		{ \n\
			color.rgb*=texcol.rgb; \n\
			color.a=texcol.a; \n\
		} \n\
		#endif\n\
		#if pp_ShadInstr==2 \n\
		{ \n\
			color.rgb=mix(color.rgb,texcol.rgb,texcol.a); \n\
		} \n\
		#endif\n\
		#if  pp_ShadInstr==3 \n\
		{ \n\
			color*=texcol; \n\
		} \n\
		#endif\n\
		\n\
		#if pp_Offset==1 \n\
		{ \n\
			color.rgb+=vtx_offs.rgb; \n\
			if (pp_FogCtrl==1) \n\
				color.rgb=mix(color.rgb,sp_FOG_COL_VERT.rgb,vtx_offs.a); \n\
		} \n\
		#endif\n\
	} \n\
	#endif\n\
	#if pp_FogCtrl==0 \n\
	{ \n\
		color.rgb=mix(color.rgb,sp_FOG_COL_RAM.rgb,fog_mode2(vtx_xyz.z));  \n\
	} \n\
	#endif\n\
	#if cp_AlphaTest == 1 \n\
		color.a = floor(color.a * 255.0 + 0.5) / 255.0; // Fixes noised cars in Jet Grind Radio \n\
		if (cp_AlphaTestValue>color.a) \n\
			discard;\n\
		else \n\
			color.a = 1.0; \n\
	#endif  \n\
	//color.rgb=vec3(vtx_xyz.z/255.0);\n"
#ifndef GLES
	"\
	highp float w = gl_FragCoord.w * 100000.0; \n\
	gl_FragDepth = log2(1.0 + w) / 34.0; \n"
#endif
	FRAGCOL "=color; \n\
}";

const char* ModifierVolumeShader =
#ifndef GLES
	"#version 140 \n"
	"out vec4 FragColor; \n"
#endif
" \
uniform lowp float sp_ShaderColor; \n\
/* Vertex input*/ \n\
void main() \n\
{ \n"
#ifndef GLES
	"\
	highp float w = gl_FragCoord.w * 100000.0; \n\
	gl_FragDepth = log2(1.0 + w) / 34.0; \n"
#endif
	FRAGCOL "=vec4(0.0, 0.0, 0.0, sp_ShaderColor); \n\
}";

const char* OSD_Shader =
#ifndef GLES
	"#version 140 \n"
	"out vec4 FragColor; \n"
#endif
" \
" vary " lowp vec4 vtx_base; \n\
" vary " mediump vec2 vtx_uv; \n\
/* Vertex input*/ \n\
uniform sampler2D tex; \n\
void main() \n\
{ \n\
	mediump vec2 uv=vtx_uv; \n\
	uv.y=1.0-uv.y; \n\
	" FRAGCOL "=vtx_base*" TEXLOOKUP "(tex,uv.st); \n\n\
}";


gl_ctx gl;

int screen_width;
int screen_height;

#if (HOST_OS != OS_DARWIN) && !defined(TARGET_NACL32)
#if defined(GLES) && !defined(USE_SDL)
	// Create a basic GLES context
	bool gl_init(void* wind, void* disp)
	{
	#if !defined(_ANDROID)
		gl.setup.native_wind=(EGLNativeWindowType)wind;
		gl.setup.native_disp=(EGLNativeDisplayType)disp;

		//try to get a display
		gl.setup.display = eglGetDisplay(gl.setup.native_disp);

		//if failed, get the default display (this will not happen in win32)
		if(gl.setup.display == EGL_NO_DISPLAY)
			gl.setup.display = eglGetDisplay((EGLNativeDisplayType) EGL_DEFAULT_DISPLAY);


		// Initialise EGL
		EGLint maj, min;
		if (!eglInitialize(gl.setup.display, &maj, &min))
		{
			printf("EGL Error: eglInitialize failed\n");
			return false;
		}

		printf("Info: EGL version %d.%d\n",maj,min);



		EGLint pi32ConfigAttribs[]  = { EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT , EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8, EGL_NONE };
		EGLint pi32ContextAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, 2 , EGL_NONE };

		int num_config;

		EGLConfig config;
		if (!eglChooseConfig(gl.setup.display, pi32ConfigAttribs, &config, 1, &num_config) || (num_config != 1))
		{
			printf("EGL Error: eglChooseConfig failed\n");
			return false;
		}

		gl.setup.surface = eglCreateWindowSurface(gl.setup.display, config, (EGLNativeWindowType)wind, NULL);

		if (eglCheck())
			return false;

		eglBindAPI(EGL_OPENGL_ES_API);
		if (eglCheck())
			return false;

		gl.setup.context = eglCreateContext(gl.setup.display, config, NULL, pi32ContextAttribs);

		if (eglCheck())
			return false;

	#endif

		eglMakeCurrent(gl.setup.display, gl.setup.surface, gl.setup.surface, gl.setup.context);

		if (eglCheck())
			return false;

		EGLint w,h;
		eglQuerySurface(gl.setup.display, gl.setup.surface, EGL_WIDTH, &w);
		eglQuerySurface(gl.setup.display, gl.setup.surface, EGL_HEIGHT, &h);

		screen_width=w;
		screen_height=h;

		printf("EGL config: %p, %08X, %08X %dx%d\n",gl.setup.context,gl.setup.display,gl.setup.surface,w,h);
		return true;
	}

	void egl_stealcntx()
	{
		gl.setup.context=eglGetCurrentContext();
		gl.setup.display=eglGetCurrentDisplay();
		gl.setup.surface=eglGetCurrentSurface(EGL_DRAW);
	}

	//swap buffers
	void gl_swap()
	{
		#ifdef TARGET_PANDORA0
		if (fbdev >= 0)
		{
			int arg = 0;
			ioctl(fbdev,FBIO_WAITFORVSYNC,&arg);
		}
		#endif
		eglSwapBuffers(gl.setup.display, gl.setup.surface);
	}

	//destroy the gles context and free resources
	void gl_term()
	{
	#if HOST_OS==OS_WINDOWS
		ReleaseDC((HWND)gl.setup.native_wind,(HDC)gl.setup.native_disp);
	#endif
	#ifdef TARGET_PANDORA
		eglMakeCurrent( gl.setup.display, NULL, NULL, EGL_NO_CONTEXT );
		if (gl.setup.context)
			eglDestroyContext(gl.setup.display, gl.setup.context);
		if (gl.setup.surface)
			eglDestroySurface(gl.setup.display, gl.setup.surface);
		if (gl.setup.display)
			eglTerminate(gl.setup.display);
		if (fbdev>=0)
			close( fbdev );

		fbdev=-1;
		gl.setup.context=0;
		gl.setup.surface=0;
		gl.setup.display=0;
	#endif
	}
#else

	#if HOST_OS == OS_WINDOWS
		#define WGL_DRAW_TO_WINDOW_ARB         0x2001
		#define WGL_ACCELERATION_ARB           0x2003
		#define WGL_SWAP_METHOD_ARB            0x2007
		#define WGL_SUPPORT_OPENGL_ARB         0x2010
		#define WGL_DOUBLE_BUFFER_ARB          0x2011
		#define WGL_PIXEL_TYPE_ARB             0x2013
		#define WGL_COLOR_BITS_ARB             0x2014
		#define WGL_DEPTH_BITS_ARB             0x2022
		#define WGL_STENCIL_BITS_ARB           0x2023
		#define WGL_FULL_ACCELERATION_ARB      0x2027
		#define WGL_SWAP_EXCHANGE_ARB          0x2028
		#define WGL_TYPE_RGBA_ARB              0x202B
		#define WGL_CONTEXT_MAJOR_VERSION_ARB  0x2091
		#define WGL_CONTEXT_MINOR_VERSION_ARB  0x2092
		#define WGL_CONTEXT_FLAGS_ARB              0x2094

		#define		WGL_CONTEXT_PROFILE_MASK_ARB  0x9126
		#define 	WGL_CONTEXT_MAJOR_VERSION_ARB   0x2091
		#define 	WGL_CONTEXT_MINOR_VERSION_ARB   0x2092
		#define 	WGL_CONTEXT_LAYER_PLANE_ARB   0x2093
		#define 	WGL_CONTEXT_FLAGS_ARB   0x2094
		#define 	WGL_CONTEXT_DEBUG_BIT_ARB   0x0001
		#define 	WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB   0x0002
		#define 	ERROR_INVALID_VERSION_ARB   0x2095
		#define		WGL_CONTEXT_CORE_PROFILE_BIT_ARB 0x00000001

		typedef BOOL (WINAPI * PFNWGLCHOOSEPIXELFORMATARBPROC) (HDC hdc, const int *piAttribIList, const FLOAT *pfAttribFList, UINT nMaxFormats,
		                                                        int *piFormats, UINT *nNumFormats);
		typedef HGLRC (WINAPI * PFNWGLCREATECONTEXTATTRIBSARBPROC) (HDC hDC, HGLRC hShareContext, const int *attribList);
		typedef BOOL (WINAPI * PFNWGLSWAPINTERVALEXTPROC) (int interval);

		PFNWGLCHOOSEPIXELFORMATARBPROC wglChoosePixelFormatARB;
		PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribsARB;
		PFNWGLSWAPINTERVALEXTPROC wglSwapIntervalEXT;


		HDC ourWindowHandleToDeviceContext;
		bool gl_init(void* hwnd, void* hdc)
		{
			PIXELFORMATDESCRIPTOR pfd =
		    {
		            sizeof(PIXELFORMATDESCRIPTOR),
		            1,
		            PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,    //Flags
		            PFD_TYPE_RGBA,            //The kind of framebuffer. RGBA or palette.
		            32,                        //Colordepth of the framebuffer.
		            0, 0, 0, 0, 0, 0,
		            0,
		            0,
		            0,
		            0, 0, 0, 0,
		            24,                        //Number of bits for the depthbuffer
		            8,                        //Number of bits for the stencilbuffer
		            0,                        //Number of Aux buffers in the framebuffer.
		            PFD_MAIN_PLANE,
		            0,
		            0, 0, 0
		    };

		    /*HDC*/ ourWindowHandleToDeviceContext = (HDC)hdc;//GetDC((HWND)hwnd);

		    int  letWindowsChooseThisPixelFormat;
		    letWindowsChooseThisPixelFormat = ChoosePixelFormat(ourWindowHandleToDeviceContext, &pfd);
		    SetPixelFormat(ourWindowHandleToDeviceContext,letWindowsChooseThisPixelFormat, &pfd);

		    HGLRC ourOpenGLRenderingContext = wglCreateContext(ourWindowHandleToDeviceContext);
		    wglMakeCurrent (ourWindowHandleToDeviceContext, ourOpenGLRenderingContext);

			bool rv = true;

			if (rv) {

				wglChoosePixelFormatARB = (PFNWGLCHOOSEPIXELFORMATARBPROC)wglGetProcAddress("wglChoosePixelFormatARB");
				if(!wglChoosePixelFormatARB)
				{
					return false;
				}

				wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress("wglCreateContextAttribsARB");
				if(!wglCreateContextAttribsARB)
				{
					return false;
				}

				wglSwapIntervalEXT = (PFNWGLSWAPINTERVALEXTPROC)wglGetProcAddress("wglSwapIntervalEXT");
				if(!wglSwapIntervalEXT)
				{
					return false;
				}

				int attribs[] =
		       {
		            WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
		            WGL_CONTEXT_MINOR_VERSION_ARB, 1,
		            WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
		            WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
		            0
		       };

				HGLRC m_hrc = wglCreateContextAttribsARB(ourWindowHandleToDeviceContext,0, attribs);

				if (m_hrc)
					wglMakeCurrent(ourWindowHandleToDeviceContext,m_hrc);
				else
					rv = false;

				wglDeleteContext(ourOpenGLRenderingContext);
			}

			if (rv) {
				rv = gl3wInit() != -1 && gl3wIsSupported(3, 1);
			}

			RECT r;
			GetClientRect((HWND)hwnd, &r);
			screen_width = r.right - r.left;
			screen_height = r.bottom - r.top;

			return rv;
		}
		#include <Wingdi.h>
		void gl_swap()
		{
			wglSwapLayerBuffers(ourWindowHandleToDeviceContext,WGL_SWAP_MAIN_PLANE);
			//SwapBuffers(ourWindowHandleToDeviceContext);
		}
	#else
		#if defined(SUPPORT_X11)
			//! windows && X11
			//let's assume glx for now

			#include <X11/X.h>
			#include <X11/Xlib.h>
			#include <GL/gl.h>
			#include <GL/glx.h>


			bool gl_init(void* wind, void* disp)
			{
				extern void* x11_glc;

				glXMakeCurrent((Display*)libPvr_GetRenderSurface(),
					(GLXDrawable)libPvr_GetRenderTarget(),
					(GLXContext)x11_glc);

				screen_width = 640;
				screen_height = 480;
				return gl3wInit() != -1 && gl3wIsSupported(3, 1);
			}

			void gl_swap()
			{
				glXSwapBuffers((Display*)libPvr_GetRenderSurface(), (GLXDrawable)libPvr_GetRenderTarget());

				Window win;
				int temp;
				unsigned int tempu, new_w, new_h;
				XGetGeometry((Display*)libPvr_GetRenderSurface(), (GLXDrawable)libPvr_GetRenderTarget(),
							&win, &temp, &temp, &new_w, &new_h,&tempu,&tempu);

				//if resized, clear up the draw buffers, to avoid out-of-draw-area junk data
				if (new_w != screen_width || new_h != screen_height) {
					screen_width = new_w;
					screen_height = new_h;
				}

				#if 0
					//handy to debug really stupid render-not-working issues ...

					glClearColor( 0, 0.5, 1, 1 );
					glClear( GL_COLOR_BUFFER_BIT );
					glXSwapBuffers((Display*)libPvr_GetRenderSurface(), (GLXDrawable)libPvr_GetRenderTarget());


					glClearColor ( 1, 0.5, 0, 1 );
					glClear ( GL_COLOR_BUFFER_BIT );
					glXSwapBuffers((Display*)libPvr_GetRenderSurface(), (GLXDrawable)libPvr_GetRenderTarget());
				#endif
			}
		#endif
	#endif
#endif

#endif

struct ShaderUniforms_t
{
	float PT_ALPHA;
	float scale_coefs[4];
	float depth_coefs[4];
	float fog_den_float;
	float ps_FOG_COL_RAM[3];
	float ps_FOG_COL_VERT[3];
	float fog_coefs[2];

	void Set(PipelineShader* s)
	{
		if (s->cp_AlphaTestValue!=-1)
			glUniform1f(s->cp_AlphaTestValue,PT_ALPHA);

		if (s->scale!=-1)
			glUniform4fv( s->scale, 1, scale_coefs);

		if (s->depth_scale!=-1)
			glUniform4fv( s->depth_scale, 1, depth_coefs);

		if (s->sp_FOG_DENSITY!=-1)
			glUniform1f( s->sp_FOG_DENSITY,fog_den_float);

		if (s->sp_FOG_COL_RAM!=-1)
			glUniform3fv( s->sp_FOG_COL_RAM, 1, ps_FOG_COL_RAM);

		if (s->sp_FOG_COL_VERT!=-1)
			glUniform3fv( s->sp_FOG_COL_VERT, 1, ps_FOG_COL_VERT);

		if (s->sp_LOG_FOG_COEFS!=-1)
			glUniform2fv(s->sp_LOG_FOG_COEFS,1, fog_coefs);
	}

} ShaderUniforms;

GLuint gl_CompileShader(const char* shader,GLuint type)
{
	GLint result;
	GLint compile_log_len;
	GLuint rv=glCreateShader(type);
	glShaderSource(rv, 1,&shader, NULL);
	glCompileShader(rv);

	//lets see if it compiled ...
	glGetShaderiv(rv, GL_COMPILE_STATUS, &result);
	glGetShaderiv(rv, GL_INFO_LOG_LENGTH, &compile_log_len);

	if (!result && compile_log_len>0)
	{
		char* compile_log=(char*)malloc(compile_log_len);
		*compile_log=0;

		glGetShaderInfoLog(rv, compile_log_len, &compile_log_len, compile_log);
		printf("Shader: %s \n%s\n",result?"compiled!":"failed to compile",compile_log);

		free(compile_log);
	}

	return rv;
}

GLuint gl_CompileAndLink(const char* VertexShader, const char* FragmentShader)
{
	//create shaders
	GLuint vs=gl_CompileShader(VertexShader ,GL_VERTEX_SHADER);
	GLuint ps=gl_CompileShader(FragmentShader ,GL_FRAGMENT_SHADER);

	GLuint program = glCreateProgram();
	glAttachShader(program, vs);
	glAttachShader(program, ps);

	//bind vertex attribute to vbo inputs
	glBindAttribLocation(program, VERTEX_POS_ARRAY,      "in_pos");
	glBindAttribLocation(program, VERTEX_COL_BASE_ARRAY, "in_base");
	glBindAttribLocation(program, VERTEX_COL_OFFS_ARRAY, "in_offs");
	glBindAttribLocation(program, VERTEX_UV_ARRAY,       "in_uv");

#ifndef GLES
	glBindFragDataLocation(program, 0, "FragColor");
#endif

	glLinkProgram(program);

	GLint result;
	glGetProgramiv(program, GL_LINK_STATUS, &result);


	GLint compile_log_len;
	glGetProgramiv(program, GL_INFO_LOG_LENGTH, &compile_log_len);

	if (!result && compile_log_len>0)
	{
		compile_log_len+= 1024;
		char* compile_log=(char*)malloc(compile_log_len);
		*compile_log=0;

		glGetProgramInfoLog(program, compile_log_len, &compile_log_len, compile_log);
		printf("Shader linking: %s \n (%d bytes), - %s -\n",result?"linked":"failed to link", compile_log_len,compile_log);

		free(compile_log);
		die("shader compile fail\n");
	}

	glDeleteShader(vs);
	glDeleteShader(ps);

	glUseProgram(program);

	verify(glIsProgram(program));

	return program;
}

int GetProgramID(u32 cp_AlphaTest, u32 pp_ClipTestMode,
							u32 pp_Texture, u32 pp_UseAlpha, u32 pp_IgnoreTexA, u32 pp_ShadInstr, u32 pp_Offset,
							u32 pp_FogCtrl)
{
	u32 rv=0;

	rv|=pp_ClipTestMode;
	rv<<=1; rv|=cp_AlphaTest;
	rv<<=1; rv|=pp_Texture;
	rv<<=1; rv|=pp_UseAlpha;
	rv<<=1; rv|=pp_IgnoreTexA;
	rv<<=2; rv|=pp_ShadInstr;
	rv<<=1; rv|=pp_Offset;
	rv<<=2; rv|=pp_FogCtrl;

	return rv;
}

bool CompilePipelineShader(	PipelineShader* s)
{
	char pshader[8192];

	sprintf(pshader,PixelPipelineShader,
                s->cp_AlphaTest,s->pp_ClipTestMode,s->pp_UseAlpha,
                s->pp_Texture,s->pp_IgnoreTexA,s->pp_ShadInstr,s->pp_Offset,s->pp_FogCtrl);

	s->program=gl_CompileAndLink(VertexShaderSource,pshader);


	//setup texture 0 as the input for the shader
	GLuint gu=glGetUniformLocation(s->program, "tex");
	if (s->pp_Texture==1)
		glUniform1i(gu,0);

	//get the uniform locations
	s->scale	            = glGetUniformLocation(s->program, "scale");
	s->depth_scale      = glGetUniformLocation(s->program, "depth_scale");


	s->pp_ClipTest      = glGetUniformLocation(s->program, "pp_ClipTest");

	s->sp_FOG_DENSITY   = glGetUniformLocation(s->program, "sp_FOG_DENSITY");

	s->cp_AlphaTestValue= glGetUniformLocation(s->program, "cp_AlphaTestValue");

	//FOG_COL_RAM,FOG_COL_VERT,FOG_DENSITY;
	if (s->pp_FogCtrl==1 && s->pp_Texture==1)
		s->sp_FOG_COL_VERT=glGetUniformLocation(s->program, "sp_FOG_COL_VERT");
	else
		s->sp_FOG_COL_VERT=-1;
	if (s->pp_FogCtrl==0 || s->pp_FogCtrl==3)
	{
		s->sp_FOG_COL_RAM=glGetUniformLocation(s->program, "sp_FOG_COL_RAM");
		s->sp_LOG_FOG_COEFS=glGetUniformLocation(s->program, "sp_LOG_FOG_COEFS");
	}
	else
	{
		s->sp_FOG_COL_RAM=-1;
		s->sp_LOG_FOG_COEFS=-1;
	}


	ShaderUniforms.Set(s);

	return glIsProgram(s->program)==GL_TRUE;
}

GLuint osd_tex;
#ifdef TARGET_PANDORA
GLuint osd_font;
#endif

bool gl_create_resources()
{

#ifndef GLES
	//create vao
	//This is really not "proper", vaos are supposed to be defined once
	//i keep updating the same one to make the es2 code work in 3.1 context
	glGenVertexArrays(1, &gl.vbo.vao);
#endif

	//create vbos
	glGenBuffers(1, &gl.vbo.geometry);
	glGenBuffers(1, &gl.vbo.modvols);
	glGenBuffers(1, &gl.vbo.idxs);
	glGenBuffers(1, &gl.vbo.idxs2);

	memset(gl.pogram_table,0,sizeof(gl.pogram_table));

	PipelineShader* dshader=0;
	u32 compile=0;
#define forl(name,max) for(u32 name=0;name<=max;name++)
	forl(cp_AlphaTest,1)
	{
		forl(pp_ClipTestMode,2)
		{
			forl(pp_UseAlpha,1)
			{
				forl(pp_Texture,1)
				{
					forl(pp_FogCtrl,3)
					{
						forl(pp_IgnoreTexA,1)
						{
							forl(pp_ShadInstr,3)
							{
								forl(pp_Offset,1)
								{
									dshader=&gl.pogram_table[GetProgramID(cp_AlphaTest,pp_ClipTestMode,pp_Texture,pp_UseAlpha,pp_IgnoreTexA,
															pp_ShadInstr,pp_Offset,pp_FogCtrl)];

									dshader->cp_AlphaTest = cp_AlphaTest;
									dshader->pp_ClipTestMode = pp_ClipTestMode-1;
									dshader->pp_Texture = pp_Texture;
									dshader->pp_UseAlpha = pp_UseAlpha;
									dshader->pp_IgnoreTexA = pp_IgnoreTexA;
									dshader->pp_ShadInstr = pp_ShadInstr;
									dshader->pp_Offset = pp_Offset;
									dshader->pp_FogCtrl = pp_FogCtrl;
									dshader->program = -1;
								}
							}
						}
					}
				}
			}
		}
	}



	gl.modvol_shader.program=gl_CompileAndLink(VertexShaderSource,ModifierVolumeShader);
	gl.modvol_shader.scale          = glGetUniformLocation(gl.modvol_shader.program, "scale");
	gl.modvol_shader.sp_ShaderColor = glGetUniformLocation(gl.modvol_shader.program, "sp_ShaderColor");
	gl.modvol_shader.depth_scale    = glGetUniformLocation(gl.modvol_shader.program, "depth_scale");


	gl.OSD_SHADER.program=gl_CompileAndLink(VertexShaderSource,OSD_Shader);
	printf("OSD: %d\n",gl.OSD_SHADER.program);
	gl.OSD_SHADER.scale=glGetUniformLocation(gl.OSD_SHADER.program, "scale");
	gl.OSD_SHADER.depth_scale=glGetUniformLocation(gl.OSD_SHADER.program, "depth_scale");
	glUniform1i(glGetUniformLocation(gl.OSD_SHADER.program, "tex"),0);		//bind osd texture to slot 0

	//#define PRECOMPILE_SHADERS
	#ifdef PRECOMPILE_SHADERS
	for (u32 i=0;i<sizeof(gl.pogram_table)/sizeof(gl.pogram_table[0]);i++)
	{
		if (!CompilePipelineShader(	&gl.pogram_table[i] ))
			return false;
	}
	#endif

	int w, h;
	osd_tex=loadPNG(get_readonly_data_path("/data/buttons.png"),w,h);
#ifdef TARGET_PANDORA
	osd_font=loadPNG(get_readonly_data_path("/font2.png"),w,h);
#endif

	return true;
}

bool gl_init(void* wind, void* disp);

//swap buffers
void gl_swap();
//destroy the gles context and free resources
void gl_term();

GLuint gl_CompileShader(const char* shader,GLuint type);

bool gl_create_resources();

//setup


bool gles_init()
{

	if (!gl_init((void*)libPvr_GetRenderTarget(),
		         (void*)libPvr_GetRenderSurface()))
			return false;

	if (!gl_create_resources())
		return false;

#if defined(GLES) && HOST_OS != OS_DARWIN && !defined(TARGET_NACL32)
	#ifdef TARGET_PANDORA
	fbdev=open("/dev/fb0", O_RDONLY);
	#else
	eglSwapInterval(gl.setup.display,1);
	#endif
#endif

	//clean up all buffers ...
	for (int i=0;i<10;i++)
	{
		glClearColor(0.f, 0.f, 0.f, 0.f);
		glClear(GL_COLOR_BUFFER_BIT);
		gl_swap();
	}

	return true;
}



float fog_coefs[]={0,0};
void tryfit(float* x,float* y)
{
	//y=B*ln(x)+A

	double sylnx=0,sy=0,slnx=0,slnx2=0;

	u32 cnt=0;

	for (int i=0;i<128;i++)
	{
		int rep=1;

		//discard values clipped to 0 or 1
		if (y[i]==1 && y[i+1]==1)
			continue;

		if (i>0 && y[i]==0 && y[i-1]==0)
			continue;

		//Add many samples for first and last value (fog-in, fog-out -> important)
		if (i>0 && y[i]!=1 && y[i-1]==1)
			rep=10000;

		if (y[i]!=0 && y[i+1]==0)
			rep=10000;

		for (int j=0;j<rep;j++)
		{
			cnt++;
			sylnx+=y[i]*log((double)x[i]);
			sy+=y[i];
			slnx+=log((double)x[i]);
			slnx2+=log((double)x[i])*log((double)x[i]);
		}
	}

	double a,b;
	b=(cnt*sylnx-sy*slnx)/(cnt*slnx2-slnx*slnx);
	a=(sy-b*slnx)/(cnt);


	//We use log2 and not ln on calculations	//B*log(x)+A
	//log2(x)=log(x)/log(2)
	//log(x)=log2(x)*log(2)
	//B*log(2)*log(x)+A
	b*=logf(2.0);

	float maxdev=0;
	for (int i=0;i<128;i++)
	{
		float diff=min(max(b*logf(x[i])/logf(2.0)+a,(double)0),(double)1)-y[i];
		maxdev=max((float)fabs((float)diff),(float)maxdev);
	}
	printf("FOG TABLE Curve match: maxdev: %.02f cents\n",maxdev*100);
	fog_coefs[0]=a;
	fog_coefs[1]=b;
	//printf("%f\n",B*log(maxdev)/log(2.0)+A);
}



extern u16 kcode[4];
extern u8 rt[4],lt[4];

#define key_CONT_C           (1 << 0)
#define key_CONT_B           (1 << 1)
#define key_CONT_A           (1 << 2)
#define key_CONT_START       (1 << 3)
#define key_CONT_DPAD_UP     (1 << 4)
#define key_CONT_DPAD_DOWN   (1 << 5)
#define key_CONT_DPAD_LEFT   (1 << 6)
#define key_CONT_DPAD_RIGHT  (1 << 7)
#define key_CONT_Z           (1 << 8)
#define key_CONT_Y           (1 << 9)
#define key_CONT_X           (1 << 10)
#define key_CONT_D           (1 << 11)
#define key_CONT_DPAD2_UP    (1 << 12)
#define key_CONT_DPAD2_DOWN  (1 << 13)
#define key_CONT_DPAD2_LEFT  (1 << 14)
#define key_CONT_DPAD2_RIGHT (1 << 15)

u32 osd_base;
u32 osd_count;


#if defined(_ANDROID)
extern float vjoy_pos[14][8];
#else

float vjoy_pos[14][8]=
{
	{24+0,24+64,64,64},     //LEFT
	{24+64,24+0,64,64},     //UP
	{24+128,24+64,64,64},   //RIGHT
	{24+64,24+128,64,64},   //DOWN

	{440+0,280+64,64,64},   //X
	{440+64,280+0,64,64},   //Y
	{440+128,280+64,64,64}, //B
	{440+64,280+128,64,64}, //A

	{320-32,360+32,64,64},  //Start

	{440,200,90,64},        //RT
	{542,200,90,64},        //LT

	{-24,128+224,128,128},  //ANALOG_RING
	{96,320,64,64},         //ANALOG_POINT
	{1}
};
#endif // !_ANDROID

float vjoy_sz[2][14] = {
	{ 64,64,64,64, 64,64,64,64, 64, 90,90, 128, 64 },
	{ 64,64,64,64, 64,64,64,64, 64, 64,64, 128, 64 },
};

static void DrawButton(float* xy, u32 state)
{
	Vertex vtx;

	vtx.z=1;

	float x=xy[0];
	float y=xy[1];
	float w=xy[2];
	float h=xy[3];

	vtx.col[0]=vtx.col[1]=vtx.col[2]=(0x7F-0x40*state/255)*vjoy_pos[13][0];

	vtx.col[3]=0xA0*vjoy_pos[13][4];

	vjoy_pos[13][4]+=(vjoy_pos[13][0]-vjoy_pos[13][4])/2;



	vtx.x=x; vtx.y=y;
	vtx.u=xy[4]; vtx.v=xy[5];
	*pvrrc.verts.Append()=vtx;

	vtx.x=x+w; vtx.y=y;
	vtx.u=xy[6]; vtx.v=xy[5];
	*pvrrc.verts.Append()=vtx;

	vtx.x=x; vtx.y=y+h;
	vtx.u=xy[4]; vtx.v=xy[7];
	*pvrrc.verts.Append()=vtx;

	vtx.x=x+w; vtx.y=y+h;
	vtx.u=xy[6]; vtx.v=xy[7];
	*pvrrc.verts.Append()=vtx;

	osd_count+=4;
}

static void ClearBG()
{

}


void DrawButton2(float* xy, bool state) { DrawButton(xy,state?0:255); }
#ifdef TARGET_PANDORA
static void DrawCenteredText(float yy, float scale, int transparency, const char* text)
// Draw a centered text. Font is loaded from font2.png file. Each char is 16*16 size, so scale it down so it's not too big
// Transparency 255=opaque, 0=not visible
{
  Vertex vtx;

  vtx.z=1;

  float w=float(strlen(text)*14)*scale;

  float x=320-w/2.0f;
  float y=yy;
  float h=16.0f*scale;
  w=14.0f*scale;
  float step=32.0f/512.0f;
  float step2=4.0f/512.0f;

  if (transparency<0) transparency=0;
  if (transparency>255) transparency=255;

  for (int i=0; i<strlen(text); i++) {
    int c=text[i];
    float u=float(c%16);
    float v=float(c/16);

    vtx.col[0]=vtx.col[1]=vtx.col[2]=255;
    vtx.col[3]=transparency;

    vtx.x=x; vtx.y=y;
    vtx.u=u*step+step2; vtx.v=v*step+step2;
    *pvrrc.verts.Append()=vtx;

    vtx.x=x+w; vtx.y=y;
    vtx.u=u*step+step-step2; vtx.v=v*step+step2;
    *pvrrc.verts.Append()=vtx;

    vtx.x=x; vtx.y=y+h;
    vtx.u=u*step+step2; vtx.v=v*step+step-step2;
    *pvrrc.verts.Append()=vtx;

    vtx.x=x+w; vtx.y=y+h;
    vtx.u=u*step+step-step2; vtx.v=v*step+step-step2;
    *pvrrc.verts.Append()=vtx;

    x+=w;

    osd_count+=4;
  }
}
static void DrawRightedText(float yy, float scale, int transparency, const char* text)
// Draw a text right justified. Font is loaded from font2.png file. Each char is 16*16 size, so scale it down so it's not too big
// Transparency 255=opaque, 0=not visible
{
  Vertex vtx;

  vtx.z=1;

  float w=float(strlen(text)*14)*scale;

  float x=640-w;
  float y=yy;
  float h=16.0f*scale;
  w=14.0f*scale;
  float step=32.0f/512.0f;
  float step2=4.0f/512.0f;

  if (transparency<0) transparency=0;
  if (transparency>255) transparency=255;

  for (int i=0; i<strlen(text); i++) {
    int c=text[i];
    float u=float(c%16);
    float v=float(c/16);

    vtx.col[0]=vtx.col[1]=vtx.col[2]=255;
    vtx.col[3]=transparency;

    vtx.x=x; vtx.y=y;
    vtx.u=u*step+step2; vtx.v=v*step+step2;
    *pvrrc.verts.Append()=vtx;

    vtx.x=x+w; vtx.y=y;
    vtx.u=u*step+step-step2; vtx.v=v*step+step2;
    *pvrrc.verts.Append()=vtx;

    vtx.x=x; vtx.y=y+h;
    vtx.u=u*step+step2; vtx.v=v*step+step-step2;
    *pvrrc.verts.Append()=vtx;

    vtx.x=x+w; vtx.y=y+h;
    vtx.u=u*step+step-step2; vtx.v=v*step+step-step2;
    *pvrrc.verts.Append()=vtx;

    x+=w;

    osd_count+=4;
  }
}
#endif

#ifdef TARGET_PANDORA
char OSD_Info[128];
int  OSD_Delay=0;
char OSD_Counters[256];
int  OSD_Counter=0;
#endif

static void OSD_HOOK()
{
	osd_base=pvrrc.verts.used();
	osd_count=0;

	#ifndef TARGET_PANDORA
	DrawButton2(vjoy_pos[0],kcode[0]&key_CONT_DPAD_LEFT);
	DrawButton2(vjoy_pos[1],kcode[0]&key_CONT_DPAD_UP);
	DrawButton2(vjoy_pos[2],kcode[0]&key_CONT_DPAD_RIGHT);
	DrawButton2(vjoy_pos[3],kcode[0]&key_CONT_DPAD_DOWN);

	DrawButton2(vjoy_pos[4],kcode[0]&key_CONT_X);
	DrawButton2(vjoy_pos[5],kcode[0]&key_CONT_Y);
	DrawButton2(vjoy_pos[6],kcode[0]&key_CONT_B);
	DrawButton2(vjoy_pos[7],kcode[0]&key_CONT_A);

	DrawButton2(vjoy_pos[8],kcode[0]&key_CONT_START);

	DrawButton(vjoy_pos[9],lt[0]);

	DrawButton(vjoy_pos[10],rt[0]);

	DrawButton2(vjoy_pos[11],1);
	DrawButton2(vjoy_pos[12],0);
	#endif
	#ifdef TARGET_PANDORA
	  if (OSD_Delay) {
		DrawCenteredText(400, 1.0f, (OSD_Delay<255)?OSD_Delay:255, OSD_Info);
		OSD_Delay--;    //*TODO* Delay should be in ms, not in ticks...
	  }
	  if (OSD_Counter) {
		DrawRightedText(20, 1.0f, 255, OSD_Counters);
	  }
	#endif
}

extern GLuint osd_tex;
#ifdef TARGET_PANDORA
extern GLuint osd_font;
#endif

#define OSD_TEX_W 512
#define OSD_TEX_H 256

void OSD_DRAW()
{
	#ifndef TARGET_PANDORA
	if (osd_tex)
	{
		float u=0;
		float v=0;

		for (int i=0;i<13;i++)
		{
			//umin,vmin,umax,vmax
			vjoy_pos[i][4]=(u+1)/OSD_TEX_W;
			vjoy_pos[i][5]=(v+1)/OSD_TEX_H;

			vjoy_pos[i][6]=((u+vjoy_sz[0][i]-1))/OSD_TEX_W;
			vjoy_pos[i][7]=((v+vjoy_sz[1][i]-1))/OSD_TEX_H;

			u+=vjoy_sz[0][i];
			if (u>=OSD_TEX_W)
			{
				u-=OSD_TEX_W;
				v+=vjoy_sz[1][i];
			}
			//v+=vjoy_pos[i][3];
		}

		verify(glIsProgram(gl.OSD_SHADER.program));

		glBindTexture(GL_TEXTURE_2D,osd_tex);
		glUseProgram(gl.OSD_SHADER.program);

		//reset rendering scale
/*
		float dc_width=640;
		float dc_height=480;

		float dc2s_scale_h=screen_height/480.0f;
		float ds2s_offs_x=(screen_width-dc2s_scale_h*640)/2;

		//-1 -> too much to left
		ShaderUniforms.scale_coefs[0]=2.0f/(screen_width/dc2s_scale_h);
		ShaderUniforms.scale_coefs[1]=-2/dc_height;
		ShaderUniforms.scale_coefs[2]=1-2*ds2s_offs_x/(screen_width);
		ShaderUniforms.scale_coefs[3]=-1;

		glUniform4fv( gl.OSD_SHADER.scale, 1, ShaderUniforms.scale_coefs);
*/

		glEnable(GL_BLEND);
		glDisable(GL_DEPTH_TEST);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glDepthMask(false);
		glDepthFunc(GL_ALWAYS);

		glDisable(GL_CULL_FACE);
		glDisable(GL_SCISSOR_TEST);

		int dfa=osd_count/4;

		for (int i=0;i<dfa;i++)
			glDrawArrays(GL_TRIANGLE_STRIP,osd_base+i*4,4);
	}
#endif
#ifdef TARGET_PANDORA
  if (osd_font)
  {
    float u=0;
    float v=0;

    verify(glIsProgram(gl.OSD_SHADER.program));

	float dc_width=640;
	float dc_height=480;

	float dc2s_scale_h=screen_height/480.0f;
	float ds2s_offs_x=(screen_width-dc2s_scale_h*640)/2;


    glBindTexture(GL_TEXTURE_2D,osd_font);
    glUseProgram(gl.OSD_SHADER.program);

  /*
    //-1 -> too much to left
    ShaderUniforms.scale_coefs[0]=2.0f/(screen_width/dc2s_scale_h);
    ShaderUniforms.scale_coefs[1]=-2/dc_height;
    ShaderUniforms.scale_coefs[2]=1-2*ds2s_offs_x/(screen_width);
    ShaderUniforms.scale_coefs[3]=-1;

    glUniform4fv( gl.OSD_SHADER.scale, 1, ShaderUniforms.scale_coefs);
*/

    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


    glDepthMask(false);
    glDepthFunc(GL_ALWAYS);


    glDisable(GL_CULL_FACE);
    glDisable(GL_SCISSOR_TEST);


    int dfa=osd_count/4;

   	for (int i=0;i<dfa;i++)
		glDrawArrays(GL_TRIANGLE_STRIP,osd_base+i*4,4);
 }
#endif
}

bool ProcessFrame(TA_context* ctx)
{
	//disable RTTs for now ..
	if (ctx->rend.isRTT)
		return false;

	ctx->rend_inuse.Lock();
	ctx->MarkRend();

	if (KillTex)
	{
		void killtex();
		killtex();
		printf("Texture cache cleared\n");
	}

	if (!ta_parse_vdrc(ctx))
		return false;

	CollectCleanup();

	return true;
}

bool RenderFrame()
{
	DoCleanup();

	bool is_rtt=pvrrc.isRTT;


	OSD_HOOK();

	//if (FrameCount&7) return;

	//Setup the matrix

	//TODO: Make this dynamic
	float vtx_min_fZ=0.f;	//pvrrc.fZ_min;
	float vtx_max_fZ=pvrrc.fZ_max;

	//sanitise the values, now with NaN detection (for omap)
	//0x49800000 is 1024*1024. Using integer math to avoid issues w/ infs and nans
	if ((s32&)vtx_max_fZ<0 || (u32&)vtx_max_fZ>0x49800000)
		vtx_max_fZ=10*1024;


	//add some extra range to avoid clipping border cases
	vtx_min_fZ*=0.98f;
	vtx_max_fZ*=1.001f;

	//calculate a projection so that it matches the pvr x,y setup, and
	//a) Z is linearly scaled between 0 ... 1
	//b) W is passed though for proper perspective calculations

	/*
	PowerVR coords:
	fx, fy (pixel coordinates)
	fz=1/w

	(as a note, fx=x*fz;fy=y*fz)

	Clip space
	-Wc .. Wc, xyz
	x: left-right, y: bottom-top
	NDC space
	-1 .. 1, xyz
	Window space:
	translated NDC (viewport, glDepth)

	Attributes:
	//this needs to be cleared up, been some time since I wrote my rasteriser and i'm starting
	//to forget/mixup stuff
	vaX         -> VS output
	iaX=vaX*W   -> value to be interpolated
	iaX',W'     -> interpolated values
	paX=iaX'/W' -> Per pixel interpolated value for attribute


	Proper mappings:
	Output from shader:
	W=1/fz
	x=fx*W -> maps to fx after perspective divide
	y=fy*W ->         fy   -//-
	z=-W for min, W for max. Needs to be linear.



	umodified W, perfect mapping:
	Z mapping:
	pz=z/W
	pz=z/(1/fz)
	pz=z*fz
	z=zt_s+zt_o
	pz=(zt_s+zt_o)*fz
	pz=zt_s*fz+zt_o*fz
	zt_s=scale
	zt_s=2/(max_fz-min_fz)
	zt_o*fz=-min_fz-1
	zt_o=(-min_fz-1)/fz == (-min_fz-1)*W


	x=fx/(fx_range/2)-1		//0 to max -> -1 to 1
	y=fy/(-fy_range/2)+1	//0 to max -> 1 to -1
	z=-min_fz*W + (zt_s-1)  //0 to +inf -> -1 to 1

	o=a*z+c
	1=a*z_max+c
	-1=a*z_min+c

	c=-a*z_min-1
	1=a*z_max-a*z_min-1
	2=a*(z_max-z_min)
	a=2/(z_max-z_min)
	*/

	//float B=2/(min_invW-max_invW);
	//float A=-B*max_invW+vnear;

	//these should be adjusted based on the current PVR scaling etc params
	float dc_width=640;
	float dc_height=480;

	if (!is_rtt)
	{
		gcflip=0;
		dc_width=640;
		dc_height=480;
	}
	else
	{
		gcflip=1;

		//For some reason this produces wrong results
		//so for now its hacked based like on the d3d code
		/*
		dc_width=FB_X_CLIP.max-FB_X_CLIP.min+1;
		dc_height=FB_Y_CLIP.max-FB_Y_CLIP.min+1;
		u32 pvr_stride=(FB_W_LINESTRIDE.stride)*8;
		*/

		dc_width=640;
		dc_height=480;
	}

	float scale_x=1, scale_y=1;

	float scissoring_scale_x = 1;

	if (!is_rtt)
	{
		scale_x=fb_scale_x;
		scale_y=fb_scale_y;

		//work out scaling parameters !
		//Pixel doubling is on VO, so it does not affect any pixel operations
		//A second scaling is used here for scissoring
		if (VO_CONTROL.pixel_double)
		{
			scissoring_scale_x = 0.5f;
			scale_x *= 0.5f;
		}
	}

	if (SCALER_CTL.hscale)
	{
		scale_x*=2;
	}

	dc_width  *= scale_x;
	dc_height *= scale_y;

	glUseProgram(gl.modvol_shader.program);

	/*

	float vnear=0;
	float vfar =1;

	float max_invW=1/vtx_min_fZ;
	float min_invW=1/vtx_max_fZ;

	float B=vfar/(min_invW-max_invW);
	float A=-B*max_invW+vnear;


	GLfloat dmatrix[16] =
	{
		(2.f/dc_width)  ,0                ,-(640/dc_width)              ,0  ,
		0               ,-(2.f/dc_height) ,(480/dc_height)              ,0  ,
		0               ,0                ,A                            ,B  ,
		0               ,0                ,1                            ,0
	};

	glUniformMatrix4fv(gl.matrix, 1, GL_FALSE, dmatrix);

	*/

	/*
		Handle Dc to screen scaling
	*/
	float dc2s_scale_h=screen_height/480.0f;
	float ds2s_offs_x=(screen_width-dc2s_scale_h*640)/2;

	//-1 -> too much to left
	ShaderUniforms.scale_coefs[0]=2.0f/(screen_width/dc2s_scale_h*scale_x);
	ShaderUniforms.scale_coefs[1]=(is_rtt?2:-2)/dc_height;
	ShaderUniforms.scale_coefs[2]=1-2*ds2s_offs_x/(screen_width);
	ShaderUniforms.scale_coefs[3]=(is_rtt?1:-1);


	ShaderUniforms.depth_coefs[0]=2/(vtx_max_fZ-vtx_min_fZ);
	ShaderUniforms.depth_coefs[1]=-vtx_min_fZ-1;
	ShaderUniforms.depth_coefs[2]=0;
	ShaderUniforms.depth_coefs[3]=0;

	//printf("scale: %f, %f, %f, %f\n",scale_coefs[0],scale_coefs[1],scale_coefs[2],scale_coefs[3]);


	//VERT and RAM fog color constants
	u8* fog_colvert_bgra=(u8*)&FOG_COL_VERT;
	u8* fog_colram_bgra=(u8*)&FOG_COL_RAM;
	ShaderUniforms.ps_FOG_COL_VERT[0]=fog_colvert_bgra[2]/255.0f;
	ShaderUniforms.ps_FOG_COL_VERT[1]=fog_colvert_bgra[1]/255.0f;
	ShaderUniforms.ps_FOG_COL_VERT[2]=fog_colvert_bgra[0]/255.0f;

	ShaderUniforms.ps_FOG_COL_RAM[0]=fog_colram_bgra [2]/255.0f;
	ShaderUniforms.ps_FOG_COL_RAM[1]=fog_colram_bgra [1]/255.0f;
	ShaderUniforms.ps_FOG_COL_RAM[2]=fog_colram_bgra [0]/255.0f;

	//Fog density constant
	u8* fog_density=(u8*)&FOG_DENSITY;
	float fog_den_mant=fog_density[1]/128.0f;  //bit 7 -> x. bit, so [6:0] -> fraction -> /128
	s32 fog_den_exp=(s8)fog_density[0];
	ShaderUniforms.fog_den_float=fog_den_mant*powf(2.0f,fog_den_exp);


	if (fog_needs_update)
	{
		fog_needs_update=false;
		//Get the coefs for the fog curve
		u8* fog_table=(u8*)FOG_TABLE;
		float xvals[128];
		float yvals[128];
		for (int i=0;i<128;i++)
		{
			xvals[i]=powf(2.0f,i>>4)*(1+(i&15)/16.f);
			yvals[i]=fog_table[i*4+1]/255.0f;
		}

		tryfit(xvals,yvals);
	}

	glUseProgram(gl.modvol_shader.program);

	glUniform4fv( gl.modvol_shader.scale, 1, ShaderUniforms.scale_coefs);
	glUniform4fv( gl.modvol_shader.depth_scale, 1, ShaderUniforms.depth_coefs);


	GLfloat td[4]={0.5,0,0,0};

	glUseProgram(gl.OSD_SHADER.program);
	glUniform4fv( gl.OSD_SHADER.scale, 1, ShaderUniforms.scale_coefs);
	glUniform4fv( gl.OSD_SHADER.depth_scale, 1, td);

	ShaderUniforms.PT_ALPHA=(PT_ALPHA_REF&0xFF)/255.0f;

	for (u32 i=0;i<sizeof(gl.pogram_table)/sizeof(gl.pogram_table[0]);i++)
	{
		PipelineShader* s=&gl.pogram_table[i];
		if (s->program == -1)
			continue;

		glUseProgram(s->program);

		ShaderUniforms.Set(s);
	}
	//setup render target first
	if (is_rtt)
	{
		GLuint channels,format;
		switch(FB_W_CTRL.fb_packmode)
		{
		case 0: //0x0   0555 KRGB 16 bit  (default)	Bit 15 is the value of fb_kval[7].
			channels=GL_RGBA;
			format=GL_UNSIGNED_SHORT_5_5_5_1;
			break;

		case 1: //0x1   565 RGB 16 bit
			channels=GL_RGB;
			format=GL_UNSIGNED_SHORT_5_6_5;
			break;

		case 2: //0x2   4444 ARGB 16 bit
			channels=GL_RGBA;
			format=GL_UNSIGNED_SHORT_5_5_5_1;
			break;

		case 3://0x3    1555 ARGB 16 bit    The alpha value is determined by comparison with the value of fb_alpha_threshold.
			channels=GL_RGBA;
			format=GL_UNSIGNED_SHORT_5_5_5_1;
			break;

		case 4: //0x4   888 RGB 24 bit packed
			channels=GL_RGB;
			format=GL_UNSIGNED_SHORT_5_6_5;
			break;

		case 5: //0x5   0888 KRGB 32 bit    K is the value of fk_kval.
			channels=GL_RGBA;
			format=GL_UNSIGNED_SHORT_4_4_4_4;
			break;

		case 6: //0x6   8888 ARGB 32 bit
			channels=GL_RGBA;
			format=GL_UNSIGNED_SHORT_4_4_4_4;
			break;

		case 7: //7     invalid
			die("7 is not valid");
			break;
		}
		BindRTT(FB_W_SOF1&VRAM_MASK,FB_X_CLIP.max-FB_X_CLIP.min+1,FB_Y_CLIP.max-FB_Y_CLIP.min+1,channels,format);
	}
	else
	{
#if HOST_OS != OS_DARWIN
        //Fix this in a proper way
		glBindFramebuffer(GL_FRAMEBUFFER,0);
#endif
	}

	//Clear depth
	//Color is cleared by the bgp
	if (settings.rend.WideScreen)
		glClearColor(pvrrc.verts.head()->col[2]/255.0f,pvrrc.verts.head()->col[1]/255.0f,pvrrc.verts.head()->col[0]/255.0f,1.0f);
	else
		glClearColor(0,0,0,1.0f);

	glClearDepthf(0.f); glCheck();
	glStencilMask(0xFF); glCheck();
	glClear(GL_COLOR_BUFFER_BIT|GL_STENCIL_BUFFER_BIT|GL_DEPTH_BUFFER_BIT); glCheck();


	if (UsingAutoSort())
		GenSorted();

	//move vertex to gpu

	//Main VBO
	glBindBuffer(GL_ARRAY_BUFFER, gl.vbo.geometry); glCheck();
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl.vbo.idxs); glCheck();

	glBufferData(GL_ARRAY_BUFFER,pvrrc.verts.bytes(),pvrrc.verts.head(),GL_STREAM_DRAW); glCheck();

	glBufferData(GL_ELEMENT_ARRAY_BUFFER,pvrrc.idx.bytes(),pvrrc.idx.head(),GL_STREAM_DRAW);

	//Modvol VBO
	if (pvrrc.modtrig.used())
	{
		glBindBuffer(GL_ARRAY_BUFFER, gl.vbo.modvols); glCheck();
		glBufferData(GL_ARRAY_BUFFER,pvrrc.modtrig.bytes(),pvrrc.modtrig.head(),GL_STREAM_DRAW); glCheck();
	}

	int offs_x=ds2s_offs_x+0.5f;
	//this needs to be scaled

	//not all scaling affects pixel operations, scale to adjust for that
	scale_x *= scissoring_scale_x;

	#if 0
		//handy to debug really stupid render-not-working issues ...
		printf("SS: %dx%d\n", screen_width, screen_height);
		printf("SCI: %d, %f\n", pvrrc.fb_X_CLIP.max, dc2s_scale_h);
		printf("SCI: %f, %f, %f, %f\n", offs_x+pvrrc.fb_X_CLIP.min/scale_x,(pvrrc.fb_Y_CLIP.min/scale_y)*dc2s_scale_h,(pvrrc.fb_X_CLIP.max-pvrrc.fb_X_CLIP.min+1)/scale_x*dc2s_scale_h,(pvrrc.fb_Y_CLIP.max-pvrrc.fb_Y_CLIP.min+1)/scale_y*dc2s_scale_h);
	#endif

	glScissor(offs_x+pvrrc.fb_X_CLIP.min/scale_x,(pvrrc.fb_Y_CLIP.min/scale_y)*dc2s_scale_h,(pvrrc.fb_X_CLIP.max-pvrrc.fb_X_CLIP.min+1)/scale_x*dc2s_scale_h,(pvrrc.fb_Y_CLIP.max-pvrrc.fb_Y_CLIP.min+1)/scale_y*dc2s_scale_h);
	if (settings.rend.WideScreen && pvrrc.fb_X_CLIP.min==0 && ((pvrrc.fb_X_CLIP.max+1)/scale_x==640) && (pvrrc.fb_Y_CLIP.min==0) && ((pvrrc.fb_Y_CLIP.max+1)/scale_y==480 ) )
	{
		glDisable(GL_SCISSOR_TEST);
	}
	else
		glEnable(GL_SCISSOR_TEST);


	//restore scale_x
	scale_x /= scissoring_scale_x;

	DrawStrips();

	#if HOST_OS==OS_WINDOWS
		//Sleep(40); //to test MT stability
	#endif

	eglCheck();

	KillTex=false;

	return !is_rtt;
}

#if !defined(_ANDROID) && !defined(TARGET_NACL32)
#if HOST_OS==OS_LINUX
#define SET_AFNT 1
#endif
#endif

extern u16 kcode[4];

/*
bool rend_single_frame()
{
	//wait render start only if no frame pending
	_pvrrc = DequeueRender();

	while (!_pvrrc)
	{
		rs.Wait();
		_pvrrc = DequeueRender();
	}

	bool do_swp=false;
	//if (kcode[0]&(1<<9))
	{


	//clear up & free data ..
	tactx_Recycle(_pvrrc);
	_pvrrc=0;

	return do_swp;
}
*/


void rend_set_fb_scale(float x,float y)
{
	fb_scale_x=x;
	fb_scale_y=y;
}

struct glesrend : Renderer
{
	bool Init() { return gles_init(); }
	void Resize(int w, int h) { screen_width=w; screen_height=h; }
	void Term() { }

	bool Process(TA_context* ctx) { return ProcessFrame(ctx); }
	bool Render() { return RenderFrame(); }

	void Present() { gl_swap(); glViewport(0, 0, screen_width, screen_height); }

	void DrawOSD() { OSD_DRAW(); }

	virtual u32 GetTexture(TSP tsp, TCW tcw) {
		return gl_GetTexture(tsp, tcw);
	}
};


#include "deps/libpng/png.h"

FILE* pngfile;

void png_cstd_read(png_structp png_ptr, png_bytep data, png_size_t length)
{
	fread(data,1, length,pngfile);
}

GLuint loadPNG(const string& fname, int &width, int &height)
{
	const char* filename=fname.c_str();
	FILE* file = fopen(filename, "rb");
	pngfile=file;

	if (!file)
	{
		printf("Error opening %s\n", filename);
		return TEXTURE_LOAD_ERROR;
	}

	//header for testing if it is a png
	png_byte header[8];

	//read the header
	fread(header,1,8,file);

	//test if png
	int is_png = !png_sig_cmp(header, 0, 8);
	if (!is_png)
	{
		fclose(file);
		printf("Not a PNG file : %s", filename);
		return TEXTURE_LOAD_ERROR;
	}

	//create png struct
	png_structp png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL,
		NULL, NULL);
	if (!png_ptr)
	{
		fclose(file);
		printf("Unable to create PNG struct : %s", filename);
		return (TEXTURE_LOAD_ERROR);
	}

	//create png info struct
	png_infop info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr)
	{
		png_destroy_read_struct(&png_ptr, (png_infopp) NULL, (png_infopp) NULL);
		printf("Unable to create PNG info : %s", filename);
		fclose(file);
		return (TEXTURE_LOAD_ERROR);
	}

	//create png info struct
	png_infop end_info = png_create_info_struct(png_ptr);
	if (!end_info)
	{
		png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
		printf("Unable to create PNG end info : %s", filename);
		fclose(file);
		return (TEXTURE_LOAD_ERROR);
	}

	//png error stuff, not sure libpng man suggests this.
	if (setjmp(png_jmpbuf(png_ptr)))
	{
		fclose(file);
		printf("Error during setjmp : %s", filename);
		png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
		return (TEXTURE_LOAD_ERROR);
	}

	//init png reading
	//png_init_io(png_ptr, fp);
	png_set_read_fn(png_ptr, NULL, png_cstd_read);

	//let libpng know you already read the first 8 bytes
	png_set_sig_bytes(png_ptr, 8);

	// read all the info up to the image data
	png_read_info(png_ptr, info_ptr);

	//variables to pass to get info
	int bit_depth, color_type;
	png_uint_32 twidth, theight;

	// get info about png
	png_get_IHDR(png_ptr, info_ptr, &twidth, &theight, &bit_depth, &color_type,
		NULL, NULL, NULL);

	//update width and height based on png info
	width = twidth;
	height = theight;

	// Update the png info struct.
	png_read_update_info(png_ptr, info_ptr);

	// Row size in bytes.
	int rowbytes = png_get_rowbytes(png_ptr, info_ptr);

	// Allocate the image_data as a big block, to be given to opengl
	png_byte *image_data = new png_byte[rowbytes * height];
	if (!image_data)
	{
		//clean up memory and close stuff
		png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
		printf("Unable to allocate image_data while loading %s ", filename);
		fclose(file);
		return TEXTURE_LOAD_ERROR;
	}

	//row_pointers is for pointing to image_data for reading the png with libpng
	png_bytep *row_pointers = new png_bytep[height];
	if (!row_pointers)
	{
		//clean up memory and close stuff
		png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
		delete[] image_data;
		printf("Unable to allocate row_pointer while loading %s ", filename);
		fclose(file);
		return TEXTURE_LOAD_ERROR;
	}

	// set the individual row_pointers to point at the correct offsets of image_data
	for (int i = 0; i < height; ++i)
		row_pointers[height - 1 - i] = image_data + i * rowbytes;

	//read the png into image_data through row_pointers
	png_read_image(png_ptr, row_pointers);

	//Now generate the OpenGL texture object
	GLuint texture;
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
		GL_UNSIGNED_BYTE, (GLvoid*) image_data);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

	//clean up memory and close stuff
	png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
	delete[] image_data;
	delete[] row_pointers;
	fclose(file);

	return texture;
}


Renderer* rend_GLES2() { return new glesrend(); }
