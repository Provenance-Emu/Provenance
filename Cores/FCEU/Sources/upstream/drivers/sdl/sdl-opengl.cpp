#define GL_GLEXT_LEGACY

#include "sdl.h"
#include "sdl-opengl.h"
#include "../common/vidblit.h"
#include "../../utils/memory.h"

#ifdef APPLEOPENGL
#include <OpenGL/gl.h>
#include <OpenGL/glu.h>
#include <OpenGL/glext.h>
#else
#include <GL/gl.h>
#include <GL/glu.h>
#include <GL/glext.h>
#endif
#include <cstring>
#include <cstdlib>

#ifndef APIENTRY
#define APIENTRY
#endif

static GLuint textures[2]={0,0};	// Normal image, scanline overlay.

static int left,right,top,bottom; // right and bottom are not inclusive.
static int scanlines;
static void *HiBuffer;

typedef void APIENTRY (*glColorTableEXT_Func)(GLenum target,
		GLenum internalformat,  GLsizei width, GLenum format, GLenum type,
		const GLvoid *table);
glColorTableEXT_Func p_glColorTableEXT;

void
SetOpenGLPalette(uint8 *data)
{
	if(!HiBuffer) {
		glBindTexture(GL_TEXTURE_2D, textures[0]);
		p_glColorTableEXT(GL_TEXTURE_2D, GL_RGB, 256,
						GL_RGBA, GL_UNSIGNED_BYTE, data);
	} else {
		SetPaletteBlitToHigh((uint8*)data);
	}
}

void
BlitOpenGL(uint8 *buf)
{
	glClear(GL_COLOR_BUFFER_BIT);
	glBindTexture(GL_TEXTURE_2D, textures[0]);

	if(HiBuffer) {
		Blit8ToHigh(buf, (uint8*)HiBuffer, 256, 240, 256*4, 1, 1);
    
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 256, 256, 0,
					GL_RGBA, GL_UNSIGNED_BYTE, HiBuffer);
	}
	else {
		//glPixelStorei(GL_UNPACK_ROW_LENGTH, 256);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_COLOR_INDEX8_EXT, 256, 256, 0,
					GL_COLOR_INDEX,GL_UNSIGNED_BYTE,buf);
	}

	glBegin(GL_QUADS);
	glTexCoord2f(1.0f*left/256, 1.0f*bottom/256); // Bottom left of picture.
	glVertex2f(-1.0f, -1.0f);	// Bottom left of target.

	glTexCoord2f(1.0f*right/256, 1.0f*bottom/256);// Bottom right of picture.
	glVertex2f( 1.0f, -1.0f);	// Bottom right of target.

	glTexCoord2f(1.0f*right/256, 1.0f*top/256); // Top right of our picture.
	glVertex2f( 1.0f,  1.0f);	// Top right of target.

	glTexCoord2f(1.0f*left/256, 1.0f*top/256);  // Top left of our picture.
	glVertex2f(-1.0f,  1.0f);	// Top left of target.
	glEnd();

	//glDisable(GL_BLEND);
	if(scanlines) {
		glEnable(GL_BLEND);

		glBindTexture(GL_TEXTURE_2D, textures[1]);
		glBlendFunc(GL_DST_COLOR, GL_SRC_ALPHA);

		glBegin(GL_QUADS);

		glTexCoord2f(1.0f*left/256,
					1.0f*bottom/256); // Bottom left of our picture.
		glVertex2f(-1.0f, -1.0f);      // Bottom left of target.
 
		glTexCoord2f(1.0f*right/256,
					1.0f*bottom/256); // Bottom right of our picture.
		glVertex2f( 1.0f, -1.0f);      // Bottom right of target.
 
		glTexCoord2f(1.0f*right/256,
					1.0f*top/256);    // Top right of our picture.
		glVertex2f( 1.0f,  1.0f);      // Top right of target.
 
		glTexCoord2f(1.0f*left/256,
					1.0f*top/256);     // Top left of our picture.
		glVertex2f(-1.0f,  1.0f);      // Top left of target.

		glEnd();
		glDisable(GL_BLEND);
	}
	SDL_GL_SwapBuffers();
}

void
KillOpenGL(void)
{
	if(textures[0]) {
		glDeleteTextures(2, &textures[0]);
	}
	textures[0]=0;
	if(HiBuffer) {
		free(HiBuffer);
		HiBuffer=0;
	}
}
/* Rectangle, left, right(not inclusive), top, bottom(not inclusive). */

