/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - hvqm.c                                          *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2020 Gilles Siberlin                                    *
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

#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "hle_external.h"
#include "hle_internal.h"
#include "memory.h"

 /* Nest size  */
#define HVQM2_NESTSIZE_L 70	/* Number of elements on long side */
#define HVQM2_NESTSIZE_S 38	/* Number of elements on short side */
#define HVQM2_NESTSIZE (HVQM2_NESTSIZE_L * HVQM2_NESTSIZE_S)

struct HVQM2Block {
    uint8_t nbase;
    uint8_t dc;
    uint8_t dc_l;
    uint8_t dc_r;
    uint8_t dc_u;
    uint8_t dc_d;
};

struct HVQM2Basis {
    uint8_t sx;
    uint8_t sy;
    int16_t scale;
    uint16_t offset;
    uint16_t lineskip;
};

struct HVQM2Arg {
    uint32_t info;
    uint32_t buf;
    uint16_t buf_width;
    uint8_t chroma_step_h;
    uint8_t chroma_step_v;
    uint16_t hmcus;
    uint16_t vmcus;
    uint8_t alpha;
    uint32_t nest;
};

struct RGBA {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
};

static struct HVQM2Arg arg;

static const int16_t constant[5][16] = {
{0x0006,0x0008,0x0008,0x0006,0x0008,0x000A,0x000A,0x0008,0x0008,0x000A,0x000A,0x0008,0x0006,0x0008,0x0008,0x0006},
{0x0002,0x0000,0xFFFF,0xFFFF,0x0002,0x0000,0xFFFF,0xFFFF,0x0002,0x0000,0xFFFF,0xFFFF,0x0002,0x0000,0xFFFF,0xFFFF},
{0xFFFF,0xFFFF,0x0000,0x0002,0xFFFF,0xFFFF,0x0000,0x0002,0xFFFF,0xFFFF,0x0000,0x0002,0xFFFF,0xFFFF,0x0000,0x0002},
{0x0002,0x0002,0x0002,0x0002,0x0000,0x0000,0x0000,0x0000,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF},
{0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0x0000,0x0000,0x0000,0x0000,0x0002,0x0002,0x0002,0x0002}
};

static int process_info(struct hle_t* hle, uint8_t* base, int16_t* out)
{
    struct HVQM2Block block;
    uint8_t nbase = *base;

    dram_load_u8(hle, (uint8_t*)&block, arg.info, sizeof(struct HVQM2Block));
    arg.info += 8;

    *base = block.nbase & 0x7;

    if ((block.nbase & nbase) != 0)
        return 0;

    if (block.nbase == 0)
    {
        //LABEL8
        for (int i = 0; i < 16; i++)
        {
            out[i] = constant[0][i] * block.dc;
            out[i] += constant[1][i] * block.dc_l;
            out[i] += constant[2][i] * block.dc_r;
            out[i] += constant[3][i] * block.dc_u;
            out[i] += constant[4][i] * block.dc_d;
            out[i] += 4;
            out[i] >>= 3;
        }
    }
    else if ((block.nbase & 0xf) == 0)
    {
        //LABEL7
        for (int i = 0; i < 16; i++)
        {
            out[i] = *dram_u8(hle, arg.info);
            arg.info++;
        }
    }
    else if (*base == 0)
    {
        //LABEL6
        for (int i = 0; i < 16; i++)
        {
            out[i] = *(int8_t*)dram_u8(hle, arg.info) + block.dc;
            arg.info++;
        }
    }
    else
    {
        //LABEL5
        struct HVQM2Basis basis;

        for (int i = 0; i < 16; i++)
            out[i] = block.dc;

        for (; *base != 0; (*base)--)
        {
            basis.sx = *dram_u8(hle, arg.info);
            arg.info++;
            basis.sy = *dram_u8(hle, arg.info);
            arg.info++;
            basis.scale = *dram_u16(hle, arg.info);
            arg.info += 2;
            basis.offset = *dram_u16(hle, arg.info);
            arg.info += 2;
            basis.lineskip = *dram_u16(hle, arg.info);
            arg.info += 2;

            int16_t vec[16];
            uint32_t addr = arg.nest + basis.offset;
            int shift = (basis.sx != 0) ? 1 : 0;

            //LABEL9
            //LABEL10
            for (int i = 0; i < 16; i += 4)
            {
                vec[i] = *dram_u8(hle, addr);
                vec[i + 1] = *dram_u8(hle, addr + (1 << shift));
                vec[i + 2] = *dram_u8(hle, addr + (2 << shift));
                vec[i + 3] = *dram_u8(hle, addr + (3 << shift));
                addr += basis.lineskip;
            }

            //LABEL11
            int16_t sum = 0x8;
            for (int i = 0; i < 16; i++)
                sum += vec[i];

            sum >>= 4;

            int16_t max = 0;
            for (int i = 0; i < 16; i++)
            {
                vec[i] -= sum;
                max = (abs(vec[i]) > max) ? abs(vec[i]) : max;
            }

            double dmax = 0.0;
            if (max > 0)
                dmax = (double)(basis.scale << 2) / (double)max;

            for (int i = 0; i < 16; i++)
                out[i] += (vec[i] < 0) ? (int16_t)((double)vec[i] * dmax - 0.5) : (int16_t)((double)vec[i] * dmax + 0.5);

            block.nbase &= 8;
        }

        assert(block.nbase == 0);
        //if(block.nbase != 0)
        //  LABEL6
    }

    return 1;
}

