/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - re2.c                                           *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2016 Gilles Siberlin                                    *
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
#include <stdint.h>
#include <stdlib.h>

#include "hle_external.h"
#include "hle_internal.h"
#include "memory.h"

#define SATURATE8(x) ((unsigned int) x <= 255 ? x : (x < 0 ? 0: 255))

/**************************************************************************
 * Resident evil 2 ucodes
 **************************************************************************/
void resize_bilinear_task(struct hle_t* hle)
{
    int data_ptr = *dmem_u32(hle, TASK_UCODE_DATA);

    int src_addr = *dram_u32(hle, data_ptr);
    int dst_addr = *dram_u32(hle, data_ptr + 4);
    int dst_width = *dram_u32(hle, data_ptr + 8);
    int dst_height = *dram_u32(hle, data_ptr + 12);
    int x_ratio = *dram_u32(hle, data_ptr + 16);
    int y_ratio = *dram_u32(hle, data_ptr + 20);
#if 0 /* unused, but keep it for documentation purpose */
    int dst_stride = *dram_u32(hle, data_ptr + 24);
#endif
    int src_offset = *dram_u32(hle, data_ptr + 36);

    int a, b, c ,d, index, y_index, xr, yr, blue, green, red, addr, i, j;
    long long x, y, x_diff, y_diff, one_min_x_diff, one_min_y_diff;
    unsigned short pixel;

    src_addr += (src_offset >> 16) * (320 * 3);
    x = y = 0;

    for(i = 0; i < dst_height; i++)
    {
        yr = (int)(y >> 16);
        y_diff = y - (yr << 16);
        one_min_y_diff = 65536 - y_diff;
        y_index = yr * 320;
        x = 0;

        for(j = 0; j < dst_width; j++)
        {
            xr = (int)(x >> 16);
            x_diff = x - (xr << 16);
            one_min_x_diff = 65536 - x_diff;
            index = y_index + xr;
            addr = src_addr + (index * 3);

            dram_load_u8(hle, (uint8_t*)&a, addr, 3);
            dram_load_u8(hle, (uint8_t*)&b, (addr + 3), 3);
            dram_load_u8(hle, (uint8_t*)&c, (addr + (320 * 3)), 3);
            dram_load_u8(hle, (uint8_t*)&d, (addr + (320 * 3) + 3), 3);

            blue = (int)(((a&0xff)*one_min_x_diff*one_min_y_diff + (b&0xff)*x_diff*one_min_y_diff +
                          (c&0xff)*y_diff*one_min_x_diff         + (d&0xff)*x_diff*y_diff) >> 32);

            green = (int)((((a>>8)&0xff)*one_min_x_diff*one_min_y_diff + ((b>>8)&0xff)*x_diff*one_min_y_diff +
                           ((c>>8)&0xff)*y_diff*one_min_x_diff         + ((d>>8)&0xff)*x_diff*y_diff) >> 32);

            red = (int)((((a>>16)&0xff)*one_min_x_diff*one_min_y_diff + ((b>>16)&0xff)*x_diff*one_min_y_diff +
                         ((c>>16)&0xff)*y_diff*one_min_x_diff         + ((d>>16)&0xff)*x_diff*y_diff) >> 32);

            blue = (blue >> 3) & 0x001f;
            green = (green >> 3) & 0x001f;
            red = (red >> 3) & 0x001f;
            pixel = (red << 11) | (green << 6) | (blue << 1) | 1;

            dram_store_u16(hle, &pixel, dst_addr, 1);
            dst_addr += 2;

            x += x_ratio;
        }
        y += y_ratio;
    }

    rsp_break(hle, SP_STATUS_TASKDONE);
}

static uint32_t YCbCr_to_RGBA(uint8_t Y, uint8_t Cb, uint8_t Cr)
{
    int r, g, b;

    r = (int)(((double)Y * 0.582199097) + (0.701004028 * (double)(Cr - 128)));
    g = (int)(((double)Y * 0.582199097) - (0.357070923 * (double)(Cr - 128)) - (0.172073364 * (double)(Cb - 128)));
    b = (int)(((double)Y * 0.582199097) + (0.886001587 * (double)(Cb - 128)));
    
    r = SATURATE8(r);
    g = SATURATE8(g);
    b = SATURATE8(b);
    
    return (r << 24) | (g << 16) | (b << 8) | 0;
}

