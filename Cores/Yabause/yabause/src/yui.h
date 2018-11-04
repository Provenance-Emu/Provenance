/*  Copyright 2004-2005 Guillaume Duhamel
    Copyright 2004-2006 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#ifndef YUI_H
#define YUI_H

#include "cdbase.h"
#include "sh2core.h"
#include "sh2int.h"
#include "scsp.h"
#include "smpc.h"
#include "vdp1.h"
#include "yabause.h"

/* If Yabause encounters any fatal errors, it sends the error text to this function */
void YuiErrorMsg(const char *string);

/* Tells the yui to exchange front and back video buffers. This may end
   up being moved to the Video Core. */
void YuiSwapBuffers(void);

//////////////////////////////////////////////////////////////////////////////
// Helper functions(you can use these in your own port)
//////////////////////////////////////////////////////////////////////////////

/* int MappedMemoryLoad(const char *filename, u32 addr);

   Loads the specified file(filename) to specified address(addr). Returns zero
   on success, less than zero if an error has occured.
   Note: Some areas in memory are read-only and won't acknowledge any writes.
*/

/* int MappedMemorySave(const char *filename, u32 addr, u32 size);

   Saves data from specified address(addr) by specified amount of bytes(size)
   to specified file(filename). Returns zero on success, less than zero if
   an error has occured.
   Note: Some areas in memory are write-only and will only return zero on
   reads.
*/

/* void MappedMemoryLoadExec(const char *filename, u32 pc);

   Loads the specified file(filename) to specified address(pc) and sets
   Master SH2 to execute from there.
   Note: Some areas in memory are read-only and won't acknowledge any writes.
*/

/* void FormatBackupRam(void *mem, u32 size);

   Formats the specified Backup Ram memory area(mem) of specified size(size).
*/

/* void SH2Disasm(u32 v_addr, u16 op, int mode, char *string);

   Generates a disassembled instruction into specified string(string) based
   on specified address(v_addr) and specified opcode(op). mode should always
   be 0.
*/

/* void SH2Step(SH2_struct *context);

   For the specified SH2 context(context), it executes 1 instruction. context
   should be either MSH2 or SSH2.
*/

/* void SH2GetRegisters(SH2_struct *context, sh2regs_struct * r);

   For the specified SH2 context(context), copies the current registers into
   the specified structure(r). context should be either MSH2 or SSH2.
*/

/* void SH2SetRegisters(SH2_struct *context, sh2regs_struct * r);

   For the specified SH2 context(context), copies the specified structure(r)
   to the current registers. context should be either MSH2 or SSH2.
*/

/* void SH2SetBreakpointCallBack(SH2_struct *context, void (*func)(void *, u32, void *), void *userdata);

   For the specified SH2 context(context), it sets the breakpoint handler
   function(func). context should be either MSH2 or SSH2.
*/

/* int SH2AddCodeBreakpoint(SH2_struct *context, u32 addr);

   For the specified SH2 context(context), it adds a code breakpoint for
   specified address(addr). context should be either MSH2 or SSH2. Returns
   zero on success, or less than zero if an error has occured(such as the
   breakpoint list being full)
*/

/* int SH2DelCodeBreakpoint(SH2_struct *context, u32 addr);

   For the specified SH2 context(context), it deletes a code breakpoint for
   specified address(addr). context should be either MSH2 or SSH2. Returns
   zero on success, or less than zero if an error has occured.
*/

/* codebreakpoint_struct *SH2GetBreakpointList(SH2_struct *context);

   For the specified SH2 context(context), it returns a pointer to the
   code breakpoint list for the processor. context should be either MSH2 or
   SSH2.
*/

/* void SH2ClearCodeBreakpoints(SH2_struct *context);

   For the specified SH2 context(context), it deletes every code breakpoint
   entry. context should be either MSH2 or SSH2.
*/

/* u32 M68KDisasm(u32 addr, char *outstring);

   Generates a disassembled instruction into specified string(string) based on
   instruction stored at specified address(addr). Returns address of next
   instruction.
*/

/* void M68KStep();

   Executes 1 68k instruction.
*/

/* void M68KGetRegisters(m68kregs_struct *regs);

   Copies the current 68k registers into the specified structure(regs).
*/

/* void M68KSetRegisters(m68kregs_struct *regs);

   Copies the specified structure(regs) to the current 68k registers.
*/

/* void M68KSetBreakpointCallBack(void (*func)(u32));

   It sets the breakpoint handler function(func) for the 68k. 
*/

/* int M68KAddCodeBreakpoint(u32 addr);

   It adds a 68K code breakpoint for specified address(addr). Returns zero on
   success, or less than zero if an error has occured(such as the breakpoint
   list being full)
*/

/* int M68KDelCodeBreakpoint(u32 addr);

   It deletes a 68k code breakpoint for specified address(addr). Returns zero
   on success, or less than zero if an error has occured.
*/

/* m68kcodebreakpoint_struct *M68KGetBreakpointList();

   It returns a pointer to the code breakpoint list for the 68k.
*/

/* void M68KClearCodeBreakpoints();

   It deletes every code breakpoint entry for the 68k.
*/

/* void ScuDspDisasm(u8 addr, char *outstring);

   Generates a disassembled instruction into specified string(string) based on
   instruction stored at specified address(addr).
*/

/* void ScuDspStep(void);

   Executes 1 SCU DSP step
*/

/* void ScuDspGetRegisters(scudspregs_struct *regs);

   Copies the current SCU DSP registers into the specified structure(regs).
*/

/* void ScuDspSetRegisters(scudspregs_struct *regs);

   Copies the specified structure(regs) to the current SCU DSP registers.
*/

/* void ScuDspSetBreakpointCallBack(void (*func)(u32));

   It sets the breakpoint handler function(func) for the SCU DSP.
*/

/* int ScuDspAddCodeBreakpoint(u32 addr);

   It adds a SCU DSP code breakpoint for specified address(addr). Returns zero
   on success, or less than zero if an error has occured(such as the
   breakpoint list being full)
*/

/* int ScuDspDelCodeBreakpoint(u32 addr);

   It deletes a SCU DSP code breakpoint for specified address(addr). Returns
   zero on success, or less than zero if an error has occured.
*/

/* scucodebreakpoint_struct *ScuDspGetBreakpointList();

   It returns a pointer to the code breakpoint list for the SCU DSP.
*/

/* void ScuDspClearCodeBreakpoints();

   It deletes every code breakpoint entry for the SCU DSP.
*/

/* void Vdp2DebugStatsRBG0(char *outstring, int *isenabled);
   void Vdp2DebugStatsNBG0(char *outstring, int *isenabled);
   void Vdp2DebugStatsNBG1(char *outstring, int *isenabled);
   void Vdp2DebugStatsNBG2(char *outstring, int *isenabled);
   void Vdp2DebugStatsNBG3(char *outstring, int *isenabled);

   Fills a specified string pointer(outstring) with debug information for the
   specified screen. It also fills a variable(isenabled) with the screen's
   current status 
*/

#endif
