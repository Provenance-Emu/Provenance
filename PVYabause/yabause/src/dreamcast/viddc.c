/*  Copyright 2003-2006 Guillaume Duhamel
    Copyright 2004-2009 Lawrence Sebald
    Copyright 2004-2006 Theo Berkau
    Copyright 2006 Fabien Coulon

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
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "viddc.h"
#include "../debug.h"
#include "../vdp2.h"

#include <dc/video.h>
#include <dc/pvr.h>
#include <time.h>
#include <assert.h>
#include <string.h>
#include <kos/sem.h>
#include <arch/cache.h>

#include <stdio.h>

#define SAT2YAB1(temp)	((temp & 0x8000) | (temp & 0x1F) << 10 | \
                         (temp & 0x3E0) | (temp & 0x7C00) >> 10)
#define SAT2YAB32(alpha, temp)	(alpha << 24 | (temp & 0x1F) << 3 | \
                                 (temp & 0x3E0) << 6 | (temp & 0x7C00) << 9)

#define SAT2YAB2(dot1, dot2)    ((dot1 & 0xF8) << 7 | (dot2 & 0xF800) >> 6 | \
                                 (dot2 & 0x00F8) >> 3 | 0x8000)
#define SAT2YAB2_32(alpha, dot1, dot2)  (alpha << 24 | ((dot1 & 0xFF) << 16) | \
                                         (dot2 & 0xFF00) | (dot2 & 0xFF))

#define COLOR_ADDt32(b)		(b > 0xFF ? 0xFF : (b < 0 ? 0 : b))
#define COLOR_ADDb32(b1,b2)	COLOR_ADDt32((signed) (b1) + (b2))

#define COLOR_ADD32(l,r,g,b)	COLOR_ADDb32((l & 0xFF), r) | \
                (COLOR_ADDb32((l >> 8) & 0xFF, g) << 8) | \
                (COLOR_ADDb32((l >> 16) & 0xFF, b) << 16) | \
                (l & 0xFF000000)

#define COLOR_ADDt(b)       (b > 0xF8 ? 0xF8 : (b < 0x08 ? 0 : b))
#define COLOR_ADDb(b1,b2)   COLOR_ADDt((signed) (b1) + (b2))
#define COLOR_ADD(l,r,g,b)      ((COLOR_ADDb((l >> 7) & 0xF8, \
                                             r) & 0xF8) << 7) | \
                                ((COLOR_ADDb((l >> 2) & 0xF8, \
                                             g) & 0xF8) << 2) | \
                                ((COLOR_ADDb((l << 3) & 0xF8, \
                                             b) & 0xF8) >> 3) | \
                                (l & 0x8000)


static pvr_init_params_t pvr_params =   {
    /* Enable Opaque, Translucent, and Punch-Thru polygons with binsize 16 */
    { PVR_BINSIZE_16, PVR_BINSIZE_0, PVR_BINSIZE_16, PVR_BINSIZE_0,
      PVR_BINSIZE_16 },
    /* 512KB Vertex Buffer */
    512 * 1024,
    /* DMA Enabled */
    1,
    /* FSAA Disabled */
    0
};

struct sprite_info  {
    uint32 pvr_base;
    uint32 vdp1_base;
    float uf, vf;
    int w, h;
};

typedef struct  {
    int cellw, cellh;
    int flipfunction;
    int priority;

    int mapwh;
    int planew, planeh;
    int pagewh;
    int patternwh;
    int patterndatasize;
    int specialfunction;
    u32 addr, charaddr, paladdr;
    int colornumber;
    int isbitmap;
    u16 supplementdata;
    int auxmode;
    int enable;
    int x, y;
    int alpha;
    int coloroffset;
    int transparencyenable;
    int specialprimode;

    s32 cor;
    s32 cog;
    s32 cob;

    float coordincx, coordincy;
    void (* PlaneAddr)(void *, int);
    u16 (* PostPixelFetchCalc)(void *, u16);
    int patternpixelwh;
    int draww;
    int drawh;
} vdp2draw_struct;

static struct sprite_info cur_spr;

static struct sprite_info cache[1024];
int cached_spr = 0;

/* Polygon Headers */
static pvr_sprite_hdr_t op_poly_hdr;
static pvr_sprite_hdr_t tr_poly_hdr;
static pvr_sprite_hdr_t tr_sprite_hdr;
static pvr_sprite_hdr_t pt_sprite_hdr;

/* DMA Vertex Buffers 256KB Each */
static uint8 vbuf_opaque[1024 * 256] __attribute__((aligned(32)));
static uint8 vbuf_translucent[1024 * 256] __attribute__((aligned(32)));
static uint8 vbuf_punchthru[1024 * 256] __attribute__((aligned(32)));

/* VDP2 Framebuffer */
static uint16 *vdp2_fb;
static int vdp2_fbnum = 0;
static uint16 vdp2_fbs[2][512 * 256] __attribute__((aligned(32)));
static uint8 vdp2_prio[352][240];
static semaphore_t dmadone = SEM_INITIALIZER(1);

static pvr_ptr_t vdp2_tex;
static uint32 cur_vdp2;

/* Priority levels, sprites drawn last get drawn on top */
static float priority_levels[8];

/* Texture space for VDP1 sprites */
static pvr_ptr_t tex_space;
static uint32 cur_addr;

/* Misc parameters */
static int vdp1cor = 0;
static int vdp1cog = 0;
static int vdp1cob = 0;

static int nbg0priority = 0;
static int nbg1priority = 0;
static int nbg2priority = 0;
static int nbg3priority = 0;
static int rbg0priority = 0;

static int vdp2width = 320;
static int vdp2height = 224;

/* Frame counter */
static time_t lastup;
static int framecount;

static int power_of_two(int num)    {
    int ret = 8;

    while(ret < num)
        ret <<= 1;

    return ret;
}

static inline void vdp2putpixel(s32 x, s32 y, u16 color, int priority)  {
    vdp2_fb[(y * 512) + x] = color;
    vdp2_prio[x][y] = (uint8) priority;
}

static u32 Vdp2ColorRamGetColor32(u32 colorindex, int alpha)    {
    switch(Vdp2Internal.ColorMode)  {
        case 0:
        case 1:
        {
            u32 tmp;
            colorindex <<= 1;
            tmp = T2ReadWord(Vdp2ColorRam, colorindex & 0xFFF);
            return SAT2YAB32(alpha, tmp);
        }
        case 2:
        {
            u32 tmp1, tmp2;
            colorindex <<= 2;
            colorindex &= 0xFFF;
            tmp1 = T2ReadWord(Vdp2ColorRam, colorindex);
            tmp2 = T2ReadWord(Vdp2ColorRam, colorindex+2);
            return SAT2YAB2_32(alpha, tmp1, tmp2);
        }
        default:
            break;
    }

    return 0;
}

static uint16 Vdp2ColorRamGetColor(u32 colorindex)   {
    u16 tmp;

    switch(Vdp2Internal.ColorMode)  {
        case 0:
        case 1:
        {
            colorindex <<= 1;
            tmp = T2ReadWord(Vdp2ColorRam, colorindex & 0xFFF);
            return SAT2YAB1(tmp) | 0x8000;
        }
        case 2:
        {
            u16 tmp2;
            colorindex <<= 2;
            colorindex &= 0xFFF;
            tmp = T2ReadWord(Vdp2ColorRam, colorindex);
            tmp2 = T2ReadWord(Vdp2ColorRam, colorindex+2);
            return SAT2YAB2(tmp, tmp2) | 0x8000;
        }
        default:
            break;
    }

    return 0;
}

