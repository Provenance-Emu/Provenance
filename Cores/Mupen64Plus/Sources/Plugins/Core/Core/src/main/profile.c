/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - profile.c                                               *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
 *   Copyright (C) 2012 CasualJames                                        *
 *   Copyright (C) 2002 Hacktarux                                          *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include "profile.h"

#include "api/callbacks.h"
#include "api/m64p_types.h"

static long long int time_in_section[NUM_TIMED_SECTIONS];
static long long int last_start[NUM_TIMED_SECTIONS];

#if defined(WIN32) && !defined(__MINGW32__)
  // timing
  #include <windows.h>

  static long long int get_time(void)
  {
      LARGE_INTEGER counter;
      QueryPerformanceCounter(&counter);
      return counter.QuadPart;
  }
  static long long int time_to_nsec(long long int time)
  {
      static LARGE_INTEGER freq = { 0 };
      if (freq.QuadPart == 0)
          QueryPerformanceFrequency(&freq);
      return time * 1000000000 / freq.QuadPart;
  }

#else  /* Not WIN32 */
  // timing
  #include <time.h>

  static long long int get_time(void)
  {
     struct timespec ts;
     clock_gettime(CLOCK_MONOTONIC, &ts);
     return (long long int)ts.tv_sec * 1000000000 + ts.tv_nsec;
  }
  static long long int time_to_nsec(long long int time)
  {
      return time;
  }
#endif

void timed_section_start(enum timed_section section)
{
   last_start[section] = get_time();
}

void timed_section_end(enum timed_section section)
{
   long long int end = get_time();
   time_in_section[section] += end - last_start[section];
}

void timed_sections_refresh()
{
   long long int curr_time = get_time();
   if(time_to_nsec(curr_time - last_start[TIMED_SECTION_ALL]) >= 2000000000)
   {
      time_in_section[TIMED_SECTION_ALL] = curr_time - last_start[TIMED_SECTION_ALL];
      DebugMessage(M64MSG_INFO, "gfx=%f%% - audio=%f%% - compiler=%f%%, idle=%f%%",
         100.0 * (double)time_in_section[TIMED_SECTION_GFX] / time_in_section[TIMED_SECTION_ALL],
         100.0 * (double)time_in_section[TIMED_SECTION_AUDIO] / time_in_section[TIMED_SECTION_ALL],
         100.0 * (double)time_in_section[TIMED_SECTION_COMPILER] / time_in_section[TIMED_SECTION_ALL],
         100.0 * (double)time_in_section[TIMED_SECTION_IDLE] / time_in_section[TIMED_SECTION_ALL]);
      DebugMessage(M64MSG_INFO, "gfx=%llins - audio=%llins - compiler %llins - idle=%llins",
         time_to_nsec(time_in_section[TIMED_SECTION_GFX]),
         time_to_nsec(time_in_section[TIMED_SECTION_AUDIO]),
         time_to_nsec(time_in_section[TIMED_SECTION_COMPILER]),
         time_to_nsec(time_in_section[TIMED_SECTION_IDLE]));
      time_in_section[TIMED_SECTION_GFX] = 0;
      time_in_section[TIMED_SECTION_AUDIO] = 0;
      time_in_section[TIMED_SECTION_COMPILER] = 0;
      time_in_section[TIMED_SECTION_IDLE] = 0;
      last_start[TIMED_SECTION_ALL] = curr_time;
   }
}
