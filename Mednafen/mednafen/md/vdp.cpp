/*
    Copyright (C) 1999, 2000, 2001, 2002, 2003  Charles MacDonald

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/*
 FIXME:

  HC table for 320-pixel mode is mapped to cycles incorrectly.

*/

#include "shared.h"
#include "vcnt.h"
#include "hvc.h"

namespace MDFN_IEN_MD
{

/*
        only update window clip on window change (?)
        fix leftmost window/nta render and window bug
        sprite masking isn't right in sonic/micromachines 2, but
        seems ok in galaxy force 2
*/


/*--------------------------------------------------------------------------*/
/* Init, reset, shutdown functions                                          */
/*--------------------------------------------------------------------------*/

const uint8 MDVDP::shift_table[4] = { 6, 7, 0, 8 };
const uint8 MDVDP::col_mask_table[4] = { 0x1F, 0x3F, 0x1F, 0x7F };
const uint16 MDVDP::row_mask_table[4] = { 0x0FF, 0x1FF, 0x2FF, 0x3FF };
const uint32 MDVDP::y_mask_table[4] = { 0x1FC0, 0x1FC0, 0x1F80, 0x1F00 };

 /* Attribute expansion table */
const uint32 MDVDP::atex_table[8] = {
    0x00000000, 0x10101010, 0x20202020, 0x30303030,
    0x40404040, 0x50505050, 0x60606060, 0x70707070
 };

MDVDP::MDVDP()
{
    int bx, ax, i;

    UserLE = ~0;

    /* Allocate and align pixel look-up tables */
    lut_base = (uint8 *)malloc((LUT_MAX * LUT_SIZE) + LUT_SIZE);
    lut[0] = (uint8 *)(((uint64)lut_base + LUT_SIZE) & ~(LUT_SIZE - 1));
    for(i = 1; i < LUT_MAX; i += 1)
    {
        lut[i] = lut[0] + (i * LUT_SIZE);
    }

    /* Make pixel look-up table data */
    for(bx = 0; bx < 0x100; bx += 1)
    for(ax = 0; ax < 0x100; ax += 1)
    {
        uint16 index = (bx << 8) | (ax);
        lut[0][index] = make_lut_bg(bx, ax);
        lut[1][index] = make_lut_obj(bx, ax);
        lut[2][index] = make_lut_bg_ste(bx, ax);
        lut[3][index] = make_lut_obj_ste(bx, ax);
        lut[4][index] = make_lut_bgobj_ste(bx, ax);
    }

    /* Make sprite name look-up table */
    make_name_lut();
}

void MDVDP::SetSettings(bool PAL, bool PAL_reported, bool auto_aspect)
{
 is_pal = PAL;
 report_pal = PAL_reported;
 WantAutoAspect = auto_aspect;
}

MDVDP::~MDVDP()
{
   if(lut_base) free(lut_base);
}

void MDVDP::RedoViewport(void)
{
 // Warning:  Don't test these viewport variables to determine what video mode we're in(do it right, with reg[0xC])
#if 0
 bitmap.viewport.x = 0x20;
 bitmap.viewport.y = 0x20;
 bitmap.viewport.w = WantAutoAspect ? ((reg[0xC] & 0x1) ? 320 : 256) : 320;
 bitmap.viewport.h = (reg[0x1] & 0x8) ? 240 : 224;

 if((reg[0xC] & 0x06) == 0x06)
  bitmap.viewport.h *= 2;

 bitmap.viewport.changed = 1;
#endif
}

void MDVDP::SyncColors(void)
{
 /* Update colors */
 for(int i = 0; i < 0x40; i++)
  color_update(i, cram[i]);

 color_update(0x00, cram[border]);
 color_update(0x40, cram[border]);
 color_update(0x80, cram[border]);
}

void MDVDP::Reset(void)
{
    memset(sat, 0, sizeof(sat));
    memset(vram, 0, sizeof(vram));
    memset(cram, 0, sizeof(cram));
    memset(vsram, 0, sizeof(vsram));

    memset(bg_name_dirty, 0, sizeof(bg_name_dirty));
    memset(bg_name_list, 0, sizeof(bg_name_list));
    bg_list_index = 0;
    memset(bg_pattern_cache, 0, sizeof(bg_pattern_cache));
    memset(reg, 0, sizeof(reg));

    addr = addr_latch = code = pending = buffer = status = 0;
    ntab = ntbb = ntwb = satb = hscb = 0;
    sat_base_mask = 0xFE00;
    sat_addr_mask = 0x01FF;

    /* Mark all colors as dirty to force a palette update */
    border = 0x00;

    playfield_shift = 6;
    playfield_col_mask = 0x1F;
    playfield_row_mask = 0x0FF;
    y_mask = 0x1FC0;

    hint_pending = vint_pending = 0;
    counter = 0;
    visible_frame_end = 0xE0;
    v_counter = v_update = 0;

    fifo_simu_count = 0;
    dma_fill_latch = 0;
    DMASource = 0;
    DMALength = 0;
    dma_fill = 0;
    im2_flag = 0;

    vdp_last_ts = 0;
    vdp_cycle_counter = 102;
    vdp_line_phase = 5;
    vdp_hcounter_start_ts = 0;
    scanline = visible_frame_end;

    MD_Suspend68K(FALSE);
    z80_set_interrupt(FALSE);
    C68k_Set_IRQ(&Main68K, 0);

    RedoViewport();

    memset(&clip, 0, sizeof(clip));
    memset(&pixel_32, 0, sizeof(pixel_32));

    SyncColors();
}


/*--------------------------------------------------------------------------*/
/* Memory access functions                                                  */
/*--------------------------------------------------------------------------*/
void MDVDP::vdp_ctrl_w(uint16 data)
{
    if(pending == 0)
    {
        if((data & 0xC000) == 0x8000)
        {
            uint8 r = (data >> 8) & 0x1F;
            uint8 d = (data >> 0) & 0xFF;
            vdp_reg_w(r, d);
        }
        else
        {
            pending = 1;
        }

        addr = ((addr_latch & 0xC000) | (data & 0x3FFF)) & 0xFFFF;
        code = ((code & 0x3C) | ((data >> 14) & 0x03)) & 0x3F;
    }
    else
    {
        /* Clear pending flag */
        pending = 0;

        /* Update address and code registers */
        addr = ((addr & 0x3FFF) | ((data & 3) << 14)) & 0xFFFF;
        code = ((code & 0x03) | ((data >> 2) & 0x3C)) & 0x3F;

        /* Save address bits A15 and A14 */
        addr_latch = (addr & 0xC000);

        if((code & 0x20) && (reg[1] & 0x10))
        {
	 // printf("DMA: %02x, %d, %d\n", reg[23], scanline, DMALength);
            switch(reg[23] & 0xC0)
            {
                case 0x00: /* V bus to VDP DMA */
                case 0x40: /* V bus to VDP DMA */
		    if((code & 0x0F) != 0x1 && (code & 0x0F) != 0x3 && (code & 0x0F) != 0x5)
                     MD_DBG(MD_DBG_WARNING, "[VDP] Invalid code for V bus to VDP dma: %02x\n", code);
		    status |= 0x2;
		    Recalc68KSuspend();
                    break;

                case 0x80: /* VRAM fill */
                    if((code & 0x0F) != 0x1)
                     MD_DBG(MD_DBG_WARNING, "[VDP] Invalid code for fill dma: %02x\n", code);
                    dma_fill = 1;
                    break;

                case 0xC0: /* VRAM copy */
                    if((code & 0x0F) != 0x0)
                     MD_DBG(MD_DBG_WARNING, "[VDP] Invalid code for copy dma: %02x\n", code);
		    status |= 0x2;
                    break;
            }
        }
    }
}

uint16 MDVDP::vdp_ctrl_r(void)
{
    #if 1
    uint16 backup_status = status;
    bool backup_pending = pending;
    #endif

    uint16 temp = 0; //(0x4e71 & 0xFC00);
    pending = 0;

    status &= ~0x0001;
    status |= report_pal ? 0x0001 : 0x0000;

    if(fifo_simu_count >= 4)
     temp |= 0x0100;

    if(fifo_simu_count == 0)
     temp |= 0x0200;  	// FIFO empty

    temp |= status & 0x03FF;

    if(!(reg[1] & 0x40))
     temp |= 0x08;

    status &= ~0x0020;  // Clear sprite hit flag on reads.
    status &= ~0x0040;  // Clear sprite overflow flag on reads.


    if(MD_HackyHackyMode)
    {
     status = backup_status;
     pending = backup_pending;
    }
    return (temp);
}

INLINE void MDVDP::WriteCRAM(uint16 data)
{
 const int index = (addr >> 1) & 0x3F;
 uint16 *p = &cram[index];
 uint16 packed_data;

 data &= 0x0EEE;
 packed_data = PACK_CRAM(data);

 if(packed_data != *p)
 {
  *p = packed_data;

  // Must come before the next color_update call!
  color_update(index, *p);

  if(index == border || !index)
  {
   color_update(0x00, cram[border]);
  }

 }
}

// Only used for DMA fill and VRAM->VRAM DMA copy.
// Since CRAM and VSRAM only allow 16-bit accesses, trying
// to use DMA fill on CRAM and CSRAM will probably not work so well.
INLINE void MDVDP::MemoryWrite8(uint8 data)
{
 switch(code & 0x0F)
 {
        case 0x01: /* VRAM */
            /* Copy SAT data to the internal SAT */
            if((addr & sat_base_mask) == satb)
            {
                sat[addr & sat_addr_mask] = data;
            }

            /* Only write unique data to VRAM */
            if(data != READ_BYTE_LSB(vram, addr & 0xFFFF))
            {
                /* Write data to VRAM */
                WRITE_BYTE_LSB(vram, addr & 0xFFFF, data);

                /* Update the pattern cache */
                MARK_BG_DIRTY(addr);
            }
            break;
        case 0x03: /* CRAM */
	    WriteCRAM(data);
	    break;

        case 0x05: /* VSRAM */
            vsram[(addr & 0x7E) >> 1] = data;
            break;
 }

 /* Bump address register */
 addr += reg[15];
}


INLINE void MDVDP::MemoryWrite16(uint16 data)
{
 switch(code & 0x0F)
 {
        case 0x01: /* VRAM */
            /* Byte-swap data if A0 is set */
            if(addr & 1) data = (data >> 8) | (data << 8);

            /* Copy SAT data to the internal SAT */
            if((addr & sat_base_mask) == satb)
            {
                //MDFN_en16lsb(&sat[addr & sat_addr_mask], data);
		MDFN_en16lsb<true>(&sat[addr & sat_addr_mask & ~1], data);
            }

            /* Only write unique data to VRAM */
            if(data != READ_WORD_LSB(vram, addr & 0xFFFE))
            {
                /* Write data to VRAM */
		WRITE_WORD_LSB(vram, addr & 0xFFFE, data);

                /* Update the pattern cache */
                MARK_BG_DIRTY(addr);
            }
            break;

        case 0x03: /* CRAM */
            WriteCRAM(data);
	    break;
          
        case 0x05: /* VSRAM */
            vsram[(addr & 0x7E) >> 1] = data;
            break;
 }

 /* Bump address register */
 addr += reg[15];
}

INLINE void MDVDP::Recalc68KSuspend(void)
{
 MD_Suspend68K((fifo_simu_count > 4) || ((status & 0x2) && (reg[23] & 0xC0) < 0x80));
}

void MDVDP::vdp_data_w(uint16 data)
{
    /* Clear pending flag */
    pending = 0;

    if(fifo_simu_count < 16)
     fifo_simu_count++;

    //printf("%04x, %d\n", data, scanline);
    MemoryWrite16(data);

    if(dma_fill)
    {
     dma_fill_latch = data >> 8;
     status |= 0x2;
     //printf("DMA Fill: %d, %02x, %04x\n", DMALength, code & 0x0F, data);
     dma_fill = 0;
    }

    Recalc68KSuspend();
}

uint16 MDVDP::vdp_data_r(void)
{
    uint16 temp = 0;

    /* Clear pending flag */
    if(!MD_HackyHackyMode)
     pending = 0;

    switch(code & 0x0F)
    {
        case 0x00: /* VRAM */
            temp = READ_WORD_LSB(vram, addr & 0xFFFE);
            break;

        case 0x08: /* CRAM */
            temp = cram[(addr & 0x7E) >> 1];
            temp = UNPACK_CRAM(temp);
            break;

        case 0x04: /* VSRAM */
            temp = vsram[(addr & 0x7E) >> 1];
            break;
    }

    /* Bump address register */
    if(!MD_HackyHackyMode)
     addr += reg[15];

    /* return data */
    return (temp);
}


/*
    The reg[] array is updated at the *end* of this function, so the new
    register data can be compared with the previous data.
*/
void MDVDP::vdp_reg_w(uint8 r, uint8 d)
{
 // If in mode 4, ignore writes to registers >= 0x0B
 if(!(reg[1] & 0x4) && r >= 0x0B)
  return;

    switch(r)
    {
        case 0x00: /* CTRL #1 */
            break;

        case 0x01: /* CTRL #2 */
            /* Change the frame timing */
            visible_frame_end = (d & 8) ? 0xF0 : 0xE0;

            /* Check if the viewport height has actually been changed */
            if((reg[1] & 8) != (d & 8))
            {                
		reg[1] = d;
		RedoViewport();
            }
            break;

        case 0x02: /* NTAB */
            ntab = (d << 10) & 0xE000;
            break;

        case 0x03: /* NTWB */
            ntwb = (d << 10) & 0xF800;
            if(reg[12] & 1) ntwb &= 0xF000;
            break;

        case 0x04: /* NTBB */
            ntbb = (d << 13) & 0xE000;
            break;

        case 0x05: /* SATB */
            sat_base_mask = (reg[12] & 1) ? 0xFC00 : 0xFE00;
            sat_addr_mask = (reg[12] & 1) ? 0x03FF : 0x01FF;
            satb = (d << 9) & sat_base_mask;
            break;

        case 0x07:
            d &= 0x3F;

            /* Check if the border color has actually changed */
            if(border != d)
            {
                /* Mark the border color as modified */
                border = d;

                color_update(0x00, cram[border]);
                color_update(0x40, cram[border]);
                color_update(0x80, cram[border]);
            }
            break;

        case 0x0C:

            /* See if the S/TE mode bit has changed */
            if((reg[0x0C] & 8) != (d & 8))
            {
             reg[0x0C] = d;

	     SyncColors();
            }

            /* Check interlace mode 2 setting */
            im2_flag = ((d & 0x06) == 0x06) ? 1 : 0;

            /* The following register updates check this value */
            reg[0x0C] = d;

	    RedoViewport();

            /* Update display-dependent registers */
            vdp_reg_w(0x03, reg[0x03]);
            vdp_reg_w(0x05, reg[0x05]);

            break;

        case 0x0D: /* HSCB */
            hscb = (d << 10) & 0xFC00;
            break;

        case 0x10: /* Playfield size */
            playfield_shift = shift_table[(d & 3)];
            playfield_col_mask = col_mask_table[(d & 3)];
            playfield_row_mask = row_mask_table[(d >> 4) & 3];
            y_mask = y_mask_table[(d & 3)];
            break;


	case 0x13: DMALength &= 0xFF00;
		   DMALength |= d << 0;
		   break;

	case 0x14: DMALength &= 0x00FF;
		   DMALength |= d << 8;
		   break;

	case 0x15: DMASource &= 0xFFFF00;
		   DMASource |= d << 0;
		   break;

	case 0x16: DMASource &= 0xFF00FF;
		   DMASource |= d << 8;
		   break;

	case 0x17: DMASource &= 0x00FFFF;
		   DMASource |= d << 16;
		   break;
    }

    /* Write new register value */
    reg[r] = d;
}


uint16 MDVDP::vdp_hvc_r(void)
{
 int32 cycle = (md_timestamp - vdp_hcounter_start_ts) % 3420;
 int hc;
 uint8 vc;

 hc = (reg[0xC] & 1) ? cycle2hc40[cycle] : cycle2hc32[cycle];

 if(is_pal)
  vc = (reg[0x1] & 0x8) ? vc30_pal[v_counter] : vc28_pal[v_counter];
 else
  vc = (reg[0x1] & 0x8) ? vc30_ntsc[v_counter] : vc28_ntsc[v_counter];

 if(im2_flag)
 {
  vc = (vc << 1) | (vc >> 7);
 }

 return (vc << 8 | hc);
}

INLINE void MDVDP::CheckDMA(void)
{
 //
 static const int vbus_cc[2][2] =
 {
  { 16, 167 },
  { 18, 205 },
 };
 static const int copy_cc[2][2] =
 {
  { 8, 83 },
  { 9, 102 },
 };
 static const int fill_cc[2][2] =
 {
  { 16, 167 },
  { 18, 205 },
 };
 const int vb_index = ((status & 0x8) >> 3) | (((reg[1] & 0x40) ^ 0x40) >> 6);

 if(!(status & 0x2))
  return;

 switch(reg[23] & 0xC0)
 {
  case 0x00: /* V bus to VDP DMA */
  case 0x40: /* V bus to VDP DMA */
	   {
	    int32 runcount = (vbus_cc[reg[0x0C] & 1][vb_index] + 1) / 2;

	    //printf("%08x, %d, %02x\n", DMASource, DMALength, reg[0xC] & 0x81);
	    do
 	    {
	     uint16 temp = vdp_dma_r((DMASource & 0x7FFFFF) << 1);
	     DMASource = (DMASource & 0xFF0000) | ((DMASource + 1) & 0xFFFF);
	     MemoryWrite16(temp);
	     DMALength--;
	     runcount--;
	    } while (DMALength && runcount);

	    if(!DMALength)
	    {
             status &= ~0x2;
             Recalc68KSuspend();
	    }
	    break;
	   }
  case 0x80: // DMA Fill
	   {
	    int32 runcount = fill_cc[reg[0x0C] & 1][vb_index];

	    do
	    {
	     MemoryWrite8(dma_fill_latch);
	     DMALength--;
	     runcount--;
	    } while(DMALength && runcount);

            if(!DMALength)
             status &= ~0x2;

	    break;
	   }

  case 0xC0: // VRAM copy
	   {
            int32 runcount = copy_cc[reg[0x0C] & 1][vb_index];

	    do
	    {
  	     uint8 temp = READ_BYTE_LSB(vram, DMASource & 0xFFFF);
             WRITE_BYTE_LSB(vram, addr, temp);
             MARK_BG_DIRTY(addr);
             if((addr & sat_base_mask) == satb)
             {
                sat[addr & sat_addr_mask] = temp;
             }
             DMASource = (DMASource & 0xFF0000) | ((DMASource + 1) & 0xFFFF);
             addr = (addr + reg[15]) & 0xFFFF;
             DMALength--;
	     runcount--;
	    } while(DMALength && runcount);

	    if(!DMALength)
	    {
	     status &= ~0x2;
	    }
	    break;
	   }

 }
}


void MDVDP::vdp_test_w(uint16 value)
{
}

void MDVDP::Run(void)
{
 #include "vdp_run.inc"
}

void MDVDP::ResetTS(void)
{
 //printf("%d, %d\n", vdp_cycle_counter, md_timestamp);
 vdp_hcounter_start_ts -= vdp_last_ts;
 vdp_last_ts = 0;
}

void MDVDP::StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFARRAY(sat, 0x400),
  SFARRAY(vram, 0x10000),
  SFARRAY16(cram, 0x40),
  SFARRAY16(vsram, 0x40),
  SFARRAY(reg, 0x20),

