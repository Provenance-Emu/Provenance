/***************************************************************************************
 *  Genesis Plus
 *  Video Display Processor (68k & Z80 CPU interface)
 *
 *  Support for SG-1000 (TMS99xx & 315-5066), Master System (315-5124 & 315-5246), Game Gear & Mega Drive VDP
 *
 *  Copyright (C) 1998-2003  Charles Mac Donald (original code)
 *  Copyright (C) 2007-2017  Eke-Eke (Genesis Plus GX)
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

#include "shared.h"
#include "hvc.h"

/* Mark a pattern as modified */
#define MARK_BG_DIRTY(addr)                         \
{                                                   \
  name = (addr >> 5) & 0x7FF;                       \
  if (bg_name_dirty[name] == 0)                     \
  {                                                 \
    bg_name_list[bg_list_index++] = name;           \
  }                                                 \
  bg_name_dirty[name] |= (1 << ((addr >> 2) & 7));  \
}

/* VDP context */
uint8 ALIGNED_(4) sat[0x400];    /* Internal copy of sprite attribute table */
uint8 ALIGNED_(4) vram[0x10000]; /* Video RAM (64K x 8-bit) */
uint8 ALIGNED_(4) cram[0x80];    /* On-chip color RAM (64 x 9-bit) */
uint8 ALIGNED_(4) vsram[0x80];   /* On-chip vertical scroll RAM (40 x 11-bit) */
uint8 reg[0x20];                 /* Internal VDP registers (23 x 8-bit) */
uint8 hint_pending;              /* 0= Line interrupt is pending */
uint8 vint_pending;              /* 1= Frame interrupt is pending */
uint16 status;                   /* VDP status flags */
uint32 dma_length;               /* DMA remaining length */

/* Global variables */
uint16 ntab;                      /* Name table A base address */
uint16 ntbb;                      /* Name table B base address */
uint16 ntwb;                      /* Name table W base address */
uint16 satb;                      /* Sprite attribute table base address */
uint16 hscb;                      /* Horizontal scroll table base address */
uint8 bg_name_dirty[0x800];       /* 1= This pattern is dirty */
uint16 bg_name_list[0x800];       /* List of modified pattern indices */
uint16 bg_list_index;             /* # of modified patterns in list */
uint8 hscroll_mask;               /* Horizontal Scrolling line mask */
uint8 playfield_shift;            /* Width of planes A, B (in bits) */
uint8 playfield_col_mask;         /* Playfield column mask */
uint16 playfield_row_mask;        /* Playfield row mask */
uint16 vscroll;                   /* Latched vertical scroll value */
uint8 odd_frame;                  /* 1: odd field, 0: even field */
uint8 im2_flag;                   /* 1= Interlace mode 2 is being used */
uint8 interlaced;                 /* 1: Interlaced mode 1 or 2 */
uint8 vdp_pal;                    /* 1: PAL , 0: NTSC (default) */
uint8 h_counter;                  /* Horizontal counter */
uint16 v_counter;                 /* Vertical counter */
uint16 vc_max;                    /* Vertical counter overflow value */
uint16 lines_per_frame;           /* PAL: 313 lines, NTSC: 262 lines */
uint16 max_sprite_pixels;         /* Max. sprites pixels per line (parsing & rendering) */
int32 fifo_write_cnt;             /* VDP FIFO write count */
uint32 fifo_slots;                /* VDP FIFO access slot count */
uint32 hvc_latch;                 /* latched HV counter */
const uint8 *hctab;               /* pointer to H Counter table */

/* Function pointers */
void (*vdp_68k_data_w)(unsigned int data);
void (*vdp_z80_data_w)(unsigned int data);
unsigned int (*vdp_68k_data_r)(void);
unsigned int (*vdp_z80_data_r)(void);

/* Function prototypes */
static void vdp_68k_data_w_m4(unsigned int data);
static void vdp_68k_data_w_m5(unsigned int data);
static unsigned int vdp_68k_data_r_m4(void);
static unsigned int vdp_68k_data_r_m5(void);
static void vdp_z80_data_w_m4(unsigned int data);
static void vdp_z80_data_w_m5(unsigned int data);
static unsigned int vdp_z80_data_r_m4(void);
static unsigned int vdp_z80_data_r_m5(void);
static void vdp_z80_data_w_ms(unsigned int data);
static void vdp_z80_data_w_gg(unsigned int data);
static void vdp_z80_data_w_sg(unsigned int data);
static void vdp_bus_w(unsigned int data);
static void vdp_fifo_update(unsigned int cycles);
static void vdp_reg_w(unsigned int r, unsigned int d, unsigned int cycles);
static void vdp_dma_68k_ext(unsigned int length);
static void vdp_dma_68k_ram(unsigned int length);
static void vdp_dma_68k_io(unsigned int length);
static void vdp_dma_copy(unsigned int length);
static void vdp_dma_fill(unsigned int length);

/* Tables that define the playfield layout */
static const uint8 hscroll_mask_table[] = { 0x00, 0x07, 0xF8, 0xFF };
static const uint8 shift_table[]        = { 6, 7, 0, 8 };
static const uint8 col_mask_table[]     = { 0x0F, 0x1F, 0x0F, 0x3F };
static const uint16 row_mask_table[]    = { 0x0FF, 0x1FF, 0x2FF, 0x3FF };

static uint8 border;          /* Border color index */
static uint8 pending;         /* Pending write flag */
static uint8 code;            /* Code register */
static uint8 dma_type;        /* DMA mode */
static uint16 addr;           /* Address register */
static uint16 addr_latch;     /* Latched A15, A14 of address */
static uint16 sat_base_mask;  /* Base bits of SAT */
static uint16 sat_addr_mask;  /* Index bits of SAT */
static uint16 dma_src;        /* DMA source address */
static uint32 dma_endCycles;  /* 68k cycles to DMA end */
static int dmafill;           /* DMA Fill pending flag */
static int cached_write;      /* 2nd part of 32-bit CTRL port write (Genesis mode) or LSB of CRAM data (Game Gear mode) */
static uint16 fifo[4];        /* FIFO ring-buffer */
static int fifo_idx;          /* FIFO write index */
static int fifo_byte_access;  /* FIFO byte access flag */
static uint32 fifo_cycles;    /* FIFO next access cycle */
static int *fifo_timing;      /* FIFO slots timing table */

 /* set Z80 or 68k interrupt lines */
static void (*set_irq_line)(unsigned int level);
static void (*set_irq_line_delay)(unsigned int level);

/* Vertical counter overflow values (see hvc.h) */
static const uint16 vc_table[4][2] = 
{
  /* NTSC, PAL */
  {0xDA , 0xF2},  /* Mode 4 (192 lines) */
  {0xEA , 0x102}, /* Mode 5 (224 lines) */
  {0xDA , 0xF2},  /* Mode 4 (192 lines) */
  {0x106, 0x10A}  /* Mode 5 (240 lines) */
};

/* FIFO access slots timings */
static const int fifo_timing_h32[16+4] = 
{
  230, 510, 810, 970, 1130, 1450, 1610, 1770, 2090, 2250, 2410, 2730, 2890, 3050, 3350, 3370,
  MCYCLES_PER_LINE + 230, MCYCLES_PER_LINE + 510, MCYCLES_PER_LINE + 810, MCYCLES_PER_LINE + 970, 
};

static const int fifo_timing_h40[18+4] = 
{
  352, 820, 948, 1076, 1332, 1460, 1588, 1844, 1972, 2100, 2356, 2484, 2612, 2868, 2996, 3124, 3364, 3380,
  MCYCLES_PER_LINE + 352, MCYCLES_PER_LINE + 820, MCYCLES_PER_LINE + 948, MCYCLES_PER_LINE + 1076, 
};

/* DMA Timings (number of access slots per line) */
static const uint8 dma_timing[2][2] =
{
/* H32, H40 */
  {16 , 18},  /* active display */
  {166, 204}  /* blank display */
};

/* DMA processing functions (set by VDP register 23 high nibble) */
static void (*const dma_func[16])(unsigned int length) =
{
  /* 0x0-0x3 : DMA from 68k bus $000000-$7FFFFF (external area) */
  vdp_dma_68k_ext,vdp_dma_68k_ext,vdp_dma_68k_ext,vdp_dma_68k_ext,

  /* 0x4-0x7 : DMA from 68k bus $800000-$FFFFFF (internal RAM & I/O) */
  vdp_dma_68k_ram, vdp_dma_68k_io,vdp_dma_68k_ram,vdp_dma_68k_ram,

  /* 0x8-0xB : DMA Fill */
  vdp_dma_fill,vdp_dma_fill,vdp_dma_fill,vdp_dma_fill,

  /* 0xC-0xF : DMA Copy */
  vdp_dma_copy,vdp_dma_copy,vdp_dma_copy,vdp_dma_copy
};

/* BG rendering functions */
static void (*const render_bg_modes[16])(int line) =
{
  render_bg_m0,   /* Graphics I */
  render_bg_m2,   /* Graphics II */
  render_bg_m4,   /* Mode 4 */
  render_bg_m4,   /* Mode 4 */
  render_bg_m3,   /* Multicolor */
  render_bg_m3x,  /* Multicolor (Extended PG) */
  render_bg_m4,   /* Mode 4 */
  render_bg_m4,   /* Mode 4 */
  render_bg_m1,   /* Text */
  render_bg_m1x,  /* Text (Extended PG) */
  render_bg_m4,   /* Mode 4 */
  render_bg_m4,   /* Mode 4 */
  render_bg_inv,  /* Invalid (1+3) */
  render_bg_inv,  /* Invalid (1+2+3) */
  render_bg_m4,   /* Mode 4 */
  render_bg_m4,   /* Mode 4 */
};

/*--------------------------------------------------------------------------*/
/* Init, reset, context functions                                           */
/*--------------------------------------------------------------------------*/

void vdp_init(void)
{
  /* PAL/NTSC timings */
  lines_per_frame = vdp_pal ? 313: 262;

  /* CPU interrupt line(s)*/
  if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
  {
    /* 68k cpu */
    set_irq_line = m68k_set_irq;
    set_irq_line_delay = m68k_set_irq_delay;
  }
  else
  {
    /* Z80 cpu */
    set_irq_line = z80_set_irq_line;
    set_irq_line_delay = z80_set_irq_line;
  }
}

