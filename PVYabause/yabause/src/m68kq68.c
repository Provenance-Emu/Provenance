/*  src/m68kpsp.c: Q68 emulator interface
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

#include "yabause.h"
#include "m68kcore.h"

#include "q68/q68.h"

/*************************************************************************/

/**
 * NEED_TRAMPOLINE:  Defined on platforms where we need trampoline
 * functions to convert read/write calls from the native format to the
 * FASTCALL format used by Yabause.
 */
#ifdef CPU_X86
# define NEED_TRAMPOLINE
#endif

/**
 * PROFILE_68K: Perform simple profiling of the 68000 emulation, reporting
 * the average time per 68000 clock cycle.  (Realtime execution would be
 * around 88.5 nsec/cycle.)
 *
 * Note that this profiling has an overhead of two YabauseGetTicks() calls
 * for each M68K->Exec() call; on PSP, this amounts to about 3.8 usec per
 * Exec(), or 52.8 nsec/cycle at 72 cycles/call.
 */
// #define PROFILE_68K

// #define COUNT_OPCODES  // see COUNT_OPCODES in q68-core.c

/*************************************************************************/

/* Interface function declarations (must come before interface definition) */

static int m68kq68_init(void);
static void m68kq68_deinit(void);
static void m68kq68_reset(void);

static FASTCALL s32 m68kq68_exec(s32 cycles);
static void m68kq68_sync(void);

static u32 m68kq68_get_dreg(u32 num);
static u32 m68kq68_get_areg(u32 num);
static u32 m68kq68_get_pc(void);
static u32 m68kq68_get_sr(void);
static u32 m68kq68_get_usp(void);
static u32 m68kq68_get_ssp(void);

static void m68kq68_set_dreg(u32 num, u32 val);
static void m68kq68_set_areg(u32 num, u32 val);
static void m68kq68_set_pc(u32 val);
static void m68kq68_set_sr(u32 val);
static void m68kq68_set_usp(u32 val);
static void m68kq68_set_ssp(u32 val);

static FASTCALL void m68kq68_set_irq(s32 level);
static FASTCALL void m68kq68_write_notify(u32 address, u32 size);

static void m68kq68_set_fetch(u32 low_addr, u32 high_addr, pointer fetch_addr);
static void m68kq68_set_readb(M68K_READ *func);
static void m68kq68_set_readw(M68K_READ *func);
static void m68kq68_set_writeb(M68K_WRITE *func);
static void m68kq68_set_writew(M68K_WRITE *func);

static uint32_t dummy_read(uint32_t address);
static void dummy_write(uint32_t address, uint32_t data);

#ifdef NEED_TRAMPOLINE
static uint32_t readb_trampoline(uint32_t address);
static uint32_t readw_trampoline(uint32_t address);
static void writeb_trampoline(uint32_t address, uint32_t data);
static void writew_trampoline(uint32_t address, uint32_t data);
#endif

/*-----------------------------------------------------------------------*/

/* Module interface definition */

M68K_struct M68KQ68 = {
    .id          = M68KCORE_Q68,
    .Name        = "Q68 68k Emulator Interface",

    .Init        = m68kq68_init,
    .DeInit      = m68kq68_deinit,
    .Reset       = m68kq68_reset,

    .Exec        = m68kq68_exec,
    .Sync        = m68kq68_sync,

    .GetDReg     = m68kq68_get_dreg,
    .GetAReg     = m68kq68_get_areg,
    .GetPC       = m68kq68_get_pc,
    .GetSR       = m68kq68_get_sr,
    .GetUSP      = m68kq68_get_usp,
    .GetMSP      = m68kq68_get_ssp,

    .SetDReg     = m68kq68_set_dreg,
    .SetAReg     = m68kq68_set_areg,
    .SetPC       = m68kq68_set_pc,
    .SetSR       = m68kq68_set_sr,
    .SetUSP      = m68kq68_set_usp,
    .SetMSP      = m68kq68_set_ssp,

    .SetIRQ      = m68kq68_set_irq,
    .WriteNotify = m68kq68_write_notify,

    .SetFetch    = m68kq68_set_fetch,
    .SetReadB    = m68kq68_set_readb,
    .SetReadW    = m68kq68_set_readw,
    .SetWriteB   = m68kq68_set_writeb,
    .SetWriteW   = m68kq68_set_writew,
};

/*-----------------------------------------------------------------------*/

/* Virtual processor state block */

static Q68State *state;


#ifdef NEED_TRAMPOLINE

/* Read/write functions passed to Set{Read,Write}[BW], called via the
 * trampolines */
static M68K_READ *real_readb, *real_readw;
static M68K_WRITE *real_writeb, *real_writew;

#endif

