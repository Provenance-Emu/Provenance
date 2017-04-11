/*  src/sh2trace.c: SH-2 tracing code for debugging
    Copyright 2009 Andrew Church

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

/*! \file sh2trace.c
    \brief SH2 execution tracing.
*/


#include <stdio.h>
#include "sh2core.h"
#include "sh2d.h"
#include "sh2trace.h"

/*************************************************************************/

/* Define BINARY_LOG to log traces in a binary format (faster than text) */
// #define BINARY_LOG

/* Define GZIP_LOG to compress log as it's created */
#ifdef __linux__
# define GZIP_LOG
#endif

/* Define ECHO_TO_STDERR to log traces to stderr as well as logfile
 * (ignored in BINARY_LOG mode) */
// #define ECHO_TO_STDERR

/*----------------------------------*/

static const u64 trace_start =  000000000ULL;  // First cycle to trace
static const u64 trace_stop  = 2800000000ULL;  // Last cycle to trace + 1

/*----------------------------------*/

static FILE *logfile;                // Trace log file
static u64 cycle_accum = 0;     // Global cycle accumulator
static u64 current_cycles = 0;  // Cycle count on last call to sh2_trace()

/*************************************************************************/

FASTCALL u64 sh2_cycle_count(void)
{
    return current_cycles;
}

/*-----------------------------------------------------------------------*/

FASTCALL void sh2_trace_add_cycles(s32 cycles)
{
    cycle_accum += cycles;
}

/*-----------------------------------------------------------------------*/

FASTCALL void sh2_trace_writeb(u32 address, u32 value)
{
#ifdef BINARY_LOG
        struct {
            u16 id;  // 1 = byte store
            u16 pad1;
            u32 address;
            u32 value;
            u32 pad2;
        } buf;
#endif
    if (logfile) {
        value &= 0xFF;
#ifdef BINARY_LOG
        buf.id = 1;
        buf.pad1 = 0;
        buf.address = address;
        buf.value = value;
        buf.pad2 = 0;
        fwrite(&buf, sizeof(buf), 1, logfile);
#else
        fprintf(logfile, "WRITEB %08X <- %02X\n", (int)address, (int)value);
# ifdef ECHO_TO_STDERR
        fprintf(stderr, "WRITEB %08X <- %02X\n", (int)address, (int)value);
# endif
#endif
    }
}

FASTCALL void sh2_trace_writew(u32 address, u32 value)
{
#ifdef BINARY_LOG
        struct {
            u16 id;  // 2 = word store
            u16 pad1;
            u32 address;
            u32 value;
            u32 pad2;
        } buf;
#endif
    if (logfile) {
        value &= 0xFFFF;
#ifdef BINARY_LOG
        buf.id = 2;
        buf.pad1 = 0;
        buf.address = address;
        buf.value = value;
        buf.pad2 = 0;
        fwrite(&buf, sizeof(buf), 1, logfile);
#else
        fprintf(logfile, "WRITEW %08X <- %04X\n", (int)address, (int)value);
# ifdef ECHO_TO_STDERR
        fprintf(stderr, "WRITEW %08X <- %04X\n", (int)address, (int)value);
# endif
#endif
    }
}

FASTCALL void sh2_trace_writel(u32 address, u32 value)
{
    if (logfile) {
#ifdef BINARY_LOG
        struct {
            u16 id;  // 4 = long store
            u16 pad1;
            u32 address;
            u32 value;
            u32 pad2;
        } buf;
        buf.id = 4;
        buf.pad1 = 0;
        buf.address = address;
        buf.value = value;
        buf.pad2 = 0;
        fwrite(&buf, sizeof(buf), 1, logfile);
#else
        fprintf(logfile, "WRITEL %08X <- %08X\n", (int)address, (int)value);
# ifdef ECHO_TO_STDERR
        fprintf(stderr, "WRITEL %08X <- %08X\n", (int)address, (int)value);
# endif
#endif
    }
}

/*-----------------------------------------------------------------------*/