  SFVAR(addr),
  SFVAR(addr_latch),
  SFVAR(code),
  SFVAR(pending),
  SFVAR(buffer),
  SFVAR(status),
  SFVAR(ntab),
  SFVAR(ntbb),
  SFVAR(ntwb),
  SFVAR(satb),
  SFVAR(hscb),
  SFVAR(sat_base_mask),
  SFVAR(sat_addr_mask),

  SFVAR(dma_fill_latch),
  SFVAR(DMASource),
  SFVAR(DMALength),
  SFVAR(border),
  SFVAR(playfield_shift),
  SFVAR(playfield_col_mask),
  SFVAR(playfield_row_mask),
  SFVAR(y_mask),

  SFVAR(hint_pending),
  SFVAR(vint_pending),
  SFVAR(counter),
  SFVAR(dma_fill),
  SFVAR(im2_flag),
  SFVAR(visible_frame_end),
  SFVAR(v_counter),
  SFVAR(v_update),
  SFVAR(vdp_cycle_counter),
  SFVAR(vdp_last_ts),
  SFVAR(vdp_line_phase),
  SFVAR(vdp_hcounter_start_ts),
  SFVAR(scanline),

  SFVAR(fifo_simu_count),

  //SFVAR(is_pal), SFVAR(report_pal),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VDP");

