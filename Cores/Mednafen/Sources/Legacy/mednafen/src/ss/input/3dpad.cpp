/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* 3dpad.cpp:
**  Copyright (C) 2016-2017 Mednafen Team
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

#include "common.h"
#include "3dpad.h"

namespace MDFN_IEN_SS
{

IODevice_3DPad::IODevice_3DPad() : dbuttons(0), mode(false)
{

}

IODevice_3DPad::~IODevice_3DPad()
{

}

void IODevice_3DPad::Power(void)
{
 phase = -1;
 tl = true;
 data_out = 0x01;
}

void IODevice_3DPad::UpdateInput(const uint8* data, const int32 time_elapsed)
{
 const uint16 dtmp = MDFN_de16lsb(&data[0]);

 dbuttons = (dbuttons & 0x8800) | (dtmp & 0x0FFF);
 mode = (bool)(dtmp & 0x1000);

 for(unsigned axis = 0; axis < 2; axis++)
 {
  int32 tmp = MDFN_de16lsb(&data[0x2 + (axis << 1)]);

  if(tmp >= (32768 - 128) && tmp < 32768)
   tmp = 32768;

  tmp = (tmp * 255 + 32767) / 65535;
  thumb[axis] = tmp;
 }

 for(unsigned w = 0; w < 2; w++)
 {
  shoulder[w] = (MDFN_de16lsb(&data[0x6 + (w << 1)]) * 255 + 32767) / 65535;

  // May not be right for digital mode, but shouldn't matter too much:
  if(shoulder[w] <= 0x55)
   dbuttons &= ~(0x0800 << (w << 2));
  else if(shoulder[w] >= 0x8E)
   dbuttons |= 0x0800 << (w << 2);
 }

 //printf("DButtons: %04x, Mode: %d, Thumb0: %02x, Thumb1: %02x, Shoulder0: %02x, Shoulder1: %02x\n", dbuttons, mode, thumb[0], thumb[1], shoulder[0], shoulder[1]);
}

void IODevice_3DPad::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(dbuttons),
  SFVAR(mode),

  SFVAR(thumb),
  SFVAR(shoulder),

  SFVAR(buffer),
  SFVAR(data_out),
  SFVAR(tl),

  SFVAR(phase),
  SFEND
 };
 char section_name[64];
 trio_snprintf(section_name, sizeof(section_name), "%s_3DPad", sname_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
  Power();
 else if(load)
 {
  if(phase < 0)
   phase = -1;
  else
   phase &= 0xF;
 }
}

uint8 IODevice_3DPad::UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted)
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
   if(phase < 15)
   {
    tl = !tl;
    phase++;
   }

   if(!phase)
   {
    if(mode)
    {   
     buffer[ 0] = 0x1;
     buffer[ 1] = 0x6;
     buffer[ 2] = (((dbuttons >>  0) & 0xF) ^ 0xF);
     buffer[ 3] = (((dbuttons >>  4) & 0xF) ^ 0xF);
     buffer[ 4] = (((dbuttons >>  8) & 0xF) ^ 0xF);
     buffer[ 5] = (((dbuttons >> 12) & 0xF) ^ 0xF);
     buffer[ 6] = (thumb[0] >> 4) & 0xF;
     buffer[ 7] = (thumb[0] >> 0) & 0xF;
     buffer[ 8] = (thumb[1] >> 4) & 0xF;
     buffer[ 9] = (thumb[1] >> 0) & 0xF;
     buffer[10] = (shoulder[0] >> 4) & 0xF;
     buffer[11] = (shoulder[0] >> 0) & 0xF;
     buffer[12] = (shoulder[1] >> 4) & 0xF;
     buffer[13] = (shoulder[1] >> 0) & 0xF;
     buffer[14] = 0x0;
     buffer[15] = 0x1;
    }
    else
    {
     phase = 8;
     buffer[ 8] = 0x0;
     buffer[ 9] = 0x2;
     buffer[10] = (((dbuttons >>  0) & 0xF) ^ 0xF);
     buffer[11] = (((dbuttons >>  4) & 0xF) ^ 0xF);
     buffer[12] = (((dbuttons >>  8) & 0xF) ^ 0xF);
     buffer[13] = (((dbuttons >> 12) & 0xF) ^ 0xF);
     buffer[14] = 0x0;
     buffer[15] = 0x1;
    }
   }

   data_out = buffer[phase];
  }
 }

 tmp = (tl << 4) | data_out;

 return (smpc_out & (smpc_out_asserted | 0xE0)) | (tmp &~ smpc_out_asserted);
}

static const IDIIS_SwitchPos ModeSwitchPositions[] =
{
 { "digital", gettext_noop("Digital(+)") },
 { "analog", gettext_noop("Analog(○)"), gettext_noop("Analog mode is not compatible with all games.  For some compatible games, analog mode reportedly must be enabled before the game boots up for the game to recognize it properly.") },
};

IDIISG IODevice_3DPad_IDII =
{
 IDIIS_Button("up", "D-Pad UP ↑", 0, "down"),
 IDIIS_Button("down", "D-Pad DOWN ↓", 1, "up"),
 IDIIS_Button("left", "D-Pad LEFT ←", 2, "right"),
 IDIIS_Button("right", "D-Pad RIGHT →", 3, "left"),

 IDIIS_Button("b", "B", 6),
 IDIIS_Button("c", "C", 7),
 IDIIS_Button("a", "A", 5),
 IDIIS_Button("start", "START", 4),

 IDIIS_Button("z", "Z", 10),
 IDIIS_Button("y", "Y", 9),
 IDIIS_Button("x", "X", 8),
 IDIIS_Padding<1>(),

 IDIIS_Switch("mode", "Mode", 17, ModeSwitchPositions, false),

 IDIIS_Axis(	"analog", "Analog",
		"left", "LEFT ←",
		"right", "RIGHT →", 14),

 IDIIS_Axis(	"analog", "Analog",
		"up", "UP ↑",
		"down", "DOWN ↓", 13),

 IDIIS_AnaButton("rs", "Right Shoulder (Analog)", 12),
 IDIIS_AnaButton("ls", "Left Shoulder (Analog)", 11),
};




}
