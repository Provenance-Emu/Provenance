/***************************************************************************************
 *  Genesis Plus
 *  Virtual System emulation
 *
 *  Support for 16-bit & 8-bit hardware modes
 *
 *  Copyright (C) 1998-2003  Charles Mac Donald (original code)
 *  Copyright (C) 2007-2018  Eke-Eke (Genesis Plus GX)
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
#include "eq.h"

/* Global variables */
t_bitmap bitmap;
t_snd snd;
uint32 mcycles_vdp;
uint8 system_hw;
uint8 system_bios;
uint32 system_clock;
int16 SVP_cycles = 800; 

static uint8 pause_b;
static EQSTATE eq[2];
static int16 llp,rrp;

/******************************************************************************************/
/* Audio subsystem                                                                        */
/******************************************************************************************/

int audio_init(int samplerate, double framerate)
{
  /* Shutdown first */
  audio_shutdown();

  /* Clear the sound data context */
  memset(&snd, 0, sizeof (snd));

  /* Initialize Blip Buffers */
  snd.blips[0] = blip_new(samplerate / 10);
  if (!snd.blips[0])
  {
    return -1;
  }

  /* Mega CD sound hardware */
  if (system_hw == SYSTEM_MCD)
  {
    /* allocate blip buffers */
    snd.blips[1] = blip_new(samplerate / 10);
    snd.blips[2] = blip_new(samplerate / 10);
    if (!snd.blips[1] || !snd.blips[2])
    {
      audio_shutdown();
      return -1;
    }
  }

  /* Initialize resampler internal rates */
  audio_set_rate(samplerate, framerate);

  /* Set audio enable flag */
  snd.enabled = 1;

  /* Reset audio */
  audio_reset();

  return (0);
}

void audio_set_rate(int samplerate, double framerate)
{
  /* Number of M-cycles executed per second. */
  /* All emulated chips are kept in sync by using a common oscillator (MCLOCK)            */
  /*                                                                                      */
  /* The original console would run exactly 53693175 M-cycles per sec (53203424 for PAL), */
  /* 3420 M-cycles per line and 262 (313 for PAL) lines per frame, which gives an exact   */
  /* framerate of 59.92 (49.70 for PAL) frames per second.                                */
  /*                                                                                      */
  /* Since audio samples are generated at the end of the frame, to prevent audio skipping */
  /* or lag between emulated frames, number of samples rendered per frame must be set to  */
  /* output samplerate (number of samples played per second) divided by input framerate   */
  /* (number of frames emulated per seconds).                                             */
  /*                                                                                      */
  /* On some systems, we may want to achieve 100% smooth video rendering by synchronizing */
  /* frame emulation with VSYNC, which frequency is generally not exactly those values.   */
  /* In that case, input framerate (number of frames emulated per seconds) is the same as */
  /* output framerate (number of frames rendered per seconds) by the host video hardware. */
  /*                                                                                      */
  /* When no framerate is specified, base clock is set to original master clock value.    */
  /* Otherwise, it is set to number of M-cycles emulated per line (fixed) multiplied by   */
  /* number of lines per frame (VDP mode specific) multiplied by input framerate.         */
  /*                                                                                      */
  double mclk = framerate ? (MCYCLES_PER_LINE * (vdp_pal ? 313 : 262) * framerate) : system_clock;

  /* For maximal accuracy, sound chips are running at their original rate using common */
  /* master clock timebase so they remain perfectly synchronized together, while still */
  /* being synchronized with 68K and Z80 CPUs as well. Mixed sound chip output is then */
  /* resampled to desired rate at the end of each frame, using Blip Buffer.            */
  blip_set_rates(snd.blips[0], mclk, samplerate);

  /* Mega CD sound hardware */
  if (system_hw == SYSTEM_MCD)
  {
    /* number of SCD master clocks run per second */
    mclk = (mclk / system_clock) * SCD_CLOCK;

    /* PCM core */
    pcm_init(mclk, samplerate);

    /* CDD core */
    cdd_init(samplerate);
  }

  /* Reinitialize internal rates */
  snd.sample_rate = samplerate;
  snd.frame_rate  = framerate;
}

