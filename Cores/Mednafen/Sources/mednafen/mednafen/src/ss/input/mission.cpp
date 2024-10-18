/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* mission.cpp:
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
 Real mission stick has bugs and quirks that aren't emulated here(like apparently latching/updating the physical input state at the end of the
 read sequence instead of near the beginning like other controllers do, resulting in increased latency).
*/


#include "common.h"
#include "mission.h"

namespace MDFN_IEN_SS
{

IODevice_Mission::IODevice_Mission(const bool dual_) : dbuttons(0), afeswitches(0), afspeed(0), dual(dual_)
{

}

IODevice_Mission::~IODevice_Mission()
{

}

void IODevice_Mission::Power(void)
{
 phase = -1;
 tl = true;
 data_out = 0x01;

 // Power-on state not tested:
 afcounter = 0;
 afphase = false;
}

void IODevice_Mission::UpdateInput(const uint8* data, const int32 time_elapsed)
{
 const uint32 dtmp = MDFN_de32lsb(&data[0]);

 dbuttons = (dbuttons & 0xF) | ((dtmp & 0xFFF) << 4);
 afeswitches = ((dtmp >> 12) & 0x8FF) << 4;
 afspeed = (dtmp >> 20) & 0x7;

 for(unsigned stick = 0; stick < (dual ? 2 : 1); stick++)
 {
  for(unsigned axis = 0; axis < 3; axis++)
  {
   int32 tmp = MDFN_de16lsb(&data[0x3 + ((axis + (stick * 3)) * 2)]);

   axes[stick][axis] = (tmp * 255 + 32767) / 65535;
  }
 }

 //printf("Update: %02x %02x %02x\n", axes[0][0], axes[0][1], axes[0][2]);
}

void IODevice_Mission::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(dbuttons),
  SFVAR(afeswitches),
  SFVAR(afspeed),

  SFVAR(afcounter),
  SFVAR(afphase),

  SFVARN(axes, "&axes[0][0]"),

  SFVAR(buffer),
  SFVAR(data_out),
  SFVAR(tl),

  SFVAR(phase),
  SFEND
 };
 char section_name[64];
 trio_snprintf(section_name, sizeof(section_name), "%s_Mission", sname_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
  Power();
 else if(load)
 {
  afspeed %= 7;

  if(phase < 0)
   phase = -1;
  else
   phase &= 0x1F;
 }
}

uint8 IODevice_Mission::UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted)
{
 uint8 tmp;

 if(smpc_out & 0x40)
 {
  phase = -1;
  tl = true;
  data_out = 0x01;
 }
 else
 {
  if((bool)(smpc_out & 0x20) != tl)
  {
   if(phase < (dual ? 21 : 13))
   {
    tl = !tl;
    phase++;
   }

   if(!phase)
   {
    unsigned dbaf = dbuttons & ((afphase - 1) | ~afeswitches);
    unsigned c = 0;

    // Digital Left
    dbuttons |=  ((axes[0][0] <= 0x56) ? 0x4 : 0);
    dbuttons &= ~((axes[0][0] >= 0x6C) ? 0x4 : 0);

    // Digital Right
    dbuttons |=  ((axes[0][0] >= 0xAB) ? 0x8 : 0);
    dbuttons &= ~((axes[0][0] <= 0x95) ? 0x8 : 0);

    // Digital Up
    dbuttons |=  ((axes[0][1] <= 0x54) ? 0x1 : 0);
    dbuttons &= ~((axes[0][1] >= 0x6A) ? 0x1 : 0);

    // Digital Down
    dbuttons |=  ((axes[0][1] >= 0xA9) ? 0x2 : 0);
    dbuttons &= ~((axes[0][1] <= 0x94) ? 0x2 : 0);

    if(!afcounter)
    {
     static const uint8 speedtab[7] = { 12, 8, 7, 5, 4, 4/* ? */, 1 };
     afphase = !afphase;
     afcounter = speedtab[afspeed];
    }
    afcounter--;

    buffer[c++] = 0x1;
    buffer[c++] = dual ? 0x9 : 0x5;
    buffer[c++] = (((dbaf >>  0) & 0xF) ^ 0xF);
    buffer[c++] = (((dbaf >>  4) & 0xF) ^ 0xF);
    buffer[c++] = (((dbaf >>  8) & 0xF) ^ 0xF);
    buffer[c++] = (((dbaf >> 12) & 0xF) ^ 0xF);

    for(unsigned stick = 0; stick < (dual ? 2 : 1); stick++)
    {
     if(stick)
     {
      // Not sure, looks like something buggy.
      buffer[c++] = 0x0;
      buffer[c++] = 0x0;
     }

     buffer[c++] = (axes[stick][0] >> 4) & 0xF;
     buffer[c++] = (axes[stick][0] >> 0) & 0xF;
     buffer[c++] = (axes[stick][1] >> 4) & 0xF;
     buffer[c++] = (axes[stick][1] >> 0) & 0xF;
     buffer[c++] = (axes[stick][2] >> 4) & 0xF;
     buffer[c++] = (axes[stick][2] >> 0) & 0xF;
    }
    buffer[c++] = 0x0;
    buffer[c++] = 0x1;
   }

   data_out = buffer[phase];
  }
 }

 tmp = (tl << 4) | data_out;

 return (smpc_out & (smpc_out_asserted | 0xE0)) | (tmp &~ smpc_out_asserted);
}