 if(load)
 {
  vdp_line_phase %= 8; // tied to table in vdp_run.inc !!!

  status &= ~(0x200 | 0x100);

  for(int i = 0; i < 0x800; i++)
  {
   bg_name_list[i] = i;
   bg_name_dirty[i] = 0xFF;
  }
  bg_list_index = 0x800;

  for(int i = 0; i < 0x40; i++)
   color_update(i, cram[i]);

  color_update(0x00, cram[border]);

  RedoViewport();

  update_bg_pattern_cache();
 }
}

/*







*/

/* Draw a single 16-pixel column */
#define DRAW_COLUMN(ATTR, LINE) \
    atex = atex_table[(ATTR >> 13) & 7]; \
    src = &bg_pattern_cache[(ATTR & 0x1FFF) << 4 | (LINE)]; \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex)); \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex)); \
    ATTR >>= 16; \
    atex = atex_table[(ATTR >> 13) & 7]; \
    src = &bg_pattern_cache[(ATTR & 0x1FFF) << 4 | (LINE)]; \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex)); \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex));

/* Draw a single 16-pixel column */
#define DRAW_COLUMN_IM2(ATTR, LINE) \
    atex = atex_table[(ATTR >> 13) & 7]; \
    offs = (ATTR & 0x03FF) << 5 | (ATTR & 0x1800) << 4 | (LINE); \
    if(ATTR & 0x1000) offs ^= 0x10; \
    src = &bg_pattern_cache[offs]; \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex)); \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex)); \
    ATTR >>= 16; \
    atex = atex_table[(ATTR >> 13) & 7]; \
    offs = (ATTR & 0x03FF) << 5 | (ATTR & 0x1800) << 4 | (LINE); \
    if(ATTR & 0x1000) offs ^= 0x10; \
    src = &bg_pattern_cache[offs]; \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex)); \
    MDFN_ennsb<uint32, false>(dst++, (*src++ | atex));