static int Vdp1ReadTexture(vdp1cmd_struct *cmd, pvr_sprite_hdr_t *hdr) {
    u32 charAddr = cmd->CMDSRCA << 3;
    uint16 dot, dot2;
    int queuepos = 0;
    uint32 *store_queue;
    uint32 cur_base;
    u8 SPD = ((cmd->CMDPMOD & 0x40) != 0);
    int k;

    int wi = power_of_two(cur_spr.w);
    int he = power_of_two(cur_spr.h);

    for(k = 0; k < cached_spr; ++k)  {
        if(cache[k].vdp1_base == charAddr) {
            if(cache[k].w == cur_spr.w && cache[k].h == cur_spr.h)  {
                cur_base = cache[k].pvr_base;
                goto fillHeader;
            }
        }
    }

    cur_base = cur_addr;

    /* Set up both Store Queues for transfer to VRAM */
    QACR0 = 0x00000004;
    QACR1 = 0x00000004;

    switch((cmd->CMDPMOD >> 3) & 0x07)  {
        case 0:
        {
            // 4 bpp Bank mode
            u16 temp;
            u32 colorBank = cmd->CMDCOLR;
            u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
            int i, j;

            for(i = 0; i < cur_spr.h; ++i)  {
                store_queue = (uint32 *) (0xE0000000 |
                                          (cur_addr & 0x03FFFFE0));

                for(j = 0; j < cur_spr.w; j += 2)    {
                    dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);

                    if(((dot & 0xF) == 0) && !SPD) dot2 = 0;
                    else    {
                        temp = Vdp2ColorRamGetColor(((dot & 0x0F) | colorBank) +
                                                    colorOffset);
                        dot2 = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    if(((dot >> 4) == 0) && !SPD)  dot = 0;
                    else    {
                        temp = Vdp2ColorRamGetColor(((dot >> 4) | colorBank) +
                                                    colorOffset);
                        dot = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    ++charAddr;

                    store_queue[queuepos++] = dot | (dot2 << 16);

                    if(queuepos == 8)   {
                        asm("pref @%0" : : "r"(store_queue));
                        queuepos = 0;
                        store_queue += 8;
                    }
                }

                if(queuepos)    {
                    asm("pref @%0" : : "r"(store_queue));
                    queuepos = 0;
                }

                cur_addr += wi * 2;
            }
            break;
        }

        case 1:
        {
            // 4 bpp LUT mode
            u16 temp;
            u32 colorLut = cmd->CMDCOLR * 8;
            int i, j;

            for(i = 0; i < cur_spr.h; ++i)  {
                store_queue = (uint32 *) (0xE0000000 |
                                          (cur_addr & 0x03FFFFE0));

                for(j = 0; j < cur_spr.w; j += 2)    {
                    dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);

                    if(((dot & 0xF) == 0) && !SPD) dot2 = 0;
                    else    {
                        temp = T1ReadWord(Vdp1Ram, ((dot & 0xF) * 2 +
                                                    colorLut) & 0x7FFFF);

                        if(temp & 0x8000)
                            dot2 = COLOR_ADD(SAT2YAB1(temp), vdp1cor, vdp1cog,
                                             vdp1cob);
                        else
                            dot2 = COLOR_ADD(Vdp2ColorRamGetColor(temp),
                                             vdp1cor, vdp1cog, vdp1cob);
                    }

                    if(((dot >> 4) == 0) && !SPD)  dot = 0;
                    else    {
                        temp = T1ReadWord(Vdp1Ram, ((dot >> 4) * 2 + colorLut) &
                                          0x7FFFF);
                        if (temp & 0x8000)
                            dot = COLOR_ADD(SAT2YAB1(temp), vdp1cor, vdp1cog,
                                            vdp1cob);
                        else
                            dot = COLOR_ADD(Vdp2ColorRamGetColor(temp), vdp1cor,
                                            vdp1cog, vdp1cob);
                    }

                    ++charAddr;

                    store_queue[queuepos++] = dot | (dot2 << 16);

                    if(queuepos == 8)   {
                        asm("pref @%0" : : "r"(store_queue));
                        queuepos = 0;
                        store_queue += 8;
                    }
                }

                if(queuepos)    {
                    asm("pref @%0" : : "r"(store_queue));
                    queuepos = 0;
                }

                cur_addr += wi * 2;
            }
            break;
        }

        case 2:
        {
            // 8 bpp (64 color) Bank mode
            int i, j;
            u32 colorBank = cmd->CMDCOLR;
            u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
            u16 temp;

            for(i = 0; i < cur_spr.h; ++i)  {
                store_queue = (uint32 *) (0xE0000000 |
                                          (cur_addr & 0x03FFFFE0));

                for(j = 0; j < cur_spr.w; j += 2)  {
                    dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF) & 0x3F;
                    dot2 = T1ReadByte(Vdp1Ram, (charAddr + 1) & 0x7FFFF) & 0x3F;
                    charAddr = charAddr + 2;

                    if(dot || SPD)  {
                        temp = Vdp2ColorRamGetColor((dot | colorBank) +
                                                    colorOffset);
                        dot = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    if(dot2 || SPD) {
                        temp = Vdp2ColorRamGetColor((dot2 | colorBank) +
                                                    colorOffset);
                        dot2 = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    store_queue[queuepos++] = dot | (dot2 << 16);

                    if(queuepos == 8)   {
                        asm("pref @%0" : : "r"(store_queue));
                        queuepos = 0;
                        store_queue += 8;
                    }
                }

                if(queuepos)    {
                    asm("pref @%0" : : "r"(store_queue));
                    queuepos = 0;
                }

                cur_addr += wi * 2;
            }
            break;
        }

        case 3:
        {
            // 8 bpp (128 color) Bank mode
            int i, j;
            u32 colorBank = cmd->CMDCOLR;
            u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
            u16 temp;

            for(i = 0; i < cur_spr.h; ++i)  {
                store_queue = (uint32 *) (0xE0000000 |
                                          (cur_addr & 0x03FFFFE0));

                for(j = 0; j < cur_spr.w; j += 2)  {
                    dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF) & 0x7F;
                    dot2 = T1ReadByte(Vdp1Ram, (charAddr + 1) & 0x7FFFF) & 0x7F;
                    charAddr = charAddr + 2;

                    if(dot || SPD)  {
                        temp = Vdp2ColorRamGetColor((dot | colorBank) +
                                                    colorOffset);
                        dot = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    if(dot2 || SPD) {
                        temp = Vdp2ColorRamGetColor((dot2 | colorBank) +
                                                    colorOffset);
                        dot2 = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    store_queue[queuepos++] = dot | (dot2 << 16);

                    if(queuepos == 8)   {
                        asm("pref @%0" : : "r"(store_queue));
                        queuepos = 0;
                        store_queue += 8;
                    }
                }

                if(queuepos)    {
                    asm("pref @%0" : : "r"(store_queue));
                    queuepos = 0;
                }

                cur_addr += wi * 2;
            }
            break;
        }

        case 4:
        {
            // 8 bpp (256 color) Bank mode
            int i, j;
            u32 colorBank = cmd->CMDCOLR;
            u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
            u16 temp;

            for(i = 0; i < cur_spr.h; ++i)  {
                store_queue = (uint32 *) (0xE0000000 |
                                          (cur_addr & 0x03FFFFE0));

                for(j = 0; j < cur_spr.w; j += 2)  {
                    dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);
                    dot2 = T1ReadByte(Vdp1Ram, (charAddr + 1) & 0x7FFFF);
                    charAddr = charAddr + 2;

                    if(dot || SPD)  {
                        temp = Vdp2ColorRamGetColor((dot | colorBank) +
                                                    colorOffset);
                        dot = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    if(dot2 || SPD) {
                        temp = Vdp2ColorRamGetColor((dot2 | colorBank) +
                                                    colorOffset);
                        dot2 = COLOR_ADD(temp, vdp1cor, vdp1cog, vdp1cob);
                    }

                    store_queue[queuepos++] = dot | (dot2 << 16);

                    if(queuepos == 8)   {
                        asm("pref @%0" : : "r"(store_queue));
                        queuepos = 0;
                        store_queue += 8;
                    }
                }

                if(queuepos)    {
                    asm("pref @%0" : : "r"(store_queue));
                    queuepos = 0;
                }

                cur_addr += wi * 2;
            }
            break;
        }

        case 5:
        {
            // 16 bpp Bank mode
            int i, j;

            for(i = 0; i < cur_spr.h; ++i)  {
                store_queue = (uint32 *) (0xE0000000 |
                                          (cur_addr & 0x03FFFFE0));

                for(j = 0; j < cur_spr.w; j += 2)  {
                    dot = T1ReadWord(Vdp1Ram, charAddr & 0x7FFFF);
                    dot2 = T1ReadWord(Vdp1Ram, (charAddr + 2) & 0x7FFFF);
                    charAddr = charAddr + 4;

                    if(dot || SPD)
                        dot = COLOR_ADD(SAT2YAB1(dot), vdp1cor, vdp1cog,
                                        vdp1cob);

                    if(dot2 || SPD)
                        dot2 = COLOR_ADD(SAT2YAB1(dot2), vdp1cor, vdp1cog,
                                         vdp1cob);

                    store_queue[queuepos++] = dot | (dot2 << 16);

                    if(queuepos == 8)   {
                        asm("pref @%0" : : "r"(store_queue));
                        queuepos = 0;
                        store_queue += 8;
                    }
                }

                if(queuepos)    {
                    asm("pref @%0" : : "r"(store_queue));
                    queuepos = 0;
                }

                cur_addr += wi * 2;
            }
            break;
        }

        default:
            VDP1LOG("Unimplemented sprite color mode: %X\n",
                    (cmd->CMDPMOD >> 3) & 0x7);
            return 0;
    }

    if(cached_spr < 1023)    {
        cache[cached_spr].vdp1_base = cmd->CMDSRCA << 3;
        cache[cached_spr].pvr_base = cur_base;
        cache[cached_spr].w = cur_spr.w;
        cache[cached_spr].h = cur_spr.h;

        cached_spr++;
    }

fillHeader:

    cur_spr.uf = (float) cur_spr.w / wi;
    cur_spr.vf = (float) cur_spr.h / he;

    hdr->mode2 &= (~(PVR_TA_PM2_USIZE_MASK | PVR_TA_PM2_VSIZE_MASK));

    switch (wi) {
        case 8:     break;
        case 16:    hdr->mode2 |= (1 << PVR_TA_PM2_USIZE_SHIFT); break;
        case 32:    hdr->mode2 |= (2 << PVR_TA_PM2_USIZE_SHIFT); break;
        case 64:    hdr->mode2 |= (3 << PVR_TA_PM2_USIZE_SHIFT); break;
        case 128:   hdr->mode2 |= (4 << PVR_TA_PM2_USIZE_SHIFT); break;
        case 256:   hdr->mode2 |= (5 << PVR_TA_PM2_USIZE_SHIFT); break;
        case 512:   hdr->mode2 |= (6 << PVR_TA_PM2_USIZE_SHIFT); break;
        case 1024:  hdr->mode2 |= (7 << PVR_TA_PM2_USIZE_SHIFT); break;
        default:    assert_msg(0, "Invalid texture U size"); break;
    }

    switch (he) {
        case 8:     break;
        case 16:    hdr->mode2 |= (1 << PVR_TA_PM2_VSIZE_SHIFT); break;
        case 32:    hdr->mode2 |= (2 << PVR_TA_PM2_VSIZE_SHIFT); break;
        case 64:    hdr->mode2 |= (3 << PVR_TA_PM2_VSIZE_SHIFT); break;
        case 128:   hdr->mode2 |= (4 << PVR_TA_PM2_VSIZE_SHIFT); break;
        case 256:   hdr->mode2 |= (5 << PVR_TA_PM2_VSIZE_SHIFT); break;
        case 512:   hdr->mode2 |= (6 << PVR_TA_PM2_VSIZE_SHIFT); break;
        case 1024:  hdr->mode2 |= (7 << PVR_TA_PM2_VSIZE_SHIFT); break;
        default:    assert_msg(0, "Invalid texture V size"); break;
    }

    hdr->mode3 = ((cur_base & 0x00FFFFF8) >> 3) | (PVR_TXRFMT_NONTWIDDLED);

    /* Make sure everything is aligned nicely... */
    cur_addr = (cur_addr & 0x03FFFFE0) + 0x20;

    return 1;
}

static u8 Vdp1ReadPriority(vdp1cmd_struct *cmd) {
    u8 SPCLMD = Vdp2Regs->SPCTL;
    u8 sprite_register;
    u8 *sprprilist = (u8 *)&Vdp2Regs->PRISA;

    if ((SPCLMD & 0x20) && (cmd->CMDCOLR & 0x8000)) {
        // RGB data, use register 0
        return Vdp2Regs->PRISA & 0x07;
    }
    else    {
        u8 sprite_type = SPCLMD & 0x0F;
        switch(sprite_type) {
            case 0:
                sprite_register = ((cmd->CMDCOLR & 0x8000) |
                                   (~cmd->CMDCOLR & 0x4000)) >> 14;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            case 1:
                sprite_register = ((cmd->CMDCOLR & 0xC000) |
                                   (~cmd->CMDCOLR & 0x2000)) >> 13;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            case 3:
                sprite_register = ((cmd->CMDCOLR & 0x4000) |
                                   (~cmd->CMDCOLR & 0x2000)) >> 13;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            case 4:
                sprite_register = ((cmd->CMDCOLR & 0x4000) |
                                   (~cmd->CMDCOLR & 0x2000)) >> 13;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            case 5:
                sprite_register = ((cmd->CMDCOLR & 0x6000) |
                                   (~cmd->CMDCOLR & 0x1000)) >> 12;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            case 6:
                sprite_register = ((cmd->CMDCOLR & 0x6000) |
                                   (~cmd->CMDCOLR & 0x1000)) >> 12;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            case 7:
                sprite_register = ((cmd->CMDCOLR & 0x6000) |
                                   (~cmd->CMDCOLR & 0x1000)) >> 12;
                return sprprilist[sprite_register ^ 1] & 0x07;
                break;
            default:
                VDP1LOG("sprite type %d not implemented\n", sprite_type);
                return 0x07;
                break;
        }
    }
}

/* This has all been imported from the vidsoft.c file. It will be updated,
   hopefully (roughly) synchronized with updates to it */

//////////////////////////////////////////////////////////////////////////////

typedef struct
{
    int xstart, ystart;
    int xend, yend;
    int pixeloffset;
    int lineincrement;
} clipping_struct;

static void inline HandleClipping(vdp2draw_struct *info, clipping_struct *clip)
{
    clip->pixeloffset=0;
    clip->lineincrement=0;

    // Handle clipping(both window and screen clipping)
    if (info->x < 0)
    {
        clip->xstart = 0;
        clip->xend = (info->x+info->cellw);
        clip->pixeloffset = 0 - info->x;
        clip->lineincrement = 0 - info->x;
    }
    else
    {
        clip->xstart = info->x;

        if ((info->x+info->cellw) > vdp2width)
        {
            clip->xend = vdp2width;
            clip->lineincrement = (info->x+info->cellw) - vdp2width;
        }
        else
            clip->xend = (info->x+info->cellw);
    }

    if (info->y < 0)
    {
        clip->ystart = 0;
        clip->yend = (info->y+info->cellh);
        clip->pixeloffset =  (info->cellw * (0 - info->y)) + clip->pixeloffset;
    }
    else
    {
        clip->ystart = info->y;

        if ((info->y+info->cellh) >= vdp2height)
            clip->yend = vdp2height;
        else
            clip->yend = (info->y+info->cellh);
    }
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DrawScrollBitmap(vdp2draw_struct *info)
{
    int i, i2;
    clipping_struct clip;

    HandleClipping(info, &clip);

    switch (info->colornumber)
    {
        case 0: // 4 BPP(16 colors)
                // fix me
            printf("vdp2 bitmap 4 bpp draw\n");
            return;
        case 1: // 8 BPP(256 colors)
            info->charaddr += clip.pixeloffset;

            for (i = clip.ystart; i < clip.yend; i++)
            {
                for (i2 = clip.xstart; i2 < clip.xend; i2++)
                {
                    u16 color = T1ReadByte(Vdp2Ram, info->charaddr);
                    info->charaddr++;

                    if (color == 0 && info->transparencyenable) {
                        vdp2putpixel(i2, i, 0, info->priority);
                    }
                    else    {
                        color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | color));
                        vdp2putpixel(i2, i, info->PostPixelFetchCalc(info, color) | 0x8000, info->priority);
                    }
                }

                info->charaddr += clip.lineincrement;
            }

            return;
        case 2:
            printf("vdp2 bitmap 16bpp palette draw\n");
            break;
        case 3: // 15 BPP
            clip.pixeloffset *= 2;
            clip.lineincrement *= 2;

            info->charaddr += clip.pixeloffset;

            for (i = clip.ystart; i < clip.yend; i++)
            {
                for (i2 = clip.xstart; i2 < clip.xend; i2++)
                {
                    u16 color = T1ReadWord(Vdp2Ram, info->charaddr);
                    info->charaddr += 2;

                    if ((color & 0x8000) == 0 && info->transparencyenable)
                        vdp2_fb[(i * vdp2width) + i2] = 0;
                    else
                        vdp2_fb[(i * vdp2width) + i2] = info->PostPixelFetchCalc(info, SAT2YAB1(color)) | 0x8000;

                    vdp2_prio[i][i2] = info->priority;
                }

                info->charaddr += clip.lineincrement;
            }

            return;
        case 4: // 24 BPP
            clip.pixeloffset *= 4;
            clip.lineincrement *= 4;

            info->charaddr += clip.pixeloffset;

            for (i = clip.ystart; i < clip.yend; i++)
            {
                for (i2 = clip.xstart; i2 < clip.xend; i2++)
                {
                    u32 color = T1ReadLong(Vdp2Ram, info->charaddr);
                    info->charaddr += 4;

                    if ((color & 0x80000000) == 0 && info->transparencyenable)
                        vdp2putpixel(i2, i, 0, info->priority);
                    else    {
                        u16 dot = ((color & 0xF80000) >> 19 |
                                   (color & 0x00F800) >> 6 |
                                   (color & 0x0000F8) << 7 | 0x8000);
                        vdp2putpixel(i2, i, info->PostPixelFetchCalc(info, dot), info->priority);
                    }
                }

                info->charaddr += clip.lineincrement;

            }
            return;
        default: break;
    }
}

//////////////////////////////////////////////////////////////////////////////

#define Vdp2DrawCell4bpp(mask, shift) \
    if ((dot & mask) == 0 && info->transparencyenable) { \
        vdp2putpixel(i2, i, 0, info->priority); \
    } \
    else \
    { \
        color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | ((dot & mask) >> shift))); \
        vdp2putpixel(i2, i, info->PostPixelFetchCalc(info, color), info->priority); \
    }

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawCell(vdp2draw_struct *info)
{
    u32 color;
    int i, i2;
    clipping_struct clip;
    u32 newcharaddr;

    HandleClipping(info, &clip);

    if (info->flipfunction & 0x1)
    {
        // Horizontal flip
    }

    if (info->flipfunction & 0x2)
    {
        // Vertical flip
        //      clip.pixeloffset = (info.w * info.h) - clip.pixeloffset;
        //      clip.lineincrement = 0 - clip.lineincrement;
    }

    switch(info->colornumber)
    {
        case 0: // 4 BPP
            if ((clip.lineincrement | clip.pixeloffset) == 0)
            {
                for (i = clip.ystart; i < clip.yend; i++)
                {
                    u32 dot;
                    u16 color;

                    i2 = clip.xstart;

                    // Fetch Pixel 1/2/3/4/5/6/7/8
                    dot = T1ReadLong(Vdp2Ram, info->charaddr);
                    info->charaddr+=4;

                    // Draw 8 Pixels
                    Vdp2DrawCell4bpp(0xF0000000, 28)
                    i2++;
                    Vdp2DrawCell4bpp(0x0F000000, 24)
                    i2++;
                    Vdp2DrawCell4bpp(0x00F00000, 20)
                    i2++;
                    Vdp2DrawCell4bpp(0x000F0000, 16)
                    i2++;
                    Vdp2DrawCell4bpp(0x0000F000, 12)
                    i2++;
                    Vdp2DrawCell4bpp(0x00000F00, 8)
                    i2++;
                    Vdp2DrawCell4bpp(0x000000F0, 4)
                    i2++;
                    Vdp2DrawCell4bpp(0x0000000F, 0)
                    i2++;
                }
            }
            else
            {
                u8 dot;

                newcharaddr = info->charaddr + ((info->cellw * info->cellh) >> 1);

                info->charaddr <<= 1;
                info->charaddr += clip.pixeloffset;

                for (i = clip.ystart; i < clip.yend; i++)
                {
                    dot = T1ReadByte(Vdp2Ram, info->charaddr >> 1);
                    info->charaddr++;

                    for (i2 = clip.xstart; i2 < clip.xend; i2++)
                    {
                        u32 color;

                        // Draw two pixels
                        if(info->charaddr & 0x1)
                        {
                            Vdp2DrawCell4bpp(0xF0, 4)
                            info->charaddr++;
                        }
                        else
                        {
                            Vdp2DrawCell4bpp(0x0F, 0)
                            dot = T1ReadByte(Vdp2Ram, info->charaddr >> 1);
                            info->charaddr++;
                        }
                    }
                    info->charaddr += clip.lineincrement;
                }

                info->charaddr = newcharaddr;
            }
            break;
        case 1: // 8 BPP
            newcharaddr = info->charaddr + (info->cellw * info->cellh);
            info->charaddr += clip.pixeloffset;

            for (i = clip.ystart; i < clip.yend; i++)
            {
                for (i2 = clip.xstart; i2 < clip.xend; i2++)
                {
                    u16 color = T1ReadByte(Vdp2Ram, info->charaddr);
                    info->charaddr++;

                    if (color == 0 && info->transparencyenable) {
                        vdp2putpixel(i2, i, 0, info->priority);
                    }
                    else    {
                        color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | color));
                        vdp2putpixel(i2, i, info->PostPixelFetchCalc(info, color), info->priority);
                    }
                }

                info->charaddr += clip.lineincrement;
            }

            info->charaddr = newcharaddr;

            break;
        case 2: // 16 BPP(palette)
            printf("vdp2 cell draw 16bpp palette\n");
            break;

        case 3: // 16 BPP(RGB)
            printf("vdp2 cell draw 16bpp\n");
            break;
        case 4: // 32 BPP
            newcharaddr = info->charaddr + (info->cellw * info->cellh);
            info->charaddr += clip.pixeloffset;

            for (i = clip.ystart; i < clip.yend; i++)
            {
                for (i2 = clip.xstart; i2 < clip.xend; i2++)
                {
                    u16 dot1, dot2;
                    dot1 = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);
                    info->charaddr += 2;
                    dot2 = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);
                    info->charaddr += 2;

                    if (!(dot1 & 0x8000) && info->transparencyenable)
                        continue;

                    color = SAT2YAB2(dot1, dot2);
                    vdp2putpixel(i2, i, info->PostPixelFetchCalc(info, color), info->priority);
                }

                info->charaddr += clip.lineincrement;
            }

                info->charaddr = newcharaddr;

            break;
    }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawPattern(vdp2draw_struct *info)
{
    //   if (info->specialprimode == 1)
    //      tile.priority = (info->priority & 0xFFFFFFFE) | info->specialfunction;
    //   else
    //      tile.priority = info->priority;

    switch(info->patternwh)
    {
        case 1:
            Vdp2DrawCell(info);
            info->x += 8;
            info->y += 8;
            break;
        case 2:
            Vdp2DrawCell(info);
            info->x += 8;
            Vdp2DrawCell(info);
            info->x -= 8;
            info->y += 8;
            Vdp2DrawCell(info);
            info->x += 8;
            Vdp2DrawCell(info);
            info->x += 8;
            info->y += 8;
            break;
    }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2PatternAddr(vdp2draw_struct *info)
{
    switch(info->patterndatasize)
    {
        case 1:
        {
            u16 tmp = T1ReadWord(Vdp2Ram, info->addr);

            info->addr += 2;
            info->specialfunction = (info->supplementdata >> 9) & 0x1;

            switch(info->colornumber)
            {
                case 0: // in 16 colors
                    info->paladdr = ((tmp & 0xF000) >> 8) | ((info->supplementdata & 0xE0) << 3);
                    break;
                default: // not in 16 colors
                    info->paladdr = (tmp & 0x7000) >> 4;
                    break;
            }

            switch(info->auxmode)
            {
                case 0:
                    info->flipfunction = (tmp & 0xC00) >> 10;

                    switch(info->patternwh)
                    {
                        case 1:
                            info->charaddr = (tmp & 0x3FF) | ((info->supplementdata & 0x1F) << 10);
                            break;
                        case 2:
                            info->charaddr = ((tmp & 0x3FF) << 2) | (info->supplementdata & 0x3) | ((info->supplementdata & 0x1C) << 10);
                            break;
                    }
                    break;
                case 1:
                    info->flipfunction = 0;

                    switch(info->patternwh)
                    {
                        case 1:
                            info->charaddr = (tmp & 0xFFF) | ((info->supplementdata & 0x1C) << 10);
                            break;
                        case 2:
                            info->charaddr = ((tmp & 0xFFF) << 2) | (info->supplementdata & 0x3) | ((info->supplementdata & 0x10) << 10);
                            break;
                    }
                        break;
            }

            break;
        }
        case 2: {
            u16 tmp1 = T1ReadWord(Vdp2Ram, info->addr);
            u16 tmp2 = T1ReadWord(Vdp2Ram, info->addr+2);
            info->addr += 4;
            info->charaddr = tmp2 & 0x7FFF;
            info->flipfunction = (tmp1 & 0xC000) >> 14;
            info->paladdr = (tmp1 & 0x7F) << 4;
            info->specialfunction = (tmp1 & 0x2000) >> 13;
            break;
        }
    }

    if (!(Vdp2Regs->VRSIZE & 0x8000))
        info->charaddr &= 0x3FFF;

    info->charaddr *= 0x20; // selon Runik
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawPage(vdp2draw_struct *info)
{
    int X, Y;
    int i, j;

    X = info->x;
    for(i = 0;i < info->pagewh;i++)
    {
        Y = info->y;
        info->x = X;
        for(j = 0;j < info->pagewh;j++)
        {
            info->y = Y;
            if ((info->x >= -info->patternpixelwh) &&
                (info->y >= -info->patternpixelwh) &&
                (info->x <= info->draww) &&
                (info->y <= info->drawh))
            {
                Vdp2PatternAddr(info);
                Vdp2DrawPattern(info);
            }
            else
            {
                info->addr += info->patterndatasize * 2;
                info->x += info->patternpixelwh;
                info->y += info->patternpixelwh;
            }
        }
    }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawPlane(vdp2draw_struct *info)
{
    int X, Y;
    int i, j;

    X = info->x;
    for(i = 0;i < info->planeh;i++)
    {
        Y = info->y;
        info->x = X;
        for(j = 0;j < info->planew;j++)
        {
            info->y = Y;
            Vdp2DrawPage(info);
        }
    }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawMap(vdp2draw_struct *info)
{
    int i, j;
    int X, Y;
    u32 lastplane;

    X = info->x;
    lastplane=0xFFFFFFFF;

    info->patternpixelwh = 8 * info->patternwh;
    info->draww = (int)((float)vdp2width / info->coordincx);
    info->drawh = (int)((float)vdp2height / info->coordincy);

    for(i = 0;i < info->mapwh;i++)
    {
        Y = info->y;
        info->x = X;
        for(j = 0;j < info->mapwh;j++)
        {
            info->y = Y;
            info->PlaneAddr(info, info->mapwh * i + j);
            if (info->addr != lastplane)
            {
                Vdp2DrawPlane(info);
                lastplane = info->addr;
            }
        }
    }
}

static int VIDDCInit(void)  {
    pvr_sprite_cxt_t op_poly_cxt, tr_poly_cxt;
    pvr_sprite_cxt_t pt_sprite_cxt, tr_sprite_cxt;

    vid_set_mode(DM_320x240, PM_RGB565);

    if(pvr_init(&pvr_params))   {
        fprintf(stderr, "VIDDCInit() - error initializing PVR\n");
        return -1;
    }

    pvr_set_vertbuf(PVR_LIST_OP_POLY, vbuf_opaque, 1024 * 256);
    pvr_set_vertbuf(PVR_LIST_TR_POLY, vbuf_translucent, 1024 * 256);
    pvr_set_vertbuf(PVR_LIST_PT_POLY, vbuf_punchthru, 1024 * 256);

    tex_space = pvr_mem_malloc(1024 * 1024 * 2);
    vdp2_tex = pvr_mem_malloc(512 * 256 * 4 * 2);
    cur_addr = (uint32)tex_space;

    printf("PVR Memory Available: %lu\n", pvr_mem_available());

    sq_set(tex_space, 0xFF, 1024 * 1024 * 2);

    pvr_sprite_cxt_col(&op_poly_cxt, PVR_LIST_OP_POLY);
    pvr_sprite_cxt_col(&tr_poly_cxt, PVR_LIST_TR_POLY);

    op_poly_cxt.gen.culling = PVR_CULLING_NONE;
    tr_poly_cxt.gen.culling = PVR_CULLING_NONE;

    pvr_sprite_compile(&op_poly_hdr, &op_poly_cxt);
    pvr_sprite_compile(&tr_poly_hdr, &tr_poly_cxt);

    pvr_sprite_cxt_txr(&tr_sprite_cxt, PVR_LIST_TR_POLY, PVR_TXRFMT_ARGB1555 |
                       PVR_TXRFMT_NONTWIDDLED, 1024, 1024, tex_space,
                       PVR_FILTER_NONE);
    pvr_sprite_cxt_txr(&pt_sprite_cxt, PVR_LIST_PT_POLY, PVR_TXRFMT_ARGB1555 |
                       PVR_TXRFMT_NONTWIDDLED, 1024, 1024, tex_space,
                       PVR_FILTER_NONE);

    pt_sprite_cxt.gen.culling = PVR_CULLING_NONE;
    tr_sprite_cxt.gen.culling = PVR_CULLING_NONE;

    pvr_sprite_compile(&tr_sprite_hdr, &tr_sprite_cxt);
    pvr_sprite_compile(&pt_sprite_hdr, &pt_sprite_cxt);

    tr_sprite_hdr.argb = PVR_PACK_COLOR(0.5f, 1.0f, 1.0f, 1.0f);

    priority_levels[0] = 0.0f;
    priority_levels[1] = 1.0f;
    priority_levels[2] = 2.0f;
    priority_levels[3] = 3.0f;
    priority_levels[4] = 4.0f;
    priority_levels[5] = 5.0f;
    priority_levels[6] = 6.0f;
    priority_levels[7] = 7.0f;

    framecount = 0;
    lastup = time(NULL);

    return 0;
}

static void VIDDCDeInit(void)   {
    pvr_set_vertbuf(PVR_LIST_OP_POLY, NULL, 0);
    pvr_set_vertbuf(PVR_LIST_TR_POLY, NULL, 0);
    pvr_set_vertbuf(PVR_LIST_PT_POLY, NULL, 0);

    pvr_mem_free(tex_space);
    sem_destroy(&dmadone);

    pvr_shutdown();
    vid_set_mode(DM_640x480, PM_RGB565);
}

static void VIDDCResize(unsigned int w, unsigned int h, int unused) {
}

static int VIDDCIsFullscreen(void)  {
    return 1;
}

static int VIDDCVdp1Reset(void) {
    return 0;
}

static void VIDDCVdp1DrawStart(void)    {
    if(Vdp2Regs->CLOFEN & 0x40)    {
        // color offset enable
        if(Vdp2Regs->CLOFSL & 0x40)    {
            // color offset B
            vdp1cor = Vdp2Regs->COBR & 0xFF;
            if(Vdp2Regs->COBR & 0x100)
                vdp1cor |= 0xFFFFFF00;

            vdp1cog = Vdp2Regs->COBG & 0xFF;
            if(Vdp2Regs->COBG & 0x100)
                vdp1cog |= 0xFFFFFF00;

            vdp1cob = Vdp2Regs->COBB & 0xFF;
            if(Vdp2Regs->COBB & 0x100)
                vdp1cob |= 0xFFFFFF00;
        }
        else    {
            // color offset A
            vdp1cor = Vdp2Regs->COAR & 0xFF;
            if(Vdp2Regs->COAR & 0x100)
                vdp1cor |= 0xFFFFFF00;

            vdp1cog = Vdp2Regs->COAG & 0xFF;
            if(Vdp2Regs->COAG & 0x100)
                vdp1cog |= 0xFFFFFF00;

            vdp1cob = Vdp2Regs->COAB & 0xFF;
            if(Vdp2Regs->COAB & 0x100)
                vdp1cob |= 0xFFFFFF00;
        }
    }
    else // color offset disable
        vdp1cor = vdp1cog = vdp1cob = 0;
}

static void VIDDCVdp1DrawEnd(void)  {
    cached_spr = 0;
    priority_levels[0] = 0.0f;
    priority_levels[1] = 1.0f;
    priority_levels[2] = 2.0f;
    priority_levels[3] = 3.0f;
    priority_levels[4] = 4.0f;
    priority_levels[5] = 5.0f;
    priority_levels[6] = 6.0f;
    priority_levels[7] = 7.0f;
}

static void VIDDCVdp1NormalSpriteDraw(void) {
    int x, y, num;
    u8 z;
    vdp1cmd_struct cmd;
    pvr_sprite_txr_t sprite;
    pvr_list_t list;

    Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

    x = Vdp1Regs->localX + cmd.CMDXA;
    y = Vdp1Regs->localY + cmd.CMDYA;
    cur_spr.w = ((cmd.CMDSIZE >> 8) & 0x3F) << 3;
    cur_spr.h = cmd.CMDSIZE & 0xFF;

    if ((cmd.CMDPMOD & 0x07) == 0x03) {
        list = PVR_LIST_TR_POLY;
        num = Vdp1ReadTexture(&cmd, &tr_sprite_hdr);

        if(num == 0)
            return;
        else
            pvr_list_prim(PVR_LIST_TR_POLY, &tr_sprite_hdr,
                          sizeof(pvr_sprite_hdr_t));
    }
    else    {
        num = Vdp1ReadTexture(&cmd, &pt_sprite_hdr);
        list = PVR_LIST_PT_POLY;

        if(num == 0)
            return;
        else
            pvr_list_prim(PVR_LIST_PT_POLY, &pt_sprite_hdr,
                          sizeof(pvr_sprite_hdr_t));
    }

    z = Vdp1ReadPriority(&cmd);

    sprite.flags = PVR_CMD_VERTEX_EOL;
    sprite.ax = x;
    sprite.ay = y;
    sprite.az = priority_levels[z];

    sprite.bx = x + cur_spr.w;
    sprite.by = y;
    sprite.bz = priority_levels[z];

    sprite.cx = x + cur_spr.w;
    sprite.cy = y + cur_spr.h;
    sprite.cz = priority_levels[z];

    sprite.dx = x;
    sprite.dy = y + cur_spr.h;

    sprite.auv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? cur_spr.uf : 0.0f),
                                  ((cmd.CMDCTRL & 0x0020) ? cur_spr.vf : 0.0f));
    sprite.buv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? 0.0f : cur_spr.uf),
                                  ((cmd.CMDCTRL & 0x0020) ? cur_spr.vf : 0.0f));
    sprite.cuv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? 0.0f : cur_spr.uf),
                                  ((cmd.CMDCTRL & 0x0020) ? 0.0f : cur_spr.vf));
    pvr_list_prim(list, &sprite, sizeof(sprite));

    priority_levels[z] += 0.000001f;
}

