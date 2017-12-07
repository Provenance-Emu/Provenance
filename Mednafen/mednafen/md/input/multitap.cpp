/* Mednafen - Multi-system Emulator
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

//
// Bleck, so many horrible guesses.
//

#include "../shared.h"
#include "multitap.h"
#include <trio/trio.h>

MD_Multitap::MD_Multitap()
{
 prev_th = false;
 prev_tr = false;

 Power();
}

MD_Multitap::~MD_Multitap()
{



}

void MD_Multitap::Power(void)
{
 phase = 0;

 memset(bb, 0, sizeof(bb));
 data_out = 0;
 data_out_offs = 0;
 nyb = 0;

 for(unsigned i = 0; i < 4; i++)
 {
  if(SubPort[i])
   SubPort[i]->Power();
 }
}


void MD_Multitap::BeginTimePeriod(const int32 timestamp_base)
{
#if 0
  static uint32 counter = 0;

  counter++;

  if(counter >= 600)
   exit(0);
#endif

 for(unsigned i = 0; i < 4; i++)
 {
  SubPort[i]->BeginTimePeriod(timestamp_base);
 }
}

void MD_Multitap::EndTimePeriod(const int32 master_timestamp)
{
 for(unsigned i = 0; i < 4; i++)
 {
  SubPort[i]->EndTimePeriod(master_timestamp);
 }
}


void MD_Multitap::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
#if 0
 const bool th = (bus & 0x40);
 const bool tr = (bus & 0x20);
 printf("%02x\n", bus);

 if(th)
  bus &= (~0x0F) | 3;
 else
  bus |= 0x0F;
#endif
 //bus &= (genesis_asserted & 0x60) | ~0x60;

 const bool th = (bus & 0x40);
 const bool tr = (bus & 0x20);

 if(th)
 {
  phase = 0;
  bus &= ~0x1F;
  bus |= 0x03 | (tr << 4);
  nyb = 0x0F;
  data_out_offs = 0;
  data_out = 0;
 }
 else if(phase < 18)
 {
  if(tr != prev_tr)
  {
   if(phase == 0)
   {
    for(int idx = -2; idx < 5; idx++)
    {
     for(unsigned sp = 0; sp < 4; sp++)
     {
      uint8 sub_bus = ((!(idx & 1)) << 6) | 0x3F;
      uint8 sub_asserted = 0x40;

      SubPort[sp]->UpdateBus(master_timestamp, sub_bus, sub_asserted);

      if(idx >= 0)
       bb[sp][idx] = sub_bus;
     }
    }
   }

   if(phase >= 0 && phase <= 1)
   {
    nyb = 0x0;
   }
   else if(phase >= 2 && phase <= 5)
   {
	uint8* cb = bb[phase - 2];

	//printf("MOO: %d %02x %02x %02x %02x\n", phase - 2, cb[0], cb[1], cb[2], cb[3]);

	switch(cb[3] & 0xF)
	{
	  default:
	  case 0xF:	// Nothing
		nyb = 0xF;
		break;

	  case 0x1:
	  case 0x2:
	  case 0x3:	// 3-button
		nyb = 0x0;
		data_out |= (uint64)((cb[0] & 0x3F) | ((cb[1] << 2) & 0xC0)) << data_out_offs;
		data_out_offs += 8;
		break;

	  case 0x0:	// 6-button
		nyb = 0x1;
		data_out |= (uint64)((cb[0] & 0x3F) | ((cb[1] << 2) & 0xC0) | ((cb[4] & 0xF) << 8)) << data_out_offs;
		data_out_offs += 12;
		break;
	}

	if(phase == 5)
	 data_out |= (~(uint64)0) << data_out_offs;
   }
   else if(phase >= 6 && phase <= 17)
   {
    nyb = data_out & 0xF;
    data_out >>= 4;
   }
   phase++;
  }

  bus = (bus &~ 0x1F) | (tr << 4) | nyb;
 }

 //printf("Phase: %3d, Bus: 0x%02x --- %02x\n", phase, bus, genesis_asserted);

#if 0
 {
  static uint32 th_counter = 0;

  if(th != prev_th)
   th_counter++;

  if(phase == 10)
  {
   //printf("YES: %08x\n", C68k_Get_PC(&Main68K));
   exit(1);
  }

  if(th_counter >= 100)
  {
   exit(0);
  }
 }
#endif

 prev_th = th;
 prev_tr = tr;
}

void MD_Multitap::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(phase),
  SFVAR(prev_th),
  SFVAR(prev_tr),

  SFARRAY(&bb[0][0], sizeof(bb) / sizeof(bb[0][0])),
  
  SFVAR(data_out),
  SFVAR(data_out_offs),
  SFVAR(nyb),

  SFEND
 };

 char sname[64];

 trio_snprintf(sname, sizeof(sname), "%s-MT", section_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 { 

 }

 for(unsigned i = 0; i < 4; i++)
 {
  char ss_prefix[64];

  trio_snprintf(ss_prefix, sizeof(ss_prefix), "%s-MT%u", section_prefix, i);

  SubPort[i]->StateAction(sm, load, data_only, ss_prefix);
 }
}


void MD_Multitap::SetSubPort(unsigned n, MD_Input_Device* d)
{
 assert(n < 4);

 SubPort[n] = d;
}

