#define GL_GLEXT_LEGACY
#ifdef APPLEOPENGL
#include <OpenGL/gl.h>
#include <OpenGL/glu.h>
#include <OpenGL/glext.h>
#else
#include <GL/gl.h>
#include <GL/glu.h>
#include <GL/glext.h>
#endif
#include <string.h>
#include <stdlib.h>

#include "sdl.h"
#include "sdl-opengl.h"
#include "../common/vidblit.h"

#ifndef APIENTRY
#define APIENTRY
#endif

static GLuint textures[2]={0,0};	// Normal image, scanline overlay.

static int left,right,top,bottom; // right and bottom are not inclusive.
static int scanlines;
static void *HiBuffer;

void APIENTRY (*p_glBindTexture)(GLenum target,GLuint texture);
void APIENTRY (*p_glColorTableEXT)(GLenum target, GLenum internalformat,  GLsizei width, GLenum format, GLenum type, const GLvoid *table);
void APIENTRY (*p_glTexImage2D)( GLenum target, GLint level,
                                    GLint internalFormat,
                                    GLsizei width, GLsizei height, GLint border,
                                    GLenum format, GLenum type,
                                    const GLvoid *pixels );
void APIENTRY (*p_glBegin)(GLenum mode);
void APIENTRY (*p_glVertex2f)(GLfloat x, GLfloat y);
void APIENTRY (*p_glTexCoord2f)(GLfloat s, GLfloat t);
void APIENTRY (*p_glEnd)(void);
void APIENTRY (*p_glEnable)(GLenum cap);
void APIENTRY (*p_glBlendFunc)(GLenum sfactor, GLenum dfactor);
const GLubyte* APIENTRY (*p_glGetString)(GLenum name);
void APIENTRY (*p_glViewport)(GLint x, GLint y,GLsizei width, GLsizei height);
void APIENTRY (*p_glGenTextures)(GLsizei n, GLuint *textures);
void APIENTRY (*p_glDeleteTextures)(GLsizei n,const GLuint *textures);
void APIENTRY (*p_glTexParameteri)(GLenum target, GLenum pname, GLint param);
void APIENTRY (*p_glClearColor)(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
void APIENTRY (*p_glLoadIdentity)(void);
void APIENTRY (*p_glClear)(GLbitfield mask);
void APIENTRY (*p_glMatrixMode)(GLenum mode);
void APIENTRY (*p_glDisable)(GLenum cap);

void SetOpenGLPalette(uint8 *data)
{
 if(!HiBuffer)
 {
  p_glBindTexture(GL_TEXTURE_2D, textures[0]);
  p_glColorTableEXT(GL_TEXTURE_2D,GL_RGB,256,GL_RGBA,GL_UNSIGNED_BYTE,data);
 }
 else
  SetPaletteBlitToHigh((uint8*)data); 
}

void BlitOpenGL(uint8 *buf)
{
 p_glBindTexture(GL_TEXTURE_2D, textures[0]);
 if(HiBuffer)
 {
  static int xo=0;
  xo=(xo+1)&3;
  Blit8ToHigh(buf,(uint8*)HiBuffer,256,240,256*4,1,1);
  if(!xo)
  p_glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,256,256, 0, GL_RGBA,GL_UNSIGNED_BYTE,
			HiBuffer);
 }
 else
 {
  //glPixelStorei(GL_UNPACK_ROW_LENGTH, 256);
  p_glTexImage2D(GL_TEXTURE_2D, 0, GL_COLOR_INDEX8_EXT, 256, 256, 0,
		GL_COLOR_INDEX,GL_UNSIGNED_BYTE,buf);
 }

 p_glBegin(GL_QUADS);
 p_glTexCoord2f(1.0f*left/256, 1.0f*bottom/256);	// Bottom left of our picture.
 p_glVertex2f(-1.0f, -1.0f);	// Bottom left of target.

 p_glTexCoord2f(1.0f*right/256, 1.0f*bottom/256);	// Bottom right of our picture.
 p_glVertex2f( 1.0f, -1.0f);	// Bottom right of target.

 p_glTexCoord2f(1.0f*right/256, 1.0f*top/256);	// Top right of our picture.
 p_glVertex2f( 1.0f,  1.0f);	// Top right of target.

 p_glTexCoord2f(1.0f*left/256, 1.0f*top/256);	// Top left of our picture.
 p_glVertex2f(-1.0f,  1.0f);	// Top left of target.
 p_glEnd();

 //glDisable(GL_BLEND);
 if(scanlines)
 {
  p_glEnable(GL_BLEND);

  p_glBindTexture(GL_TEXTURE_2D, textures[1]);
  p_glBlendFunc(GL_DST_COLOR, GL_SRC_ALPHA);

  p_glBegin(GL_QUADS);

  p_glTexCoord2f(1.0f*left/256, 1.0f*bottom/256);  // Bottom left of our picture.
  p_glVertex2f(-1.0f, -1.0f);      // Bottom left of target.
 
  p_glTexCoord2f(1.0f*right/256, 1.0f*bottom/256); // Bottom right of our picture.
  p_glVertex2f( 1.0f, -1.0f);      // Bottom right of target.
 
  p_glTexCoord2f(1.0f*right/256, 1.0f*top/256);    // Top right of our picture.
  p_glVertex2f( 1.0f,  1.0f);      // Top right of target.
 
  p_glTexCoord2f(1.0f*left/256, 1.0f*top/256);     // Top left of our picture.
  p_glVertex2f(-1.0f,  1.0f);      // Top left of target.

  p_glEnd();
  p_glDisable(GL_BLEND);
 }
  SDL_GL_SwapBuffers();
}