/*
    gcc complains about this:
        *lb++ = table[(*lb << 8) |(*src++ | palette)]; 
    .. claiming the result on lb is undefined.
    So we manually advance lb and use constant offsets into the line buffer.
*/
#define DRAW_SPRITE_TILE \
    for(int p = 0; p < 8; p++)	\
    {	\
     if(((lb[p] & 0x8F) > 0x80) && (*src & 0xF))	\
	status |= 0x20;						\
     lb[p] = table[(lb[p] << 8) |(*src++ | palette)]; \
    }



void MDVDP::SetPixelFormat(const MDFN_PixelFormat &format)
{
 /* Make pixel data tables */
 for(int i = 0; i < 0x200; i += 1)
 {
  const int mult = 17; // 0x7 | 0x8 = 0xF, 0xF * 17 = 0xFF
  int r, g, b;

  r = (i >> 6) & 7;
  g = (i >> 3) & 7;
  b = (i >> 0) & 7;

  //r = g = b = 1;
  pixel_32_lut[0][i] = format.MakeColor(mult * r, mult * g, mult * b);
  pixel_32_lut[1][i] = format.MakeColor(mult * (r << 1), mult * (g << 1), mult * (b << 1));
  pixel_32_lut[2][i] = format.MakeColor(mult * (r|8), mult * (g|8), mult * (b|8));
 }

 SyncColors();
}

void MDVDP::SetSurface(EmulateSpecStruct *espec_arg)	//MDFN_Surface *new_surface, MDFN_Rect *new_rect)
{
 espec = espec_arg;
 surface = espec->surface;
 rect = &espec->DisplayRect;
}


void MDVDP::SetLayerEnableMask(uint64 mask)
{
 UserLE = mask;
}


void MDVDP::make_name_lut(void)
{
    int col, row;
    int vcol, vrow;
    int width, height;
    int flipx, flipy;
    int i, name;

    memset(name_lut, 0, sizeof(name_lut));

    for(i = 0; i < 0x400; i += 1)
    {
        vcol = col = i & 3;
        vrow = row = (i >> 2) & 3;
        height = (i >> 4) & 3;
        width = (i >> 6) & 3;
        flipx = (i >> 8) & 1;
        flipy = (i >> 9) & 1;

        if(flipx)
            vcol = (width - col);
        if(flipy)
            vrow = (height - row);

        name = vrow + (vcol * (height + 1));

        if((row > height) || col > width)
            name = -1;

        name_lut[i] = name;        
    }
}


/*--------------------------------------------------------------------------*/
/* Line render function                                                     */
/*--------------------------------------------------------------------------*/

void MDVDP::render_line(int line)
{
    /* Line buffers */
    alignas(8) uint8 tmp_buf[0x400];                   /* Temporary buffer */
    alignas(8) uint8 bg_buf[0x400];                    /* Merged background buffer */
    alignas(8) uint8 nta_buf[0x400];                   /* Plane A / Window line buffer */
    alignas(8) uint8 ntb_buf[0x400];                   /* Plane B line buffer */
    alignas(8) uint8 obj_buf[0x400];                   /* Object layer line buffer */
    uint8 *lb = tmp_buf;

    const int32 vp_x = 0x20;
    const int32 vp_w = ((reg[0xC] & 0x1) ? 320 : 256);

    // Our display output window is nominally XXX*224 with NTSC, XXX*240 with PAL.

    if(line == 120)
    {
     rect->x = 0;
     rect->w = WantAutoAspect ? vp_w : 320;
    }

    if((reg[1] & 0x40) == 0x00 || line >= visible_frame_end)
    {
        /* Use the overscan color to clear the screen */
        memset(&lb[vp_x], 0x40 | border, vp_w);
    }
    else
    {
        update_bg_pattern_cache();
        window_clip(line);

        if(im2_flag)
        {
            render_ntx_im2(0, line, nta_buf);
            render_ntx_im2(1, line, ntb_buf);
        }
        else
        {
            if(reg[0x0B] & 4)
            {
                render_ntx_vs(0, line, nta_buf);
                render_ntx_vs(1, line, ntb_buf);
            }
            else
            {
                render_ntx(0, line, nta_buf);
                render_ntx(1, line, ntb_buf);
            }
        }

        if(im2_flag)
              render_ntw_im2(line, nta_buf);
        else
              render_ntw(line, nta_buf);

	if(!(UserLE & 0x1))
	 memset(&nta_buf[0x20], 0, (reg[12] & 1) ? 320 : 256);

	if(!(UserLE & 0x2))
	 memset(&ntb_buf[0x20], 0, (reg[12] & 1) ? 320 : 256);

        if(reg[12] & 8)
        {
            merge(&nta_buf[0x20], &ntb_buf[0x20], &bg_buf[0x20], lut[2], (reg[12] & 1) ? 320 : 256);
            memset(&obj_buf[0], 0, 0x20 + ((reg[12] & 1) ? 320 : 256) + 0x20);	// Need to clear left and right padding areas to prevent uninitialized memory usage.

            if(im2_flag)
                render_obj_im2(line, obj_buf, lut[3]);
            else
                render_obj(line, obj_buf, lut[3]);

	    if(!(UserLE & 0x4))
             memset(&obj_buf[0x20], 0, (reg[12] & 1) ? 320 : 256);

            merge(&obj_buf[0x20], &bg_buf[0x20], &lb[0x20], lut[4], (reg[12] & 1) ? 320 : 256);
        }
        else
        {
	  // So sprite rendering won't read from uninitialized memory.
	  memset(&lb[0x00], 0, 0x20);
	  memset(&lb[0x20 + ((reg[12] & 1) ? 320 : 256)], 0, 0x20);


	  if(UserLE & 0x4)
           merge(&nta_buf[0x20], &ntb_buf[0x20], &lb[0x20], lut[0], (reg[12] & 1) ? 320 : 256);
	  else
	   memset(&lb[0x20], 0, (reg[12] & 1) ? 320 : 256);

          if(im2_flag)
           render_obj_im2(line, lb, lut[1]);
          else
           render_obj(line, lb, lut[1]);

          if(!(UserLE & 0x4))
           merge(&nta_buf[0x20], &ntb_buf[0x20], &lb[0x20], lut[0], (reg[12] & 1) ? 320 : 256);
        }

	if(reg[0] & 0x20)
    	{
        	memset(&lb[vp_x], 0x40 | border, 0x08);
    	}
    }

    const unsigned int lines_per_frame = is_pal ? 313 : 262;	// FIXME: have this as an inline function(duplicated in vdp_run.inc)
    unsigned int cvp_line = (line + ((240 - visible_frame_end) >> 1)) % lines_per_frame;

    if(cvp_line < 240)
    {
     //printf("ION: %d, IFIELD: %d --- %d, %d, im2f=%d\n", espec->InterlaceOn, espec->InterlaceField, line, ((line + ((240 - visible_frame_end) >> 1)) * (espec->InterlaceOn ? 2 : 1) + espec->InterlaceField), im2_flag);
     //printf("%d, %d %d\n", line, espec->InterlaceOn, espec->InterlaceField);
     switch(surface->format.bpp)
     {
	case 16:CopyLineSurface<uint16>(&lb[vp_x], cvp_line, vp_w);
		break;

	case 32:CopyLineSurface<uint32>(&lb[vp_x], cvp_line, vp_w);
		break;
     }
    }
}
/*--------------------------------------------------------------------------*/
/* Window rendering                                                         */
/*--------------------------------------------------------------------------*/