void vdp_reset(void)
{
  int i;

  memset ((char *) sat, 0, sizeof (sat));
  memset ((char *) vram, 0, sizeof (vram));
  memset ((char *) cram, 0, sizeof (cram));
  memset ((char *) vsram, 0, sizeof (vsram));
  memset ((char *) reg, 0, sizeof (reg));

  addr            = 0;
  addr_latch      = 0;
  code            = 0;
  pending         = 0;
  border          = 0;
  hint_pending    = 0;
  vint_pending    = 0;
  dmafill         = 0;
  dma_src         = 0;
  dma_type        = 0;
  dma_length      = 0;
  dma_endCycles   = 0;
  odd_frame       = 0;
  im2_flag        = 0;
  interlaced      = 0;
  fifo_write_cnt  = 0;
  fifo_cycles     = 0;
  fifo_slots      = 0;
  fifo_idx        = 0;
  cached_write    = -1;
  fifo_byte_access = 1;

  ntab = 0;
  ntbb = 0;
  ntwb = 0;
  satb = 0;
  hscb = 0;

  vscroll = 0;

  hscroll_mask        = 0x00;
  playfield_shift     = 6;
  playfield_col_mask  = 0x0F;
  playfield_row_mask  = 0x0FF;
  sat_base_mask       = 0xFE00;
  sat_addr_mask       = 0x01FF;

  /* reset pattern cache changes */
  bg_list_index = 0;
  memset ((char *) bg_name_dirty, 0, sizeof (bg_name_dirty));
  memset ((char *) bg_name_list, 0, sizeof (bg_name_list));

  /* default Window clipping */
  window_clip(0,0);

  /* reset VDP status (FIFO empty flag is set) */
  if (system_hw & SYSTEM_MD)
  {
    status = vdp_pal | 0x200;
  }
  else
  {
    status = 0;
  }

  /* default display area */
  bitmap.viewport.w   = 256;
  bitmap.viewport.h   = 192;
  bitmap.viewport.ow  = 256;
  bitmap.viewport.oh  = 192;

  /* default HVC */
  hvc_latch = 0x10000;
  hctab = cycle2hc32;
  vc_max = vc_table[0][vdp_pal];
  v_counter = bitmap.viewport.h;
  h_counter = 0xff;

  /* default sprite pixel width */
  max_sprite_pixels = 256;

  /* default FIFO access slots timings */
  fifo_timing = (int *)fifo_timing_h32;

  /* default overscan area */
  if ((system_hw == SYSTEM_GG) && !config.gg_extra)
  {
    /* Display area reduced to 160x144 if overscan is disabled */
    bitmap.viewport.x = (config.overscan & 2) ? 14 : -48;
    bitmap.viewport.y = (config.overscan & 1) ? (24 * (vdp_pal + 1)) : -24;
  }
  else
  {
    bitmap.viewport.x = (config.overscan & 2) * 7;
    bitmap.viewport.y = (config.overscan & 1) * 24 * (vdp_pal + 1);
  }

  /* default rendering mode */
  update_bg_pattern_cache = update_bg_pattern_cache_m4;
  if (system_hw < SYSTEM_MD)
  {
    /* Mode 0 */
    render_bg = render_bg_m0;
    render_obj = render_obj_tms;
    parse_satb = parse_satb_tms;
  }
  else
  {
    /* Mode 4 */
    render_bg = render_bg_m4;
    render_obj = render_obj_m4;
    parse_satb = parse_satb_m4;
  }

  /* default 68k bus interface (Mega Drive VDP only) */
  vdp_68k_data_w = vdp_68k_data_w_m4;
  vdp_68k_data_r = vdp_68k_data_r_m4;

  /* default Z80 bus interface */
  switch (system_hw)
  {
    case SYSTEM_SG:
    case SYSTEM_SGII:
    {
      /* SG-1000 (TMS99xx) or SG-1000 II (315-5066) VDP */
      vdp_z80_data_w = vdp_z80_data_w_sg;
      vdp_z80_data_r = vdp_z80_data_r_m4;
      break;
    }

    case SYSTEM_GG:
    {
      /* Game Gear VDP */
      vdp_z80_data_w = vdp_z80_data_w_gg;
      vdp_z80_data_r = vdp_z80_data_r_m4;
      break;
    }

    case SYSTEM_MARKIII:
    case SYSTEM_SMS:
    case SYSTEM_SMS2:
    case SYSTEM_GGMS:
    {
      /* Master System or Game Gear (in MS compatibility mode) VDP  */
      vdp_z80_data_w = vdp_z80_data_w_ms;
      vdp_z80_data_r = vdp_z80_data_r_m4;
      break;
    }

    default:
    {
      /* Mega Drive VDP (in MS compatibility mode) */
      vdp_z80_data_w = vdp_z80_data_w_m4;
      vdp_z80_data_r = vdp_z80_data_r_m4;
      break;
    }
  }

  /* H-INT is disabled on startup (verified on VA4 MD1 with 315-5313 VDP) */
  reg[10] = 0xFF;
  
  /* Master System specific */
  if ((system_hw & SYSTEM_SMS) && (!(config.bios & 1) || !(system_bios & SYSTEM_SMS)))
  {
    /* force registers initialization (normally done by BOOT ROM on all Master System models) */
    vdp_reg_w(0 , 0x36, 0);
    vdp_reg_w(1 , 0x80, 0);
    vdp_reg_w(2 , 0xFF, 0);
    vdp_reg_w(3 , 0xFF, 0);
    vdp_reg_w(4 , 0xFF, 0);
    vdp_reg_w(5 , 0xFF, 0);
    vdp_reg_w(6 , 0xFF, 0);

    /* Mode 4 */
    render_bg = render_bg_m4;
    render_obj = render_obj_m4;
    parse_satb = parse_satb_m4;
  }

  /* Mega Drive specific */
  else if (((system_hw == SYSTEM_MD) || (system_hw == SYSTEM_MCD)) && (config.bios & 1) && !(system_bios & SYSTEM_MD))
  {
    /* force registers initialization (normally done by BOOT ROM, only on Mega Drive model with TMSS) */
    vdp_reg_w(0 , 0x04, 0);
    vdp_reg_w(1 , 0x04, 0);
    vdp_reg_w(12, 0x81, 0);
    vdp_reg_w(15, 0x02, 0);
  }

  /* reset color palette */
  for(i = 0; i < 0x20; i ++)
  {
    color_update_m4(i, 0x00);
  }
  color_update_m4(0x40, 0x00);
}

int vdp_context_save(uint8 *state)
{
  int bufferptr = 0;

  save_param(sat, sizeof(sat));
  save_param(vram, sizeof(vram));
  save_param(cram, sizeof(cram));
  save_param(vsram, sizeof(vsram));
  save_param(reg, sizeof(reg));
  save_param(&addr, sizeof(addr));
  save_param(&addr_latch, sizeof(addr_latch));
  save_param(&code, sizeof(code));
  save_param(&pending, sizeof(pending));
  save_param(&status, sizeof(status));
  save_param(&dmafill, sizeof(dmafill));
  save_param(&fifo_idx, sizeof(fifo_idx));
  save_param(&fifo, sizeof(fifo));
  save_param(&h_counter, sizeof(h_counter));
  save_param(&hint_pending, sizeof(hint_pending));
  save_param(&vint_pending, sizeof(vint_pending));
  save_param(&dma_length, sizeof(dma_length));
  save_param(&dma_type, sizeof(dma_type));
  save_param(&dma_src, sizeof(dma_src));
  save_param(&cached_write, sizeof(cached_write));
  return bufferptr;
}

int vdp_context_load(uint8 *state)
{
  int i, bufferptr = 0;
  uint8 temp_reg[0x20];

  load_param(sat, sizeof(sat));
  load_param(vram, sizeof(vram));
  load_param(cram, sizeof(cram));
  load_param(vsram, sizeof(vsram));
  load_param(temp_reg, sizeof(temp_reg));

  /* restore VDP registers */
  if (system_hw < SYSTEM_MD)
  {
    if (system_hw >= SYSTEM_MARKIII)
    {
      for (i=0;i<0x10;i++) 
      {
        pending = 1;
        addr_latch = temp_reg[i];
        vdp_sms_ctrl_w(0x80 | i);
      }
    }
    else
    {
      /* TMS-99xx registers are updated directly to prevent spurious 4K->16K VRAM switching */
      for (i=0;i<0x08;i++) 
      {
        reg[i] = temp_reg[i];
      }

      /* Rendering mode */
      render_bg = render_bg_modes[((reg[0] & 0x02) | (reg[1] & 0x18)) >> 1];
    }
  }
  else
  {
    for (i=0;i<0x20;i++) 
    {
      vdp_reg_w(i, temp_reg[i], 0);
    }
  }

  load_param(&addr, sizeof(addr));
  load_param(&addr_latch, sizeof(addr_latch));
  load_param(&code, sizeof(code));
  load_param(&pending, sizeof(pending));
  load_param(&status, sizeof(status));
  load_param(&dmafill, sizeof(dmafill));
  load_param(&fifo_idx, sizeof(fifo_idx));
  load_param(&fifo, sizeof(fifo));
  load_param(&h_counter, sizeof(h_counter));
  load_param(&hint_pending, sizeof(hint_pending));
  load_param(&vint_pending, sizeof(vint_pending));
  load_param(&dma_length, sizeof(dma_length));
  load_param(&dma_type, sizeof(dma_type));
  load_param(&dma_src, sizeof(dma_src));
  load_param(&cached_write, sizeof(cached_write));

  /* restore FIFO byte access flag */
  fifo_byte_access = ((code & 0x0F) < 0x03);

  /* restore current NTSC/PAL mode */
  if (system_hw & SYSTEM_MD)
  {
    status = (status & ~1) | vdp_pal;
  }

  if (reg[1] & 0x04)
  {
    /* Mode 5 */
    bg_list_index = 0x800;

    /* reinitialize palette */
    color_update_m5(0, *(uint16 *)&cram[border << 1]);
    for(i = 1; i < 0x40; i++)
    {
      color_update_m5(i, *(uint16 *)&cram[i << 1]);
    }
  }
  else
  {
    /* Modes 0,1,2,3,4 */
    bg_list_index = 0x200;

    /* reinitialize palette */
    for(i = 0; i < 0x20; i ++)
    {
      color_update_m4(i, *(uint16 *)&cram[i << 1]);
    }
    color_update_m4(0x40, *(uint16 *)&cram[(0x10 | (border & 0x0F)) << 1]);
  }

  /* invalidate tile cache */
  for (i=0;i<bg_list_index;i++) 
  {
    bg_name_list[i]=i;
    bg_name_dirty[i]=0xFF;
  }

  return bufferptr;
}


/*--------------------------------------------------------------------------*/
/* DMA update function (Mega Drive VDP only)                                */
/*--------------------------------------------------------------------------*/