static void VIDDCVdp1ScaledSpriteDraw(void) {
    vdp1cmd_struct cmd;
    s16 rw = 0, rh = 0;
    s16 x, y;
    u8 z;
    pvr_sprite_txr_t sprite;
    pvr_list_t list;
    int num;

    Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

    x = cmd.CMDXA + Vdp1Regs->localX;
    y = cmd.CMDYA + Vdp1Regs->localY;
    cur_spr.w = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
    cur_spr.h = cmd.CMDSIZE & 0xFF;

    if((cmd.CMDPMOD & 0x07) == 0x03)    {
        list = PVR_LIST_TR_POLY;
        num = Vdp1ReadTexture(&cmd, &tr_sprite_hdr);

        if(num == 0)
            return;
        else
            pvr_list_prim(PVR_LIST_TR_POLY, &tr_sprite_hdr,
                          sizeof(pvr_sprite_hdr_t));
    }
    else    {
        num = Vdp1ReadTexture(&cmd, &pt_sprite_hdr);
        list = PVR_LIST_PT_POLY;

        if(num == 0)
            return;
        else
            pvr_list_prim(PVR_LIST_PT_POLY, &pt_sprite_hdr,
                          sizeof(pvr_sprite_hdr_t));
    }

    // Setup Zoom Point
    switch ((cmd.CMDCTRL & 0xF00) >> 8) {
        case 0x0: // Only two coordinates
            rw = cmd.CMDXC - x + Vdp1Regs->localX + 1;
            rh = cmd.CMDYC - y + Vdp1Regs->localY + 1;
            break;
        case 0x5: // Upper-left
            rw = cmd.CMDXB + 1;
            rh = cmd.CMDYB + 1;
            break;
        case 0x6: // Upper-Center
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            x = x - rw / 2;
            ++rw;
            ++rh;
            break;
        case 0x7: // Upper-Right
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            x = x - rw;
            ++rw;
            ++rh;
            break;
        case 0x9: // Center-left
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            y = y - rh / 2;
            ++rw;
            ++rh;
            break;
        case 0xA: // Center-center
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            x = x - rw / 2;
            y = y - rh / 2;
            ++rw;
            ++rh;
            break;
        case 0xB: // Center-right
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            x = x - rw;
            y = y - rh / 2;
            ++rw;
            ++rh;
            break;
        case 0xD: // Lower-left
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            y = y - rh;
            ++rw;
            ++rh;
            break;
        case 0xE: // Lower-center
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            x = x - rw / 2;
            y = y - rh;
            ++rw;
            ++rh;
            break;
        case 0xF: // Lower-right
            rw = cmd.CMDXB;
            rh = cmd.CMDYB;
            x = x - rw;
            y = y - rh;
            ++rw;
            ++rh;
            break;
        default:
            break;
    }

    z = Vdp1ReadPriority(&cmd);

    sprite.flags = PVR_CMD_VERTEX_EOL;
    sprite.ax = x;
    sprite.ay = y;
    sprite.az = priority_levels[z];

    sprite.bx = x + rw;
    sprite.by = y;
    sprite.bz = priority_levels[z];

    sprite.cx = x + rw;
    sprite.cy = y + rh;
    sprite.cz = priority_levels[z];

    sprite.dx = x;
    sprite.dy = y + rh;

    sprite.auv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? cur_spr.uf : 0.0f),
                                  ((cmd.CMDCTRL & 0x0020) ? cur_spr.vf : 0.0f));
    sprite.buv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? 0.0f : cur_spr.uf),
                                  ((cmd.CMDCTRL & 0x0020) ? cur_spr.vf : 0.0f));
    sprite.cuv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? 0.0f : cur_spr.uf),
                                  ((cmd.CMDCTRL & 0x0020) ? 0.0f : cur_spr.vf));
    pvr_list_prim(list, &sprite, sizeof(sprite));

    priority_levels[z] += 0.000001f;
}

