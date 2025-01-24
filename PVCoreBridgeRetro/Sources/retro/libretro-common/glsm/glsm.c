/* Copyright (C) 2010-2016 The RetroArch team
 *
 * ---------------------------------------------------------------------------------------
 * The following license statement only applies to this libretro SDK code part (glsm).
 * ---------------------------------------------------------------------------------------
 *
 * Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <glsym/glsym.h>
#include <glsm/glsm.h>

struct gl_cached_state
{
   struct
   {
      GLuint *ids;
   } bind_textures;

#ifndef HAVE_OPENGLES
   GLenum colorlogicop;
#endif

   struct
   {
      bool enabled[MAX_ATTRIB];
   } vertex_attrib_pointer;

   struct
   {
      GLenum pname;
      GLint param;
   } pixelstore_i;

   struct
   {
      GLuint r;
      GLuint g;
      GLuint b;
      GLuint a;
   } clear_color;

   struct
   {
      bool used;
      GLint x;
      GLint y;
      GLsizei w;
      GLsizei h;
   } scissor;

   struct
   {
      GLint x;
      GLint y;
      GLsizei w;
      GLsizei h;
   } viewport;

   struct
   {
      bool used;
      GLenum sfactor;
      GLenum dfactor;
   } blendfunc;

   struct
   {
      bool used;
      GLenum srcRGB;
      GLenum dstRGB;
      GLenum srcAlpha;
      GLenum dstAlpha;
   } blendfunc_separate;

   struct
   {
      bool used;
      GLboolean red;
      GLboolean green;
      GLboolean blue;
      GLboolean alpha;
   } colormask;

   struct
   {
      bool used;
      GLdouble depth;
   } cleardepth;

   struct
   {
      bool used;
      GLenum func;
   } depthfunc;


   struct
   {
      bool used;
      GLclampd zNear;
      GLclampd zFar;
   } depthrange;

   struct
   {
      bool used;
      GLfloat factor;
      GLfloat units;
   } polygonoffset;

   struct
   {
      bool used;
      GLenum func;
      GLint ref;
      GLuint mask;
   } stencilfunc;

   struct
   {
      bool used;
      GLenum sfail;
      GLenum dpfail;
      GLenum dppass;
   } stencilop;

   struct
   {
      bool used;
      GLenum mode;
   } frontface;

   struct 
   {
      bool used;
      GLenum mode;
   } cullface;

   struct
   {
      bool used;
      GLuint mask;
   } stencilmask;

   struct
   {
      bool used;
      GLboolean mask;
   } depthmask;

   struct
   {
      GLenum mode;
   } readbuffer;

   GLuint vao;
   GLuint framebuf;
   GLuint program; 
   GLenum active_texture;
   int cap_state[SGL_CAP_MAX];
   int cap_translate[SGL_CAP_MAX];
};

static GLint glsm_max_textures;
static struct retro_hw_render_callback hw_render;
static struct gl_cached_state gl_state;

/* GL wrapper-side */

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
GLenum rglGetError(void)
{
   return glGetError();
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglClear(GLbitfield mask)
{
   glClear(mask);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0
 */
void rglValidateProgram(GLuint program)
{
   glValidateProgram(program);
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 * OpenGLES  : N/A
 */
void rglPolygonMode(GLenum face, GLenum mode)
{
#ifndef HAVE_OPENGLES
   glPolygonMode(face, mode);
#endif
}

void rglTexSubImage2D(
      GLenum target,
  	GLint level,
  	GLint xoffset,
  	GLint yoffset,
  	GLsizei width,
  	GLsizei height,
  	GLenum format,
  	GLenum type,
  	const GLvoid * pixels)
{
   glTexSubImage2D(target, level, xoffset, yoffset,
         width, height, format, type, pixels);
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglLineWidth(GLfloat width)
{
   glLineWidth(width);
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0
 * OpenGLES  : 3.0
 */
void rglBlitFramebuffer(
      GLint srcX0, GLint srcY0,
      GLint srcX1, GLint srcY1,
      GLint dstX0, GLint dstY0,
      GLint dstX1, GLint dstY1,
      GLbitfield mask, GLenum filter)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glBlitFramebuffer(srcX0, srcY0, srcX1, srcY1,
         dstX0, dstY0, dstX1, dstY1,
         mask, filter);
#endif
}

/*
 *
 * Core in:
 * OpenGLES  : 3.0
 */
void rglReadBuffer(GLenum mode)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glReadBuffer(mode);
   gl_state.readbuffer.mode = mode;
#endif
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglClearDepth(GLdouble depth)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
#ifdef HAVE_OPENGLES
   glClearDepthf(depth);
#else
   glClearDepth(depth);
#endif
   gl_state.cleardepth.used  = true;
   gl_state.cleardepth.depth = depth;
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglPixelStorei(GLenum pname, GLint param)
{
   glPixelStorei(pname, param);
   gl_state.pixelstore_i.pname = pname;
   gl_state.pixelstore_i.param = param;
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglDepthRange(GLclampd zNear, GLclampd zFar)
{
#ifdef HAVE_OPENGLES
   glDepthRangef(zNear, zFar);
#else
   glDepthRange(zNear, zFar);
#endif
   gl_state.depthrange.used  = true;
   gl_state.depthrange.zNear = zNear;
   gl_state.depthrange.zFar  = zFar;
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglFrontFace(GLenum mode)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glFrontFace(mode);
   gl_state.frontface.used = true;
   gl_state.frontface.mode = mode; 
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglDepthFunc(GLenum func)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   gl_state.depthfunc.used = true;
   gl_state.depthfunc.func = func;
   glDepthFunc(func);
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglColorMask(GLboolean red, GLboolean green,
      GLboolean blue, GLboolean alpha)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glColorMask(red, green, blue, alpha);
   gl_state.colormask.red   = red;
   gl_state.colormask.green = green;
   gl_state.colormask.blue  = blue;
   gl_state.colormask.alpha = alpha;
   gl_state.colormask.used  = true;
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglCullFace(GLenum mode)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glCullFace(mode);
   gl_state.cullface.used = true;
   gl_state.cullface.mode = mode;
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglStencilOp(GLenum sfail, GLenum dpfail, GLenum dppass)
{
   glStencilOp(sfail, dpfail, dppass);
   gl_state.stencilop.used   = true;
   gl_state.stencilop.sfail  = sfail;
   gl_state.stencilop.dpfail = dpfail;
   gl_state.stencilop.dppass = dppass;
}

/*
 *
 * Core in:
 * OpenGLES  : 2.0
 */
void rglStencilFunc(GLenum func, GLint ref, GLuint mask)
{
   glStencilFunc(func, ref, mask);
   gl_state.stencilfunc.used = true;
   gl_state.stencilfunc.func = func;
   gl_state.stencilfunc.ref  = ref;
   gl_state.stencilfunc.mask = mask;
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
GLboolean rglIsEnabled(GLenum cap)
{
   return gl_state.cap_state[cap] ? GL_TRUE : GL_FALSE;
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglClearColor(GLclampf red, GLclampf green,
      GLclampf blue, GLclampf alpha)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glClearColor(red, green, blue, alpha);
   gl_state.clear_color.r = red;
   gl_state.clear_color.g = green;
   gl_state.clear_color.b = blue;
   gl_state.clear_color.a = alpha;
}

/*
 *
 * Core in:
 * OpenGLES    : 2.0 (maybe earlier?)
 */
void rglScissor(GLint x, GLint y, GLsizei width, GLsizei height)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glScissor(x, y, width, height);
   gl_state.scissor.used = true;
   gl_state.scissor.x    = x;
   gl_state.scissor.y    = y;
   gl_state.scissor.w    = width;
   gl_state.scissor.h    = height;
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglViewport(GLint x, GLint y, GLsizei width, GLsizei height)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glViewport(x, y, width, height);
   gl_state.viewport.x = x;
   gl_state.viewport.y = y;
   gl_state.viewport.w = width;
   gl_state.viewport.h = height;
}

void rglBlendFunc(GLenum sfactor, GLenum dfactor)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   gl_state.blendfunc.used    = true;
   gl_state.blendfunc.sfactor = sfactor;
   gl_state.blendfunc.dfactor = dfactor;
   glBlendFunc(sfactor, dfactor);
}

/*
 * Category: Blending
 *
 * Core in:
 * OpenGL    : 1.4
 */
void rglBlendFuncSeparate(GLenum sfactor, GLenum dfactor)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   gl_state.blendfunc_separate.used     = true;
   gl_state.blendfunc_separate.srcRGB   = sfactor;
   gl_state.blendfunc_separate.dstRGB   = dfactor;
   gl_state.blendfunc_separate.srcAlpha = sfactor;
   gl_state.blendfunc_separate.dstAlpha = dfactor;
   glBlendFunc(sfactor, dfactor);
}

/*
 * Category: Textures
 *
 * Core in:
 * OpenGL    : 1.3 
 */
void rglActiveTexture(GLenum texture)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glActiveTexture(texture);
   gl_state.active_texture = texture - GL_TEXTURE0;
}

/*
 *
 * Core in:
 * OpenGL    : 1.1
 */
void rglBindTexture(GLenum target, GLuint texture)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glBindTexture(target, texture);
   gl_state.bind_textures.ids[gl_state.active_texture] = texture;
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglDisable(GLenum cap)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glDisable(gl_state.cap_translate[cap]);
   gl_state.cap_state[cap] = 0;
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglEnable(GLenum cap)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glEnable(gl_state.cap_translate[cap]);
   gl_state.cap_state[cap] = 1;
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUseProgram(GLuint program)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   gl_state.program = program;
   glUseProgram(program);
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglDepthMask(GLboolean flag)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glDepthMask(flag);
   gl_state.depthmask.used = true;
   gl_state.depthmask.mask = flag;
}

/*
 *
 * Core in:
 * OpenGL    : 1.0
 */
void rglStencilMask(GLenum mask)
{
   glStencilMask(mask);
   gl_state.stencilmask.used = true;
   gl_state.stencilmask.mask = mask;
}

/*
 *
 * Core in:
 * OpenGL    : 1.5
 */
void rglBufferData(GLenum target, GLsizeiptr size,
      const GLvoid *data, GLenum usage)
{
   glBufferData(target, size, data, usage);
}

/*
 *
 * Core in:
 * OpenGL    : 1.5
 */
void rglBufferSubData(GLenum target, GLintptr offset,
      GLsizeiptr size, const GLvoid *data)
{
   glBufferSubData(target, offset, size, data);
}

/*
 *
 * Core in:
 * OpenGL    : 1.5
 */
void rglBindBuffer(GLenum target, GLuint buffer)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glBindBuffer(target, buffer);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0
 */
void rglLinkProgram(GLuint program)
{
   glLinkProgram(program);
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0 
 * OpenGLES  : 2.0
 */
void rglFramebufferTexture2D(GLenum target, GLenum attachment,
      GLenum textarget, GLuint texture, GLint level)
{
   glFramebufferTexture2D(target, attachment, textarget, texture, level);
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0
 * OpenGLES  : 3.2
 */
void rglFramebufferTexture(GLenum target, GLenum attachment,
  	GLuint texture, GLint level)
{
#if defined(HAVE_OPENGL) || (defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3_2))
   glFramebufferTexture(target, attachment, texture, level);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 1.1
 */
void rglDrawArrays(GLenum mode, GLint first, GLsizei count)
{
   glDrawArrays(mode, first, count);
}

/*
 *
 * Core in:
 * OpenGL    : 1.1
 */
void rglDrawElements(GLenum mode, GLsizei count, GLenum type,
                           const GLvoid * indices)
{
   glDrawElements(mode, count, type, indices);
}

void rglCompressedTexImage2D(GLenum target, GLint level,
      GLenum internalformat, GLsizei width, GLsizei height,
      GLint border, GLsizei imageSize, const GLvoid *data)
{
   glCompressedTexImage2D(target, level, internalformat, 
         width, height, border, imageSize, data);
}


void rglDeleteFramebuffers(GLsizei n, const GLuint *framebuffers)
{
   glDeleteFramebuffers(n, framebuffers);
}

void rglDeleteTextures(GLsizei n, const GLuint *textures)
{
   glDeleteTextures(n, textures);
}

/*
 *
 * Core in:
 * OpenGLES    : 2.0 
 */
void rglRenderbufferStorage(GLenum target, GLenum internalFormat,
      GLsizei width, GLsizei height)
{
   glRenderbufferStorage(target, internalFormat, width, height);
}

/*
 *
 * Core in:
 *
 * OpenGL      : 3.0
 * OpenGLES    : 2.0 
 */
void rglBindRenderbuffer(GLenum target, GLuint renderbuffer)
{
   glBindRenderbuffer(target, renderbuffer);
}

/*
 *
 * Core in:
 *
 * OpenGLES    : 2.0 
 */
void rglDeleteRenderbuffers(GLsizei n, GLuint *renderbuffers)
{
   glDeleteRenderbuffers(n, renderbuffers);
}

/*
 *
 * Core in:
 *
 * OpenGL      : 3.0
 * OpenGLES    : 2.0 
 */
void rglGenRenderbuffers(GLsizei n, GLuint *renderbuffers)
{
   glGenRenderbuffers(n, renderbuffers);
}

/*
 *
 * Core in:
 *
 * OpenGL      : 3.0
 * OpenGLES    : 2.0 
 */
void rglGenerateMipmap(GLenum target)
{
   glGenerateMipmap(target);
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0 
 */
GLenum rglCheckFramebufferStatus(GLenum target)
{
   return glCheckFramebufferStatus(target);
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0 
 * OpenGLES  : 2.0
 */
void rglFramebufferRenderbuffer(GLenum target, GLenum attachment,
      GLenum renderbuffertarget, GLuint renderbuffer)
{
   glFramebufferRenderbuffer(target, attachment, renderbuffertarget, renderbuffer);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 3.0 
 */
void rglBindFragDataLocation(GLuint program, GLuint colorNumber,
                                   const char * name)
{
#if !defined(HAVE_OPENGLES2)
   glBindFragDataLocation(program, colorNumber, name);
#endif
}


/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglGetProgramiv(GLuint shader, GLenum pname, GLint *params)
{
   glGetProgramiv(shader, pname, params);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 4.1 
 * OpenGLES  : 3.0
 */
void rglProgramParameteri( 	GLuint program,
  	GLenum pname,
  	GLint value)
{
#if !defined(HAVE_OPENGLES) || defined(HAVE_OPENGLES) && (defined(HAVE_OPENGLES3) || defined(HAVE_OPENGLES_3_1))
   glProgramParameteri(program, pname, value);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglGetActiveUniform(GLuint program, GLuint index, GLsizei bufsize,
      GLsizei *length, GLint *size, GLenum *type, GLchar *name)
{
   glGetActiveUniform(program, index, bufsize, length, size, type, name);
}

/*
 * Category: UBO
 *
 * Core in:
 *
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void rglGetActiveUniformBlockiv(GLuint program,
  	GLuint uniformBlockIndex,
  	GLenum pname,
  	GLint *params)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glGetActiveUniformBlockiv(program, uniformBlockIndex,
         pname, params);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 *
 * OpenGLES  : 3.0
 */
void rglGetActiveUniformsiv( 	GLuint program,
  	GLsizei uniformCount,
  	const GLuint *uniformIndices,
  	GLenum pname,
  	GLint *params)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glGetActiveUniformsiv(program, uniformCount,
         uniformIndices, pname, params);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 *
 * OpenGLES  : 3.0
 */
void rglGetUniformIndices(GLuint program,
  	GLsizei uniformCount,
  	const GLchar **uniformNames,
  	GLuint *uniformIndices)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glGetUniformIndices(program, uniformCount,
         uniformNames, uniformIndices);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 * Category: UBO
 *
 * Core in:
 *
 * OpenGLES  : 3.0
 */
void rglBindBufferBase( 	GLenum target,
  	GLuint index,
  	GLuint buffer)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glBindBufferBase(target, index, buffer);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Category: UBO
 *
 * Core in:
 *
 * OpenGLES  : 3.0
 */
GLuint rglGetUniformBlockIndex( 	GLuint program,
  	const GLchar *uniformBlockName)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   return glGetUniformBlockIndex(program, uniformBlockName);
#else
   printf("WARNING! Not implemented.\n");
   return 0;
#endif
}

/*
 * Category: UBO
 *
 * Core in:
 *
 * OpenGLES  : 3.0
 */
void rglUniformBlockBinding( 	GLuint program,
  	GLuint uniformBlockIndex,
  	GLuint uniformBlockBinding)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glUniformBlockBinding(program, uniformBlockIndex,
         uniformBlockBinding);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void rglUniform1ui(GLint location, GLuint v)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glUniform1ui(location ,v);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void rglUniform2ui(GLint location, GLuint v0, GLuint v1)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glUniform2ui(location, v0, v1);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void rglUniform3ui(GLint location, GLuint v0, GLuint v1, GLuint v2)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glUniform3ui(location, v0, v1, v2);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void rglUniform4ui(GLint location, GLuint v0, GLuint v1, GLuint v2, GLuint v3)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glUniform4ui(location, v0, v1, v2, v3);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniformMatrix4fv(GLint location, GLsizei count, GLboolean transpose,
      const GLfloat *value)
{
   glUniformMatrix4fv(location, count, transpose, value);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglDetachShader(GLuint program, GLuint shader)
{
   glDetachShader(program, shader);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglGetShaderiv(GLuint shader, GLenum pname, GLint *params)
{
   glGetShaderiv(shader, pname, params);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglAttachShader(GLuint program, GLuint shader)
{
   glAttachShader(program, shader);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
GLint rglGetAttribLocation(GLuint program, const GLchar *name)
{
   return glGetAttribLocation(program, name);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglShaderSource(GLuint shader, GLsizei count,
      const GLchar **string, const GLint *length)
{
   return glShaderSource(shader, count, string, length);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglCompileShader(GLuint shader)
{
   glCompileShader(shader);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
GLuint rglCreateProgram(void)
{
   return glCreateProgram();
}

/*
 *
 * Core in:
 * OpenGL    : 1.1 
 */
void rglGenTextures(GLsizei n, GLuint *textures)
{
   glGenTextures(n, textures);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglGetShaderInfoLog(GLuint shader, GLsizei maxLength,
      GLsizei *length, GLchar *infoLog)
{
   glGetShaderInfoLog(shader, maxLength, length, infoLog);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglGetProgramInfoLog(GLuint shader, GLsizei maxLength,
      GLsizei *length, GLchar *infoLog)
{
   glGetProgramInfoLog(shader, maxLength, length, infoLog);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
GLboolean rglIsProgram(GLuint program)
{
   return glIsProgram(program);
}


void rglTexCoord2f(GLfloat s, GLfloat t)
{
#ifdef HAVE_LEGACY_GL
   glTexCoord2f(s, t);
#endif
}

/*
 * Category: Generic vertex attributes
 *
 * Core in:
 * OpenGL    : 2.0 
 *
 */
void rglDisableVertexAttribArray(GLuint index)
{
   gl_state.vertex_attrib_pointer.enabled[index] = 0;
   glDisableVertexAttribArray(index);
}

/*
 * Category: Generic vertex attributes
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglEnableVertexAttribArray(GLuint index)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   gl_state.vertex_attrib_pointer.enabled[index] = 1;
   glEnableVertexAttribArray(index);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglVertexAttribIPointer(
      GLuint index,
      GLint size,
      GLenum type,
      GLsizei stride,
      const GLvoid * pointer)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glVertexAttribIPointer(index, size, type, stride, pointer);
#endif
}

void rglVertexAttribLPointer(
      GLuint index,
      GLint size,
      GLenum type,
      GLsizei stride,
      const GLvoid * pointer)
{
#if defined(HAVE_OPENGL)
   glVertexAttribLPointer(index, size, type, stride, pointer);
#endif
}

/*
 * Category: Generic vertex attributes
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglVertexAttribPointer(GLuint name, GLint size,
      GLenum type, GLboolean normalized, GLsizei stride,
      const GLvoid* pointer)
{
   glVertexAttribPointer(name, size, type, normalized, stride, pointer);
}

/*
 * Category: Generic vertex attributes
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglBindAttribLocation(GLuint program, GLuint index, const GLchar *name)
{
   glBindAttribLocation(program, index, name);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglVertexAttrib4f(GLuint name, GLfloat x, GLfloat y,
      GLfloat z, GLfloat w)
{
    glVertexAttrib4f(name, x, y, z, w);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglVertexAttrib4fv(GLuint name, GLfloat* v)
{
    glVertexAttrib4fv(name, v);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
GLuint rglCreateShader(GLenum shaderType)
{
   return glCreateShader(shaderType);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglDeleteProgram(GLuint program)
{
   glDeleteProgram(program);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglDeleteShader(GLuint shader)
{
   glDeleteShader(shader);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
GLint rglGetUniformLocation(GLuint program, const GLchar *name)
{
   return glGetUniformLocation(program, name);
}

/*
 * Category: VBO and PBO
 *
 * Core in:
 * OpenGL    : 1.5 
 */
void rglDeleteBuffers(GLsizei n, const GLuint *buffers)
{
   glDeleteBuffers(n, buffers);
}

/*
 * Category: VBO and PBO
 *
 * Core in:
 * OpenGL    : 1.5 
 */
void rglGenBuffers(GLsizei n, GLuint *buffers)
{
   glGenBuffers(n, buffers);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform1f(GLint location, GLfloat v0)
{
   glUniform1f(location, v0);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform1fv(GLint location,  GLsizei count,  const GLfloat *value)
{
   glUniform1fv(location, count, value);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform1iv(GLint location,  GLsizei count,  const GLint *value)
{
   glUniform1iv(location, count, value);
}

void rglClearBufferfv( 	GLenum buffer,
  	GLint drawBuffer,
  	const GLfloat * value)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3)
   glClearBufferfv(buffer, drawBuffer, value);
#endif
}

void rglTexBuffer(GLenum target, GLenum internalFormat, GLuint buffer)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3_2)
   glTexBuffer(target, internalFormat, buffer);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
const GLubyte* rglGetStringi(GLenum name, GLuint index)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3)
   return glGetStringi(name, index);
#else
   return NULL;
#endif
}

void rglClearBufferfi( 	GLenum buffer,
  	GLint drawBuffer,
  	GLfloat depth,
  	GLint stencil)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3)
   glClearBufferfi(buffer, drawBuffer, depth, stencil);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 3.0 
 * OpenGLES  : 3.0
 */
void rglRenderbufferStorageMultisample( 	GLenum target,
  	GLsizei samples,
  	GLenum internalformat,
  	GLsizei width,
  	GLsizei height)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3)
   glRenderbufferStorageMultisample(target, samples, internalformat, width, height);
#endif
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform1i(GLint location, GLint v0)
{
   glUniform1i(location, v0);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform2f(GLint location, GLfloat v0, GLfloat v1)
{
   glUniform2f(location, v0, v1);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform2i(GLint location, GLint v0, GLint v1)
{
   glUniform2i(location, v0, v1);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform2fv(GLint location, GLsizei count, const GLfloat *value)
{
   glUniform2fv(location, count, value);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform3f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2)
{
   glUniform3f(location, v0, v1, v2);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform3fv(GLint location, GLsizei count, const GLfloat *value)
{
   glUniform3fv(location, count, value);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0
 */
void rglUniform4i(GLint location, GLint v0, GLint v1, GLint v2, GLint v3)
{
   glUniform4i(location, v0, v1, v2, v3);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform4f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3)
{
   glUniform4f(location, v0, v1, v2, v3);
}

/*
 * Category: Shaders
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglUniform4fv(GLint location, GLsizei count, const GLfloat *value)
{
   glUniform4fv(location, count, value);
}


/*
 *
 * Core in:
 * OpenGL    : 1.0 
 */
void rglPolygonOffset(GLfloat factor, GLfloat units)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glPolygonOffset(factor, units);
   gl_state.polygonoffset.used   = true;
   gl_state.polygonoffset.factor = factor;
   gl_state.polygonoffset.units  = units;
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0 
 */
void rglGenFramebuffers(GLsizei n, GLuint *ids)
{
   glGenFramebuffers(n, ids);
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 3.0 
 */
void rglBindFramebuffer(GLenum target, GLuint framebuffer)
{
   glsm_ctl(GLSM_CTL_IMM_VBO_DRAW, NULL);
   glBindFramebuffer(target, framebuffer);
   gl_state.framebuf = framebuffer;
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void rglDrawBuffers(GLsizei n, const GLenum *bufs)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glDrawBuffers(n, bufs);
#endif
}

/*
 * Category: FBO
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.0
 */
void *rglMapBufferRange( 	GLenum target,
  	GLintptr offset,
  	GLsizeiptr length,
  	GLbitfield access)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   return glMapBufferRange(target, offset, length, access);
#else
   printf("WARNING! Not implemented.\n");
   return NULL;
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 4.3
 * OpenGLES  : 3.1
 */
void rglTexStorage2DMultisample(GLenum target, GLsizei samples,
      GLenum internalformat, GLsizei width, GLsizei height,
      GLboolean fixedsamplelocations)
{
#if defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3_1)
   glTexStorage2DMultisample(target, samples, internalformat,
         width, height, fixedsamplelocations);
#endif
}

/*
 *
 * Core in:
 * OpenGLES  : 3.0
 */
void rglTexStorage2D(GLenum target, GLsizei levels, GLenum internalFormat,
      GLsizei width, GLsizei height)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glTexStorage2D(target, levels, internalFormat, width, height);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 4.2 
 * OpenGLES  : 3.1
 */
void rglMemoryBarrier( 	GLbitfield barriers)
{
#if !defined(HAVE_OPENGLES) || defined(HAVE_OPENGLES3) && defined(HAVE_OPENGLES_3_1)
   glMemoryBarrier(barriers);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 4.2 
 * OpenGLES  : 3.1
 */
void rglBindImageTexture( 	GLuint unit,
  	GLuint texture,
  	GLint level,
  	GLboolean layered,
  	GLint layer,
  	GLenum access,
  	GLenum format)
{
#if !defined(HAVE_OPENGLES) || defined(HAVE_OPENGLES3) && defined(HAVE_OPENGLES_3_1)
   glBindImageTexture(unit, texture, level, layered, layer, access, format);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 4.1
 * OpenGLES  : 3.1
 */
void rglGetProgramBinary( 	GLuint program,
  	GLsizei bufsize,
  	GLsizei *length,
  	GLenum *binaryFormat,
  	void *binary)
{
#if !defined(HAVE_OPENGLES) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glGetProgramBinary(program, bufsize, length, binaryFormat, binary);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 4.1
 * OpenGLES  : 3.1
 */
void rglProgramBinary(GLuint program,
  	GLenum binaryFormat,
  	const void *binary,
  	GLsizei length)
{
#if !defined(HAVE_OPENGLES) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3_1)
   glProgramBinary(program, binaryFormat, binary, length);
#else
   printf("WARNING! Not implemented.\n");
#endif
}

void rglTexImage2DMultisample( 	GLenum target,
  	GLsizei samples,
  	GLenum internalformat,
  	GLsizei width,
  	GLsizei height,
  	GLboolean fixedsamplelocations)
{
#ifndef HAVE_OPENGLES
   glTexImage2DMultisample(target, samples, internalformat, width, height, fixedsamplelocations);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 1.5 
 */
void * rglMapBuffer(	GLenum target, GLenum access)
{
#if defined(HAVE_OPENGLES)
   return glMapBufferOES(target, access);
#else
   return glMapBuffer(target, access);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 1.5 
 */
GLboolean rglUnmapBuffer( 	GLenum target)
{
#if defined(HAVE_OPENGLES)
   return glUnmapBufferOES(target);
#else
   return glUnmapBuffer(target);
#endif
}

void rglBlendEquation(GLenum mode)
{
   glBlendEquation(mode);
}

void rglBlendColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
   glBlendColor(red, green, blue, alpha);
}

/*
 * Category: Blending
 *
 * Core in:
 * OpenGL    : 2.0 
 */
void rglBlendEquationSeparate(GLenum modeRGB, GLenum modeAlpha)
{
   glBlendEquationSeparate(modeRGB, modeAlpha);
}

/*
 *
 * Core in:
 * OpenGL    : 2.0 
 * OpenGLES  : 3.2
 */
void rglCopyImageSubData( 	GLuint srcName,
  	GLenum srcTarget,
  	GLint srcLevel,
  	GLint srcX,
  	GLint srcY,
  	GLint srcZ,
  	GLuint dstName,
  	GLenum dstTarget,
  	GLint dstLevel,
  	GLint dstX,
  	GLint dstY,
  	GLint dstZ,
  	GLsizei srcWidth,
  	GLsizei srcHeight,
  	GLsizei srcDepth)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES_3_2)
   glCopyImageSubData(srcName,
         srcTarget,
         srcLevel,
         srcX,
         srcY,
         srcZ,
         dstName,
         dstTarget,
         dstLevel,
         dstX,
         dstY,
         dstZ,
         srcWidth,
         srcHeight,
         srcDepth);
#endif
}

/*
 * Category: VAO
 *
 * Core in:
 * OpenGL    : 3.0 
 * OpenGLES  : 3.0
 */
void rglBindVertexArray(GLuint array)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glBindVertexArray(array);
#endif
}

/*
 * Category: VAO
 *
 * Core in:
 * OpenGL    : 3.0 
 * OpenGLES  : 3.0
 */
void rglGenVertexArrays(GLsizei n, GLuint *arrays)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glGenVertexArrays(n, arrays);
#endif
}

/*
 * Category: VAO
 *
 * Core in:
 * OpenGL    : 3.0 
 * OpenGLES  : 3.0
 */
void rglDeleteVertexArrays(GLsizei n, const GLuint *arrays)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glDeleteVertexArrays(n, arrays);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 3.2
 * OpenGLES  : 3.0
 */
void *rglFenceSync(GLenum condition, GLbitfield flags)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   return (GLsync)glFenceSync(condition, flags);
#endif
}

/*
 *
 * Core in:
 * OpenGL    : 3.2
 * OpenGLES  : 3.0
 */
void rglWaitSync(void *sync, GLbitfield flags, uint64_t timeout)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) && defined(HAVE_OPENGLES3)
   glWaitSync((GLsync)sync, flags, (GLuint64)timeout);
#endif
}

/* GLSM-side */

static void glsm_state_setup(void)
{
   unsigned i;

   gl_state.cap_translate[SGL_DEPTH_TEST]           = GL_DEPTH_TEST;
   gl_state.cap_translate[SGL_BLEND]                = GL_BLEND;
   gl_state.cap_translate[SGL_POLYGON_OFFSET_FILL]  = GL_POLYGON_OFFSET_FILL;
   gl_state.cap_translate[SGL_FOG]                  = GL_FOG;
   gl_state.cap_translate[SGL_CULL_FACE]            = GL_CULL_FACE;
   gl_state.cap_translate[SGL_ALPHA_TEST]           = GL_ALPHA_TEST;
   gl_state.cap_translate[SGL_SCISSOR_TEST]         = GL_SCISSOR_TEST;
   gl_state.cap_translate[SGL_STENCIL_TEST]         = GL_STENCIL_TEST;

#ifndef HAVE_OPENGLES
   gl_state.cap_translate[SGL_COLOR_LOGIC_OP]       = GL_COLOR_LOGIC_OP;
   gl_state.cap_translate[SGL_CLIP_DISTANCE0]       = GL_CLIP_DISTANCE0;
   gl_state.cap_translate[SGL_DEPTH_CLAMP]          = GL_DEPTH_CLAMP;
#endif

   for (i = 0; i < MAX_ATTRIB; i++)
      gl_state.vertex_attrib_pointer.enabled[i] = 0;

   glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &glsm_max_textures);

   gl_state.bind_textures.ids           = (GLuint*)calloc(glsm_max_textures, sizeof(GLuint));

   gl_state.framebuf                    = hw_render.get_current_framebuffer();
   gl_state.cullface.mode               = GL_BACK;
   gl_state.frontface.mode              = GL_CCW; 

   gl_state.blendfunc_separate.used     = false;
   gl_state.blendfunc_separate.srcRGB   = GL_ONE;
   gl_state.blendfunc_separate.dstRGB   = GL_ZERO;
   gl_state.blendfunc_separate.srcAlpha = GL_ONE;
   gl_state.blendfunc_separate.dstAlpha = GL_ZERO;

   gl_state.depthfunc.used              = false;
   
   gl_state.colormask.used              = false;
   gl_state.colormask.red               = GL_TRUE;
   gl_state.colormask.green             = GL_TRUE;
   gl_state.colormask.blue              = GL_TRUE;
   gl_state.colormask.alpha             = GL_TRUE;

   gl_state.polygonoffset.used          = false;

   gl_state.depthfunc.func              = GL_LESS;

#ifndef HAVE_OPENGLES
   gl_state.colorlogicop                = GL_COPY;
#endif

#ifdef CORE
   glGenVertexArrays(1, &gl_state.vao);
#endif
}

static void glsm_state_bind(void)
{
   unsigned i;

   for (i = 0; i < MAX_ATTRIB; i++)
   {
      if (gl_state.vertex_attrib_pointer.enabled[i])
         glEnableVertexAttribArray(i);
      else
         glDisableVertexAttribArray(i);
   }

   glBindFramebuffer(RARCH_GL_FRAMEBUFFER, hw_render.get_current_framebuffer());

   if (gl_state.blendfunc.used)
      glBlendFunc(
            gl_state.blendfunc.sfactor,
            gl_state.blendfunc.dfactor);

   if (gl_state.blendfunc_separate.used)
      glBlendFuncSeparate(
            gl_state.blendfunc_separate.srcRGB,
            gl_state.blendfunc_separate.dstRGB,
            gl_state.blendfunc_separate.srcAlpha,
            gl_state.blendfunc_separate.dstAlpha
            );

   glClearColor(
         gl_state.clear_color.r,
         gl_state.clear_color.g,
         gl_state.clear_color.b,
         gl_state.clear_color.a);

   if (gl_state.depthfunc.used)
      glDepthFunc(gl_state.depthfunc.func);

   if (gl_state.colormask.used)
      glColorMask(
            gl_state.colormask.red,
            gl_state.colormask.green,
            gl_state.colormask.blue,
            gl_state.colormask.alpha);

   if (gl_state.cullface.used)
      glCullFace(gl_state.cullface.mode);

   if (gl_state.depthmask.used)
      glDepthMask(gl_state.depthmask.mask);

   if (gl_state.polygonoffset.used)
      glPolygonOffset(
            gl_state.polygonoffset.factor,
            gl_state.polygonoffset.units);

   if (gl_state.scissor.used)
      glScissor(
            gl_state.scissor.x,
            gl_state.scissor.y,
            gl_state.scissor.w,
            gl_state.scissor.h);

   glUseProgram(gl_state.program);

   glViewport(
         gl_state.viewport.x,
         gl_state.viewport.y,
         gl_state.viewport.w,
         gl_state.viewport.h);
#ifdef CORE
   glBindVertexArray(gl_state.vao);
#endif
   for(i = 0; i < SGL_CAP_MAX; i ++)
   {
      if (gl_state.cap_state[i])
         glEnable(gl_state.cap_translate[i]);
   }

   if (gl_state.frontface.used)
      glFrontFace(gl_state.frontface.mode);

   if (gl_state.stencilmask.used)
      glStencilMask(gl_state.stencilmask.mask);

   if (gl_state.stencilop.used)
      glStencilOp(gl_state.stencilop.sfail,
            gl_state.stencilop.dpfail,
            gl_state.stencilop.dppass);

   if (gl_state.stencilfunc.used)
      glStencilFunc(
            gl_state.stencilfunc.func,
            gl_state.stencilfunc.ref,
            gl_state.stencilfunc.mask);

   for (i = 0; i < glsm_max_textures; i ++)
   {
      glActiveTexture(GL_TEXTURE0 + i);
      glBindTexture(GL_TEXTURE_2D, gl_state.bind_textures.ids[i]);
   }

   glActiveTexture(GL_TEXTURE0 + gl_state.active_texture);

   glBindBuffer(GL_ARRAY_BUFFER, 0);
}

static void glsm_state_unbind(void)
{
   unsigned i;
#ifdef CORE
   glBindVertexArray(0);
#endif
   for (i = 0; i < SGL_CAP_MAX; i ++)
   {
      if (gl_state.cap_state[i])
         glDisable(gl_state.cap_translate[i]);
   }

   glBlendFunc(GL_ONE, GL_ZERO);

   if (gl_state.colormask.used)
      glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
   if (gl_state.blendfunc_separate.used)
      glBlendFuncSeparate(GL_ONE, GL_ZERO, GL_ONE, GL_ZERO);

   if (gl_state.cullface.used)
      glCullFace(GL_BACK);

   if (gl_state.depthmask.used)
      glDepthMask(GL_TRUE);

   if (gl_state.polygonoffset.used)
      glPolygonOffset(0, 0);

   glUseProgram(0);
   glClearColor(0,0,0,0.0f);

   if (gl_state.depthrange.used)
      rglDepthRange(0, 1);

   glStencilMask(1);
   glFrontFace(GL_CCW);
   if (gl_state.depthfunc.used)
      glDepthFunc(GL_LESS);

   if (gl_state.stencilop.used)
      glStencilOp(GL_KEEP,GL_KEEP, GL_KEEP);

   if (gl_state.stencilfunc.used)
      glStencilFunc(GL_ALWAYS,0,1);

   /* Clear textures */
   for (i = 0; i < glsm_max_textures; i ++)
   {
      glActiveTexture(GL_TEXTURE0 + i);
      glBindTexture(GL_TEXTURE_2D, 0);
   }
   glActiveTexture(GL_TEXTURE0);

   for (i = 0; i < MAX_ATTRIB; i ++)
      glDisableVertexAttribArray(i);

   glBindFramebuffer(RARCH_GL_FRAMEBUFFER, 0);
}

static bool glsm_state_ctx_destroy(void *data)
{
   if (gl_state.bind_textures.ids)
      free(gl_state.bind_textures.ids);
   gl_state.bind_textures.ids = NULL;
}

static bool glsm_state_ctx_init(void *data)
{
   glsm_ctx_params_t *params = (glsm_ctx_params_t*)data;

   if (!params || !params->environ_cb)
      return false;

#ifdef HAVE_OPENGLES
#if defined(HAVE_OPENGLES_3_1)
   hw_render.context_type       = RETRO_HW_CONTEXT_OPENGLES_VERSION;
   hw_render.version_major      = 3;
   hw_render.version_minor      = 1;
#elif defined(HAVE_OPENGLES3)
   hw_render.context_type       = RETRO_HW_CONTEXT_OPENGLES3;
#else
   hw_render.context_type       = RETRO_HW_CONTEXT_OPENGLES2;
#endif
#else
#ifdef CORE
   hw_render.context_type       = RETRO_HW_CONTEXT_OPENGL_CORE;
   hw_render.version_major      = 3;
   hw_render.version_minor      = 1;
#else
   hw_render.context_type       = RETRO_HW_CONTEXT_OPENGL;
#endif
#endif
   hw_render.context_reset      = params->context_reset;
   hw_render.context_destroy    = params->context_destroy;
   hw_render.stencil            = params->stencil;
   hw_render.depth              = true;
   hw_render.bottom_left_origin = true;
   hw_render.cache_context      = true;

   if (!params->environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render))
      return false;

   return true;
}

GLuint glsm_get_current_framebuffer(void)
{
   return hw_render.get_current_framebuffer();
}

bool glsm_ctl(enum glsm_state_ctl state, void *data)
{
   switch (state)
   {
      case GLSM_CTL_IMM_VBO_DRAW:
         return false;
      case GLSM_CTL_IMM_VBO_DISABLE:
         return false;
      case GLSM_CTL_IS_IMM_VBO:
         return false;
      case GLSM_CTL_SET_IMM_VBO:
         break;
      case GLSM_CTL_UNSET_IMM_VBO:
         break;
      case GLSM_CTL_PROC_ADDRESS_GET:
         {
            glsm_ctx_proc_address_t *proc = (glsm_ctx_proc_address_t*)data;
            if (!hw_render.get_proc_address)
               return false;
            proc->addr = hw_render.get_proc_address;
         }
         break;
      case GLSM_CTL_STATE_CONTEXT_RESET:
         rglgen_resolve_symbols(hw_render.get_proc_address);
         break;
      case GLSM_CTL_STATE_CONTEXT_DESTROY:
         glsm_state_ctx_destroy(data);
         break;
      case GLSM_CTL_STATE_CONTEXT_INIT:
         return glsm_state_ctx_init(data);
      case GLSM_CTL_STATE_SETUP:
         glsm_state_setup();
         break;
      case GLSM_CTL_STATE_UNBIND:
         glsm_state_unbind();
         break;
      case GLSM_CTL_STATE_BIND:
         glsm_state_bind();
         break;
      case GLSM_CTL_NONE:
      default:
         break;
   }

   return true;
}