/*************************************************************************/
/************************** Interface functions **************************/
/*************************************************************************/

/**
 * m68kq68_init:  Initialize the virtual processpr.
 *
 * [Parameters]
 *     None
 * [Return value]
 *     Zero on success, negative on failure
 */
static int m68kq68_init(void)
{
    if (!(state = q68_create())) {
        return -1;
    }
    q68_set_irq(state, 0);
    q68_set_readb_func(state, dummy_read);
    q68_set_readw_func(state, dummy_read);
    q68_set_writeb_func(state, dummy_write);
    q68_set_writew_func(state, dummy_write);

    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * m68kq68_deinit:  Destroy the virtual processor.
 *
 * [Parameters]
 *     None
 * [Return value]
 *     None
 */
static void m68kq68_deinit(void)
{
    q68_destroy(state);
    state = NULL;
}

/*-----------------------------------------------------------------------*/

/**
 * m68kq68_reset:  Reset the virtual processor.
 *
 * [Parameters]
 *     None
 * [Return value]
 *     None
 */
static void m68kq68_reset(void)
{
    q68_reset(state);
}

/*************************************************************************/

/**
 * m68kq68_exec:  Execute instructions for the given number of clock cycles.
 *
 * [Parameters]
 *     cycles: Number of clock cycles to execute
 * [Return value]
 *     Number of clock cycles actually executed
 */
static FASTCALL s32 m68kq68_exec(s32 cycles)
{
#ifdef PROFILE_68K
    static uint32_t tot_cycles = 0, tot_usec = 0, tot_ticks = 0;
    static uint32_t last_report = 0;
    uint32_t start, end;
    start = (uint32_t) YabauseGetTicks();
    int retval = q68_run(state, cycles);
    end = (uint32_t) YabauseGetTicks();
    tot_cycles += cycles;
    tot_ticks += end - start;
    if (tot_cycles/1000000 > last_report) {
        tot_usec += (uint64_t)tot_ticks * 1000000 / yabsys.tickfreq;
        tot_ticks = 0;
        fprintf(stderr, "%ld cycles in %.3f sec = %.3f nsec/cycle\n",
                (long)tot_cycles, (double)tot_usec/1000000,
                ((double)tot_usec / (double)tot_cycles) * 1000);
        last_report = tot_cycles/1000000;
# ifdef COUNT_OPCODES
        if (last_report % 100 == 0) {
            extern uint32_t q68_ops[128], q68_4xxx_ops[32];
            int i;
            fprintf(stderr, "Opcodes per 1M cycles:\n");
            for (i = 0; i < 128; i++) {
                fprintf(stderr, "%s%8ld%s", i%8==0 ? "    " : "",
                        (long)((q68_ops[i] + last_report/2) / last_report),
                        i%8==7 ? "\n" : "");
            }
            fprintf(stderr, "$4xxx opcodes per 1M cycles:\n");
            for (i = 0; i < 32; i++) {
                fprintf(stderr, "%s%8ld%s", i%8==0 ? "    " : "",
                        (long)((q68_4xxx_ops[i] + last_report/2) / last_report),
                        i%8==7 ? "\n" : "");
            }
        }
# endif  // COUNT_OPCODES
    }
    return retval;
#else  // !PROFILE_68K
    return q68_run(state, cycles);
#endif
}

/*-----------------------------------------------------------------------*/

/**
 * m68kq68_sync:  Wait for background execution to finish.
 *
 * [Parameters]
 *     None
 * [Return value]
 *     None
 */
static void m68kq68_sync(void)
{
    /* Nothing to do */
}

/*************************************************************************/

/**
 * m68kq68_get_{dreg,areg,pc,sr,usp,ssp}:  Return the current value of
 * the specified register.
 *
 * [Parameters]
 *     num: Register number (m68kq68_get_dreg(), m68kq68_get_areg() only)
 * [Return value]
 *     None
 */

static u32 m68kq68_get_dreg(u32 num)
{
    return q68_get_dreg(state, num);
}

static u32 m68kq68_get_areg(u32 num)
{
    return q68_get_areg(state, num);
}

static u32 m68kq68_get_pc(void)
{
    return q68_get_pc(state);
}

static u32 m68kq68_get_sr(void)
{
    return q68_get_sr(state);
}

static u32 m68kq68_get_usp(void)
{
    return q68_get_usp(state);
}

static u32 m68kq68_get_ssp(void)
{
    return q68_get_ssp(state);
}

/*-----------------------------------------------------------------------*/

/**
 * m68kq68_set_{dreg,areg,pc,sr,usp,ssp}:  Set the value of the specified
 * register.
 *
 * [Parameters]
 *     num: Register number (m68kq68_set_dreg(), m68kq68_set_areg() only)
 *     val: Value to set
 * [Return value]
 *     None
 */

static void m68kq68_set_dreg(u32 num, u32 val)
{
    q68_set_dreg(state, num, val);
}

static void m68kq68_set_areg(u32 num, u32 val)
{
    q68_set_areg(state, num, val);
}

static void m68kq68_set_pc(u32 val)
{
    q68_set_pc(state, val);
}

static void m68kq68_set_sr(u32 val)
{
    q68_set_sr(state, val);
}

static void m68kq68_set_usp(u32 val)
{
    q68_set_usp(state, val);
}

static void m68kq68_set_ssp(u32 val)
{
    q68_set_ssp(state, val);
}

/*************************************************************************/

/**
 * m68kq68_set_irq:  Deliver an interrupt to the processor.
 *
 * [Parameters]
 *     level: Interrupt level (0-7)
 * [Return value]
 *     None
 */
static FASTCALL void m68kq68_set_irq(s32 level)
{
    q68_set_irq(state, level);
}

/*-----------------------------------------------------------------------*/

/**
 * m68kq68_write_notify:  Inform the 68k emulator that the given address
 * range has been modified.
 *
 * [Parameters]
 *     address: 68000 address of modified data
 *        size: Size of modified data in bytes
 * [Return value]
 *     None
 */
static FASTCALL void m68kq68_write_notify(u32 address, u32 size)
{
    q68_touch_memory(state, address, size);
}

/*************************************************************************/

/**
 * m68kq68_set_fetch:  Set the instruction fetch pointer for a region of
 * memory.  Not used by Q68.
 *
 * [Parameters]
 *       low_addr: Low address of memory region to set
 *      high_addr: High address of memory region to set
 *     fetch_addr: Pointer to corresponding memory region (NULL to disable)
 * [Return value]
 *     None
 */
static void m68kq68_set_fetch(u32 low_addr, u32 high_addr, pointer fetch_addr)
{
}

/*-----------------------------------------------------------------------*/

/**
 * m68kq68_set_{readb,readw,writeb,writew}:  Set functions for reading or
 * writing bytes or words in memory.
 *
 * [Parameters]
 *     func: Function to set
 * [Return value]
 *     None
 */

static void m68kq68_set_readb(M68K_READ *func)
{
#ifdef NEED_TRAMPOLINE
    real_readb = func;
    q68_set_readb_func(state, readb_trampoline);
#else
    q68_set_readb_func(state, (Q68ReadFunc *)func);
#endif
}

static void m68kq68_set_readw(M68K_READ *func)
{
#ifdef NEED_TRAMPOLINE
    real_readw = func;
    q68_set_readw_func(state, readw_trampoline);
#else
    q68_set_readw_func(state, (Q68ReadFunc *)func);
#endif
}

static void m68kq68_set_writeb(M68K_WRITE *func)
{
#ifdef NEED_TRAMPOLINE
    real_writeb = func;
    q68_set_writeb_func(state, writeb_trampoline);
#else
    q68_set_writeb_func(state, (Q68WriteFunc *)func);
#endif
}

static void m68kq68_set_writew(M68K_WRITE *func)
{
#ifdef NEED_TRAMPOLINE
    real_writew = func;
    q68_set_writew_func(state, writew_trampoline);
#else
    q68_set_writew_func(state, (Q68WriteFunc *)func);
#endif
}

/*************************************************************************/

/**
 * dummy_read:  Default read function, always returning 0 for any address.
 *
 * [Parameters]
 *     address: Address to read from
 * [Return value]
 *     Value read (always zero)
 */
static uint32_t dummy_read(uint32_t address)
{
    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * dummy_write:  Default write function, ignoring all writes.
 *
 * [Parameters]
 *     address: Address to write to
 *        data: Value to write
 * [Return value]
 *     None
 */
static void dummy_write(uint32_t address, uint32_t data)
{
}

/*-----------------------------------------------------------------------*/

#ifdef NEED_TRAMPOLINE

/**
 * read[bw]_trampoline, write[bw]_trampoline:  Adjust calling conventions
 * between the M68k emulator and Yabause's M68k core.
 *
 * [Parameters]
 *     address: Address to read from
 *        data: Value to write (only for write_trampoline)
 * [Return value]
 *     Value read (only for read_trampoline)
 */

static uint32_t readb_trampoline(uint32_t address) {
    return (*real_readb)(address);
}

static uint32_t readw_trampoline(uint32_t address) {
    return (*real_readw)(address);
}

static void writeb_trampoline(uint32_t address, uint32_t data) {
    return (*real_writeb)(address, data);
}

static void writew_trampoline(uint32_t address, uint32_t data) {
    return (*real_writew)(address, data);
}

#endif  // NEED_TRAMPOLINE

/*************************************************************************/
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
