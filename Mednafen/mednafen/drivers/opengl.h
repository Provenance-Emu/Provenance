#ifndef __DRIVERS_OPENGL_H
#define __DRIVERS_OPENGL_H

//#define GL_GLEXT_LEGACY
//#ifdef HAVE_APPLE_OPENGL_FRAMEWORK
//#include <OpenGL/gl.h>
//#include <OpenGL/glext.h>
//#include <OpenGL/glu.h>
//#else
//#include <GL/gl.h>
//#include <GL/glext.h>
//#include <GL/glu.h>
//#endif

#include <SDL_opengl.h>


#ifndef GLAPIENTRY
 #ifdef APIENTRY
  #define GLAPIENTRY APIENTRY
 #else
  #define GLAPIENTRY
 #endif
#endif

typedef GLenum GLAPIENTRY (*glGetError_Func)(void);

typedef void GLAPIENTRY (*glBindTexture_Func)(GLenum target,GLuint texture);
typedef void GLAPIENTRY (*glColorTableEXT_Func)(GLenum target,
        GLenum internalformat,  GLsizei width, GLenum format, GLenum type,
        const GLvoid *table);
typedef void GLAPIENTRY (*glTexImage2D_Func)(GLenum target, GLint level,
        GLint internalFormat,
        GLsizei width, GLsizei height, GLint border,
        GLenum format, GLenum type,
        const GLvoid *pixels);
typedef void GLAPIENTRY (*glBegin_Func)(GLenum mode);
typedef void GLAPIENTRY (*glVertex2f_Func)(GLfloat x, GLfloat y);
typedef void GLAPIENTRY (*glTexCoord2f_Func)(GLfloat s, GLfloat t);
typedef void GLAPIENTRY (*glEnd_Func)(void);
typedef void GLAPIENTRY (*glEnable_Func)(GLenum cap);
typedef void GLAPIENTRY (*glBlendFunc_Func)(GLenum sfactor, GLenum dfactor);
typedef const GLubyte* GLAPIENTRY (*glGetString_Func)(GLenum name);
typedef void GLAPIENTRY (*glViewport_Func)(GLint x, GLint y,GLsizei width,
         GLsizei height);
typedef void GLAPIENTRY (*glGenTextures_Func)(GLsizei n, GLuint *textures);
typedef void GLAPIENTRY (*glDeleteTextures_Func)(GLsizei n,
         const GLuint *textures);
typedef void GLAPIENTRY (*glTexParameteri_Func)(GLenum target, GLenum pname,
         GLint param);
typedef void GLAPIENTRY (*glClearColor_Func)(GLclampf red, GLclampf green,
         GLclampf blue, GLclampf alpha);
typedef void GLAPIENTRY (*glLoadIdentity_Func)(void);
typedef void GLAPIENTRY (*glClear_Func)(GLbitfield mask);
typedef void GLAPIENTRY (*glMatrixMode_Func)(GLenum mode);
typedef void GLAPIENTRY (*glDisable_Func)(GLenum cap);

typedef void GLAPIENTRY (*glPixelStorei_Func)(GLenum pname, GLint param);
typedef void GLAPIENTRY (*glTexSubImage2D_Func)(GLenum target, GLint level,
                                       GLint xoffset, GLint yoffset,
                                       GLsizei width, GLsizei height,
                                       GLenum format, GLenum type,
                                       const GLvoid *pixels);
typedef void GLAPIENTRY (*glFinish_Func)(void);
typedef void GLAPIENTRY (*glOrtho_Func)(GLdouble left, GLdouble right,
                                 GLdouble bottom, GLdouble top,
                                 GLdouble near_val, GLdouble far_val);