void vdp_dma_update(unsigned int cycles)
{
  unsigned int dma_cycles, dma_bytes;

  /* DMA transfer rate (bytes per line) 

      DMA Mode      Width       Display      Transfer Count
      -----------------------------------------------------
      68K > VDP     32-cell     Active       16
                                Blanking     166
                    40-cell     Active       18
                                Blanking     204
      VRAM Fill     32-cell     Active       15
                                Blanking     165
                    40-cell     Active       17
                                Blanking     203
      VRAM Copy     32-cell     Active       8
                                Blanking     83
                    40-cell     Active       9
                                Blanking     102

   'Active' is the active display period, 'Blanking' is either the vertical
   blanking period or when the display is forcibly blanked via register #1.

   The above transfer counts are all in bytes, unless the destination is
   CRAM or VSRAM for a 68K > VDP transfer, in which case it is in words.
  */
  unsigned int rate = dma_timing[(status & 8) || !(reg[1] & 0x40)][reg[12] & 1];

  /* Adjust for 68k bus DMA to VRAM (one word = 2 access) or DMA Copy (one read + one write = 2 access) */
  rate = rate >> (dma_type & 1);

  /* Remaining DMA cycles */
  if (status & 8)
  {
    /* Process DMA until the end of VBLANK */
    /* NOTE: DMA timings can not change during VBLANK because active display width cannot be modified. */
    /* Indeed, writing VDP registers during DMA is either impossible (when doing DMA from 68k bus, CPU */
    /* is locked) or will abort DMA operation (in case of DMA Fill or Copy). */
    dma_cycles = ((lines_per_frame - bitmap.viewport.h - 1) * MCYCLES_PER_LINE) - cycles;
  }
  else
  {
    /* Process DMA until the end of current line */
    dma_cycles = (mcycles_vdp + MCYCLES_PER_LINE) - cycles;
  }

  /* Remaining DMA bytes for that line */
  dma_bytes = (dma_cycles * rate) / MCYCLES_PER_LINE;

#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] DMA type %d (%d access/line)(%d cycles left)-> %d access (%d remaining) (%x)\n", v_counter, (v_counter + (cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, cycles, cycles%MCYCLES_PER_LINE,dma_type, rate, dma_cycles, dma_bytes, dma_length, m68k_get_reg(M68K_REG_PC));
#endif

  /* Check if DMA can be finished before the end of current line */
  if (dma_length < dma_bytes)
  {
    /* Adjust remaining DMA bytes */
    dma_bytes = dma_length;
    dma_cycles = (dma_bytes * MCYCLES_PER_LINE) / rate;
  }

  /* Update DMA timings */
  if (dma_type < 2)
  {
    /* 68K is frozen during DMA from 68k bus */
    m68k.cycles = cycles + dma_cycles;
#ifdef LOGVDP
    error("-->CPU frozen for %d cycles\n", dma_cycles);
#endif
  }
  else
  {
    /* Set DMA Busy flag */
    status |= 0x02;

    /* 68K is still running, set DMA end cycle */
    dma_endCycles = cycles + dma_cycles;
#ifdef LOGVDP
    error("-->DMA ends in %d cycles\n", dma_cycles);
#endif
  }

  /* Process DMA */
  if (dma_bytes)
  {
    /* Update DMA length */
    dma_length -= dma_bytes;

    /* Process DMA operation */
    dma_func[reg[23] >> 4](dma_bytes);

    /* Check if DMA is finished */
    if (!dma_length)
    {
      /* DMA source address registers are incremented during DMA (even DMA Fill) */
      uint16 end = reg[21] + (reg[22] << 8) + reg[19] + (reg[20] << 8);
      reg[21] = end & 0xff;
      reg[22] = end >> 8;

      /* DMA length registers are decremented during DMA */
      reg[19] = reg[20] = 0;

      /* perform cached write, if any */
      if (cached_write >= 0)
      {
        vdp_68k_ctrl_w(cached_write);
        cached_write = -1;
      }
    }
  }
}


/*--------------------------------------------------------------------------*/
/* Control port access functions                                            */
/*--------------------------------------------------------------------------*/

void vdp_68k_ctrl_w(unsigned int data)
{
  /* Check pending flag */
  if (pending == 0)
  {
    /* A single long word write instruction could have started DMA with the first word */
    if (dma_length)
    {
      /* 68k is frozen during 68k bus DMA */
      /* Second word should be written after DMA completion */
      /* See Formula One & Kawasaki Superbike Challenge */
      if (dma_type < 2)
      {
        /* Latch second control word for later */
        cached_write = data;
        return;
      }
    }

    /* Check CD0-CD1 bits */
    if ((data & 0xC000) == 0x8000)
    {
      /* VDP register write */
      vdp_reg_w((data >> 8) & 0x1F, data & 0xFF, m68k.cycles);
    }
    else
    {
      /* Set pending flag (Mode 5 only) */
      pending = reg[1] & 4;
    }

    /* Update address and code registers */
    addr = addr_latch | (data & 0x3FFF);
    code = ((code & 0x3C) | ((data >> 14) & 0x03));
  }
  else
  {
    /* Clear pending flag */
    pending = 0;

    /* Save address bits A15 and A14 */
    addr_latch = (data & 3) << 14;

    /* Update address and code registers */
    addr = addr_latch | (addr & 0x3FFF);
    code = ((code & 0x03) | ((data >> 2) & 0x3C));

    /* Detect DMA operation (CD5 bit set) */
    if (code & 0x20)
    {
      /* DMA must be enabled */
      if (reg[1] & 0x10)
      {
        /* DMA type */
        switch (reg[23] >> 6)
        {
          case 2:
          {
            /* DMA Fill */
            dma_type = 2;

            /* DMA is pending until next DATA port write */
            dmafill = 1;

            /* Set DMA Busy flag */
            status |= 0x02;

            /* DMA end cycle is not initialized yet (this prevents DMA Busy flag from being cleared on VDP status read) */
            dma_endCycles = 0xffffffff;
            break;
          }

          case 3:
          {
            /* DMA Copy */
            dma_type = 3;

            /* DMA length */
            dma_length = (reg[20] << 8) | reg[19];

            /* Zero DMA length (pre-decrementing counter) */
            if (!dma_length)
            {
              dma_length = 0x10000;
            }

            /* DMA source address */
            dma_src = (reg[22] << 8) | reg[21];

            /* Trigger DMA */
            vdp_dma_update(m68k.cycles);
            break;
          }

          default:
          {
            /* DMA from 68k bus */
            dma_type = (code & 0x06) ? 0 : 1;

            /* DMA length */
            dma_length = (reg[20] << 8) | reg[19];

            /* Zero DMA length (pre-decrementing counter) */
            if (!dma_length)
            {
              dma_length = 0x10000;
            }

            /* DMA source address */
            dma_src = (reg[22] << 8) | reg[21];

            /* Transfer from SVP ROM/RAM ($000000-$3fffff) or CD Word-RAM ($200000-$3fffff/$600000-$7fffff) */
            if (((system_hw == SYSTEM_MCD) && ((reg[23] & 0x70) == ((scd.cartridge.boot >> 1) + 0x10))) || (svp && !(reg[23] & 0x60)))
            {
              /* source data is available with one cycle delay, i.e first word written by VDP is */
              /* previous data being held on 68k bus at that time, then source words are written */
              /* normally to VDP RAM, with only last source word being ignored */
              addr += reg[15];
              dma_length--;
            }

            /* Trigger DMA */
            vdp_dma_update(m68k.cycles);
            break;
          }
        }
      }
    }
  }

  /* 
     FIFO emulation (Chaos Engine/Soldier of Fortune, Double Clutch, Sol Deace) 
     --------------------------------------------------------------------------
     Each VRAM access is byte wide, so one VRAM write (word) need two slot access.

      NOTE: Invalid code 0x02 (register write) should not behave the same as VRAM
      access, i.e data is ignored and only one access slot is used for each word, 
      BUT a few games ("Clue", "Microcosm") which accidentally corrupt code value 
      will have issues when emulating FIFO timings. They likely work fine on real
      hardware because of periodical 68k wait-states which have been observed and
      would naturaly add some delay between writes. Until those wait-states are
      accurately measured and emulated, delay is forced when invalid code value
      is being used.
  */ 
  fifo_byte_access = ((code & 0x0F) <= 0x02);
}

/* Mega Drive VDP control port specific (MS compatibility mode) */
void vdp_z80_ctrl_w(unsigned int data)
{
  switch (pending)
  {
    case 0:
    {
      /* Latch LSB */
      addr_latch = data;

      /* Set LSB pending flag */
      pending = 1;
      return;
    }

    case 1:
    {
      /* Update address and code registers */
      addr = (addr & 0xC000) | ((data & 0x3F) << 8) | addr_latch ;
      code = ((code & 0x3C) | ((data >> 6) & 0x03));

      if ((code & 0x03) == 0x02)
      {
        /* VDP register write */
        vdp_reg_w(data & 0x1F, addr_latch, Z80.cycles);

        /* Clear pending flag  */
        pending = 0;
        return;
      }

      /* Set Mode 5 pending flag  */
      pending = (reg[1] & 4) >> 1;

      if (!pending && !(code & 0x03))
      {
        /* Process VRAM read */
        fifo[0] = vram[addr & 0x3FFF];

        /* Increment address register */
        addr += (reg[15] + 1);
      }
      return;
    }

    case 2:
    {
      /* Latch LSB */
      addr_latch = data;

      /* Set LSB pending flag */
      pending = 3;
      return;
    }

    case 3:
    {
      /* Clear pending flag  */
      pending = 0;

      /* Update address and code registers */
      addr = ((addr_latch & 3) << 14) | (addr & 0x3FFF);
      code = ((code & 0x03) | ((addr_latch >> 2) & 0x3C));

      /* Detect DMA operation (CD5 bit set) */
      if (code & 0x20)
      {
        /* DMA should be enabled */
        if (reg[1] & 0x10)
        {
          /* DMA type */
          switch (reg[23] >> 6)
          {
            case 2:
            {
              /* DMA Fill */
              dma_type = 2;

              /* DMA is pending until next DATA port write */
              dmafill = 1;

              /* Set DMA Busy flag */
              status |= 0x02;

              /* DMA end cycle is not initialized yet (this prevents DMA Busy flag from being cleared on VDP status read) */
              dma_endCycles = 0xffffffff;
              break;
            }

            case 3:
            {
              /* DMA copy */
              dma_type = 3;

              /* DMA length */
              dma_length = (reg[20] << 8) | reg[19];

              /* Zero DMA length (pre-decrementing counter) */
              if (!dma_length)
              {
                dma_length = 0x10000;
              }

              /* DMA source address */
              dma_src = (reg[22] << 8) | reg[21];

              /* Trigger DMA */
              vdp_dma_update(Z80.cycles);
              break;
            }

            default:
            {
              /* DMA from 68k bus does not work when Z80 is in control */
              break;
            }
          }
        }
      }
    }
    return;
  }
}

/* Master System & Game Gear VDP control port specific */
void vdp_sms_ctrl_w(unsigned int data)
{
  if (pending == 0)
  {
    /* Update address register LSB */
    addr = (addr & 0x3F00) | (data & 0xFF);

    /* Latch LSB */
    addr_latch = data;

    /* Set LSB pending flag */
    pending = 1;
  }
  else
  {
    /* Update address and code registers */
    code = (data >> 6) & 3;
    addr = (data << 8 | addr_latch) & 0x3FFF;

    /* Clear pending flag  */
    pending = 0;

    if (code == 0)
    {
      /* Process VRAM read */
      fifo[0] = vram[addr & 0x3FFF];

      /* Increment address register */
      addr = (addr + 1) & 0x3FFF;
      return;
    }

    if (code == 2)
    {
      /* Save current VDP mode */
      int mode, prev = (reg[0] & 0x06) | (reg[1] & 0x18);

      /* Write VDP register 0-15 */
      vdp_reg_w(data & 0x0F, addr_latch, Z80.cycles);

      /* Check VDP mode changes */
      mode = (reg[0] & 0x06) | (reg[1] & 0x18);
      prev ^= mode;
 
      if (prev)
      {
        /* Check for extended modes */
        if (system_hw > SYSTEM_SMS)
        {
          int height;

          if (mode == 0x0E) /* M1=0,M2=1,M3=1,M4=1 */
          {
            /* Mode 4 extended (240 lines) */
            height = 240;

            /* Update vertical counter max value */
            vc_max = vc_table[3][vdp_pal];
          }
          else if (mode == 0x16) /* M1=1,M2=1,M3=0,M4=1 */
          {
            /* Mode 4 extended (224 lines) */
            height = 224;

            /* Update vertical counter max value */
            vc_max = vc_table[1][vdp_pal];
          }
          else
          {
            /* Mode 4 default (224 lines) */
            height = 192;

            /* Default vertical counter max value */
            vc_max = vc_table[0][vdp_pal];
          }

          /* viewport changes should be applied on next frame */
          if (height != bitmap.viewport.h)
          {
            bitmap.viewport.changed |= 2;
          }
        }

        /* Rendering mode */
        render_bg = render_bg_modes[mode>>1];

        /* Mode switching */
        if (prev & 0x04)
        {
          int i;

          if (mode & 0x04)
          {
            /* Mode 4 sprites */
            parse_satb = parse_satb_m4;
            render_obj = render_obj_m4;

            /* force BG cache update*/
            bg_list_index = 0x200;
          }
          else
          {
            /* TMS-mode sprites */
            parse_satb = parse_satb_tms;
            render_obj = render_obj_tms;

            /* BG cache is not used */
            bg_list_index = 0;
          }

          /* reinitialize palette */
          for(i = 0; i < 0x20; i ++)
          {
            color_update_m4(i, *(uint16 *)&cram[i << 1]);
          }
          color_update_m4(0x40, *(uint16 *)&cram[(0x10 | (border & 0x0F)) << 1]);
        }
      }
    }
  }
}

