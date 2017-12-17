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

#include "../shared.h"
#include "4way.h"
#include <trio/trio.h>

MD_4Way_Shim::MD_4Way_Shim(unsigned nin, MD_4Way* p4w) : n(nin), parent(p4w)
{


}

MD_4Way_Shim::~MD_4Way_Shim()
{


}

void MD_4Way_Shim::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 if(!n)
  parent->StateAction(sm, load, data_only, section_prefix);
}

void MD_4Way_Shim::Power(void)
{
 if(!n)
  parent->Power();
}

void MD_4Way_Shim::BeginTimePeriod(const int32 timestamp_base)
{
 if(!n)
  parent->BeginTimePeriod(timestamp_base);
}

void MD_4Way_Shim::EndTimePeriod(const int32 master_timestamp)
{
 if(!n)
  parent->EndTimePeriod(master_timestamp);
}

void MD_4Way_Shim::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
 parent->UpdateBus(n, master_timestamp, bus, genesis_asserted);
}

MD_4Way::MD_4Way()
{
 Power();
}

MD_4Way::~MD_4Way()
{



}

void MD_4Way::Power(void)
{
 index = 8;
 for(unsigned i = 0; i < 4; i++)
 {
  if(SubPort[i])
   SubPort[i]->Power();
 }
}


void MD_4Way::BeginTimePeriod(const int32 timestamp_base)
{
 for(unsigned i = 0; i < 4; i++)
 {
  SubPort[i]->BeginTimePeriod(timestamp_base);
 }
}

void MD_4Way::EndTimePeriod(const int32 master_timestamp)
{
 for(unsigned i = 0; i < 4; i++)
 {
  SubPort[i]->EndTimePeriod(master_timestamp);
 }
}


void MD_4Way::UpdateBus(unsigned n, const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
 //printf("%d, %02x %02x\n", n, bus, genesis_asserted);

 if(n)
 {
  if((bus & 0xF) == 0xC)
  {
   index = (bus >> 4) & 0x7;

   //if(index == 7)
   // printf("%08x\n", C68k_Get_PC(&Main68K));
  }
  else
   index = 8;
 }
 else
 {
  if(index & 4)
   bus = (bus &~ 0x3);
 }

#if 1
 for(unsigned sp = 0; sp < 4; sp++)
 {
  if(sp == index)
  {
   SubPort[sp]->UpdateBus(master_timestamp, bus, genesis_asserted);
  }
  else
  {
   uint8 tmp = 0x7F;
   SubPort[sp]->UpdateBus(master_timestamp, tmp, 0);
  }
 }
#endif

#if 0
 if(index < 4)
 {
  SubPort[index]->UpdateBus(master_timestamp, bus, genesis_asserted);
 }
#endif
}

void MD_4Way::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(index),
  SFEND
 };

 char sname[64];

 trio_snprintf(sname, sizeof(sname), "%s-4W", section_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 { 

 }

 for(unsigned i = 0; i < 4; i++)
 {
  char ss_prefix[64];

  trio_snprintf(ss_prefix, sizeof(ss_prefix), "%s-4W%u", section_prefix, i);

  SubPort[i]->StateAction(sm, load, data_only, ss_prefix);
 }
}


void MD_4Way::SetSubPort(unsigned n, MD_Input_Device* d)
{
 assert(n < 4);

 SubPort[n] = d;
}

