/*  Copyright 2005-2006 Guillaume Duhamel
    Copyright 2005-2006 Theo Berkau
    Copyright 2011 Shinya Miyamoto
    
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

/*! \file ygl.c
    \brief OpenGL rendering functions
*/

#ifdef HAVE_LIBGL
#include <stdlib.h>
#include <math.h>
#include "ygl.h"
#include "yui.h"
#include "vidshared.h"
#include "error.h"

#ifdef WIN32
#include <windows.h>
#include <wingdi.h>
#elif HAVE_GLXGETPROCADDRESS
#include <GL/glx.h>
#endif
YglTextureManager * YglTM;
Ygl * _Ygl;

typedef struct
{
   u32 id;
   YglCache c;
} cache_struct;

static cache_struct *cachelist;
static int cachelistsize=0;

typedef struct
{
   float s, t, r, q;
} texturecoordinate_struct;


extern int GlHeight;
extern int GlWidth;
extern int vdp1cor;
extern int vdp1cog;
extern int vdp1cob;



#ifdef HAVE_GLXGETPROCADDRESS
void STDCALL * (*yglGetProcAddress)(const char *szProcName) = (void STDCALL *(*)(const char *))glXGetProcAddress;
#elif WIN32
#define yglGetProcAddress wglGetProcAddress
#endif

#ifdef __APPLE__

#ifndef HAVE_FBO
#define glBindFramebuffer glBindFramebufferEXT
#define glBindRenderbuffer glBindRenderbufferEXT
#define glCheckFramebufferStatus glCheckFramebufferStatusEXT
#define glDeleteRenderbuffers glDeleteRenderbuffersEXT
#define glFramebufferRenderbuffer glFramebufferRenderbufferEXT
#define glFramebufferTexture2D glFramebufferTexture2DEXT
#define glGenFramebuffers glGenFramebuffersEXT
#define glGenRenderbuffers glGenRenderbuffersEXT
#define glRenderbufferStorage glRenderbufferStorageEXT
#endif

#else

// extention function pointers
GLuint (STDCALL *glCreateProgram)(void);
GLuint (STDCALL *glCreateShader)(GLenum);
void (STDCALL *glCompileShader)(GLuint);
void (STDCALL *glAttachShader)(GLuint,GLuint);
void (STDCALL *glLinkProgram)(GLuint);
void (STDCALL *glUseProgram)(GLuint);
GLint (STDCALL *glGetUniformLocation)(GLuint,const GLchar *);
void (STDCALL *glShaderSource)(GLuint,GLsizei,const GLchar **,const GLint *);
void (STDCALL *glUniform1i)(GLint,GLint);
void (STDCALL *glGetShaderInfoLog)(GLuint,GLsizei,GLsizei *,GLchar *);
void (STDCALL *glVertexAttribPointer)(GLuint index,GLint size, GLenum type, GLboolean normalized, GLsizei stride,const void *pointer);
GLint (STDCALL *glGetAttribLocation)(GLuint program,const GLchar *    name);
void (STDCALL *glBindAttribLocation)( GLuint program, GLuint index, const GLchar * name);
void (STDCALL *glGetProgramiv)( GLuint    program, GLenum pname, GLint * params);
void (STDCALL *glGetShaderiv)(GLuint shader,GLenum pname,GLint *    params);
void (STDCALL *glEnableVertexAttribArray)(GLuint index);
void (STDCALL *glDisableVertexAttribArray)(GLuint index);

//GL_ARB_framebuffer_object
PFNGLISRENDERBUFFERPROC glIsRenderbuffer;
PFNGLBINDRENDERBUFFERPROC glBindRenderbuffer;
PFNGLDELETERENDERBUFFERSPROC glDeleteRenderbuffers;
PFNGLGENRENDERBUFFERSPROC glGenRenderbuffers;
PFNGLRENDERBUFFERSTORAGEPROC glRenderbufferStorage;
PFNGLGETRENDERBUFFERPARAMETERIVPROC glGetRenderbufferParameteriv;
PFNGLISFRAMEBUFFERPROC glIsFramebuffer;
PFNGLBINDFRAMEBUFFERPROC glBindFramebuffer;
PFNGLDELETEFRAMEBUFFERSPROC glDeleteFramebuffers;
PFNGLGENFRAMEBUFFERSPROC glGenFramebuffers;
PFNGLCHECKFRAMEBUFFERSTATUSPROC glCheckFramebufferStatus;
PFNGLFRAMEBUFFERTEXTURE1DPROC glFramebufferTexture1D;
PFNGLFRAMEBUFFERTEXTURE2DPROC glFramebufferTexture2D;
PFNGLFRAMEBUFFERTEXTURE3DPROC glFramebufferTexture3D;
PFNGLFRAMEBUFFERRENDERBUFFERPROC glFramebufferRenderbuffer;
PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC glGetFramebufferAttachmentParameteriv;
PFNGLGENERATEMIPMAPPROC glGenerateMipmap;
PFNGLBLITFRAMEBUFFERPROC glBlitFramebuffer;
PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC glRenderbufferStorageMultisample;
PFNGLFRAMEBUFFERTEXTURELAYERPROC glFramebufferTextureLayer;

PFNGLUNIFORM4FPROC glUniform4f;
PFNGLUNIFORM1FPROC glUniform1f;
PFNGLUNIFORMMATRIX4FVPROC glUniformMatrix4fv;
#ifdef WIN32
PFNGLACTIVETEXTUREPROC glActiveTexture;
#endif



// extention function dummys
GLuint STDCALL glCreateProgramdmy(void){return 0;}
GLuint STDCALL glCreateShaderdmy(GLenum a){ return 0;}
void STDCALL glCompileShaderdmy(GLuint a){return;}
void STDCALL glAttachShaderdmy(GLuint a,GLuint b){return;}
void STDCALL glLinkProgramdmy(GLuint a){return;}
void STDCALL glUseProgramdmy(GLuint a){return;}
GLint STDCALL glGetUniformLocationdmy(GLuint a,const GLchar * b){return 0;}
void STDCALL glShaderSourcedmy(GLuint a,GLsizei b,const GLchar **c,const GLint *d){return;}
void STDCALL glUniform1idmy(GLint a,GLint b){return;}
void STDCALL glVertexAttribPointerdmy(GLuint index,GLint size, GLenum type, GLboolean normalized, GLsizei stride,const void *pointer){return;}
GLint STDCALL glGetAttribLocationdmy(GLuint program,const GLchar * name){return 0;}
void STDCALL glBindAttribLocationdmy( GLuint program, GLuint index, const GLchar * name){return;}
void STDCALL glGetProgramivdmy(GLuint    program, GLenum pname, GLint * params)
{
   if( pname == GL_LINK_STATUS ) *params = GL_FALSE;
   return;
}
GLchar s_msg_no_opengl2[]="Your GPU driver does not support OpenGL 2.0.\nOpenGL Video Interface is running fallback mode.";
void STDCALL glGetShaderivdmy(GLuint shader,GLenum pname,GLint *    params)
{
   if( pname == GL_COMPILE_STATUS ) *params = GL_FALSE;
   if( pname == GL_INFO_LOG_LENGTH ) *params = strlen((const char *) s_msg_no_opengl2)+1;
   return;
}
void STDCALL glGetShaderInfoLogdmy(GLuint a,GLsizei b,GLsizei *c,GLchar *d)
{
   memcpy(d,s_msg_no_opengl2,b);
   *c=b;
   return;
}
void STDCALL glEnableVertexAttribArraydmy(GLuint index){return;}
void STDCALL glDisableVertexAttribArraydmy(GLuint index){return;}
GLAPI GLboolean APIENTRY glIsRenderbufferdmy (GLuint renderbuffer){return GL_FALSE;}
GLAPI void APIENTRY glBindRenderbufferdmy (GLenum target, GLuint renderbuffer){return;}
GLAPI void APIENTRY glDeleteRenderbuffersdmy (GLsizei n, const GLuint *renderbuffers){return;}
GLAPI void APIENTRY glGenRenderbuffersdmy (GLsizei n, GLuint *renderbuffers){*renderbuffers=0;}
GLAPI void APIENTRY glRenderbufferStoragedmy (GLenum target, GLenum internalformat, GLsizei width, GLsizei height){}
GLAPI void APIENTRY glGetRenderbufferParameterivdmy (GLenum target, GLenum pname, GLint *params){}
GLAPI GLboolean APIENTRY glIsFramebufferdmy (GLuint framebuffer){return GL_FALSE;}
GLAPI void APIENTRY glBindFramebufferdmy (GLenum target, GLuint framebuffer){}
GLAPI void APIENTRY glDeleteFramebuffersdmy (GLsizei n, const GLuint *framebuffers){}
GLAPI void APIENTRY glGenFramebuffersdmy (GLsizei n, GLuint *framebuffers){}
GLAPI GLenum APIENTRY glCheckFramebufferStatusdmy (GLenum target){return 0;}
GLAPI void APIENTRY glFramebufferTexture1Ddmy (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level){}
GLAPI void APIENTRY glFramebufferTexture2Ddmy (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level){}
GLAPI void APIENTRY glFramebufferTexture3Ddmy (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level, GLint zoffset){}
GLAPI void APIENTRY glFramebufferRenderbufferdmy (GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer){}
GLAPI void APIENTRY glGetFramebufferAttachmentParameterivdmy (GLenum target, GLenum attachment, GLenum pname, GLint *params){}
GLAPI void APIENTRY glGenerateMipmapdmy (GLenum target){}
GLAPI void APIENTRY glBlitFramebufferdmy (GLint srcX0, GLint srcY0, GLint srcX1, GLint srcY1, GLint dstX0, GLint dstY0, GLint dstX1, GLint dstY1, GLbitfield mask, GLenum filter){}
GLAPI void APIENTRY glRenderbufferStorageMultisampledmy (GLenum target, GLsizei samples, GLenum internalformat, GLsizei width, GLsizei height){}
GLAPI void APIENTRY glFramebufferTextureLayerdmy (GLenum target, GLenum attachment, GLuint texture, GLint level, GLint layer){}
GLAPI void APIENTRY glUniform4fdmy(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3){}
GLAPI void APIENTRY glUniform1fdmy (GLint location, GLfloat v0){}
GLAPI void APIENTRY glUniformMatrix4fvdmy (GLint location, GLsizei count, GLboolean transpose, const GLfloat *value){}
GLAPI void APIENTRY glActiveTexturedmy (GLenum texture){}
#endif

