/***************************************************************************************
 *  Genesis Plus
 *  CD graphics processor
 *
 *  Copyright (C) 2012  Eke-Eke (Genesis Plus GX)
 *
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************************/
#include "../pico_int.h"
#include "genplus_macros.h"

typedef struct
{
  //uint32 cycles;                    /* current cycles count for graphics operation */
  //uint32 cyclesPerLine;             /* current graphics operation timings */
  uint32 dotMask;                   /* stamp map size mask */
  uint16 *tracePtr;                 /* trace vector pointer */
  uint16 *mapPtr;                   /* stamp map table base address */
  uint8 stampShift;                 /* stamp pixel shift value (related to stamp size) */
  uint8 mapShift;                   /* stamp map table shift value (related to stamp map size) */
  uint16 bufferOffset;              /* image buffer column offset */
  uint32 bufferStart;               /* image buffer start index */
  uint32 y_step;                    /* pico: render line step */
  uint8 lut_prio[4][0x10][0x10];    /* WORD-RAM data writes priority lookup table */
  uint8 lut_pixel[0x200];           /* Graphics operation dot offset lookup table */
  uint8 lut_cell[0x100];            /* Graphics operation stamp offset lookup table */
} gfx_t;

static gfx_t gfx;

static void gfx_schedule(void);

/***************************************************************/
/*      Rotation / Scaling operation (2M Mode)                 */
/***************************************************************/

void gfx_init(void)
{
  int i, j;
  uint8 mask, row, col, temp;

  memset(&gfx, 0, sizeof(gfx));

  /* Initialize priority modes lookup table */
  for (i = 0; i < 0x10; i++)
  {
    for (j = 0; j < 0x10; j++)
    {
      /* normal */
      gfx.lut_prio[0][i][j] = j;
      /* underwrite */
      gfx.lut_prio[1][i][j] = i ? i : j;
      /* overwrite */
      gfx.lut_prio[2][i][j] = j ? j : i;
      /* invalid */
      gfx.lut_prio[3][i][j] = i;
    }
  }

  /* Initialize cell lookup table             */
  /* table entry = yyxxshrr (8 bits)          */
  /* with: yy = cell row (0-3)                */
  /*       xx = cell column (0-3)             */
  /*        s = stamp size (0=16x16, 1=32x32) */
  /*      hrr = HFLIP & ROTATION bits         */
  for (i=0; i<0x100; i++)
  {
    /* one stamp = 2x2 cells (16x16) or 4x4 cells (32x32) */
    mask = (i & 8) ? 3 : 1;
    row = (i >> 6) & mask;
    col = (i >> 4) & mask;

    if (i & 4) { col = col ^ mask; }  /* HFLIP (always first)  */ 
    if (i & 2) { col = col ^ mask; row = row ^ mask; }  /* ROLL1 */
    if (i & 1) { temp = col; col = row ^ mask; row = temp; }  /* ROLL0  */

    /* cell offset (0-3 or 0-15) */
    gfx.lut_cell[i] = row + col * (mask + 1);
  }

  /* Initialize pixel lookup table      */
  /* table entry = yyyxxxhrr (9 bits)   */
  /* with:  yyy = pixel row  (0-7)      */
  /*        xxx = pixel column (0-7)    */
  /*        hrr = HFLIP & ROTATION bits */
  for (i=0; i<0x200; i++)
  {
    /* one cell = 8x8 pixels */
    row = (i >> 6) & 7;
    col = (i >> 3) & 7;

    if (i & 4) { col = col ^ 7; }   /* HFLIP (always first) */ 
    if (i & 2) { col = col ^ 7; row = row ^ 7; }  /* ROLL1 */
    if (i & 1) { temp = col; col = row ^ 7; row = temp; } /* ROLL0 */

    /* pixel offset (0-63) */
    gfx.lut_pixel[i] = col + row * 8;
  }
}

