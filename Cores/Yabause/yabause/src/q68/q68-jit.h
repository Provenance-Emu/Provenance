/*  src/q68/q68-jit.h: Dynamic translation header for Q68
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

#ifndef Q68_JIT_H
#define Q68_JIT_H

/*************************************************************************/

/* Info structure for translated code blocks */
struct Q68JitEntry_ {
    Q68JitEntry *next, *prev; // Hash table collision chain pointers
    Q68State *state;          // Associated processor state block
    uint32_t m68k_start;      // Code start address in 68000 address space
                              //    (zero indicates a free entry)
    uint32_t m68k_end;        // Code end address in 68000 address space
    OpcodeFunc *native_code;  // Pointer to native code
    uint32_t native_length;   // Length of native code (bytes)
    uint32_t native_size;     // Size of native code buffer (bytes)
    void *exec_address;       // Next execution address (NULL if not started)
    uint32_t timestamp;       // Time this entry was added
    uint8_t running;          // Nonzero if entry is currently running
    uint8_t must_clear;       // Nonzero if entry must be cleared on completion
};

/* Hash function */
#define JIT_HASH(addr)  ((uint32_t)(addr) % Q68_JIT_TABLE_SIZE)

/*************************************************************************/

/**
 * TIMESTAMP_COMPARE:  Compare two timestamps.
 *
 * [Parameters]
 *          a, b: Timestamps to compare
 *     reference: Reference timestamp by which the comparison is made
 * [Return value]
 *     -1 if a < b (i.e. "a is older than b")
 *      0 if a == b
 *      1 if a > b
 */
#ifdef __GNUC__
__attribute__((const))
#endif
static inline int TIMESTAMP_COMPARE(uint32_t reference, uint32_t a, uint32_t b)
{
    const uint32_t age_a = reference - a;
    const uint32_t age_b = reference - b;
    return age_a > age_b ? -1 :
           age_a < age_b ?  1 : 0;
}

/*************************************************************************/

#endif  // Q68_JIT_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