void MDVDP::render_ntw(int line, uint8 *buf)
{
    int column, v_line, width;
    uint32 *nt, *src, *dst, atex, atbuf;

    v_line = (line & 7) << 1;
    width = (reg[12] & 1) ? 7 : 6;

    nt = (uint32 *)&vram[ntwb | ((line >> 3) << width)];
    dst = (uint32 *)&buf[0x20 + (clip[1].left << 4)];

    for(column = clip[1].left; column < clip[1].right; column += 1)
    {
        atbuf = MDFN_de32lsb<true>(&nt[column]);
        DRAW_COLUMN(atbuf, v_line)
    }
}

void MDVDP::render_ntw_im2(int line, uint8 *buf)
{
    int column, v_line, width;
    uint32 *nt, *src, *dst, atex, atbuf, offs;

    v_line = ((line & 7) << 1 | ((status >> 4) & 1)) << 1;
    width = (reg[12] & 1) ? 7 : 6;

    nt = (uint32 *)&vram[ntwb | ((line >> 3) << width)];
    dst = (uint32 *)&buf[0x20 + (clip[1].left << 4)];

    for(column = clip[1].left; column < clip[1].right; column += 1)
    {
        atbuf = MDFN_de32lsb<true>(&nt[column]);
        DRAW_COLUMN_IM2(atbuf, v_line)
    }
}

/*--------------------------------------------------------------------------*/
/* Background plane rendering                                               */
/*--------------------------------------------------------------------------*/

void MDVDP::render_ntx(int which, int line, uint8 *buf)
{
    int column;
    int start, end;
    int index;
    int shift;
    int nametable_row_mask = (playfield_col_mask >> 1);
    int v_line;
    uint32 atex, atbuf, *src, *dst;
    uint16 xascroll, xbscroll, xscroll;
    int y_scroll;
    uint8 *nt;
    uint16 *vs;
    uint16 table;


    table = (which) ? ntbb : ntab;

    get_hscroll(line, &xascroll, &xbscroll);
    xscroll = (which) ? xbscroll : xascroll;

    shift = (xscroll & 0x0F);
    index = ((playfield_col_mask + 1) >> 1) - ((xscroll >> 4) & nametable_row_mask);

    if(which)
    {
        start = 0;
        end = (reg[0x0C] & 1) ? 20 : 16;
    }
    else
    {
// Looks correct if clip[0].left has 1 subtracted
// Otherwise window has gap between endpoint and where the first normal
// nta column starts

        if(clip[0].enable == 0) return;
        start = clip[0].left;
        end = clip[0].right;
        index = (index + clip[0].left) & nametable_row_mask;
    }

    vs = &vsram[which ? 1 : 0];

    y_scroll = vs[0];
    y_scroll = (line + (y_scroll & 0x3FF)) & playfield_row_mask;
    v_line = (y_scroll & 7) << 1;
    nt = &vram[table + (((y_scroll >> 3) << playfield_shift) & y_mask)];

    if(shift)
    {
        dst = (uint32 *)&buf[0x20-(0x10-shift)];
        atbuf = MDFN_de32lsb<true>(&nt[((index-1) & nametable_row_mask) << 2]);
        DRAW_COLUMN(atbuf, v_line)
    }
    buf = (buf + 0x20 + shift);
    dst = (uint32 *)&buf[start<<4];

    for(column = start; column < end; column += 1, index += 1)
    {
        atbuf = MDFN_de32lsb<true>(&nt[(index & nametable_row_mask) << 2]);
        DRAW_COLUMN(atbuf, v_line)
    }
}


void MDVDP::render_ntx_im2(int which, int line, uint8 *buf)
{
    int column;
    int start, end;
    int index;
    int shift;
    int nametable_row_mask = (playfield_col_mask >> 1);
    int v_line;
    uint32 atex, atbuf, *src, *dst;
    uint16 xascroll, xbscroll, xscroll;
    int y_scroll;
    uint8 *nt;
    uint16 *vs;
    uint16 table;
    uint32 offs;

    table = (which) ? ntbb : ntab;

    get_hscroll(line, &xascroll, &xbscroll);
    xscroll = (which) ? xbscroll : xascroll;

    shift = (xscroll & 0x0F);
    index = ((playfield_col_mask + 1) >> 1) - ((xscroll >> 4) & nametable_row_mask);

    if(which)
    {
        start = 0;
        end = (reg[0x0C] & 1) ? 20 : 16;
    }
    else
    {
        if(clip[0].enable == 0) return;
        start = clip[0].left;
        end = clip[0].right;
        index = (index + clip[0].left) & nametable_row_mask;
    }

    vs = &vsram[which ? 1 : 0];

    y_scroll = vs[0];
    y_scroll = (line + ((y_scroll >> 1) & 0x3FF)) & playfield_row_mask;
    v_line = (((y_scroll & 7) << 1) | ((status >> 4) & 1)) << 1;
    nt = &vram[table + (((y_scroll >> 3) << playfield_shift) & y_mask)];

    if(shift)
    {
        dst = (uint32 *)&buf[0x20-(0x10-shift)];
        atbuf = MDFN_de32lsb<true>(&nt[((index-1) & nametable_row_mask) << 2]);
        DRAW_COLUMN_IM2(atbuf, v_line)
    }
    buf = (buf + 0x20 + shift);
    dst = (uint32 *)&buf[start<<4];

    for(column = start; column < end; column += 1, index += 1)
    {
        atbuf = MDFN_de32lsb<true>(&nt[(index & nametable_row_mask) << 2]);
        DRAW_COLUMN_IM2(atbuf, v_line)
    }
}


