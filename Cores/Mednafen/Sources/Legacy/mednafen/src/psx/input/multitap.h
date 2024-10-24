/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* multitap.h:
**  Copyright (C) 2012-2016 Mednafen Team
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

#ifndef __MDFN_PSX_INPUT_MULTITAP_H
#define __MDFN_PSX_INPUT_MULTITAP_H

namespace MDFN_IEN_PSX
{

class InputDevice_Multitap final : public InputDevice
{
 public:

 InputDevice_Multitap() MDFN_COLD;
 virtual ~InputDevice_Multitap() override MDFN_COLD;
 virtual void Power(void) override MDFN_COLD;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 virtual void Update(const pscpu_timestamp_t timestamp) override;
 virtual void ResetTS(void) override;

 virtual bool RequireNoFrameskip(void) override;
 virtual pscpu_timestamp_t GPULineHook(const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider) override;
 virtual void DrawCrosshairs(uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock) override;

 void SetSubDevice(unsigned int sub_index, InputDevice *device, InputDevice *mc_device);

 //
 //
 //
 virtual void SetDTR(bool new_dtr) override;
 virtual bool GetDSR(void) override;
 virtual bool Clock(bool TxD, int32 &dsr_pulse_delay) override;

 private:

 InputDevice *pad_devices[4];
 InputDevice *mc_devices[4];

 bool dtr;

 int selected_device;
 bool full_mode_setting;

 bool full_mode;
 bool mc_mode;
 bool prev_fm_success;

 uint8 fm_dp;	// Device-present.
 uint8 fm_buffer[4][8];

 uint8 sb[4][8];

 bool fm_command_error;

 uint8 command;
 uint8 receive_buffer;
 uint8 bit_counter;
 uint8 byte_counter;
};

}

#endif
