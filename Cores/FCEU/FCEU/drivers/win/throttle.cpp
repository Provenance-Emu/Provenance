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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "../../types.h"
#include "../../fceu.h"
#include "windows.h"
#include "driver.h"

static uint64 tmethod,tfreq;
static uint64 desiredfps;
int32 fps_scale = 256;
int32 fps_scale_unpaused = 256;
int32 fps_scale_frameadvance = 0;

static int32 fps_scale_table[] = { 3, 3, 4, 8, 16, 32, 64, 128, 192, 256, 384, 512, 768, 1024, 2048, 4096, 8192, 16384, 16384};
#define fps_table_size		(sizeof(fps_scale_table) / sizeof(fps_scale_table[0]))

void RefreshThrottleFPS(void)
{
 desiredfps=FCEUI_GetDesiredFPS()>>8;
 desiredfps=(desiredfps*fps_scale)>>8;
}

static uint64 GetCurTime(void)
{
 if(tmethod)
 {
  uint64 tmp;

  /* Practically, LARGE_INTEGER and uint64 differ only by signness and name. */
  QueryPerformanceCounter((LARGE_INTEGER*)&tmp);

  return(tmp);
 }
 else
  return((uint64)GetTickCount());

}

void InitSpeedThrottle(void)
{
 tmethod=0;
 if(QueryPerformanceFrequency((LARGE_INTEGER*)&tfreq))
 {
  tmethod=1;
 }
 else
  tfreq=1000;
 tfreq<<=16;    /* Adjustment for fps returned from FCEUI_GetDesiredFPS(). */
}


int SpeedThrottle(void)
{
 static uint64 ttime,ltime;

 waiter:

 ttime=GetCurTime();

                            
 if( (ttime-ltime) < (tfreq/desiredfps) )
 {
  uint64 sleepy;
  sleepy=(tfreq/desiredfps)-(ttime-ltime);  
  sleepy*=1000;
  if(tfreq>=65536)
	  sleepy/=tfreq>>16;
  else
      sleepy=0;
  if(sleepy>100)
  {
   // block for a max of 100ms to
   // keep the gui responsive
   Sleep(100);
   return 1;
  }
  Sleep(sleepy);
  goto waiter;
 }
 if( (ttime-ltime) >= (tfreq*4/desiredfps))
  ltime=ttime;
 else
 {
  ltime+=tfreq/desiredfps;

  if( (ttime-ltime) >= (tfreq/desiredfps) ) // Oops, we're behind!
  return(1);
 }
 return(0);
}

// Quick code for internal FPS display.
uint64 FCEUD_GetTime(void)
{
 return(GetCurTime());
}
uint64 FCEUD_GetTimeFreq(void)
{
 return(tfreq>>16);
}

static void IncreaseEmulationSpeed(void)
{
 int i;
 for(i = 1; fps_scale_table[i] < fps_scale_unpaused; i++)
  ;
 fps_scale = fps_scale_unpaused = fps_scale_table[i+1];
}

static void DecreaseEmulationSpeed(void)
{
 int i;
 for(i = 1; fps_scale_table[i] < fps_scale_unpaused; i++)
  ;
 fps_scale = fps_scale_unpaused = fps_scale_table[i-1];
}

void FCEUD_SetEmulationSpeed(int cmd)
{
	switch(cmd)
	{
	case EMUSPEED_SLOWEST:	fps_scale = fps_scale_unpaused = fps_scale_table[0];  break;
	case EMUSPEED_SLOWER:	DecreaseEmulationSpeed(); break;
	case EMUSPEED_NORMAL:	fps_scale = fps_scale_unpaused = 256; break;
	case EMUSPEED_FASTER:	IncreaseEmulationSpeed(); break;
	case EMUSPEED_FASTEST:	fps_scale = fps_scale_unpaused = fps_scale_table[fps_table_size - 1]; break;
	default:
		return;
	}

	RefreshThrottleFPS();
	FCEU_DispMessage("Emulation speed %d%%", 0, (fps_scale_unpaused * 100) >> 8);
}