void MDVDP::render_ntx_vs(int which, int line, uint8 *buf)
{
    int column;
    int start, end;
    int index;
    int shift;
    int nametable_row_mask = (playfield_col_mask >> 1);
    int v_line;
    uint32 atex, atbuf, *src, *dst;
    uint16 xascroll, xbscroll, xscroll;
    int y_scroll;
    uint8 *nt;
    uint16 *vs;
    uint16 table;

    table = (which) ? ntbb : ntab;

    get_hscroll(line, &xascroll, &xbscroll);
    xscroll = (which) ? xbscroll : xascroll;
    shift = (xscroll & 0x0F);
    index = ((playfield_col_mask + 1) >> 1) - ((xscroll >> 4) & nametable_row_mask);

    if(which)
    {
        start = 0;
        end = (reg[0x0C] & 1) ? 20 : 16;
    }
    else
    {
        if(clip[0].enable == 0) return;
        start = clip[0].left;
        end = clip[0].right;
        index = (index + clip[0].left) & nametable_row_mask;
    }

    vs = &vsram[which ? 1 : 0];
    end = (reg[0x0C] & 1) ? 20 : 16;

    if(shift)
    {
        dst = (uint32 *)&buf[0x20-(0x10-shift)];
        y_scroll = (line & playfield_row_mask);
        v_line = (y_scroll & 7) << 1;
        nt = &vram[table + (((y_scroll >> 3) << playfield_shift) & y_mask)];
        atbuf = MDFN_de32lsb<true>(&nt[((index-1) & nametable_row_mask) << 2]);
        DRAW_COLUMN(atbuf, v_line)
    }

    buf = (buf + 0x20 + shift);
    dst = (uint32 *)&buf[start << 4];

    for(column = start; column < end; column += 1, index += 1)
    {
        y_scroll = vs[column << 1];
        y_scroll = (line + (y_scroll & 0x3FF)) & playfield_row_mask;
        v_line = (y_scroll & 7) << 1;
        nt = &vram[table + (((y_scroll >> 3) << playfield_shift) & y_mask)];
        atbuf = MDFN_de32lsb<true>(&nt[(index & nametable_row_mask) << 2]);
        DRAW_COLUMN(atbuf, v_line)
    }
}
/*--------------------------------------------------------------------------*/
/* Helper functions (cache update, hscroll, window clip)                    */
/*--------------------------------------------------------------------------*/

void MDVDP::update_bg_pattern_cache(void)
{
    int i;
    uint8 x, y, c;
    uint16 name;

    if(!bg_list_index) return;

    for(i = 0; i < bg_list_index; i += 1)
    {
        name = bg_name_list[i];
        bg_name_list[i] = 0;

        for(y = 0; y < 8; y += 1)
        {
            if(bg_name_dirty[name] & (1 << y))
            {
                uint8 *dst = (uint8 *)&bg_pattern_cache[name << 4];
                uint32 bp = MDFN_de32lsb<true>(vram + ((name << 5) | (y << 2)));

                for(x = 0; x < 8; x += 1)
                {
                    c = (bp >> ((x ^ 3) << 2)) & 0x0F;
                    dst[0x00000 | (y << 3) | (x)] = (c);
                    dst[0x20000 | (y << 3) | (x ^ 7)] = (c);
                    dst[0x40000 | ((y ^ 7) << 3) | (x)] = (c);
                    dst[0x60000 | ((y ^ 7) << 3) | (x ^ 7)] = (c);
                }
            }
        }
        bg_name_dirty[name] = 0;
    }
    bg_list_index = 0;
}

void MDVDP::get_hscroll(int line, uint16 *scrolla, uint16 *scrollb)
{
    switch(reg[11] & 3)
    {
        case 0: /* Full-screen */
            *scrolla = READ_WORD_LSB(vram, hscb + 0);
            *scrollb = READ_WORD_LSB(vram, hscb + 2);
            break;

        case 1: /* First 8 lines */
            *scrolla = READ_WORD_LSB(vram, hscb + ((line & 7) << 2) + 0);
            *scrollb = READ_WORD_LSB(vram, hscb + ((line & 7) << 2) + 2);
            break;

        case 2: /* Every 8 lines */
            *scrolla = READ_WORD_LSB(vram, hscb + ((line & ~7) << 2) + 0);
            *scrollb = READ_WORD_LSB(vram, hscb + ((line & ~7) << 2) + 2);
            break;

        case 3: /* Every line */
            *scrolla = READ_WORD_LSB(vram, hscb + (line << 2) + 0);
            *scrollb = READ_WORD_LSB(vram, hscb + (line << 2) + 2);
            break;
    }

    *scrolla &= 0x03FF;
    *scrollb &= 0x03FF;
}

void MDVDP::window_clip(int line)
{
    /* Window size and invert flags */
    int hp = (reg[17] & 0x1F);
    int hf = (reg[17] >> 7) & 1;
    int vp = (reg[18] & 0x1F) << 3;
    int vf = (reg[18] >> 7) & 1;

    /* Display size  */
    int sw = (reg[12] & 1) ? 20 : 16;

    /* Clear clipping data */
    memset(&clip, 0, sizeof(clip));

    /* Check if line falls within window range */
    if(vf == (line >= vp))
    {
        /* Window takes up entire line */
        clip[1].right = sw;
        clip[1].enable = 1;
    }
    else
    {
        /* Perform horizontal clipping; the results are applied in reverse
           if the horizontal inversion flag is set */
        int a = hf;
        int w = hf ^ 1;

        if(hp)
        {
            if(hp > sw)
            {
                /* Plane W takes up entire line */
                clip[w].right = sw;
                clip[w].enable = 1;
            }
            else
            {
                /* Window takes left side, Plane A takes right side */
                clip[w].right = hp;
                clip[a].left = hp;
                clip[a].right = sw;
                clip[0].enable = clip[1].enable = 1;
            }
        }
        else
        {
            /* Plane A takes up entire line */
            clip[a].right = sw;
            clip[a].enable = 1;
        }
    }
}



/*--------------------------------------------------------------------------*/
/* Look-up table functions                                                  */
/*--------------------------------------------------------------------------*/

/* Input (bx):  d5-d0=color, d6=priority, d7=unused */
/* Input (ax):  d5-d0=color, d6=priority, d7=unused */
/* Output:      d5-d0=color, d6=priority, d7=unused */
int MDVDP::make_lut_bg(int bx, int ax)
{
    int bf, bp, b;
    int af, ap, a;
    int x = 0;
    int c;

    bf = (bx & 0x7F);
    bp = (bx >> 6) & 1;
    b  = (bx & 0x0F);
    
    af = (ax & 0x7F);   
    ap = (ax >> 6) & 1;
    a  = (ax & 0x0F);

    c = (ap ? (a ? af : (b ? bf : x)) : \
        (bp ? (b ? bf : (a ? af : x)) : \
        (     (a ? af : (b ? bf : x)) )));

    /* Strip palette bits from transparent pixels */
    if((c & 0x0F) == 0x00) c = (c & 0xC0);

    return (c);
}


