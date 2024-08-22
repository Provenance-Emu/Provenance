/* Mednafen - Multi-system Emulator
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

#ifndef __WSWAN_INTERRUPT_H
#define __WSWAN_INTERRUPT_H

namespace MDFN_IEN_WSWAN
{

enum
{
 WSINT_SERIAL_SEND = 0,
 WSINT_KEY_PRESS,
 WSINT_RTC_ALARM,
 WSINT_SERIAL_RECV,
 WSINT_LINE_HIT,
 WSINT_VBLANK_TIMER,
 WSINT_VBLANK,
 WSINT_HBLANK_TIMER
};

void WSwan_InterruptAssert(unsigned which, bool asserted);
void WSwan_Interrupt(unsigned);

void WSwan_InterruptWrite(uint32 A, uint8 V);
uint8 WSwan_InterruptRead(uint32 A);
void WSwan_InterruptCheck(void);
void WSwan_InterruptStateAction(StateMem *sm, const unsigned load, const bool data_only);
void WSwan_InterruptReset(void);
void WSwan_InterruptDebugForce(unsigned int level);

#ifdef WANT_DEBUGGER
enum
{
 INT_GSREG_IASSERTED = 0,
 INT_GSREG_ISTATUS,
 INT_GSREG_IENABLE,
 INT_GSREG_IVECTORBASE
};
uint32 WSwan_InterruptGetRegister(const unsigned int id, char *special, const uint32 special_len);
void WSwan_InterruptSetRegister(const unsigned int id, uint32 value);

#endif

}

#endif
