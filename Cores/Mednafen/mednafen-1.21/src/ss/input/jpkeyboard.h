/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* jpkeyboard.h:
**  Copyright (C) 2017-2018 Mednafen Team
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

#ifndef __MDFN_SS_INPUT_JPKEYBOARD_H
#define __MDFN_SS_INPUT_JPKEYBOARD_H

namespace MDFN_IEN_SS
{

class IODevice_JPKeyboard final : public IODevice
{
 public:
 IODevice_JPKeyboard() MDFN_COLD;
 virtual ~IODevice_JPKeyboard() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;
 virtual void UpdateInput(const uint8* data, const int32 time_elapsed) override;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 virtual uint8 UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted) override;

 private:

 uint64 phys[4];
 uint64 processed[4];
 uint8 lock;
 uint8 lock_pend;
 uint16 simbutt;
 uint16 simbutt_pend;
 enum { fifo_size = 16 };
 uint16 fifo[fifo_size];
 uint8 fifo_rdp;
 uint8 fifo_wrp;
 uint8 fifo_cnt;
 enum
 {
  LOCK_SCROLL = 0x01,
  LOCK_CAPS = 0x04
 };

 uint8 rep_sc;
 uint8 rep_sc_pend;
 uint8 rep_dcnt;
 uint8 rep_dcnt_pend;

 int16 mkbrk_pend;
 uint8 buffer[12];
 uint8 data_out;
 bool tl;
 int8 phase;
};

extern const IDIISG IODevice_JPKeyboard_IDII;
}

#endif
