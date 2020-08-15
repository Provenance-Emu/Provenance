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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <dpmi.h>
#include <string.h>

#include "dos.h"

int InitMouse(void)
{
 __dpmi_regs regs;

 memset(&regs,0,sizeof(regs));
 regs.x.ax=0;
 __dpmi_int(0x33,&regs);
 if(regs.x.ax!=0xFFFF)
  return(0);

 memset(&regs,0,sizeof(regs));
 regs.x.ax=0x7;
 regs.x.cx=0;           // Min X
 regs.x.dx=260;         // Max X
 __dpmi_int(0x33,&regs);

 memset(&regs,0,sizeof(regs));
 regs.x.ax=0x8;
 regs.x.cx=0;           // Min Y
 regs.x.dx=260;         // Max Y
 __dpmi_int(0x33,&regs);

 memset(&regs,0,sizeof(regs));
 regs.x.ax=0xF;
 regs.x.cx=8;           // Mickey X
 regs.x.dx=8;           // Mickey Y
 __dpmi_int(0x33,&regs);

 memset(&regs,0,sizeof(regs));
 regs.x.ax=0x2;
 __dpmi_int(0x33,&regs);

 return(1);
}

uint32 GetMouseData(uint32 *x, uint32 *y)
{
 if(FCEUI_IsMovieActive()<0)
   return;

 __dpmi_regs regs;

 memset(&regs,0,sizeof(regs));
 regs.x.ax=0x3;
 __dpmi_int(0x33,&regs);

 *x=regs.x.cx;
 *y=regs.x.dx;
 return(regs.x.bx&3);
}

void KillMouse(void)
{

}
