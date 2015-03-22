#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sdl.h"
#include "sdl-video.h"
#ifdef NETWORK
#include "unix-netplay.h"
#endif

DSETTINGS Settings;
CFGSTRUCT DriverConfig[]={
	#ifdef OPENGL
	AC(_stretchx),
	AC(_stretchy),
	AC(_opengl),
	AC(_openglip),
	#endif
	AC(Settings.special),
	AC(Settings.specialfs),
	AC(_doublebuf),
	AC(_xscale),
	AC(_yscale),
	AC(_xscalefs),
	AC(_yscalefs),
	AC(_bpp),
	AC(_efx),
	AC(_efxfs),
	AC(_fullscreen),
        AC(_xres),
	AC(_yres),
	#ifdef NETWORK
        ACS(netplaynick),
	AC(netlocalplayers),
	AC(tport),
	ACS(netpassword),
	ACS(netgamekey),
	#endif
        ENDCFGSTRUCT
};

//-fshack x       Set the environment variable SDL_VIDEODRIVER to \"x\" when
//                entering full screen mode and x is not \"0\".

char *DriverUsage=
"-xres   x	Set horizontal resolution to x for full screen mode.\n\
-yres   x       Set vertical resolution to x for full screen mode.\n\
-xscale(fs) x	Multiply width by x(Real numbers >0 with OpenGL, otherwise integers >0).\n\
-yscale(fs) x	Multiply height by x(Real numbers >0 with OpenGL, otherwise integers >0).\n\
-bpp(fs) x	Bits per pixel for SDL surface(and video mode in fs). 8, 16, 32.\n\
-opengl x	Enable OpenGL support if x is 1.\n\
-openglip x	Enable OpenGL linear interpolation if x is 1.\n\
-doublebuf x	\n\
-special(fs) x	Specify special scaling filter.\n\
-stretch(x/y) x	Stretch to fill surface on x or y axis(fullscreen, only with OpenGL).\n\
-efx(fs) x	Enable special effects.  Logically OR the following together:\n\
		 1 = scanlines(for yscale>=2).\n\
		 2 = TV blur(for bpp of 16 or 32).\n\
-fs	 x      Select full screen mode if x is non zero.\n\
-connect s      Connect to server 's' for TCP/IP network play.\n\
-netnick s	Set the nickname to use in network play.\n\
-netgamekey s 	Use key 's' to create a unique session for the game loaded.\n\
-netpassword s	Password to use for connecting to the server.\n\
-netlocalplayers x	Set the number of local players.\n\
-netport x      Use TCP/IP port x for network play.";

ARGPSTRUCT DriverArgs[]={
	#ifdef OPENGL
	 {"-opengl",0,&_opengl,0},
	 {"-openglip",0,&_openglip,0},
	 {"-stretchx",0,&_stretchx,0},
	 {"-stretchy",0,&_stretchy,0},
	#endif
	 {"-special",0,&Settings.special,0},
	 {"-specialfs",0,&Settings.specialfs,0},
	 {"-doublebuf",0,&_doublebuf,0},
	 {"-bpp",0,&_bpp,0},
	 {"-xscale",0,&_xscale,2},
	 {"-yscale",0,&_yscale,2},
	 {"-efx",0,&_efx,0},
         {"-xscalefs",0,&_xscalefs,2},
         {"-yscalefs",0,&_yscalefs,2},
         {"-efxfs",0,&_efxfs,0},
	 {"-xres",0,&_xres,0},
         {"-yres",0,&_yres,0},
         {"-fs",0,&_fullscreen,0},
         //{"-fshack",0,&_fshack,0x4001},
	 #ifdef NETWORK
         {"-connect",0,&netplayhost,0x4001},
         {"-netport",0,&tport,0},
	 {"-netlocalplayers",0,&netlocalplayers,0},
	 {"-netnick",0,&netplaynick,0x4001},
	 {"-netpassword",0,&netpassword,0x4001},
	 #endif
         {0,0,0,0}
};

static void SetDefaults(void)
{
 Settings.special=Settings.specialfs=0;
 _bpp=8;
 _xres=640;
 _yres=480;
 _fullscreen=0;
 _xscale=2.50;
 _yscale=2;
 _xscalefs=_yscalefs=2;
 _efx=_efxfs=0;
 //_fshack=_fshacksave=0;
#ifdef OPENGL
 _opengl=1;
 _stretchx=1; 
 _stretchy=0;
 _openglip=1;
#endif
}

