/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* rtc.cpp - WonderSwan RTC Emulation
**  Copyright (C) 2014-2016 Mednafen Team
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

/*
 RTC utilizing games:
	Dicing Knight
	Dokodemo Hamster 3
	Inuyasha - Kagome no Sengoku Nikki
*/

#include "wswan.h"
#include <mednafen/Time.h>
#include <limits.h>

#include <mednafen/cdrom/CDUtility.h>	// We really should move the BCD functions somewhere else...
using namespace CDUtility;

namespace MDFN_IEN_WSWAN
{

static uint32 ClockCycleCounter;

static uint8 Command;
static uint8 CommandBuffer[7];
static uint8 CommandIndex;
static uint8 CommandCount;

//template<bool century21st>
struct GenericRTC
{
 GenericRTC();
 void Init(const struct tm& toom);
 void Clock(void);

 bool BCDInc(uint8 &V, uint8 thresh, uint8 reset_val = 0x00);

 uint8 sec;
 uint8 min;
 uint8 hour;
 uint8 wday;
 uint8 mday;
 uint8 mon;
 uint8 year;
};

GenericRTC::GenericRTC()
{
 sec = 0x00;
 min = 0x00;
 hour = 0x00;
 wday = 0x00;
 mday = 0x01;
 mon = 0x00;
 year = 0x00;
}

bool GenericRTC::BCDInc(uint8 &V, uint8 thresh, uint8 reset_val)
{
 V = ((V + 1) & 0x0F) | (V & 0xF0);
 if((V & 0x0F) >= 0x0A)
 {
  V &= 0xF0;
  V += 0x10;

  if((V & 0xF0) >= 0xA0)
  {
   V &= 0x0F;
  }
 }

 if(V >= thresh)
 {
  V = reset_val;

  return(true);
 }

 return(false);
}

void GenericRTC::Init(const struct tm& toom)
{
 sec = U8_to_BCD(toom.tm_sec);
 min = U8_to_BCD(toom.tm_min);
 hour = U8_to_BCD(toom.tm_hour);
 wday = U8_to_BCD(toom.tm_wday);
 mday = U8_to_BCD(toom.tm_mday);
 mon = U8_to_BCD(toom.tm_mon);
 year = U8_to_BCD(toom.tm_year % 100);

 if(sec >= 0x60)	// Murder the leap second.
  sec = 0x59;
}

void GenericRTC::Clock(void)
{
 if(BCDInc(sec, 0x60))
 {
  if(BCDInc(min, 0x60))
  {
   if(BCDInc(hour, 0x24))
   {
    uint8 mday_thresh = 0x32;

    if(mon == 0x01)
    {
     mday_thresh = 0x29;

     if(((year & 0x0F) % 4) == ((year & 0x10) ? 0x02 : 0x00))
      mday_thresh = 0x30;
    }
    else if(mon == 0x03 || mon == 0x05 || mon == 0x08 || mon == 0x10)
     mday_thresh = 0x31;

    BCDInc(wday, 0x07);

    if(BCDInc(mday, mday_thresh, 0x01))
    {
     if(BCDInc(mon, 0x12))
     {
      BCDInc(year, 0xA0);
     }
    }
   }
  }
 }
}

static GenericRTC RTC;

void RTC_Write(uint8 A, uint8 V)
{
 //printf("RTC Write: %02x %02x\n", A, V);

 if(A == 0xCA)
 {
  Command = V & 0x1F;

  if(Command == 0x15)
  {
   CommandBuffer[0] = RTC.year;
   CommandBuffer[1] = RTC.mon;
   CommandBuffer[2] = RTC.mday;
   CommandBuffer[3] = RTC.wday;
   CommandBuffer[4] = RTC.hour;
   CommandBuffer[5] = RTC.min;
   CommandBuffer[6] = RTC.sec;

   CommandIndex = 0;
   CommandCount = 7;
  }
  else if(Command == 0x14)
  {
   CommandIndex = 0;
   CommandCount = 7;
  }
  else if(Command == 0x13)
  {
   //CommandIndex = 0;
  }
 }
 else if(A == 0xCB)
 {
  if(Command == 0x14)
  {
   if(CommandIndex < CommandCount)
   {
    CommandBuffer[CommandIndex++] = V;
    if(CommandIndex == CommandCount)
    {
     //printf("Program time\n");
     //for(int i = 0; i < CommandCount; i++)
     // printf("%d: %02x\n", i, CommandBuffer[i]);
     //abort();
#if 0
     RTC.year = CommandBuffer[0];
     RTC.mon = CommandBuffer[1];
     RTC.mday = CommandBuffer[2];
     RTC.wday = CommandBuffer[3];
     RTC.hour = CommandBuffer[4];
     RTC.min = CommandBuffer[5];
     RTC.sec = CommandBuffer[6];

     printf("WDAY: %02x\n", RTC.wday);
#endif
    }
   }
  }
 }
}

uint8 RTC_Read(uint8 A)
{
 uint8 ret = 0;

 if(A == 0xCA)
 {
  ret = Command | 0x80;
 }
 else if(A == 0xCB)
 {
  ret = 0x80;

  if(Command == 0x15)
  {
   if(CommandIndex < CommandCount)
   {
    ret = CommandBuffer[CommandIndex];

    if(!WS_InDebug)
     CommandIndex++;
   }
  }
 }

// printf("RTC Read: %02x %02x\n", A, ret);

 return(ret);
}

void RTC_Clock(uint32 cycles)
{
 ClockCycleCounter += cycles;

 while(ClockCycleCounter >= 3072000)
 {
  ClockCycleCounter -= 3072000;
  RTC.Clock();
 }
}

void RTC_Init(void)
{
 RTC.Init(Time::LocalTime());
 ClockCycleCounter = 0;

#if 0
 {
  GenericRTC rtc_a, rtc_b;
  time_t ct = 0; //947000000; //time(NULL);

  rtc_a.Init(ct);

  while(ct < INT_MAX)
  {
   rtc_b.Init(ct);

   if(memcmp(&rtc_a, &rtc_b, sizeof(GenericRTC)))
   {
    printf("%02x:%02x:%02x-%02x:%02x:%02x      %02x:%02x:%02x-%02x:%02x:%02x\n", rtc_a.year, rtc_a.mon, rtc_a.mday, rtc_a.hour, rtc_a.min, rtc_a.sec,
										 rtc_b.year, rtc_b.mon, rtc_b.mday, rtc_b.hour, rtc_b.min, rtc_b.sec);
    abort();
   }

   rtc_a.Clock();
   ct++;
  }
 }
#endif
}

void RTC_Reset(void)
{
 Command = 0x00;
}

void RTC_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(RTC.sec),
  SFVAR(RTC.min),
  SFVAR(RTC.hour),
  SFVAR(RTC.wday),
  SFVAR(RTC.mday),
  SFVAR(RTC.mon),
  SFVAR(RTC.year),

  SFVAR(ClockCycleCounter),

  SFVAR(Command),
  SFVAR(CommandBuffer),
  SFVAR(CommandCount),
  SFVAR(CommandIndex),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "RTC");

 if(load)
 {

 }
}


}