static void VIDDCVdp1DistortedSpriteDraw(void)  {
    vdp1cmd_struct cmd;
    u8 z;
    pvr_sprite_txr_t sprite;
    pvr_list_t list;
    int num;

    Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

    cur_spr.w = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
    cur_spr.h = cmd.CMDSIZE & 0xFF;

    if((cmd.CMDPMOD & 0x7) == 0x3) {
        list = PVR_LIST_TR_POLY;
        num = Vdp1ReadTexture(&cmd, &tr_sprite_hdr);

        if(num == 0)
            return;
        else
            pvr_list_prim(PVR_LIST_TR_POLY, &tr_sprite_hdr,
                          sizeof(pvr_sprite_hdr_t));
    }
    else    {
        num = Vdp1ReadTexture(&cmd, &pt_sprite_hdr);
        list = PVR_LIST_PT_POLY;

        if(num == 0)
            return;
        else
            pvr_list_prim(PVR_LIST_PT_POLY, &pt_sprite_hdr,
                          sizeof(pvr_sprite_hdr_t));
    }

    z = Vdp1ReadPriority(&cmd);

    sprite.flags = PVR_CMD_VERTEX_EOL;
    sprite.ax = cmd.CMDXA + Vdp1Regs->localX;
    sprite.ay = cmd.CMDYA + Vdp1Regs->localY;
    sprite.az = priority_levels[z];

    sprite.bx = cmd.CMDXB + Vdp1Regs->localX + 1;
    sprite.by = cmd.CMDYB + Vdp1Regs->localY;
    sprite.bz = priority_levels[z];

    sprite.cx = cmd.CMDXC + Vdp1Regs->localX + 1;
    sprite.cy = cmd.CMDYC + Vdp1Regs->localY + 1;
    sprite.cz = priority_levels[z];

    sprite.dx = cmd.CMDXD + Vdp1Regs->localX;
    sprite.dy = cmd.CMDYD + Vdp1Regs->localY + 1;

    sprite.auv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? cur_spr.uf : 0.0f),
                                  ((cmd.CMDCTRL & 0x0020) ? cur_spr.vf : 0.0f));
    sprite.buv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? 0.0f : cur_spr.uf),
                                  ((cmd.CMDCTRL & 0x0020) ? cur_spr.vf : 0.0f));
    sprite.cuv = PVR_PACK_16BIT_UV(((cmd.CMDCTRL & 0x0010) ? 0.0f : cur_spr.uf),
                                  ((cmd.CMDCTRL & 0x0020) ? 0.0f : cur_spr.vf));
    pvr_list_prim(list, &sprite, sizeof(sprite));

    priority_levels[z] += 0.000001f;
}