typedef void GLAPIENTRY (*glPixelTransferf_Func)(GLenum pname, GLfloat param);
typedef void GLAPIENTRY (*glColorMask_Func)(GLboolean, GLboolean, GLboolean, GLboolean);
typedef void GLAPIENTRY (*glTexEnvf_Func)(GLenum, GLenum, GLfloat);
typedef void GLAPIENTRY (*glGetIntegerv_Func)(GLenum, GLint *);
typedef void GLAPIENTRY (*glTexGend_Func)(GLenum, GLenum, GLdouble);
typedef void GLAPIENTRY (*glRasterPos2i_Func)(GLint x, GLint y);
typedef void GLAPIENTRY (*glDrawPixels_Func)(GLsizei width, GLsizei height, GLenum format, GLenum type, const GLvoid *pixels);
typedef void GLAPIENTRY (*glPixelZoom_Func)(GLfloat, GLfloat);
typedef void GLAPIENTRY (*glGetTexLevelParameteriv_Func)(GLenum target, GLint level, GLenum pname, GLint *params);
typedef void GLAPIENTRY (*glAccum_Func)(GLenum, GLfloat);
typedef void GLAPIENTRY (*glClearAccum_Func)(GLfloat, GLfloat, GLfloat, GLfloat);
typedef void GLAPIENTRY (*glPushMatrix_Func)(void);
typedef void GLAPIENTRY (*glPopMatrix_Func)(void);
typedef void GLAPIENTRY (*glRotated_Func)(GLdouble angle, GLdouble x, GLdouble y, GLdouble z);
typedef void GLAPIENTRY (*glScalef_Func)(GLfloat x, GLfloat y, GLfloat z);
typedef void GLAPIENTRY (*glReadPixels_Func)(GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid *data);

#ifndef GL_ARB_sync
#define GL_ARB_sync 1
typedef int64_t GLint64;
typedef uint64_t GLuint64;
typedef struct __GLsync *GLsync;

#define        GL_MAX_SERVER_WAIT_TIMEOUT         0x9111
#define        GL_OBJECT_TYPE                     0x9112
#define        GL_SYNC_CONDITION                  0x9113
#define        GL_SYNC_STATUS                     0x9114
#define        GL_SYNC_FLAGS                      0x9115
#define        GL_SYNC_FENCE                      0x9116
#define        GL_SYNC_GPU_COMMANDS_COMPLETE      0x9117
#define        GL_UNSIGNALED                      0x9118
#define        GL_SIGNALED                        0x9119
#define        GL_SYNC_FLUSH_COMMANDS_BIT         0x00000001
#define        GL_TIMEOUT_IGNORED                 0xFFFFFFFFFFFFFFFFull
#define        GL_ALREADY_SIGNALED                0x911A
#define        GL_TIMEOUT_EXPIRED                 0x911B
#define        GL_CONDITION_SATISFIED             0x911C
#define        GL_WAIT_FAILED                     0x911D

#endif

typedef GLsync GLAPIENTRY (*glFenceSync_Func)(GLenum condition, GLbitfield flags);
typedef GLboolean GLAPIENTRY (*glIsSync_Func)(GLsync sync);
typedef void GLAPIENTRY (*glDeleteSync_Func)(GLsync sync);

typedef GLenum GLAPIENTRY (*glClientWaitSync_Func)(GLsync sync, GLbitfield flags, GLuint64 timeout);
typedef void GLAPIENTRY (*glWaitSync_Func)(GLsync sync, GLbitfield flags, GLuint64 timeout);

typedef void GLAPIENTRY (*glGetInteger64v_Func)(GLenum pname, GLint64 *params);
typedef void GLAPIENTRY (*glGetSynciv_Func)(GLsync sync, GLenum pname, GLsizei bufSize, GLsizei *length, GLint *values);