static const IDIIS_SwitchPos SpeedSwitchPositions[] =
{
 { "1", gettext_noop("1/7"), gettext_noop("Slowest") },
 { "2", gettext_noop("2/7") },
 { "3", gettext_noop("3/7") },
 { "4", gettext_noop("4/7") },
 { "5", gettext_noop("5/7") },
 { "6", gettext_noop("6/7") },
 { "7", gettext_noop("7/7"), gettext_noop("Fastest") },
};

static const IDIIS_SwitchPos AFSwitchPositions[] =
{
 { "off", gettext_noop("• (Off)"), },
 { "on", gettext_noop("•• (On)") },
};

IDIISG IODevice_Mission_IDII =
{
 // 0
 IDIIS_Button("b", "B (Stick Left Button)", 6),
 IDIIS_Button("c", "C (Stick Right Button)", 8),
 IDIIS_Button("a", "A (Stick Trigger)", 7),
 IDIIS_Button("start", "START", 9),

 // 4
 IDIIS_Button("z", "Z", 13),
 IDIIS_Button("y", "Y", 12),
 IDIIS_Button("x", "X", 11),
 IDIIS_Button("r", "R", 14),

 // 8
 IDIIS_Padding<3>(),
 IDIIS_Button("l", "L", 10),

 // 12
 IDIIS_Switch("afb", "B AF", 20, AFSwitchPositions),
 IDIIS_Switch("afc", "C AF", 21, AFSwitchPositions),
 IDIIS_Switch("afa", "A AF", 19, AFSwitchPositions),
 IDIIS_Padding<1>(),

 // 16
 IDIIS_Switch("afz", "Z AF", 17, AFSwitchPositions),
 IDIIS_Switch("afy", "Y AF", 16, AFSwitchPositions),
 IDIIS_Switch("afx", "X AF", 15, AFSwitchPositions),
 IDIIS_Switch("afr", "R AF", 22, AFSwitchPositions),

 // 20
 IDIIS_Switch("afspeed", "AF Speed", 23, SpeedSwitchPositions),
 IDIIS_Switch("afl", "L AF", 18, AFSwitchPositions),

 // 24
 IDIIS_Axis(	"stick", "Stick",
		"left", "LEFT ← (Analog)",
		"right", "RIGHT → (Analog)", 1),

 // 40
 IDIIS_Axis(	"stick", "Stick",
		"fore", "FORE ↑ (Analog)",
		"back", "BACK ↓ (Analog)", 0),

 // 56
 IDIIS_Axis(	"throttle", "Throttle",
		"down", "Down (Analog)",
		"up", "Up (Analog)", 2, true),
};

IDIISG IODevice_DualMission_IDII =
{
 // 0
 IDIIS_Button("b", "B (R Stick Left Button)", 15),
 IDIIS_Button("c", "C (R Stick Right Button)", 17),
 IDIIS_Button("a", "A (R Stick Trigger)", 16),
 IDIIS_Button("start", "START", 18),

 // 4
 IDIIS_Button("z", "Z (L Stick Right Button)", 8),
 IDIIS_Button("y", "Y (L Stick Left Button)", 6),
 IDIIS_Button("x", "X (L Stick Trigger)", 7),
 IDIIS_Button("r", "R", 20),

 // 8
 IDIIS_Padding<3>(),
 IDIIS_Button("l", "L", 19),

 // 12
 IDIIS_Switch("afb", "B AF", 26, AFSwitchPositions),
 IDIIS_Switch("afc", "C AF", 27, AFSwitchPositions),
 IDIIS_Switch("afa", "A AF", 25, AFSwitchPositions),
 IDIIS_Padding<1>(),

 // 16
 IDIIS_Switch("afz", "Z AF", 23, AFSwitchPositions),
 IDIIS_Switch("afy", "Y AF", 22, AFSwitchPositions),
 IDIIS_Switch("afx", "X AF", 21, AFSwitchPositions),
 IDIIS_Switch("afr", "R AF", 28, AFSwitchPositions),

 // 20
 IDIIS_Switch("afspeed", "Autofire Speed", 29, SpeedSwitchPositions),
 IDIIS_Switch("afl", "L AF", 24, AFSwitchPositions),

 // 24
 IDIIS_Axis(	"rstick", "R Stick",
		"left", "LEFT ← (Analog)",
		"right", "RIGHT → (Analog)", 11),

 // 40
 IDIIS_Axis(	"rstick", "R Stick",
		"fore", "FORE ↑ (Analog)",
		"back", "BACK ↓ (Analog)", 9),

 // 56
 IDIIS_Axis(	"rthrottle", "R Throttle",
		"down", "Down (Analog)",
		"up", "Up (Analog)", 13, true),

 // 72
 IDIIS_Axis(	"lstick", "L Stick",
		"left", "LEFT ← (Analog)",
		"right", "RIGHT → (Analog)", 2),

 // 88
 IDIIS_Axis(	"lstick", "L Stick",
		"fore", "FORE ↑ (Analog)",
		"back", "BACK ↓ (Analog)", 0),

 // 104
 IDIIS_Axis(	"lthrottle", "L Throttle",
		"down", "Down (Analog)",
		"up", "Up (Analog)", 4, true),
};



}