void decode_video_frame_task(struct hle_t* hle)
{
    int data_ptr = *dmem_u32(hle, TASK_UCODE_DATA);

    int pLuminance = *dram_u32(hle, data_ptr);
    int pCb = *dram_u32(hle, data_ptr + 4);
    int pCr = *dram_u32(hle, data_ptr + 8);
    int pDestination = *dram_u32(hle, data_ptr + 12);
    int nMovieWidth = *dram_u32(hle, data_ptr + 16);
    int nMovieHeight = *dram_u32(hle, data_ptr + 20);
#if 0 /* unused, but keep it for documentation purpose */
    int nRowsPerDMEM = *dram_u32(hle, data_ptr + 24);
    int nDMEMPerFrame = *dram_u32(hle, data_ptr + 28);
    int nLengthSkipCount = *dram_u32(hle, data_ptr + 32);
#endif
    int nScreenDMAIncrement = *dram_u32(hle, data_ptr + 36);

    int i, j;
    uint8_t Y, Cb, Cr;
    uint32_t pixel;
    int pY_1st_row, pY_2nd_row, pDest_1st_row, pDest_2nd_row;

    for (i = 0; i < nMovieHeight; i += 2)
    {
        pY_1st_row = pLuminance;
        pY_2nd_row = pLuminance + nMovieWidth;
        pDest_1st_row = pDestination;
        pDest_2nd_row = pDestination + (nScreenDMAIncrement >> 1);

        for (j = 0; j < nMovieWidth; j += 2)
        {
            dram_load_u8(hle, (uint8_t*)&Cb, pCb++, 1);
            dram_load_u8(hle, (uint8_t*)&Cr, pCr++, 1);

            /*1st row*/
            dram_load_u8(hle, (uint8_t*)&Y, pY_1st_row++, 1);
            pixel = YCbCr_to_RGBA(Y, Cb, Cr);
            dram_store_u32(hle, &pixel, pDest_1st_row, 1);
            pDest_1st_row += 4;

            dram_load_u8(hle, (uint8_t*)&Y, pY_1st_row++, 1);
            pixel = YCbCr_to_RGBA(Y, Cb, Cr);
            dram_store_u32(hle, &pixel, pDest_1st_row, 1);
            pDest_1st_row += 4;

            /*2nd row*/
            dram_load_u8(hle, (uint8_t*)&Y, pY_2nd_row++, 1);
            pixel = YCbCr_to_RGBA(Y, Cb, Cr);
            dram_store_u32(hle, &pixel, pDest_2nd_row, 1);
            pDest_2nd_row += 4;

            dram_load_u8(hle, (uint8_t*)&Y, pY_2nd_row++, 1);
            pixel = YCbCr_to_RGBA(Y, Cb, Cr);
            dram_store_u32(hle, &pixel, pDest_2nd_row, 1);
            pDest_2nd_row += 4;
        }

        pLuminance += (nMovieWidth << 1);
        pDestination += nScreenDMAIncrement;
    }

    rsp_break(hle, SP_STATUS_TASKDONE);
}

void fill_video_double_buffer_task(struct hle_t* hle)
{
    int data_ptr = *dmem_u32(hle, TASK_UCODE_DATA);

    int pSrc = *dram_u32(hle, data_ptr);
    int pDest = *dram_u32(hle, data_ptr + 0x4);
    int width = *dram_u32(hle, data_ptr + 0x8) >> 1;
    int height = *dram_u32(hle, data_ptr + 0x10) << 1;
    int stride = *dram_u32(hle, data_ptr + 0x1c) >> 1;

    assert((*dram_u32(hle, data_ptr + 0x28) >> 16) == 0x8000);

#if 0 /* unused, but keep it for documentation purpose */
    int arg3 = *dram_u32(hle, data_ptr + 0xc);
    int arg5 = *dram_u32(hle, data_ptr + 0x14);
    int arg6 = *dram_u32(hle, data_ptr + 0x18);
#endif

    int i, j;
    int r, g, b;
    uint32_t pixel, pixel1, pixel2;

    for(i = 0; i < height; i++)
    {
      for(j = 0; j < width; j=j+4)
      {
        pixel1 = *dram_u32(hle, pSrc+j);
        pixel2 = *dram_u32(hle, pDest+j);
      
        r = (((pixel1 >> 24) & 0xff) + ((pixel2 >> 24) & 0xff)) >> 1;
        g = (((pixel1 >> 16) & 0xff) + ((pixel2 >> 16) & 0xff)) >> 1;
        b = (((pixel1 >> 8) & 0xff) + ((pixel2 >> 8) & 0xff)) >> 1;
      
        pixel = (r << 24) | (g << 16) | (b << 8) | 0;
      
        dram_store_u32(hle, &pixel, pDest+j, 1);
      }
      pSrc += stride;
      pDest += stride;
    }

    rsp_break(hle, SP_STATUS_TASKDONE);
}
