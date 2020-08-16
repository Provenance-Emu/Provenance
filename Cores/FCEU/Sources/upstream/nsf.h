#ifndef NSF_H
#define NSF_H

/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

typedef struct {
                char ID[5]; /*NESM^Z*/
                uint8 Version;
                uint8 TotalSongs;
                uint8 StartingSong;
                uint8 LoadAddressLow;
                uint8 LoadAddressHigh;
                uint8 InitAddressLow;
                uint8 InitAddressHigh;
                uint8 PlayAddressLow;
                uint8 PlayAddressHigh;
                uint8 SongName[32];
                uint8 Artist[32];
                uint8 Copyright[32];
                uint8 NTSCspeed[2];        // Unused
                uint8 BankSwitch[8];
                uint8 PALspeed[2];         // Unused
                uint8 VideoSystem;
                uint8 SoundChip;
                uint8 Expansion[4];
                uint8 reserve[8];
        } NSF_HEADER;
void NSF_init(void);
void DrawNSF(uint8 *XBuf);
extern NSF_HEADER NSFHeader; //mbg merge 6/29/06
extern uint8 *NSFDATA;
extern int NSFMaxBank;
void NSFDealloc(void);
void NSFDodo(void);
void DoNSFFrame(void);

#endif