static void VIDDCVdp1PolygonDraw(void)  {
    s16 X[4];
    s16 Y[4];
    u16 color;
    u16 CMDPMOD;
    u8 alpha, z;
    pvr_list_t list;
    pvr_sprite_col_t spr;
    pvr_sprite_hdr_t *hdr;

    X[0] = Vdp1Regs->localX + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C);
    Y[0] = Vdp1Regs->localY + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E);
    X[1] = Vdp1Regs->localX + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x10);
    Y[1] = Vdp1Regs->localY + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12);
    X[2] = Vdp1Regs->localX + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
    Y[2] = Vdp1Regs->localY + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);
    X[3] = Vdp1Regs->localX + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x18);
    Y[3] = Vdp1Regs->localY + T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1A);

    color = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x06);
    CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x04);

    /* Don't bother rendering completely transparent polygons */
    if((!(color & 0x8000) && !(CMDPMOD & 0x0040)) || !color)    {
        return;
    }

    if((CMDPMOD & 0x0007) == 0x0003)    {
        alpha = 0x80;
        list = PVR_LIST_TR_POLY;
        hdr = &tr_poly_hdr;
    }
    else    {
        alpha = 0xFF;
        list = PVR_LIST_OP_POLY;
        hdr = &op_poly_hdr;
    }

    if(color & 0x8000)  {
        hdr->argb = COLOR_ADD32(SAT2YAB32(alpha, color), vdp1cor, vdp1cog,
                                vdp1cob);
    }
    else    {
        hdr->argb = COLOR_ADD32(Vdp2ColorRamGetColor32(color, alpha), vdp1cor,
                                vdp1cog, vdp1cob);
    }

    pvr_list_prim(list, hdr, sizeof(pvr_sprite_hdr_t));

    z = Vdp2Regs->PRISA & 0x07;

    spr.flags = PVR_CMD_VERTEX_EOL;
    spr.d1 = spr.d2 = spr.d3 = spr.d4 = 0;
    spr.az = spr.bz = spr.cz = priority_levels[z];

    spr.ax = X[0];
    spr.ay = Y[0];
    spr.bx = X[1];
    spr.by = Y[1];
    spr.cx = X[2];
    spr.cy = Y[2];
    spr.dx = X[3];
    spr.dy = Y[3];

    pvr_list_prim(list, &spr, sizeof(pvr_sprite_col_t));

    priority_levels[z] += 0.000001f;
}