int gfx_context_save(uint8 *state)
{
  uint32 tmp32;
  int bufferptr = 0;

  //save_param(&gfx.cycles, sizeof(gfx.cycles));
  //save_param(&gfx.cyclesPerLine, sizeof(gfx.cyclesPerLine));
  save_param(&gfx.dotMask, sizeof(gfx.dotMask));
  save_param(&gfx.stampShift, sizeof(gfx.stampShift));
  save_param(&gfx.mapShift, sizeof(gfx.mapShift));
  save_param(&gfx.bufferOffset, sizeof(gfx.bufferOffset));
  save_param(&gfx.bufferStart, sizeof(gfx.bufferStart));

  tmp32 = (uint8 *)(gfx.tracePtr) - Pico_mcd->word_ram2M;
  save_param(&tmp32, 4);

  tmp32 = (uint8 *)(gfx.mapPtr) - Pico_mcd->word_ram2M;
  save_param(&tmp32, 4);

  save_param(&gfx.y_step, sizeof(gfx.y_step));

  return bufferptr;
}

int gfx_context_load(const uint8 *state)
{
  uint32 tmp32;
  int bufferptr = 0;

  //load_param(&gfx.cycles, sizeof(gfx.cycles));
  //load_param(&gfx.cyclesPerLine, sizeof(gfx.cyclesPerLine));
  load_param(&gfx.dotMask, sizeof(gfx.dotMask));
  load_param(&gfx.stampShift, sizeof(gfx.stampShift));
  load_param(&gfx.mapShift, sizeof(gfx.mapShift));
  load_param(&gfx.bufferOffset, sizeof(gfx.bufferOffset));
  load_param(&gfx.bufferStart, sizeof(gfx.bufferStart));

  load_param(&tmp32, 4);
  gfx.tracePtr = (uint16 *)(Pico_mcd->word_ram2M + tmp32);

  load_param(&tmp32, 4);
  gfx.mapPtr = (uint16 *)(Pico_mcd->word_ram2M + tmp32);

  load_param(&gfx.y_step, sizeof(gfx.y_step));

  return bufferptr;
}

