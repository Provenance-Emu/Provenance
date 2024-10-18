/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - dbg_memory.c                                            *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008 DarkJeztr                                          *
 *   Copyright (C) 2002 Blight                                             *
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

#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "dbg_breakpoints.h"
#include "dbg_memory.h"
#include "device/device.h"
#include "device/r4300/cached_interp.h"
#include "osal/preproc.h"

#if !defined(NO_ASM) && (defined(__i386__) || (defined(__x86_64__) && defined(__GNUC__)))

/* we must define PACKAGE so that bfd.h (which is included from dis-asm.h) doesn't throw an error */
#define PACKAGE "mupen64plus-core"
#include <dis-asm.h>
#include <stdarg.h>

static int  lines_recompiled;
static uint32_t addr_recompiled;
static int  num_decoded;

static char opcode_recompiled[564][MAX_DISASSEMBLY];
static char args_recompiled[564][MAX_DISASSEMBLY*4];
static void *opaddr_recompiled[564];

static disassemble_info dis_info;
static disassembler_ftype disassemble;

static void process_opcode_out(void *strm, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    char *arg;
    char buff[256];

    if (num_decoded==0)
    {
        if (strcmp(fmt,"%s")==0)
        {
            arg = va_arg(ap, char*);
            strcpy(opcode_recompiled[lines_recompiled],arg);
        }
        else
            strcpy(opcode_recompiled[lines_recompiled],"OPCODE-X");
        num_decoded++;
        *(args_recompiled[lines_recompiled])=0;
    }
    else
    {
        vsprintf(buff, fmt, ap);
        sprintf(args_recompiled[lines_recompiled],"%s%s",
                args_recompiled[lines_recompiled],buff);
    }
    va_end(ap);
}

// Callback function that will be called by libopcodes to read the
// bytes to disassemble ('read_memory_func' member of 'disassemble_info').
static int read_memory_func(bfd_vma memaddr, bfd_byte *myaddr, unsigned int length, disassemble_info *info)
{
    char* from = (char*)(long)(memaddr);
    char* to =   (char*)myaddr;

    while (length-- != 0) {
        *to++ = *from++;
    }
    return (0);
}

void init_host_disassembler(void)
{
    INIT_DISASSEMBLE_INFO(dis_info, stderr, process_opcode_out);
    dis_info.fprintf_func = (fprintf_ftype) process_opcode_out;
    dis_info.stream = stderr;
    dis_info.bytes_per_line=1;
    dis_info.endian = 1;
    dis_info.arch = bfd_arch_i386;
    dis_info.mach = bfd_mach_i386_i8086;
    dis_info.disassembler_options = (char*) "i386,suffix";
    dis_info.read_memory_func = read_memory_func;

#if defined(USE_LIBOPCODES_GE_2_29)
    /* libopcode >= 2.29 cannot use print_insn_i386 directly,
     * but can get it through disassembler function
     * whose prototype has been also updated to allow such selection. */
    disassemble = disassembler(dis_info.arch,
            (dis_info.endian == BFD_ENDIAN_BIG),
            dis_info.mach,
            NULL);
#else
    disassemble = print_insn_i386;
#endif
}

static void decode_recompiled(struct r4300_core* r4300, uint32_t addr)
{
    unsigned char *assemb, *end_addr;

    lines_recompiled=0;

    if (r4300->cached_interp.blocks[addr>>12] == NULL)
        return;

    if (r4300->cached_interp.blocks[addr>>12]->block[(addr&0xFFF)/4].ops == r4300->cached_interp.not_compiled)
    {
        strcpy(opcode_recompiled[0],"INVLD");
        strcpy(args_recompiled[0],"NOTCOMPILED");
        opaddr_recompiled[0] = (void *) 0;
        addr_recompiled=0;
        lines_recompiled++;
        return;
    }

    assemb = (r4300->cached_interp.blocks[addr>>12]->code) +
        (r4300->cached_interp.blocks[addr>>12]->block[(addr&0xFFF)/4].local_addr);

    end_addr = r4300->cached_interp.blocks[addr>>12]->code;

    if ((addr & 0xFFF) >= 0xFFC)
        end_addr += r4300->cached_interp.blocks[addr>>12]->code_length;
    else
        end_addr += r4300->cached_interp.blocks[addr>>12]->block[(addr&0xFFF)/4+1].local_addr;

    while (assemb < end_addr)
    {
        opaddr_recompiled[lines_recompiled] = assemb;
        num_decoded=0;

        assemb += disassemble((bfd_vma)(long) assemb, &dis_info);

        lines_recompiled++;
    }

    addr_recompiled = addr;
}