/* Input (bx):  d5-d0=color, d6=priority, d7=sprite pixel marker */
/* Input (sx):  d5-d0=color, d6=priority, d7=unused */
/* Output:      d5-d0=color, d6=zero, d7=sprite pixel marker */
int MDVDP::make_lut_obj(int bx, int sx)
{
    int bf, bp, bs, b;
    int sf, sp, s;
    int c;

    bf = (bx & 0x3F);
    bs = (bx >> 7) & 1;
    bp = (bx >> 6) & 1;
    b  = (bx & 0x0F);
    
    sf = (sx & 0x3F);
    sp = (sx >> 6) & 1;
    s  = (sx & 0x0F);

    if(s == 0) return bx;

    if(bs)
    {
        c = bf;
    }
    else
    {
        c = (sp ? (s ? sf : bf)  : \
            (bp ? (b ? bf : (s ? sf : bf)) : \
                  (s ? sf : bf) ));
    }

    /* Strip palette bits from transparent pixels */
    if((c & 0x0F) == 0x00) c = (c & 0xC0);

    return (c | 0x80);
}


/* Input (bx):  d5-d0=color, d6=priority, d7=unused */
/* Input (sx):  d5-d0=color, d6=priority, d7=unused */
/* Output:      d5-d0=color, d6=priority, d7=intensity select (half/normal) */
int MDVDP::make_lut_bg_ste(int bx, int ax)
{
    int bf, bp, b;
    int af, ap, a;
    int gi;
    int x = 0;
    int c;

    bf = (bx & 0x7F);
    bp = (bx >> 6) & 1;
    b  = (bx & 0x0F);
    
    af = (ax & 0x7F);   
    ap = (ax >> 6) & 1;
    a  = (ax & 0x0F);

    gi = (ap | bp) ? 0x80 : 0x00;

    c = (ap ? (a ? af  : (b ? bf  : x  )) : \
        (bp ? (b ? bf  : (a ? af  : x  )) : \
        (     (a ? af : (b ? bf : x)) )));

    c |= gi;

    /* Strip palette bits from transparent pixels */
    if((c & 0x0F) == 0x00) c = (c & 0xC0);

    return (c);
}


/* Input (bx):  d5-d0=color, d6=priority, d7=sprite pixel marker */
/* Input (sx):  d5-d0=color, d6=priority, d7=unused */
/* Output:      d5-d0=color, d6=priority, d7=sprite pixel marker */
int MDVDP::make_lut_obj_ste(int bx, int sx)
{
    int bf, bs;
    int sf;
    int c;

    bf = (bx & 0x7F);   
    bs = (bx >> 7) & 1; 
    sf = (sx & 0x7F);

    if((sx & 0x0F) == 0) return bx;

    c = (bs) ? bf : sf;

    /* Strip palette bits from transparent pixels */
    if((c & 0x0F) == 0x00) c = (c & 0xC0);

    return (c | 0x80);
}


/* Input (bx):  d5-d0=color, d6=priority, d7=intensity (half/normal) */
/* Input (sx):  d5-d0=color, d6=priority, d7=sprite marker */
/* Output:      d5-d0=color, d6=intensity (half/normal), d7=(double/invalid) */
int MDVDP::make_lut_bgobj_ste(int bx, int sx)
{
    int c;

    int bf = (bx & 0x3F);
    int bp = (bx >> 6) & 1;
    int bi = (bx & 0x80) ? 0x40 : 0x00;
    int b  = (bx & 0x0F);

    int sf = (sx & 0x3F);
    int sp = (sx >> 6) & 1;
    int si = (sx & 0x40);
    int s  = (sx & 0x0F);

    if(bi & 0x40) si |= 0x40;

    if(sp)
    {
        if(s)
        {            
            if((sf & 0x3E) == 0x3E)
            {
                if(sf & 1)
                {
                    c = (bf | 0x00);
                }
                else
                {
                    c = (bx & 0x80) ? (bf | 0x80) : (bf | 0x40);
                }
            }
            else
            {
                if(sf == 0x0E || sf == 0x1E || sf == 0x2E)
                {
                    c = (sf | 0x40);
                }
                else
                {
                    c = (sf | si);
                }
            }
        }
        else
        {
            c = (bf | bi);
        }
    }
    else
    {
        if(bp)
        {
            if(b)
            {
                c = (bf | bi);
            }
            else
            {
                if(s)
                {
                    if((sf & 0x3E) == 0x3E)
                    {
                        if(sf & 1)
                        {
                            c = (bf | 0x00);
                        }
                        else
                        {
                            c = (bx & 0x80) ? (bf | 0x80) : (bf | 0x40);
                        }
                    }
                    else
                    {
                        if(sf == 0x0E || sf == 0x1E || sf == 0x2E)
                        {
                            c = (sf | 0x40);
                        }
                        else
                        {
                            c = (sf | si);
                        }
                    }
                }
                else
                {
                    c = (bf | bi);
                }
            }
        }
        else
        {
            if(s)
            {
                if((sf & 0x3E) == 0x3E)
                {
                    if(sf & 1)
                    {
                        c = (bf | 0x00);
                    }
                    else
                    {
                        c = (bx & 0x80) ? (bf | 0x80) : (bf | 0x40);
                    }
                }
                else
                {
                    if(sf == 0x0E || sf == 0x1E || sf == 0x2E)
                    {
                        c = (sf | 0x40);
                    }
                    else
                    {
                        c = (sf | si);
                    }
                }
            }
            else
            {                    
                c = (bf | bi);
            }
        }
    }

    if((c & 0x0f) == 0x00) c = (c & 0xC0);

    return (c);
}

/*--------------------------------------------------------------------------*/
/* Remap functions                                                          */
/*--------------------------------------------------------------------------*/
template<typename T>
void MDVDP::CopyLineSurface(const uint8 *src, const unsigned cvp_line, const unsigned width)
{
     T *out = &surface->pix<T>()[(cvp_line * (espec->InterlaceOn ? 2 : 1) + espec->InterlaceField) * surface->pitchinpix];

     if(!WantAutoAspect)
     {
      int half_diff = (320 - width) >> 1;
      const uint32 cb = pixel_32[0x40 | border]; //surface->MakeColor(0,0,0);

      for(int i = 0; i < half_diff; i++)
      {
       out[i] = cb;
       out[half_diff + width + i] = cb;
      }
      out += (320 - width) >> 1;
     }

     for(unsigned i = 0; i < width; i++)
      out[i] = pixel_32[src[i]];
}

/*--------------------------------------------------------------------------*/
/* Merge functions                                                          */
/*--------------------------------------------------------------------------*/