/* SG-1000 VDP (TMS99xx) control port specific */
void vdp_tms_ctrl_w(unsigned int data)
{
  if (pending == 0)
  {
    /* Latch LSB */
    addr_latch = data;

    /* Set LSB pending flag */
    pending = 1;
  }
  else
  {
    /* Update address and code registers */
    code = (data >> 6) & 3;
    addr = (data << 8 | addr_latch) & 0x3FFF;

    /* Clear pending flag  */
    pending = 0;

    if (code == 0)
    {
      /* Process VRAM read */
      fifo[0] = vram[addr & 0x3FFF];

      /* Increment address register */
      addr = (addr + 1) & 0x3FFF;
      return;
    }

    if (code & 2)
    {
      /* VDP register index (0-7) */
      data &= 0x07;

      /* Write VDP register */
      vdp_reg_w(data, addr_latch, Z80.cycles);
 
      /* Check VDP mode changes */
      if (data < 2)
      {
        /* Rendering mode */
        render_bg = render_bg_modes[((reg[0] & 0x02) | (reg[1] & 0x18)) >> 1];
      }
    }
  }
}

  /*
   * Status register
   *
   * Bits
   * 0  NTSC(0)/PAL(1)
   * 1  DMA Busy
   * 2  During HBlank
   * 3  During VBlank
   * 4  0:1 even:odd field (interlaced modes only)
   * 5  Sprite collision
   * 6  Too many sprites per line
   * 7  v interrupt occurred
   * 8  Write FIFO full
   * 9  Write FIFO empty
   * 10 - 15  Open Bus
   */
unsigned int vdp_68k_ctrl_r(unsigned int cycles)
{
  unsigned int temp;

  /* Cycle-accurate VDP status read (adjust CPU time with current instruction execution time) */
  cycles += m68k_cycles();

  /* Update FIFO status flags if not empty */
  if (fifo_write_cnt)
  {
    vdp_fifo_update(cycles);
  }

  /* Check if DMA Busy flag is set */
  if (status & 2)
  {
    /* Check if DMA is finished */
    if (!dma_length && (cycles >= dma_endCycles))
    {
      /* Clear DMA Busy flag */
      status &= 0xFFFD;
    }
  }

  /* Return VDP status */
  temp = status;

  /* Clear pending flag */
  pending = 0;

  /* Clear SOVR & SCOL flags */
  status &= 0xFF9F;

  /* VBLANK flag is set when display is disabled */
  if (!(reg[1] & 0x40))
  {
    temp |= 0x08;
  }

  /* Cycle-accurate VINT flag (Ex-Mutants, Tyrant / Mega-Lo-Mania, Marvel Land) */
  /* this allows VINT flag to be read just before vertical interrupt is being triggered */
  if ((v_counter == bitmap.viewport.h) && (cycles >= (mcycles_vdp + 788)))
  {
    /* check Z80 interrupt state to assure VINT has not already been triggered (and flag cleared) */
    if (Z80.irq_state != ASSERT_LINE)
    {
      temp |= 0x80;
    }
  }

  /* Cycle-accurate HBLANK flag (Sonic 3 & Sonic 2 "VS Modes", Bugs Bunny Double Trouble, Lemmings 2, Mega Turrican, V.R Troopers, Gouketsuji Ichizoku,...) */
  /* NB: this is not 100% accurate (see hvc.h for horizontal events timings in H32 and H40 mode) but is close enough to make no noticeable difference for games */
  if ((cycles % MCYCLES_PER_LINE) < 588)
  {
    temp |= 0x04;
  }

#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] VDP 68k status read -> 0x%x (0x%x) (%x)\n", v_counter, (v_counter + (cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, cycles, cycles%MCYCLES_PER_LINE, temp, status, m68k_get_reg(M68K_REG_PC));
#endif
  return (temp);
}

unsigned int vdp_z80_ctrl_r(unsigned int cycles)
{
  unsigned int temp;

  /* Check if DMA busy flag is set (Mega Drive VDP specific) */
  if (status & 2)
  {
    /* Check if DMA is finished */
    if (!dma_length && (cycles >= dma_endCycles))
    {
      /* Clear DMA Busy flag */
      status &= 0xFD;
    }
  }

  /* Check if we are already on next line */
  if ((cycles - mcycles_vdp) >= MCYCLES_PER_LINE)
  {
    /* check vertical position */
    if (v_counter == bitmap.viewport.h)
    {
      /* update VCounter to indicate VINT flag has been cleared & VINT should not be triggered */
      v_counter++;

      /* cycle-accurate VINT flag (immediately cleared after being read) */
      status |= 0x80;
    }
    else
    {
      /* update line counter */
      int line = (v_counter + 1) % lines_per_frame;
    
      /* check if we are within active display range */
      if ((line < bitmap.viewport.h) && !(work_ram[0x1ffb] & cart.special & HW_3D_GLASSES))
      {
        /* update VCounter to indicate next line has already been rendered */
        v_counter = line;

        /* render next line (cycle-accurate SCOL & SOVR flags) */
        render_line(line);
      }
    }
  }

  /* Return VDP status */
  temp = status;

  /* Clear pending flag */
  pending = 0;

  /* Clear VINT, SOVR & SCOL flags */
  status &= 0xFF1F;

  /* Mega Drive VDP specific */
  if (system_hw & SYSTEM_MD)
  {
    /* Display OFF: VBLANK flag is set */
    if (!(reg[1] & 0x40))
    {
      temp |= 0x08;
    }

    /* HBLANK flag */
    if ((cycles % MCYCLES_PER_LINE) < 588)
    {
      temp |= 0x04;
    }
  }
  else if (reg[0] & 0x04)
  {
    /* Mode 4 unused bits (fixes PGA Tour Golf) */
    temp |= 0x1F;
  }

  /* Cycle-accurate SCOL flag */
  if ((temp & 0x20) && (v_counter == (spr_col >> 8)))
  {
    if (system_hw & SYSTEM_MD)
    {
      /* COL flag is set at HCount 0xFF on MD */
      if ((cycles % MCYCLES_PER_LINE) < 105)
      {
        status |= 0x20;
        temp &= ~0x20;
      }
    }
    else
    {
      /* COL flag is set at the pixel it occurs */
      uint8 hc = hctab[(cycles + SMS_CYCLE_OFFSET + 15) % MCYCLES_PER_LINE];
      if ((hc < (spr_col & 0xff)) || (hc > 0xf3))
      {
        status |= 0x20;
        temp &= ~0x20;
      }
    }
  }

  /* Clear HINT & VINT pending flags */
  hint_pending = vint_pending = 0;

  /* Clear Z80 interrupt */
  Z80.irq_state = CLEAR_LINE;

#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] VDP Z80 status read -> 0x%x (0x%x) (%x)\n", v_counter, (v_counter + (cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, cycles, cycles%MCYCLES_PER_LINE, temp, status, Z80.pc.w.l);
#endif
  return (temp);
}

/*--------------------------------------------------------------------------*/
/* HV Counters                                                              */
/*--------------------------------------------------------------------------*/

unsigned int vdp_hvc_r(unsigned int cycles)
{
  int vc;
  unsigned int data = hvc_latch;

  /* Check if HVC latch is enabled */
  if (data)
  {
    /* Mode 5: HV counters are frozen (cf. lightgun games, Sunset Riders logo) */
    if (reg[1] & 0x04)
    {
#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] HVC latch read -> 0x%x (%x)\n", v_counter, (v_counter + (cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, cycles, cycles%MCYCLES_PER_LINE, data & 0xffff, m68k_get_reg(M68K_REG_PC));
#endif
      /* return latched HVC value */
      return (data & 0xffff);
    }
    else
    {
      /* Mode 4: by default, VCounter runs normally & HCounter is frozen */
      data &= 0xff;
    }
  }
  else
  {
    /* Cycle-accurate HCounter (Striker, Mickey Mania, Skitchin, Road Rash I,II,III, Sonic 3D Blast...) */
    data = hctab[cycles % MCYCLES_PER_LINE];
  }

  /* Cycle-accurate VCounter */
  vc = v_counter;
  if ((cycles - mcycles_vdp) >= MCYCLES_PER_LINE)
  {
    vc = (vc + 1) % lines_per_frame;
  }

  /* VCounter overflow */
  if (vc > vc_max)
  {
    vc -= lines_per_frame;
  }

  /* Interlaced modes */
  if (interlaced)
  {
    /* Interlace mode 2 (Sonic the Hedgehog 2, Combat Cars) */
    vc <<= im2_flag;

    /* Replace bit 0 with bit 8 */
    vc = (vc & ~1) | ((vc >> 8) & 1);
  }

  /* return HCounter in LSB & VCounter in MSB */
  data |= ((vc & 0xff) << 8);
  
#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] HVC read -> 0x%x (%x)\n", v_counter, (v_counter + (cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, cycles, cycles%MCYCLES_PER_LINE, data, m68k_get_reg(M68K_REG_PC));
#endif
  return (data);
}


/*--------------------------------------------------------------------------*/
/* Test registers                                                           */
/*--------------------------------------------------------------------------*/

void vdp_test_w(unsigned int data)
{
#ifdef LOGERROR
  error("Unused VDP Write 0x%x (%08x)\n", data, m68k_get_reg(M68K_REG_PC));
#endif
}


/*--------------------------------------------------------------------------*/
/* 68k interrupt handler (TODO: check how interrupts are handled in Mode 4) */
/*--------------------------------------------------------------------------*/

int vdp_68k_irq_ack(int int_level)
{
#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] INT Level %d ack (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE,int_level, m68k_get_reg(M68K_REG_PC));
#endif

  /* VINT has higher priority (Fatal Rewind) */
  if (reg[1] & vint_pending)
  {
#ifdef LOGVDP
    error("---> VINT cleared\n");
#endif

    /* Clear VINT pending flag */
    vint_pending = 0;
    status &= ~0x80;

    /* Update IRQ status */
    if (reg[0] & hint_pending)
    {
      m68k_set_irq(4);
    }
    else
    {
      m68k_set_irq(0);
    }
  }
  else
  {
#ifdef LOGVDP
    error("---> HINT cleared\n");
#endif

    /* Clear HINT pending flag */
    hint_pending = 0;

    /* Update IRQ status */
    m68k_set_irq(0);
  }

  return M68K_INT_ACK_AUTOVECTOR;
}


/*--------------------------------------------------------------------------*/
/* VDP registers update function                                            */
/*--------------------------------------------------------------------------*/