char* get_recompiled_opcode(struct r4300_core* r4300, uint32_t addr, int index)
{
    if (addr != addr_recompiled)
        decode_recompiled(r4300, addr);

    if (index < lines_recompiled)
        return opcode_recompiled[index];
    else
        return NULL;
}

char* get_recompiled_args(struct r4300_core* r4300, uint32_t addr, int index)
{
    if (addr != addr_recompiled)
        decode_recompiled(r4300, addr);

    if (index < lines_recompiled)
        return args_recompiled[index];
    else
        return NULL;
}

void* get_recompiled_addr(struct r4300_core* r4300, uint32_t addr, int index)
{
    if (addr != addr_recompiled)
        decode_recompiled(r4300, addr);

    if (index < lines_recompiled)
        return opaddr_recompiled[index];
    else
        return 0;
}

int get_num_recompiled(struct r4300_core* r4300, uint32_t addr)
{
    if (addr != addr_recompiled)
        decode_recompiled(r4300, addr);

    return lines_recompiled;
}

int get_has_recompiled(struct r4300_core* r4300, uint32_t addr)
{
    unsigned char *assemb, *end_addr;

    if (r4300->emumode != EMUMODE_DYNAREC || r4300->cached_interp.blocks[addr>>12] == NULL)
        return FALSE;

    assemb = (r4300->cached_interp.blocks[addr>>12]->code) +
        (r4300->cached_interp.blocks[addr>>12]->block[(addr&0xFFF)/4].local_addr);

    end_addr = r4300->cached_interp.blocks[addr>>12]->code;

    if ((addr & 0xFFF) >= 0xFFC)
        end_addr += r4300->cached_interp.blocks[addr>>12]->code_length;
    else
        end_addr += r4300->cached_interp.blocks[addr>>12]->block[(addr&0xFFF)/4+1].local_addr;
    if(assemb==end_addr)
        return FALSE;

    return TRUE;
}

#else

int get_num_recompiled(struct r4300_core* r4300, uint32_t addr)
{
    return 0;
}

char* get_recompiled_opcode(struct r4300_core* r4300, uint32_t addr, int index)
{
    return NULL;
}

char* get_recompiled_args(struct r4300_core* r4300, uint32_t addr, int index)
{
    return NULL;
}

void* get_recompiled_addr(struct r4300_core* r4300, uint32_t addr, int index)
{
    return 0;
}

int get_has_recompiled(struct r4300_core* r4300, uint32_t addr)
{
    return 0;
}

void init_host_disassembler(void)
{

}

#endif

#ifdef DBG

uint64_t read_memory_64(struct device* dev, uint32_t addr)
{
    return ((uint64_t)read_memory_32(dev, addr) << 32) | (uint64_t)read_memory_32(dev, addr + 4);
}

uint64_t read_memory_64_unaligned(struct device* dev, uint32_t addr)
{
    uint64_t w[2];

    w[0] = read_memory_32_unaligned(dev, addr);
    w[1] = read_memory_32_unaligned(dev, addr + 4);
    return (w[0] << 32) | w[1];
}

void write_memory_64(struct device* dev, uint32_t addr, uint64_t value)
{
    write_memory_32(dev, addr, (uint32_t) (value >> 32));
    write_memory_32(dev, addr + 4, (uint32_t) (value & 0xFFFFFFFF));
}

void write_memory_64_unaligned(struct device* dev, uint32_t addr, uint64_t value)
{
    write_memory_32_unaligned(dev, addr, (uint32_t) (value >> 32));
    write_memory_32_unaligned(dev, addr + 4, (uint32_t) (value & 0xFFFFFFFF));
}

