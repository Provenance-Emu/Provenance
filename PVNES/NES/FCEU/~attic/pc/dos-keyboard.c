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

#include <stdio.h>
#include <signal.h>
#include <string.h>
#include <pc.h>
#include <dpmi.h>
#include <go32.h>
#include "keyscan.h"

static unsigned char lastsc;
static char keybuf[256];
int newk;

/* Read scan code from port $60 */
/* Acknowledge interrupt( output $20 to port $20) */

static void ihandler(_go32_dpmi_registers *r)
{
 unsigned char scode=inp(0x60);	/* Get scan code. */


 if(scode!=0xE0)
 {
  int offs=0;

  /* I'm only interested in preserving the independent status of the
     right ALT and CONTROL keys.
  */
  if(lastsc==0xE0)
   if((scode&0x7F)==SCAN_LEFTALT || (scode&0x7F)==SCAN_LEFTCONTROL)
    offs=0x80;
  

  keybuf[(scode&0x7f)|offs]=((scode&0x80)^0x80);
  newk++;
 }
 lastsc=scode;

 outp(0x20,0x20);	/* Acknowledge interrupt. */
}

static _go32_dpmi_seginfo KBIBack,KBIBackRM;
static _go32_dpmi_seginfo KBI,KBIRM;
static _go32_dpmi_registers KBIRMRegs;
static int initdone=0;

int InitKeyboard(void)
{
 /* I'll assume that the keyboard is in the correct scancode mode(translated
    mode 2, I think).
 */
  newk=0;
  memset(keybuf,0,sizeof(keybuf));
  KBIRM.pm_offset=KBI.pm_offset=(int)ihandler;
  KBIRM.pm_selector=KBI.pm_selector=_my_cs();

  _go32_dpmi_get_real_mode_interrupt_vector(9,&KBIBackRM);
  _go32_dpmi_allocate_real_mode_callback_iret(&KBIRM, &KBIRMRegs);
  _go32_dpmi_set_real_mode_interrupt_vector(9,&KBIRM);

  _go32_dpmi_get_protected_mode_interrupt_vector(9,&KBIBack);
  _go32_dpmi_allocate_iret_wrapper(&KBI);
  _go32_dpmi_set_protected_mode_interrupt_vector(9,&KBI);
  lastsc=0;
  initdone=1;
  return(1);
}

void KillKeyboard(void)
{
 if(initdone)
 {
  _go32_dpmi_set_protected_mode_interrupt_vector(9,&KBIBack);
  _go32_dpmi_free_iret_wrapper(&KBI);

  _go32_dpmi_set_real_mode_interrupt_vector(9,&KBIBackRM);
  _go32_dpmi_free_real_mode_callback(&KBIRM);
  initdone=0;
 }
}

/* In FCE Ultra, it doesn't matter if the key states change
   in the middle of the keyboard handling code.  If you want
   to use this code elsewhere, you may want to memcpy() keybuf
   to another buffer and return that when GetKeyboard() is
   called.
*/

char *GetKeyboard(void)
{
 return keybuf;
}

/* Returns 1 on new scan codes generated, 0 on no new scan codes. */
int UpdateKeyboard(void)
{
 int t=newk;

 if(t)
 {
  asm volatile(
        "subl %%eax,_newk\n\t"
	:
	: "a" (t)
  );

  if(keybuf[SCAN_LEFTCONTROL] && keybuf[SCAN_C])
   raise(SIGINT);
  return(1);
 }
 return(0);
}
