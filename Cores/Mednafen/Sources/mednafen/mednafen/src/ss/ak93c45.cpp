/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ak93c45.cpp:
**  Copyright (C) 2022 Mednafen Team
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

#include "ak93c45.h"

namespace Mednafen
{

AK93C45::AK93C45(void)
{
 Init();
}

AK93C45::~AK93C45()
{
 lastts = 0;
}

void AK93C45::Init(void)
{
 memset(mem, 0xFF, sizeof(mem));
 lastts = 0;
 tsratio = 0;

 Power();
}

void AK93C45::ResetTS(void)
{
 lastts = 0;

 if(write_finish_counter < 0)
  write_finish_counter = 0;
}

void AK93C45::SetTSFreq(const int32 rate)
{
 tsratio = 1000000 * (1ULL << 32) / rate;
}

void AK93C45::Power(void)
{
 write_enable = false;

 addr = 0;
 data_buffer = 0;
 counter = 0;
 opcode = 0;
 dout = true;

 prev_cs = false;
 prev_sk = true;

 write_finish_counter = 0;

 phase = PHASE_IDLE;
}


bool AK93C45::UpdateBus(int32 timestamp, bool cs, bool sk, bool di)
{
 int64 clocks;

 clocks = (int64)(timestamp - lastts) * tsratio;
 lastts = timestamp;

 write_finish_counter -= clocks;
 if(phase == PHASE_WRITING && write_finish_counter <= 0)
 {
  //printf("Write finished\n");
  dout = true;
  phase = PHASE_IDLE;
 }
 //
 //
 //
 if(!cs)
 {
  if(phase == PHASE_WRITE_PENDING)
  {
   //printf("Write: %04x %04x\n", addr, data_buffer);

   if(addr == 0xFFFF)
    memset(mem, data_buffer, sizeof(mem));
   else
    mem[addr & 0x3F] = data_buffer;

   phase = PHASE_WRITING;
   write_finish_counter = (int64)10000 << 32;
  }
  else if(phase != PHASE_WRITING)
   phase = PHASE_IDLE;

  dout = true;
 }
 else
 {
  if(phase == PHASE_WRITING)
   dout = false;
  else if(/*prev_cs &&*/ sk && !prev_sk)
  {
   switch(phase)
   {
    case PHASE_IDLE:
	if(!di)
         phase++;
	break;

    case PHASE_WAIT_START:
	if(di)
	{
	 phase++;
	 counter = 2;
	 opcode = 0;
	}
	break;

    case PHASE_OPCODE:
	opcode <<= 1;
	opcode |= di;
	counter--;
	if(!counter)
	{
	 phase++;
	 counter = 6;
	 addr = 0;
	}
	break;

    case PHASE_ADDR:
	addr <<= 1;
	addr |= di;
	counter--;
	if(!counter)
	{
	 //printf("Op: 0x%01x, Address: 0x%02x\n", opcode, addr);
	 if(opcode == 0x2)	// Read
	 {
	  phase++;
#if 0
	  data_buffer = 0x0000;
	  counter = 1;
#else
	  dout = false;
	  data_buffer = mem[addr & 0x3F];
	  addr = (addr + 1) & 0x3F;
	  counter = 16;
#endif
	 }
	 else if(opcode == 0x1)	// Write
	 {
	  data_buffer = 0x0000;
	  phase++;
	  counter = 16;
	 }
	 else if(opcode == 0x0)
	 {
	  switch(addr & 0x30)
	  {
	   case 0x00:
	   	write_enable = false;
		phase = PHASE_IDLE;
		break;

	   case 0x30:
		write_enable = true;
		phase = PHASE_IDLE;
		break;

	   case 0x10:
		addr = 0xFFFF;
		data_buffer = 0x0000;
		phase++;
		counter = 16;
		break;
	  }
	 }
	}
	break;

    case PHASE_DATA:
	if(opcode == 0x2)	// Read
	{
	 dout = (bool)(data_buffer & 0x8000);
	 //printf("read dout: %d\n", dout);
	 data_buffer <<= 1;
	 counter--;
	 if(!counter)
	 {
	  data_buffer = mem[addr & 0x3F];
	  addr = (addr + 1) & 0x3F;
	  counter = 16;
	 }
	}
	else // Write
	{
	 data_buffer <<= 1;
	 data_buffer |= di;

	 counter--;
	 if(!counter)
	 {
	  phase = PHASE_WRITE_PENDING;
	 }
	}
	break;
   }
  }
 }
 
 //
 //
 prev_cs = cs;
 prev_sk = sk;

 return dout;
}

void AK93C45::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(mem),
  SFVAR(write_enable),
  SFVAR(addr),
  SFVAR(data_buffer),
  SFVAR(counter),
  SFVAR(opcode),
  SFVAR(dout),
  SFVAR(prev_cs),
  SFVAR(prev_sk),
  SFVAR(phase),
  SFVAR(write_finish_counter),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

 if(load)
 {

 
 }
}

}