static void gfx_render(uint32 bufferIndex, uint32 width)
{
  uint8 pixel_in, pixel_out;
  uint16 stamp_data;
  uint32 stamp_index;
  uint32 priority;

  /* pixel map start position for current line (13.3 format converted to 13.11) */
  uint32 xpos = *gfx.tracePtr++ << 8;
  uint32 ypos = *gfx.tracePtr++ << 8;

  /* pixel map offset values for current line (5.11 format) */
  uint32 xoffset = (int16) *gfx.tracePtr++;
  uint32 yoffset = (int16) *gfx.tracePtr++;

  priority = (Pico_mcd->s68k_regs[2] << 8) | Pico_mcd->s68k_regs[3];
  priority = (priority >> 3) & 0x03;

  /* process all dots */
  while (width--)
  {
    /* check if stamp map is repeated */
    if (Pico_mcd->s68k_regs[0x58+1] & 0x01)
    {
      /* stamp map range */
      xpos &= gfx.dotMask;
      ypos &= gfx.dotMask;
    }
    else
    {
      /* 24-bit range */
      xpos &= 0xffffff;
      ypos &= 0xffffff;
    }

    /* check if pixel is outside stamp map */
    if ((xpos | ypos) & ~gfx.dotMask)
    {
      /* force pixel output to 0 */
      pixel_out = 0x00;
    }
    else
    {
      /* read stamp map table data */
      stamp_data = gfx.mapPtr[(xpos >> gfx.stampShift) | ((ypos >> gfx.stampShift) << gfx.mapShift)];

      /* stamp generator base index                                     */
      /* sss ssssssss ccyyyxxx (16x16) or sss sssssscc ccyyyxxx (32x32) */
      /* with:  s = stamp number (1 stamp = 16x16 or 32x32 pixels)      */
      /*        c = cell offset  (0-3 for 16x16, 0-15 for 32x32)        */
      /*      yyy = line offset  (0-7)                                  */
      /*      xxx = pixel offset (0-7)                                  */
      stamp_index = (stamp_data & 0x7ff) << 8;

      if (stamp_index)
      {
        /* extract HFLIP & ROTATION bits */
        stamp_data = (stamp_data >> 13) & 7;

        /* cell offset (0-3 or 0-15)                             */
        /* table entry = yyxxshrr (8 bits)                       */
        /* with: yy = cell row  (0-3) = (ypos >> (11 + 3)) & 3   */
        /*       xx = cell column (0-3) = (xpos >> (11 + 3)) & 3 */
        /*        s = stamp size (0=16x16, 1=32x32)              */
        /*      hrr = HFLIP & ROTATION bits                      */
        stamp_index |= gfx.lut_cell[
          stamp_data | ((Pico_mcd->s68k_regs[0x58+1] & 0x02) << 2 )
          | ((ypos >> 8) & 0xc0) | ((xpos >> 10) & 0x30)] << 6;
            
        /* pixel  offset (0-63)                              */
        /* table entry = yyyxxxhrr (9 bits)                  */
        /* with: yyy = pixel row  (0-7) = (ypos >> 11) & 7   */
        /*       xxx = pixel column (0-7) = (xpos >> 11) & 7 */
        /*       hrr = HFLIP & ROTATION bits                 */
        stamp_index |= gfx.lut_pixel[stamp_data | ((xpos >> 8) & 0x38) | ((ypos >> 5) & 0x1c0)];

        /* read pixel pair (2 pixels/byte) */
        pixel_out = READ_BYTE(Pico_mcd->word_ram2M, stamp_index >> 1);

        /* extract left or rigth pixel */
        if (stamp_index & 1)
        {
           pixel_out &= 0x0f;
        }
        else
        {
           pixel_out >>= 4;
        }
      }
      else
      {
        /* stamp 0 is not used: force pixel output to 0 */
        pixel_out = 0x00;
      }
    }

    /* read out paired pixel data */
    pixel_in = READ_BYTE(Pico_mcd->word_ram2M, bufferIndex >> 1);

    /* update left or rigth pixel */
    if (bufferIndex & 1)
    {
      /* priority mode write */
      pixel_out = gfx.lut_prio[priority][pixel_in & 0x0f][pixel_out];

      pixel_out |= (pixel_in & 0xf0);
    }
    else
    {
      /* priority mode write */
      pixel_out = gfx.lut_prio[priority][pixel_in >> 4][pixel_out];

      pixel_out = (pixel_out << 4) | (pixel_in & 0x0f);
    }

    /* write data to image buffer */
    WRITE_BYTE(Pico_mcd->word_ram2M, bufferIndex >> 1, pixel_out);

    /* check current pixel position  */
    if ((bufferIndex & 7) != 7)
    {
      /* next pixel */
      bufferIndex++;
    }
    else
    {
      /* next cell: increment image buffer offset by one column (minus 7 pixels) */
      bufferIndex += gfx.bufferOffset;
    }

    /* increment pixel position */
    xpos += xoffset;
    ypos += yoffset;
  }
}

