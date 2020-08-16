#ifndef WIN_COMMON_H
#define WIN_COMMON_H

#include <stdio.h>
#include <windows.h>
#include <windowsx.h>
#include <commctrl.h> //bbit edited:this line added   //mbg merge 7/17/06 removing conditional compiles

#ifndef WIN32
#define WIN32
#endif
#undef  WINNT
#define NONAMELESSUNION

#define DIRECTSOUND_VERSION  0x0700
#define DIRECTDRAW_VERSION 0x0700
#define DIRECTINPUT_VERSION     0x700

//#define FCEUDEF_DEBUGGER //mbg merge 7/17/06 removing conditional compiles
#include "../../types.h"
#include "../../file.h"
#include "../../driver.h"
#include "../common/vidblit.h" //mbg merge 7/17/06 added
#include "../common/config.h"
#include "resource.h" //mbg merge 7/18/06 added

/* Message logging(non-netplay messages, usually) for all. */
#include "log.h"
extern HWND hAppWnd;
extern HINSTANCE fceu_hInstance;

extern int NoWaiting;

extern int eoptions;

#define EO_BGRUN              1

#define EO_CPALETTE           4 //this is bad, it is desynchronized from other state management in palette.cpp
#define EO_NOSPRLIM           8
#define EO_FSAFTERLOAD       32
#define EO_FOAFTERSTART      64
#define EO_NOTHROTTLE       128
#define EO_CLIPSIDES        256
#define EO_HIDEMENU        2048
#define EO_HIGHPRIO        4096
#define EO_FORCEASPECT     8192
#define EO_FORCEISCALE    16384
#define EO_FOURSCORE      32768
#define EO_BESTFIT        65536
#define EO_BGCOLOR       131072
#define EO_HIDEMOUSE     262144
#define EO_TVASPECT      524288
#define EO_SQUAREPIXELS 1048576

enum WINDOW_ITEM_RESIZE_TYPES
{
	WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED,
	WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	WINDOW_ITEM_RESIZE_TYPE_CENTER_ALIGNED,
	WINDOW_ITEM_RESIZE_TYPE_MULTIPLY,
	// ---
	WINDOW_ITEM_RESIZE_TYPES_TOTAL
};

bool directoryExists(const char* dirname);
void WindowBoundsCheckResize(int &windowPosX, int &windowPosY, int windowSizeX, long windowRight);
void WindowBoundsCheckNoResize(int &windowPosX, int &windowPosY, long windowRight);
int recalculateResizedItemCoordinate(int initialValue, int initialBase, int newBase, unsigned int resizingType);
void AddExtensionIfMissing(char * name,unsigned int maxsize,const char * extension);
void AddExtensionIfMissing(std::string &name,const char * extension);
std::string GetPath(std::string filename);
bool IsRelativePath(char* name);
bool IsRelativePath(const char* name);
bool IsRelativePath(std::string name);
std::string ConvertRelativePath(std::string name);
#endif
