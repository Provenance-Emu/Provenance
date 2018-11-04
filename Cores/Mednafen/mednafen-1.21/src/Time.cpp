/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Time.cpp:
**  Copyright (C) 2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include <mednafen/mednafen.h>
#include <mednafen/string/string.h>
#include "Time.h"

#if defined(WIN32)
 #include <windows.h>
#endif

namespace Time
{

static bool Initialized = false;

#if defined(WIN32)
 static uint32 tgt_base;
#else
 static struct timespec cgt_base;
#endif

void Time_Init(void)
{
 #ifdef WIN32
  tgt_base = timeGetTime();
 #else
  if(MDFN_UNLIKELY(clock_gettime(CLOCK_MONOTONIC, &cgt_base) == -1))
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "clock_gettime()", ene.StrError());
  }
 #endif
 Initialized = true;
}

int64 EpochTime(void)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

#ifdef WIN32
 __time64_t ret = _time64(nullptr);

 if(ret == -1)
 {
  ErrnoHolder ene(errno);
  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "_time64()", ene.StrError());
 }
#else
 time_t ret = time(nullptr);

 if(ret == (time_t)-1)
 {
  ErrnoHolder ene(errno);
  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "time()", ene.StrError());
 }
#endif

 return (int64)ret;
}

struct tm LocalTime(const int64 ept)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

 struct tm tout;

#ifdef WIN32
 __time64_t tt = (__time64_t)ept;
 struct tm* tr;
 if(!(tr = _localtime64(&tt)))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "_localtime64()", ene.StrError());
 }
 memcpy(&tout, tr, sizeof(struct tm));
#else
 time_t tt = (time_t)ept;

 #ifdef HAVE_LOCALTIME_R
 if(!localtime_r(&tt, &tout))
 {
  ErrnoHolder ene(errno);
  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "localetime_r()", ene.StrError());
 }
 #else
 struct tm* tr;
 if(!(tr = localtime(&tt)))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "localtime()", ene.StrError());
 }
 memcpy(&tout, tr, sizeof(struct tm));
 #endif
#endif

 return tout;
}

struct tm UTCTime(const int64 ept)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

 struct tm tout;

#ifdef WIN32
 __time64_t tt = (__time64_t)ept;
 struct tm* tr;
 if(!(tr = _gmtime64(&tt)))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "_gmtime64()", ene.StrError());
 }
 memcpy(&tout, tr, sizeof(struct tm));
#else
 time_t tt = (time_t)ept;

 #ifdef HAVE_GMTIME_R
 if(!gmtime_r(&tt, &tout))
 {
  ErrnoHolder ene(errno);
  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "gmtime_r()", ene.StrError());
 }
 #else
 struct tm* tr;
 if(!(tr = gmtime(&tt)))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "gmtime()", ene.StrError());
 }
 memcpy(&tout, tr, sizeof(struct tm));
 #endif
#endif

 return tout;
}

std::string StrTime(const char* format, const struct tm& tin)
{
 #ifdef WIN32
 std::u16string ret((size_t)256, 0);
 size_t rv;
 std::u16string formatadj = UTF8_to_UTF16(format) + u"!";

 while(!(rv = wcsftime((wchar_t*)&ret[0], ret.size(), (const wchar_t*)formatadj.c_str(), &tin)))
  ret.resize(ret.size() * 2);

 ret.resize(rv - 1);

 return UTF16_to_UTF8(ret);
 #else
 std::string ret((size_t)256, 0);
 size_t rv;
 std::string formatadj = std::string(format) + "!";

 while(!(rv = strftime(&ret[0], ret.size(), formatadj.c_str(), &tin)))
  ret.resize(ret.size() * 2);

 ret.resize(rv - 1);

 return ret;
 #endif
}

int64 MonoUS(void)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

 #if defined(WIN32)
 {
  return (int64)1000 * (timeGetTime() - tgt_base);
 }
 #else
 {
  struct timespec tp;

  if(MDFN_UNLIKELY(clock_gettime(CLOCK_MONOTONIC, &tp) == -1))
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "clock_gettime()", ene.StrError());
  }

  return (int64)(tp.tv_sec - cgt_base.tv_sec) * 1000 * 1000 + (tp.tv_nsec - cgt_base.tv_nsec) / 1000;
 }
 #endif
}

uint32 MonoMS(void)
{
 return MonoUS() / 1000;
}

void SleepMS(uint32 amount) noexcept
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

 #if defined(WIN32)
  Sleep(amount);
 #else
 {
  struct timespec want, rem;

  want.tv_sec = amount / 1000;
  want.tv_nsec = (amount % 1000) * 1000 * 1000;

  nanosleep(&want, &rem);
 }
 #endif
}

}
