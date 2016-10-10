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

int InitBlitToHigh(int b, uint32 rmask, uint32 gmask, uint32 bmask, int eefx, int specfilt, int specfilteropt);
void SetPaletteBlitToHigh(uint8 *src);
void KillBlitToHigh(void);
void Blit8ToHigh(uint8 *src, uint8 *dest, int xr, int yr, int pitch, int xscale, int yscale);
void Blit8To8(uint8 *src, uint8 *dest, int xr, int yr, int pitch, int xscale, int yscale, int efx, int special);

void Blit32to24(uint32 *src, uint8 *dest, int xr, int yr, int dpitch);
void Blit32to16(uint32 *src, uint16 *dest, int xr, int yr, int dpitch,
        int shiftr[3], int shiftl[3]);


u32 ModernDeemphColorMap(u8* src, u8* srcbuf, int xscale, int yscale);