typedef GLhandleARB GLAPIENTRY (*glCreateShaderObjectARB_Func)(GLenum);
typedef void GLAPIENTRY (*glShaderSourceARB_Func)(GLhandleARB, GLsizei, const GLcharARB* *, const GLint *);
typedef void GLAPIENTRY (*glCompileShaderARB_Func)(GLhandleARB);
typedef GLhandleARB GLAPIENTRY (*glCreateProgramObjectARB_Func)(void);
typedef void GLAPIENTRY (*glAttachObjectARB_Func)(GLhandleARB, GLhandleARB);
typedef void GLAPIENTRY (*glLinkProgramARB_Func)(GLhandleARB);
typedef void GLAPIENTRY (*glUseProgramObjectARB_Func)(GLhandleARB);
typedef void GLAPIENTRY (*glUniform1fARB_Func)(GLint, GLfloat);
typedef void GLAPIENTRY (*glUniform2fARB_Func)(GLint, GLfloat, GLfloat);
typedef void GLAPIENTRY (*glUniform3fARB_Func)(GLint, GLfloat, GLfloat, GLfloat);
typedef void GLAPIENTRY (*glUniform1iARB_Func)(GLint, GLint);
typedef void GLAPIENTRY (*glUniform2iARB_Func)(GLint, GLint, GLint);
typedef void GLAPIENTRY (*glUniform3iARB_Func)(GLint, GLint, GLint, GLint);
typedef void GLAPIENTRY (*glUniformMatrix2fvARB_Func)(GLint, GLsizei, GLboolean, const GLfloat*);
typedef void GLAPIENTRY (*glActiveTextureARB_Func)(GLenum);
typedef void GLAPIENTRY (*glGetInfoLogARB_Func)(GLhandleARB, GLsizei, GLsizei *, GLcharARB *);
typedef GLint GLAPIENTRY (*glGetUniformLocationARB_Func)(GLhandleARB, const GLcharARB *);
typedef void GLAPIENTRY (*glDeleteObjectARB_Func)(GLhandleARB);
typedef void GLAPIENTRY (*glDetachObjectARB_Func)(GLhandleARB, GLhandleARB);

typedef void GLAPIENTRY (*glGetObjectParameterivARB_Func)(GLhandleARB, GLenum, GLint *);


#include "shader.h"

class OpenGL_Blitter
{
 public:

 OpenGL_Blitter(int scanlines, ShaderType pixshader, const int screen_w, const int screen_h, int *rs, int *gs, int *bs, int *as);
 ~OpenGL_Blitter();

