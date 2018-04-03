/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* keyboard.h:
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

#ifndef __MDFN_SS_INPUT_KEYBOARD_H
#define __MDFN_SS_INPUT_KEYBOARD_H

namespace MDFN_IEN_SS
{

class IODevice_Keyboard final : public IODevice
{
 public:
 IODevice_Keyboard() MDFN_COLD;
 virtual ~IODevice_Keyboard() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;
 virtual void UpdateInput(const uint8* data, const int32 time_elapsed) override;
 virtual void UpdateOutput(uint8* data) override;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 virtual uint8 UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted) override;

 private:

 uint64 phys[4];
 uint64 processed[4];
 uint8 lock;
 uint8 lock_pend;
 uint16 simbutt;
 uint16 simbutt_pend;
 enum : int { fifo_size = 16 };
 uint16 fifo[fifo_size];
 uint8 fifo_rdp;
 uint8 fifo_wrp;
 uint8 fifo_cnt;
 enum
 {
  LOCK_SCROLL = 0x01,
  LOCK_NUM = 0x02,
  LOCK_CAPS = 0x04
 };

 int16 rep_sc;
 int32 rep_dcnt;

 int16 mkbrk_pend;
 uint8 buffer[12];
 uint8 data_out;
 bool tl;
 int8 phase;
};

extern const IDIISG IODevice_Keyboard_US101_IDII;
}

#endif