static void vdp_reg_w(unsigned int r, unsigned int d, unsigned int cycles)
{
#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] VDP register %d write -> 0x%x (%x)\n", v_counter, (v_counter + (cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, cycles, cycles%MCYCLES_PER_LINE, r, d, m68k_get_reg(M68K_REG_PC));
#endif

  /* VDP registers #11 to #23 cannot be updated in Mode 4 (Captain Planet & Avengers, Bass Master Classic Pro Edition) */
  if (!(reg[1] & 4) && (r > 10))
  {
    return;
  }

  switch(r)
  {
    case 0: /* CTRL #1 */
    {
      /* Look for changed bits */
      r = d ^ reg[0];
      reg[0] = d;

      /* Line Interrupt */
      if (r & hint_pending)
      {
        /* Update IRQ status */
        if (reg[1] & vint_pending)
        {
          set_irq_line(6);
        }
        else if (d & 0x10)
        {
          set_irq_line_delay(4);
        }
        else
        {
          set_irq_line(0);
        }
      }

      /* Palette selection */
      if (r & 0x04)
      {
        /* Mega Drive VDP only */
        if (system_hw & SYSTEM_MD)
        {
          /* Reset color palette */
          int i;
          if (reg[1] & 0x04)
          {
            /* Mode 5 */
            color_update_m5(0x00, *(uint16 *)&cram[border << 1]);
            for (i = 1; i < 0x40; i++)
            {
              color_update_m5(i, *(uint16 *)&cram[i << 1]);
            }
          }
          else
          {
            /* Mode 4 */
            for (i = 0; i < 0x20; i++)
            {
              color_update_m4(i, *(uint16 *)&cram[i << 1]);
            }
            color_update_m4(0x40, *(uint16 *)&cram[(0x10 | (border & 0x0F)) << 1]);
          }
        }
      }

      /* HVC latch (Sunset Riders, Lightgun games) */
      if (r & 0x02)
      {
        /* Mega Drive VDP only */
        if (system_hw & SYSTEM_MD)
        {
          /* Mode 5 only */
          if (reg[1] & 0x04)
          {
            if (d & 0x02)
            {
              /* Latch current HVC */
              hvc_latch = vdp_hvc_r(cycles) | 0x10000;
            }
            else
            {
              /* Free-running HVC */
              hvc_latch = 0;
            }
          }
        }
      }
      break;
    }

    case 1: /* CTRL #2 */
    {
      /* Look for changed bits */
      r = d ^ reg[1];
      reg[1] = d;

      /* 4K/16K address decoding */
      if (r & 0x80)
      {
        /* original TMS99xx hardware only (fixes Magical Kid Wiz) */
        if (system_hw == SYSTEM_SG)
        {
          int i;
          
          /* make temporary copy of 16KB VRAM */
          memcpy(vram + 0x4000, vram, 0x4000);

          /* re-arrange 16KB VRAM address decoding */
          if (d & 0x80)
          {
            /* 4K->16K address decoding */
            for (i=0; i<0x4000; i+=2)
            {
              *(uint16 *)(vram + ((i & 0x203F) | ((i << 6) & 0x1000) | ((i >> 1) & 0xFC0))) = *(uint16 *)(vram + 0x4000 + i);
            }
          }
          else
          {
            /* 16K->4K address decoding */
            for (i=0; i<0x4000; i+=2)
            {
              *(uint16 *)(vram + ((i & 0x203F) | ((i >> 6) & 0x40) | ((i << 1) & 0x1F80))) = *(uint16 *)(vram + 0x4000 + i);
            }
          }
        }
      }

      /* Display status (modified during active display) */
      if ((r & 0x40) && (v_counter < bitmap.viewport.h))
      {
        /* Cycle offset vs HBLANK */
        int offset = cycles - mcycles_vdp;
        if (offset <= 860)
        {
          /* Sprite rendering is limited if display was disabled during HBLANK (Mickey Mania 3d level, Overdrive Demo) */
          if (d & 0x40)
          {
            /* NB: This is not 100% accurate. On real hardware, the maximal number of rendered sprites pixels */
            /* for the current line (normally 256 or 320 pixels) but also the maximal number of pre-processed */
            /* sprites for the next line (normally 64 or 80 sprites) are both reduced depending on the amount */
            /* of cycles spent with display disabled. Here we only reduce them by a fixed amount when display */
            /* has been reenabled after a specific point within HBLANK. */
            if (offset > 360)
            {
              max_sprite_pixels = 128;
            }
          }

          /* Redraw entire line (Legend of Galahad, Lemmings 2, Formula One, Kawasaki Super Bike, Deadly Moves,...) */
          render_line(v_counter);

          /* Restore default */
          max_sprite_pixels = 256 + ((reg[12] & 1) << 6);
        }
        else if (system_hw & SYSTEM_MD)
        {
          /* Active pixel offset  */
          if (reg[12] & 1)
          {
            /* dot clock = MCLK / 8 */
            offset = ((offset - 860) / 8) + 16;
          }
          else
          {
            /* dot clock = MCLK / 10 */
            offset = ((offset - 860) / 10) + 16;
          }

          /* Line is partially blanked (Nigel Mansell's World Championship Racing , Ren & Stimpy Show, ...) */
          if (offset < bitmap.viewport.w)
          {
            if (d & 0x40)
            {
              render_line(v_counter);
              blank_line(v_counter, 0, offset);
            }
            else
            {
              blank_line(v_counter, offset, bitmap.viewport.w - offset);
            }
          }
        }
      }

      /* Frame Interrupt */
      if (r & vint_pending)
      {
        /* Update IRQ status */
        if (d & 0x20) 
        {
          set_irq_line_delay(6);
        }
        else if (reg[0] & hint_pending)
        {
          set_irq_line(4);
        }
        else
        {
          set_irq_line(0);
        }
      }

      /* Active display height */
      if (r & 0x08)
      {
        /* Mega Drive VDP only */
        if (system_hw & SYSTEM_MD)
        {
          /* Mode 5 only */
          if (d & 0x04)
          {
            /* Changes should be applied on next frame */
            bitmap.viewport.changed |= 2;

            /* Update vertical counter max value */
            vc_max = vc_table[(d >> 2) & 3][vdp_pal];
          }
        }
      }

      /* Rendering mode */
      if (r & 0x04)
      {
        /* Mega Drive VDP only */
        if (system_hw & SYSTEM_MD)
        {
          int i;
          if (d & 0x04)
          {
            /* Mode 5 rendering */
            parse_satb = parse_satb_m5;
            update_bg_pattern_cache = update_bg_pattern_cache_m5;
            if (im2_flag)
            {
              render_bg = (reg[11] & 0x04) ? render_bg_m5_im2_vs : render_bg_m5_im2;
              render_obj = (reg[12] & 0x08) ? render_obj_m5_im2_ste : render_obj_m5_im2;
            }
            else
            {
              render_bg = (reg[11] & 0x04) ? render_bg_m5_vs : render_bg_m5;
              render_obj = (reg[12] & 0x08) ? render_obj_m5_ste : render_obj_m5;
            }

            /* Reset color palette */
            color_update_m5(0x00, *(uint16 *)&cram[border << 1]);
            for (i = 1; i < 0x40; i++)
            {
              color_update_m5(i, *(uint16 *)&cram[i << 1]);
            }

            /* Mode 5 bus access */
            vdp_68k_data_w = vdp_68k_data_w_m5;
            vdp_z80_data_w = vdp_z80_data_w_m5;
            vdp_68k_data_r = vdp_68k_data_r_m5;
            vdp_z80_data_r = vdp_z80_data_r_m5;

            /* Clear HVC latched value */
            hvc_latch = 0;

            /* Check if HVC latch bit is set */
            if (reg[0] & 0x02)
            {
              /* Latch current HVC */
              hvc_latch = vdp_hvc_r(cycles) | 0x10000;
            }

            /* max tiles to invalidate */
            bg_list_index = 0x800;
          }
          else
          {
            /* Mode 4 rendering */
            parse_satb = parse_satb_m4;
            update_bg_pattern_cache = update_bg_pattern_cache_m4;
            render_bg = render_bg_m4;
            render_obj = render_obj_m4;

            /* Reset color palette */
            for (i = 0; i < 0x20; i++)
            {
              color_update_m4(i, *(uint16 *)&cram[i << 1]);
            }
            color_update_m4(0x40, *(uint16 *)&cram[(0x10 | (border & 0x0F)) << 1]);

            /* Mode 4 bus access */
            vdp_68k_data_w = vdp_68k_data_w_m4;
            vdp_z80_data_w = vdp_z80_data_w_m4;
            vdp_68k_data_r = vdp_68k_data_r_m4;
            vdp_z80_data_r = vdp_z80_data_r_m4;

            /* Latch current HVC */
            hvc_latch = vdp_hvc_r(cycles) | 0x10000;

            /* max tiles to invalidate */
            bg_list_index = 0x200;
          }

          /* Invalidate pattern cache */
          for (i=0;i<bg_list_index;i++) 
          {
            bg_name_list[i] = i;
            bg_name_dirty[i] = 0xFF;
          }

          /* Update vertical counter max value */
          vc_max = vc_table[(d >> 2) & 3][vdp_pal];

          /* Display height change should be applied on next frame */
          bitmap.viewport.changed |= 2; 
        }
        else
        {
          /* No effect (cleared to avoid mode 5 detection elsewhere) */
          reg[1] &= ~0x04;
        }
      }
      break;
    }

    case 2: /* Plane A Name Table Base */
    {
      reg[2] = d;
      ntab = (d << 10) & 0xE000;

      /* Plane A Name Table Base changed during HBLANK */
      if ((v_counter < bitmap.viewport.h) && (reg[1] & 0x40) && (cycles <= (mcycles_vdp + 860)))
      {
        /* render entire line */
        render_line(v_counter);
      }
      break;
    }

    case 3: /* Window Plane Name Table Base */
    {
      reg[3] = d;
      if (reg[12] & 0x01)
      {
        ntwb = (d << 10) & 0xF000;
      }
      else
      {
        ntwb = (d << 10) & 0xF800;
      }

      /* Window Plane Name Table Base changed during HBLANK */
      if ((v_counter < bitmap.viewport.h) && (reg[1] & 0x40) && (cycles <= (mcycles_vdp + 860)))
      {
        /* render entire line */
        render_line(v_counter);
      }
      break;
    }

    case 4: /* Plane B Name Table Base */
    {
      reg[4] = d;
      ntbb = (d << 13) & 0xE000;

      /* Plane B Name Table Base changed during HBLANK (Adventures of Batman & Robin) */
      if ((v_counter < bitmap.viewport.h) && (reg[1] & 0x40) && (cycles <= (mcycles_vdp + 860)))
      {
        /* render entire line */
        render_line(v_counter);
      }

      break;
    }

    case 5: /* Sprite Attribute Table Base */
    {
      reg[5] = d;
      satb = (d << 9) & sat_base_mask;
      break;
    }

    case 7: /* Backdrop color */
    {
      reg[7] = d;

      /* Check if backdrop color changed */
      d &= 0x3F;

      if (d != border)
      {
        /* Update backdrop color */
        border = d;

        /* Reset palette entry */
        if (reg[1] & 4)
        {
          /* Mode 5 */
          color_update_m5(0x00, *(uint16 *)&cram[d << 1]);
        }
        else
        {
          /* Mode 4 */
          color_update_m4(0x40, *(uint16 *)&cram[(0x10 | (d & 0x0F)) << 1]);
        }

        /* Backdrop color modified during HBLANK (Road Rash 1,2,3)*/
        if ((v_counter < bitmap.viewport.h) && (cycles <= (mcycles_vdp + 860)))
        {
          /* remap entire line */
          remap_line(v_counter);
        }
      }
      break;
    }

    case 8:   /* Horizontal Scroll (Mode 4 only) */
    {
      /* H-Scroll is latched at HCount 0xF3, HCount 0xF6 on MD */
      /* Line starts at HCount 0xF4, HCount 0xF6 on MD */
      if (system_hw < SYSTEM_MD)
      {
        cycles = cycles + 15;
      }

      /* Check if H-Scroll has already been latched */
      if ((cycles - mcycles_vdp) >= MCYCLES_PER_LINE)
      {
        /* update line counter */
        int line = (v_counter + 1) % lines_per_frame;

        /* check if we are within active display range */
        if ((line < bitmap.viewport.h) && !(work_ram[0x1ffb] & cart.special & HW_3D_GLASSES))
        {
          /* update VCounter to indicate next line has already been rendered */
          v_counter = line;

          /* render next line before updating H-Scroll */
          render_line(line);
        }
      }

      reg[8] = d;
      break;
    }

    case 11:  /* CTRL #3 */
    {
      reg[11] = d;

      /* Horizontal scrolling mode */
      hscroll_mask = hscroll_mask_table[d & 0x03];

      /* Vertical Scrolling mode */
      if (d & 0x04)
      {
        render_bg = im2_flag ? render_bg_m5_im2_vs : render_bg_m5_vs;
      }
      else
      {
        render_bg = im2_flag ? render_bg_m5_im2 : render_bg_m5;
      }
      break;
    }

    case 12:  /* CTRL #4 */
    {
      /* Look for changed bits */
      r = d ^ reg[12];
      reg[12] = d;

      /* Shadow & Highlight mode */
      if (r & 0x08)
      {
        /* Reset color palette */
        int i;
        color_update_m5(0x00, *(uint16 *)&cram[border << 1]);
        for (i = 1; i < 0x40; i++)
        {
          color_update_m5(i, *(uint16 *)&cram[i << 1]);
        }

        /* Update sprite rendering function */
        if (d & 0x08)
        {
          render_obj = im2_flag ? render_obj_m5_im2_ste : render_obj_m5_ste;
        }
        else
        {
          render_obj = im2_flag ? render_obj_m5_im2 : render_obj_m5;
        }
      }

      /* Interlaced modes */
      if (r & 0x06)
      {
        /* changes should be applied on next frame */
        bitmap.viewport.changed |= 2;
      }

      /* Active display width */
      if (r & 0x01)
      {
        /* FIFO access slots timings depend on active width */
        if (fifo_slots)
        {
          /* Synchronize VDP FIFO */
          vdp_fifo_update(cycles);
        }

        if (d & 0x01)
        {
          /* Update display-dependant registers */
          ntwb = (reg[3] << 10) & 0xF000;
          satb = (reg[5] << 9) & 0xFC00;
          sat_base_mask = 0xFC00;
          sat_addr_mask = 0x03FF;

          /* Update HC table */
          hctab = cycle2hc40;

          /* Update clipping */
          window_clip(reg[17], 1);

          /* Update max sprite pixels per line*/
          max_sprite_pixels = 320;

          /* FIFO access slots timings */
          fifo_timing = (int *)fifo_timing_h40;
        }
        else
        {
          /* Update display-dependant registers */
          ntwb = (reg[3] << 10) & 0xF800;
          satb = (reg[5] << 9) & 0xFE00;
          sat_base_mask = 0xFE00;
          sat_addr_mask = 0x01FF;

          /* Update HC table */
          hctab = cycle2hc32;

          /* Update clipping */
          window_clip(reg[17], 0);

          /* Update max sprite pixels per line*/
          max_sprite_pixels = 256;

          /* FIFO access slots timings */
          fifo_timing = (int *)fifo_timing_h32;
        }

        /* Active screen width modified during VBLANK will be applied on upcoming frame */
        if (v_counter >= bitmap.viewport.h)
        {
          bitmap.viewport.w = max_sprite_pixels;
        }

        /* Allow active screen width to be modified during first two lines (Bugs Bunny in Double Trouble) */
        else if (v_counter <= 1)
        {
          bitmap.viewport.w = max_sprite_pixels;

          /* Redraw lines */
          render_line(0);
          if (v_counter)
          {
            render_line(1);
          }
        }
        else
        {
          /* Screen width changes during active display (Golden Axe 3 intro, Ultraverse Prime) */
          /* should be applied on next frame since backend rendered framebuffer width is fixed */
          /* and can not be modified mid-frame. This is not 100% accurate but games generally  */
          /* do this when the screen is blanked so it is likely unnoticeable. */
          bitmap.viewport.changed |= 2;
        }
      }
      break;
    }

    case 13: /* HScroll Base Address */
    {
      reg[13] = d;
      hscb = (d << 10) & 0xFC00;
      break;
    }

    case 16: /* Playfield size */
    {
      reg[16] = d;
      playfield_shift = shift_table[(d & 3)];
      playfield_col_mask = col_mask_table[(d & 3)];
      playfield_row_mask = row_mask_table[(d >> 4) & 3];
      break;
    }

    case 17: /* Window/Plane A vertical clipping */
    {
      reg[17] = d;
      window_clip(d, reg[12] & 1);
      break;
    }

    default:
    {
      reg[r] = d;
      break;
    }
  }
}

