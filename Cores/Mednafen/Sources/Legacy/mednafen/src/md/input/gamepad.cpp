/* Mednafen - Multi-system Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1999, 2000, 2001, 2002, 2003  Charles MacDonald
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
#include "gamepad.h"
#include <trio/trio.h>

namespace MDFN_IEN_MD
{
/*--------------------------------------------------------------------------*/
/* Master System 2-button gamepad                                           */
/*--------------------------------------------------------------------------*/
class Gamepad2 final : public MD_Input_Device
{
        public:
        Gamepad2();
        virtual ~Gamepad2() override;
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;
        virtual void UpdatePhysicalState(const void *data) override;
        virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;

        private:
        uint8 buttons;
};

/*--------------------------------------------------------------------------*/
/* Genesis 3-button gamepad                                                 */
/*--------------------------------------------------------------------------*/
class Gamepad3 final : public MD_Input_Device
{
        public:
        Gamepad3();
        virtual ~Gamepad3() override;
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;
        virtual void UpdatePhysicalState(const void *data) override;
	virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;

	private:
	uint8 buttons;
};

/*--------------------------------------------------------------------------*/
/* Fighting Pad 6B                                                          */
/*--------------------------------------------------------------------------*/
class Gamepad6 final : public MD_Input_Device
{
        public:
        Gamepad6();
        virtual ~Gamepad6() override;

	virtual void Power(void) override;

        virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;
        virtual void UpdatePhysicalState(const void *data) override;
        virtual void BeginTimePeriod(const int32 timestamp_base) override;
        virtual void EndTimePeriod(const int32 master_timestamp) override;

        virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;

        private:
	void Run(const int32 master_timestamp);

	int32 prev_timestamp;
	int32 count;
	bool old_select;
	int32 timeout;
	uint16 buttons;

	bool compat_mode;
};

const IDIISG Gamepad2IDII =
{
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("a", "A", 5, NULL),
 IDIIS_ButtonCR("b", "B", 6, NULL),
 IDIIS_Button("start", "Start", 4, NULL),
};

Gamepad2::Gamepad2()
{
 buttons = 0;
}

Gamepad2::~Gamepad2()
{

}

void Gamepad2::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(buttons),
  SFEND
 };

 char sname[64];

 trio_snprintf(sname, sizeof(sname), "%s-gp2", section_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {

 }
}


void Gamepad2::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
 bus = (bus &~ 0x3F) | (0x3F & ~buttons);
}

void Gamepad2::UpdatePhysicalState(const void *data)
{
 buttons = *(uint8 *)data;
}

const IDIISG GamepadIDII =
{
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("b", "B", 6, NULL),
 IDIIS_ButtonCR("c", "C", 7, NULL),
 IDIIS_ButtonCR("a", "A", 5, NULL),
 IDIIS_Button("start", "Start", 4, NULL),
};

Gamepad3::Gamepad3()
{
 buttons = 0;
}

Gamepad3::~Gamepad3()
{

}

void Gamepad3::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
 const bool select = (bus >> 6) & 1;
 uint8 temp;

 if(select)
  temp = 0x3F & ~buttons;
 else
  temp = 0x33 & ~(buttons & 0x3) & ~((buttons >> 2) & 0x30);

 bus = (bus & ~0x3F) | temp;
}

void Gamepad3::UpdatePhysicalState(const void *data)
{
 buttons = *(uint8 *)data;
}

void Gamepad3::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(buttons),
  SFEND
 };

 char sname[64];

 trio_snprintf(sname, sizeof(sname), "%s-gp3", section_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {

 }
}


const IDIISG Gamepad6IDII =
{
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("b", "B", 6, NULL),
 IDIIS_ButtonCR("c", "C", 7, NULL),
 IDIIS_ButtonCR("a", "A", 5, NULL),
 IDIIS_Button("start", "Start", 4, NULL),
 IDIIS_ButtonCR("z", "Z", 10, NULL),
 IDIIS_ButtonCR("y", "Y", 9, NULL),
 IDIIS_ButtonCR("x", "X", 8, NULL),
 IDIIS_Button("mode", "Mode", 11, NULL),
};

Gamepad6::Gamepad6()
{
 buttons = 0;
 old_select = 0;
 prev_timestamp = 0;
}

Gamepad6::~Gamepad6()	// Destructor.  DEEEEEEEE.  Don't put variables to initialize here again!
{

}