void audio_reset(void)
{
  int i;
  
  /* Clear blip buffers */
  for (i=0; i<3; i++)
  {
    if (snd.blips[i])
    {
      blip_clear(snd.blips[i]);
    }
  }

  /* Low-Pass filter */
  llp = 0;
  rrp = 0;

  /* 3 band EQ */
  audio_set_equalizer();
}

void audio_set_equalizer(void)
{
  init_3band_state(&eq[0],config.low_freq,config.high_freq,snd.sample_rate);
  init_3band_state(&eq[1],config.low_freq,config.high_freq,snd.sample_rate);
  eq[0].lg = eq[1].lg = (double)(config.lg) / 100.0;
  eq[0].mg = eq[1].mg = (double)(config.mg) / 100.0;
  eq[0].hg = eq[1].hg = (double)(config.hg) / 100.0;
}

void audio_shutdown(void)
{
  int i;
  
  /* Delete blip buffers */
  for (i=0; i<3; i++)
  {
    blip_delete(snd.blips[i]);
    snd.blips[i] = 0;
  }
}

int audio_update(int16 *buffer)
{
  /* run sound chips until end of frame */
  int size = sound_update(mcycles_vdp);

  /* Mega CD specific */
  if (system_hw == SYSTEM_MCD)
  {
    /* sync PCM chip with other sound chips */
    pcm_update(size);

    /* read CDDA samples */
    cdd_read_audio(size);

#ifdef ALIGN_SND
    /* return an aligned number of samples if required */
    size &= ALIGN_SND;
#endif

    /* resample & mix FM/PSG, PCM & CD-DA streams to output buffer */
    blip_mix_samples(snd.blips[0], snd.blips[1], snd.blips[2], buffer, size);
  }
  else
  {
#ifdef ALIGN_SND
    /* return an aligned number of samples if required */
    size &= ALIGN_SND;
#endif

    /* resample FM/PSG mixed stream to output buffer */
    blip_read_samples(snd.blips[0], buffer, size);
  }

  /* Audio filtering */
  if (config.filter)
  {
    int samples = size;
    int16 *out = buffer;
    int32 l, r;

    if (config.filter & 1)
    {
      /* single-pole low-pass filter (6 dB/octave) */
      uint32 factora  = config.lp_range;
      uint32 factorb  = 0x10000 - factora;

      /* restore previous sample */
      l = llp;
      r = rrp;

      do
      {
        /* apply low-pass filter */
        l = l*factora + out[0]*factorb;
        r = r*factora + out[1]*factorb;

        /* 16.16 fixed point */
        l >>= 16;
        r >>= 16;

        /* update sound buffer */
        *out++ = l;
        *out++ = r;
      }
      while (--samples);

      /* save last samples for next frame */
      llp = l;
      rrp = r;
    }
    else if (config.filter & 2)
    {
      do
      {
        /* 3 Band EQ */
        l = do_3band(&eq[0],out[0]);
        r = do_3band(&eq[1],out[1]);

        /* clipping (16-bit samples) */
        if (l > 32767) l = 32767;
        else if (l < -32768) l = -32768;
        if (r > 32767) r = 32767;
        else if (r < -32768) r = -32768;

        /* update sound buffer */
        *out++ = l;
        *out++ = r;
      }
      while (--samples);
    }
  }

  /* Mono output mixing */
  if (config.mono)
  {
    int16 out;
    int samples = size;
    do
    {
      out = (buffer[0] + buffer[1]) / 2;
      *buffer++ = out;
      *buffer++ = out;
    }
    while (--samples);
  }

#ifdef LOGSOUND
  error("%d samples returned\n\n",size);
#endif

  return size;
}

/****************************************************************
 * Virtual System emulation
 ****************************************************************/
void system_init(void)
{
  gen_init();
  io_init();
  vdp_init();
  render_init();
  sound_init();
}

void system_reset(void)
{
  gen_reset(1);
  io_reset();
  render_reset();
  vdp_reset();
  sound_reset();
  audio_reset();
}