#define STD_Q2 (1.0f)
#define EPS (1e-10)
#define EQ(a,b) (abs((a)-(b)) < EPS)
#define IS_ZERO(a) ( (a) < EPS && (a) > -EPS)

// AXB = |A||B|sin
static INLINE float cross2d( float veca[2], float vecb[2] )
{
   return (veca[0]*vecb[1])-(vecb[0]*veca[1]);
}

/*-----------------------------------------
    b1+--+ a1
     /  / \
    /  /   \
  a2+-+-----+b2
      ans
      
  get intersection point for opposite edge.
--------------------------------------------*/  
int FASTCALL YglIntersectionOppositeEdge(float * a1, float * a2, float * b1, float * b2, float * out ) 
{
  float veca[2];
  float vecb[2];
  float vecc[2];
  float d1;
  float d2;

  veca[0]=a2[0]-a1[0];
  veca[1]=a2[1]-a1[1];
  vecb[0]=b1[0]-a1[0];
  vecb[1]=b1[1]-a1[1];
  vecc[0]=b2[0]-a1[0];
  vecc[1]=b2[1]-a1[1];
  d1 = cross2d(vecb,vecc);
  if( IS_ZERO(d1) ) return -1;
  d2 = cross2d(vecb,veca);
  
  out[0] = a1[0]+vecc[0]*d2/d1;
  out[1] = a1[1]+vecc[1]*d2/d1;
 
  return 0;
}


int YglCalcTextureQ(
   int   *pnts,
   float *q   
)
{
   float p1[2],p2[2],p3[2],p4[2],o[2];
   float   q1, q3, q4, qw;
   float   dx, w;
   float   ww;
   
   // fast calculation for triangle
   if (( pnts[2*0+0] == pnts[2*1+0] ) && ( pnts[2*0+1] == pnts[2*1+1] )) {
      q[0] = 1.0f;
      q[1] = 1.0f;
      q[2] = 1.0f;
      q[3] = 1.0f;
      return 0;
      
   } else if (( pnts[2*1+0] == pnts[2*2+0] ) && ( pnts[2*1+1] == pnts[2*2+1] ))  {
      q[0] = 1.0f;
      q[1] = 1.0f;
      q[2] = 1.0f;
      q[3] = 1.0f;
      return 0;
   } else if (( pnts[2*2+0] == pnts[2*3+0] ) && ( pnts[2*2+1] == pnts[2*3+1] ))  {
      q[0] = 1.0f;
      q[1] = 1.0f;
      q[2] = 1.0f;
      q[3] = 1.0f;
      return 0;
   } else if (( pnts[2*3+0] == pnts[2*0+0] ) && ( pnts[2*3+1] == pnts[2*0+1] )) {
      q[0] = 1.0f;
      q[1] = 1.0f;
      q[2] = 1.0f;
      q[3] = 1.0f;
      return 0;
   }

   p1[0]=pnts[0];
   p1[1]=pnts[1];
   p2[0]=pnts[2];
   p2[1]=pnts[3];
   p3[0]=pnts[4];
   p3[1]=pnts[5];
   p4[0]=pnts[6];
   p4[1]=pnts[7];

   // calcurate Q1
   if( YglIntersectionOppositeEdge( p3, p1, p2, p4,  o ) == 0 )
   {
      dx = o[0]-p1[0];
      if( !IS_ZERO(dx) )
      {
         w = p3[0]-p2[0];
         if( !IS_ZERO(w) )
          q1 = fabs(dx/w);
         else
          q1 = 0.0f;
      }else{
         w = p3[1] - p2[1];
         if ( !IS_ZERO(w) ) 
         {
            ww = ( o[1] - p1[1] );
            if ( !IS_ZERO(ww) )
               q1 = fabs(ww / w);
            else
               q1 = 0.0f;
         } else {
            q1 = 0.0f;
         }         
      }
   }else{
      q1 = 1.0f;
   }

   /* q2 = 1.0f; */

   // calcurate Q3
   if( YglIntersectionOppositeEdge( p1, p3, p2,p4,  o ) == 0 )
   {
      dx = o[0]-p3[0];
      if( !IS_ZERO(dx) )
      {
         w = p1[0]-p2[0];
         if( !IS_ZERO(w) )
          q3 = fabs(dx/w);
         else
          q3 = 0.0f;
      }else{
         w = p1[1] - p2[1];
         if ( !IS_ZERO(w) ) 
         {
            ww = ( o[1] - p3[1] );
            if ( !IS_ZERO(ww) )
               q3 = fabs(ww / w);
            else
               q3 = 0.0f;
         } else {
            q3 = 0.0f;
         }         
      }
   }else{
      q3 = 1.0f;
   }

   
   // calcurate Q4
   if( YglIntersectionOppositeEdge( p3, p1, p4, p2,  o ) == 0 )
   {
      dx = o[0]-p1[0];
      if( !IS_ZERO(dx) )
      {
         w = p3[0]-p4[0];
         if( !IS_ZERO(w) )
          qw = fabs(dx/w);
         else
          qw = 0.0f;
      }else{
         w = p3[1] - p4[1];
         if ( !IS_ZERO(w) ) 
         {
            ww = ( o[1] - p1[1] );
            if ( !IS_ZERO(ww) )
               qw = fabs(ww / w);
            else
               qw = 0.0f;
         } else {
            qw = 0.0f;
         }         
      }
      if ( !IS_ZERO(qw) )
      {
         w   = qw / q1;
      }
      else
      {
         w   = 0.0f;
      }
      if ( IS_ZERO(w) ) {
         q4 = 1.0f;
      } else {
         q4 = 1.0f / w;
      }      
   }else{
      q4 = 1.0f;
   }

   qw = q1;
   if ( qw < 1.0f )   /* q2 = 1.0f */
      qw = 1.0f;
   if ( qw < q3 )
      qw = q3;
   if ( qw < q4 )
      qw = q4;

   if ( 1.0f != qw )
   {
      qw      = 1.0f / qw;

      q[0]   = q1 * qw;
      q[1]   = 1.0f * qw;
      q[2]   = q3 * qw;
      q[3]   = q4 * qw;
   }
   else
   {
      q[0]   = q1;
      q[1]   = 1.0f;
      q[2]   = q3;
      q[3]   = q4;
   }
   return 0;
}



//////////////////////////////////////////////////////////////////////////////

void YglTMInit(unsigned int w, unsigned int h) {
   YglTM = (YglTextureManager *) malloc(sizeof(YglTextureManager));
   YglTM->texture = (unsigned int *) malloc(sizeof(unsigned int) * w * h);
   YglTM->width = w;
   YglTM->height = h;

   YglTMReset();
}

//////////////////////////////////////////////////////////////////////////////

void YglTMDeInit(void) {
   free(YglTM->texture);
   free(YglTM);
}

//////////////////////////////////////////////////////////////////////////////

void YglTMReset(void) {
   YglTM->currentX = 0;
   YglTM->currentY = 0;
   YglTM->yMax = 0;
}

//////////////////////////////////////////////////////////////////////////////

