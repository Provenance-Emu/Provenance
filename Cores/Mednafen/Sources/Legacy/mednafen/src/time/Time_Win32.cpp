/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Time_Win32.cpp:
**  Copyright (C) 2017-2020 Mednafen Team
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
#include <mednafen/win32-common.h>
#include <mednafen/Time.h>

namespace Mednafen
{

namespace Time
{

static bool Initialized = false;
static uint32 tgt_base;
static BOOL WINAPI (*p_GetTimeZoneInformationForYear)(USHORT, PDYNAMIC_TIME_ZONE_INFORMATION, LPTIME_ZONE_INFORMATION);

void Time_Init(void)
{
 tgt_base = timeGetTime();

 p_GetTimeZoneInformationForYear = (decltype(p_GetTimeZoneInformationForYear))Win32Common::GetProcAddress_TOE(Win32Common::GetModuleHandle_TOE(TEXT("kernel32.dll")), "GetTimeZoneInformationForYear");
 //
 Initialized = true;
}

int64 MonoUS(void)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

 return (int64)1000 * (timeGetTime() - tgt_base);
}

void SleepMS(uint32 amount) noexcept
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();

 Sleep(amount);
}

/*
static struct tm SystemTimeToTM(const SYSTEMTIME* syst, const int isdst)
{
 static const int tab[12] = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
 struct tm ret;
 int yday;

 yday = tab[syst->wMonth - 1] + (syst->wDay - 1);
 if(syst->wMonth > 2 && !(syst->wYear & 0x3))
 {
  if((syst->wYear % 100) || !(syst->wYear % 400))
   yday++;
 }

 memset(&ret, 0, sizeof(ret));
 ret.tm_sec = syst->wSecond;
 ret.tm_min = syst->wMinute;
 ret.tm_hour = syst->wHour;
 ret.tm_mday = syst->wDay;
 ret.tm_mon = syst->wMonth - 1;
 ret.tm_year = syst->wYear - 1900;
 ret.tm_wday = syst->wDayOfWeek;
 ret.tm_yday = yday;
 ret.tm_isdst = isdst;

 return ret;
}

static INLINE FILETIME EpochTimeToFileTime(int64 ept)
{
 FILETIME ft;
 int64 tmp;

 tmp = (ept + 11644473600) * 10000000;

 ft.dwHighDateTime = tmp >> 32;
 ft.dwLowDateTime = tmp >> 0;

 return ft;
}
*/
static INLINE int64 FileTimeToEpochTime(const FILETIME& ft)
{
 return (int64)((((uint64)ft.dwHighDateTime << 32) + ft.dwLowDateTime) / 10000000) - 11644473600;
}

int64 EpochTime(void)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();
 //
 FILETIME ft;

 memset(&ft, 0, sizeof(ft));
 GetSystemTimeAsFileTime(&ft);

 return FileTimeToEpochTime(ft);
}
//
//
//
//
//
enum : int32 { days_per_400_years = 146097 };
enum : int32 { days_per_normal_year = 365 };
enum : int32 { days_per_leap_year = 366 };
enum : int32 { days_per_first_100_of_400_years = 36525 };
enum : int32 { days_per_other_100_of_400_years = 36524 };
enum : int32 { seconds_per_day = 60 * 60 * 24 };
enum : int64 { seconds_from_year_0_to_epoch = 62167219200LL };

enum : int64 { wtfbbq = -(int64)(((uint64)1 << 63) / ((uint64)days_per_400_years * seconds_per_day) * 400) };
enum : int64 { days_from_wtfbbq_to_year_0 = (-wtfbbq / 400) * days_per_400_years };
enum : int64 { seconds_from_wtfbbq_to_year_0 = (int64)days_from_wtfbbq_to_year_0 * seconds_per_day };
enum : uint64 { wtfbbq_ept_bias = (uint64)seconds_from_wtfbbq_to_year_0 + seconds_from_year_0_to_epoch };

static const unsigned month_day_offset[2][12] = 
{
 { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 },
 { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335 },
};

