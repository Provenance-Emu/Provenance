/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "main.h"
#include "throttle.h"

#include "../common/cheat.h"

#include "input.h"
#include "dface.h"

extern int32 fps_scale;

int CloseGame(void);

static char *soundrecfn=0;	/* File name of sound recording. */

static int ntsccol=0,ntschue=0,ntsctint=0;
int soundvol=100;
long soundq=0;
int _sound=1;
long soundrate=48000;
#ifdef WIN32
long soundbufsize=52;
#else
long soundbufsize=24;
#endif

#ifdef FRAMESKIP
static int frameskip=0;
#endif
static int inited=0;
static int isloaded=0;	// Is game loaded?

int srendlinev[2]={8,0};
int erendlinev[2]={231,239};


static uint8 *DrBaseDirectory;

int eoptions=0;

static void DriverKill(void);
static int DriverInitialize(FCEUGI *gi);
int gametype;

FCEUGI *CurGame=NULL;

static void ParseGI(FCEUGI *gi)
{
 ParseGIInput(gi);
 gametype=gi->type;
}

#ifndef EXTGUI
void FCEUD_PrintError(char *s)
{
 puts(s);
}

void FCEUD_Message(char *s)
{
 fputs(s,stdout);
}
#endif

static char *cpalette=0;
static void LoadCPalette(void)
{
 uint8 tmpp[192];
 FILE *fp;

 if(!(fp=FCEUD_UTF8fopen(cpalette,"rb")))
 {
  printf(" Error loading custom palette from file: %s\n",cpalette);
  return;
 }
 fread(tmpp,1,192,fp);
 FCEUI_SetPaletteArray(tmpp);
 fclose(fp);
}
#ifdef EXTGUI
extern CFGSTRUCT GUIConfig;
#endif
static CFGSTRUCT fceuconfig[]={
	AC(soundrate),
	AC(soundq),
	AC(_sound),
	AC(soundvol),
	AC(soundbufsize),
	ACS(cpalette),
	AC(ntsctint),
	AC(ntschue),
	AC(ntsccol),
	AC(eoptions),
	ACA(srendlinev),
	ACA(erendlinev),
	ADDCFGSTRUCT(InputConfig),
	ADDCFGSTRUCT(DriverConfig),
	#ifdef EXTGUI
	ADDCFGSTRUCT(GUIConfig),
	#endif
	ENDCFGSTRUCT
};

static void SaveConfig(void)
{	
	char tdir[2048];
	sprintf(tdir,"%s"PSS"fceu98.cfg",DrBaseDirectory);
	FCEUI_GetNTSCTH(&ntsctint, &ntschue);
        SaveFCEUConfig(tdir,fceuconfig);
}

static void LoadConfig(void)
{
	char tdir[2048];
        sprintf(tdir,"%s"PSS"fceu98.cfg",DrBaseDirectory);
	FCEUI_GetNTSCTH(&ntsctint, &ntschue);	/* Get default settings for if
					   no config file exists. */
        LoadFCEUConfig(tdir,fceuconfig);
	InputUserActiveFix();
}

static void CreateDirs(void)
{
 char *subs[7]={"fcs","fcm","snaps","gameinfo","sav","cheats","movie"};
 char tdir[2048];
 int x;

 #ifdef WIN32
 mkdir(DrBaseDirectory);
 for(x=0;x<6;x++)
 {
  sprintf(tdir,"%s"PSS"%s",DrBaseDirectory,subs[x]);
  mkdir(tdir);
 }
 #else
 mkdir(DrBaseDirectory,S_IRWXU);
 for(x=0;x<6;x++)
 {
  sprintf(tdir,"%s"PSS"%s",DrBaseDirectory,subs[x]);
  mkdir(tdir,S_IRWXU);
 }
 #endif
}

#ifndef WIN32
static void SetSignals(void (*t)(int))
{
  int sigs[11]={SIGINT,SIGTERM,SIGHUP,SIGPIPE,SIGSEGV,SIGFPE,SIGKILL,SIGALRM,SIGABRT,SIGUSR1,SIGUSR2};
  int x;
  for(x=0;x<11;x++)
   signal(sigs[x],t);
}

static void CloseStuff(int signum)
{
	DriverKill();
        printf("\nSignal %d has been caught and dealt with...\n",signum);
        switch(signum)
        {
         case SIGINT:printf("How DARE you interrupt me!\n");break;
         case SIGTERM:printf("MUST TERMINATE ALL HUMANS\n");break;
         case SIGHUP:printf("Reach out and hang-up on someone.\n");break;
         case SIGPIPE:printf("The pipe has broken!  Better watch out for floods...\n");break;
         case SIGSEGV:printf("Iyeeeeeeeee!!!  A segmentation fault has occurred.  Have a fluffy day.\n");break;
	 /* So much SIGBUS evil. */
	 #ifdef SIGBUS
	 #if(SIGBUS!=SIGSEGV)
         case SIGBUS:printf("I told you to be nice to the driver.\n");break;
	 #endif
	 #endif
         case SIGFPE:printf("Those darn floating points.  Ne'er know when they'll bite!\n");break;
         case SIGALRM:printf("Don't throw your clock at the meowing cats!\n");break;
         case SIGABRT:printf("Abort, Retry, Ignore, Fail?\n");break;
         case SIGUSR1:
         case SIGUSR2:printf("Killing your processes is not nice.\n");break;
        }
        exit(1);
}
#endif

