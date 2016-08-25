/*
 * DrZ80 Version 1.0
 * Z80 Emulator by Reesy
 * Copyright 2005 Reesy
 * 
 * This file is part of DrZ80.
 * 
 *     DrZ80 is free software; you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation; either version 2 of the License, or
 *     (at your option) any later version.
 * 
 *     DrZ80 is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 * 
 *     You should have received a copy of the GNU General Public License
 *     along with DrZ80; if not, write to the Free Software
 *     Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 * 
 */

#ifdef __cplusplus
extern "C" {
#endif

#ifndef DRZ80_H
#define DRZ80_H

extern int DrZ80Ver; /* Version number of library */

struct DrZ80
{ 
  unsigned int Z80PC;           /*0x00 - PC Program Counter (Memory Base + PC) */
  unsigned int Z80A;            /*0x04 - A Register:   0xAA------ */
  unsigned int Z80F;            /*0x08 - F Register:   0x------FF */
  unsigned int Z80BC;           /*0x0C - BC Registers: 0xBBCC---- */
  unsigned int Z80DE;           /*0x10 - DE Registers: 0xDDEE---- */
  unsigned int Z80HL;           /*0x14 - HL Registers: 0xHHLL---- */
  unsigned int Z80SP;           /*0x18 - SP Stack Pointer (Memory Base + PC) */
  unsigned int Z80PC_BASE;      /*0x1C - PC Program Counter (Memory Base) */
  unsigned int Z80SP_BASE;      /*0x20 - SP Stack Pointer (Memory Base) */
  unsigned int Z80IX;           /*0x24 - IX Index Register */
  unsigned int Z80IY;           /*0x28 - IY Index Register */
  unsigned int Z80I;            /*0x2C - I Interrupt Register */
  unsigned int Z80A2;           /*0x30 - A' Register:    0xAA------ */
  unsigned int Z80F2;           /*0x34 - F' Register:    0x------FF */
  unsigned int Z80BC2;          /*0x38 - B'C' Registers: 0xBBCC---- */
  unsigned int Z80DE2;          /*0x3C - D'E' Registers: 0xDDEE---- */
  unsigned int Z80HL2;          /*0x40 - H'L' Registers: 0xHHLL---- */    
  int cycles;		            /*0x44 - Cycles pending to be executed yet */
  int previouspc;	            /*0x48 - Previous PC */
  unsigned char Z80_IRQ;        /*0x4C - Set IRQ Number (must be halfword aligned) */   
  unsigned char Z80IF;          /*0x4D - Interrupt Flags:  bit0=_IFF1, bit1=_IFF2, bit2=_HALT, b3=NMI */
  unsigned char Z80IM;          /*0x4E - Set IRQ Mode */
  unsigned char spare;          /*0x4F - N/A */
  unsigned int z80irqvector;    /*0x50 - Set IRQ Vector i.e. 0xFF=RST */
  void (*z80_irq_callback )(void);
  void (*z80_write8 )(unsigned char d,unsigned short a); 
  void (*z80_write16 )(unsigned short d,unsigned short a); 
  unsigned char (*z80_in)(unsigned short p);
  void (*z80_out )(unsigned short p,unsigned char d);
  unsigned char (*z80_read8)(unsigned short a);
  unsigned short (*z80_read16)(unsigned short a);
  unsigned int (*z80_rebaseSP)(unsigned short new_sp);
  unsigned int (*z80_rebasePC)(unsigned short new_pc);
  unsigned int bla;
};

extern int DrZ80Run(struct DrZ80 *pcy,unsigned int cyc);

#endif

#ifdef __cplusplus
} /* End of extern "C" */
#endif
