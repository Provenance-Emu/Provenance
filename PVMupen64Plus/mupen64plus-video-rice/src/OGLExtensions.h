/* OGLExtensions.h
Copyright (C) 2009 Richard Goedeken

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

/* This header file contains function pointers to some OpenGL functions */
/* This is only necessary because Windows does not contain development support for OpenGL versions beyond 1.1 */
#ifndef USE_GLES
#if !defined(OGL_EXTENSIONS_H)
#define OGL_EXTENSIONS_H

#include "osal_opengl.h"

/* Just call this one function to load up the function pointers. */
void OGLExtensions_Init(void);

/* The function pointer types are defined here because as of 2009 some OpenGL drivers under Linux do 'incorrect' things which
   mess up the SDL_opengl.h header, resulting in no function pointer typedefs at all, and thus compilation errors.
*/
typedef void (APIENTRYP PFUNCGLACTIVETEXTUREPROC) (GLenum texture);
typedef void (APIENTRYP PFUNCGLMULTITEXCOORD2FPROC) (GLenum target, GLfloat s, GLfloat t);
typedef void (APIENTRYP PFUNCGLMULTITEXCOORD2FVPROC) (GLenum target, const GLfloat *v);
typedef void (APIENTRYP PFUNCGLDELETEPROGRAMSARBPROC) (GLsizei n, const GLuint *programs);
typedef void (APIENTRYP PFUNCGLPROGRAMSTRINGARBPROC) (GLenum target, GLenum format, GLsizei len, const GLvoid *string);
typedef void (APIENTRYP PFUNCGLBINDPROGRAMARBPROC) (GLenum target, GLuint program);
typedef void (APIENTRYP PFUNCGLGENPROGRAMSARBPROC) (GLsizei n, GLuint *programs);
typedef void (APIENTRYP PFUNCGLPROGRAMENVPARAMETER4FVARBPROC) (GLenum target, GLuint index, const GLfloat *params);
typedef void (APIENTRYP PFUNCGLFOGCOORDPOINTERPROC) (GLenum type, GLsizei stride, const GLvoid *pointer);
typedef void (APIENTRYP PFUNCGLCLIENTACTIVETEXTUREPROC) (GLenum texture);

extern PFUNCGLACTIVETEXTUREPROC             pglActiveTexture;
extern PFUNCGLMULTITEXCOORD2FPROC           pglMultiTexCoord2f;
extern PFUNCGLMULTITEXCOORD2FVPROC          pglMultiTexCoord2fv;
extern PFUNCGLDELETEPROGRAMSARBPROC         pglDeleteProgramsARB;
extern PFUNCGLPROGRAMSTRINGARBPROC          pglProgramStringARB;
extern PFUNCGLBINDPROGRAMARBPROC            pglBindProgramARB;
extern PFUNCGLGENPROGRAMSARBPROC            pglGenProgramsARB;
extern PFUNCGLPROGRAMENVPARAMETER4FVARBPROC pglProgramEnvParameter4fvARB;
extern PFUNCGLFOGCOORDPOINTERPROC           pglFogCoordPointer;
extern PFUNCGLCLIENTACTIVETEXTUREPROC       pglClientActiveTexture;

#endif  // OGL_EXTENSIONS_H
#endif  // USE_GLES