void DoDriverArgs(void)
{
	#ifdef BROKEN
        if(_fshack)
        {
         if(_fshack[0]=='0')
          if(_fshack[1]==0)
          {
           free(_fshack);
           _fshack=0;
          }
        }
	#endif
}

int InitMouse(void)
{
 return(0);
}

void KillMouse(void){}

void GetMouseData(uint32 *d)
{
 if(FCEUI_IsMovieActive()<0)
   return;

 int x,y;
 uint32 t;

 t=SDL_GetMouseState(&x,&y);
 #ifdef EXTGUI
 GUI_GetMouseState(&t,&x,&y);
 #endif

 d[2]=0;
 if(t&SDL_BUTTON(1))
  d[2]|=1;
 if(t&SDL_BUTTON(3))
  d[2]|=2;
 t=PtoV(x,y); 
 d[0]=t&0xFFFF;
 d[1]=(t>>16)&0xFFFF;
}

int InitKeyboard(void)
{
 return(1);
}

int UpdateKeyboard(void)
{
 return(1);
}

void KillKeyboard(void)
{

}


void UpdatePhysicalInput(void)
{
 SDL_Event event;

 while(SDL_PollEvent(&event))
 {
  switch(event.type)
  {
   //case SDL_SYSWMEVENT: puts("Nifty keen");break;
   //case SDL_VIDEORESIZE: puts("Okie dokie");break;
   case SDL_QUIT: CloseGame();puts("Quit");break;
  }
  //printf("Event: %d\n",event.type);
  //fflush(stdout);
 }
 //SDL_PumpEvents();
}

static uint8 *KeyState=NULL;
char *GetKeyboard(void)
{
 KeyState=SDL_GetKeyState(0);
 #ifdef EXTGUI
 { char *tmp=GUI_GetKeyboard(); if(tmp) KeyState=tmp; }
 #endif
 return((char *)KeyState);
}

#ifdef WIN32
#include <windows.h>

 /* Stupid SDL */
 #ifdef main
 #undef main
 #endif
#endif

#ifndef EXTGUI
uint8 *GetBaseDirectory(void)
{
 uint8 *ol;
 uint8 *ret; 

 ol=getenv("HOME");

 if(ol)
 {
  ret=malloc(strlen(ol)+1+strlen("./fceultra"));
  strcpy(ret,ol);
  strcat(ret,"/.fceultra");
 }
 else
 {
  #ifdef WIN32
  char *sa;

  ret=malloc(MAX_PATH+1);
  GetModuleFileName(NULL,ret,MAX_PATH+1);

  sa=strrchr(ret,'\\');
  if(sa)
   *sa = 0; 
  #else
  ret=malloc(1);
  ret[0]=0;
  #endif
  printf("%s\n",ret);
 }
 return(ret);
}
#endif

#ifdef OPENGL
int sdlhaveogl;
#endif


int DTestButton(ButtConfig *bc)
{
 int x;

 for(x=0;x<bc->NumC;x++)
 {
  if(bc->ButtType[x]==BUTTC_KEYBOARD)
  {
   if(KeyState[bc->ButtonNum[x]])
    return(1);
  }
  else if(bc->ButtType[x]==BUTTC_JOYSTICK)
  {
   if(DTestButtonJoy(bc))
    return(1);
  }
 }
 return(0);
}

static int bcpv,bcpj;

int ButtonConfigBegin(void)
{
 SDL_Surface *screen;
 SDL_QuitSubSystem(SDL_INIT_VIDEO);
 bcpv=KillVideo();
 bcpj=KillJoysticks();
 
 if(!(SDL_WasInit(SDL_INIT_VIDEO)&SDL_INIT_VIDEO))
  if(SDL_InitSubSystem(SDL_INIT_VIDEO)==-1)
  {
   FCEUD_Message(SDL_GetError());
   return(0);
  } 
 
 screen = SDL_SetVideoMode(300, 1, 8, 0); 
 SDL_WM_SetCaption("Button Config",0);
 InitJoysticks();
 
 return(1);
}

void ButtonConfigEnd(void)
{ 
 extern FCEUGI *CurGame;
 KillJoysticks();
 SDL_QuitSubSystem(SDL_INIT_VIDEO); 
 if(bcpv) InitVideo(CurGame);
 if(bcpj) InitJoysticks();
}