static const unsigned month_day_count[2][12] =
{
 { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
 { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
};

static uint64 GetDaysSinceWTFBBQ(int64 year_in)
{
 uint64 year = year_in - wtfbbq;
 uint64 days = 0;

 if(year >= 400)
  days += (year / 400) * days_per_400_years;

 year %= 400;

 if(year >= 100)
 {
  year -= 100;
  days += (year / 100) * days_per_other_100_of_400_years + days_per_first_100_of_400_years;
  year = year % 100;

  if(year >= 4)
  {
   year -= 4;
   days += 4 * days_per_normal_year + (year * (365 * 4 + 1) + 3) / 4;
  }
  else
   days += year * days_per_normal_year;
 }
 else
  days += (year * (365 * 4 + 1) + 3) / 4;

 return days;
}

static int GetFirstDayOfWeekForYear(int64 year)
{
 return (GetDaysSinceWTFBBQ(year) + 6) % 7;
}

static bool IsLeapYear(int64 year)
{
 return !(year & 0x3) && ((year % 100) || !(year % 400));
}

static int GetFirstDayOfWeekForMonth(int64 year, unsigned month)
{
 return (GetFirstDayOfWeekForYear(year) + month_day_offset[IsLeapYear(year)][month]) % 7;
}

static int GetNumberOfDaysForMonth(int64 year, int month)
{
 return month_day_count[IsLeapYear(year)][month];
}

static int64 EpochTimeFromUTCTime(const struct tm& hmt)
{
 int64 year = (int64)1900 + hmt.tm_year;
 int month = hmt.tm_mon;
 int mday = hmt.tm_mday - 1;
 int second = hmt.tm_sec;
 int minute = hmt.tm_min;
 int hour = hmt.tm_hour;

 //if(month >= 0)
 //{
  year += month / 12;
  month %= 12;
 //}
 //else
 //{
 // year -= (11 - month) / 12;
 // month = 11 - (-month % 12);
 //}

 minute += second / 60;
 second %= 60;

 hour += minute / 60;
 minute %= 60;

 mday += hour / 60;
 hour %= 60;

 {
  int mdc;
  bool ly;

  if(MDFN_UNLIKELY(mday >= days_per_400_years))
  {
   year += 400 * (mday / days_per_400_years);
   mday %= days_per_400_years;
  }

  while(month && mday >= (mdc = month_day_count[ly = IsLeapYear(year)][month]))
  {
   mday -= mdc;
   month++;
   if(month == 12)
   {
    month = 0;
    year++;
   }
  }

  while(mday >= (mdc = (365 + IsLeapYear(year))))
  {
   mday -= mdc;
   year++;
  }

  while(mday >= (mdc = month_day_count[IsLeapYear(year)][month]))
  {
   mday -= mdc;
   month++;
   if(month == 12)
   {
    month = 0;
    year++;
   }
  }
 }
 //
 //
 //
 uint64 days = GetDaysSinceWTFBBQ(year) + month_day_offset[IsLeapYear(year)][month] + mday;
 int64 ret = -wtfbbq_ept_bias + (((((days * 24) + hour) * 60) + minute) * 60) + second;

 return ret;
}

struct tm UTCTime(int64 ept)
{
 uint64 seconds_since_wtfbbq = wtfbbq_ept_bias + ept;
 uint64 minutes_since_wtfbbq = seconds_since_wtfbbq / 60;
 uint64 hours_since_wtfbbq = minutes_since_wtfbbq / 60;
 uint64 days_since_wtfbbq = hours_since_wtfbbq / 24;
 uint64 years_since_wtfbbq = 0;
 uint32 days_since_year = 0;
 uint32 months_since_year = 0;
 uint32 days_since_month = 0;
 struct tm ret = { 0 };

 //assert(seconds_since_wtfbbq >= 0);
 {
  uint64 years = 0;
  uint64 days = 0;

  years += 400 * (days_since_wtfbbq / days_per_400_years);
  days = days_since_wtfbbq % days_per_400_years;

  if(days >= days_per_first_100_of_400_years)	// +100
  {
   days -= days_per_first_100_of_400_years;
   years += 100 + 100 * (days / days_per_other_100_of_400_years);
   days %= days_per_other_100_of_400_years;

   if(days >= 4 * 365)
   {
    days -= 4 * 365;
    years += 4 + (days * 4) / (365 * 4 + 1);
    days = ((days * 4) % (365 * 4 + 1)) / 4;
   }
   else
   {
    years += days / 365;
    days %= 365;
   }
  }
  else
  {
   years += (days * 4) / (365 * 4 + 1);
   days = ((days * 4) % (365 * 4 + 1)) / 4;
  }
  days_since_year = days;
  years_since_wtfbbq = years;
 }

 {
  const bool ly = IsLeapYear(wtfbbq + years_since_wtfbbq);

  for(unsigned m = 0; m < 12; m++)
  {
   if(m == 11 || (days_since_year >= month_day_offset[ly][m] && days_since_year < month_day_offset[ly][m + 1]))
   {
    months_since_year = m;
    days_since_month = days_since_year - month_day_offset[ly][m];
    break;
   }
  }
 }

 ret.tm_sec = seconds_since_wtfbbq % 60;
 ret.tm_min = minutes_since_wtfbbq % 60;
 ret.tm_hour = hours_since_wtfbbq % 24;
 ret.tm_wday = (6 + days_since_wtfbbq) % 7;
 ret.tm_mon = months_since_year;
 ret.tm_mday = 1 + days_since_month;
 ret.tm_yday = days_since_year;
 ret.tm_year = years_since_wtfbbq + wtfbbq - 1900;
 ret.tm_isdst = 0;

 return ret;
}

static int64 CalcTZPeriodStartByYear(int year, int month, int day_of_week, int nth, int hour, int minute, int second)
{
 const int month_num_days = GetNumberOfDaysForMonth(year, month);
 int day;
 int64 ret;

 day = day_of_week - GetFirstDayOfWeekForMonth(year, month);
 if(day < 0)
  day += 7;
 day += 7 * nth;
 while(day >= month_num_days)
  day -= 7;
 //
 {
  struct tm t;
  t.tm_year = year - 1900;
  t.tm_mon = month;
  t.tm_mday = 1 + day;
  t.tm_hour = hour;
  t.tm_min = minute;
  t.tm_sec = second;
  t.tm_isdst = 0;

  ret = EpochTimeFromUTCTime(t);
 }

 return ret;
}

struct tm LocalTime(const int64 ept)
{
 if(MDFN_UNLIKELY(!Initialized))
  Time_Init();
 //
 struct tm ret;

 ret = UTCTime(ept);
 //
 //
 struct
 {
  int64 start_ept;
  int bias;
  bool is_dst;
 } tzperiods[6];

 for(int ydi = 0; ydi < 4; ydi++)
 {
  const int year = 1900 + ret.tm_year + ydi - 2;
  TIME_ZONE_INFORMATION tzi = { 0 };

  if(!p_GetTimeZoneInformationForYear || !p_GetTimeZoneInformationForYear(year, NULL, &tzi))
   GetTimeZoneInformation(&tzi);

  if(!tzi.DaylightDate.wMonth || !tzi.StandardDate.wMonth)
  {
   struct tm t;

   t.tm_year = year - 1900;
   t.tm_mon = 0;
   t.tm_mday = 1;
   t.tm_hour = 0;
   t.tm_min = 0;
   t.tm_sec = 0;
   t.tm_isdst = 0;

   tzperiods[ydi * 2 + 0].start_ept = EpochTimeFromUTCTime(t);
   tzperiods[ydi * 2 + 0].bias = -tzi.Bias * 60;
   tzperiods[ydi * 2 + 0].is_dst = false;

   tzperiods[ydi * 2 + 1] = tzperiods[ydi * 2 + 0];
  }
  else for(unsigned w = 0; w < 2; w++)
  {
   const SYSTEMTIME* st = (w ? &tzi.DaylightDate : &tzi.StandardDate);

   tzperiods[ydi * 2 + w].start_ept = CalcTZPeriodStartByYear(year, st->wMonth - 1, st->wDayOfWeek, st->wDay + !st->wDay - 1, st->wHour, st->wMinute, st->wSecond);
   tzperiods[ydi * 2 + w].bias = -(tzi.Bias + (w ? tzi.DaylightBias : tzi.StandardBias)) * 60;
   tzperiods[ydi * 2 + w].is_dst = w;
  }

  if(tzperiods[ydi * 2 + 0].start_ept > tzperiods[ydi * 2 + 1].start_ept)
   std::swap(tzperiods[ydi * 2 + 0], tzperiods[ydi * 2 + 1]);
 }

 for(unsigned i = 1; i < 8; i++)
  tzperiods[i].start_ept -= tzperiods[i - 1].bias;
 //
 //
 int bias = 0;
 bool is_dst = false;
 for(unsigned i = 1; i < 8; i++)
 {
  if(ept >= tzperiods[i].start_ept)
  {
   bias = tzperiods[i].bias;
   is_dst = tzperiods[i].is_dst;   
  }
 }

 ret = UTCTime(ept + bias);
 ret.tm_isdst = is_dst;

 return ret;
}

std::string StrTime(const char* format, const struct tm& tin)
{
 std::u16string ret((size_t)256, 0);
 size_t rv;
 std::u16string formatadj = UTF8_to_UTF16(format) + u"!";

 while(!(rv = wcsftime((wchar_t*)&ret[0], ret.size(), (const wchar_t*)formatadj.c_str(), &tin)))
  ret.resize(ret.size() * 2);

 ret.resize(rv - 1);

 return UTF16_to_UTF8(ret);
}

}

}
