#include <sys/time.h>
#include "main.h"
#include "throttle.h"

static uint64 tfreq;
static uint64 desiredfps;

void RefreshThrottleFPS(void)
{
 desiredfps=FCEUI_GetDesiredFPS()>>8;
 tfreq=1000000;
 tfreq<<=16;    /* Adjustment for fps returned from FCEUI_GetDesiredFPS(). */
}

static uint64 GetCurTime(void)
{
 uint64 ret;
 struct timeval tv;

 gettimeofday(&tv,0);
 ret=(uint64)tv.tv_sec*1000000;
 ret+=tv.tv_usec;
 return(ret);
}

void SpeedThrottle(void)
{
 static uint64 ttime,ltime=0;

 waiter:

 ttime=GetCurTime();

 if( (ttime-ltime) < (tfreq/desiredfps) )
  goto waiter;
 if( (ttime-ltime) >= (tfreq*4/desiredfps))
  ltime=ttime;
 else
  ltime+=tfreq/desiredfps;
}