void gfx_start(unsigned int base)
{
  /* make sure 2M mode is enabled */
  if (!(Pico_mcd->s68k_regs[3] & 0x04))
  {
    uint32 mask = 0;
    uint32 reg;
    
    /* trace vector pointer */
    gfx.tracePtr = (uint16 *)(Pico_mcd->word_ram2M + ((base << 2) & 0x3fff8));

    /* stamps & stamp map size */
    switch ((Pico_mcd->s68k_regs[0x58+1] >> 1) & 0x03)
    {
      case 0:
        gfx.dotMask = 0x07ffff;   /* 256x256 dots/map  */
        gfx.stampShift = 11 + 4;  /* 16x16 dots/stamps */
        gfx.mapShift = 4;         /* 16x16 stamps/map  */
        mask = 0x3fe00;           /* 512 bytes/table   */
        break;

      case 1:
        gfx.dotMask = 0x07ffff;   /* 256x256 dots/map  */
        gfx.stampShift = 11 + 5;  /* 32x32 dots/stamps */
        gfx.mapShift = 3;         /* 8x8 stamps/map    */
        mask = 0x3ff80;           /* 128 bytes/table   */
        break;

      case 2:
        gfx.dotMask = 0x7fffff;   /* 4096*4096 dots/map */
        gfx.stampShift = 11 + 4;  /* 16x16 dots/stamps  */
        gfx.mapShift = 8;         /* 256x256 stamps/map */
        mask = 0x20000;           /* 131072 bytes/table */
        break;

      case 3:
        gfx.dotMask = 0x7fffff;   /* 4096*4096 dots/map */
        gfx.stampShift = 11 + 5;  /* 32x32 dots/stamps  */
        gfx.mapShift = 7;         /* 128x128 stamps/map */
        mask = 0x38000;           /* 32768 bytes/table  */
        break;
    }

    /* stamp map table base address */
    reg = (Pico_mcd->s68k_regs[0x5a] << 8) | Pico_mcd->s68k_regs[0x5b];
    gfx.mapPtr = (uint16 *)(Pico_mcd->word_ram2M + ((reg << 2) & mask));

    /* image buffer column offset (64 pixels/cell, minus 7 pixels to restart at cell beginning) */
    gfx.bufferOffset = (((Pico_mcd->s68k_regs[0x5c+1] & 0x1f) + 1) << 6) - 7;

    /* image buffer start index in dot units (2 pixels/byte) */
    reg = (Pico_mcd->s68k_regs[0x5e] << 8) | Pico_mcd->s68k_regs[0x5f];
    gfx.bufferStart = (reg << 3) & 0x7ffc0;

    /* add image buffer horizontal dot offset */
    gfx.bufferStart += (Pico_mcd->s68k_regs[0x60+1] & 0x3f);

    /* reset GFX chip cycle counter */
    //gfx.cycles = cycles;

    /* update GFX chip timings (see AC3:Thunderhawk / Thunderstrike) */
    //gfx.cyclesPerLine = 4 * 5 * scd.regs[0x62>>1].w;

    /* start graphics operation */
    Pico_mcd->s68k_regs[0x58] = 0x80;

    gfx_schedule();
  }
}

/* PicoDrive specific */
#define UPDATE_CYCLES 20000

static void gfx_schedule(void)
{
  int w, h, cycles;
  int y_step;

  w = (Pico_mcd->s68k_regs[0x62] << 8) | Pico_mcd->s68k_regs[0x63];
  h = (Pico_mcd->s68k_regs[0x64] << 8) | Pico_mcd->s68k_regs[0x65];

  cycles = 5 * w * h;
  if (cycles > UPDATE_CYCLES)
    y_step = (UPDATE_CYCLES + 5 * w - 1) / (5 * w);
  else
    y_step = h;

  gfx.y_step = y_step;
  pcd_event_schedule_s68k(PCD_EVENT_GFX, 5 * w * y_step);
}

void gfx_update(unsigned int cycles)
{
  int lines, lines_reg;
  int w;

  if (!(Pico_mcd->s68k_regs[0x58] & 0x80))
    return;

  w = (Pico_mcd->s68k_regs[0x62] << 8) | Pico_mcd->s68k_regs[0x63];
  lines = (Pico_mcd->s68k_regs[0x64] << 8) | Pico_mcd->s68k_regs[0x65];
  lines_reg = lines - gfx.y_step;

  if (lines_reg <= 0) {
    Pico_mcd->s68k_regs[0x58] = 0;
    Pico_mcd->s68k_regs[0x64] =
    Pico_mcd->s68k_regs[0x65] = 0;

    if (Pico_mcd->s68k_regs[0x33] & PCDS_IEN1) {
      elprintf(EL_INTS|EL_CD, "s68k: gfx_cd irq 1");
      SekInterruptS68k(1);
    }
  }
  else {
    Pico_mcd->s68k_regs[0x64] = lines_reg >> 8;
    Pico_mcd->s68k_regs[0x65] = lines_reg;

    if (lines > gfx.y_step)
      lines = gfx.y_step;

    pcd_event_schedule(cycles, PCD_EVENT_GFX, 5 * w * lines);
  }

  if (PicoOpt & POPT_EN_MCD_GFX)
  {
    /* render lines */
    while (lines--)
    {
      /* process dots to image buffer */
      gfx_render(gfx.bufferStart, w);

      /* increment image buffer start index for next line (8 pixels/line) */
      gfx.bufferStart += 8;
    }
  }
}

// vim:shiftwidth=2:ts=2:expandtab