static void VIDDCVdp1PolylineDraw(void) {
}

static void VIDDCVdp1LineDraw(void) {
}

static void VIDDCVdp1UserClipping(void) {
    Vdp1Regs->userclipX1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C);
    Vdp1Regs->userclipY1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E);
    Vdp1Regs->userclipX2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
    Vdp1Regs->userclipY2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);
}

static void VIDDCVdp1SystemClipping(void)   {
    Vdp1Regs->systemclipX1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C);
    Vdp1Regs->systemclipY1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E);
    Vdp1Regs->systemclipX2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
    Vdp1Regs->systemclipY2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);
}

static void VIDDCVdp1LocalCoordinate(void)  {
    Vdp1Regs->localX = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C);
    Vdp1Regs->localY = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E);
}

//////////////////////////////////////////////////////////////////////////////

static u16 DoNothing(void *info, u16 pixel)
{
    return pixel;
}

//////////////////////////////////////////////////////////////////////////////

static u16 DoColorOffset(void *info, u16 pixel)
{
    return COLOR_ADD(pixel, ((vdp2draw_struct *)info)->cor,
                     ((vdp2draw_struct *)info)->cog,
                     ((vdp2draw_struct *)info)->cob);
}

//////////////////////////////////////////////////////////////////////////////

static u16 DoColorCalc(void *info, u16 pixel)
{
    // should be doing color calculation here
    return pixel;
}

//////////////////////////////////////////////////////////////////////////////

static u16 DoColorCalcWithColorOffset(void *info, u16 pixel)
{
    // should be doing color calculation here

    return COLOR_ADD(pixel, ((vdp2draw_struct *)info)->cor,
                     ((vdp2draw_struct *)info)->cog,
                     ((vdp2draw_struct *)info)->cob);
}

static void Vdp2DrawBackScreen()    {
    u32 scrAddr;
    u16 dot;
    pvr_sprite_col_t spr;

    if(Vdp2Regs->VRSIZE & 0x8000)
        scrAddr = (((Vdp2Regs->BKTAU & 0x07) << 16) | Vdp2Regs->BKTAL) << 1;
    else
        scrAddr = (((Vdp2Regs->BKTAU & 0x03) << 16) | Vdp2Regs->BKTAL) << 1;

    if(Vdp2Regs->BKTAU & 0x8000)    {
        int i;

        for(i = 0; i < vdp2height; ++i)    {
            dot = T1ReadWord(Vdp2Ram, scrAddr);
            scrAddr += 2;

            op_poly_hdr.argb = SAT2YAB32(0xFF, dot);
            pvr_list_prim(PVR_LIST_OP_POLY, &op_poly_hdr,
                          sizeof(pvr_sprite_hdr_t));

            spr.flags = PVR_CMD_VERTEX_EOL;
            spr.ax = 0.0f;
            spr.ay = i + 1;
            spr.az = 0.1f;
            spr.bx = 0.0f;
            spr.by = i;
            spr.bz = 0.1f;
            spr.cx = vdp2width;
            spr.cy = i;
            spr.cz = 0.1f;
            spr.dx = vdp2width;
            spr.dy = i + 1;
            spr.d1 = spr.d2 = spr.d3 = spr.d4 = 0;
            pvr_list_prim(PVR_LIST_OP_POLY, &spr, sizeof(pvr_sprite_col_t));
        }
    }
    else    {
        dot = T1ReadWord(Vdp2Ram, scrAddr);

        op_poly_hdr.argb = SAT2YAB32(0xFF, dot);
        pvr_list_prim(PVR_LIST_OP_POLY, &op_poly_hdr, sizeof(pvr_sprite_hdr_t));

        spr.flags = PVR_CMD_VERTEX_EOL;
        spr.ax = 0.0f;
        spr.ay = vdp2height;
        spr.az = 0.1f;
        spr.bx = 0.0f;
        spr.by = 0.0f;
        spr.bz = 0.1f;
        spr.cx = vdp2width;
        spr.cy = 0.0f;
        spr.cz = 0.1f;
        spr.dx = vdp2width;
        spr.dy = vdp2height;
        spr.d1 = spr.d2 = spr.d3 = spr.d4 = 0;
        pvr_list_prim(PVR_LIST_OP_POLY, &spr, sizeof(pvr_sprite_col_t));
    }
}

static void Vdp2DrawLineColorScreen()   {
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2NBG0PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x7) << 6;
   u32 tmp=0;
   int deca;
   int multi;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN0 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN0 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN0 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN0 >> 8);
         break;
   }

   deca = info->planeh + info->planew - 2;
   multi = info->planeh * info->planew;

   //if (Vdp2Regs->VRSIZE & 0x8000)
   //{
      if (info->patterndatasize == 1)
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x2000);
         else
            info->addr = (tmp >> deca) * (multi * 0x800);
      }
      else
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x1000);
      }
   /*}
   else
   {
      if (info->patterndatasize == 1)
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x2000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x800);
      }
      else
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0xF) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x1000);
      }
   }*/
}

//////////////////////////////////////////////////////////////////////////////

static int Vdp2DrawNBG0(void)
{
   vdp2draw_struct info;

   /* FIXME should start by checking if it's a normal
    * or rotate scroll screen
    */
   info.enable = Vdp2Regs->BGON & 0x1;

   if (!(info.enable & Vdp2External.disptoggle))
       return 0;

   info.transparencyenable = !(Vdp2Regs->BGON & 0x100);
   info.specialprimode = Vdp2Regs->SFPRMD & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLA & 0x70) >> 4;

   if((info.isbitmap = Vdp2Regs->CHCTLA & 0x2) != 0)
   {
      // Bitmap Mode

      switch((Vdp2Regs->CHCTLA & 0xC) >> 2)
      {
         case 0: info.cellw = 512;
                 info.cellh = 256;
                 break;
         case 1: info.cellw = 512;
                 info.cellh = 512;
                 break;
         case 2: info.cellw = 1024;
                 info.cellh = 256;
                 break;
         case 3: info.cellw = 1024;
                 info.cellh = 512;
                 break;
      }

      info.x = - ((Vdp2Regs->SCXIN0 & 0x7FF) % info.cellw);
      info.y = - ((Vdp2Regs->SCYIN0 & 0x7FF) % info.cellh);

      info.charaddr = (Vdp2Regs->MPOFN & 0x7) * 0x20000;
      info.paladdr = (Vdp2Regs->BMPNA & 0x7) << 8;
      info.flipfunction = 0;
      info.specialfunction = 0;
   }
   else
   {
      // Tile Mode
      info.mapwh = 2;

      switch(Vdp2Regs->PLSZ & 0x3)
      {
         case 0:
            info.planew = info.planeh = 1;
            break;
         case 1:
            info.planew = 2;
            info.planeh = 1;
            break;
         case 3:
            info.planew = info.planeh = 2;
            break;
         default: // Not sure what 0x2 does
            info.planew = info.planeh = 1;
            break;
      }

      info.x = - ((Vdp2Regs->SCXIN0 & 0x7FF) % (512 * info.planew));
      info.y = - ((Vdp2Regs->SCYIN0 & 0x7FF) % (512 * info.planeh));

      if(Vdp2Regs->PNCN0 & 0x8000)
         info.patterndatasize = 1;
      else
         info.patterndatasize = 2;

      if(Vdp2Regs->CHCTLA & 0x1)
         info.patternwh = 2;
      else
         info.patternwh = 1;

      info.pagewh = 64/info.patternwh;
      info.cellw = info.cellh = 8;
      info.supplementdata = Vdp2Regs->PNCN0 & 0x3FF;
      info.auxmode = (Vdp2Regs->PNCN0 & 0x4000) >> 14;
   }

   if (Vdp2Regs->CCCTL & 0x1)
      info.alpha = ((~Vdp2Regs->CCRNA & 0x1F) << 3) + 0x7;
   else
      info.alpha = 0xFF;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7) << 8;

   if (Vdp2Regs->CLOFEN & 0x1)
   {
      // color offset enable
      if (Vdp2Regs->CLOFSL & 0x1)
      {
         // color offset B
         info.cor = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            info.cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         info.cor = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            info.cob |= 0xFFFFFF00;
      }

      if (Vdp2Regs->CCCTL & 0x1)
         info.PostPixelFetchCalc = &DoColorCalcWithColorOffset;
      else
         info.PostPixelFetchCalc = &DoColorOffset;
   }
   else // color offset disable
   {
      if (Vdp2Regs->CCCTL & 0x1)
         info.PostPixelFetchCalc = &DoColorCalc;
      else
         info.PostPixelFetchCalc = &DoNothing;
   }

   info.coordincx = (float) 65536 / (Vdp2Regs->ZMXN0.all & 0x7FF00);
   info.coordincy = (float) 65536 / (Vdp2Regs->ZMYN0.all & 0x7FF00);

   info.priority = nbg0priority;
   info.PlaneAddr = (void (*)(void *, int))&Vdp2NBG0PlaneAddr;

   if (info.isbitmap)
      Vdp2DrawScrollBitmap(&info);
   else
      Vdp2DrawMap(&info);

   return 1;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2NBG1PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x70) << 2;
   u32 tmp=0;
   int deca;
   int multi;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN1 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN1 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN1 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN1 >> 8);
         break;
   }

   deca = info->planeh + info->planew - 2;
   multi = info->planeh * info->planew;

   //if (Vdp2Regs->VRSIZE & 0x8000)
   //{
      if (info->patterndatasize == 1)
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x2000);
         else
            info->addr = (tmp >> deca) * (multi * 0x800);
      }
      else
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x1000);
      }
   /*}
   else
   {
      if (info->patterndatasize == 1)
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x2000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x800);
      }
      else
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0xF) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x1000);
      }
   }*/
}

//////////////////////////////////////////////////////////////////////////////