static void DoArgs(int argc, char *argv[])
{
	int x;

        static ARGPSTRUCT FCEUArgs[]={
	 {"-soundbufsize",0,&soundbufsize,0},
	 {"-soundrate",0,&soundrate,0},
	 {"-soundq",0,&soundq,0},
#ifdef FRAMESKIP
	 {"-frameskip",0,&frameskip,0},
#endif
         {"-sound",0,&_sound,0},
         {"-soundvol",0,&soundvol,0},
         {"-cpalette",0,&cpalette,0x4001},
	 {"-soundrecord",0,&soundrecfn,0x4001},

         {"-ntsccol",0,&ntsccol,0},
         {"-pal",0,&eoptions,0x8000|EO_PAL},

	 {"-lowpass",0,&eoptions,0x8000|EO_LOWPASS},
         {"-gg",0,&eoptions,0x8000|EO_GAMEGENIE},
         {"-no8lim",0,&eoptions,0x8001},
         {"-snapname",0,&eoptions,0x8000|EO_SNAPNAME},
	 {"-nofs",0,&eoptions,0x8000|EO_NOFOURSCORE},
         {"-clipsides",0,&eoptions,0x8000|EO_CLIPSIDES},
	 {"-nothrottle",0,&eoptions,0x8000|EO_NOTHROTTLE},
         {"-slstart",0,&srendlinev[0],0},{"-slend",0,&erendlinev[0],0},
         {"-slstartp",0,&srendlinev[1],0},{"-slendp",0,&erendlinev[1],0},
	 {0,(int *)InputArgs,0,0},
	 {0,(int *)DriverArgs,0,0},
	 {0,0,0,0}
        };

	ParseArguments(argc, argv, FCEUArgs);
	if(cpalette)
	{
  	 if(cpalette[0]=='0')
	  if(cpalette[1]==0)
	  {
	   free(cpalette);
	   cpalette=0;
	  }
	}
	FCEUI_SetVidSystem((eoptions&EO_PAL)?1:0);
	FCEUI_SetGameGenie((eoptions&EO_GAMEGENIE)?1:0);
	FCEUI_SetLowPass((eoptions&EO_LOWPASS)?1:0);

        FCEUI_DisableSpriteLimitation(eoptions&1);
	FCEUI_SetSnapName(eoptions&EO_SNAPNAME);

	for(x=0;x<2;x++)
	{
         if(srendlinev[x]<0 || srendlinev[x]>239) srendlinev[x]=0;
         if(erendlinev[x]<srendlinev[x] || erendlinev[x]>239) erendlinev[x]=239;
	}

        FCEUI_SetRenderedLines(srendlinev[0],erendlinev[0],srendlinev[1],erendlinev[1]);
	DoDriverArgs();
}

#include "usage.h"

/* Loads a game, given a full path/filename.  The driver code must be
   initialized after the game is loaded, because the emulator code
   provides data necessary for the driver code(number of scanlines to
   render, what virtual input devices to use, etc.).
*/
int LoadGame(const char *path)
{
	FCEUGI *tmp;

	CloseGame();
        if(!(tmp=FCEUI_LoadGame(path,1)))
	 return 0;
	CurGame=tmp;
        ParseGI(tmp);
        RefreshThrottleFPS();

        if(!DriverInitialize(tmp))
         return(0);  
	if(soundrecfn)
	{
	 if(!FCEUI_BeginWaveRecord(soundrecfn))
	 {
 	  free(soundrecfn);
	  soundrecfn=0;
	 }
	}
	isloaded=1;
	#ifdef EXTGUI
	if(eoptions&EO_AUTOHIDE) GUI_Hide(1);
	#endif

	FCEUD_NetworkConnect();
	return 1;
}

/* Closes a game.  Frees memory, and deinitializes the drivers. */
int CloseGame(void)
{
	if(!isloaded) return(0);
	FCEUI_CloseGame();
	DriverKill();
	isloaded=0;
	CurGame=0;

	if(soundrecfn)
         FCEUI_EndWaveRecord();

	#ifdef EXTGUI
	GUI_Hide(0);
	#endif
	InputUserActiveFix();
	return(1);
}

void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count);

void DoFun(void)
{
         uint8 *gfx;  
         int32 *sound;
         int32 ssize;
         static int fskipc=0;
         static int opause=0;
         
         #ifdef FRAMESKIP
         fskipc=(fskipc+1)%(frameskip+1);
         #endif
         
         if(NoWaiting) {gfx=0;}
         FCEUI_Emulate(&gfx, &sound, &ssize, fskipc);
         FCEUD_Update(gfx, sound, ssize);

         if(opause!=FCEUI_EmulationPaused())
         {
          opause=FCEUI_EmulationPaused();
		  SilenceSound(opause);
         }
}   