/*--------------------------------------------------------------------------*/
/*  FIFO emulation (Mega Drive VDP specific)                                */
/*  ----------------------------------------                                */
/*                                                                          */
/*  CPU access to VRAM, CRAM & VSRAM is limited during active display:      */
/*    H32 mode -> 16 access per line                                        */
/*    H40 mode -> 18 access per line                                        */
/*                                                                          */
/*  with fixed access slots timings detailled below.                        */
/*                                                                          */
/*  Each VRAM access is byte wide, so one VRAM write (word) need two slots. */
/*                                                                          */
/*--------------------------------------------------------------------------*/

static void vdp_fifo_update(unsigned int cycles)
{
  int fifo_read_cnt, line_slots = 0;

  /* number of access slots up to current line */
  int total_slots = dma_timing[0][reg[12] & 1] * ((v_counter + 1) % lines_per_frame);

  /* number of access slots within current line */
  cycles -= mcycles_vdp;
  while (fifo_timing[line_slots] <= cycles)
  {
    line_slots++;
  }

  /* number of processed FIFO entries since last access (byte access needs two slots to process one FIFO word) */
  fifo_read_cnt = (total_slots + line_slots - fifo_slots) >> fifo_byte_access;

  if (fifo_read_cnt > 0)
  {
    /* process FIFO entries */
    fifo_write_cnt -= fifo_read_cnt;

    /* Clear FIFO full flag */
    status &= 0xFEFF;

    if (fifo_write_cnt <= 0)
    {
      /* No more FIFO entries */
      fifo_write_cnt = 0;

      /* Set FIFO empty flag */
      status |= 0x200;

      /* Reinitialize FIFO access slot counter */
      fifo_slots = total_slots + line_slots;
    }
    else
    {
      /* Update FIFO access slot counter */
      fifo_slots += (fifo_read_cnt << fifo_byte_access);
    }
  }

  /* next FIFO update cycle */
  fifo_cycles = mcycles_vdp + fifo_timing[fifo_slots - total_slots + fifo_byte_access];
}