uint32_t read_memory_32(struct device* dev, uint32_t addr)
{
    uint32_t value;
    if (r4300_read_aligned_word(&dev->r4300, addr, &value) == 0)
        return M64P_MEM_INVALID;
    return value;
}

uint32_t read_memory_32_unaligned(struct device* dev, uint32_t addr)
{
    uint8_t i, b[4];

    for(i=0; i<4; i++) b[i] = read_memory_8(dev, addr + i);
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
}

void write_memory_32(struct device* dev, uint32_t addr, uint32_t value)
{
    r4300_write_aligned_word(&dev->r4300, addr, value, 0xffffffff);
}

void write_memory_32_unaligned(struct device* dev, uint32_t addr, uint32_t value)
{
    write_memory_8(dev, addr + 0, value >> 24);
    write_memory_8(dev, addr + 1, (value >> 16) & 0xFF);
    write_memory_8(dev, addr + 2, (value >> 8) & 0xFF);
    write_memory_8(dev, addr + 3, value & 0xFF);
}

//read_memory_16_unaligned and write_memory_16_unaligned don't exist because
//read_memory_16 and write_memory_16 work unaligned already.
uint16_t read_memory_16(struct device* dev, uint32_t addr)
{
    return ((uint16_t)read_memory_8(dev, addr) << 8) | (uint16_t)read_memory_8(dev, addr+1); //cough cough hack hack
}

void write_memory_16(struct device* dev, uint32_t addr, uint16_t value)
{
    write_memory_8(dev, addr, value >> 8); //this isn't much better
    write_memory_8(dev, addr + 1, value & 0xFF); //then again, it works unaligned
}

uint8_t read_memory_8(struct device* dev, uint32_t addr)
{
    uint32_t word;

    word = read_memory_32(dev, addr & ~3);
    return (word >> ((3 - (addr & 3)) * 8)) & 0xFF;
}

void write_memory_8(struct device* dev, uint32_t addr, uint8_t value)
{
    uint32_t word;
    uint32_t mask;

    mask = 0xFF << ((3 - (addr & 3)) * 8);
    word = value << ((3 - (addr & 3)) * 8);
    
    r4300_write_aligned_word(&dev->r4300, addr, word, mask);
}

uint32_t get_memory_flags(struct device* dev, uint32_t addr)
{
    int type=get_memory_type(&dev->mem, addr);
    const uint32_t addrlow = (addr & 0xFFFF);
    uint32_t flags = 0;

    switch(type)
    {
        case M64P_MEM_NOMEM:
            if(dev->r4300.cp0.tlb.LUT_r[addr>>12])
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_NOTHING:
            if (((addr >> 16) == 0x8801 || (addr >> 16 == 0xA801)) && addrlow == 0)
                flags = M64P_MEM_FLAG_WRITABLE_EMUONLY; // for flashram command
            break;
        case M64P_MEM_RDRAM:
            flags = M64P_MEM_FLAG_WRITABLE;
        case M64P_MEM_ROM:
            flags |= M64P_MEM_FLAG_READABLE;
            break;
        case M64P_MEM_RDRAMREG:
            if (addrlow < 0x28)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_RSPMEM:
            if (addrlow < 0x2000)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_RSPREG:
            if (addrlow < 0x20)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_RSP:
            if (addrlow < 0x8)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_DP:
            if (addrlow < 0x20)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_DPS:
            if (addrlow < 0x10)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_VI:
            if (addrlow < 0x38)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_AI:
            if (addrlow < 0x18)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_PI:
            if (addrlow < 0x34)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_RI:
            if (addrlow < 0x20)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_SI:
            if (addrlow < 0x1c)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_FLASHRAMSTAT:
            if (addrlow == 0)
                flags = M64P_MEM_FLAG_READABLE_EMUONLY;
            break;
        case M64P_MEM_PIF:
            if (addrlow >= 0x7C0 && addrlow <= 0x7FF)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        case M64P_MEM_MI:
            if (addrlow < 0x10)
                flags = M64P_MEM_FLAG_READABLE | M64P_MEM_FLAG_WRITABLE_EMUONLY;
            break;
        default:
            break;
    }

    return flags;
}

#endif
