/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* megamouse.cpp:
**  Copyright (C) 2009-2016 Mednafen Team
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

#include "../shared.h"
#include "megamouse.h"
#include <trio/trio.h>

namespace MDFN_IEN_MD
{

enum
{
 MASK_TH = 0x40,
 MASK_TR = 0x20,
 MASK_TL = 0x10,
 MASK_DATA = 0x0F
};

class MegaMouse final : public MD_Input_Device
{
        public:
	MegaMouse();
	virtual ~MegaMouse() override;
        virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;
        virtual void UpdatePhysicalState(const void *data) override;
        virtual void BeginTimePeriod(const int32 timestamp_base) override;
        virtual void EndTimePeriod(const int32 master_timestamp) override;
	virtual void Power(void) override;
        virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;

	private:
	int32 mouse_x;
	int32 mouse_y;
	uint8 buttons;

	int32 busy_until;

	uint8 phase;
	uint8 bus_av;
	uint8 data_buffer[0x8];
};

const IDIISG MegaMouseIDII =
{
 IDIIS_AxisRel("motion", "Motion",/**/ "left", "Left",/**/ "right", "Right", 0),
 IDIIS_AxisRel("motion", "Motion",/**/ "up", "Up",/**/ "down", "Down", 1),
 IDIIS_Button("left", "Left Button", 2),
 IDIIS_Button("right", "Right Button", 3),
 IDIIS_Button("middle", "Middle Button", 4),
 IDIIS_Button("start", "Start Button", 5),
};

enum
{
 PHASE_RESETTING = 0,
 PHASE_RESET_EXEC,
 PHASE_INITIAL,
 PHASE_BEGIN,
 PHASE_DATA0,
 PHASE_DATA1,
 PHASE_DATA2,
 PHASE_DATA3,
 PHASE_DATA4,
 PHASE_DATA5,
 PHASE_DATA6,
 PHASE_DATA7,
 PHASE_END
};

MegaMouse::MegaMouse()
{
        mouse_x = 0;
        mouse_y = 0;
        buttons = 0;

	phase = PHASE_INITIAL;
	busy_until = -1;
}

MegaMouse::~MegaMouse()
{

}

void MegaMouse::Power(void)
{
	bus_av = 0x10;
	phase = PHASE_INITIAL;
	busy_until = -1;
}


void MegaMouse::BeginTimePeriod(const int32 timestamp_base)
{
 //puts("Begin");
 if(busy_until >= 0)
  busy_until += timestamp_base;
}

void MegaMouse::EndTimePeriod(const int32 master_timestamp)
{
 if(busy_until >= 0 && master_timestamp >= busy_until)
 {
  //puts("Advance phase");
  if(phase < PHASE_END)
   phase++;
  busy_until = -1;
 }

 if(busy_until >= 0)
  busy_until -= master_timestamp;
}

void MegaMouse::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
 const bool th = bus & MASK_TH;
 const bool tr = bus & MASK_TR;

 if(th && tr && phase != PHASE_RESET_EXEC)
 {
  busy_until = -1;
  phase = PHASE_INITIAL;
 }

 if(busy_until >= 0)
 {
  if(master_timestamp >= busy_until)
  {
   //puts("Advance phase");
   if(phase < PHASE_END)
    phase++;
   busy_until = -1;
  }
 }

 if(busy_until < 0)
 {
  switch(phase)
  {
   case PHASE_RESET_EXEC:
	bus_av = 0x00;
	if(tr)
	 busy_until = master_timestamp + 400;
	break;

   case PHASE_INITIAL:
	if(th)
	{
	 bus_av = 0x10;

	 if(!tr)
	 {
	  phase = PHASE_RESETTING;
	  busy_until = master_timestamp + 400;
	 }
	}
	else
	{
	 phase++;
	}
	break;

   case PHASE_BEGIN:
	bus_av = 0x1B;
	if(!tr)
	{
	 int32 rel_x = mouse_x;
     	 int32 rel_y = mouse_y;
     	 bool x_neg = 0;
	 bool y_neg = 0;

     	 if(rel_x < -255)
	  rel_x = -255;

	 if(rel_x > 255)
	  rel_x = 255;

	 if(rel_y < -255)
	  rel_y = -255;

	 if(rel_y > 255)
	  rel_y = 255;

	 mouse_x -= rel_x;
	 mouse_y -= rel_y;

	 rel_y = -rel_y;

	 x_neg = (rel_x < 0);
	 y_neg = (rel_y < 0);

	 data_buffer[0] = 0xF;
	 data_buffer[1] = 0xF;
	 data_buffer[2] = (x_neg ? 0x1 : 0x0) | (y_neg ? 0x2 : 0x0); // Axis sign and overflow
	 data_buffer[3] = buttons; // Button state
	 data_buffer[4] = (rel_x >> 4) & 0xF; // X axis MSN
	 data_buffer[5] = (rel_x >> 0) & 0xF; // X axis LSN
	 data_buffer[6] = (rel_y >> 4) & 0xF; // Y axis MSN
     	 data_buffer[7] = (rel_y >> 0) & 0xF; // Y axis LSN

	 //printf("DB: %02x %02x %02x %02x %02x %02x %02x %02x\n", data_buffer[0], data_buffer[1], data_buffer[2], data_buffer[3], data_buffer[4], data_buffer[5], data_buffer[6], data_buffer[7]);

	 busy_until = master_timestamp + 400;
	}
	break;

   case PHASE_DATA0: case PHASE_DATA1: case PHASE_DATA2: case PHASE_DATA3:
   case PHASE_DATA4: case PHASE_DATA5: case PHASE_DATA6: case PHASE_DATA7:
	bus_av = data_buffer[phase - PHASE_DATA0] | (((phase - PHASE_DATA0) & 1) << 4);
	if(tr != ((phase - PHASE_DATA0) & 1))
	 busy_until = master_timestamp + 400;
	break;

   case PHASE_END:
	bus_av ^= 0x10;

	if(tr != (bool)(bus_av & 0x10))
	{
	 busy_until = master_timestamp + 400;
	}
	break;
  }
 }

 bus = (bus &~ 0x1F) | bus_av;
 //printf("%02x, %02x --- %d -- %d\n", bus, bus_av, phase, master_timestamp);
}

void MegaMouse::UpdatePhysicalState(const void *data)
{
 mouse_x += (int16)MDFN_de16lsb((uint8 *)data + 0);
 mouse_y += (int16)MDFN_de16lsb((uint8 *)data + 2);
 buttons = ((uint8 *)data)[4];
}

void MegaMouse::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(mouse_x),
  SFVAR(mouse_y),
  SFVAR(buttons),

  SFVAR(busy_until),

  SFVAR(phase),
  SFVAR(bus_av),
  SFVAR(data_buffer),

  SFEND
 };
 char sname[64];

 trio_snprintf(sname, sizeof(sname), "%s-mmouse", section_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {

 }
}

MD_Input_Device *MDInput_MakeMegaMouse(void)
{
 MD_Input_Device *ret = new MegaMouse();

 return(ret);
}

}