int CLImain(int argc, char *argv[])
{
	int ret;

	if(!(ret=FCEUI_Initialize()))
         return(0);

        DrBaseDirectory=GetBaseDirectory();
	FCEUI_SetBaseDirectory(DrBaseDirectory);

	CreateDirs();

	#ifdef EXTGUI
	if(argc==2 && !strcmp(argv[1],"-help")) // I hope no one has a game named "-help" :b
	#else
        if(argc<=1) 
	#endif
        {
         ShowUsage(argv[0]);
         return(0);
        }

        LoadConfig();
        DoArgs(argc-2,&argv[1]);
	FCEUI_SetNTSCTH(ntsccol, ntsctint, ntschue);
	if(cpalette)
	 LoadCPalette();

	/* All the config files and arguments are parsed now. */
	#ifdef EXTGUI
        return(1);

	#else
        if(!LoadGame(argv[argc-1]))
        {
         DriverKill();
         return(0);
        }

	while(CurGame)
	 DoFun();

	#if(0)
	{
	 int x;
	 for(x=1;x<argc;x++) 
         { LoadGame(argv[x]); while(CurGame) DoFun(); }
	}
	#endif

        CloseGame();
        
	SaveConfig();

        FCEUI_Kill();

	#endif
        return(1);
}

static int DriverInitialize(FCEUGI *gi)
{
	#ifndef WIN32
	SetSignals(CloseStuff);
	#endif

	/* Initialize video before all else, due to some wacko dependencies
	   in the SexyAL code(DirectSound) that need to be fixed.
	*/

        if(!InitVideo(gi)) return 0;
        inited|=4;

	if(InitSound(gi))
	 inited|=1;

	if(InitJoysticks())
	 inited|=2;

	if(!InitKeyboard()) return 0;
	inited|=8;

	InitOtherInput();
	return 1;
}

static void DriverKill(void)
{
 SaveConfig();

 #ifndef WIN32
 SetSignals(SIG_IGN);
 #endif

 if(inited&2)
  KillJoysticks();
 if(inited&8)
  KillKeyboard();
 if(inited&4)
  KillVideo();
 if(inited&1)
  KillSound();
 if(inited&16)
  KillMouse();
 inited=0;
}

void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count)
{
 #ifdef NETWORK
 extern int FCEUDnetplay;
 #endif

 int ocount = Count;
 // apply frame scaling to Count
 Count = (Count<<8)/fps_scale;
 if(Count)
 {
  int32 can=GetWriteSound();
  static int uflow=0;
  int32 tmpcan;

  // don't underflow when scaling fps
  if(can >= GetMaxSound() && fps_scale<=256) uflow=1;	/* Go into massive underflow mode. */

  if(can > Count) can=Count;
  else uflow=0;

  WriteSound(Buffer,can);

  //if(uflow) puts("Underflow");
  tmpcan = GetWriteSound();
  // don't underflow when scaling fps
  if(fps_scale>256 || ((tmpcan < Count*0.90) && !uflow))
  {
   if(XBuf && (inited&4) && !(NoWaiting & 2))
    BlitScreen(XBuf);
   Buffer+=can;
   Count-=can;
   if(Count)
   {
    if(NoWaiting)
    {
     can=GetWriteSound(); 
     if(Count>can) Count=can;
     WriteSound(Buffer,Count);
    }
    else
    {
     while(Count>0)
     {
      WriteSound(Buffer,(Count<ocount) ? Count : ocount);
      Count -= ocount;
     }
    }
   }
  } //else puts("Skipped");
  #ifdef NETWORK
  else if(!NoWaiting && FCEUDnetplay && (uflow || tmpcan >= (Count * 1.8)))
  {
   if(Count > tmpcan) Count=tmpcan;
   while(tmpcan > 0)
   {
//    printf("Overwrite: %d\n", (Count <= tmpcan)?Count : tmpcan);
    WriteSound(Buffer, (Count <= tmpcan)?Count : tmpcan);
    tmpcan -= Count;
   }
  }
  #endif

 }
 else
 {
  if(!NoWaiting && (!(eoptions&EO_NOTHROTTLE) || FCEUI_EmulationPaused()))
   SpeedThrottle();
  if(XBuf && (inited&4))
  {
   BlitScreen(XBuf);
  }
 }
 FCEUD_UpdateInput();
 //if(!Count && !NoWaiting && !(eoptions&EO_NOTHROTTLE))
 // SpeedThrottle();
 //if(XBuf && (inited&4))
 //{
 // BlitScreen(XBuf);
 //}
 //if(Count)
 // WriteSound(Buffer,Count,NoWaiting);
 //FCEUD_UpdateInput();
}


/* Maybe ifndef WXWINDOWS would be better? ^_^ */
#ifndef EXTGUI
FILE *FCEUD_UTF8fopen(const char *fn, const char *mode)
{
 return(fopen(fn,mode));
}


#endif