void MDVDP::merge(uint8 *srca, uint8 *srcb, uint8 *dst, uint8 *table, int width)
{
    int i;
    for(i = 0; i < width; i += 1)
    {
        uint8 a = srca[i];
        uint8 b = srcb[i];
        uint8 c = table[(b << 8) | (a)];
        dst[i] = c;
    }
}

/*--------------------------------------------------------------------------*/
/* Color update functions                                                   */
/*--------------------------------------------------------------------------*/

void MDVDP::color_update(int index, uint16 data)
{
    if(reg[12] & 8)
    {
        pixel_32[0x00 | index] = pixel_32_lut[0][data];
        pixel_32[0x40 | index] = pixel_32_lut[1][data];
        pixel_32[0x80 | index] = pixel_32_lut[2][data];
    }
    else
    {
        uint32 temp = pixel_32_lut[1][data];
        pixel_32[0x00 | index] = temp;
        pixel_32[0x40 | index] = temp;
        pixel_32[0x80 | index] = temp;
    }
}

/*--------------------------------------------------------------------------*/
/* Object render functions                                                  */
/*--------------------------------------------------------------------------*/

void MDVDP::parse_satb(int line)
{
    static const uint8 sizetab[] = {8, 16, 24, 32};
    uint8 *p, *q, link = 0;
    uint16 ypos;
    int pixel_count = 0;
    int max_pixel_count = (reg[12] & 1) ? 320 : 256;

    int count;
    int height;

    int limit = (reg[12] & 1) ? 20 : 16;
    int total = (reg[12] & 1) ? 80 : 64;

    object_index_count = 0;

    for(count = 0; count < total; count += 1)
    {
        q = &sat[link << 3];
        p = &vram[satb + (link << 3)];

        ypos = MDFN_de16lsb<true>(&q[0]);

        if(im2_flag)
            ypos = (ypos >> 1) & 0x1FF;
        else
            ypos &= 0x1FF;

        height = sizetab[q[3] & 3];

        if((line >= ypos) && (line < (ypos + height)))
        {
	    pixel_count += sizetab[(q[3] >> 2) & 3];

            if(pixel_count > max_pixel_count)
            {
             status |= 0x40;
             return;
            }

            object_info[object_index_count].ypos = MDFN_de16lsb<true>(&q[0]);
            object_info[object_index_count].xpos = MDFN_de16lsb<true>(&p[6]);

            // using xpos from internal satb stops sprite x
            // scrolling in bloodlin.bin,
            // but this seems to go against the test prog
           //object_info[object_index_count].xpos = MDFN_de16lsb(&q[6]);
            object_info[object_index_count].attr = MDFN_de16lsb<true>(&p[4]);
            object_info[object_index_count].size = q[3];
            object_info[object_index_count].index = count;

            object_index_count += 1;

            if(object_index_count == limit)
            {
                status |= 0x40;
                return;
            }
        }

        link = q[2] & 0x7F;
        if(link == 0) break;
    }
}

void MDVDP::render_obj(int line, uint8 *buf, uint8 *table)
{
    uint16 ypos;
    uint16 attr;
    uint16 xpos;
    uint8 sizetab[] = {8, 16, 24, 32};
    uint8 size;
    uint8 *src;

    int count;
    int pixellimit = (reg[12] & 1) ? 320 : 256;
    int pixelcount = 0;
    int width;
    int v_line;
    int column;
    int sol_flag = 0;
    int left = 0x80;
    int right = 0x80 + ((reg[12] & 1) ? 320 : 256);

    uint8 *s, *lb;
    uint16 name, index;
    uint8 palette;

    int attr_mask, nt_row;

    if(object_index_count == 0) return;

    for(count = 0; count < object_index_count; count += 1)
    {
        size = object_info[count].size & 0x0f;
        xpos = object_info[count].xpos;
        xpos &= 0x1ff;

        width = sizetab[(size >> 2) & 3];

        if(xpos != 0) sol_flag = 1;
        else
        if(xpos == 0 && sol_flag) return;

        if(pixelcount > pixellimit) return;
        pixelcount += width;

        if(((xpos + width) >= left) && (xpos < right))
        {
            ypos = object_info[count].ypos;
            ypos &= 0x1ff;

            attr = object_info[count].attr;
            attr_mask = (attr & 0x1800);

            palette = (attr >> 9) & 0x70;

            v_line = (line - ypos);
            nt_row = (v_line >> 3) & 3;
            v_line = (v_line & 7) << 1;

            name = (attr & 0x07FF);
            s = &name_lut[((attr >> 3) & 0x300) | (size << 4) | (nt_row << 2)];

            lb = (uint8 *)&buf[0x20 + (xpos - 0x80)];
            width >>= 3;
            for(column = 0; column < width; column += 1, lb+=8)
            {
                index = attr_mask | ((name + s[column]) & 0x07FF);
                src = (uint8 *)&bg_pattern_cache[(index << 4) | (v_line)];
                DRAW_SPRITE_TILE;
            }
        }
    }
}

void MDVDP::render_obj_im2(int line, uint8 *buf, uint8 *table)
{
    uint16 ypos;
    uint16 attr;
    uint16 xpos;
    uint8 sizetab[] = {8, 16, 24, 32};
    uint8 size;
    uint8 *src;

    int count;
    int pixellimit = (reg[12] & 1) ? 320 : 256;
    int pixelcount = 0;
    int width;
    int v_line;
    int column;
    int sol_flag = 0;
    int left = 0x80;
    int right = 0x80 + ((reg[12] & 1) ? 320 : 256);

    uint8 *s, *lb;
    uint16 name, index;
    uint8 palette;
    uint32 offs;

    int attr_mask, nt_row;

    if(object_index_count == 0) return;

    for(count = 0; count < object_index_count; count += 1)
    {
        size = object_info[count].size & 0x0f;
        xpos = object_info[count].xpos;
        xpos &= 0x1ff;

        width = sizetab[(size >> 2) & 3];

        if(xpos != 0) sol_flag = 1;
        else
        if(xpos == 0 && sol_flag) return;

        if(pixelcount > pixellimit) return;
        pixelcount += width;

        if(((xpos + width) >= left) && (xpos < right))
        {
            ypos = object_info[count].ypos;
            ypos = (ypos >> 1) & 0x1ff;

            attr = object_info[count].attr;
            attr_mask = (attr & 0x1800);

            palette = (attr >> 9) & 0x70;

            v_line = (line - ypos);
            nt_row = (v_line >> 3) & 3;
            v_line = (((v_line & 7) << 1) | ((status >> 4) & 1)) << 1;

            name = (attr & 0x03FF);
            s = &name_lut[((attr >> 3) & 0x300) | (size << 4) | (nt_row << 2)];

            lb = (uint8 *)&buf[0x20 + (xpos - 0x80)];

            width >>= 3;
            for(column = 0; column < width; column += 1, lb+=8)
            {
                index = (name + s[column]) & 0x3ff;
                offs = (index << 5) | (attr_mask << 4) | v_line;
                if(attr & 0x1000) offs ^= 0x10;

                src = (uint8 *)&bg_pattern_cache[offs];
                DRAW_SPRITE_TILE;
            }
        }
    }
}




}