void YglTMAllocate(YglTexture * output, unsigned int w, unsigned int h, unsigned int * x, unsigned int * y) {
   if ((YglTM->height - YglTM->currentY) < h) {
      fprintf(stderr, "can't allocate texture: %dx%d\n", w, h);
      *x = *y = 0;
      output->w = 0;
      output->textdata = YglTM->texture;
      return;
   }

   if ((YglTM->width - YglTM->currentX) >= w) {
      *x = YglTM->currentX;
      *y = YglTM->currentY;
      output->w = YglTM->width - w;
      output->textdata = YglTM->texture + YglTM->currentY * YglTM->width + YglTM->currentX;
      YglTM->currentX += w;
      if ((YglTM->currentY + h) > YglTM->yMax)
         YglTM->yMax = YglTM->currentY + h;
   }
   else {
      YglTM->currentX = 0;
      YglTM->currentY = YglTM->yMax;
      YglTMAllocate(output, w, h, x, y);
   }
}

//////////////////////////////////////////////////////////////////////////////

int YglGLInit(int width, int height) {
   int status;
   
   glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrtho(0, 320, 224, 0, 1, 0);

   glMatrixMode(GL_TEXTURE);
   glLoadIdentity();
   glOrtho(-width, width, -height, height, 1, 0 );

   glEnable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
   
   glEnable(GL_ALPHA_TEST);
   glAlphaFunc(GL_GREATER, 0.0);
   
   glEnable(GL_DEPTH_TEST);
   glDepthFunc(GL_GEQUAL);
   glClearDepth(0.0f);
   
   glDisable(GL_CULL_FACE);
   glDisable(GL_DITHER);
   glDisable(GL_LIGHTING);
   
   glEnableClientState(GL_VERTEX_ARRAY);
   glEnableClientState(GL_TEXTURE_COORD_ARRAY);

   glGenTextures(1, &_Ygl->texture);
   glBindTexture(GL_TEXTURE_2D, _Ygl->texture);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, YglTM->texture);
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   
   if( glGenRenderbuffers == NULL ) return 0;

   if( _Ygl->vdp1FrameBuff != 0 ) glDeleteTextures(2,_Ygl->vdp1FrameBuff);
   glGenTextures(2,_Ygl->vdp1FrameBuff);
   glBindTexture(GL_TEXTURE_2D,_Ygl->vdp1FrameBuff[0]);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, GlWidth, GlHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE,NULL);
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

   glBindTexture(GL_TEXTURE_2D,_Ygl->vdp1FrameBuff[1]);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, GlWidth, GlHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE,NULL);
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
   
   if( _Ygl->rboid != 0 ) glDeleteRenderbuffers(1,&_Ygl->rboid);
   glGenRenderbuffers(1, &_Ygl->rboid);
   glBindRenderbuffer(GL_RENDERBUFFER,_Ygl->rboid);
   glRenderbufferStorage(GL_RENDERBUFFER,  GL_DEPTH24_STENCIL8, GlWidth, GlHeight);
   
   
   glBindFramebuffer(GL_FRAMEBUFFER, _Ygl->vdp1fbo);
   glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _Ygl->vdp1FrameBuff[0], 0);
   glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _Ygl->rboid);
   status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
   if( status != GL_FRAMEBUFFER_COMPLETE )
   {
      printf("YglGLInit:Framebuffer status = %08X\n", status );
   }  

   // Message Layer
   _Ygl->msgwidth =800;
   _Ygl->msgheight=480;
   if( _Ygl->messagebuf == NULL )
   {
      _Ygl->messagebuf = malloc(sizeof(u32)*_Ygl->msgwidth*_Ygl->msgheight);
      if( NULL == _Ygl->messagebuf )
      {
         printf("YglGLInit:Fail to malloc _Ygl->messagebuf\n");
      }
   }
   memset( _Ygl->messagebuf,0,sizeof(u32)*_Ygl->msgwidth*_Ygl->msgheight);

   if( _Ygl->msgtexture == 0 )
   {
      glGenTextures(1, &_Ygl->msgtexture);
   }
   glBindTexture(GL_TEXTURE_2D, _Ygl->msgtexture);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _Ygl->msgwidth,_Ygl->msgheight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

   glBindFramebuffer(GL_FRAMEBUFFER, 0 );
   glBindTexture(GL_TEXTURE_2D,_Ygl->texture);
   
   return 0;
}

//////////////////////////////////////////////////////////////////////////////