#ifndef BINARY_LOG
static INLINE void HEXIT(char * const ptr, u32 val, int ndigits)
{
    while (ndigits-- > 0) {
        const int digit = val & 0xF;
        val >>= 4;
        ptr[ndigits] = (digit>9 ? digit+7+'0' : digit+'0');
    }
}
#endif

FASTCALL void sh2_trace(SH2_struct *state, u32 address)
{
    current_cycles = cycle_accum + state->cycles;

    if (current_cycles < trace_start) {

        /* Before first instruction: do nothing */

    } else if (current_cycles >= trace_stop) {

        /* After last instruction: close log file if it's open */
        if (logfile) {
#ifdef GZIP_LOG
            pclose(logfile);
#else
            fclose(logfile);
#endif
            logfile = NULL;
        }

    } else {
        u16 opcode;
#ifdef BINARY_LOG
        struct {
            u16 id;  // 1/2/4 = store; 0x80 = MSH2 insn; 0x81 = SSH2 insn
            u16 opcode;
            u32 regs[23];
            u64 cycles;
            u32 pad[2];
        } buf;
#else
        char buf[100];
        /* This looks ugly, but it's faster than fprintf() in this case */
        static char regbuf[] = "  R0: XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX\n  R8: XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX\n  PR: XXXXXXXX  SR: XXX  MAC: XXXXXXXX/XXXXXXXX  GBR: XXXXXXXX  VBR: XXXXXXXX\n";
        int i;
#endif

        if (!logfile) {
            const char *filename = "sh2.log";
#ifdef GZIP_LOG
            char cmdbuf[100];
            snprintf(cmdbuf, sizeof(cmdbuf), "gzip -3 >'%s'.gz", filename);
            logfile = popen(cmdbuf, "w");
#else
            logfile = fopen(filename, "w");
#endif
            if (!logfile) {
                return;
            }
            setvbuf(logfile, NULL, _IOFBF, 65536);
        }

        opcode = MappedMemoryReadWord(address);

#ifdef BINARY_LOG

        buf.id = state==SSH2 ? 0x81 : 0x80;
        buf.opcode = opcode;
        /* sh2int leaves the branch target in regs.PC during a delay slot,
         * so insert the proper PC manually */
        SH2GetRegisters(state, (sh2regs_struct *)buf.regs);
        buf.regs[22] = address;
        buf.cycles = current_cycles;
        buf.pad[0] = 0;
        buf.pad[1] = 0;
        fwrite(&buf, sizeof(buf), 1, logfile);

#else  // !BINARY_LOG

        SH2GetRegisters(state, &state->regs);

        SH2Disasm(address, opcode, 0, buf);
        fprintf(logfile, "[%c] %08X: %04X  %-44s [%12llu]\n",
                state==SSH2 ? 'S' : 'M', (int)address, (int)opcode, buf+12,
                (unsigned long long)current_cycles);
#ifdef ECHO_TO_STDERR
        fprintf(stderr, "[%c] %08X: %04X  %-44s [%12llu]\n",
                state==SSH2 ? 'S' : 'M', (int)address, (int)opcode, buf+12,
                (unsigned long long)current_cycles);
#endif

        for (i = 0; i < 16; i++) {
            HEXIT(i>=8 ? &regbuf[12+i*9] : &regbuf[6+i*9], state->regs.R[i], 8);
        }
        HEXIT(&regbuf[162], state->regs.PR, 8);
        HEXIT(&regbuf[176], state->regs.SR.all, 3);
        HEXIT(&regbuf[186], state->regs.MACH, 8);
        HEXIT(&regbuf[195], state->regs.MACL, 8);
        HEXIT(&regbuf[210], state->regs.GBR, 8);
        HEXIT(&regbuf[225], state->regs.VBR, 8);
        fwrite(regbuf, sizeof(regbuf)-1, 1, logfile);
#ifdef ECHO_TO_STDERR
        fwrite(regbuf, sizeof(regbuf)-1, 1, stderr);
#endif

#endif  // BINARY_LOG

    }  // current_cycles >= trace_start && current_cycles < trace_stop
}

/*************************************************************************/

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
