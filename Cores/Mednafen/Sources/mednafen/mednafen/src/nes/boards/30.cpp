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

static uint8 latch;
static bool osm_allowed;

static INLINE void UNROM512_Sync(void)
{
 setchr8((latch >> 5) & 0x3);
 setprg16(0x8000, latch & 0x1F);

 if(osm_allowed)
  setmirror((latch & 0x80) ? MI_1 : MI_0);
}

static DECLFW(UNROM512_Write)
{
 latch = V;
 UNROM512_Sync();
}

static void UNROM512_Reset(CartInfo *info)
{
 latch = 0x00;
 setprg16(0xC000, 0x1F);
 UNROM512_Sync();
}

static int UNROM512_StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(latch),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");

 if(load)
  UNROM512_Sync();

 return(ret);
}

int Mapper30_Init(CartInfo *info)
{
 info->Power = UNROM512_Reset;
 info->StateAction = UNROM512_StateAction;

 SetReadHandler(0x8000, 0xFFFF, CartBR);
 SetWriteHandler(0x8000, 0xFFFF, UNROM512_Write);

 osm_allowed = (info->mirror == 2);

 return(1);
}

}