int YglInit(int width, int height, unsigned int depth) {
   unsigned int i,j;
   GLuint status;

   YglTMInit(width, height);
   
   if ((_Ygl = (Ygl *) malloc(sizeof(Ygl))) == NULL)
      return -1;
   
   memset(_Ygl,0,sizeof(Ygl));
   
   _Ygl->depth = depth;
   _Ygl->rwidth = 320;
   _Ygl->rheight = 240;
   
   if ((_Ygl->levels = (YglLevel *) malloc(sizeof(YglLevel) * (depth+1))) == NULL)
      return -1;
   
   memset(_Ygl->levels,0,sizeof(YglLevel) * (depth+1) );
   
   for(i = 0;i < (depth+1) ;i++) {
     _Ygl->levels[i].prgcurrent = 0;
     _Ygl->levels[i].uclipcurrent = 0;
     _Ygl->levels[i].prgcount = 1;
     _Ygl->levels[i].prg = (YglProgram*)malloc(sizeof(YglProgram)*_Ygl->levels[i].prgcount);
     memset(  _Ygl->levels[i].prg,0,sizeof(YglProgram)*_Ygl->levels[i].prgcount);
     if( _Ygl->levels[i].prg == NULL ) return -1;
     
     for(j = 0;j < _Ygl->levels[i].prgcount; j++) {
       _Ygl->levels[i].prg[j].prg=0;
      _Ygl->levels[i].prg[j].currentQuad = 0;
      _Ygl->levels[i].prg[j].maxQuad = 12 * 2000;
      if ((_Ygl->levels[i].prg[j].quads = (int *) malloc(_Ygl->levels[i].prg[j].maxQuad * sizeof(int))) == NULL)
         return -1;

      if ((_Ygl->levels[i].prg[j].textcoords = (float *) malloc(_Ygl->levels[i].prg[j].maxQuad * sizeof(float) * 2)) == NULL)
         return -1;

       if ((_Ygl->levels[i].prg[j].vertexAttribute = (float *) malloc(_Ygl->levels[i].prg[j].maxQuad * sizeof(float)*2)) == NULL)
         return -1;
     }
   }

   YglGLInit(width, height);

   // Set up Extention
/* would be much better to test the opengl api */
#ifdef __APPLE__

#else
   glCreateProgram = (GLuint (STDCALL *)(void)) yglGetProcAddress("glCreateProgram");
   if( glCreateProgram == NULL )
   {
      YuiErrorMsg((const char *) s_msg_no_opengl2);
      glCreateProgram = glCreateProgramdmy;
   }
   glCreateShader = (GLuint (STDCALL *)(GLenum))yglGetProcAddress("glCreateShader");
   if( glCreateShader == NULL ) glCreateShader = glCreateShaderdmy;
   glCompileShader = (void (STDCALL *)(GLuint))yglGetProcAddress("glCompileShader");
   if(glCompileShader==NULL) glCompileShader = glCompileShaderdmy;
   glAttachShader = (void (STDCALL *)(GLuint,GLuint))yglGetProcAddress("glAttachShader");
   if(glAttachShader == NULL) glAttachShader = glAttachShaderdmy;
   glLinkProgram = (void (STDCALL *)(GLuint))yglGetProcAddress("glLinkProgram");
   if(glLinkProgram == NULL ) glLinkProgram = glLinkProgramdmy;
   glUseProgram = (void (STDCALL *)(GLuint))yglGetProcAddress("glUseProgram");
   if(glUseProgram == NULL ) glUseProgram = glUseProgramdmy;
   glGetUniformLocation = (GLint (STDCALL *)(GLuint,const GLchar *))yglGetProcAddress("glGetUniformLocation");
   if( glGetUniformLocation == NULL ) glGetUniformLocation = glGetUniformLocationdmy;
   glShaderSource = (void (STDCALL *)(GLuint,GLsizei,const GLchar **,const GLint *))yglGetProcAddress("glShaderSource");
   if( glShaderSource == NULL ) glShaderSource = glShaderSourcedmy;
   glUniform1i = (void (STDCALL *)(GLint,GLint))yglGetProcAddress("glUniform1i");
   if( glUniform1i == NULL ) glUniform1i = glUniform1idmy;
   glGetShaderInfoLog = (void (STDCALL *)(GLuint,GLsizei,GLsizei *,GLchar *))yglGetProcAddress("glGetShaderInfoLog");
   if( glGetShaderInfoLog == NULL ) glGetShaderInfoLog = glGetShaderInfoLogdmy;
   glVertexAttribPointer = (void (STDCALL *)(GLuint index,GLint size, GLenum type, GLboolean normalized, GLsizei stride,const void *pointer)) yglGetProcAddress("glVertexAttribPointer");
   if( glVertexAttribPointer == NULL ) glVertexAttribPointer = glVertexAttribPointerdmy;
   glGetAttribLocation  = (GLint (STDCALL *)(GLuint program,const GLchar *    name)) yglGetProcAddress("glGetAttribLocation");
   if( glGetAttribLocation == NULL ) glGetAttribLocation = glGetAttribLocationdmy;
   glBindAttribLocation = (void (STDCALL *)( GLuint program, GLuint index, const GLchar * name))yglGetProcAddress("glBindAttribLocation");
   if( glBindAttribLocation == NULL ) glBindAttribLocation = glBindAttribLocationdmy;
   glGetProgramiv = (void (STDCALL *)( GLuint    program, GLenum pname, GLint * params))yglGetProcAddress("glGetProgramiv");
   if( glGetProgramiv == NULL ) glGetProgramiv = glGetProgramivdmy;
   glGetShaderiv  = (void (STDCALL *)(GLuint shader,GLenum pname,GLint *    params))yglGetProcAddress("glGetShaderiv");
   if( glGetShaderiv == NULL ) glGetShaderiv = glGetShaderivdmy;
   glEnableVertexAttribArray = (void (STDCALL *)(GLuint index))yglGetProcAddress("glEnableVertexAttribArray");
   if( glEnableVertexAttribArray == NULL ) glEnableVertexAttribArray = glEnableVertexAttribArraydmy;
   glDisableVertexAttribArray = (void (STDCALL *)(GLuint index))yglGetProcAddress("glDisableVertexAttribArray");
   if( glDisableVertexAttribArray == NULL ) glDisableVertexAttribArray = glDisableVertexAttribArraydmy;
   
   glIsRenderbuffer=(PFNGLISRENDERBUFFERPROC)yglGetProcAddress("glIsRenderbufferEXT");
   if(glIsRenderbuffer==NULL) glIsRenderbuffer = glIsRenderbufferdmy;
   glBindRenderbuffer = (PFNGLBINDRENDERBUFFERPROC)yglGetProcAddress("glBindRenderbufferEXT");
   if( glBindRenderbuffer == NULL ) glBindRenderbuffer = glBindRenderbufferdmy;
   glDeleteRenderbuffers = (PFNGLDELETERENDERBUFFERSPROC)yglGetProcAddress("glDeleteRenderbuffersEXT");
   if(glDeleteRenderbuffers==NULL) glDeleteRenderbuffers = glDeleteRenderbuffersdmy;
   glGenRenderbuffers = (PFNGLGENRENDERBUFFERSPROC)yglGetProcAddress("glGenRenderbuffersEXT");
   if( glGenRenderbuffers == NULL ) glGenRenderbuffers = glGenRenderbuffersdmy;
   glRenderbufferStorage = (PFNGLRENDERBUFFERSTORAGEPROC)yglGetProcAddress("glRenderbufferStorageEXT");
   if( glRenderbufferStorage == NULL ) glRenderbufferStorage = glRenderbufferStoragedmy;
   glGetRenderbufferParameteriv = (PFNGLGETRENDERBUFFERPARAMETERIVPROC)yglGetProcAddress("glGetRenderbufferParameterivEXT");
   if(glGetRenderbufferParameteriv==NULL) glGetRenderbufferParameteriv = glGetRenderbufferParameterivdmy;
   glIsFramebuffer = (PFNGLISFRAMEBUFFERPROC)yglGetProcAddress("glIsFramebufferEXT");
   if( glIsFramebuffer == NULL ) glIsFramebuffer = glIsFramebufferdmy;
   glBindFramebuffer = (PFNGLBINDFRAMEBUFFERPROC)yglGetProcAddress("glBindFramebufferEXT");
   if( glBindFramebuffer==NULL) glBindFramebuffer = glBindFramebufferdmy;
   glDeleteFramebuffers = (PFNGLDELETEFRAMEBUFFERSPROC)yglGetProcAddress("glDeleteFramebuffersEXT");
   if( glDeleteFramebuffers==NULL) glDeleteFramebuffers=glDeleteFramebuffersdmy;
   glGenFramebuffers = (PFNGLGENFRAMEBUFFERSPROC)yglGetProcAddress("glGenFramebuffersEXT");
   if( glGenFramebuffers == NULL ) glGenFramebuffers=glGenFramebuffersdmy;
   glCheckFramebufferStatus = (PFNGLCHECKFRAMEBUFFERSTATUSPROC)yglGetProcAddress("glCheckFramebufferStatusEXT");
   if( glCheckFramebufferStatus == NULL ) glCheckFramebufferStatus = glCheckFramebufferStatusdmy;
   glFramebufferTexture1D = (PFNGLFRAMEBUFFERTEXTURE1DPROC)yglGetProcAddress("glFramebufferTexture1DEXT");
   if( glFramebufferTexture1D == NULL ) glFramebufferTexture1D = glFramebufferTexture1Ddmy;
   glFramebufferTexture2D = (PFNGLFRAMEBUFFERTEXTURE2DPROC)yglGetProcAddress("glFramebufferTexture2DEXT");
   if( glFramebufferTexture2D == NULL ) glFramebufferTexture2D = glFramebufferTexture2Ddmy;
   glFramebufferTexture3D = (PFNGLFRAMEBUFFERTEXTURE3DPROC)yglGetProcAddress("glFramebufferTexture3DEXT");
   if( glFramebufferTexture3D == NULL ) glFramebufferTexture3D = glFramebufferTexture3Ddmy;
   glFramebufferRenderbuffer = (PFNGLFRAMEBUFFERRENDERBUFFERPROC)yglGetProcAddress("glFramebufferRenderbufferEXT");
   if( glFramebufferRenderbuffer == NULL ) glFramebufferRenderbuffer = glFramebufferRenderbufferdmy;
   glGetFramebufferAttachmentParameteriv = (PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC)yglGetProcAddress("glGetFramebufferAttachmentParameterivEXT");
   if( glGetFramebufferAttachmentParameteriv == NULL ) glGetFramebufferAttachmentParameteriv = glGetFramebufferAttachmentParameterivdmy;
   glGenerateMipmap = (PFNGLGENERATEMIPMAPPROC)yglGetProcAddress("glGenerateMipmapEXT");
   if( glGenerateMipmap == NULL ) glGenerateMipmap = glGenerateMipmapdmy;
   glBlitFramebuffer = (PFNGLBLITFRAMEBUFFERPROC)yglGetProcAddress("glBlitFramebufferEXT");
   if( glBlitFramebuffer == NULL ) glBlitFramebuffer = glBlitFramebufferdmy;
   glRenderbufferStorageMultisample = (PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC)yglGetProcAddress("glRenderbufferStorageMultisampleEXT");
   if( glRenderbufferStorageMultisample == NULL ) glRenderbufferStorageMultisample = glRenderbufferStorageMultisampledmy;
   glFramebufferTextureLayer = (PFNGLFRAMEBUFFERTEXTURELAYERPROC)yglGetProcAddress("glFramebufferTextureLayerEXT");   
   if( glFramebufferTextureLayer == NULL ) glFramebufferTextureLayer = glFramebufferTextureLayerdmy;
   glUniform4f = (PFNGLUNIFORM4FPROC)yglGetProcAddress("glUniform4f");
   if( glUniform4f == NULL ) glUniform4f = glUniform4fdmy;
   glUniformMatrix4fv = (PFNGLUNIFORMMATRIX4FVPROC)yglGetProcAddress("glUniformMatrix4fv");
   if( glUniformMatrix4fv == NULL ) glUniformMatrix4fv = glUniformMatrix4fvdmy;
   glUniform1f = (PFNGLUNIFORM1FPROC)yglGetProcAddress("glUniform1f");
   if( glUniform1f == NULL ) glUniform1f = glUniform1fdmy;
#endif

#ifdef WIN32   
   glActiveTexture = (PFNGLACTIVETEXTUREPROC)yglGetProcAddress("glActiveTexture");
   if( glActiveTexture == NULL ) glActiveTexture = glActiveTexturedmy;
#endif
   
   if( YglProgramInit() != 0 ) 
      return -1;
   
   _Ygl->drawframe = 0;
   
   glGenTextures(2,_Ygl->vdp1FrameBuff);
   glBindTexture(GL_TEXTURE_2D,_Ygl->vdp1FrameBuff[0]);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, GlWidth, GlHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE,NULL);
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

   glBindTexture(GL_TEXTURE_2D,_Ygl->vdp1FrameBuff[1]);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, GlWidth, GlHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE,NULL);
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
   
   glGenRenderbuffers(1, &_Ygl->rboid);
   glBindRenderbuffer(GL_RENDERBUFFER,_Ygl->rboid);
   glRenderbufferStorage(GL_RENDERBUFFER,  GL_DEPTH24_STENCIL8, GlWidth, GlHeight);
    
   glGenFramebuffers(1,&_Ygl->vdp1fbo);
   glBindFramebuffer(GL_FRAMEBUFFER, _Ygl->vdp1fbo);
   glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _Ygl->vdp1FrameBuff[0], 0);
   glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _Ygl->rboid);
   status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
   if( status != GL_FRAMEBUFFER_COMPLETE )
   {
      YabErrorMsg("YglInit: Framebuffer status = %08X", status );
      return -1;
   }
   
   glBindFramebuffer(GL_FRAMEBUFFER, 0 );   
   
   _Ygl->st = 0;

   // This is probably wrong, but it'll have to do for now
   if ((cachelist = (cache_struct *)malloc(0x100000 / 8 * sizeof(cache_struct))) == NULL)
      return -1;

   return 0;
}


