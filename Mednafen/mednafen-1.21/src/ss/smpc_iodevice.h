/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* smpc_iodevice.h:
**  Copyright (C) 2015-2017 Mednafen Team
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

#ifndef __MDFN_SS_SMPC_IODEVICE_H
#define __MDFN_SS_SMPC_IODEVICE_H

namespace MDFN_IEN_SS
{

class IODevice
{
 public:

 IODevice() MDFN_COLD;
 virtual ~IODevice() MDFN_COLD;

 virtual void Power(void) MDFN_COLD;

 virtual void TransformInput(uint8* const data, float gun_x_scale, float gun_x_offs) const;
 //
 // time_elapsed is emulated time elapsed since last call to UpdateInput(), in microseconds;
 // it's mostly for keyboard emulation, to keep the implementation from becoming unnecessarily complex.
 //
 virtual void UpdateInput(const uint8* data, const int32 time_elapsed);
 virtual void UpdateOutput(uint8* data);
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix);

 virtual void Draw(MDFN_Surface* surface, const MDFN_Rect& drect, const int32* lw, int ifield, float gun_x_scale, float gun_x_offs) const;

 //
 // timestamp passed to UpdateBus() and LineHook() may exceed that as specified by NextEventTS under certain conditions(behind emulated multitap) for performance reasons,
 // so write code that can handle this.
 //
 virtual uint8 UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted);
 virtual void LineHook(const sscpu_timestamp_t timestamp, int32 out_line, int32 div, int32 coord_adj);
 virtual void ResetTS(void);
 sscpu_timestamp_t NextEventTS = SS_EVENT_DISABLED_TS;
 sscpu_timestamp_t LastTS = 0;
};

}
#endif
