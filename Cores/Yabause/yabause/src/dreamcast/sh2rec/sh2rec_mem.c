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
#include <inttypes.h>

#include "sh2rec_mem.h"

typedef struct block_s {
    uint8_t *ptr;
    int size;
    struct block_s *prev;
    struct block_s *next;
} sh2rec_mem_block;

typedef struct usedblock_s {
    sh2rec_mem_block base;
    sh2rec_mem_block *freespace;
} sh2rec_mem_usedblock;

typedef struct allocblock_s {
    struct allocblock_s *next;
} sh2rec_mem_allocblock;

static sh2rec_mem_block *freeblocks = NULL;
static sh2rec_mem_usedblock *usedblocks = NULL;
static sh2rec_mem_usedblock *usedblocks_tail = NULL;
static sh2rec_mem_allocblock *allocblocks = NULL;

static int cur_allocation = 0;

#define BSSIZE (sizeof(sh2rec_mem_allocblock) + sizeof(sh2rec_mem_block) + \
                sizeof(sh2rec_mem_usedblock))

int sh2rec_mem_init(void) {
    sh2rec_mem_block *initblock;
    sh2rec_mem_allocblock *allocblock;
    uint8_t *block;

    /* Allocate our initial space for storing rec'd instructions in */
    block = (uint8_t *)malloc(SH2REC_MEM_INITIAL);

#ifdef DEBUG
    if(!block) {
        return -1;
    }
#endif

    /* Carve our structures out of the beginning of the block */
    allocblock = (sh2rec_mem_allocblock *)block;
    initblock = (sh2rec_mem_block *)(block + sizeof(sh2rec_mem_allocblock));
    cur_allocation = SH2REC_MEM_INITIAL;

    /* Fill in the rest of the structs */
    initblock->size = SH2REC_MEM_INITIAL - sizeof(sh2rec_mem_allocblock) -
        sizeof(sh2rec_mem_block);
    initblock->prev = NULL;
    initblock->next = NULL;

    allocblock->next = NULL;
    allocblocks = allocblock;

    /* The whole block is free, so put it in the free list */
    freeblocks = initblock;

    return 0;
}

void sh2rec_mem_shutdown(void) {
    sh2rec_mem_allocblock *i, *tmp;

    /* Loop through and free any blocks we allocated */
    i = allocblocks;
    while(i) {
        tmp = i->next;
        free(i);
        i = tmp;
    }

    /* Clean up the stale pointers */
    allocblocks = NULL;
    freeblocks = NULL;
    usedblocks = NULL;
}

void *sh2rec_mem_alloc(int sz) {
    sh2rec_mem_block *i;
    sh2rec_mem_usedblock *rv;
    sh2rec_mem_allocblock *b;
    int szlook = sz + SH2REC_MEM_FUDGE + sizeof(sh2rec_mem_usedblock);
    uint8_t *block;

    /* Look for a free block of enough size */
    i = freeblocks;
    while(i) {
        if(i->size >= szlook) {
            /* We've found a candidate, so, start working with it */
            rv = (sh2rec_mem_usedblock *)i->ptr;
            rv->freespace = i;
            rv->base.ptr = i->ptr + sizeof(sh2rec_mem_usedblock);
            rv->base.size = sz;
            rv->base.prev = (sh2rec_mem_block *)usedblocks_tail;
            rv->base.next = NULL;

            /* Update the tail */
            if(usedblocks_tail) {
                usedblocks_tail->base.next = (sh2rec_mem_block *)rv;
            }

            usedblocks_tail = rv;

            /* The freeblock is now smaller, so reflect that */
            i->size -= sz + sizeof(sh2rec_mem_usedblock);

            return rv;
        }

        i = i->next;
    }

    /* We didn't find one, so allocate a new block */
    block = malloc(SH2REC_MEM_ALLOCSZ);

#ifdef DEBUG
    if(!block) {
        return NULL;
    }
#endif

    /* Fill in the allocblock */
    b = (sh2rec_mem_allocblock *)block;
    b->next = allocblocks;
    allocblocks = b;

    /* Now, create a freeblock, and work from that */
    i = (sh2rec_mem_block *)(block + sizeof(sh2rec_mem_allocblock));
    i->ptr = block + BSSIZE + sz;
    i->prev = NULL;
    i->next = freeblocks;
    i->size = SH2REC_MEM_ALLOCSZ - BSSIZE - sz;
    freeblocks = i;

    /* Create the usedblock */
    rv = (sh2rec_mem_usedblock *)(i->ptr - sz);
    rv->freespace = i;
    rv->base.ptr = i->ptr;
    rv->base.size = sz;
    rv->base.prev = (sh2rec_mem_block *)usedblocks_tail;
    rv->base.next = NULL;

    /* Update the tail */
    if(usedblocks_tail) {
        usedblocks_tail->base.next = (sh2rec_mem_block *)rv;
    }

    usedblocks_tail = rv;

    /* Keep track of our allocation */
    cur_allocation += SH2REC_MEM_ALLOCSZ;

    return rv;
}

int sh2rec_mem_expand(void *block, int amt) {
    sh2rec_mem_usedblock *b = (sh2rec_mem_usedblock *)block;

    /* If the freeblock has space, allow it */
    if(b->freespace->size > amt) {
        b->freespace->size -= amt;
        b->base.size += amt;
        b->freespace->ptr += amt;
        return 1;
    }

    return 0;
}

void sh2rec_mem_free(void *block) {
    sh2rec_mem_usedblock *b = (sh2rec_mem_usedblock *)block;

    /* Remove the usedblock from the chain */
    if(b->base.next) {
        b->base.next->prev = b->base.prev;
    }

    if(b->base.prev) {
        b->base.prev->next = b->base.next;
    }

    if(b == usedblocks) {
        usedblocks = (sh2rec_mem_usedblock *)b->base.next;
    }

    if(b == usedblocks_tail) {
        usedblocks_tail = (sh2rec_mem_usedblock *)b->base.prev;
    }

    /* Treat the usedblock like its a freeblock (it is an extension of the
       freeblock), and just link it into the free blocks list */
    b->freespace = NULL;
    b->base.next = freeblocks;
    b->base.prev = NULL;
    b->base.size += sizeof(sh2rec_mem_usedblock) - sizeof(sh2rec_mem_block);
    freeblocks = (sh2rec_mem_block *)b;
}
