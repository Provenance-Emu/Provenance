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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "core.h"
#include "sh2core.h"
#include "sh2rec.h"
#include "sh2rec_htab.h"
#include "sh2rec_mem.h"

typedef struct htab_entry {
    sh2rec_block_t block;

    struct htab_entry *next;
} htab_entry_t;

/* The actual hash table. It can't be resized dynamically, and is essentially
   just an array of singly-linked lists. */
static htab_entry_t *table[SH2REC_HTAB_ENTRIES];

/* Internal functions */
static void htab_free_chain(htab_entry_t *ent) {
    htab_entry_t *i, *tmp;

    i = ent;
    while(i) {
        tmp = i->next;
        free(i->block.block);
        free(i);
        i = tmp;
    }
}

/* Hash an address into something slightly nicer to work with. The large
   constant in here is about 2^32 / phi (where phi is the golden ratio). Why use
   the golden ratio? Because its always fun to use in code. */
static inline int hash_addr(u32 addr) {
    return ((addr ^ 2654435761U) >> 2) & (SH2REC_HTAB_ENTRIES - 1);
}

/* Public functions */
void sh2rec_htab_init(void) {
    memset(table, 0, sizeof(htab_entry_t *) * SH2REC_HTAB_ENTRIES);
}

void sh2rec_htab_reset(void) {
    int i;

    for(i = 0; i < SH2REC_HTAB_ENTRIES; ++i) {
        if(table[i]) {
            htab_free_chain(table[i]);
        }
    }

    memset(table, 0, sizeof(htab_entry_t *) * SH2REC_HTAB_ENTRIES);
}

sh2rec_block_t *sh2rec_htab_lookup(u32 addr) {
    htab_entry_t *i = table[hash_addr(addr)];

    /* Look through the chain for the entry we're after */
    while(i) {
        if(i->block.start_pc == addr) {
            return &i->block;
        }

        i = i->next;
    }

    /* Didn't find it, punt. */
    return NULL;
}

/* Create a new block assuming an old one does not exist. */
sh2rec_block_t *sh2rec_htab_block_create(u32 addr, int length) {
    uint8_t *ptr;
    htab_entry_t *ent;
    int index = hash_addr(addr);

    ptr = (uint8_t *)sh2rec_mem_alloc(length + sizeof(htab_entry_t));

#ifdef DEBUG
    if(!ptr) {
        return NULL;
    }
#endif

    /* Allocate space for the block */
    ent = (htab_entry_t *)ptr;
    ent->block.block = (u16 *)(ptr + sizeof(htab_entry_t));

    /* Fill in the struct */
    ent->block.start_pc = addr;
    ent->block.cycles = 0;
    ent->block.pc = addr;
    ent->block.length = length;
    ent->block.ptr = ent->block.block;

    /* Put the item in the list (puts it at the head of the index in the table
       where it would go) */
    ent->next = table[index];
    table[index] = ent;

    return &ent->block;
}

void sh2rec_htab_block_remove(u32 addr) {
    int index = hash_addr(addr);
    htab_entry_t *i, *tmp, *last;

    i = table[index];
    last = NULL;

    /* Look through everything for the entry we're supposed to remove */
    while(i) {
        tmp = i->next;

        /* Is this the entry we're looking for? */
        if(i->block.start_pc == addr) {
            /* Unhook the entry from the list */
            if(last) {
                last->next = tmp;
            }
            else {
                table[index] = tmp;
            }

            /* Free any memory used by the block */
            sh2rec_mem_free(i);

            return;
        }

        last = i;
        i = tmp;
    }
}
