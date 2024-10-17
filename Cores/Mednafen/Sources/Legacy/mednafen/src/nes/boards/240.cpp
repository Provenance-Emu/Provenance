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

#include "mapinc.h"

namespace MDFN_IEN_NES
{

static uint8 WRAM[8192];
static uint8 latch;

static void Sync(void)
{
 setprg32(0x8000, latch >> 4);
 setchr8(latch & 0xF);
}

static DECLFW(Write)
{
 latch = V;
 Sync();
}

static DECLFW(BWRAM)
{
 WRAM[A-0x6000]=V;
}

static DECLFR(AWRAM)
{
 return(WRAM[A-0x6000]);
}

static void Power(CartInfo *info)
{
 latch = 0xFF;
 Sync();

 if(!info->battery)
  memset(WRAM, 0xFF, 8192);
}

static int StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(latch),
  SFPTR8(WRAM, 8192),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");

 if(load)
 {
  Sync();
 }
 return(ret);
}

static void Close(void)
{

}

int Mapper240_Init(CartInfo *info)
{
 info->Power = Power;
 info->StateAction = StateAction;
 info->Close = Close;

 memset(WRAM, 0xFF, 8192);

 MDFNMP_AddRAM(8192, 0x6000, WRAM);
 if(info->battery)
 {
  info->SaveGame[0] = WRAM;
  info->SaveGameLen[0] = 8192;
 }

 SetReadHandler(0x8000, 0xFFFF, CartBR);
 SetWriteHandler(0x4020, 0x5FFF, Write);

 SetReadHandler(0x6000, 0x7FFF, AWRAM);
 SetWriteHandler(0x6000, 0x7FFF, BWRAM);

 return(1);
}

}
