/*  src/q68/q68.c: Quick-and-dirty MC68000 emulator with dynamic
                   translation support
    Copyright 2009-2010 Andrew Church

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

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "q68.h"
#include "q68-internal.h"

/*************************************************************************/

/*
 * The source code for Q68 is divided into the following files:
 *
 * q68.c (this file) -- Main interface function definitions
 * q68.h -------------- Interface definition (users should include this header)
 * q68-const.h -------- 68000-related constants (status register bits, etc.)
 * q68-core.c --------- Processor execution core
 * q68-disasm.c ------- 68000 instruction disassembly and tracing support
 *                         (for debugging)
 * q68-internal.h ----- General definitions and declarations for internal use
 * q68-jit.c ---------- Dynamic ("just-in-time") translation support
 * q68-jit.h ---------- Declarations used only by the JIT code
 * q68-jit-psp.[hS] --- JIT implementation for the PSP's Allegrex processor
 * q68-jit-x86.[hS] --- JIT implementation for the Intel x86 architecture
 *                         (both 32-bit and 64-bit environments supported)
 */

/*************************************************************************/
/*************************************************************************/

/**
 * q68_create:  Create a new virtual processor.  The virtual processor is
 * created uninitialized; before starting the processor, the caller must
 * set the IRQ level and read/write callbacks, then call q68_reset().
 *
 * [Parameters]
 *     None
 * [Return value]
 *     Processor state block on success, NULL on error
 */
Q68State *q68_create(void)
{
    return q68_create_ex(malloc, realloc, free);
}

/*-----------------------------------------------------------------------*/

/**
 * q68_create_ex:  Create a new virtual processor, using the specified
 * functions for all memory allocation.
 *
 * [Parameters]
 *      malloc_func: Function for allocating a memory block
 *     realloc_func: Function for adjusting the size of a memory block
 *        free_func: Function for freeing a memory block
 * [Return value]
 *     Processor state block on success, NULL on error
 */
Q68State *q68_create_ex(void *(*malloc_func)(size_t size),
                        void *(*realloc_func)(void *ptr, size_t size),
                        void (*free_func)(void *ptr))
{
    Q68State *state;

    state = (*malloc_func)(sizeof(*state));
    if (!state) {
        return NULL;
    }
    state->malloc_func  = malloc_func;
    state->realloc_func = realloc_func;
    state->free_func    = free_func;

#ifdef Q68_USE_JIT
    if (!q68_jit_init(state)) {
        state->free_func(state);
        return NULL;
    }
#endif

    state->halted = Q68_HALTED_DOUBLE_FAULT; // Let's initialize this, at least
    return state;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_destroy:  Free all resources used by a virtual processor.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
void q68_destroy(Q68State *state)
{
#ifdef Q68_USE_JIT
    q68_jit_cleanup(state);
#endif
    state->free_func(state);
}

/*************************************************************************/

/**
 * q68_set_irq:  Set the interrupt request (IRQ) input to the processor.
 *
 * [Parameters]
 *     state: Processor state block
 *       irq: IRQ level (0-7)
 * [Return value]
 *     None
 */
void q68_set_irq(Q68State *state, int irq)
{
    state->irq = irq & 7;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_set_{readb,readw,writeb,writew}_func:  Set the read/write callback
 * functions called by the virtual processor on memory accesses.
 *
 * For the read functions, only the lower 8 (readb) or 16 (readw) bits of
 * the return value are used; the function does not need to sign-extend or
 * zero-extend the value.  Similarly, the value passed to the write
 * functions will only have the low 8 (writeb) or 16 (writew) bits valid,
 * and the function should ignore the upper bits of the value.
 *
 * For the word access functions (readw and writew), the address is
 * guaranteed to be even, so the function does not need to check for this
 * itself.  (However, see the Q68_DISABLE_ADDRESS_ERROR configuration
 * option in q68-internal.h.)
 *
 * [Parameters]
 *     state: Processor state block
 *      func: Callback function to set
 * [Return value]
 *     None
 */
void q68_set_readb_func(Q68State *state, Q68ReadFunc func)
{
    state->readb_func = func;
}

void q68_set_readw_func(Q68State *state, Q68ReadFunc func)
{
    state->readw_func = func;
}

void q68_set_writeb_func(Q68State *state, Q68WriteFunc func)
{
    state->writeb_func = func;
}

void q68_set_writew_func(Q68State *state, Q68WriteFunc func)
{
    state->writew_func = func;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_set_jit_flush_func:  Set a function to be used to flush the native
 * CPU's caches after a block of 68k code has been translated into native
 * code.  If not set, no cache flushing is performed.  This function has no
 * effect if dynamic translation is not enabled.
 *
 * [Parameters]
 *          state: Processor state block
 *     flush_func: Function for flushing the native CPU's caches (NULL if none)
 * [Return value]
 *     None
 */
void q68_set_jit_flush_func(Q68State *state, void (*flush_func)(void))
{
    state->jit_flush   = flush_func;
}

/*************************************************************************/

/**
 * q68_get_{dreg,areg,pc,sr,usp,ssp}:  Return the current value of the
 * specified register.
 *
 * [Parameters]
 *     state: Processor state block
 *       num: Register number (q68_get_dreg() and q68_get_areg() only)
 * [Return value]
 *     Register value
 */
uint32_t q68_get_dreg(const Q68State *state, int num)
{
    return state->D[num];
}

uint32_t q68_get_areg(const Q68State *state, int num)
{
    return state->A[num];
}

uint32_t q68_get_pc(const Q68State *state)
{
    return state->PC;
}

uint16_t q68_get_sr(const Q68State *state)
{
    return state->SR;
}

uint32_t q68_get_usp(const Q68State *state)
{
    return state->USP;
}

uint32_t q68_get_ssp(const Q68State *state)
{
    return state->SSP;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_set_{dreg,areg,pc,sr,usp,ssp}:  Set the value of the specified
 * register.
 *
 * [Parameters]
 *     state: Processor state block
 *       num: Register number (q68_set_dreg() and q68_set_areg() only)
 *     value: Value to set
 * [Return value]
 *     None
 */
void q68_set_dreg(Q68State *state, int num, uint32_t value)
{
    state->D[num] = value;
}

void q68_set_areg(Q68State *state, int num, uint32_t value)
{
    state->A[num] = value;
}

void q68_set_pc(Q68State *state, uint32_t value)
{
    state->PC = value;
}

void q68_set_sr(Q68State *state, uint16_t value)
{
    state->SR = value;
}

void q68_set_usp(Q68State *state, uint32_t value)
{
    state->USP = value;
}

void q68_set_ssp(Q68State *state, uint32_t value)
{
    state->SSP = value;
}

/*************************************************************************/

/**
 * q68_touch_memory:  Clear any cached translations covering the given
 * address range.  Users should call this function whenever 68000-accessible
 * memory is modified by an external agent.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: 68000 address of modified data
 *        size: Size of modified data (in bytes)
 * [Return value]
 *     None
 */
void q68_touch_memory(Q68State *state, uint32_t address, uint32_t size)
{
#ifdef Q68_USE_JIT
    const uint32_t first_page = address >> Q68_JIT_PAGE_BITS;
    const uint32_t last_page = (address + (size-1)) >> Q68_JIT_PAGE_BITS;
    uint32_t page;
    for (page = first_page; page <= last_page; page++) {
        if (UNLIKELY(JIT_PAGE_TEST(state, page))) {
            q68_jit_clear_page(state, page << Q68_JIT_PAGE_BITS);
        }
    }
#endif
}

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
