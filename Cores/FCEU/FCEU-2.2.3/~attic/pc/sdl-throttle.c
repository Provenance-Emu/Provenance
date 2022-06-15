#include "sdl.h"
#include "throttle.h"

static uint64 tfreq;
static uint64 desiredfps;

static int32 fps_scale_table[]=
{ 3, 3, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 2048 };
int32 fps_scale = 256;

#define fps_table_size          (sizeof(fps_scale_table)/sizeof(fps_scale_table[0]))

void RefreshThrottleFPS(void)
{
       desiredfps=FCEUI_GetDesiredFPS()>>8;
       desiredfps=(desiredfps*fps_scale)>>8;
       tfreq=10000000;
       tfreq<<=16;    /* Adjustment for fps returned from FCEUI_GetDesiredFPS(). */
}

void SpeedThrottle(void)
{
 static uint64 ttime,ltime=0;
  
 waiter:
 
 ttime=SDL_GetTicks();
 ttime*=10000;

 if( (ttime-ltime) < (tfreq/desiredfps) )
 {
  int64 delay;
  delay=(tfreq/desiredfps)-(ttime-ltime);
  if(delay>0) 
   SDL_Delay(delay/10000);
  //printf("%d\n",(tfreq/desiredfps)-(ttime-ltime));
  //SDL_Delay((tfreq/desiredfps)-(ttime-ltime));
  goto waiter;
 }
 if( (ttime-ltime) >= (tfreq*4/desiredfps))
  ltime=ttime;
 else
  ltime+=tfreq/desiredfps;
}

void IncreaseEmulationSpeed(void)
{
 int i;
 for(i=1; fps_scale_table[i]<fps_scale; i++)
  ;
 fps_scale = fps_scale_table[i+1];

 RefreshThrottleFPS();

 FCEU_DispMessage("emulation speed %d%%",(fps_scale*100)>>8);
}

void DecreaseEmulationSpeed(void)
{
 int i;
 for(i=1; fps_scale_table[i]<fps_scale; i++)
  ;
 fps_scale = fps_scale_table[i-1];

 RefreshThrottleFPS();

 FCEU_DispMessage("emulation speed %d%%",(fps_scale*100)>>8);
}

void FCEUD_SetEmulationSpeed(int cmd)
{
	switch(cmd)
	{
	case EMUSPEED_SLOWEST:	fps_scale=fps_scale_table[0];  break;
	case EMUSPEED_SLOWER:	DecreaseEmulationSpeed(); break;
	case EMUSPEED_NORMAL:	fps_scale=256; break;
	case EMUSPEED_FASTER:	IncreaseEmulationSpeed(); break;
	case EMUSPEED_FASTEST:	fps_scale=fps_scale_table[fps_table_size-1]; break;
	default:
		return;
	}

	RefreshThrottleFPS();

	FCEU_DispMessage("emulation speed %d%%",(fps_scale*100)>>8);
}