void Gamepad6::Power(void)
{
 count = 0;
 timeout = 0;

 //compat_mode = false; //(bool)(buttons & (1 << 11));
 //compat_mode_counter = 4474431; // ~5 video frames
 compat_mode = (bool)(buttons & (1 << 11));
}

void Gamepad6::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(old_select),
  SFVAR(buttons),
  SFVAR(count),
  SFVAR(timeout),
  SFVAR(compat_mode),
  SFEND
 };
 char sname[64];

 trio_snprintf(sname, sizeof(sname), "%s-gp6", section_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {

 }
}


void Gamepad6::Run(const int32 master_timestamp)
{
 const int32 clocks = master_timestamp - prev_timestamp;

 //printf("%d\n", master_timestamp - prev_timestamp);
#if 0
 if(compat_mode_counter >= 0)
 {
  if(!(buttons & (1 << 11)))
   compat_mode_counter = false;
  else
  {
   compat_mode_counter -= clocks;
   if(compat_mode_counter <= 0)
    compat_mode = true;
  }
 }
#endif

 timeout += clocks;

 if(timeout >= 8192 * 7)
 {
  timeout = 0;
  count = 0;

  //if(!select)
  // count++;
  //printf("TIMEOUT: %d\n", select);
 }

 prev_timestamp = master_timestamp;
}

void Gamepad6::BeginTimePeriod(const int32 timestamp_base)
{
 //printf("Begin: %d\n", timestamp_base);
 prev_timestamp = timestamp_base;
}

void Gamepad6::EndTimePeriod(const int32 master_timestamp)
{
 //printf("End: %d\n", master_timestamp);
 Run(master_timestamp);
}

/*
 How it's implemented here(copy/pasted from Charles' doc, and rearranged a bit):

 Count:

 0      TH = 0 : ?0SA00DU    3-button pad return value
 0      TH = 1 : ?1CBRLDU    3-button pad return value

 1      TH = 0 : ?0SA00DU    3-button pad return value
 1      TH = 1 : ?1CBRLDU    3-button pad return value

 2      TH = 0 : ?0SA00DU    3-button pad return value
 2      TH = 1 : ?1CBRLDU    3-button pad return value

 3      TH = 0 : ?0SA0000    D3-0 are forced to '0'
 3      TH = 1 : ?1CBMXYZ    Extra buttons returned in D3-0

 4      TH = 0 : ?0SA1111    D3-0 are forced to '1'
 4      TH = 1 : ?1CBRLDU    3-button pad return value

 ...    TH = 0 : ?0SA00DU    3-button pad return value
 ...    TH = 1 : ?1CBRLDU    3-button pad return value

*/

/*
 6-button controller games to test when making changes:
	Comix Zone

 6-button controller incompatible games(incomplete):
	Ms. Pac Man
*/

void Gamepad6::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
 Run(master_timestamp);

 const bool select = (bus >> 6) & 1;
 uint8 temp = 0x3F;

 // Only take action if TH changed.
 if(select != old_select)
 {
  timeout = 0;
  old_select = select;

  if(!select && count < 5 && !compat_mode)	// If TH is going from 1->0, and we haven't reached the end yet, increment the counter.
   count++;
 }

 switch(count)
 {
     case 5:
     case 0:
     case 1:
     case 2:
	if(select)
	 temp = 0x3F & ~buttons;
	else
         temp = 0x33 & ~(buttons & 0x3) & ~((buttons >> 2) & 0x30);
        break;

     case 3:
        if(select)
         temp = (0x30 & ~buttons) | (0x0F & ~(buttons >> 8));
	else
	 temp = 0x30 & ~((buttons >> 2) & 0x30);
	break;

     case 4:
	if(select)
	 temp = 0x3F & ~buttons;
	else
	 temp = 0x3F & ~((buttons >> 2) & 0x30);
	break;
 }

 //printf("Read: %d 0x%02x\n", (count << 1) | select, temp);
 bus = (bus & ~0x3F) | temp;
}

void Gamepad6::UpdatePhysicalState(const void *data)
{
 //printf("Buttons: %04x\n", MDFN_de16lsb((uint8 *)data));
 buttons = MDFN_de16lsb((uint8 *)data);
}

MD_Input_Device *MDInput_MakeMS2B(void)
{
 return new Gamepad2;
}

MD_Input_Device *MDInput_MakeMD3B(void)
{
 return new Gamepad3;
}

MD_Input_Device *MDInput_MakeMD6B(void)
{
 return new Gamepad6;
}

}