static int Vdp2DrawNBG1(void)
{
   vdp2draw_struct info;

   info.enable = Vdp2Regs->BGON & 0x2;

   if (!(info.enable & Vdp2External.disptoggle))
       return 0;

   info.transparencyenable = !(Vdp2Regs->BGON & 0x200);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 2) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLA & 0x3000) >> 12;

   if((info.isbitmap = Vdp2Regs->CHCTLA & 0x200) != 0)
   {
      switch((Vdp2Regs->CHCTLA & 0xC00) >> 10)
      {
         case 0: info.cellw = 512;
                 info.cellh = 256;
                 break;
         case 1: info.cellw = 512;
                 info.cellh = 512;
                 break;
         case 2: info.cellw = 1024;
                 info.cellh = 256;
                 break;
         case 3: info.cellw = 1024;
                 info.cellh = 512;
                 break;
      }

      info.x = - ((Vdp2Regs->SCXIN1 & 0x7FF) % info.cellw);
      info.y = - ((Vdp2Regs->SCYIN1 & 0x7FF) % info.cellh);

      info.charaddr = ((Vdp2Regs->MPOFN & 0x70) >> 4) * 0x20000;
      info.paladdr = Vdp2Regs->BMPNA & 0x700;
      info.flipfunction = 0;
      info.specialfunction = 0;
   }
   else
   {
      info.mapwh = 2;

      switch((Vdp2Regs->PLSZ & 0xC) >> 2)
      {
         case 0:
            info.planew = info.planeh = 1;
            break;
         case 1:
            info.planew = 2;
            info.planeh = 1;
            break;
         case 3:
            info.planew = info.planeh = 2;
            break;
         default: // Not sure what 0x2 does
            info.planew = info.planeh = 1;
            break;
      }

      info.x = - ((Vdp2Regs->SCXIN1 & 0x7FF) % (512 * info.planew));
      info.y = - ((Vdp2Regs->SCYIN1 & 0x7FF) % (512 * info.planeh));

      if(Vdp2Regs->PNCN1 & 0x8000)
         info.patterndatasize = 1;
      else
         info.patterndatasize = 2;

      if(Vdp2Regs->CHCTLA & 0x100)
         info.patternwh = 2;
      else
         info.patternwh = 1;

      info.pagewh = 64/info.patternwh;
      info.cellw = info.cellh = 8;
      info.supplementdata = Vdp2Regs->PNCN1 & 0x3FF;
      info.auxmode = (Vdp2Regs->PNCN1 & 0x4000) >> 14;
   }

   if (Vdp2Regs->CCCTL & 0x2)
      info.alpha = ((~Vdp2Regs->CCRNA & 0x1F00) >> 5) + 0x7;
   else
      info.alpha = 0xFF;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x70) << 4;

   if (Vdp2Regs->CLOFEN & 0x2)
   {
      // color offset enable
      if (Vdp2Regs->CLOFSL & 0x2)
      {
         // color offset B
         info.cor = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            info.cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         info.cor = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            info.cob |= 0xFFFFFF00;
      }

      if (Vdp2Regs->CCCTL & 0x2)
         info.PostPixelFetchCalc = &DoColorCalcWithColorOffset;
      else
         info.PostPixelFetchCalc = &DoColorOffset;
   }
   else // color offset disable
   {
      if (Vdp2Regs->CCCTL & 0x2)
         info.PostPixelFetchCalc = &DoColorCalc;
      else
         info.PostPixelFetchCalc = &DoNothing;
   }

   info.coordincx = (float) 65536 / (Vdp2Regs->ZMXN1.all & 0x7FF00);
   info.coordincy = (float) 65536 / (Vdp2Regs->ZMXN1.all & 0x7FF00);

   info.priority = nbg1priority;
   info.PlaneAddr = (void (*)(void *, int))&Vdp2NBG1PlaneAddr;

   if (info.isbitmap)
   {
      Vdp2DrawScrollBitmap(&info);
/*
      // Handle Scroll Wrapping(Let's see if we even need do to it to begin
      // with)
      if (info.x < (vdp2width - info.cellw))
      {
         info.vertices[0] = (info.x+info.cellw) * info.coordincx;
         info.vertices[2] = (info.x + (info.cellw<<1)) * info.coordincx;
         info.vertices[4] = (info.x + (info.cellw<<1)) * info.coordincx;
         info.vertices[6] = (info.x+info.cellw) * info.coordincx;

         YglCachedQuad((YglSprite *)&info, tmp);

         if (info.y < (vdp2height - info.cellh))
         {
            info.vertices[1] = (info.y+info.cellh) * info.coordincy;
            info.vertices[3] = (info.y + (info.cellh<<1)) * info.coordincy;
            info.vertices[5] = (info.y + (info.cellh<<1)) * info.coordincy;
            info.vertices[7] = (info.y+info.cellh) * info.coordincy;

            YglCachedQuad((YglSprite *)&info, tmp);
         }
      }
      else if (info.y < (vdp2height - info.cellh))
      {
         info.vertices[1] = (info.y+info.cellh) * info.coordincy;
         info.vertices[3] = (info.y + (info.cellh<<1)) * info.coordincy;
         info.vertices[5] = (info.y + (info.cellh<<1)) * info.coordincy;
         info.vertices[7] = (info.y+info.cellh) * info.coordincy;

         YglCachedQuad((YglSprite *)&info, tmp);
      }
*/
   }
   else
      Vdp2DrawMap(&info);

   return 1;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2NBG2PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x700) >> 2;
   u32 tmp=0;
   int deca;
   int multi;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN2 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN2 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN2 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN2 >> 8);
         break;
   }

   deca = info->planeh + info->planew - 2;
   multi = info->planeh * info->planew;

   //if (Vdp2Regs->VRSIZE & 0x8000)
   //{
      if (info->patterndatasize == 1)
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x2000);
         else
            info->addr = (tmp >> deca) * (multi * 0x800);
      }
      else
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x1000);
      }
   /*}
   else
   {
      if (info->patterndatasize == 1)
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x2000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x800);
      }
      else
      {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0xF) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x1000);
      }
   }*/
}

//////////////////////////////////////////////////////////////////////////////

static int Vdp2DrawNBG2(void)
{
   vdp2draw_struct info;

   info.enable = Vdp2Regs->BGON & 0x4;

   if (!(info.enable & Vdp2External.disptoggle))
       return 0;

   info.transparencyenable = !(Vdp2Regs->BGON & 0x400);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 4) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x2) >> 1;
   info.mapwh = 2;

   switch((Vdp2Regs->PLSZ & 0x30) >> 4)
   {
      case 0:
         info.planew = info.planeh = 1;
         break;
      case 1:
         info.planew = 2;
         info.planeh = 1;
         break;
      case 3:
         info.planew = info.planeh = 2;
         break;
      default: // Not sure what 0x2 does
         info.planew = info.planeh = 1;
         break;
   }
   info.x = - ((Vdp2Regs->SCXN2 & 0x7FF) % (512 * info.planew));
   info.y = - ((Vdp2Regs->SCYN2 & 0x7FF) % (512 * info.planeh));

   if(Vdp2Regs->PNCN2 & 0x8000)
      info.patterndatasize = 1;
   else
      info.patterndatasize = 2;

   if(Vdp2Regs->CHCTLB & 0x1)
      info.patternwh = 2;
   else
      info.patternwh = 1;

   info.pagewh = 64/info.patternwh;
   info.cellw = info.cellh = 8;
   info.supplementdata = Vdp2Regs->PNCN2 & 0x3FF;
   info.auxmode = (Vdp2Regs->PNCN2 & 0x4000) >> 14;

   if (Vdp2Regs->CCCTL & 0x4)
      info.alpha = ((~Vdp2Regs->CCRNB & 0x1F) << 3) + 0x7;
   else
      info.alpha = 0xFF;

   info.coloroffset = Vdp2Regs->CRAOFA & 0x700;

   if (Vdp2Regs->CLOFEN & 0x4)
   {
      // color offset enable
      if (Vdp2Regs->CLOFSL & 0x4)
      {
         // color offset B
         info.cor = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            info.cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         info.cor = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            info.cob |= 0xFFFFFF00;
      }

      if (Vdp2Regs->CCCTL & 0x4)
         info.PostPixelFetchCalc = &DoColorCalcWithColorOffset;
      else
         info.PostPixelFetchCalc = &DoColorOffset;
   }
   else // color offset disable
   {
      if (Vdp2Regs->CCCTL & 0x4)
         info.PostPixelFetchCalc = &DoColorCalc;
      else
         info.PostPixelFetchCalc = &DoNothing;
   }

   info.coordincx = info.coordincy = 1;

   info.priority = nbg2priority;
   info.PlaneAddr = (void (*)(void *, int))&Vdp2NBG2PlaneAddr;

   Vdp2DrawMap(&info);

   return 1;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2NBG3PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x7000) >> 6;
   u32 tmp=0;
   int deca;
   int multi;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN3 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN3 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN3 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN3 >> 8);
         break;
   }

   deca = info->planeh + info->planew - 2;
   multi = info->planeh * info->planew;

   //if (Vdp2Regs->VRSIZE & 0x8000) {
      if (info->patterndatasize == 1) {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x2000);
         else
            info->addr = (tmp >> deca) * (multi * 0x800);
      }
      else {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x1000);
      }
   /*}
   else {
      if (info->patterndatasize == 1) {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0x1F) >> deca) * (multi * 0x2000);
         else
            info->addr = ((tmp & 0x7F) >> deca) * (multi * 0x800);
      }
      else {
         if (info->patternwh == 1)
            info->addr = ((tmp & 0xF) >> deca) * (multi * 0x4000);
         else
            info->addr = ((tmp & 0x3F) >> deca) * (multi * 0x1000);
      }
   }*/
}

//////////////////////////////////////////////////////////////////////////////