/*--------------------------------------------------------------------------*/
/* Internal 16-bit data bus access function (Mode 5 only)                   */
/*--------------------------------------------------------------------------*/
static void vdp_bus_w(unsigned int data)
{
  /* write data to next FIFO entry */
  fifo[fifo_idx] = data;

  /* increment FIFO write pointer */
  fifo_idx = (fifo_idx + 1) & 3;

  /* Check destination code (CD0-CD3) */
  switch (code & 0x0F)
  {
    case 0x01:  /* VRAM */
    {
      /* VRAM address */
      int index = addr & 0xFFFE;

      /* Pointer to VRAM */
      uint16 *p = (uint16 *)&vram[index];

      /* Byte-swap data if A0 is set */
      if (addr & 1)
      {
        data = ((data >> 8) | (data << 8)) & 0xFFFF;
      }

      /* Intercept writes to Sprite Attribute Table */
      if ((index & sat_base_mask) == satb)
      {
        /* Update internal SAT */
        *(uint16 *) &sat[index & sat_addr_mask] = data;
      }

      /* Only write unique data to VRAM */
      if (data != *p)
      {
        int name;

        /* Write data to VRAM */
        *p = data;

        /* Update pattern cache */
        MARK_BG_DIRTY (index);
      }

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_VRAM_W, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] VRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    case 0x03:  /* CRAM */
    {
      /* Pointer to CRAM 9-bit word */
      uint16 *p = (uint16 *)&cram[addr & 0x7E];

      /* Pack 16-bit bus data (BBB0GGG0RRR0) to 9-bit CRAM data (BBBGGGRRR) */
      data = ((data & 0xE00) >> 3) | ((data & 0x0E0) >> 2) | ((data & 0x00E) >> 1);

      /* Check if CRAM data is being modified */
      if (data != *p)
      {
        /* CRAM index (64 words) */
        int index = (addr >> 1) & 0x3F;

        /* Write CRAM data */
        *p = data;

        /* Color entry 0 of each palette is never displayed (transparent pixel) */
        if (index & 0x0F)
        {
          /* Update color palette */
          color_update_m5(index, data);
        }

        /* Update backdrop color */
        if (index == border)
        {
          color_update_m5(0x00, data);
        }

        /* CRAM modified during HBLANK (Striker, Zero the Kamikaze, etc) */
        if ((v_counter < bitmap.viewport.h) && (reg[1] & 0x40) && (m68k.cycles <= (mcycles_vdp + 860)))
        {
          /* Remap current line */
          remap_line(v_counter);
        }
      }

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_CRAM_W, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] CRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    case 0x05:  /* VSRAM */
    {
      *(uint16 *)&vsram[addr & 0x7E] = data;

      /* 2-cell Vscroll mode */
      if (reg[11] & 0x04)
      {
        /* VSRAM writes during HBLANK (Adventures of Batman & Robin) */
        if ((v_counter < bitmap.viewport.h) && (reg[1] & 0x40) && (m68k.cycles <= (mcycles_vdp + 860)))
        {
          /* Redraw entire line */
          render_line(v_counter);
        }
      }

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_VSRAM_W, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] VSRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    default:
    {
      /* add some delay until 68k periodical wait-states are accurately emulated ("Clue", "Microcosm") */
      m68k.cycles += 2;
#ifdef LOGERROR
      error("[%d(%d)][%d(%d)] Invalid (%d) 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, code, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }
  }

  /* Increment address register */
  addr += reg[15];
}


/*--------------------------------------------------------------------------*/
/* 68k bus interface (Mega Drive VDP only)                                     */
/*--------------------------------------------------------------------------*/

static void vdp_68k_data_w_m4(unsigned int data)
{
  /* Clear pending flag */
  pending = 0;

  /* Restricted VDP writes during active display */
  if (!(status & 8) && (reg[1] & 0x40))
  {
    /* Update VDP FIFO */
    vdp_fifo_update(m68k.cycles);

    /* Clear FIFO empty flag */
    status &= 0xFDFF;

    /* up to 4 words can be stored */
    if (fifo_write_cnt < 4)
    {
      /* Increment FIFO counter */
      fifo_write_cnt++;

      /* Set FIFO full flag if 4 words are stored */
      status |= ((fifo_write_cnt & 4) << 6);
    }
    else
    {
      /* CPU is halted until next FIFO entry processing */
      m68k.cycles = fifo_cycles;

      /* Update FIFO access slot counter */
      fifo_slots += (fifo_byte_access + 1);
    }
  }

  /* Check destination code */
  if (code & 0x02)
  {
    /* CRAM index (32 words) */
    int index = addr & 0x1F;

    /* Pointer to CRAM 9-bit word */
    uint16 *p = (uint16 *)&cram[index << 1];

    /* Pack 16-bit data (xxx000BBGGRR) to 9-bit CRAM data (xxxBBGGRR) */
    data = ((data & 0xE00) >> 3) | (data & 0x3F);

    /* Check if CRAM data is being modified */
    if (data != *p)
    {
      /* Write CRAM data */
      *p = data;

      /* Update color palette */
      color_update_m4(index, data);

      /* Update backdrop color */
      if (index == (0x10 | (border & 0x0F)))
      {
        color_update_m4(0x40, data);
      }
    }
  }
  else
  {
    /* VRAM address (interleaved format) */
    int index = ((addr << 1) & 0x3FC) | ((addr & 0x200) >> 8) | (addr & 0x3C00);

    /* Pointer to VRAM */
    uint16 *p = (uint16 *)&vram[index];

    /* Byte-swap data if A0 is set */
    if (addr & 1)
    {
      data = ((data >> 8) | (data << 8)) & 0xFFFF;
    }

    /* Only write unique data to VRAM */
    if (data != *p)
    {
      int name;

      /* Write data to VRAM */
      *p = data;

      /* Update the pattern cache */
      MARK_BG_DIRTY (index);
    }
  }

  /* Increment address register (TODO: check how address is incremented in Mode 4) */
  addr += (reg[15] + 1);
}

static void vdp_68k_data_w_m5(unsigned int data)
{
  /* Clear pending flag */
  pending = 0;

  /* Restricted VDP writes during active display */
  if (!(status & 8) && (reg[1] & 0x40))
  {
    /* Update VDP FIFO */
    vdp_fifo_update(m68k.cycles);

    /* Clear FIFO empty flag */
    status &= 0xFDFF;

    /* up to 4 words can be stored */
    if (fifo_write_cnt < 4)
    {
      /* Increment FIFO counter */
      fifo_write_cnt++;

      /* Set FIFO full flag if 4 words are stored */
      status |= ((fifo_write_cnt & 4) << 6);
    }
    else
    {
      /* CPU is halted until next FIFO entry processing (Chaos Engine / Soldiers of Fortune, Double Clutch, Titan Overdrive Demo) */
      m68k.cycles = fifo_cycles;

      /* Update FIFO access slot counter */
      fifo_slots += (fifo_byte_access + 1);
    }
  }
  
  /* Write data */
  vdp_bus_w(data);

  /* Check if DMA Fill is pending */
  if (dmafill)
  {
    /* Clear DMA Fill pending flag */
    dmafill = 0;

    /* DMA length */
    dma_length = (reg[20] << 8) | reg[19];

    /* Zero DMA length (pre-decrementing counter) */
    if (!dma_length)
    {
      dma_length = 0x10000;
    }

    /* Trigger DMA */
    vdp_dma_update(m68k.cycles);
  }
}

static unsigned int vdp_68k_data_r_m4(void)
{
  /* VRAM address (interleaved format) */
  int index = ((addr << 1) & 0x3FC) | ((addr & 0x200) >> 8) | (addr & 0x3C00);

  /* Clear pending flag */
  pending = 0;

  /* Increment address register (TODO: check how address is incremented in Mode 4) */
  addr += (reg[15] + 1);

  /* Read VRAM data */
  return *(uint16 *) &vram[index];
}

static unsigned int vdp_68k_data_r_m5(void)
{
  uint16 data = 0;

  /* Clear pending flag */
  pending = 0;

  /* Check destination code (CD0-CD3) & CD4 */
  switch (code & 0x1F)
  {
    case 0x00:
    {
      /* read two bytes from VRAM */
      data = *(uint16 *)&vram[addr & 0xFFFE];

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_VRAM_R, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] VRAM 0x%x read -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    case 0x04:
    {
      /* VSRAM index */
      int index = addr & 0x7E;

      /* Check against VSRAM max size (80 x 11-bits) */
      if (index >= 0x50)
      {
        /* Wrap to address 0 (TODO: check if still true with Genesis 3 model) */
        index = 0;
      }

      /* Read 11-bit word from VSRAM */
      data = *(uint16 *)&vsram[index] & 0x7FF;

      /* Unused bits are set using data from next available FIFO entry */
      data |= (fifo[fifo_idx] & ~0x7FF);

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_VSRAM_R, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] VSRAM 0x%x read -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    case 0x08:
    {
      /* Read 9-bit word from CRAM */
      data = *(uint16 *)&cram[addr & 0x7E];

      /* Unpack 9-bit CRAM data (BBBGGGRRR) to 16-bit bus data (BBB0GGG0RRR0) */
      data = ((data & 0x1C0) << 3) | ((data & 0x038) << 2) | ((data & 0x007) << 1);

      /* Unused bits are set using data from next available FIFO entry */
      data |= (fifo[fifo_idx] & ~0xEEE);

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_CRAM_R, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] CRAM 0x%x read -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    case 0x0c: /* undocumented 8-bit VRAM read */
    {
      /* Read one byte from VRAM adjacent address */
      data = READ_BYTE(vram, addr ^ 1);

      /* Unused bits are set using data from next available FIFO entry */
      data |= (fifo[fifo_idx] & ~0xFF);

#ifdef HOOK_CPU
      if (cpu_hook)
        cpu_hook(HOOK_VRAM_R, 2, addr, data);
#endif

#ifdef LOGVDP
      error("[%d(%d)][%d(%d)] 8-bit VRAM 0x%x read -> 0x%x (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, addr, data, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }

    default:
    {
      /* Invalid code value (normally locks VDP, hard reset required) */
#ifdef LOGERROR
      error("[%d(%d)][%d(%d)] Invalid (%d) 0x%x read (%x)\n", v_counter, (v_counter + (m68k.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, m68k.cycles, m68k.cycles%MCYCLES_PER_LINE, code, addr, m68k_get_reg(M68K_REG_PC));
#endif
      break;
    }
  }

  /* Increment address register */
  addr += reg[15];

  /* Return data */
  return data;
}


/*--------------------------------------------------------------------------*/
/* Z80 bus interface (Mega Drive VDP in Master System compatibility mode)   */
/*--------------------------------------------------------------------------*/

static void vdp_z80_data_w_m4(unsigned int data)
{
  /* Clear pending flag */
  pending = 0;

  /* Check destination code */
  if (code & 0x02)
  {
    /* CRAM index (32 words) */
    int index = addr & 0x1F;

    /* Pointer to CRAM word */
    uint16 *p = (uint16 *)&cram[index << 1];

    /* Check if CRAM data is being modified */
    if (data != *p)
    {
      /* Write CRAM data */
      *p = data;

      /* Update color palette */
      color_update_m4(index, data);

      /* Update backdrop color */
      if (index == (0x10 | (border & 0x0F)))
      {
        color_update_m4(0x40, data);
      }
    }
  }
  else
  {
    /* VRAM address */
    int index = addr & 0x3FFF;

    /* Only write unique data to VRAM */
    if (data != vram[index])
    {
      int name;

      /* Write data */
      vram[index] = data;

      /* Update pattern cache */
      MARK_BG_DIRTY(index);
    }
  }

  /* Increment address register (TODO: check how address is incremented in Mode 4) */
  addr += (reg[15] + 1);
}

static void vdp_z80_data_w_m5(unsigned int data)
{
  /* Clear pending flag */
  pending = 0;

  /* Push byte into FIFO */
  fifo[fifo_idx] = data << 8;
  fifo_idx = (fifo_idx + 1) & 3;

  /* Check destination code (CD0-CD3) */
  switch (code & 0x0F)
  {
    case 0x01:  /* VRAM */
    {
      /* VRAM address (write low byte to even address & high byte to odd address) */
      int index = addr ^ 1;

      /* Intercept writes to Sprite Attribute Table */
      if ((index & sat_base_mask) == satb)
      {
        /* Update internal SAT */
        WRITE_BYTE(sat, index & sat_addr_mask, data);
      }

      /* Only write unique data to VRAM */
      if (data != READ_BYTE(vram, index))
      {
        int name;

        /* Write data */
        WRITE_BYTE(vram, index, data);

        /* Update pattern cache */
        MARK_BG_DIRTY (index);
      }
      break;
    }

    case 0x03:  /* CRAM */
    {
      /* Pointer to CRAM word */
      uint16 *p = (uint16 *)&cram[addr & 0x7E];

      /* Pack 8-bit value into 9-bit CRAM data */
      if (addr & 1)
      {
        /* Write high byte (0000BBB0 -> BBBxxxxxx) */
        data = (*p & 0x3F) | ((data & 0x0E) << 5);
      }
      else
      {
        /* Write low byte (GGG0RRR0 -> xxxGGGRRR) */
        data = (*p & 0x1C0) | ((data & 0x0E) >> 1)| ((data & 0xE0) >> 2);
      }

      /* Check if CRAM data is being modified */
      if (data != *p)
      {
        /* CRAM index (64 words) */
        int index = (addr >> 1) & 0x3F;

        /* Write CRAM data */
        *p = data;

        /* Color entry 0 of each palette is never displayed (transparent pixel) */
        if (index & 0x0F)
        {
          /* Update color palette */
          color_update_m5(index, data);
        }

        /* Update backdrop color */
        if (index == border)
        {
          color_update_m5(0x00, data);
        }
      }
      break;
    }

    case 0x05: /* VSRAM */
    {
      /* Write low byte to even address & high byte to odd address */
      WRITE_BYTE(vsram, (addr & 0x7F) ^ 1, data);
      break;
    }
  }

  /* Increment address register  */
  addr += reg[15];

  /* Check if DMA Fill is pending */
  if (dmafill)
  {
    /* Clear DMA Fill pending flag */
    dmafill = 0;

    /* DMA length */
    dma_length = (reg[20] << 8) | reg[19];

    /* Zero DMA length (pre-decrementing counter) */
    if (!dma_length)
    {
      dma_length = 0x10000;
    }

    /* Trigger DMA */
    vdp_dma_update(Z80.cycles);
  }
}

static unsigned int vdp_z80_data_r_m4(void)
{
  /* Read buffer */
  unsigned int data = fifo[0];

  /* Clear pending flag */
  pending = 0;

  /* Process next read */
  fifo[0] = vram[addr & 0x3FFF];

  /* Increment address register (TODO: check how address is incremented with Mega Drive VDP in Mode 4) */
  addr += (reg[15] + 1);

  /* Return data */
  return data;
}

static unsigned int vdp_z80_data_r_m5(void)
{
  unsigned int data = 0;

  /* Clear pending flag */
  pending = 0;

  /* Check destination code (CD0-CD3) & CD4 */
  switch (code & 0x1F)
  {
    case 0x00: /* VRAM */
    {
      /* Return low byte from even address & high byte from odd address */
      data = READ_BYTE(vram, addr ^ 1);
      break;
    }

    case 0x04: /* VSRAM */
    {
      /* Return low byte from even address & high byte from odd address */
      data = READ_BYTE(vsram, (addr & 0x7F) ^ 1);
      break;
    }

    case 0x08: /* CRAM */
    {
      /* Read CRAM data */
      data = *(uint16 *)&cram[addr & 0x7E];

      /* Unpack 9-bit CRAM data (BBBGGGRRR) to 16-bit data (BBB0GGG0RRR0) */
      data = ((data & 0x1C0) << 3) | ((data & 0x038) << 2) | ((data & 0x007) << 1);

      /* Return low byte from even address & high byte from odd address */
      if (addr & 1)
      {
        data = data >> 8;
      }

      data &= 0xFF;
      break;
    }
  }

  /* Increment address register */
  addr += reg[15];

  /* Return data */
  return data;
}


/*-----------------------------------------------------------------------------*/
/* Z80 bus interface (Master System, Game Gear & SG-1000 VDP)                  */
/*-----------------------------------------------------------------------------*/

static void vdp_z80_data_w_ms(unsigned int data)
{
  /* Clear pending flag */
  pending = 0;

  if (code < 3)
  {
    int index;

    /* Check if we are already on next line */
    if ((Z80.cycles - mcycles_vdp) >= MCYCLES_PER_LINE)
    {
      /* update line counter */
      int line = (v_counter + 1) % lines_per_frame;

      /* check if we are within active display range */
      if ((line < bitmap.viewport.h) && !(work_ram[0x1ffb] & cart.special & HW_3D_GLASSES))
      {
        /* update VCounter to indicate next line has already been rendered */
        v_counter = line;

        /* render next line */
        render_line(line);
      }
    }

    /* VRAM address */
    index = addr & 0x3FFF;

    /* VRAM write */
    if (data != vram[index])
    {
      int name;
      vram[index] = data;
      MARK_BG_DIRTY(index);
    }

#ifdef LOGVDP
    error("[%d(%d)][%d(%d)] VRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (Z80.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, Z80.cycles, Z80.cycles%MCYCLES_PER_LINE, index, data, Z80.pc.w.l);
#endif
  }
  else
  {
    /* CRAM address */
    int index = addr & 0x1F;

    /* Pointer to CRAM word */
    uint16 *p = (uint16 *)&cram[index << 1];

    /* Check if CRAM data is being modified */
    if (data != *p)
    {
      /* Write CRAM data */
      *p = data;

      /* Update color palette */
      color_update_m4(index, data);

      /* Update backdrop color */
      if (index == (0x10 | (border & 0x0F)))
      {
        color_update_m4(0x40, data);
      }
    }
#ifdef LOGVDP
    error("[%d(%d)][%d(%d)] CRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (Z80.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, Z80.cycles, Z80.cycles%MCYCLES_PER_LINE, addr, data, Z80.pc.w.l);
#endif
  }

  /* Update read buffer */
  fifo[0] = data;

  /* Update address register */
  addr++;
}

static void vdp_z80_data_w_gg(unsigned int data)
{
  /* Clear pending flag */
  pending = 0;

  if (code < 3)
  {
    int index;

    /* Check if we are already on next line */
    if ((Z80.cycles - mcycles_vdp) >= MCYCLES_PER_LINE)
    {
      /* update line counter */
      int line = (v_counter + 1) % lines_per_frame;

      /* check if we are within active display range */
      if ((line < bitmap.viewport.h) && !(work_ram[0x1ffb] & cart.special & HW_3D_GLASSES))
      {
        /* update VCounter to indicate next line has already been rendered */
        v_counter = line;

        /* render next line */
        render_line(line);
      }
    }

    /* VRAM address */
    index = addr & 0x3FFF;

    /* VRAM write */
    if (data != vram[index])
    {
      int name;
      vram[index] = data;
      MARK_BG_DIRTY(index);
    }
#ifdef LOGVDP
    error("[%d(%d)][%d(%d)] VRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (Z80.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, Z80.cycles, Z80.cycles%MCYCLES_PER_LINE, index, data, Z80.pc.w.l);
#endif
  }
  else
  {
    if (addr & 1)
    {
      /* Pointer to CRAM word */
      uint16 *p = (uint16 *)&cram[addr & 0x3E];

      /* 12-bit data word */
      data = (data << 8) | cached_write;

      /* Check if CRAM data is being modified */
      if (data != *p)
      {
        /* Color index (0-31) */
        int index = (addr >> 1) & 0x1F;
        
        /* Write CRAM data */
        *p = data;

        /* Update color palette */
        color_update_m4(index, data);

        /* Update backdrop color */
        if (index == (0x10 | (border & 0x0F)))
        {
          color_update_m4(0x40, data);
        }
      }
    }
    else
    {
      /* Latch LSB */
      cached_write = data;
    }
#ifdef LOGVDP
    error("[%d(%d)][%d(%d)] CRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (Z80.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, Z80.cycles, Z80.cycles%MCYCLES_PER_LINE, addr, data, Z80.pc.w.l);
#endif
  }

  /* Update read buffer */
  fifo[0] = data;

  /* Update address register */
  addr++;
}

static void vdp_z80_data_w_sg(unsigned int data)
{
  /* VRAM address */
  int index = addr & 0x3FFF;

  /* Clear pending flag */
  pending = 0;

  /* VRAM write */
  vram[index] = data;

  /* Update address register */
  addr++;

#ifdef LOGVDP
  error("[%d(%d)][%d(%d)] VRAM 0x%x write -> 0x%x (%x)\n", v_counter, (v_counter + (Z80.cycles - mcycles_vdp)/MCYCLES_PER_LINE)%lines_per_frame, Z80.cycles, Z80.cycles%MCYCLES_PER_LINE, index, data, Z80.pc.w.l);
#endif
}

/*--------------------------------------------------------------------------*/
/* DMA operations (Mega Drive VDP only)                                     */
/*--------------------------------------------------------------------------*/

/* DMA from 68K bus: $000000-$7FFFFF (external area) */
static void vdp_dma_68k_ext(unsigned int length)
{
  uint16 data;

  /* 68k bus source address */
  uint32 source = (reg[23] << 17) | (dma_src << 1);

  do
  {
    /* Read data word from 68k bus */
    if (m68k.memory_map[source>>16].read16)
    {
      data = m68k.memory_map[source>>16].read16(source);
    }
    else
    {
      data = *(uint16 *)(m68k.memory_map[source>>16].base + (source & 0xFFFF));
    }
 
    /* Increment source address */
    source += 2;

    /* 128k DMA window */
    source = (reg[23] << 17) | (source & 0x1FFFF);

    /* Write data word to VRAM, CRAM or VSRAM */
    vdp_bus_w(data);
  }
  while (--length);

  /* Update DMA source address */
  dma_src = (source >> 1) & 0xffff;
}

/* DMA from 68K bus: $800000-$FFFFFF (internal area) except I/O area */
static void vdp_dma_68k_ram(unsigned int length)
{
  uint16 data;

  /* 68k bus source address */
  uint32 source = (reg[23] << 17) | (dma_src << 1);

  do
  {
    /* access Work-RAM by default  */
    data = *(uint16 *)(work_ram + (source & 0xFFFF));
   
    /* Increment source address */
    source += 2;

    /* 128k DMA window */
    source = (reg[23] << 17) | (source & 0x1FFFF);

    /* Write data word to VRAM, CRAM or VSRAM */
    vdp_bus_w(data);
  }
  while (--length);

  /* Update DMA source address */
  dma_src = (source >> 1) & 0xffff;
}

/* DMA from 68K bus: $A00000-$A1FFFF (I/O area) specific */
static void vdp_dma_68k_io(unsigned int length)
{
  uint16 data;

  /* 68k bus source address */
  uint32 source = (reg[23] << 17) | (dma_src << 1);

  do
  {
    /* Z80 area */
    if (source <= 0xA0FFFF)
    {
      /* Return $FFFF only when the Z80 isn't hogging the Z-bus.
      (e.g. Z80 isn't reset and 68000 has the bus) */
      data = ((zstate ^ 3) ? *(uint16 *)(work_ram + (source & 0xFFFF)) : 0xFFFF);
    }

    /* The I/O chip and work RAM try to drive the data bus which results 
       in both values being combined in random ways when read.
       We return the I/O chip values which seem to have precedence, */
    else if (source <= 0xA1001F)
    {
      data = io_68k_read((source >> 1) & 0x0F);
      data = (data << 8 | data);
    }

    /* All remaining locations access work RAM */
    else
    {
      data = *(uint16 *)(work_ram + (source & 0xFFFF));
    }

    /* Increment source address */
    source += 2;

    /* 128k DMA window */
    source = (reg[23] << 17) | (source & 0x1FFFF);

    /* Write data to VRAM, CRAM or VSRAM */
    vdp_bus_w(data);
  }
  while (--length);

  /* Update DMA source address */
  dma_src = (source >> 1) & 0xffff;
}

/*  VRAM Copy */
static void vdp_dma_copy(unsigned int length)
{
  /* CD4 should be set (CD0-CD3 ignored) otherwise VDP locks (hard reset needed) */
  if (code & 0x10)
  {
    int name;
    uint8 data;
    
    /* VRAM source address */
    uint16 source = dma_src;

    do
    {
      /* Read byte from adjacent VRAM source address */
      data = READ_BYTE(vram, source ^ 1);

      /* Intercept writes to Sprite Attribute Table */
      if ((addr & sat_base_mask) == satb)
      {
        /* Update internal SAT */
        WRITE_BYTE(sat, (addr & sat_addr_mask) ^ 1, data);
      }

      /* Write byte to adjacent VRAM destination address */
      WRITE_BYTE(vram, addr ^ 1, data);

      /* Update pattern cache */
      MARK_BG_DIRTY(addr);

      /* Increment VRAM source address */
      source++;

      /* Increment VRAM destination address */
      addr += reg[15];
    }
    while (--length);

    /* Update DMA source address */
    dma_src = source;
  }
}

/* DMA Fill */
static void vdp_dma_fill(unsigned int length)
{
  /* Check destination code (CD0-CD3) */
  switch (code & 0x0F)
  {
    case 0x01:  /* VRAM */
    {
      int name;

      /* Get source data from last written FIFO  entry */
      uint8 data = fifo[(fifo_idx+3)&3] >> 8;

      do
      {
        /* Intercept writes to Sprite Attribute Table */
        if ((addr & sat_base_mask) == satb)
        {
          /* Update internal SAT */
          WRITE_BYTE(sat, (addr & sat_addr_mask) ^ 1, data);
        }

        /* Write byte to adjacent VRAM address */
        WRITE_BYTE(vram, addr ^ 1, data);

        /* Update pattern cache */
        MARK_BG_DIRTY (addr);

        /* Increment VRAM address */
        addr += reg[15];
      }
      while (--length);
      break;
    }

    case 0x03:  /* CRAM */
    {
      /* Get source data from next available FIFO entry */
      uint16 data = fifo[fifo_idx];

      /* Pack 16-bit bus data (BBB0GGG0RRR0) to 9-bit CRAM data (BBBGGGRRR) */
      data = ((data & 0xE00) >> 3) | ((data & 0x0E0) >> 2) | ((data & 0x00E) >> 1);

      do
      {
        /* Pointer to CRAM 9-bit word */
        uint16 *p = (uint16 *)&cram[addr & 0x7E];

        /* Check if CRAM data is being modified */
        if (data != *p)
        {
          /* CRAM index (64 words) */
          int index = (addr >> 1) & 0x3F;

          /* Write CRAM data */
          *p = data;

          /* Color entry 0 of each palette is never displayed (transparent pixel) */
          if (index & 0x0F)
          {
            /* Update color palette */
            color_update_m5(index, data);
          }

          /* Update backdrop color */
          if (index == border)
          {
            color_update_m5(0x00, data);
          }
        }
          
        /* Increment CRAM address */
        addr += reg[15];
      }
      while (--length);
      break;
    }

    case 0x05:  /* VSRAM */
    {
      /* Get source data from next available FIFO entry */
      uint16 data = fifo[fifo_idx];

      do
      {
        /* Write VSRAM data */
        *(uint16 *)&vsram[addr & 0x7E] = data;
          
        /* Increment VSRAM address */
        addr += reg[15];
      }
      while (--length);
      break;
    }

    default:
    {
      /* invalid destination does nothing (Williams Greatest Hits after soft reset) */

      /* address is still incremented */
      addr += reg[15] * length;
    }
  }
}
