/* Mednafen Network Play Server
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <unistd.h>
#include <time.h>
#include <sys/types.h>
#include <sys/time.h>
#include <stdio.h>
#include <errno.h>  
#include <string.h>

#include "types.h"
#include "time64.h"

// Returns (preferably-monotonic) time in microseconds.
int64 MBL_Time64(void)
{
 static bool cgt_fail_warning = 0;

 #if HAVE_CLOCK_GETTIME && ( _POSIX_MONOTONIC_CLOCK > 0 || defined(CLOCK_MONOTONIC))
 struct timespec tp;

 if(clock_gettime(CLOCK_MONOTONIC, &tp) == -1)
 {
  if(!cgt_fail_warning)
   printf("clock_gettime() failed: %s\n", strerror(errno));
  cgt_fail_warning = 1;
 }
 else
  return((int64)tp.tv_sec * (1000 * 1000) + tp.tv_nsec / 1000);

 #else
   #warning "clock_gettime() with CLOCK_MONOTONIC not available"
 #endif


 #if HAVE_GETTIMEOFDAY
 // Warning: gettimeofday() is not guaranteed to be monotonic!!
 struct timeval tv;

 if(gettimeofday(&tv, NULL) == -1)
 {
  puts("gettimeofday() error");
  return(0);
 }

 return((int64)tv.tv_sec * 1000000 + tv.tv_usec);
 #else
  #warning "gettimeofday() not available!!!"
 #endif

 // Yeaaah, this isn't going to work so well.
 return((int64)time(NULL) * 1000000);
}

// Not guaranteed to sleep specified time, but should try not to sleep more than 1millisecond extra, mostly used for reducing CPU usage.
void MBL_Sleep64(int64 microseconds)
{
 #if HAVE_NANOSLEEP
 {
  struct timespec tts;

  tts.tv_sec = microseconds / (1000 * 1000);
  tts.tv_nsec = 1000 * (microseconds - (tts.tv_sec * (1000 * 1000)));

  //printf("%lld %lld %lld\n", microseconds, tts.tv_sec, tts.tv_nsec);

  nanosleep(&tts, NULL);
 }
 #elif HAVE_USLEEP
 usleep(microseconds);
 #else

 #endif
}