void KillOpenGL(void)
{
 if(textures[0])
  p_glDeleteTextures(2, &textures[0]);
 textures[0]=0;
 if(HiBuffer)
 {
  free(HiBuffer);
  HiBuffer=0;
 }
}
/* Rectangle, left, right(not inclusive), top, bottom(not inclusive). */

int InitOpenGL(int l, int r, int t, int b, double xscale,double yscale, int efx, int ipolate,
		int stretchx, int stretchy, SDL_Surface *screen)
{
 const char *extensions;

 #define LFG(x) if(!(p_##x = SDL_GL_GetProcAddress(#x))) return(0);

 #define LFGN(x) p_##x = SDL_GL_GetProcAddress(#x)

 LFG(glBindTexture);
 LFGN(glColorTableEXT);
 LFG(glTexImage2D);
 LFG(glBegin);
 LFG(glVertex2f);
 LFG(glTexCoord2f);
 LFG(glEnd);
 LFG(glEnable);
 LFG(glBlendFunc);
 LFG(glGetString);
 LFG(glViewport);
 LFG(glGenTextures);
 LFG(glDeleteTextures);
 LFG(glTexParameteri);
 LFG(glClearColor);
 LFG(glLoadIdentity);
 LFG(glClear);
 LFG(glMatrixMode);
 LFG(glDisable);

 left=l;
 right=r;
 top=t;
 bottom=b;

 HiBuffer=0;
 
 extensions=(const char*)p_glGetString(GL_EXTENSIONS);

 if((efx&2) || !extensions || !p_glColorTableEXT || !strstr(extensions,"GL_EXT_paletted_texture"))
 {
  if(!(efx&2)) // Don't want to print out a warning message in this case...
   FCEU_printf("Paletted texture extension not found.  Using slower texture format...");
  HiBuffer=malloc(4*256*256);
  memset(HiBuffer,0x00,4*256*256);
  #ifndef LSB_FIRST
  InitBlitToHigh(4,0xFF000000,0xFF0000,0xFF00,efx&2,0);
  #else
  InitBlitToHigh(4,0xFF,0xFF00,0xFF0000,efx&2,0);
  #endif
 }

 {
  int rw=(r-l)*xscale;
  int rh=(b-t)*yscale;
  int sx=(screen->w-rw)/2;     // Start x
  int sy=(screen->h-rh)/2;      // Start y

  if(stretchx) { sx=0; rw=screen->w; }
  if(stretchy) { sy=0; rh=screen->h; }
  p_glViewport(sx, sy, rw, rh);
 }
 p_glGenTextures(2, &textures[0]);
 scanlines=0;

 if(efx&1)
 {
  uint8 *buf;
  int x,y;

  scanlines=1;

  p_glBindTexture(GL_TEXTURE_2D, textures[1]);
  p_glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,ipolate?GL_LINEAR:GL_NEAREST);
  p_glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,ipolate?GL_LINEAR:GL_NEAREST);

  buf=(uint8*)malloc(256*(256*2)*4);

  for(y=0;y<(256*2);y++)
   for(x=0;x<256;x++)
   {
    buf[y*256*4+x*4]=0;
    buf[y*256*4+x*4+1]=0;
    buf[y*256*4+x*4+2]=0;
    buf[y*256*4+x*4+3]=(y&1)?0x00:0xFF; //?0xa0:0xFF; // <-- Pretty
    //buf[y*256+x]=(y&1)?0x00:0xFF;
   }
  p_glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 256, (scanlines==2)?256*4:512, 0,
                GL_RGBA,GL_UNSIGNED_BYTE,buf);
  free(buf);
 }
 p_glBindTexture(GL_TEXTURE_2D, textures[0]);
     
 p_glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,ipolate?GL_LINEAR:GL_NEAREST);
 p_glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,ipolate?GL_LINEAR:GL_NEAREST);
 p_glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP);
 p_glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP);
 p_glEnable(GL_TEXTURE_2D);
 p_glClearColor(0.0f, 0.0f, 0.0f, 0.0f);	// Background color to black.
 p_glMatrixMode(GL_MODELVIEW);

 p_glClear(GL_COLOR_BUFFER_BIT);
 p_glLoadIdentity();

 return(1);
}