//////////////////////////////////////////////////////////////////////////////

void YglDeInit(void) {
   unsigned int i,j;

   YglTMDeInit();

   if (_Ygl)
   {
      if (_Ygl->levels)
      {
         for (i = 0; i < (_Ygl->depth+1); i++)
         {
         for (j = 0; j < _Ygl->levels[i].prgcount; j++)
         {
            if (_Ygl->levels[i].prg[j].quads)
            free(_Ygl->levels[i].prg[j].quads);
            if (_Ygl->levels[i].prg[j].textcoords)
            free(_Ygl->levels[i].prg[j].textcoords);
            if (_Ygl->levels[i].prg[j].vertexAttribute)
            free(_Ygl->levels[i].prg[j].vertexAttribute);
         }
         free(_Ygl->levels[i].prg);
         }
         free(_Ygl->levels);
      }

      free(_Ygl->messagebuf);

      free(_Ygl);
   }

   if (cachelist)
      free(cachelist);
}

void YglStartWindow( vdp2draw_struct * info, int win0, int logwin0, int win1, int logwin1, int mode )
{
   YglLevel   *level;
   YglProgram *program;
   level = &_Ygl->levels[info->priority];
   YglProgramChange(level,PG_VDP2_STARTWINDOW);
   program = &level->prg[level->prgcurrent];
   program->bwin0 = win0;
   program->logwin0 = logwin0;
   program->bwin1 = win1;
   program->logwin1 = logwin1;
   program->winmode = mode;  
   
}

void YglEndWindow( vdp2draw_struct * info )
{
   YglLevel   *level;
   level = &_Ygl->levels[info->priority];
   YglProgramChange(level,PG_VDP2_ENDWINDOW);
}


//////////////////////////////////////////////////////////////////////////////

YglProgram * YglGetProgram( YglSprite * input, int prg )
{
   YglLevel   *level;
   YglProgram *program;
   
   if (input->priority > 8) {
      VDP1LOG("sprite with priority %d\n", input->priority);
      return NULL;
   }   
   
   level = &_Ygl->levels[input->priority];
   
   level->blendmode |= (input->blendmode&0x03);
   
   if( input->uclipmode != level->uclipcurrent )
   {
      if( input->uclipmode == 0x02 || input->uclipmode == 0x03 )
      {
         YglProgramChange(level,PG_VFP1_STARTUSERCLIP);
         program = &level->prg[level->prgcurrent];
         program->uClipMode = input->uclipmode;
         if( level->ux1 != Vdp1Regs->userclipX1 || level->uy1 != Vdp1Regs->userclipY1 ||
            level->ux2 != Vdp1Regs->userclipX2 || level->uy2 != Vdp1Regs->userclipY2 ) 
         {
            program->ux1=Vdp1Regs->userclipX1;
            program->uy1=Vdp1Regs->userclipY1;
            program->ux2=Vdp1Regs->userclipX2;
            program->uy2=Vdp1Regs->userclipY2;
            level->ux1=Vdp1Regs->userclipX1;
            level->uy1=Vdp1Regs->userclipY1;
            level->ux2=Vdp1Regs->userclipX2;
            level->uy2=Vdp1Regs->userclipY2;
         }else{
            program->ux1=-1;
            program->uy1=-1;
            program->ux2=-1;
            program->uy2=-1;
         }
      }else{
         YglProgramChange(level,PG_VFP1_ENDUSERCLIP);
         program = &level->prg[level->prgcurrent];
         program->uClipMode = input->uclipmode;
      }
      level->uclipcurrent = input->uclipmode;
   
   }
   
   if( level->prg[level->prgcurrent].prgid != prg ) {
      YglProgramChange(level,prg);
   }
   program = &level->prg[level->prgcurrent];
   
   if (program->currentQuad == program->maxQuad) {
      program->maxQuad += 12*128;
      program->quads = (int *) realloc(program->quads, program->maxQuad * sizeof(int));
      program->textcoords = (float *) realloc(program->textcoords, program->maxQuad * sizeof(float) * 2);
      program->vertexAttribute = (float *) realloc(program->vertexAttribute, program->maxQuad * sizeof(float)*2);          
      YglCacheReset();
   }
   
   return program;
}


//////////////////////////////////////////////////////////////////////////////


