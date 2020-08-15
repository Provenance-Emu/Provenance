#include <SDL.h>
#include "main.h"
#include "dface.h"
#include "input.h"

int DTestButtonJoy(ButtConfig *bc);

typedef struct {
        int xres;
        int yres;
	double xscale,yscale;
	double xscalefs,yscalefs;
	int efx,efxfs;
	int bpp;
        int fullscreen;
	int doublebuf;
	char *fshack;
	char *fshacksave;
	#ifdef OPENGL
	int opengl;
	int openglip;
	int stretchx,stretchy;
	#endif
	int special,specialfs;
} DSETTINGS;

extern DSETTINGS Settings;

#define _doublebuf Settings.doublebuf
#define _bpp Settings.bpp
#define _xres Settings.xres
#define _yres Settings.yres
#define _fullscreen Settings.fullscreen
#define _xscale Settings.xscale
#define _yscale Settings.yscale
#define _xscalefs Settings.xscalefs
#define _yscalefs Settings.yscalefs
#define _efx Settings.efx
#define _efxfs Settings.efxfs
#define _ebufsize Settings.ebufsize
#define _fshack Settings.fshack
#define _fshacksave Settings.fshacksave

#ifdef OPENGL
#define _opengl Settings.opengl
#define _openglip Settings.openglip
#define _stretchx Settings.stretchx
#define _stretchy Settings.stretchy
#endif

