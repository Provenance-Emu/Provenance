/***************************************************************************************
 *  Genesis Plus
 *  Sound Hardware
 *
 *  Copyright (C) 1998-2003  Charles Mac Donald (original code)
 *  Copyright (C) 2007-2020  Eke-Eke (Genesis Plus GX)
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
#include "blip_buf.h"

/* YM2612 internal clock = input clock / 6 = (master clock / 7) / 6 */
#define YM2612_CLOCK_RATIO (7*6)

/* FM output buffer (large enough to hold a whole frame at original chips rate) */
#if defined(HAVE_YM3438_CORE) || defined(HAVE_OPLL_CORE)
static int fm_buffer[1080 * 2 * 24];
#else
static int fm_buffer[1080 * 2];
#endif

static int fm_last[2];
static int *fm_ptr;

/* Cycle-accurate FM samples */
static int fm_cycles_ratio;
static int fm_cycles_start;
static int fm_cycles_count;
static int fm_cycles_busy;

/* YM chip function pointers */
static void (*YM_Update)(int *buffer, int length);
void (*fm_reset)(unsigned int cycles);
void (*fm_write)(unsigned int cycles, unsigned int address, unsigned int data);
unsigned int (*fm_read)(unsigned int cycles, unsigned int address);

#ifdef HAVE_YM3438_CORE
static ym3438_t ym3438;
static short ym3438_accm[24][2];
static int ym3438_sample[2];
static int ym3438_cycles;
#endif

#ifdef HAVE_OPLL_CORE
static opll_t opll;
static int opll_accm[18][2];
static int opll_sample;
static int opll_cycles;
static int opll_status;
#endif

/* Run FM chip until required M-cycles */
INLINE void fm_update(int cycles)
{
  if (cycles > fm_cycles_count)
  {
    /* number of samples to run */
    int samples = (cycles - fm_cycles_count + fm_cycles_ratio - 1) / fm_cycles_ratio;

    /* run FM chip to sample buffer */
    YM_Update(fm_ptr, samples);

    /* update FM buffer pointer */
    fm_ptr += (samples * 2);

    /* update FM cycle counter */
    fm_cycles_count += (samples * fm_cycles_ratio);
  }
}

static void YM2612_Reset(unsigned int cycles)
{
  /* synchronize FM chip with CPU */
  fm_update(cycles);

  /* reset FM chip */
  YM2612ResetChip();
  fm_cycles_busy = 0;
}

static void YM2612_Write(unsigned int cycles, unsigned int a, unsigned int v)
{
  /* detect DATA port write */
  if (a & 1)
  {
    /* synchronize FM chip with CPU */
    fm_update(cycles);

    /* set FM BUSY end cycle (discrete or ASIC-integrated YM2612 chip only) */
    if (config.ym2612 < YM2612_ENHANCED)
    {
      fm_cycles_busy = (((cycles + YM2612_CLOCK_RATIO - 1) / YM2612_CLOCK_RATIO) + 32) * YM2612_CLOCK_RATIO;
    }
  }

  /* write FM register */
  YM2612Write(a, v);
}

static unsigned int YM2612_Read(unsigned int cycles, unsigned int a)
{
  /* FM status can only be read from (A0,A1)=(0,0) on discrete YM2612 */
  if ((a == 0) || (config.ym2612 > YM2612_DISCRETE))
  {
    /* synchronize FM chip with CPU */
    fm_update(cycles);

    /* read FM status */
    if (cycles >= fm_cycles_busy)
    {
      /* BUSY flag cleared */
      return YM2612Read();
    }
    else
    {
      /* BUSY flag set */
      return YM2612Read() | 0x80;
    }
  }

  /* invalid FM status address */
  return 0x00;
}

static void YM2413_Reset(unsigned int cycles)
{
  /* synchronize FM chip with CPU */
  fm_update(cycles);

  /* reset FM chip */
  YM2413ResetChip();
}

static void YM2413_Write(unsigned int cycles, unsigned int a, unsigned int v)
{
  /* detect DATA port write */
  if (a & 1)
  {
    /* synchronize FM chip with CPU */
    fm_update(cycles);
  }

  /* write FM register */
  YM2413Write(a, v);
}

static unsigned int YM2413_Read(unsigned int cycles, unsigned int a)
{
    return YM2413Read();
}

#ifdef HAVE_YM3438_CORE
static void YM3438_Update(int *buffer, int length)
{
  int i, j;
  for (i = 0; i < length; i++)
  {
    OPN2_Clock(&ym3438, ym3438_accm[ym3438_cycles]);
    ym3438_cycles = (ym3438_cycles + 1) % 24;
    if (ym3438_cycles == 0)
    {
      ym3438_sample[0] = 0;
      ym3438_sample[1] = 0;
      for (j = 0; j < 24; j++)
      {
        ym3438_sample[0] += ym3438_accm[j][0];
        ym3438_sample[1] += ym3438_accm[j][1];
      }
    }
    *buffer++ = ym3438_sample[0] * 11;
    *buffer++ = ym3438_sample[1] * 11;
  }
}

