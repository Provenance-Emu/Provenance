/******************************************************************************/
/* Mednafen GBA Emulation Module(based on VisualBoyAdvance)                   */
/******************************************************************************/
/* RTC.cpp:
**  Copyright (C) 1999-2003 Forgotten
**  Copyright (C) 2005 Forgotten and the VBA development team
**  Copyright (C) 2009-2017 Mednafen Team
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

//
// Guts of RTC implementation is generic.
//

#include <mednafen/mednafen.h>
#include "GBA.h"
#include "Globals.h"
#include "Port.h"

#include <mednafen/Time.h>

namespace MDFN_IEN_GBA
{

RTC::RTC()
{
 sec = 0x00;
 min = 0x00;
 hour = 0x00;
 wday = 0x00;
 mday = 0x01;
 mon = 0x01;
 year = 0x00;

#if 0
 {
  const int64 epst = Time::EpochTime();

  for(int64 i = epst; i < epst + 366 * 24 * 60 * 60 * 4; i++)
  {
   InitTime(Time::UTCTime(i));
   ClockSeconds();
   const uint8 sec_save = sec, min_save = min, hour_save = hour, wday_save = wday, mday_save = mday, mon_save = mon, year_save = year;
   InitTime(Time::UTCTime(i + 1));

   if(!(sec_save == sec && min_save == min && hour_save == hour && wday_save == wday && mday_save == mday && mon_save == mon && year_save == year))
   {
    printf("Sec: %02x:%02x\nMin: %02x:%02x\nHour: %02x:%02x\nWDay: %02x:%02x\nMDay: %02x:%02x\nMon: %02x:%02x\nYear: %02x:%02x\n", sec, sec_save, min, min_save, hour, hour_save, wday, wday_save, mday, mday_save, mon, mon_save, year, year_save);
    abort();
   }
  }
 }
#endif

 InitTime(Time::LocalTime());
 Reset(); 
}

RTC::~RTC()
{

}

static uint8 toBCD(uint8 value)
{
  value = value % 100;
  int l = value % 10;
  int h = value / 10;
  return h * 16 + l;
}

void RTC::InitTime(const struct tm& toom)
{
 sec = toBCD(toom.tm_sec);
 min = toBCD(toom.tm_min);
 hour = toBCD(toom.tm_hour);
 wday = toBCD(toom.tm_wday);
 mday = toBCD(toom.tm_mday);
 mon = toBCD(toom.tm_mon + 1);
 year = toBCD(toom.tm_year % 100);

 if(sec >= 0x60)	// Murder the leap second.
  sec = 0x59;
}

bool RTC::BCDInc(uint8 &V, uint8 thresh, uint8 reset_val)
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

void RTC::ClockSeconds(void)
{
 if(BCDInc(sec, 0x60))
 {
  if(BCDInc(min, 0x60))
  {
   if(BCDInc(hour, 0x24))
   {
    uint8 mday_thresh = 0x32;

    if(mon == 0x02)
    {
     mday_thresh = 0x29;

     if(((year & 0x0F) % 4) == ((year & 0x10) ? 0x02 : 0x00))
      mday_thresh = 0x30;
    }
    else if(mon == 0x04 || mon == 0x06 || mon == 0x09 || mon == 0x11)
     mday_thresh = 0x31;

    BCDInc(wday, 0x07);

    if(BCDInc(mday, mday_thresh, 0x01))
    {
     if(BCDInc(mon, 0x13, 0x01))
     {
      BCDInc(year, 0xA0);
     }
    }
   }
  }
 }
}


void RTC::AddTime(int32 amount)
{
 ClockCounter += amount;

 while(ClockCounter >= 16777216)
 {
  ClockCounter -= 16777216;
  ClockSeconds();
 }
}

uint16 RTC::Read(uint32 address)
{
    if(address == 0x80000c8)
      return byte2;
    else if(address == 0x80000c6)
      return byte1;
    else if(address == 0x80000c4)
      return byte0;

 abort();
}

void RTC::Write(uint32 address, uint16 value)
{
  if(address == 0x80000c8) {
    byte2 = (uint8)value; // enable ?
  } else if(address == 0x80000c6) {
    byte1 = (uint8)value; // read/write
  } else if(address == 0x80000c4) {
    if(byte2 & 1) {
      if(state == IDLE && byte0 == 1 && value == 5) {
          state = COMMAND;
          bits = 0;
          command = 0;
      } else if(!(byte0 & 1) && (value & 1)) { // bit transfer
        byte0 = (uint8)value;        
        switch(state) {
        case COMMAND:
          command |= ((value & 2) >> 1) << (7-bits);
          bits++;
          if(bits == 8) {
            bits = 0;
            switch(command) {
            case 0x60:
              // not sure what this command does but it doesn't take parameters
              // maybe it is a reset or stop
              state = IDLE;
              bits = 0;
              break;
            case 0x62:
              // this sets the control state but not sure what those values are
              state = READDATA;
              dataLen = 1;
              break;
            case 0x63:
              dataLen = 1;
              data[0] = 0x40;
              state = DATA;
              break;
           case 0x64:
              break;
            case 0x65:
              {                
                dataLen = 7;
                data[0] = year;
                data[1] = mon;
                data[2] = mday;
                data[3] = wday;
                data[4] = hour;
                data[5] = min;
                data[6] = sec;
                state = DATA;
              }
              break;              
            case 0x67:
              {
                dataLen = 3;
                data[0] = hour;
                data[1] = min;
                data[2] = sec;
                state = DATA;
              }
              break;
            default:
              //systemMessage(0, N_("Unknown RTC command %02x"), command);
              state = IDLE;
              break;
            }
          }
          break;
        case DATA:
          if(byte1 & 2) {
          } else {
            byte0 = (byte0 & ~2) |
              ((data[bits >> 3] >>
                (bits & 7)) & 1)*2;
            bits++;
            if(bits == 8*dataLen) {
              bits = 0;
              state = IDLE;
            }
          }
          break;
        case READDATA:
          if(!(byte1 & 2)) {
          } else {
            data[bits >> 3] =
              (data[bits >> 3] >> 1) |
              ((value << 6) & 128);
            bits++;
            if(bits == 8*dataLen) {
              bits = 0;
              state = IDLE;
            }
          }
          break;
		default:
          break;
        }
      } else
        byte0 = (uint8)value;
    }
  }
}

void RTC::Reset(void)
{
 byte0 = 0;
 byte1 = 0;
 byte2 = 0;
 command = 0;
 dataLen = 0;
 bits = 0;
 state = IDLE;

 memset(data, 0, sizeof(data));
 ClockCounter = 0;
}

int RTC::StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(byte0),
  SFVAR(byte1),
  SFVAR(byte2),
  SFVAR(command),
  SFVAR(dataLen),
  SFVAR(bits),
  SFVAR(state),
  SFPTR8(data, 12),

  SFVAR(ClockCounter),

  SFVAR(sec),
  SFVAR(min),
  SFVAR(hour),
  SFVAR(wday),
  SFVAR(mday),
  SFVAR(mon),
  SFVAR(year),

  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "RTC");

 if(load)
 {

 }

 return(ret);
}

}