void system_frame_gen(int do_skip)
{
  /* line counters */
  int start, end, line;

  /* reset frame cycle counter */
  mcycles_vdp = 0;

  /* reset VDP FIFO */
  fifo_write_cnt = 0;
  fifo_slots = 0;

  /* check if display setings have changed during previous frame */
  if (bitmap.viewport.changed & 2)
  {
    /* interlaced modes */
    int old_interlaced = interlaced;
    interlaced = (reg[12] & 0x02) >> 1;

    if (old_interlaced != interlaced)
    {
      /* double resolution mode */
      im2_flag = ((reg[12] & 0x06) == 0x06);

      /* reset field status flag */
      odd_frame = interlaced;

      /* video mode has changed */
      bitmap.viewport.changed = 5;

      /* update rendering mode */
      if (reg[1] & 0x04)
      {
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
      }
    }
    else
    {
      /* clear flag */
      bitmap.viewport.changed &= ~2;
    }

    /* active screen height */
    if (reg[1] & 0x04)
    {
      /* Mode 5 */
      if (reg[1] & 0x08)
      {
        /* 240 active lines */
        bitmap.viewport.h = 240;
        bitmap.viewport.y = (config.overscan & 1) * 24 * vdp_pal;
      }
      else
      {
        /* 224 active lines */
        bitmap.viewport.h = 224;
        bitmap.viewport.y = (config.overscan & 1) * (8 + (24 * vdp_pal));
      }
    }
    else
    {
      /* Mode 4 (192 active lines) */
      bitmap.viewport.h = 192;
      bitmap.viewport.y = (config.overscan & 1) * 24 * (vdp_pal + 1);
    }

    /* active screen width */
    bitmap.viewport.w = 256 + ((reg[12] & 0x01) << 6);

    /* check viewport changes */
    if (bitmap.viewport.h != bitmap.viewport.oh)
    {
      bitmap.viewport.oh = bitmap.viewport.h;
      bitmap.viewport.changed |= 1;
    }
  }

  /* first line of overscan */
  if (bitmap.viewport.y)
  {
    blank_line(bitmap.viewport.h, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
  }
  
  /* clear DMA Busy, FIFO FULL & field flags */
  status &= 0xFEED;

  /* set VBLANK & FIFO EMPTY flags */
  status |= 0x0208;

  /* check interlaced modes */
  if (interlaced)
  {
    /* switch even/odd field flag */
    odd_frame ^= 1;
    status |= (odd_frame << 4);
  }

  /* run VDP DMA */
  if (dma_length)
  {
    vdp_dma_update(0);
  }

  /* update 6-Buttons & Lightguns */
  input_refresh();
  
  /* H-Int counter */
  if (h_counter == 0)
  {
    /* Horizontal Interrupt is pending */
    hint_pending = 0x10;
    if (reg[0] & 0x10)
    {
      /* level 4 interrupt */
      m68k_update_irq(4);
    }
  }

  /* refresh inputs just before VINT (Warriors of Eternal Sun) */
  osd_input_update();

  /* VDP always starts after VBLANK so VINT cannot occur on first frame after a VDP reset (verified on real hardware) */
  if (v_counter != bitmap.viewport.h)
  {
    /* reinitialize VCounter */
    v_counter = bitmap.viewport.h;

    /* delay between VBLANK flag & Vertical Interrupt (Dracula, OutRunners, VR Troopers) */
    m68k_run(788);
    if (zstate == 1)
    {
      z80_run(788);
    }

    /* set VINT flag */
    status |= 0x80;    
   
    /* Vertical Interrupt */
    vint_pending = 0x20;
    if (reg[1] & 0x20)
    {
      /* level 6 interrupt */
      m68k_set_irq(6);
    }

    /* assert Z80 interrupt */
    Z80.irq_state = ASSERT_LINE;
  }

  /* run 68k & Z80 until end of line */
  m68k_run(MCYCLES_PER_LINE);
  if (zstate == 1)
  {
    z80_run(MCYCLES_PER_LINE);
  }

  /* Z80 interrupt is cleared at the end of the line */
  Z80.irq_state = CLEAR_LINE;

  /* run SVP chip */
  if (svp)
  {
    ssp1601_run(SVP_cycles);
  }

  /* update VDP cycle count */
  mcycles_vdp = MCYCLES_PER_LINE;

  /* initialize line count */
  line = bitmap.viewport.h + 1; 

  /* initialize overscan area */
  start = lines_per_frame - bitmap.viewport.y;
  end = bitmap.viewport.h + bitmap.viewport.y;

  /* Vertical Blanking */
  do
  {
    /* update VCounter */
    v_counter = line;

    /* render overscan */
    if ((line < end) || (line >= start))
    {
      blank_line(line, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
    }

    /* update 6-Buttons & Lightguns */
    input_refresh();

    /* run 68k & Z80 until end of line */
    m68k_run(mcycles_vdp + MCYCLES_PER_LINE);
    if (zstate == 1)
    {
      z80_run(mcycles_vdp + MCYCLES_PER_LINE);
    }

    /* run SVP chip */
    if (svp)
    {
      ssp1601_run(SVP_cycles);
    }

    /* update VDP cycle count */
    mcycles_vdp += MCYCLES_PER_LINE;
  }
  while (++line < (lines_per_frame - 1));
  
  /* update VCounter */
  v_counter = line;

  /* last line of overscan */
  if (bitmap.viewport.y)
  {
    blank_line(line, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
  }

  /* reload H-Int counter */
  h_counter = reg[10];
  
  /* clear VBLANK flag */
  status &= ~0x08;
 
  /* run VDP DMA */
  if (dma_length)
  {
    vdp_dma_update(mcycles_vdp);
  }

  /* parse first line of sprites */
  if (reg[1] & 0x40)
  {
    parse_satb(-1);
  }

  /* update 6-Buttons & Lightguns */
  input_refresh();

  /* run 68k & Z80 until end of line */
  m68k_run(mcycles_vdp + MCYCLES_PER_LINE);
  if (zstate == 1)
  {
    z80_run(mcycles_vdp + MCYCLES_PER_LINE);
  }

  /* run SVP chip */
  if (svp)
  {
    ssp1601_run(SVP_cycles);
  }

  /* update VDP cycle count */
  mcycles_vdp += MCYCLES_PER_LINE;

  /* reset line count */
  line = 0;
  
  /* Active Display */
  do
  {
    /* update VCounter */
    v_counter = line;

    /* run VDP DMA */
    if (dma_length)
    {
      vdp_dma_update(mcycles_vdp);
    }

    /* render scanline */
    if (!do_skip)
    {
      render_line(line);
    }

    /* update 6-Buttons & Lightguns */
    input_refresh();

    /* H-Int counter */
    if (h_counter == 0)
    {
      /* reload H-Int counter */
      h_counter = reg[10];
      
      /* Horizontal Interrupt is pending */
      hint_pending = 0x10;
      if (reg[0] & 0x10)
      {
        /* level 4 interrupt */
        m68k_update_irq(4);
      }
    }
    else
    {
      /* decrement H-Int counter */
      h_counter--;
    }

    /* run 68k & Z80 until end of line */
    m68k_run(mcycles_vdp + MCYCLES_PER_LINE);
    if (zstate == 1)
    {
      z80_run(mcycles_vdp + MCYCLES_PER_LINE);
    }

    /* run SVP chip */
    if (svp)
    {
      ssp1601_run(SVP_cycles);
    }

    /* update VDP cycle count */
    mcycles_vdp += MCYCLES_PER_LINE;
  }
  while (++line < bitmap.viewport.h);

  /* check viewport changes */
  if (bitmap.viewport.w != bitmap.viewport.ow)
  {
    bitmap.viewport.ow = bitmap.viewport.w;
    bitmap.viewport.changed |= 1;
  }

  /* adjust timings for next frame */
  input_end_frame(mcycles_vdp);
  m68k.cycles -= mcycles_vdp;
  Z80.cycles -= mcycles_vdp;
}

void system_frame_scd(int do_skip)
{
  /* line counters */
  int start, end, line;

  /* reset frame cycle counter */
  mcycles_vdp = 0;
  scd.cycles = 0;

  /* reset VDP FIFO */
  fifo_write_cnt = 0;
  fifo_slots = 0;

  /* check if display setings have changed during previous frame */
  if (bitmap.viewport.changed & 2)
  {
    /* interlaced modes */
    int old_interlaced = interlaced;
    interlaced = (reg[12] & 0x02) >> 1;

    if (old_interlaced != interlaced)
    {
      /* double resolution mode */
      im2_flag = ((reg[12] & 0x06) == 0x06);

      /* reset field status flag */
      odd_frame = interlaced;

      /* video mode has changed */
      bitmap.viewport.changed = 5;

      /* update rendering mode */
      if (reg[1] & 0x04)
      {
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
      }
    }
    else
    {
      /* clear flag */
      bitmap.viewport.changed &= ~2;
    }

    /* active screen height */
    if (reg[1] & 0x04)
    {
      /* Mode 5 */
      if (reg[1] & 0x08)
      {
        /* 240 active lines */
        bitmap.viewport.h = 240;
        bitmap.viewport.y = (config.overscan & 1) * 24 * vdp_pal;
      }
      else
      {
        /* 224 active lines */
        bitmap.viewport.h = 224;
        bitmap.viewport.y = (config.overscan & 1) * (8 + (24 * vdp_pal));
      }
    }
    else
    {
      /* Mode 4 (192 active lines) */
      bitmap.viewport.h = 192;
      bitmap.viewport.y = (config.overscan & 1) * 24 * (vdp_pal + 1);
    }

    /* active screen width */
    bitmap.viewport.w = 256 + ((reg[12] & 0x01) << 6);

    /* check viewport changes */
    if (bitmap.viewport.h != bitmap.viewport.oh)
    {
      bitmap.viewport.oh = bitmap.viewport.h;
      bitmap.viewport.changed |= 1;
    }
  }

  /* first line of overscan */
  if (bitmap.viewport.y)
  {
    blank_line(bitmap.viewport.h, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
  }
  
  /* clear DMA Busy, FIFO FULL & field flags */
  status &= 0xFEED;

  /* set VBLANK & FIFO EMPTY flags */
  status |= 0x0208;

  /* check interlaced modes */
  if (interlaced)
  {
    /* switch even/odd field flag */
    odd_frame ^= 1;
    status |= (odd_frame << 4);
  }

  /* run VDP DMA */
  if (dma_length)
  {
    vdp_dma_update(0);
  }

  /* update 6-Buttons & Lightguns */
  input_refresh();

  /* H-Int counter */
  if (h_counter == 0)
  {
    /* Horizontal Interrupt is pending */
    hint_pending = 0x10;
    if (reg[0] & 0x10)
    {
      /* level 4 interrupt */
      m68k_update_irq(4);
    }
  }

  /* refresh inputs just before VINT */
  osd_input_update();

  /* VDP always starts after VBLANK so VINT cannot occur on first frame after a VDP reset (verified on real hardware) */
  if (v_counter != bitmap.viewport.h)
  {
    /* reinitialize VCounter */
    v_counter = bitmap.viewport.h;

    /* delay between VBLANK flag & Vertical Interrupt (Dracula, OutRunners, VR Troopers) */
    m68k_run(788);
    if (zstate == 1)
    {
      z80_run(788);
    }

    /* set VINT flag */
    status |= 0x80;    

    /* Vertical Interrupt */
    vint_pending = 0x20;
    if (reg[1] & 0x20)
    {
      /* level 6 interrupt */
      m68k_set_irq(6);
    }

    /* assert Z80 interrupt */
    Z80.irq_state = ASSERT_LINE;
  }

  /* run both 68k & CD hardware until end of line */
  scd_update(MCYCLES_PER_LINE);

  /* run Z80 until end of line */
  if (zstate == 1)
  {
    z80_run(MCYCLES_PER_LINE);
  }

  /* Z80 interrupt is cleared at the end of the line */
  Z80.irq_state = CLEAR_LINE;

  /* update VDP cycle count */
  mcycles_vdp = MCYCLES_PER_LINE;

  /* initialize line count */
  line = bitmap.viewport.h + 1; 

  /* initialize overscan area */
  start = lines_per_frame - bitmap.viewport.y;
  end = bitmap.viewport.h + bitmap.viewport.y;

  /* Vertical Blanking */
  do
  {
    /* update VCounter */
    v_counter = line;

    /* render overscan */
    if ((line < end) || (line >= start))
    {
      blank_line(line, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
    }

    /* update 6-Buttons & Lightguns */
    input_refresh();

    /* run both 68k & CD hardware until end of line */
    scd_update(mcycles_vdp + MCYCLES_PER_LINE);

    /* run Z80 until end of line */
    if (zstate == 1)
    {
      z80_run(mcycles_vdp + MCYCLES_PER_LINE);
    }

    /* update VDP cycle count */
    mcycles_vdp += MCYCLES_PER_LINE;
  }
  while (++line < (lines_per_frame - 1));
  
  /* update VCounter */
  v_counter = line;

  /* last line of overscan */
  if (bitmap.viewport.y)
  {
    blank_line(line, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
  }

  /* reload H-Int counter */
  h_counter = reg[10];
  
  /* clear VBLANK flag */
  status &= ~0x08;
 
  /* run VDP DMA */
  if (dma_length)
  {
    vdp_dma_update(mcycles_vdp);
  }

  /* parse first line of sprites */
  if (reg[1] & 0x40)
  {
    parse_satb(-1);
  }

  /* update 6-Buttons & Lightguns */
  input_refresh();

  /* run both 68k & CD hardware until end of line */
  scd_update(mcycles_vdp + MCYCLES_PER_LINE);

  /* run Z80 until end of line */
  if (zstate == 1)
  {
    z80_run(mcycles_vdp + MCYCLES_PER_LINE);
  }

  /* update VDP cycle count */
  mcycles_vdp += MCYCLES_PER_LINE;

  /* reset line count */
  line = 0;
  
  /* Active Display */
  do
  {
    /* update VCounter */
    v_counter = line;

    /* run VDP DMA */
    if (dma_length)
    {
      vdp_dma_update(mcycles_vdp);
    }

    /* render scanline */
    if (!do_skip)
    {
      render_line(line);
    }
    
    /* update 6-Buttons & Lightguns */
    input_refresh();

    /* H-Int counter */
    if (h_counter == 0)
    {
      /* reload H-Int counter */
      h_counter = reg[10];
      
      /* Horizontal Interrupt is pending */
      hint_pending = 0x10;
      if (reg[0] & 0x10)
      {
        /* level 4 interrupt */
        m68k_update_irq(4);
      }
    }
    else
    {
      /* decrement H-Int counter */
      h_counter--;
    }

    /* run both 68k & CD hardware until end of line */
    scd_update(mcycles_vdp + MCYCLES_PER_LINE);

    /* run Z80 until end of line */
    if (zstate == 1)
    {
      z80_run(mcycles_vdp + MCYCLES_PER_LINE);
    }

    /* update VDP cycle count */
    mcycles_vdp += MCYCLES_PER_LINE;
  }
  while (++line < bitmap.viewport.h);

  /* check viewport changes */
  if (bitmap.viewport.w != bitmap.viewport.ow)
  {
    bitmap.viewport.ow = bitmap.viewport.w;
    bitmap.viewport.changed |= 1;
  }
  
  /* adjust timings for next frame */
  scd_end_frame(scd.cycles);
  input_end_frame(mcycles_vdp);
  m68k.cycles -= mcycles_vdp;
  Z80.cycles -= mcycles_vdp;
}

void system_frame_sms(int do_skip)
{
  /* line counter */
  int start, end, line;

  /* reset frame cycle count */
  mcycles_vdp = 0;

  /* reset VDP FIFO */
  fifo_write_cnt = 0;
  fifo_slots = 0;

  /* check if display settings has changed during previous frame */
  if (bitmap.viewport.changed & 2)
  {
    bitmap.viewport.changed &= ~2;

    if (system_hw & SYSTEM_MD)
    {
      /* interlaced modes */
      int old_interlaced = interlaced;
      interlaced = (reg[12] & 0x02) >> 1;

      if (old_interlaced != interlaced)
      {
        /* double resolution mode */
        im2_flag = ((reg[12] & 0x06) == 0x06);

        /* reset field status flag */
        odd_frame = interlaced;

        /* video mode has changed */
        bitmap.viewport.changed = 5;

        /* update rendering mode */
        if (reg[1] & 0x04)
        {
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
        }
      }

      /* active screen height */
      if (reg[1] & 0x04)
      {
        /* Mode 5 */
        if (reg[1] & 0x08)
        {
          /* 240 active lines */
          bitmap.viewport.h = 240;
          bitmap.viewport.y = (config.overscan & 1) * 24 * vdp_pal;
        }
        else
        {
          /* 224 active lines */
          bitmap.viewport.h = 224;
          bitmap.viewport.y = (config.overscan & 1) * (8 + (24 * vdp_pal));
        }
      }
      else
      {
        bitmap.viewport.h = 192;
        bitmap.viewport.y = (config.overscan & 1) * 24 * (vdp_pal + 1);
      }
    }
    else
    {
      /* check for VDP extended modes */
      int mode = (reg[0] & 0x06) | (reg[1] & 0x18);

      /* update active height */
      if (mode == 0x0E)
      {
        bitmap.viewport.h = 240;
      }
      else if (mode == 0x16)
      {
        bitmap.viewport.h = 224;
      }
      else
      {
        bitmap.viewport.h = 192;
      }

      /* update vertical overscan */
      if (config.overscan & 1)
      {
        bitmap.viewport.y = (240 + 48*vdp_pal - bitmap.viewport.h) >> 1;
      }
      else
      {
        if ((system_hw == SYSTEM_GG) && !config.gg_extra)
        {
          /* Display area reduced to 160x144 */
          bitmap.viewport.y = (144 - bitmap.viewport.h) / 2;
        }
        else
        {
          bitmap.viewport.y = 0;
        }
      }
    }

    /* active screen width */
    bitmap.viewport.w = 256 + ((reg[12] & 0x01) << 6);

    /* check viewport changes */
    if (bitmap.viewport.h != bitmap.viewport.oh)
    {
      bitmap.viewport.oh = bitmap.viewport.h;
      bitmap.viewport.changed |= 1;
    }
  }

  /* initialize VCounter */
  v_counter = bitmap.viewport.h;

  /* first line of overscan */
  if (bitmap.viewport.y > 0)
  {
    blank_line(v_counter, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
  }

  /* Mega Drive VDP specific */
  if (system_hw & SYSTEM_MD)
  {
    /* clear DMA Busy & field flags */
    status &= 0xED;

    /* set VBLANK flag */
    status |= 0x08;

    /* interlaced modes only */
    if (interlaced)
    {
      /* switch even/odd field flag */
      odd_frame ^= 1;
      status |= (odd_frame << 4);
    }

    /* run VDP DMA */
    if (dma_length)
    {
      vdp_dma_update(0);
    }
  }

  /* update 6-Buttons & Lightguns */
  input_refresh();

  /* H-Int counter */
  if (h_counter == 0)
  {
    /* Horizontal Interrupt is pending */
    hint_pending = 0x10;
    if (reg[0] & 0x10)
    {
      /* Cycle-accurate HINT */
      /* IRQ line is latched between instructions, during instruction last cycle.       */
      /* This means that if Z80 cycle count is exactly a multiple of MCYCLES_PER_LINE,  */
      /* interrupt should be triggered AFTER the next instruction.                      */
      if ((Z80.cycles % MCYCLES_PER_LINE) == 0)
      {
        z80_run(Z80.cycles + 1);
      }

      /* Z80 interrupt */
      Z80.irq_state = ASSERT_LINE;
    }
  }

  /* refresh inputs just before VINT */
  osd_input_update();

  /* run Z80 until end of line */
  z80_run(MCYCLES_PER_LINE);

  /* make sure VINT flag was not read (then cleared) by last instruction */
  if (v_counter == bitmap.viewport.h)
  {
    /* Set VINT flag */
    status |= 0x80;

    /* Vertical Interrupt */
    vint_pending = 0x20;
    if (reg[1] & 0x20)
    {
      Z80.irq_state = ASSERT_LINE;
    }
  }

  /* update VDP cycle count */
  mcycles_vdp = MCYCLES_PER_LINE;

  /* initialize line count */
  line = bitmap.viewport.h + 1;

  /* initialize overscan area */
  start = lines_per_frame - bitmap.viewport.y;
  end   = bitmap.viewport.h + bitmap.viewport.y;

  /* Vertical Blanking */
  do
  {
    /* update VCounter */
    v_counter = line;

    /* render overscan */
    if ((line < end) || (line >= start))
    {
      /* Master System & Game Gear VDP specific */
      if ((system_hw < SYSTEM_MD) && (line > (lines_per_frame - 16)))
      {
        /* Sprites are still processed during top border */
        if (reg[1] & 0x40)
        {
          render_obj((line - lines_per_frame) & 1);
        }
        
        /* Sprites pre-processing occurs even when display is disabled */
        parse_satb(line - lines_per_frame);
      }

      blank_line(line, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
    }

    /* update 6-Buttons & Lightguns */
    input_refresh();

    /* run Z80 until end of line */
    z80_run(mcycles_vdp + MCYCLES_PER_LINE);

    /* update VDP cycle count */
    mcycles_vdp += MCYCLES_PER_LINE;
  }
  while (++line < (lines_per_frame - 1));

  /* update VCounter */
  v_counter = line;

  /* last line of overscan */
  if (bitmap.viewport.y > 0)
  {
    /* Master System & Game Gear VDP specific */
    if (system_hw < SYSTEM_MD)
    {
      /* Sprites are still processed during top border */
      if (reg[1] & 0x40)
      {
        render_obj(1);
      }
    }

    blank_line(line, -bitmap.viewport.x, bitmap.viewport.w + 2*bitmap.viewport.x);
  }

  /* reload H-Int counter */
  h_counter = reg[10];

  /* Detect pause button input (in Game Gear Mode, NMI is not generated) */
  if (system_hw != SYSTEM_GG)
  {
    if (input.pad[0] & INPUT_START)
    {
      /* NMI is edge-triggered */
      if (!pause_b)
      {
        pause_b = 1;
        z80_set_nmi_line(ASSERT_LINE);
        z80_set_nmi_line(CLEAR_LINE);
      }
    }
    else
    {
      pause_b = 0;
    }
  }

  /* 3-D glasses faking: skip rendering of left lens frame */
  do_skip |= (work_ram[0x1ffb] & cart.special & HW_3D_GLASSES);

  /* Mega Drive VDP specific */
  if (system_hw & SYSTEM_MD)
  {
    /* clear VBLANK flag */
    status &= ~0x08;

    /* run VDP DMA */
    if (dma_length)
    {
      vdp_dma_update(mcycles_vdp);
    }
    
    /* parse first line of sprites */
    if (reg[1] & 0x40)
    {
      parse_satb(-1);
    }
  }

  /* Master System & Game Gear VDP specific */
  else
  {    
    /* Sprites pre-processing occurs even when display is disabled */
    parse_satb(-1);
  }

  /* update 6-Buttons & Lightguns */
  input_refresh();

  /* run Z80 until end of line */
  z80_run(mcycles_vdp + MCYCLES_PER_LINE);

  /* update VDP cycle count */
  mcycles_vdp += MCYCLES_PER_LINE;

  /* latch Vertical Scroll register */
  vscroll = reg[9];
  
  /* reset line count */
  line = 0;

  /* Active Display */
  do
  {
    /* run VDP DMA (Mega Drive VDP specific) */
    if (dma_length)
    {
      vdp_dma_update(mcycles_vdp);
    }

    /* make sure that line has not already been rendered */
    if (v_counter != line)
    {
      /* update VCounter */
      v_counter = line;

      /* render scanline */
      if (!do_skip)
      {
        render_line(line);
      }
    }

    /* update 6-Buttons & Lightguns */
    input_refresh();

    /* H-Int counter */
    if (h_counter == 0)
    {
      /* reload H-Int counter */
      h_counter = reg[10];
      
      /* Horizontal Interrupt is pending */
      hint_pending = 0x10;
      if (reg[0] & 0x10)
      {
        /* Cycle-accurate HINT */
        /* IRQ line is latched between instructions, during instruction last cycle.       */
        /* This means that if Z80 cycle count is exactly a multiple of MCYCLES_PER_LINE,  */
        /* interrupt should be triggered AFTER the next instruction.                      */
        if ((Z80.cycles % MCYCLES_PER_LINE) == 0)
        {
          z80_run(Z80.cycles + 1);
        }

        /* assert Z80 interrupt */
        Z80.irq_state = ASSERT_LINE;
      }
    }
    else
    {
      /* decrement H-Int counter */
      h_counter--;
    }

    /* run Z80 until end of line */
    z80_run(mcycles_vdp + MCYCLES_PER_LINE);

    /* update VDP cycle count */
    mcycles_vdp += MCYCLES_PER_LINE;
  }
  while (++line < bitmap.viewport.h);

  /* check viewport changes */
  if (bitmap.viewport.w != bitmap.viewport.ow)
  {
    bitmap.viewport.ow = bitmap.viewport.w;
    bitmap.viewport.changed |= 1;
  }

  /* adjust timings for next frame */
  input_end_frame(mcycles_vdp);
  Z80.cycles -= mcycles_vdp;
}
