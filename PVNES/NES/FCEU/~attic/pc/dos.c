#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <crt0.h>
#include <sys/farptr.h>
#include <go32.h>

#include "dos.h"
#include "dos-joystick.h"
#include "dos-video.h"
#include "dos-sound.h"
#include "../common/args.h"
#include "../common/config.h"

/* _CRT0_FLAG_LOCK_MEMORY might not always result in all memory being locked.
   Bummer.  I'll add code to explicitly lock the data touched by the sound
   interrupt handler(and the handler itself), if necessary(though that might
   be tricky...).  I'll also to cover the data the keyboard
   interrupt handler touches.
*/

int _crt0_startup_flags = _CRT0_FLAG_FILL_SBRK_MEMORY | _CRT0_FLAG_LOCK_MEMORY | _CRT0_FLAG_USE_DOS_SLASHES;

static int f8bit=0;
int soundo=44100;
int doptions=0;


CFGSTRUCT DriverConfig[]={
        NAC("sound",soundo),
        AC(doptions),
        AC(f8bit),
        AC(FCEUDvmode),
        NACA("joybmap",joyBMap),
        AC(joy),
        ENDCFGSTRUCT
};

char *DriverUsage=
"-vmode x        Select video mode(all are 8 bpp).\n\
                 1 = 256x240                 6 = 256x224(with scanlines)\n\
                 2 = 256x256                 8 = 256x224\n\
                 3 = 256x256(with scanlines)\n\
-vsync x        Wait for the screen's vertical retrace before updating the\n\
                screen.  Refer to the documentation for caveats.\n\
                 0 = Disabled.\n\
                 1 = Enabled.\n\
-sound x        Sound.\n\
                 0 = Disabled.\n\
                 Otherwise, x = playback rate.\n\
-f8bit x        Force 8-bit sound.\n\
                 0 = Disabled.\n\
                 1 = Enabled.";

ARGPSTRUCT DriverArgs[]={
         {"-vmode",0,&FCEUDvmode,0},
         {"-sound",0,&soundo,0},
         {"-f8bit",0,&f8bit,0},
         {"-vsync",0,&doptions,DO_VSYNC},
         {0,0,0,0}
};

void DoDriverArgs(void)
{
        if(!joy) memset(joyBMap,0,sizeof(joyBMap));
}

int InitSound(void)
{
 if(soundo)
 {
  if(soundo==1)
   soundo=44100;
  soundo=InitSB(soundo,f8bit?0:1);
  FCEUI_Sound(soundo);
 }
 return(soundo);
}

void WriteSound(int32 *Buffer, int Count, int NoWaiting)
{
 WriteSBSound(Buffer,Count,NoWaiting);
}

void KillSound(void)
{
 if(soundo)
  KillSB();
}

void DOSMemSet(uint32 A, uint8 V, uint32 count)
{
 uint32 x;

 _farsetsel(_dos_ds);
 for(x=0;x<count;x++)
  _farnspokeb(A+x,V);
}

static char *arg0;
uint8 *GetBaseDirectory(void)
{
 int x=0;
 uint8 *ret = 0;

 if(arg0)
  for(x=strlen(arg0);x>=0;x--)
  {
   if(arg0[x]=='/' || arg0[x]=='\\')
   {
    ret = malloc(x + 1);
    strncpy(ret,arg0,x);
    break;
   }
  }

 if(!ret) { x=0; ret = malloc(1); }

 BaseDirectory[x]=0;
}

int main(int argc, char *argv[])
{
        puts("\nStarting FCE Ultra "VERSION_STRING"...\n");
	arg0=argv[0];
        return(CLImain(argc,argv));
}

