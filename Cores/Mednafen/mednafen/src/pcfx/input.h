/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* input.h:
**  Copyright (C) 2006-2016 Mednafen Team
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

#ifndef __MDFN_PCFX_INPUT_H
#define __MDFN_PCFX_INPUT_H

namespace MDFN_IEN_PCFX
{

enum
{
 FX_SIG_MOUSE = 0xD,
 FX_SIG_TAP = 0xE,
 FX_SIG_PAD = 0xF
};

class PCFX_Input_Device
{
 public:
// PCFX_Input_Device(int which); // "which" is advisory and only should be used in status messages.

 virtual ~PCFX_Input_Device();

 virtual uint32 ReadTransferTime(void);
 virtual uint32 WriteTransferTime(void);

 virtual uint32 Read(void);
 virtual void Write(uint32 data);


 virtual void Power(void);

 virtual void TransformInput(uint8* data, const bool DisableSR);
 virtual void Frame(const void *data);
 virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_name);
};


void FXINPUT_Init(void) MDFN_COLD;
void FXINPUT_SettingChanged(const char *name);

void FXINPUT_TransformInput(void);
void FXINPUT_SetInput(unsigned port, const char *type, uint8 *ptr);

uint16 FXINPUT_Read16(uint32 A, const v810_timestamp_t timestamp);
uint8 FXINPUT_Read8(uint32 A, const v810_timestamp_t timestamp);

void FXINPUT_Write8(uint32 A, uint8 V, const v810_timestamp_t timestamp);
void FXINPUT_Write16(uint32 A, uint16 V, const v810_timestamp_t timestamp);

void FXINPUT_Frame(void);
void FXINPUT_StateAction(StateMem *sm, const unsigned load, const bool data_only);

v810_timestamp_t FXINPUT_Update(const v810_timestamp_t timestamp);
void FXINPUT_ResetTS(int32 ts_base);

extern const std::vector<InputPortInfoStruct> PCFXPortInfo;

#ifdef WANT_DEBUGGER

enum
{
 FXINPUT_GSREG_KPCTRL0 = 0,
 FXINPUT_GSREG_KPCTRL1
};

uint32 FXINPUT_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void FXINPUT_SetRegister(const unsigned int id, uint32 value);
#endif

}

#endif