float * YglQuad(YglSprite * input, YglTexture * output, YglCache * c) {
   unsigned int x, y;
   YglProgram *program;
   texturecoordinate_struct *tmp;
   float q[4];
   int prg = PG_NORMAL;
   int * pos;
   
   if( (input->blendmode&0x03) == 2 )
   {
      prg = PG_VDP2_ADDBLEND;
   }else if( input->blendmode == 0x80 )
   {
      prg = PG_VFP1_HALFTRANS;
   }

   program = YglGetProgram(input,prg);
   if( program == NULL ) return NULL;
   
   
   pos = program->quads + program->currentQuad;
   pos[0] = input->vertices[0];
   pos[1] = input->vertices[1];
   pos[2] = input->vertices[2];
   pos[3] = input->vertices[3];   
   pos[4] = input->vertices[4];
   pos[5] = input->vertices[5];   
   pos[6] = input->vertices[0];
   pos[7] = input->vertices[1];
   pos[8] = input->vertices[4];
   pos[9] = input->vertices[5];   
   pos[10] = input->vertices[6];
   pos[11] = input->vertices[7];   

   tmp = (texturecoordinate_struct *)(program->textcoords + (program->currentQuad * 2));
   
   program->currentQuad += 12;
   YglTMAllocate(output, input->w, input->h, &x, &y);

   
   tmp[0].r = tmp[1].r = tmp[2].r = tmp[3].r = tmp[4].r = tmp[5].r = 0; // these can stay at 0
   
   /*
     0 +---+ 1
       |   |
       +---+ 2
     3 +---+ 
       |   |
     5 +---+ 4
   */
   
   if (input->flip & 0x1) {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x + input->w);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x);
   } else {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x + input->w);
   }
   if (input->flip & 0x2) {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y + input->h);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y);
   } else {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y + input->h);
   }

   if( c != NULL )
   {
      switch(input->flip) {
        case 0:
          c->x = *(program->textcoords + ((program->currentQuad - 12) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 12) * 2)+1); // upper left coordinates(0)   
          break;
        case 1:
          c->x = *(program->textcoords + ((program->currentQuad - 10) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 10) * 2)+1); // upper left coordinates(0)       
          break;
       case 2:
          c->x = *(program->textcoords + ((program->currentQuad - 2) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 2) * 2)+1); // upper left coordinates(0)       
          break;
       case 3:
          c->x = *(program->textcoords + ((program->currentQuad - 4) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 4) * 2)+1); // upper left coordinates(0)       
          break;
      }
   }

   
   if( input->dst == 1 )
   {
      YglCalcTextureQ(input->vertices,q);
      tmp[0].s *= q[0];
      tmp[0].t *= q[0];
      tmp[1].s *= q[1];
      tmp[1].t *= q[1];
      tmp[2].s *= q[2];
      tmp[2].t *= q[2];
      tmp[3].s *= q[0];
      tmp[3].t *= q[0];
      tmp[4].s *= q[2];
      tmp[4].t *= q[2];
      tmp[5].s *= q[3];
      tmp[5].t *= q[3];
      tmp[0].q = q[0]; 
      tmp[1].q = q[1]; 
      tmp[2].q = q[2]; 
      tmp[3].q = q[0]; 
      tmp[4].q = q[2]; 
      tmp[5].q = q[3]; 
   }else{
      tmp[0].q = 1.0f; 
      tmp[1].q = 1.0f; 
      tmp[2].q = 1.0f; 
      tmp[3].q = 1.0f; 
      tmp[4].q = 1.0f; 
      tmp[5].q = 1.0f; 
   }


   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int YglQuadGrowShading(YglSprite * input, YglTexture * output, float * colors,YglCache * c) {
   unsigned int x, y;
   YglProgram *program;
   texturecoordinate_struct *tmp;
   float * vtxa;
   float q[4];
   int prg = PG_VFP1_GOURAUDSAHDING;
   int * pos;
   
   if( (input->blendmode&0x03) == 2 )
   {
      prg = PG_VDP2_ADDBLEND;
   }else if( input->blendmode == 0x80 )
   {
      prg = PG_VFP1_GOURAUDSAHDING_HALFTRANS;
   }
   
   
   program = YglGetProgram(input,prg);
   if( program == NULL ) return -1;

   // Vertex
   pos = program->quads + program->currentQuad;
   pos[0] = input->vertices[0];
   pos[1] = input->vertices[1];
   pos[2] = input->vertices[2];
   pos[3] = input->vertices[3];   
   pos[4] = input->vertices[4];
   pos[5] = input->vertices[5];   
   pos[6] = input->vertices[0];
   pos[7] = input->vertices[1];
   pos[8] = input->vertices[4];
   pos[9] = input->vertices[5];   
   pos[10] = input->vertices[6];
   pos[11] = input->vertices[7];   
   
   
   // Color
   vtxa = (program->vertexAttribute + (program->currentQuad * 2));
   vtxa[0] = colors[0];
   vtxa[1] = colors[1];
   vtxa[2] = colors[2];
   vtxa[3] = colors[3];   
   
   vtxa[4] = colors[4];
   vtxa[5] = colors[5];   
   vtxa[6] = colors[6];
   vtxa[7] = colors[7];
   
   vtxa[8] = colors[8];
   vtxa[9] = colors[9];
   vtxa[10] = colors[10];
   vtxa[11] = colors[11];
   
   vtxa[12] = colors[0];
   vtxa[13] = colors[1];
   vtxa[14] = colors[2];
   vtxa[15] = colors[3];

   vtxa[16] = colors[8];
   vtxa[17] = colors[9];
   vtxa[18] = colors[10];
   vtxa[19] = colors[11];

   vtxa[20] = colors[12];
   vtxa[21] = colors[13];
   vtxa[22] = colors[14];
   vtxa[23] = colors[15];

   // texture
   tmp = (texturecoordinate_struct *)(program->textcoords + (program->currentQuad * 2));
   
   program->currentQuad += 12;

   YglTMAllocate(output, input->w, input->h, &x, &y);

   tmp[0].r = tmp[1].r = tmp[2].r = tmp[3].r = tmp[4].r = tmp[5].r = 0; // these can stay at 0

   if (input->flip & 0x1) {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x + input->w);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x);
   } else {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x + input->w);
   }
   if (input->flip & 0x2) {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y + input->h);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y);
   } else {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y + input->h);
   }

   if( c != NULL )
   {
      switch(input->flip) {
        case 0:
          c->x = *(program->textcoords + ((program->currentQuad - 12) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 12) * 2)+1); // upper left coordinates(0)   
          break;
        case 1:
          c->x = *(program->textcoords + ((program->currentQuad - 10) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 10) * 2)+1); // upper left coordinates(0)       
          break;
       case 2:
          c->x = *(program->textcoords + ((program->currentQuad - 2) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 2) * 2)+1); // upper left coordinates(0)       
          break;
       case 3:
          c->x = *(program->textcoords + ((program->currentQuad - 4) * 2));   // upper left coordinates(0)
          c->y = *(program->textcoords + ((program->currentQuad - 4) * 2)+1); // upper left coordinates(0)       
          break;
      }
   }

   
   if( input->dst == 1 )
   {
      YglCalcTextureQ(input->vertices,q);
      tmp[0].s *= q[0];
      tmp[0].t *= q[0];
      tmp[1].s *= q[1];
      tmp[1].t *= q[1];
      tmp[2].s *= q[2];
      tmp[2].t *= q[2];
      tmp[3].s *= q[0];
      tmp[3].t *= q[0];
      tmp[4].s *= q[2];
      tmp[4].t *= q[2];
      tmp[5].s *= q[3];
      tmp[5].t *= q[3];
      
      tmp[0].q = q[0]; 
      tmp[1].q = q[1]; 
      tmp[2].q = q[2]; 
      tmp[3].q = q[0]; 
      tmp[4].q = q[2]; 
      tmp[5].q = q[3]; 
   }else{
      tmp[0].q = 1.0f; 
      tmp[1].q = 1.0f; 
      tmp[2].q = 1.0f; 
      tmp[3].q = 1.0f; 
      tmp[4].q = 1.0f; 
      tmp[5].q = 1.0f; 
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void YglCachedQuad(YglSprite * input, YglCache * cache) {
   YglProgram * program;
   unsigned int x,y;
   texturecoordinate_struct *tmp;
   float q[4];
   int * pos;

   int prg = PG_NORMAL;
   
   if( (input->blendmode&0x03) == 2 )
   {
      prg = PG_VDP2_ADDBLEND;
   }else if( input->blendmode == 0x80 )
   {
      prg = PG_VFP1_HALFTRANS;
   }
  
   program = YglGetProgram(input,prg);
   if( program == NULL ) return;
   
   x = cache->x;
   y = cache->y;

   // Vertex
   pos = program->quads + program->currentQuad;
   pos[0] = input->vertices[0];
   pos[1] = input->vertices[1];
   pos[2] = input->vertices[2];
   pos[3] = input->vertices[3];   
   pos[4] = input->vertices[4];
   pos[5] = input->vertices[5];   
   pos[6] = input->vertices[0];
   pos[7] = input->vertices[1];
   pos[8] = input->vertices[4];
   pos[9] = input->vertices[5];   
   pos[10] = input->vertices[6];
   pos[11] = input->vertices[7]; 
   
   // Color
   tmp = (texturecoordinate_struct *)(program->textcoords + (program->currentQuad * 2));
      
   program->currentQuad += 12;

  tmp[0].r = tmp[1].r = tmp[2].r = tmp[3].r = tmp[4].r = tmp[5].r = 0; // these can stay at 0

   if (input->flip & 0x1) {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x + input->w);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x);
   } else {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x + input->w);
   }
   if (input->flip & 0x2) {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y + input->h);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y);
   } else {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y + input->h);
   }

   if( input->dst == 1 )
   {
      YglCalcTextureQ(input->vertices,q);
      tmp[0].s *= q[0];
      tmp[0].t *= q[0];
      tmp[1].s *= q[1];
      tmp[1].t *= q[1];
      tmp[2].s *= q[2];
      tmp[2].t *= q[2];
      tmp[3].s *= q[0];
      tmp[3].t *= q[0];
      tmp[4].s *= q[2];
      tmp[4].t *= q[2];
      tmp[5].s *= q[3];
      tmp[5].t *= q[3];
      
      tmp[0].q = q[0]; 
      tmp[1].q = q[1]; 
      tmp[2].q = q[2]; 
      tmp[3].q = q[0]; 
      tmp[4].q = q[2]; 
      tmp[5].q = q[3]; 
   }else{
      tmp[0].q = 1.0f; 
      tmp[1].q = 1.0f; 
      tmp[2].q = 1.0f; 
      tmp[3].q = 1.0f; 
      tmp[4].q = 1.0f; 
      tmp[5].q = 1.0f; 
   }
  
}

//////////////////////////////////////////////////////////////////////////////

