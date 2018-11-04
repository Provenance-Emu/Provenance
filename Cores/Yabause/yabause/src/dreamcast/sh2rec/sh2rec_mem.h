/*  Copyright 2010 Lawrence Sebald

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
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/

#ifndef SH2REC_MEM_H
#define SH2REC_MEM_H

/* Initial allocation of memory: 1MB */
#define SH2REC_MEM_INITIAL  (1024 * 1024)

/* Size of future allocations: 256KB */
#define SH2REC_MEM_ALLOCSZ  (256 * 1024)

/* Maximum allocation of memory: 2MB */
#define SH2REC_MEM_MAX      (2 * 1024 * 1024)

/* Fudge factor... make sure at least this much is in any block above the
   inital request */
#define SH2REC_MEM_FUDGE    48

int sh2rec_mem_init(void);
void sh2rec_mem_shutdown(void);

void *sh2rec_mem_alloc(int sz);
int sh2rec_mem_expand(void *block, int amt);
void sh2rec_mem_free(void *block);

#endif /* !SH2REC_MEM_H */