int
InitOpenGL(int l,
		int r,
		int t,
		int b,
		double xscale,
		double yscale,
		int efx,
		int ipolate,
		int stretchx,
		int stretchy,
		SDL_Surface *screen)
{
	const char *extensions;

#define LFG(x) if(!(##x = (x##_Func) SDL_GL_GetProcAddress(#x))) return(0);

#define LFGN(x) p_##x = (x##_Func) SDL_GL_GetProcAddress(#x)

//	LFG(glBindTexture);
	LFGN(glColorTableEXT);
//	LFG(glTexImage2D);
//	LFG(glBegin);
//	LFG(glVertex2f);
//	LFG(glTexCoord2f);
//	LFG(glEnd);
//	LFG(glEnable);
//	LFG(glBlendFunc);
//	LFG(glGetString);
//	LFG(glViewport);
//	LFG(glGenTextures);
//	LFG(glDeleteTextures);
//	LFG(glTexParameteri);
//	LFG(glClearColor);
//	LFG(glLoadIdentity);
//	LFG(glClear);
//	LFG(glMatrixMode);
//	LFG(glDisable);

	left=l;
	right=r;
	top=t;
	bottom=b;

	HiBuffer=0;
 
	extensions=(const char*)glGetString(GL_EXTENSIONS);

	if((efx&2) || !extensions || !p_glColorTableEXT || !strstr(extensions,"GL_EXT_paletted_texture"))
	{
	if(!(efx&2)) // Don't want to print out a warning message in this case...
		FCEU_printf("Paletted texture extension not found.  Using slower texture format...\n");
	HiBuffer=FCEU_malloc(4*256*256);
	memset(HiBuffer,0x00,4*256*256);
  #ifndef LSB_FIRST
	InitBlitToHigh(4,0xFF000000,0xFF0000,0xFF00,efx&2,0,0);
  #else
	InitBlitToHigh(4,0xFF,0xFF00,0xFF0000,efx&2,0,0);
  #endif
	}
 
	if(screen->flags & SDL_FULLSCREEN)
	{
		xscale=(double)screen->w / (double)(r-l);
		yscale=(double)screen->h / (double)(b-t);
		if(xscale<yscale) yscale = xscale;
		if(yscale<xscale) xscale = yscale;
	}

	{
		int rw=(int)((r-l)*xscale);
		int rh=(int)((b-t)*yscale);
		int sx=(screen->w-rw)/2;     // Start x
		int sy=(screen->h-rh)/2;      // Start y

		if(stretchx) { sx=0; rw=screen->w; }
		if(stretchy) { sy=0; rh=screen->h; }
		glViewport(sx, sy, rw, rh);
	}
	glGenTextures(2, &textures[0]);
	scanlines=0;

	if(efx&1)
	{
		uint8 *buf;
		int x,y;

		scanlines=1;

		glBindTexture(GL_TEXTURE_2D, textures[1]);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,ipolate?GL_LINEAR:GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,ipolate?GL_LINEAR:GL_NEAREST);

		buf=(uint8*)FCEU_dmalloc(256*(256*2)*4);

		for(y=0;y<(256*2);y++)
			for(x=0;x<256;x++)
			{
				buf[y*256*4+x*4]=0;
				buf[y*256*4+x*4+1]=0;
				buf[y*256*4+x*4+2]=0;
				buf[y*256*4+x*4+3]=(y&1)?0x00:0xFF; //?0xa0:0xFF; // <-- Pretty
				//buf[y*256+x]=(y&1)?0x00:0xFF;
			}
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 256, (scanlines==2)?256*4:512, 0,
				GL_RGBA,GL_UNSIGNED_BYTE,buf);
		FCEU_dfree(buf);
	}
	glBindTexture(GL_TEXTURE_2D, textures[0]);
     
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,ipolate?GL_LINEAR:GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,ipolate?GL_LINEAR:GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP);
	glEnable(GL_TEXTURE_2D);
	glDisable(GL_DEPTH_TEST);
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);	// Background color to black.
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	// In a double buffered setup with page flipping, be sure to clear both buffers.
	glClear(GL_COLOR_BUFFER_BIT);
	SDL_GL_SwapBuffers();
	glClear(GL_COLOR_BUFFER_BIT);
	SDL_GL_SwapBuffers();

	return 1;
}
