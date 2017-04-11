/*  Copyright 2005 Guillaume Duhamel
    Copyright 2005-2006 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#ifdef HAVE_LIBGL
#ifdef _WIN32
#include <windows.h>
#include <GL/gl.h>
#include "glext.h"
#endif

#ifdef HAVE_LIBSDL
 #ifdef __APPLE__
  #include <SDL/SDL.h>
 #else
  #include "SDL.h"
 #endif
#endif
#ifndef _arch_dreamcast
    #ifdef __APPLE__
        #include <OpenGL/gl.h>
    #else
        #include <GL/gl.h>
    #endif
#endif
#include <string.h>

#ifndef YGL_H
#define YGL_H

#include "core.h"
#include "vidshared.h"

typedef struct {
	int vertices[8];
	unsigned int w;
	unsigned int h;
	int flip;
	int priority;
	int dst;
    int uclipmode;
    int blendmode;
} YglSprite;

typedef struct {
	float x;
	float y;
} YglCache;

typedef struct {
	unsigned int * textdata;
	unsigned int w;
} YglTexture;


typedef struct {
	unsigned int currentX;
	unsigned int currentY;
	unsigned int yMax;
	unsigned int * texture;
	unsigned int width;
	unsigned int height;
} YglTextureManager;

extern YglTextureManager * YglTM;

void YglTMInit(unsigned int, unsigned int);
void YglTMDeInit(void);
void YglTMReset(void);
void YglTMAllocate(YglTexture *, unsigned int, unsigned int, unsigned int *, unsigned int *);

enum
{
   PG_NORMAL=0,
   PG_VFP1_GOURAUDSAHDING,
   PG_VFP1_STARTUSERCLIP,
   PG_VFP1_ENDUSERCLIP,
   PG_VFP1_HALFTRANS,    
   PG_VFP1_GOURAUDSAHDING_HALFTRANS, 
   PG_VDP2_ADDBLEND,
   PG_VDP2_DRAWFRAMEBUFF,    
   PG_VDP2_STARTWINDOW,
   PG_VDP2_ENDWINDOW,    
   PG_MAX,
};

typedef struct {
   int prgid;
   GLuint prg;
   int * quads;
   float * textcoords;
   float * vertexAttribute;
   int currentQuad;
   int maxQuad;
   int vaid;
   char uClipMode;
   short ux1,uy1,ux2,uy2;
   int blendmode;
   int bwin0,logwin0,bwin1,logwin1,winmode;
   int (*setupUniform)(void *);
   int (*cleanupUniform)(void *);
} YglProgram;

typedef struct {
   int prgcount;
   int prgcurrent;
   int uclipcurrent;
   short ux1,uy1,ux2,uy2;
   int blendmode;
   YglProgram * prg;
} YglLevel;

typedef struct {
   GLuint texture;
   int st;
   unsigned int width;
   unsigned int height;
   unsigned int depth;
   
   // VDP1 Info
   int vdp1_maxpri;
   int vdp1_minpri;
   
   // VDP1 Framebuffer
   int rwidth;
   int rheight;
   int drawframe;
   GLuint rboid;
   GLuint vdp1fbo;
   GLuint vdp1FrameBuff[2];

   // Message Layer
   int msgwidth;
   int msgheight;
   GLuint msgtexture;
   u32 * messagebuf;

   int bUpdateWindow;
   int win0v[512*4];
   int win0_vertexcnt;
   int win1v[512*4];
   int win1_vertexcnt;

   YglLevel * levels;
}  Ygl;

extern Ygl * _Ygl;


int YglGLInit(int, int);
int YglInit(int, int, unsigned int);
void YglDeInit(void);
float * YglQuad(YglSprite *, YglTexture *,YglCache * c);
void YglCachedQuad(YglSprite *, YglCache *);
void YglRender(void);
void YglReset(void);
void YglShowTexture(void);
void YglChangeResolution(int, int);
void YglCacheQuadGrowShading(YglSprite * input, float * colors, YglCache * cache);
int YglQuadGrowShading(YglSprite * input, YglTexture * output, float * colors,YglCache * c);

void YglStartWindow( vdp2draw_struct * info, int win0, int logwin0, int win1, int logwin1, int mode );
void YglEndWindow( vdp2draw_struct * info );

int YglIsCached(u32,YglCache *);
void YglCacheAdd(u32,YglCache *);
void YglCacheReset(void);

// 0.. no belnd, 1.. Alpha, 2.. Add 
int YglSetLevelBlendmode( int pri, int mode );

int Ygl_uniformVDP2DrawFramebuffer( float from, float to , float * offsetcol );

void YglNeedToUpdateWindow();

int YglProgramInit();
int YglProgramChange( YglLevel * level, int prgid );

#if 1  // Does anything need this?  It breaks a bunch of prototypes if
       // GLchar is typedef'd instead of #define'd  --AC
#ifndef GLchar
#define GLchar GLbyte
#endif
#endif  // 0

#ifdef __APPLE__

#else

extern GLuint (STDCALL *glCreateProgram)(void);
extern GLuint (STDCALL *glCreateShader)(GLenum);
extern void (STDCALL *glShaderSource)(GLuint,GLsizei,const GLchar **,const GLint *);
extern void (STDCALL *glCompileShader)(GLuint);
extern void (STDCALL *glAttachShader)(GLuint,GLuint);
extern void (STDCALL *glLinkProgram)(GLuint);
extern void (STDCALL *glUseProgram)(GLuint);
extern GLint (STDCALL *glGetUniformLocation)(GLuint,const GLchar *);
extern void (STDCALL *glUniform1i)(GLint,GLint);
extern void (STDCALL *glGetShaderInfoLog)(GLuint,GLsizei,GLsizei *,GLchar *);
extern void (STDCALL *glVertexAttribPointer)(GLuint index,GLint size, GLenum type, GLboolean normalized, GLsizei stride,const void *pointer);
extern void (STDCALL *glBindAttribLocation)( GLuint program, GLuint index, const GLchar * name);
extern void (STDCALL *glGetProgramiv)( GLuint    program, GLenum pname, GLint * params);
extern void (STDCALL *glGetShaderiv)(GLuint shader,GLenum pname,GLint *    params);
extern GLint (STDCALL *glGetAttribLocation)(GLuint program,const GLchar *    name);

extern void (STDCALL *glEnableVertexAttribArray)(GLuint index);
extern void (STDCALL *glDisableVertexAttribArray)(GLuint index);


//GL_ARB_framebuffer_object
extern PFNGLISRENDERBUFFERPROC glIsRenderbuffer;
extern PFNGLBINDRENDERBUFFERPROC glBindRenderbuffer;
extern PFNGLDELETERENDERBUFFERSPROC glDeleteRenderbuffers;
extern PFNGLGENRENDERBUFFERSPROC glGenRenderbuffers;
extern PFNGLRENDERBUFFERSTORAGEPROC glRenderbufferStorage;
extern PFNGLGETRENDERBUFFERPARAMETERIVPROC glGetRenderbufferParameteriv;
extern PFNGLISFRAMEBUFFERPROC glIsFramebuffer;
extern PFNGLBINDFRAMEBUFFERPROC glBindFramebuffer;
extern PFNGLDELETEFRAMEBUFFERSPROC glDeleteFramebuffers;
extern PFNGLGENFRAMEBUFFERSPROC glGenFramebuffers;
extern PFNGLCHECKFRAMEBUFFERSTATUSPROC glCheckFramebufferStatus;
extern PFNGLFRAMEBUFFERTEXTURE1DPROC glFramebufferTexture1D;
extern PFNGLFRAMEBUFFERTEXTURE2DPROC glFramebufferTexture2D;
extern PFNGLFRAMEBUFFERTEXTURE3DPROC glFramebufferTexture3D;
extern PFNGLFRAMEBUFFERRENDERBUFFERPROC glFramebufferRenderbuffer;
extern PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC glGetFramebufferAttachmentParameteriv;
extern PFNGLGENERATEMIPMAPPROC glGenerateMipmap;
extern PFNGLBLITFRAMEBUFFERPROC glBlitFramebuffer;
extern PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC glRenderbufferStorageMultisample;
extern PFNGLFRAMEBUFFERTEXTURELAYERPROC glFramebufferTextureLayer;

extern PFNGLUNIFORM4FPROC glUniform4f;
extern PFNGLUNIFORM1FPROC glUniform1f;
extern PFNGLUNIFORMMATRIX4FVPROC glUniformMatrix4fv;

#ifdef WIN32
extern PFNGLACTIVETEXTUREPROC glActiveTexture;
#endif

#endif

#endif
#endif