static void YM3438_Reset(unsigned int cycles)
{
  /* synchronize FM chip with CPU */
  fm_update(cycles);

  /* reset FM chip */
  OPN2_Reset(&ym3438);
}

static void YM3438_Write(unsigned int cycles, unsigned int a, unsigned int v)
{
  /* synchronize FM chip with CPU */
  fm_update(cycles);

  /* write FM register */
  OPN2_Write(&ym3438, a, v);
}

static unsigned int YM3438_Read(unsigned int cycles, unsigned int a)
{
  /* synchronize FM chip with CPU */
  fm_update(cycles);

  /* read FM status */
  return OPN2_Read(&ym3438, a);
}
#endif

#ifdef HAVE_OPLL_CORE
static void OPLL2413_Update(int* buffer, int length)
{
  int i, j;
  for (i = 0; i < length; i++)
  {
    OPLL_Clock(&opll, opll_accm[opll_cycles]);
    opll_cycles = (opll_cycles + 1) % 18;
    if (opll_cycles == 0)
    {
      opll_sample = 0;
      for (j = 0; j < 18; j++)
      {
        opll_sample += opll_accm[j][0] + opll_accm[j][1];
      }
    }
    *buffer++ = opll_sample * 16 * opll_status;
    *buffer++ = opll_sample * 16 * opll_status;
  }
}

static void OPLL2413_Reset(unsigned int cycles)
{
  /* synchronize FM chip with CPU */
  fm_update(cycles);

  /* reset FM chip */
  OPLL_Reset(&opll, opll_type_ym2413);
}

static void OPLL2413_Write(unsigned int cycles, unsigned int a, unsigned int v)
{
  if (!(a&2))
  {
    /* synchronize FM chip with CPU */
    fm_update(cycles);

    /* write FM register */
    OPLL_Write(&opll, a, v);
  }
  else
  {
    opll_status = v&1;
  }
}

static unsigned int OPLL2413_Read(unsigned int cycles, unsigned int a)
{
    return 0xf8 | opll_status;
}

#endif

void sound_init( void )
{
  /* Initialize FM chip */
  if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
  {
    /* YM2612 */
#ifdef HAVE_YM3438_CORE
    if (config.ym3438)
    {
      /* Nuked OPN2 */
      memset(&ym3438, 0, sizeof(ym3438));
      memset(&ym3438_sample, 0, sizeof(ym3438_sample));
      memset(&ym3438_accm, 0, sizeof(ym3438_accm));
      YM_Update = YM3438_Update;
      fm_reset = YM3438_Reset;
      fm_write = YM3438_Write;
      fm_read = YM3438_Read;

      /* chip is running at internal clock */
      fm_cycles_ratio = YM2612_CLOCK_RATIO;
    }
    else
#endif
    {
      /* MAME OPN2*/
      YM2612Init();
      YM2612Config(config.ym2612);
      YM_Update = YM2612Update;
      fm_reset = YM2612_Reset;
      fm_write = YM2612_Write;
      fm_read = YM2612_Read;

      /* chip is running at sample clock */
      fm_cycles_ratio = YM2612_CLOCK_RATIO * 24;
    }
  }
  else
  {
    /* YM2413 */
#ifdef HAVE_OPLL_CORE
    if (config.opll)
    {
      /* Nuked OPLL */
      memset(&opll, 0, sizeof(opll));
      memset(&opll_accm, 0, sizeof(opll_accm));
      opll_sample = 0;
      opll_status = 0;
      YM_Update = (config.ym2413 & 1) ? OPLL2413_Update : NULL;
      fm_reset = OPLL2413_Reset;
      fm_write = OPLL2413_Write;
      fm_read = OPLL2413_Read;

      /* chip is running at internal clock */
      fm_cycles_ratio = 4 * 15;
    }
    else
#endif
    {
      YM2413Init();
      YM_Update = (config.ym2413 & 1) ? YM2413Update : NULL;
      fm_reset = YM2413_Reset;
      fm_write = YM2413_Write;
      fm_read = YM2413_Read;

      /* chip is running at ZCLK / 72 = MCLK / 15 / 72 */
      fm_cycles_ratio = 72 * 15;
    }
  }

  /* Initialize PSG chip */
  psg_init((system_hw == SYSTEM_SG) ? PSG_DISCRETE : PSG_INTEGRATED);
}

void sound_reset(void)
{
  /* reset sound chips */
  fm_reset(0);
  psg_reset();
  psg_config(0, config.psg_preamp, 0xff);

  /* reset FM buffer ouput */
  fm_last[0] = fm_last[1] = 0;

  /* reset FM buffer pointer */
  fm_ptr = fm_buffer;
  
  /* reset FM cycle counters */
  fm_cycles_start = fm_cycles_count = 0;
}