void YglCacheQuadGrowShading(YglSprite * input, float * colors,YglCache * cache) {
   YglProgram * program;
   unsigned int x,y;
   texturecoordinate_struct *tmp;
   float q[4];
   int prg = PG_VFP1_GOURAUDSAHDING;
   float * vtxa;
   int *pos;
   
  if( (input->blendmode&0x03) == 2 )
   {
      prg = PG_VDP2_ADDBLEND;
   }else if( input->blendmode == 0x80 )
   {
      prg = PG_VFP1_GOURAUDSAHDING_HALFTRANS;
   }

   program = YglGetProgram(input,prg);
   if( program == NULL ) return;
   
   x = cache->x;
   y = cache->y;

   // Vertex
   pos = program->quads + program->currentQuad;
   pos[0] = input->vertices[0];
   pos[1] = input->vertices[1];
   pos[2] = input->vertices[2];
   pos[3] = input->vertices[3];   
   pos[4] = input->vertices[4];
   pos[5] = input->vertices[5];   
   pos[6] = input->vertices[0];
   pos[7] = input->vertices[1];
   pos[8] = input->vertices[4];
   pos[9] = input->vertices[5];   
   pos[10] = input->vertices[6];
   pos[11] = input->vertices[7]; 

   // Color 
   vtxa = (program->vertexAttribute + (program->currentQuad * 2));

   vtxa[0] = colors[0];
   vtxa[1] = colors[1];
   vtxa[2] = colors[2];
   vtxa[3] = colors[3];   
   
   vtxa[4] = colors[4];
   vtxa[5] = colors[5];   
   vtxa[6] = colors[6];
   vtxa[7] = colors[7];
   
   vtxa[8] = colors[8];
   vtxa[9] = colors[9];
   vtxa[10] = colors[10];
   vtxa[11] = colors[11];
   
   vtxa[12] = colors[0];
   vtxa[13] = colors[1];
   vtxa[14] = colors[2];
   vtxa[15] = colors[3];

   vtxa[16] = colors[8];
   vtxa[17] = colors[9];
   vtxa[18] = colors[10];
   vtxa[19] = colors[11];

   vtxa[20] = colors[12];
   vtxa[21] = colors[13];
   vtxa[22] = colors[14];
   vtxa[23] = colors[15];

   // Texture 
   tmp = (texturecoordinate_struct *)(program->textcoords + (program->currentQuad * 2));
 
   program->currentQuad += 12;

  tmp[0].r = tmp[1].r = tmp[2].r = tmp[3].r = tmp[4].r = tmp[5].r = 0; // these can stay at 0

   if (input->flip & 0x1) {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x + input->w);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x);
   } else {
      tmp[0].s = tmp[3].s = tmp[5].s = (float)(x);
      tmp[1].s = tmp[2].s = tmp[4].s = (float)(x + input->w);
   }
   if (input->flip & 0x2) {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y + input->h);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y);
   } else {
      tmp[0].t = tmp[1].t = tmp[3].t = (float)(y);
      tmp[2].t = tmp[4].t = tmp[5].t = (float)(y + input->h);
   }

   if( input->dst == 1 )
   {
      YglCalcTextureQ(input->vertices,q);
      tmp[0].s *= q[0];
      tmp[0].t *= q[0];
      tmp[1].s *= q[1];
      tmp[1].t *= q[1];
      tmp[2].s *= q[2];
      tmp[2].t *= q[2];
      tmp[3].s *= q[0];
      tmp[3].t *= q[0];
      tmp[4].s *= q[2];
      tmp[4].t *= q[2];
      tmp[5].s *= q[3];
      tmp[5].t *= q[3];
      tmp[0].q = q[0]; 
      tmp[1].q = q[1]; 
      tmp[2].q = q[2]; 
      tmp[3].q = q[0]; 
      tmp[4].q = q[2]; 
      tmp[5].q = q[3]; 
   }else{
      tmp[0].q = 1.0f; 
      tmp[1].q = 1.0f; 
      tmp[2].q = 1.0f; 
      tmp[3].q = 1.0f; 
      tmp[4].q = 1.0f; 
      tmp[5].q = 1.0f; 
   }
}

//////////////////////////////////////////////////////////////////////////////
void YglRenderVDP1(void) {
  
   YglLevel * level;
   GLuint cprg=0;
   int j;
   int status;
      
  
   level = &(_Ygl->levels[_Ygl->depth]);
   glDisable(GL_STENCIL_TEST);
   glBindTexture(GL_TEXTURE_2D, _Ygl->texture);
   glMatrixMode(GL_MODELVIEW);
   glLoadIdentity();   
   
   cprg = PG_NORMAL;
   glUseProgram(0);   
   
   glBindFramebuffer(GL_FRAMEBUFFER, _Ygl->vdp1fbo);
   glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _Ygl->vdp1FrameBuff[_Ygl->drawframe], 0);
   glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _Ygl->rboid);
   status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
   if( status != GL_FRAMEBUFFER_COMPLETE )
   {
      printf("YglRenderVDP1: Framebuffer status = %08X\n", status );
      return;
   }else{
      //printf("Framebuffer status OK = %08X\n", status );
   }
   
   glClearColor(0.0f,0.0f,0.0f,0.0f);
   glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);   
   
   glDisable(GL_DEPTH_TEST);
   glDisable(GL_BLEND);
   
 
   for( j=0;j<(level->prgcurrent+1); j++ )
   {
      if( level->prg[j].prgid != cprg )
      {
         cprg = level->prg[j].prgid;
         glUseProgram(level->prg[j].prg);
      }
      
      glVertexPointer(2, GL_INT, 0, level->prg[j].quads);
      glTexCoordPointer(4, GL_FLOAT, 0, level->prg[j].textcoords);
      
      if(level->prg[j].setupUniform) 
      {
         level->prg[j].setupUniform((void*)&level->prg[j]);
      }
         
      if( level->prg[j].currentQuad != 0 )
      {
         glDrawArrays(GL_TRIANGLES, 0, level->prg[j].currentQuad/2);
      }
      
      if( level->prg[j].cleanupUniform )
      {
         level->prg[j].cleanupUniform((void*)&level->prg[j]);
      }
   }
   level->prgcurrent = 0;
   
   _Ygl->drawframe=(_Ygl->drawframe^0x01)&0x01;
   
   // glFlush(); need??
   glBindFramebuffer(GL_FRAMEBUFFER, 0);
   glEnable(GL_DEPTH_TEST);
   glEnable(GL_BLEND);
   
   
}

void YglNeedToUpdateWindow()
{
   _Ygl->bUpdateWindow = 1;
}

void YglSetVdp2Window()
{
   if( _Ygl->bUpdateWindow )
   {
      //
     glColorMask(GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE);
     glDepthMask(GL_FALSE);
     glDisable(GL_TEXTURE_2D);
     glDisable(GL_ALPHA_TEST);
     glDisable(GL_DEPTH_TEST);
      
     glClearStencil(0);
     glClear(GL_STENCIL_BUFFER_BIT);
     glEnable(GL_STENCIL_TEST);
     glDisable(GL_TEXTURE_2D);
     glColor4f(1.0f,1.0f,1.0f,1.0f);   
     glEnableClientState(GL_VERTEX_ARRAY);
     glDisableClientState(GL_TEXTURE_COORD_ARRAY);      
     glStencilOp(GL_REPLACE,GL_REPLACE,GL_REPLACE);

      if( _Ygl->win0_vertexcnt != 0 )
      {
           glStencilMask(0x01);
           glStencilFunc(GL_ALWAYS,0x01,0x01);
           glVertexPointer(2, GL_INT, 0, _Ygl->win0v);
           glDrawArrays(GL_TRIANGLE_STRIP,0,_Ygl->win0_vertexcnt);
      }
      
      if( _Ygl->win1_vertexcnt != 0 )
      {
          glStencilMask(0x02);
          glStencilFunc(GL_ALWAYS,0x02,0x02);
          glVertexPointer(2, GL_INT, 0, _Ygl->win1v);
          glDrawArrays(GL_TRIANGLE_STRIP,0,_Ygl->win1_vertexcnt);
      }
       
      glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);
      glDepthMask(GL_TRUE);       
      glEnable(GL_TEXTURE_2D);
      glEnable(GL_DEPTH_TEST);
      glEnable(GL_ALPHA_TEST);
      glDisable(GL_STENCIL_TEST);
      glEnableClientState(GL_VERTEX_ARRAY);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY);    
      glStencilOp(GL_KEEP,GL_KEEP,GL_KEEP);
      glStencilFunc(GL_ALWAYS,0,0xFF);
      glStencilMask(0xFFFFFFFF);
      
      _Ygl->bUpdateWindow = 0;
   }
   return;
}


