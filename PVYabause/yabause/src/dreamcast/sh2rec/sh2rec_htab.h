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

#ifndef SH2REC_HTAB_H
#define SH2REC_HTAB_H

/* This MUST be set to a power of two. It is done this way to avoid using a mod
   operation to get the entry where the object will go, since division (and thus
   modulus) is quite expensive on SuperH. */
#define SH2REC_HTAB_ENTRIES 4096

void sh2rec_htab_init(void);
void sh2rec_htab_reset(void);

sh2rec_block_t *sh2rec_htab_lookup(u32 addr);
sh2rec_block_t *sh2rec_htab_block_create(u32 addr, int length);
void sh2rec_htab_block_remove(u32 addr);

#endif /* !SH2REC_HTAB_H */
