/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - new_dynarec.h                                           *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2002 Hacktarux                                          *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef M64P_R4300_NEW_DYNAREC_H
#define M64P_R4300_NEW_DYNAREC_H

#include <stddef.h>
#include <stdint.h>

#define NEW_DYNAREC_X86 1
#define NEW_DYNAREC_AMD64 2
#define NEW_DYNAREC_ARM 3

#ifdef __cplusplus
extern "C" {
#endif
extern int pcaddr;
extern int pending_exception;
#ifdef __cplusplus
}
#endif

void invalidate_all_pages(void);
void invalidate_block(unsigned int block);
void invalidate_cached_code_new_dynarec(uint32_t address, size_t size);
void new_dynarec_init(void);
void new_dyna_start(void);
void new_dynarec_cleanup(void);

#endif /* M64P_R4300_NEW_DYNAREC_H */