void YglRenderFrameBuffer( int from , int to ) {
   
   GLint   vertices[12];
   GLfloat texcord[12];
   float offsetcol[4];
   int bwin0,bwin1,logwin0,logwin1,winmode;
   
   // Out of range, do nothing
   if( _Ygl->vdp1_maxpri < from ) return;
   if( _Ygl->vdp1_minpri > to ) return;
        
   glEnable(GL_TEXTURE_2D);
   
   
   offsetcol[0] = vdp1cor / 255.0f;
   offsetcol[1] = vdp1cog / 255.0f;
   offsetcol[2] = vdp1cob / 255.0f;
   offsetcol[3] = 0.0f;
   
   Ygl_uniformVDP2DrawFramebuffer( (float)(from)/10.0f , (float)(to)/10.0f, offsetcol );
   glBindTexture(GL_TEXTURE_2D, _Ygl->vdp1FrameBuff[(_Ygl->drawframe^0x01)&0x01] );
   
   // Window Mode
   bwin0 = (Vdp2Regs->WCTLC >> 9) &0x01;
   logwin0 = (Vdp2Regs->WCTLC >> 8) & 0x01;
   bwin1 = (Vdp2Regs->WCTLC >> 11) &0x01;
   logwin1 = (Vdp2Regs->WCTLC >> 10) & 0x01;
   winmode    = (Vdp2Regs->WCTLC >> 15 ) & 0x01;


   if( bwin0 || bwin1 )
   {
      glEnable(GL_STENCIL_TEST);
      glStencilOp(GL_KEEP,GL_KEEP,GL_KEEP);
   
      if( bwin0 && !bwin1 )
      {
         if( logwin0 )
         {
            glStencilFunc(GL_EQUAL,0x01,0x01);
         }else{
            glStencilFunc(GL_NOTEQUAL,0x01,0x01);
         }
      }else if( !bwin0 && bwin1 ) {
         
         if( logwin1 )
         {
            glStencilFunc(GL_EQUAL,0x02,0x02);
         }else{
            glStencilFunc(GL_NOTEQUAL,0x02,0x02);
         }
      }else if( bwin0 && bwin1 ) {
         // and
         if( winmode == 0x0 )
         {
            glStencilFunc(GL_EQUAL,0x03,0x03);
               
         // OR
         }else if( winmode == 0x01 )
         {
            glStencilFunc(GL_LEQUAL,0x01,0x03);
            
         }
      }
   }

   
   glMatrixMode(GL_TEXTURE);
   glPushMatrix();
   glLoadIdentity();

   // render
   vertices[0] = 0;
   vertices[1] = 0;
   vertices[2] = _Ygl->rwidth+1;
   vertices[3] = 0;
   vertices[4] = _Ygl->rwidth+1;
   vertices[5] = _Ygl->rheight+1;

   vertices[6] = 0;
   vertices[7] = 0;
   vertices[8] = _Ygl->rwidth+1;
   vertices[9] = _Ygl->rheight+1;
   vertices[10] = 0;
   vertices[11] = _Ygl->rheight+1;  


   texcord[0] = 0.0f;
   texcord[1] = 1.0f;
   texcord[2] = 1.0f;
   texcord[3] = 1.0f;
   texcord[4] = 1.0f;
   texcord[5] = 0.0f;

   texcord[6] = 0.0f;
   texcord[7] = 1.0f;
   texcord[8] = 1.0f;
   texcord[9] = 0.0f;
   texcord[10] = 0.0f;
   texcord[11] = 0.0f;  

   glVertexPointer(2, GL_INT, 0, vertices);
   glTexCoordPointer(2, GL_FLOAT, 0, texcord);
   glDrawArrays(GL_TRIANGLES, 0, 6);

   glPopMatrix();
   if( bwin0 || bwin1 )
   {
      glDisable(GL_STENCIL_TEST);
      glStencilFunc(GL_ALWAYS,0,0xFF);      
   }
   glMatrixMode(GL_MODELVIEW);
}


void YglRender(void) {
   YglLevel * level;
   GLuint cprg=0;
   int from = 0;
   int to   = 0;

   glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
   
   glEnable(GL_TEXTURE_2D);
   glShadeModel(GL_SMOOTH);

   glBindTexture(GL_TEXTURE_2D, _Ygl->texture);
   glTexSubImage2D (GL_TEXTURE_2D, 0, 0, 0, YglTM->width, YglTM->yMax, GL_RGBA, GL_UNSIGNED_BYTE, YglTM->texture);

   if(_Ygl->st) {
      int vertices [] = { 0, 0, 320, 0, 320, 224, 0, 224 };
      int text [] = { 0, 0, YglTM->width, 0, YglTM->width, YglTM->height, 0, YglTM->height };
      glVertexPointer(2, GL_INT, 0, vertices);
      glTexCoordPointer(4, GL_INT, 0, text);
      glDrawArrays(GL_QUADS, 0, 4);
   } else {
      unsigned int i,j;
      
      YglRenderVDP1();
      
      glMatrixMode(GL_MODELVIEW);
      glLoadIdentity();
      
      cprg = PG_NORMAL;
      glUseProgram(0);   
      
      YglSetVdp2Window();

      glTranslatef(0.0f,0.0f,-1.0f);
      for(i = 0;i < _Ygl->depth;i++) 
      {
         level = _Ygl->levels + i;

         if( level->blendmode != 0 ) 
         {
            to = i;
            YglRenderFrameBuffer(from,to);
            from = to;

            // clean up
            cprg = PG_NORMAL;
            glUseProgram(0);   
            glBindTexture(GL_TEXTURE_2D, _Ygl->texture);
         }

         glDisable(GL_STENCIL_TEST);
         for( j=0;j<(level->prgcurrent+1); j++ )
         {
            if( level->prg[j].prgid != cprg )
            {
               cprg = level->prg[j].prgid;
               glUseProgram(level->prg[j].prg);
            }
            glVertexPointer(2, GL_INT, 0, level->prg[j].quads);
            glTexCoordPointer(4, GL_FLOAT, 0, level->prg[j].textcoords);
            if(level->prg[j].setupUniform) 
            {
               level->prg[j].setupUniform((void*)&level->prg[j]);
            }
            if( level->prg[j].currentQuad != 0 )
            {
               glDrawArrays(GL_TRIANGLES, 0, level->prg[j].currentQuad/2);
            }
            if( level->prg[j].cleanupUniform )
            {
               level->prg[j].cleanupUniform((void*)&level->prg[j]);
            }
         }
         level->prgcurrent = 0;
         glTranslatef(0.0f,0.0f,0.1f);
      }
      YglRenderFrameBuffer(from,8);
   }

   if (OSDUseBuffer())
   {
      int vertices [] = { 0, 0, 320, 0, 320, 224, 0, 224 };
      int text [] = { 0, 0, 320, 0, 320, 224, 0, 224 };

      // render
      text[2] = _Ygl->msgwidth;
      text[4] = _Ygl->msgwidth;
      text[5] = _Ygl->msgheight;
      text[7] = _Ygl->msgheight;

      glUseProgram(0);

      memset( _Ygl->messagebuf,0, sizeof(u32)*_Ygl->msgwidth * _Ygl->msgheight );
      if (OSDDisplayMessages(_Ygl->messagebuf, _Ygl->msgwidth,_Ygl->msgheight))
      {
         glBindTexture(GL_TEXTURE_2D, _Ygl->msgtexture);
         glTexSubImage2D (GL_TEXTURE_2D, 0, 0, 0, _Ygl->msgwidth,_Ygl->msgheight, GL_RGBA, GL_UNSIGNED_BYTE, _Ygl->messagebuf );
         glMatrixMode(GL_MODELVIEW);
         glLoadIdentity();
         glVertexPointer(2, GL_INT, 0, vertices);
         glTexCoordPointer(2, GL_INT, 0, text);
         glDrawArrays(GL_QUADS, 0, 4);
      }

      glDisable(GL_TEXTURE_2D);
   }
   else
   {
      glDisable(GL_TEXTURE_2D);
      glUseProgram(0);

      OSDDisplayMessages(NULL, -1, -1);
   }

   YuiSwapBuffers();

}

//////////////////////////////////////////////////////////////////////////////

void YglReset(void) {
   YglLevel * level;
   unsigned int i,j;

   glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

   YglTMReset();

   for(i = 0;i < (_Ygl->depth+1) ;i++) {
     level = _Ygl->levels + i;
     level->blendmode  = 0;
     level->prgcurrent = 0;
     level->uclipcurrent = 0;
     level->ux1 = 0;
     level->uy1 = 0;
     level->ux2 = 0;
     level->uy2 = 0;     
     for( j=0; j< level->prgcount; j++ )
     {
      level->prg[j].currentQuad = 0;
     }
   }
}

//////////////////////////////////////////////////////////////////////////////

void YglShowTexture(void) {
   _Ygl->st = !_Ygl->st;
}

//////////////////////////////////////////////////////////////////////////////

void YglChangeResolution(int w, int h) {
   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrtho(0, w, h, 0, 1, 0);
   _Ygl->rwidth = w;
   _Ygl->rheight = h;
}

//////////////////////////////////////////////////////////////////////////////

int YglIsCached(u32 addr, YglCache * c ) {
   int i = 0;

   for (i = 0; i < cachelistsize; i++)
   {
      if (addr == cachelist[i].id)
     {
         c->x=cachelist[i].c.x;
       c->y=cachelist[i].c.y;
       return 1;
      }
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void YglCacheAdd(u32 addr, YglCache * c) {
   cachelist[cachelistsize].id = addr;
   cachelist[cachelistsize].c.x = c->x;
   cachelist[cachelistsize].c.y = c->y;
   cachelistsize++;
}

//////////////////////////////////////////////////////////////////////////////

void YglCacheReset(void) {
   cachelistsize = 0;
}

//////////////////////////////////////////////////////////////////////////////



#endif



