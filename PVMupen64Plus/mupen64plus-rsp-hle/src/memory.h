/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - memory.h                                        *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
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

#ifndef MEMORY_H
#define MEMORY_H

#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#include "common.h"
#include "hle_internal.h"

#ifdef M64P_BIG_ENDIAN
#define S 0
#define S16 0
#define S8 0
#else
#define S 1
#define S16 2
#define S8 3
#endif

enum {
    TASK_TYPE               = 0xfc0,
    TASK_FLAGS              = 0xfc4,
    TASK_UCODE_BOOT         = 0xfc8,
    TASK_UCODE_BOOT_SIZE    = 0xfcc,
    TASK_UCODE              = 0xfd0,
    TASK_UCODE_SIZE         = 0xfd4,
    TASK_UCODE_DATA         = 0xfd8,
    TASK_UCODE_DATA_SIZE    = 0xfdc,
    TASK_DRAM_STACK         = 0xfe0,
    TASK_DRAM_STACK_SIZE    = 0xfe4,
    TASK_OUTPUT_BUFF        = 0xfe8,
    TASK_OUTPUT_BUFF_SIZE   = 0xfec,
    TASK_DATA_PTR           = 0xff0,
    TASK_DATA_SIZE          = 0xff4,
    TASK_YIELD_DATA_PTR     = 0xff8,
    TASK_YIELD_DATA_SIZE    = 0xffc
};

static inline unsigned int align(unsigned int x, unsigned amount)
{
    --amount;
    return (x + amount) & ~amount;
}

static inline uint8_t* u8(const unsigned char* buffer, unsigned address)
{
    return (uint8_t*)(buffer + (address ^ S8));
}

static inline uint16_t* u16(const unsigned char* buffer, unsigned address)
{
    assert((address & 1) == 0);
    return (uint16_t*)(buffer + (address ^ S16));
}

static inline uint32_t* u32(const unsigned char* buffer, unsigned address)
{
    assert((address & 3) == 0);
    return (uint32_t*)(buffer + address);
}

void load_u8 (uint8_t*  dst, const unsigned char* buffer, unsigned address, size_t count);
void load_u16(uint16_t* dst, const unsigned char* buffer, unsigned address, size_t count);
void load_u32(uint32_t* dst, const unsigned char* buffer, unsigned address, size_t count);
void store_u8 (unsigned char* buffer, unsigned address, const uint8_t*  src, size_t count);
void store_u16(unsigned char* buffer, unsigned address, const uint16_t* src, size_t count);
void store_u32(unsigned char* buffer, unsigned address, const uint32_t* src, size_t count);


/* convenient functions for DMEM access */
static inline uint8_t* dmem_u8(struct hle_t* hle, uint16_t address)
{
    return u8(hle->dmem, address & 0xfff);
}

static inline uint16_t* dmem_u16(struct hle_t* hle, uint16_t address)
{
    return u16(hle->dmem, address & 0xfff);
}

static inline uint32_t* dmem_u32(struct hle_t* hle, uint16_t address)
{
    return u32(hle->dmem, address & 0xfff);
}

static inline void dmem_load_u8(struct hle_t* hle, uint8_t* dst, uint16_t address, size_t count)
{
    load_u8(dst, hle->dmem, address & 0xfff, count);
}

static inline void dmem_load_u16(struct hle_t* hle, uint16_t* dst, uint16_t address, size_t count)
{
    load_u16(dst, hle->dmem, address & 0xfff, count);
}

static inline void dmem_load_u32(struct hle_t* hle, uint32_t* dst, uint16_t address, size_t count)
{
    load_u32(dst, hle->dmem, address & 0xfff, count);
}

static inline void dmem_store_u8(struct hle_t* hle, const uint8_t* src, uint16_t address, size_t count)
{
    store_u8(hle->dmem, address & 0xfff, src, count);
}

static inline void dmem_store_u16(struct hle_t* hle, const uint16_t* src, uint16_t address, size_t count)
{
    store_u16(hle->dmem, address & 0xfff, src, count);
}

static inline void dmem_store_u32(struct hle_t* hle, const uint32_t* src, uint16_t address, size_t count)
{
    store_u32(hle->dmem, address & 0xfff, src, count);
}

/* convenient functions DRAM access */
static inline uint8_t* dram_u8(struct hle_t* hle, uint32_t address)
{
    return u8(hle->dram, address & 0xffffff);
}

static inline uint16_t* dram_u16(struct hle_t* hle, uint32_t address)
{
    return u16(hle->dram, address & 0xffffff);
}

static inline uint32_t* dram_u32(struct hle_t* hle, uint32_t address)
{
    return u32(hle->dram, address & 0xffffff);
}

static inline void dram_load_u8(struct hle_t* hle, uint8_t* dst, uint32_t address, size_t count)
{
    load_u8(dst, hle->dram, address & 0xffffff, count);
}

static inline void dram_load_u16(struct hle_t* hle, uint16_t* dst, uint32_t address, size_t count)
{
    load_u16(dst, hle->dram, address & 0xffffff, count);
}

static inline void dram_load_u32(struct hle_t* hle, uint32_t* dst, uint32_t address, size_t count)
{
    load_u32(dst, hle->dram, address & 0xffffff, count);
}

static inline void dram_store_u8(struct hle_t* hle, const uint8_t* src, uint32_t address, size_t count)
{
    store_u8(hle->dram, address & 0xffffff, src, count);
}

static inline void dram_store_u16(struct hle_t* hle, const uint16_t* src, uint32_t address, size_t count)
{
    store_u16(hle->dram, address & 0xffffff, src, count);
}

static inline void dram_store_u32(struct hle_t* hle, const uint32_t* src, uint32_t address, size_t count)
{
    store_u32(hle->dram, address & 0xffffff, src, count);
}

#endif

