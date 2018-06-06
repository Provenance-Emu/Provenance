/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Time.h:
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

#ifndef __MDFN_TIME_H
#define __MDFN_TIME_H

#include <mednafen/types.h>

#include <time.h>

namespace Time
{
 void Time_Init(void) MDFN_COLD;

 int64 EpochTime(void);
 struct tm LocalTime(const int64 ept);
 static INLINE struct tm LocalTime(void) { return LocalTime(EpochTime()); }

 struct tm UTCTime(const int64 ept);
 static INLINE struct tm UTCTime(void) { return UTCTime(EpochTime()); }

 std::string StrTime(const char* format, const struct tm& tin);
 static INLINE std::string StrTime(const char* format) { return StrTime(format, LocalTime()); }
 static INLINE std::string StrTime(const struct tm& tin) { return StrTime("%c", tin); }
 static INLINE std::string StrTime(void) { return StrTime("%c", LocalTime()); }

 uint32 MonoMS(void);	// Milliseconds
 int64 MonoUS(void);	// Microseconds
 void SleepMS(uint32) noexcept;	// Sleep for approximately the time specified in milliseconds.
}


#endif
