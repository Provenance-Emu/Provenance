/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - hle.h                                           *
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

#ifndef HLE_H
#define HLE_H

#include "hle_internal.h"

void hle_init(struct hle_t* hle,
    unsigned char* dram,
    unsigned char* dmem,
    unsigned char* imem,
    unsigned int* mi_intr,
    unsigned int* sp_mem_addr,
    unsigned int* sp_dram_addr,
    unsigned int* sp_rd_length,
    unsigned int* sp_wr_length,
    unsigned int* sp_status,
    unsigned int* sp_dma_full,
    unsigned int* sp_dma_busy,
    unsigned int* sp_pc,
    unsigned int* sp_semaphore,
    unsigned int* dpc_start,
    unsigned int* dpc_end,
    unsigned int* dpc_current,
    unsigned int* dpc_status,
    unsigned int* dpc_clock,
    unsigned int* dpc_bufbusy,
    unsigned int* dpc_pipebusy,
    unsigned int* dpc_tmem,
    void* user_defined);

void hle_execute(struct hle_t* hle);

#endif