int DWaitButton(const uint8 *text, ButtConfig *bc, int wb)
{
 SDL_Event event;
 static int32 LastAx[64][64];
 int x,y;

 SDL_WM_SetCaption(text,0);
 #ifndef EXTGUI
 puts(text);
 #endif
 for(x=0;x<64;x++) 
  for(y=0;y<64;y++)
   LastAx[x][y]=0x100000;

 while(SDL_WaitEvent(&event))
 {
  switch(event.type)
  {
   case SDL_KEYDOWN:bc->ButtType[wb]=BUTTC_KEYBOARD;
		    bc->DeviceNum[wb]=0;
		    bc->ButtonNum[wb]=event.key.keysym.sym;
		    return(1);
   case SDL_JOYBUTTONDOWN:bc->ButtType[wb]=BUTTC_JOYSTICK;
			  bc->DeviceNum[wb]=event.jbutton.which;
			  bc->ButtonNum[wb]=event.jbutton.button; 
			  return(1);
   case SDL_JOYHATMOTION:if(event.jhat.value != SDL_HAT_CENTERED)
			 {
			  bc->ButtType[wb]=BUTTC_JOYSTICK;
			  bc->DeviceNum[wb]=event.jhat.which;
			  bc->ButtonNum[wb]=0x2000|((event.jhat.hat&0x1F)<<8)|event.jhat.value;
			  return(1);
			 }
			 break;
   case SDL_JOYAXISMOTION: 
	if(LastAx[event.jaxis.which][event.jaxis.axis]==0x100000)
	{
	 if(abs(event.jaxis.value)<1000)
 	  LastAx[event.jaxis.which][event.jaxis.axis]=event.jaxis.value;
	}
	else
	{
	 if(abs(LastAx[event.jaxis.which][event.jaxis.axis]-event.jaxis.value)>=8192)
	 {
	  bc->ButtType[wb]=BUTTC_JOYSTICK;
	  bc->DeviceNum[wb]=event.jaxis.which;
	  bc->ButtonNum[wb]=0x8000|(event.jaxis.axis)|((event.jaxis.value<0)?0x4000:0);
	  return(1);
	 }
	}
	break;
  }
 }

 return(0);
}

#ifdef EXTGUI
int FCEUSDLmain(int argc, char *argv[])
#else
int main(int argc, char *argv[])
#endif
{
        FCEUD_Message("\nStarting FCE Ultra "FCEU_VERSION"...\n");

        #ifdef WIN32
        /* Taken from win32 sdl_main.c */
        SDL_SetModuleHandle(GetModuleHandle(NULL));
        #endif

	if(SDL_Init(SDL_INIT_VIDEO)) /* SDL_INIT_VIDEO Needed for (joystick config) event processing? */
	{
	 printf("Could not initialize SDL: %s.\n", SDL_GetError());
	 return(-1);
	}

	#ifdef OPENGL
 	 #ifdef APPLEOPENGL
	 sdlhaveogl = 1;	/* Stupid something...  Hack. */
	 #else
	 if(!SDL_GL_LoadLibrary(0)) sdlhaveogl=1;
	 else sdlhaveogl=0;
	 #endif
	#endif

	SetDefaults();

	{
	 int ret=CLImain(argc,argv);
	 SDL_Quit();
	 return(ret?0:-1);
	}
}


uint64 FCEUD_GetTime(void)
{
 return(SDL_GetTicks());
}

uint64 FCEUD_GetTimeFreq(void)
{
 return(1000);
}

// dummy functions

#define DUMMY(f) void f(void) {FCEU_DispMessage("Not implemented.");}
DUMMY(FCEUD_HideMenuToggle)
DUMMY(FCEUD_TurboOn)
DUMMY(FCEUD_TurboOff)
DUMMY(FCEUD_SaveStateAs)
DUMMY(FCEUD_LoadStateFrom)
DUMMY(FCEUD_MovieRecordTo)
DUMMY(FCEUD_MovieReplayFrom)
DUMMY(FCEUD_ToggleStatusIcon)
DUMMY(FCEUD_AviRecordTo)
DUMMY(FCEUD_AviStop)
void FCEUI_AviVideoUpdate(const unsigned char* buffer) {FCEU_DispMessage("Not implemented.");} 
int FCEUD_ShowStatusIcon(void) {FCEU_DispMessage("Not implemented."); return 0; } 
int FCEUI_AviIsRecording(void) {return 0;}

