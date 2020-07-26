/*  src/q68/q68.h: Q68 main header
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

#ifndef Q68_H
#define Q68_H

#include <stdint.h>
#include <stdio.h>

/*************************************************************************/
/****************** Exported definitions and data types ******************/
/*************************************************************************/

/* Memory read/write function types.  The size of the operation is not
 * specified here, but is rather determined by which callback the function
 * is assigned to. */

/**
 * Q68ReadFunc:  Read data from memory.
 *
 * [Parameters]
 *     address: Address to read from
 * [Return value]
 *     Value read (zero-extended to 32 bits)
 */
typedef uint32_t Q68ReadFunc(uint32_t address);

/**
 * Q68WriteFunc:  Write data to memory.
 *
 * [Parameters]
 *     address: Address to write to
 *        data: Value to write
 * [Return value]
 *     None
 */
typedef void Q68WriteFunc(uint32_t address, uint32_t data);

/*************************************************************************/

/* Virtual processor state (opaque) */

typedef struct Q68State_ Q68State;

/*************************************************************************/
/************************** Emulator interface ***************************/
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
extern Q68State *q68_create(void);

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
extern Q68State *q68_create_ex(void *(*malloc_func)(size_t size),
                               void *(*realloc_func)(void *ptr, size_t size),
                               void (*free_func)(void *ptr));

/**
 * q68_destroy:  Free all resources used by a virtual processor.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
extern void q68_destroy(Q68State *state);

/*----------------------------------*/

/**
 * q68_set_irq:  Set the interrupt request (IRQ) input to the processor.
 *
 * [Parameters]
 *     state: Processor state block
 *       irq: IRQ level (0-7)
 * [Return value]
 *     None
 */
extern void q68_set_irq(Q68State *state, int irq);

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
extern void q68_set_readb_func(Q68State *state, Q68ReadFunc func);
extern void q68_set_readw_func(Q68State *state, Q68ReadFunc func);
extern void q68_set_writeb_func(Q68State *state, Q68WriteFunc func);
extern void q68_set_writew_func(Q68State *state, Q68WriteFunc func);

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
extern void q68_set_jit_flush_func(Q68State *state, void (*flush_func)(void));

/*----------------------------------*/

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
extern uint32_t q68_get_dreg(const Q68State *state, int num);
extern uint32_t q68_get_areg(const Q68State *state, int num);
extern uint32_t q68_get_pc(const Q68State *state);
extern uint16_t q68_get_sr(const Q68State *state);
extern uint32_t q68_get_usp(const Q68State *state);
extern uint32_t q68_get_ssp(const Q68State *state);

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
extern void q68_set_dreg(Q68State *state, int num, uint32_t value);
extern void q68_set_areg(Q68State *state, int num, uint32_t value);
extern void q68_set_pc(Q68State *state, uint32_t value);
extern void q68_set_sr(Q68State *state, uint16_t value);
extern void q68_set_usp(Q68State *state, uint32_t value);
extern void q68_set_ssp(Q68State *state, uint32_t value);

/*----------------------------------*/

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
extern void q68_touch_memory(Q68State *state, uint32_t address, uint32_t size);

/*-----------------------------------------------------------------------*/

/**
 * q68_reset:  Reset the virtual processor.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
extern void q68_reset(Q68State *state);

/**
 * q68_run:  Execute instructions for the given number of clock cycles.
 *
 * [Parameters]
 *      state: Processor state block
 *     cycles: Number of clock cycles to execute
 * [Return value]
 *     Number of clock cycles executed (may be greater than "cycles")
 */
extern int q68_run(Q68State *state, int cycles);

/*-----------------------------------------------------------------------*/

/**
 * q68_disassemble:  Disassemble the instruction at the given address.
 * Returns "???" if the address or opcode is invalid.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Address of instruction to disassemble
 * [Return value]
 *     String containined disassembled instruction
 * [Notes]
 *     The returned string is only valid until the next call to this function.
 */
extern const char *q68_disassemble(Q68State *state, uint32_t address,
                                   int *nwords_ret);

/*----------------------------------*/

/**
 * q68_trace_init:  Initialize the tracing code.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
extern void q68_trace_init(Q68State *state_);

/**
 * q68_trace_add_cycles:  Add the given number of cycles to the global
 * accumulator.
 *
 * [Parameters]
 *     cycles: Number of cycles to add
 * [Return value]
 *     None
 */
extern void q68_trace_add_cycles(int32_t cycles);

/**
 * q68_trace:  Output a trace for the instruction at the current PC.
 *
 * [Parameters]
 *     None
 * [Return value]
 *     None
 */
extern void q68_trace(void);

/*************************************************************************/
/*************************************************************************/

#endif  // Q68_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