static int Vdp2DrawNBG3(void)
{
   vdp2draw_struct info;

   info.enable = Vdp2Regs->BGON & 0x8;

   if (!(info.enable & Vdp2External.disptoggle))
       return 0;

   info.transparencyenable = !(Vdp2Regs->BGON & 0x800);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 6) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x20) >> 5;

   info.mapwh = 2;

   switch((Vdp2Regs->PLSZ & 0xC0) >> 6)
   {
      case 0:
         info.planew = info.planeh = 1;
         break;
      case 1:
         info.planew = 2;
         info.planeh = 1;
         break;
      case 3:
         info.planew = info.planeh = 2;
         break;
      default: // Not sure what 0x2 does
         info.planew = info.planeh = 1;
         break;
   }
   info.x = - ((Vdp2Regs->SCXN3 & 0x7FF) % (512 * info.planew));
   info.y = - ((Vdp2Regs->SCYN3 & 0x7FF) % (512 * info.planeh));

   if(Vdp2Regs->PNCN3 & 0x8000)
      info.patterndatasize = 1;
   else
      info.patterndatasize = 2;

   if(Vdp2Regs->CHCTLB & 0x10)
      info.patternwh = 2;
   else
      info.patternwh = 1;

   info.pagewh = 64/info.patternwh;
   info.cellw = info.cellh = 8;
   info.supplementdata = Vdp2Regs->PNCN3 & 0x3FF;
   info.auxmode = (Vdp2Regs->PNCN3 & 0x4000) >> 14;

   if (Vdp2Regs->CCCTL & 0x8)
      info.alpha = ((~Vdp2Regs->CCRNB & 0x1F00) >> 5) + 0x7;
   else
      info.alpha = 0xFF;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7000) >> 4;

   if (Vdp2Regs->CLOFEN & 0x8)
   {
      // color offset enable
      if (Vdp2Regs->CLOFSL & 0x8)
      {
         // color offset B
         info.cor = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            info.cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         info.cor = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            info.cor |= 0xFFFFFF00;

         info.cog = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            info.cog |= 0xFFFFFF00;

         info.cob = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            info.cob |= 0xFFFFFF00;
      }

      if (Vdp2Regs->CCCTL & 0x8)
         info.PostPixelFetchCalc = &DoColorCalcWithColorOffset;
      else
         info.PostPixelFetchCalc = &DoColorOffset;
   }
   else // color offset disable
   {
      if (Vdp2Regs->CCCTL & 0x8)
         info.PostPixelFetchCalc = &DoColorCalc;
      else
         info.PostPixelFetchCalc = &DoNothing;
   }

   info.coordincx = info.coordincy = 1;

   info.priority = nbg3priority;
   info.PlaneAddr = (void (*)(void *, int))&Vdp2NBG3PlaneAddr;

   Vdp2DrawMap(&info);

   return 1;
}

static int VIDDCVdp2Reset(void) {
    return 0;
}

static void VIDDCVdp2DrawStart(void)    {
    cur_addr = (uint32) tex_space;
    cur_vdp2 = (uint32) vdp2_tex;

    pvr_wait_ready();
    pvr_scene_begin();

    Vdp2DrawBackScreen();
    Vdp2DrawLineColorScreen();
}

static void VIDDCVdp2DrawEnd(void)  {
    /* Make sure we don't have any texture dma still going on... */
    sem_wait(&dmadone);
    sem_signal(&dmadone);

    pvr_scene_finish();

    ++framecount;

    if(lastup + 10 <= time(NULL))    {
        printf("%d frames in %d seconds FPS: %f\n", framecount, time(NULL) -
               lastup, ((float)(framecount)) / (time(NULL) - lastup));
        framecount = 0;
        lastup = time(NULL);
    }
}

static void dma_callback(ptr_t data __attribute__((unused)))    {
    sem_signal(&dmadone);
}

static void Vdp2Draw(int priority)  {
    pvr_sprite_txr_t sprite;

    pt_sprite_hdr.mode2 &= (~(PVR_TA_PM2_USIZE_MASK | PVR_TA_PM2_VSIZE_MASK));
    pt_sprite_hdr.mode2 |= (6 << PVR_TA_PM2_USIZE_SHIFT) |
                           (5 << PVR_TA_PM2_VSIZE_SHIFT);
    pt_sprite_hdr.mode3 = ((cur_vdp2 & 0x00FFFFF8) >> 3) |
                          (PVR_TXRFMT_NONTWIDDLED);

    pvr_list_prim(PVR_LIST_PT_POLY, &pt_sprite_hdr, sizeof(pvr_sprite_hdr_t));

    sprite.flags = PVR_CMD_VERTEX_EOL;
    sprite.ax = 0;
    sprite.ay = 0;
    sprite.az = priority_levels[priority];

    sprite.bx = vdp2width;
    sprite.by = 0;
    sprite.bz = priority_levels[priority];

    sprite.cx = vdp2width;
    sprite.cy = vdp2height;
    sprite.cz = priority_levels[priority];

    sprite.dx = 0;
    sprite.dy = vdp2height;

    sprite.auv = PVR_PACK_16BIT_UV(0.0f, 0.0f);
    sprite.buv = PVR_PACK_16BIT_UV(vdp2width / 512.0f, 0.0f);
    sprite.cuv = PVR_PACK_16BIT_UV(vdp2width / 512.0f, vdp2height / 256.0f);
    pvr_list_prim(PVR_LIST_PT_POLY, &sprite, sizeof(pvr_sprite_txr_t));

    priority_levels[priority] += 0.000001f;
}

static void VIDDCVdp2SetResolution(u16 TVMD)    {
    int w = 0, h = 0;

    switch(TVMD & 0x03) {
        case 0:
        w = 320;
        break;
        case 1:
        w = 352;
        break;
        case 2:
        w = 640;
        break;
        case 3:
        w = 704;
        break;
    }

    switch((TVMD >> 4) & 0x03)  {
        case 0:
        h = 224;
        break;
        case 1:
        h = 240;
        break;
        case 2:
        h = 256;
        break;
    }

    switch((TVMD >> 6) & 0x03)  {
        case 2:
        case 3:
        h <<= 1;
        default:
        break;
    }

    vdp2width = w;
    vdp2height = h;

    if(w > 352 || h > 256)  {
        printf("Unsupported resolution set %d x %d\n", w, h);
        printf("Bailing out!\n");
        exit(-1);
    }
}

static void VIDDCVdp2SetPriorityNBG0(int priority)  {
    nbg0priority = priority;
}

static void VIDDCVdp2SetPriorityNBG1(int priority)  {
    nbg1priority = priority;
}

static void VIDDCVdp2SetPriorityNBG2(int priority)  {
    nbg2priority = priority;
}

static void VIDDCVdp2SetPriorityNBG3(int priority)  {
    nbg3priority = priority;
}

static void VIDDCVdp2SetPriorityRBG0(int priority)  {
    rbg0priority = priority;
}

static void VIDDCVdp2DrawScreens(void)  {
    int i;

    VIDDCVdp2SetResolution(Vdp2Regs->TVMD);
    VIDDCVdp2SetPriorityNBG0(Vdp2Regs->PRINA & 0x7);
    VIDDCVdp2SetPriorityNBG1((Vdp2Regs->PRINA >> 8) & 0x7);
    VIDDCVdp2SetPriorityNBG2(Vdp2Regs->PRINB & 0x7);
    VIDDCVdp2SetPriorityNBG3((Vdp2Regs->PRINB >> 8) & 0x7);
    VIDDCVdp2SetPriorityRBG0(Vdp2Regs->PRIR & 0x7);

    vdp2_fb = vdp2_fbs[0];
    vdp2_fbnum = 0;

    for(i = 1; i < 8; i++)  {
        if(nbg3priority == i)   {
            if(Vdp2DrawNBG3())  {
                dcache_flush_range((ptr_t)(vdp2_fb), 512 * 256 * 2);
                sem_wait(&dmadone);

                pvr_txr_load_dma(vdp2_fb, (pvr_ptr_t) cur_vdp2, 512 * 256 * 2,
                                 0, dma_callback, 0);

                Vdp2Draw(i);

                cur_vdp2 += 512 * 256 * 2;
                vdp2_fbnum ^= 1;
                vdp2_fb = vdp2_fbs[vdp2_fbnum];
            }
        }
        if(nbg2priority == i)   {
            if(Vdp2DrawNBG2())  {
                dcache_flush_range((ptr_t)(vdp2_fb), 512 * 256 * 2);
                sem_wait(&dmadone);

                pvr_txr_load_dma(vdp2_fb, (pvr_ptr_t) cur_vdp2, 512 * 256 * 2,
                                 0, dma_callback, 0);

                Vdp2Draw(i);

                cur_vdp2 += 512 * 256 * 2;
                vdp2_fbnum ^= 1;
                vdp2_fb = vdp2_fbs[vdp2_fbnum];
            }
        }
        if(nbg1priority == i)   {
            if(Vdp2DrawNBG1())  {
                dcache_flush_range((ptr_t)(vdp2_fb), 512 * 256 * 2);
                sem_wait(&dmadone);

                pvr_txr_load_dma(vdp2_fb, (pvr_ptr_t) cur_vdp2, 512 * 256 * 2,
                                 0, dma_callback, 0);

                Vdp2Draw(i);

                cur_vdp2 += 512 * 256 * 2;
                vdp2_fbnum ^= 1;
                vdp2_fb = vdp2_fbs[vdp2_fbnum];
            }
        }
        if(nbg0priority == i)   {
            if(Vdp2DrawNBG0())  {
                dcache_flush_range((ptr_t)(vdp2_fb), 512 * 256 * 2);
                sem_wait(&dmadone);

                pvr_txr_load_dma(vdp2_fb, (pvr_ptr_t) cur_vdp2, 512 * 256 * 2,
                                 0, dma_callback, 0);

                Vdp2Draw(i);

                cur_vdp2 += 512 * 256 * 2;
                vdp2_fbnum ^= 1;
                vdp2_fb = vdp2_fbs[vdp2_fbnum];
            }
        }
//        if (rbg0priority == i)
//            Vdp2DrawRBG0();
    }
}

VideoInterface_struct VIDDC = {
    VIDCORE_DC,
    "Dreamcast PVR Video Interface",
    VIDDCInit,
    VIDDCDeInit,
    VIDDCResize,
    VIDDCIsFullscreen,
    VIDDCVdp1Reset,
    VIDDCVdp1DrawStart,
    VIDDCVdp1DrawEnd,
    VIDDCVdp1NormalSpriteDraw,
    VIDDCVdp1ScaledSpriteDraw,
    VIDDCVdp1DistortedSpriteDraw,
    VIDDCVdp1PolygonDraw,
    VIDDCVdp1PolylineDraw,
    VIDDCVdp1LineDraw,
    VIDDCVdp1UserClipping,
    VIDDCVdp1SystemClipping,
    VIDDCVdp1LocalCoordinate,
    NULL,
    VIDDCVdp2Reset,
    VIDDCVdp2DrawStart,
    VIDDCVdp2DrawEnd,
    VIDDCVdp2DrawScreens
};