 void BlitRaw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *dest_rect, const bool source_alpha);
 void Blit(MDFN_Surface *src_surface, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, const MDFN_Rect *original_src_rect, int InterlaceField, int UsingIP, int rotated);
 void ClearBackBuffer(void);

 //void HardSync(uint64 timeout);

 void ReadPixels(MDFN_Surface *surface, const MDFN_Rect *rect);

 private:

 void Cleanup(void);
 void DrawQuad(float src_coords[4][2], int dest_coords[4][2]);
 void DrawLinearIP(const unsigned UsingIP, const unsigned rotated, const MDFN_Rect *tex_src_rect, const MDFN_Rect *dest_rect, const uint32 tmpwidth, const uint32 tmpheight);

 glGetError_Func p_glGetError;
 glBindTexture_Func p_glBindTexture;
 glColorTableEXT_Func p_glColorTableEXT;
 glTexImage2D_Func p_glTexImage2D;
 glBegin_Func p_glBegin;
 glVertex2f_Func p_glVertex2f;
 glTexCoord2f_Func p_glTexCoord2f;
 glEnd_Func p_glEnd;
 glEnable_Func p_glEnable;
 glBlendFunc_Func p_glBlendFunc;
 glGetString_Func p_glGetString;
 glViewport_Func p_glViewport;
 glGenTextures_Func p_glGenTextures;
 glDeleteTextures_Func p_glDeleteTextures;
 glTexParameteri_Func p_glTexParameteri;
 glClearColor_Func p_glClearColor;
 glLoadIdentity_Func p_glLoadIdentity;
 glClear_Func p_glClear;
 glMatrixMode_Func p_glMatrixMode;
 glDisable_Func p_glDisable;
 glPixelStorei_Func p_glPixelStorei;
 glTexSubImage2D_Func p_glTexSubImage2D;
 glFinish_Func p_glFinish;
 glOrtho_Func p_glOrtho;
 glPixelTransferf_Func p_glPixelTransferf;
 glColorMask_Func p_glColorMask;
 glTexEnvf_Func p_glTexEnvf;
 glGetIntegerv_Func p_glGetIntegerv;
 glTexGend_Func p_glTexGend;
 glDrawPixels_Func p_glDrawPixels;
 glRasterPos2i_Func p_glRasterPos2i;
 glPixelZoom_Func p_glPixelZoom;
 glGetTexLevelParameteriv_Func p_glGetTexLevelParameteriv;
 glAccum_Func p_glAccum;
 glClearAccum_Func p_glClearAccum;
 glPushMatrix_Func p_glPushMatrix;
 glPopMatrix_Func p_glPopMatrix;
 glRotated_Func p_glRotated;
 glScalef_Func p_glScalef;
 glReadPixels_Func p_glReadPixels;

 glFenceSync_Func p_glFenceSync;
 glIsSync_Func p_glIsSync;
 glDeleteSync_Func p_glDeleteSync;
 glClientWaitSync_Func p_glClientWaitSync;
 glWaitSync_Func p_glWaitSync;
 glGetInteger64v_Func p_glGetInteger64v;
 glGetSynciv_Func p_glGetSynciv;

 glCreateShaderObjectARB_Func p_glCreateShaderObjectARB;
 glShaderSourceARB_Func p_glShaderSourceARB;
 glCompileShaderARB_Func p_glCompileShaderARB;
 glCreateProgramObjectARB_Func p_glCreateProgramObjectARB;
 glAttachObjectARB_Func p_glAttachObjectARB;
 glLinkProgramARB_Func p_glLinkProgramARB;
 glUseProgramObjectARB_Func p_glUseProgramObjectARB;
 glUniform1fARB_Func p_glUniform1fARB;
 glUniform2fARB_Func p_glUniform2fARB;
 glUniform3fARB_Func p_glUniform3fARB;
 glUniform1iARB_Func p_glUniform1iARB;
 glUniform2iARB_Func p_glUniform2iARB;
 glUniform3iARB_Func p_glUniform3iARB;
 glUniformMatrix2fvARB_Func p_glUniformMatrix2fvARB;
 glActiveTextureARB_Func p_glActiveTextureARB;
 glGetInfoLogARB_Func p_glGetInfoLogARB;
 glGetUniformLocationARB_Func p_glGetUniformLocationARB;
 glDeleteObjectARB_Func p_glDeleteObjectARB;
 glDetachObjectARB_Func p_glDetachObjectARB;
 glGetObjectParameterivARB_Func p_glGetObjectParameterivARB;

 uint32 MaxTextureSize;		// Maximum power-of-2 texture width/height(we assume they're the same, and if they're not, this is set to the lower value of the two)
 bool SupportNPOT; 		// True if the OpenGL implementation supports non-power-of-2-sized textures
 bool SupportARBSync;
 GLenum PixelFormat;		// For glTexSubImage2D()
 GLenum PixelType;		// For glTexSubImage2D()

 const int gl_screen_w, gl_screen_h;
 GLuint textures[4];		// emulated fb, scanlines, osd, raw(netplay)
 GLuint rgb_mask; 		// TODO:  RGB mask texture for LCD RGB triad simulation

 int using_scanlines;	// Don't change to bool.
 unsigned int last_w, last_h;

 uint32 OSDLastWidth, OSDLastHeight;

 OpenGL_Blitter_Shader *shader;

 uint32 *DummyBlack;		 // Black/Zeroed image data for cleaning textures
 uint32 DummyBlackSize;

 friend class OpenGL_Blitter_Shader;
};

#endif
