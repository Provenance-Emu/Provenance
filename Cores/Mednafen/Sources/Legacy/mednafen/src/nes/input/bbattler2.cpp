/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* bbattler2.cpp - Barcode Battler II(via Barcode World adapter cable) Emulation
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

/*
 ~1200bps, 8N1

 20 bytes total:
  13 bytes of barcode numbers as ASCII, "EPOCH", <CR>, <LF>
*/

#include "share.h"

namespace MDFN_IEN_NES
{

static uint8 serdata[25];
static uint64 serdata_stime;

static INLINE uint32 GetPos(void)
{
 const uint64 tdelta = (timestamp + timestampbase) - serdata_stime; 

 if(tdelta < 8000000)
  return (tdelta * (PAL ? 3099927 : 2879673)) >> 32;

 return 8 * sizeof(serdata);
}

static uint8 Read(int w, uint8 ret)
{
 if(w)
 {
  uint32 pos = GetPos();

  if((pos >> 3) < sizeof(serdata))
   ret |= ((serdata[pos >> 3] >> (pos & 0x7)) & 0x1) << 2;

  //printf("timestamp: %llu, pos: %5d\n", (unsigned long long)(timestampbase + timestamp), pos);
 }

 return ret;
}

static void Update(void* data)
{
 uint8* d = (uint8*)data;

 if(d[0] && (GetPos() >> 3) >= sizeof(serdata))
 {
  uint8 tmp[20];
  unsigned blen;
  bool error_cond = false;

  for(blen = 0; blen < 13 && d[1 + blen] >= '0' && d[1 + blen] <= '9'; blen++);

  if(blen == 12)
  {
   tmp[0] = '0';
   memcpy(tmp + 1, d + 1, 12);
  }
  else if(blen == 13)
   memcpy(tmp, d + 1, 13);
  else
   error_cond = true;

  if(!error_cond)
  {
   unsigned csum = 0;
   for(unsigned i = 0; i < 13; i++)
   {
    unsigned c = tmp[i] - '0';
    csum += c * ((i & 1) ? 3 : 1);
   }

   if(csum % 10)
    error_cond = true;
  }

  if(error_cond)
  {
   tmp[0] = 'E';
   tmp[1] = 'R';
   tmp[2] = 'R';
   tmp[3] = 'O';
   tmp[4] = 'R';

   for(unsigned i = 5; i < 13; i++)
    tmp[i] = ' ';
  }

  tmp[13] = 'E';
  tmp[14] = 'P';
  tmp[15] = 'O';
  tmp[16] = 'C';
  tmp[17] = 'H';
  tmp[18] = '\r';
  tmp[19] = '\n';

  memset(serdata, 0x00, sizeof(serdata));
  for(unsigned by = 0, dbp = 0; by < 20; by++)
  {
   for(int wb = -1; wb <= 8; wb++)
   {
    bool b;

    if(wb < 0) // Start
     b = false;
    else if(wb >= 8) // Stop
     b = true;
    else
     b = (tmp[by] >> wb) & 0x1;

    serdata[dbp >> 3] |= !b << (dbp & 0x7);
    dbp++;
   }
  }

  serdata_stime = timestamp + timestampbase;
 }
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(serdata),
  SFVAR(serdata_stime),
  SFEND
 };

 //
 serdata_stime -= timestampbase + timestamp;
 MDFNSS_StateAction(sm, load, data_only, StateRegs, "BBATTLER2", true);
 serdata_stime += timestampbase + timestamp;
 //

 if(load)
 {

 }
}

static INPUTCFC BBattler2 =
{
 Read,
 NULL,
 NULL,
 Update,
 NULL,
 NULL,
 StateAction
};

INPUTCFC* MDFN_InitBBattler2(void)
{
 return &BBattler2;
}

}