int sound_update(unsigned int cycles)
{
  /* Run PSG chip until end of frame */
  psg_end_frame(cycles);

  /* FM chip is enabled ? */
  if (YM_Update)
  {
    int prev_l, prev_r, preamp, time, l, r, *ptr;

    /* Run FM chip until end of frame */
    fm_update(cycles);

    /* FM output pre-amplification */
    preamp = config.fm_preamp;

    /* FM frame initial timestamp */
    time = fm_cycles_start;

    /* Restore last FM outputs from previous frame */
    prev_l = fm_last[0];
    prev_r = fm_last[1];

    /* FM buffer start pointer */
    ptr = fm_buffer;

    /* flush FM samples */
    if (config.hq_fm)
    {
      /* high-quality Band-Limited synthesis */
      do
      {
        /* left & right channels */
        l = ((*ptr++ * preamp) / 100);
        r = ((*ptr++ * preamp) / 100);
        blip_add_delta(snd.blips[0], time, l-prev_l, r-prev_r);
        prev_l = l;
        prev_r = r;

        /* increment time counter */
        time += fm_cycles_ratio;
      }
      while (time < cycles);
    }
    else
    {
      /* faster Linear Interpolation */
      do
      {
        /* left & right channels */
        l = ((*ptr++ * preamp) / 100);
        r = ((*ptr++ * preamp) / 100);
        blip_add_delta_fast(snd.blips[0], time, l-prev_l, r-prev_r);
        prev_l = l;
        prev_r = r;

        /* increment time counter */
        time += fm_cycles_ratio;
      }
      while (time < cycles);
    }

    /* reset FM buffer pointer */
    fm_ptr = fm_buffer;

    /* save last FM output for next frame */
    fm_last[0] = prev_l;
    fm_last[1] = prev_r;

    /* adjust FM cycle counters for next frame */
    fm_cycles_count = fm_cycles_start = time - cycles;
    if (fm_cycles_busy > cycles)
    {
      fm_cycles_busy -= cycles;
    }
    else
    {
      fm_cycles_busy = 0;
    }
  }

  /* end of blip buffer time frame */
  blip_end_frame(snd.blips[0], cycles);

  /* return number of available samples */
  return blip_samples_avail(snd.blips[0]);
}

int sound_context_save(uint8 *state)
{
  int bufferptr = 0;
  
  if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
  {
#ifdef HAVE_YM3438_CORE
    save_param(&config.ym3438, sizeof(config.ym3438));
    if (config.ym3438)
    {
      save_param(&ym3438, sizeof(ym3438));
      save_param(&ym3438_accm, sizeof(ym3438_accm));
      save_param(&ym3438_sample, sizeof(ym3438_sample));
      save_param(&ym3438_cycles, sizeof(ym3438_cycles));
    }
    else
    {
      bufferptr += YM2612SaveContext(state + sizeof(config.ym3438));
    }
#else
    bufferptr = YM2612SaveContext(state);
#endif
  }
  else
  {
#ifdef HAVE_OPLL_CORE
    save_param(&config.opll, sizeof(config.opll));
    if (config.opll)
    {
      save_param(&opll, sizeof(opll));
      save_param(&opll_accm, sizeof(opll_accm));
      save_param(&opll_sample, sizeof(opll_sample));
      save_param(&opll_cycles, sizeof(opll_cycles));
      save_param(&opll_status, sizeof(opll_status));
    }
    else
#endif
    {
      save_param(YM2413GetContextPtr(),YM2413GetContextSize());
    }
  }

  bufferptr += psg_context_save(&state[bufferptr]);

  save_param(&fm_cycles_start,sizeof(fm_cycles_start));

  return bufferptr;
}

int sound_context_load(uint8 *state)
{
  int bufferptr = 0;

  if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
  {
#ifdef HAVE_YM3438_CORE
    uint8 config_ym3438;
    load_param(&config_ym3438, sizeof(config_ym3438));
    if (config_ym3438)
    {
      load_param(&ym3438, sizeof(ym3438));
      load_param(&ym3438_accm, sizeof(ym3438_accm));
      load_param(&ym3438_sample, sizeof(ym3438_sample));
      load_param(&ym3438_cycles, sizeof(ym3438_cycles));
    }
    else
    {
      bufferptr += YM2612LoadContext(state + sizeof(config_ym3438));
    }
#else
    bufferptr = YM2612LoadContext(state);
#endif
  }
  else
  {
#ifdef HAVE_OPLL_CORE
    uint8 config_opll;
    load_param(&config_opll, sizeof(config_opll));
    if (config_opll)
    {
      load_param(&opll, sizeof(opll));
      load_param(&opll_accm, sizeof(opll_accm));
      load_param(&opll_sample, sizeof(opll_sample));
      load_param(&opll_cycles, sizeof(opll_cycles));
      load_param(&opll_status, sizeof(opll_status));
    }
    else
#endif
    {
      load_param(YM2413GetContextPtr(),YM2413GetContextSize());
    }
  }

  bufferptr += psg_context_load(&state[bufferptr]);

  load_param(&fm_cycles_start,sizeof(fm_cycles_start));
  fm_cycles_count = fm_cycles_start;

  return bufferptr;
}