#define SATURATE8(x) ((unsigned int) x <= 255 ? x : (x < 0 ? 0: 255))
static struct RGBA YCbCr_to_RGBA(int16_t Y, int16_t Cb, int16_t Cr, uint8_t alpha)
{
    struct RGBA color;

    //Format S10.6
    int r = (int)(((double)Y + 0.5) + (1.765625 * (double)(Cr - 128)));
    int g = (int)(((double)Y + 0.5) - (0.34375 * (double)(Cr - 128)) - (0.71875 * (double)(Cb - 128)));
    int b = (int)(((double)Y + 0.5) + (1.40625 * (double)(Cb - 128)));

    color.r = SATURATE8(r);
    color.g = SATURATE8(g);
    color.b = SATURATE8(b);
    color.a = alpha;

    return color;
}

void store_rgba5551(struct hle_t* hle, struct RGBA color, uint32_t * addr)
{
    uint16_t pixel = ((color.b >> 3) << 11) | ((color.g >> 3) << 6) | ((color.r >> 3) << 1) | (color.a & 1);
    dram_store_u16(hle, &pixel, *addr, 1);
    *addr += 2;
}

void store_rgba8888(struct hle_t* hle, struct RGBA color, uint32_t * addr)
{
    uint32_t pixel = (color.b << 24) | (color.g << 16) | (color.r << 8) | color.a;
    dram_store_u32(hle, &pixel, *addr, 1);
    *addr += 4;
}

typedef void(*store_pixel_t)(struct hle_t* hle, struct RGBA color, uint32_t * addr);

static void hvqm2_decode(struct hle_t* hle, int is32)
{
    //uint32_t uc_data_ptr = *dmem_u32(hle, TASK_UCODE_DATA);
    uint32_t data_ptr = *dmem_u32(hle, TASK_DATA_PTR);

    assert((*dmem_u32(hle, TASK_FLAGS) & 0x1) == 0);

    /* Fill HVQM2Arg struct */
    arg.info = *dram_u32(hle, data_ptr);
    data_ptr += 4;
    arg.buf = *dram_u32(hle, data_ptr);
    data_ptr += 4;
    arg.buf_width = *dram_u16(hle, data_ptr);
    data_ptr += 2;
    arg.chroma_step_h = *dram_u8(hle, data_ptr);
    data_ptr++;
    arg.chroma_step_v = *dram_u8(hle, data_ptr);
    data_ptr++;
    arg.hmcus = *dram_u16(hle, data_ptr);
    data_ptr += 2;
    arg.vmcus = *dram_u16(hle, data_ptr);
    data_ptr += 2;
    arg.alpha = *dram_u8(hle, data_ptr);
    arg.nest = data_ptr + 1;

    assert(arg.chroma_step_h == 2);
    assert((arg.chroma_step_v == 1) || (arg.chroma_step_v == 2));
    assert((*hle->sp_status & 0x80) == 0);  //SP_STATUS_YIELD

    int length, skip;
    store_pixel_t store_pixel;

    if (is32)
    {
        length = 0x20;
        skip = arg.buf_width << 2;
        arg.buf_width <<= 4;
        store_pixel = &store_rgba8888;
    }
    else
    {
        length = 0x10;
        skip = arg.buf_width << 1;
        arg.buf_width <<= 3;
        store_pixel = &store_rgba5551;
    }

    if (arg.chroma_step_v == 2)
        arg.buf_width += arg.buf_width;

    for (int i = arg.vmcus; i != 0; i--)
    {
        uint32_t out;
        int j;

        for (j = arg.hmcus, out = arg.buf; j != 0; j--, out += length)
        {
            uint8_t base = 0x80;
            int16_t Cb[16], Cr[16], Y1[32], Y2[32];
            int16_t* pCb = Cb;
            int16_t* pCr = Cr;
            int16_t* pY1 = Y1;
            int16_t* pY2 = Y2;

            if (arg.chroma_step_v == 2)
            {
                if (process_info(hle, &base, pY1) == 0)
                    continue;
                if (process_info(hle, &base, pY2) == 0)
                    continue;

                pY1 = &Y1[16];
                pY2 = &Y2[16];
            }

            if (process_info(hle, &base, pY1) == 0)
                continue;
            if (process_info(hle, &base, pY2) == 0)
                continue;
            if (process_info(hle, &base, Cr) == 0)
                continue;
            if (process_info(hle, &base, Cb) == 0)
                continue;

            pY1 = Y1;
            pY2 = Y2;

            uint32_t out_buf = out;
            for (int k = 0; k < 4; k++)
            {
                for (int m = 0; m < arg.chroma_step_v; m++)
                {
                    uint32_t addr = out_buf;
                    for (int l = 0; l < 4; l++)
                    {
                        struct RGBA color = YCbCr_to_RGBA(pY1[l], pCb[l >> 1], pCr[l >> 1], arg.alpha);
                        store_pixel(hle, color, &addr);
                    }
                    for (int l = 0; l < 4; l++)
                    {
                        struct RGBA color = YCbCr_to_RGBA(pY2[l], pCb[(l + 4) >> 1], pCr[(l + 4) >> 1], arg.alpha);
                        store_pixel(hle, color, &addr);
                    }
                    out_buf += skip;
                    pY1 += 4;
                    pY2 += 4;
                }
                pCr += 4;
                pCb += 4;
            }
        }
        arg.buf += arg.buf_width;
    }
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void hvqm2_decode_sp1_task(struct hle_t* hle)
{
    hvqm2_decode(hle, 0);
}

void hvqm2_decode_sp2_task(struct hle_t* hle)
{
    hvqm2_decode(hle, 1);
}