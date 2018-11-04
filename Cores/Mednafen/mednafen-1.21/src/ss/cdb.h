/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* cdb.h:
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

#ifndef __MDFN_SS_CDB_H
#define __MDFN_SS_CDB_H

class CDIF;

namespace MDFN_IEN_SS
{

void CDB_Init(void) MDFN_COLD;
void CDB_Kill(void) MDFN_COLD;
void CDB_StateAction(StateMem* sm, const unsigned load, const bool data_only) MDFN_COLD;

void CDB_SetDisc(bool tray_open, CDIF *cdif) MDFN_COLD;

void CDB_Write_DBM(uint32 offset, uint16 DB, uint16 mask) MDFN_HOT;
uint16 CDB_Read(uint32 offset) MDFN_HOT;

void CDB_Reset(bool powering_up) MDFN_COLD;

sscpu_timestamp_t CDB_Update(sscpu_timestamp_t timestamp);
void CDB_ResetTS(void);

void CDB_GetCDDA(uint16* outbuf);	// writes to outbuf[0] and outbuf[1]


void CDB_SetClockRatio(uint32 ratio);
void CDB_ResetCD(void);
void CDB_SetCDActive(bool active);

}

#endif
