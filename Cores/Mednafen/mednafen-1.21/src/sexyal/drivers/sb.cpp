/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* sb.cpp - Creative Labs Sound Blaster Sound Driver
**  Copyright (C) 2014-2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 DSP versus output capabilities(from Creative's manual):

 4.xx:  16-bit, mono and stereo
	5000 to 44100 Hz

 3.xx:  8-bit, mono and stereo
	mono, 4000 to 23000 Hz
	mono(HS), 23000 to 44100 Hz
	stereo(HS), 11025 and 22050 Hz

 2.01:  8-bit, mono
	mono, 4000 to 23000 Hz
	mono(HS), 23000 to 44100 Hz

 1.xx-2.00: 8-bit, mono
	mono, 4000 to 23000 Hz
*/

#include "dos_common.h"

/*
 Interrupts *MUST* be disabled when calling the dma_*() and irq_*() functions.
*/

static const struct
{
 uint8 addr;
 uint8 count;
 uint8 page;
} dma_ch_ports[8] =
{
 { 0x00, 0x01, 0x87 },	// 0
 { 0x02, 0x03, 0x83 },	// 1
 { 0x04, 0x05, 0x81 },	// 2
 { 0x06, 0x07, 0x82 },	// 3

 { 0xC0, 0xC2, 0x8F },	// 4
 { 0xC4, 0xC6, 0x8B },	// 5
 { 0xC8, 0xCA, 0x89 },	// 6
 { 0xCC, 0xCE, 0x8A }, 	// 7
};

static const struct
{
 uint8 stat_cmd;
 uint8 req;
 uint8 mask_bit;
 uint8 mode;
 uint8 clear_ff;
 uint8 master_disable;
 uint8 clear_mask;
 uint8 write_all_mask;
} dma_con_ports[2] = 
{
 { 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F },
 { 0xD0, 0xD2, 0xD4, 0xD6, 0xD8, 0xDA, 0xDC, 0xDE },
};

static void dma_wr_base_addr(uint8 ch, uint16 value)
{
 outportb(dma_con_ports[ch >> 2].clear_ff, 0);
 outportb(dma_ch_ports[ch].addr, value >> 0);
 outportb(dma_ch_ports[ch].addr, value >> 8);
}

static void dma_wr_count(uint8 ch, uint16 value)
{
 outportb(dma_con_ports[ch >> 2].clear_ff, 0);
 outportb(dma_ch_ports[ch].count, value >> 0);
 outportb(dma_ch_ports[ch].count, value >> 8);
}

static uint16 dma_rd_cur_addr(uint8 ch)
{
 uint16 a;
 uint16 b;

 outportb(dma_con_ports[ch >> 2].clear_ff, 0);

 do
 {
  a = inportb(dma_ch_ports[ch].addr);
  a |= inportb(dma_ch_ports[ch].addr) << 8;
  b = inportb(dma_ch_ports[ch].addr);
  b |= inportb(dma_ch_ports[ch].addr) << 8;
 } while((uint16)(b - a) > 8);  //a != b);

 return(b);
}

static void dma_wr_page(uint8 ch, uint8 value)
{
 outportb(dma_ch_ports[ch].page, value);
}


#define DMA_MODE_TYPE_DEMAND	(0 << 6)
#define DMA_MODE_TYPE_SINGLE	(1 << 6)
#define DMA_MODE_TYPE_BLOCK	(2 << 6)
#define DMA_MODE_TYPE_CASCADE	(3 << 6)

#define DMA_MODE_AIS_INCREMENT	(0 << 5)
#define DMA_MODE_AIS_DECREMENT	(1 << 5)

#define DMA_MODE_AUTOINIT_OFF	(0 << 4)
#define DMA_MODE_AUTOINIT_ON	(1 << 4)

#define DMA_MODE_TT_VERIFY	(0 << 2)
#define DMA_MODE_TT_WRITE	(1 << 2)
#define DMA_MODE_TT_READ	(2 << 2)
#define DMA_MODE_TT_KABOOM	(3 << 2)	

static void dma_ch_set_buffer(uint8 ch, uint32 addr, uint32 size)
{
 const uint8 page = (addr >> 16) & ((ch >= 4) ? 0xFE : 0xFF);	// Mask out the lower bit with 16-bit DMA in case any motherboards use it for A24.

 assert(addr < (1U << 24));

 //printf("DMA Set Buffer: ch=%d phys_addr=0x%08x byte_size=0x%08x\n", ch, addr, size);

 if(ch >= 4)
 {
  assert(!(addr & 1));
  assert(!(size & 1));

  addr >>= 1;
  size >>= 1;

  assert(((addr & 0xFFFF) + size) <= 0x10000);
 }

 dma_wr_base_addr(ch, addr & 0xFFFF);
 dma_wr_page(ch, page);
 dma_wr_count(ch, size - 1);
}

static void dma_ch_set_mode(uint8 ch, uint8 value)
{
 //printf("DMA Set Mode: %d 0x%02x\n", ch, value);

 outportb(dma_con_ports[ch >> 2].mode, (ch & 0x3) | (value &~ 0x3));
}

static void dma_ch_on(uint8 ch)
{
 outportb(dma_con_ports[ch >> 2].mask_bit, (ch & 0x3) | (0 << 2));
}

static void dma_ch_off(uint8 ch)
{
 outportb(dma_con_ports[ch >> 2].mask_bit, (ch & 0x3) | (1 << 2));
}

static bool irq_fonof(uint8 irq, bool on)
{
 const uint8 pnum = ((irq >= 8) ? 0xA1 : 0x21);
 const uint8 old_status = inportb(pnum);
 uint8 tmp = old_status;

 tmp &= ~(1 << (irq & 0x7));
 tmp |= (!on) << (irq & 0x7);

 outportb(pnum, tmp);

 return !((old_status >> (irq & 0x7)) & 1);
}

static void irq_eoi(uint8 irq)	// Specific EOI; don't change it to non-specific!
{
 if(irq >= 8)
 {
  outportb(0xA0, 0x60 + (irq & 0x7));
  outportb(0x20, 0x60 + 2);
 }
 else
 {
  outportb(0x20, 0x60 + (irq & 0x7));
 }
}

struct SB_Driver_t
{
 uint16 dsp_version;	// 0x100, 0x200, 0x201, etc.

 unsigned base;		// I/O base, typically 0x220 or 0x240
 unsigned dma;
 unsigned irq;

 bool hs_mode;

 int save_istate;
 int save_pic_ion;
 uint8 save_mixer[0x40];
 bool save_mixer_valid;

 _go32_dpmi_seginfo dmabuf;
 uint32 dmabuf_eff_paddr;
 uint32 dmabuf_eff_size;

 uint64 read_counter;		// In frames, not bytes.
 uint64 write_counter;	// In frames, not bytes.

 uint16 prev_dmacounter;
 bool paused;
};

static bool dsp_reset(SB_Driver_t* ds)
{
 outportb(ds->base + 0x6, 1);

 for(unsigned i = 0; i < 50 * 10; i++)
  inportb(ds->base + 0xE);

 outportb(ds->base + 0x6, 0);

 for(unsigned i = 0; i < 65536; i++)
  inportb(ds->base + 0xE);

 if(!(inportb(ds->base + 0xE) & 0x80) || (inportb(ds->base + 0xA) != 0xAA))
  return(false);

 return(true);
}

static void dsp_write(SB_Driver_t* ds, uint8 value)
{
 while(inportb(ds->base + 0xC) & 0x80);

 outportb(ds->base + 0xC, value);

 //printf("DSP Write: 0x%02x\n", value);
}

static uint8 dsp_read(SB_Driver_t* ds)
{
 while(!(inportb(ds->base + 0xE) & 0x80));

 return inportb(ds->base + 0xA);
}

static void dsp_command(SB_Driver_t* ds, uint8 cmd)
{
 dsp_write(ds, cmd);
}

static void dsp_command(SB_Driver_t* ds, uint8 cmd, uint8 arg0)
{
 dsp_write(ds, cmd);
 dsp_write(ds, arg0);
}

static void dsp_command(SB_Driver_t* ds, uint8 cmd, uint8 arg0, uint8 arg1)
{
 dsp_write(ds, cmd);
 dsp_write(ds, arg0);
 dsp_write(ds, arg1);
}

static void dsp_command(SB_Driver_t* ds, uint8 cmd, uint8 arg0, uint8 arg1, uint8 arg2)
{
 dsp_write(ds, cmd);
 dsp_write(ds, arg0);
 dsp_write(ds, arg1);
 dsp_write(ds, arg2);
}

static void dsp_command(SB_Driver_t* ds, uint8 cmd, uint8 arg0, uint8 arg1, uint8 arg2, uint8 arg3)
{
 dsp_write(ds, cmd);
 dsp_write(ds, arg0);
 dsp_write(ds, arg1);
 dsp_write(ds, arg2);
 dsp_write(ds, arg3);
}

static void mixer_write(SB_Driver_t* ds, uint8 addr, uint8 value)
{
 outportb(ds->base + 0x4, addr);
 outportb(ds->base + 0x5, value);
}

static uint8 mixer_read(SB_Driver_t* ds, uint8 addr)
{
 outportb(ds->base + 0x4, addr);
 return inportb(ds->base + 0x5);
}

static uint16 GetDMACounter(SexyAL_device* device)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;
 const uint32 lb = (ds->dmabuf_eff_paddr >> ((ds->dma >= 4) ? 1 : 0)) & 0xFFFF;
 const uint32 ls = (ds->dmabuf_eff_size >> ((ds->dma >= 4) ? 1 : 0));
 uint32 tmp;
 int pis;

 // For EMU10K DOS SB emulator, so it doesn't stop playback and cause the sound code to freeze up.
 inportb(ds->base + 0xE);
 inportb(ds->base + 0xF);


 pis = __dpmi_get_and_disable_virtual_interrupt_state();
 tmp = dma_rd_cur_addr(ds->dma);
 __dpmi_get_and_set_virtual_interrupt_state(pis);

#if 0
 printf("TMP: 0x%04x 0x%08x\n", tmp, ds->dmabuf_eff_paddr);
#endif

 if(tmp < lb)
  tmp = lb;

 tmp -= lb;
 tmp %= ls;
 tmp /= device->format.channels * ((ds->dma >= 4) ? 1 : SAMPFORMAT_BYTES(device->format.sampformat));

 return(tmp);
}

static void UpdateReadCounter(SexyAL_device* device)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;
 const unsigned ftob = SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels;
 uint16 cur_dmacounter = GetDMACounter(device);

#if 0
 {
  static uint16 prev = 0;

  if(prev != cur_dmacounter)
  {
   printf("0x%04x\n", cur_dmacounter);
   prev = cur_dmacounter;
  }
 }
#endif

 ds->read_counter -= ds->prev_dmacounter;
 ds->read_counter += cur_dmacounter;

 if(cur_dmacounter < ds->prev_dmacounter)
  ds->read_counter += ds->dmabuf_eff_size / ftob;

 ds->prev_dmacounter = cur_dmacounter;
}


static int Pause(SexyAL_device *device, int state)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;

 // TODO; should we just mask off the DMA channel temporarily?  or will that break things horribly?

 ds->paused = state;

 return(state);
}

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;
 const unsigned ftob = SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels;

 UpdateReadCounter(device);

 // Handle underflow.
 if(ds->write_counter < ds->read_counter)
  ds->write_counter = ds->read_counter;

 *can_write = (device->buffering.buffer_size - (ds->write_counter - ds->read_counter)) * ftob;

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;
 uint32 pl_0, pl_1;
 const uint8* data_d8 = (uint8*)data;
 const unsigned ftob = SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels;

 do
 {
  uint32 cw;
  uint32 i_len;
  uint32 writepos;

  if(!RawCanWrite(device, &cw))	// Caution: RawCanWrite() will modify ds->write_counter on underflow.
   return(0);

  writepos = (ds->write_counter * ftob) % ds->dmabuf_eff_size;
  i_len = std::min<uint32>(cw, len);

  pl_0 = std::min<uint32>(i_len, ds->dmabuf_eff_size - writepos);
  pl_1 = i_len - pl_0;

  if(pl_0)
   _dosmemputb(data_d8, pl_0, ds->dmabuf_eff_paddr + writepos);

  if(pl_1)
   _dosmemputb(data_d8 + pl_0, pl_1, ds->dmabuf_eff_paddr);

  ds->write_counter += i_len / ftob;

  data_d8 += i_len;
  len -= i_len;

  if(ds->paused)
   Pause(device, false);
 } while(len > 0);

 return(1);
}

static int Clear(SexyAL_device *device)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;
 const uint32 base = ds->dmabuf_eff_paddr;
 const uint32 siz = ds->dmabuf_eff_size;

 Pause(device, true);

 _farsetsel(_dos_ds);
 for(unsigned i = 0; i < siz; i += 4)
  _farnspokel(base + i, 0);

 UpdateReadCounter(device);
 ds->write_counter = ds->read_counter;

 return(1);
}

static void Cleanup(SB_Driver_t* ds)
{
 int tmp_istate = -1;

 if(ds->dsp_version > 0)
 {
  if(ds->hs_mode)
   dsp_reset(ds);

  dsp_reset(ds);

  dsp_reset(ds);	// Make sure the last DSP reset command is done(IE we don't want the hardware to trigger any spurious IRQs that will be left pending)

  // Acknowledge any 16-bit SB DSP interrupts(in case a DSP reset didn't ack them).
  inportb(ds->base + 0xF);

  if(ds->save_mixer_valid)
  {
   for(int i = 0x01; i < 0x40; i++)
   {
    // Only necessary if we count down instead of up with i.
    //if((ds->dsp_version >= 0x400) && i == 0x04 || i == 0x0A || i == 0x22 || i == 0x26 || i == 0x28 || i == 0x2E)
    // continue;
    mixer_write(ds, i, ds->save_mixer[i]);
   }
   ds->save_mixer_valid = false;
  }

  ds->dsp_version = 0;
 }

 tmp_istate = __dpmi_get_and_disable_virtual_interrupt_state();

 if(ds->dma != ~0U)
 {
  dma_ch_off(ds->dma);
  ds->dma = ~0U;
 }

 if(ds->irq != ~0U)
 {
  // Clear any pending SB IRQ so we don't cause the next program to use the SB to spaz out. (might not be necessary since we have the IRQ masked away?)
  irq_eoi(ds->irq);

  if(ds->save_pic_ion != -1)
  {
   irq_fonof(ds->irq, ds->save_pic_ion);
   ds->save_pic_ion = -1;
  }

  ds->irq = ~0U;
 }

 if(ds->dmabuf.size != 0)
 {
  _go32_dpmi_free_dos_memory(&ds->dmabuf);
  ds->dmabuf.size = 0;
 }

 __dpmi_get_and_set_virtual_interrupt_state((ds->save_istate != -1) ? ds->save_istate : tmp_istate);
 ds->save_istate = -1;
}

static int RawClose(SexyAL_device *device)
{
 SB_Driver_t *ds = (SB_Driver_t *)device->private_data;

 if(ds)
 {
  Cleanup(ds);
  free(ds);
  device->private_data = NULL;
 }

 return(1);
}


// AKA the "I have no idea what it's doing but at least it's doing something and it's small" hash.
static uint64 DunnoHash(uint64 ht, uint8 v)
{
 ht ^= 104707;
 for(unsigned i = 0; i < 8; i++)
 {
  ht = (((ht * 33) + v) ^ (ht % ((v ^ (ht >> 19)) + 1))) + ((ht >> 1) * (v * 123456789));
  v = (v >> 3) | (v << 5);
 }
 ht ^= 104707;
 return(ht);
}

/*
 Aztech 2320 reaaally didn't like it when we wrote to regs at 0x40-0x7F.

 Fingerprinting is currently only used for DSP version >= 4.13.
*/
static uint64 SaveFPAndResetMixer(SB_Driver_t* ds)
{
 uint64 fip = 0;
 uint8 all_savemixer[0x100];

 //
 // Save mixer params.
 //
 for(unsigned i = 0; i < 0x100; i++)
 {
  uint8 tmp = mixer_read(ds, i);

  if(i < 0x40)
   ds->save_mixer[i] = mixer_read(ds, i);

  all_savemixer[i] = tmp;
  //printf("0x%02x: 0x%02x\n", i, tmp);
 }
 ds->save_mixer_valid = true;

 //
 //
 //
 if(ds->dsp_version < 0x40D)
  goto SkipFP;

 //
 // Reset mixer and hash initial state of registers
 //
 for(unsigned i = 0x01; i < 0x80; i++)
  mixer_write(ds, i, 0);
 mixer_write(ds, 0x00, 0);

 for(unsigned i = 0x01; i < 0x80; i++)
  fip = DunnoHash(fip, mixer_read(ds, i));


 for(unsigned i = 0x01; i < 0x80; i++)
  mixer_write(ds, i, 0xFF);
 mixer_write(ds, 0x00, 0);

 for(unsigned i = 0x01; i < 0x80; i++)
  fip = DunnoHash(fip, mixer_read(ds, i));


 //
 // Clear registers to 0, and hash state of registers.
 //
 for(unsigned i = 0x01; i < 0x80; i++)
  mixer_write(ds, i, 0);

 for(unsigned i = 0x01; i < 0x80; i++)
  fip = DunnoHash(fip, mixer_read(ds, i));

 //
 // Go through setting each bit of each byte individually(0x40 * 8 iterations)
 // (note: should occur after the clear-to-0 step.
 //
 for(unsigned bigi = 0; bigi < 0x80 * 8; bigi++)
 {
  if((bigi >> 3) == 0)
   continue;

  mixer_write(ds, bigi >> 3, 1 << (bigi & 0x7));

  for(unsigned i = 0x01; i < 0x80; i++)
   fip = DunnoHash(fip, mixer_read(ds, i));

  mixer_write(ds, bigi >> 3, 0);
 }

 //
 // Set registers to 0xFF, and hash state of registers.
 //
 for(unsigned i = 0x01; i < 0x80; i++)
  mixer_write(ds, i, 0xFF);

 for(unsigned i = 0x01; i < 0x80; i++)
  fip = DunnoHash(fip, mixer_read(ds, i));


#if 0
 //
 // Go through clearing each bit of each byte individually(0x80 * 8 iterations)
 // (note: should occur after the set-to-0xFF step.
 //
 for(unsigned bigi = 0; bigi < 0x80 * 8; bigi++)
 {
  if((bigi >> 3) == 0)
   continue;

  mixer_write(ds, bigi >> 3, 0xFF ^ (1 << (bigi & 0x7)));

  for(unsigned i = 0x01; i < 0x80; i++)
   fip = DunnoHash(fip, mixer_read(ds, i));

  mixer_write(ds, bigi >> 3, 0xFF);
 }
#endif

 //
 // Reset
 //
 for(unsigned i = 0x01; i < 0x100; i++)
  mixer_write(ds, i, all_savemixer[i]);

 SkipFP: ;

 mixer_write(ds, 0x00, 0);

 return(fip);
}

bool SexyALI_DOS_SB_Avail(void)
{
 if(getenv("BLASTER") != NULL)
  return(true);

 return(false);
}

#define SB_INIT_CLEANUP		\
	if(device) free(device);	\
	if(ds) { Cleanup(ds); free(ds); }

SexyAL_device *SexyALI_DOS_SB_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device = NULL;
 SB_Driver_t *ds = NULL;

 if(!(device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device))))
 {
  SB_INIT_CLEANUP
  return(NULL);
 }

 if(!(ds = (SB_Driver_t *)calloc(1, sizeof(SB_Driver_t))))
 {
  SB_INIT_CLEANUP
  return(NULL);
 }

 ds->base = ~0U;
 ds->dma = ~0U;
 ds->irq = ~0U;
 ds->save_istate = -1;
 ds->save_pic_ion = -1;
 ds->save_mixer_valid = false;

 device->private_data = ds;

 //
 // Read BLASTER environment variable.
 //
 {
  const char* eblast = getenv("BLASTER");
  unsigned eblast_len;
  unsigned lbp = 0;
  unsigned eb_base = 0;
  unsigned eb_dma8 = 0;
  unsigned eb_irq = 0;
  
  bool found_base = false;
  bool found_dma8 = false;
  bool found_irq = false;

  if(!eblast)
  {
   fprintf(stderr, "SB: \"BLASTER\" environment variable not found!\n");
   SB_INIT_CLEANUP
   return(NULL);
  }

  eblast_len = strlen(eblast);
  for(unsigned i = 0; i < eblast_len + 1; i++)
  {
   char c = eblast[i];

   if(c <= 0x20)
   {
    if(lbp < i)
    {
     char t = eblast[lbp];

     switch(t)
     {
      case 'A':
	if(sscanf(&eblast[lbp + 1], "%x", &eb_base) != 1)
	{
	 fprintf(stderr, "SB: Malformed base address specifier in \"BLASTER\" environment variable!\n");
	 SB_INIT_CLEANUP
	 return(NULL);
	}
	found_base = true;
	break;

      case 'I':
	if(sscanf(&eblast[lbp + 1], "%u", &eb_irq) != 1)
	{
	 fprintf(stderr, "SB: Malformed IRQ specifier in \"BLASTER\" environment variable!\n");
	 SB_INIT_CLEANUP
	 return(NULL);
	}
	found_irq = true;
	break;

      case 'D':
	if(sscanf(&eblast[lbp + 1], "%u", &eb_dma8) != 1)
	{
	 fprintf(stderr, "SB: Malformed 8-bit DMA specifier in \"BLASTER\" environment variable!\n");
	 SB_INIT_CLEANUP
	 return(NULL);
	}
	found_dma8 = true;
	break;
     }
    }
    lbp = i + 1;
   }
  }

  if(found_base)
  {
   if((eb_base &~ 0xF0) != 0x200)
   {
    fprintf(stderr, "SB: Bad base address specified by \"BLASTER\" environment variable: 0x%04X\n", eb_base);
    SB_INIT_CLEANUP
    return(NULL);
   }
   ds->base = eb_base;
  }
  else
  {
   fprintf(stderr, "SB: Missing base address specifier in \"BLASTER\" environment variable!\n");
   SB_INIT_CLEANUP
   return(NULL);
  }

  if(found_irq)
  {
   if(eb_irq < 3 || eb_irq > 15)
   {
    fprintf(stderr, "SB: Bad IRQ: %u\n", eb_irq);
    SB_INIT_CLEANUP
    return(NULL);
   }
   ds->irq = eb_irq;
  }
  else
  {
   fprintf(stderr, "SB: Missing IRQ specifier in \"BLASTER\" environment variable!\n");
   SB_INIT_CLEANUP
   return(NULL);
  }

  if(found_dma8)
  {
   if(eb_dma8 > 4 || eb_dma8 == 2)
   {
    fprintf(stderr, "SB: Bad 8-bit DMA channel: %u\n", eb_dma8);
    SB_INIT_CLEANUP
    return(NULL);
   }
   ds->dma = eb_dma8;
  }
  else
  {
   fprintf(stderr, "SB: Missing 8-bit DMA specifier in \"BLASTER\" environment variable!\n");
   SB_INIT_CLEANUP
   return(NULL);
  }
 }
 //
 // End BLASTER parsing.
 //

 if(!dsp_reset(ds))
 {
  fprintf(stderr, "SB: Error resetting DSP(SB not found, or misconfigured).\n");
  SB_INIT_CLEANUP
  return(NULL);
 }

 //
 // Get DSP version.
 //
 dsp_command(ds, 0xE1);
 ds->dsp_version = dsp_read(ds) << 8;
 ds->dsp_version |= dsp_read(ds) << 0;

 if(ds->dsp_version < 0x200)
 {
  fprintf(stderr, "SB: DSP versions earlier than 2.00 are not supported.\n");
  SB_INIT_CLEANUP
  return(NULL);
 }

 //
 // Make sure SB IRQ is masked off in the IRQ controller.
 //
 ds->save_istate = __dpmi_get_and_disable_virtual_interrupt_state();
 ds->save_pic_ion = irq_fonof(ds->irq, false);
 __dpmi_get_and_set_virtual_interrupt_state(ds->save_istate);
 ds->save_istate = -1;

 //
 // Save and fingerprint and reset mixer state
 //
 printf("\n");
 uint64 mixer_fp = SaveFPAndResetMixer(ds);
 dsp_reset(ds);	// Work around fingerprinting-triggered bug in Sound Blaster PCI SB emulation code.


 //
 //
 //
 if(ds->dsp_version >= 0x400)
 {
  uint8 conf_dmabf = mixer_read(ds, 0x81);

  if(conf_dmabf & (1 << 0))
   ds->dma = 0;
  else if(conf_dmabf & (1 << 1))
   ds->dma = 1;
  else if(conf_dmabf & (1 << 3))
   ds->dma = 3;

  if(SAMPFORMAT_BYTES(format->sampformat) >= 2)
  {
   if(conf_dmabf & (1 << 5))
    ds->dma = 5;
   else if(conf_dmabf & (1 << 6))
    ds->dma = 6;
   else if(conf_dmabf & (1 << 7))
    ds->dma = 7;
  }
 }

 {
#if 0
  static struct
  {
   uint16 dsp_version;
   uint64 mixer_fp;
   const char *name;
  } card_table[] =
  {
	{ 0x40D, 0xffc8998833d57773ULL, "Creative Sound Blaster PCI Legacy Driver" },
//   { 0x302, 0xULL, "Creative Labs Sound Blaster Pro 2" },

	{ 0x301, 0x7cbc1f28b011ef2bULL, "Aztech 2320" },

//   { 0x301, 0xULL, "Yamaha YMF715" },

   { 0, 0, NULL },
  };
#endif
  printf("Sound Blaster Information:\n");
#if 0
  for(unsigned i = 0; card_table[i].name; i++)
  {
   if(card_table[i].dsp_version == ds->dsp_version && card_table[i].mixer_fp == mixer_fp)
   {
    printf(" Implementation(guessed): %s\n", card_table[i].name);
    break;
   }
  }
#endif
  printf(" DSP version: %d.%d\n", (ds->dsp_version >> 8), (ds->dsp_version & 0xFF));
  printf(" IRQ: %u\n", ds->irq);
  printf(" DMA: %u\n", ds->dma);
  if(mixer_fp != 0)
   printf(" Mixer fingerprint: 0x%016llx\n", mixer_fp);
 }

 //
 //
 //
 format->noninterleaved = false;

 if(!buffering->ms) 
  buffering->ms = 24;

 buffering->period_size = 0;
 buffering->bt_gran = 1;

 if(ds->dsp_version < 0x300)
  format->channels = 1;
 else if(format->channels > 2)
  format->channels = 2;

 if(SAMPFORMAT_BYTES(format->sampformat) >= 2)
 {
  if(ds->dsp_version < 0x400)
  {
   format->sampformat = SEXYAL_FMT_PCMU8;
  }
  else if(SAMPFORMAT_BYTES(format->sampformat) > 2)
  {
   format->sampformat = SEXYAL_FMT_PCMS16;
  }
 }
 else if(ds->dsp_version < 0x400)
 {
  format->sampformat = SEXYAL_FMT_PCMU8;
 }

 if(ds->dsp_version < 0x201)
 {
  format->channels = 1;
 }

 //
 // Program rate.
 //
 if(ds->dsp_version < 0x400)
 {
  signed tc;

  tc = 256 - ((1000000 + (format->channels * format->rate / 2)) / (format->channels * format->rate));

  if(ds->dsp_version < 0x201)
  {
   if(tc > 211)
    tc = 211;
  }
  else
  {
   if(tc > 234)
    tc = 234;

   if(format->channels == 2 && tc < 211)
    tc = 211;
  }

  if(tc < 56)
   tc = 56;

  //if(getenv("SBTC"))
  // tc = atoi(getenv("SBTC"));

  format->rate = (1000000 + (256 - tc) * format->channels / 2) / ((256 - tc) * format->channels);
  ds->hs_mode = ((tc > 211) || format->channels == 2);

  // command 0x40
  dsp_command(ds, 0x40, tc);
 }
 else
 {
  if(mixer_fp == 0x79912aba874f4ad3ULL)	// Fingerprint from EMU10K SB emulator(hopefully real SB16 hardware doesn't have the same fingerprint >_>)
  {
   if(format->rate < 5000)
    format->rate = 5000;

   if(format->rate > 65535)
    format->rate = 64000;
  }
  else
  {
   // Sound output sampling rate, hardcoded to 44100 since I'm not sure about the sample rate accuracy, especially on clone cards...but are there SB16 clone
   // cards?
   format->rate = 44100;
  }
  ds->hs_mode = false;

  dsp_command(ds, 0x41, format->rate >> 8, format->rate >> 0);
 }

 buffering->buffer_size = buffering->ms * format->rate / 1000;

 //
 // 65536 bytes maximum size for 8-bit DMA, / 2 since we need DMA buffer size *2 buffer size for reliable wraparound detection.
 //
 // Don't bother having a higher limit for 16-bit DMA, since it'd use too much conventional memory to be useful when taking into consideration
 // allocation alignment overhead needed to prevent the buffer from straddling a 64K/128K boundary.
 if((buffering->buffer_size * SAMPFORMAT_BYTES(format->sampformat) * format->channels) > 32768)
  buffering->buffer_size = 32768 / (format->channels * SAMPFORMAT_BYTES(format->sampformat));

 buffering->latency = buffering->buffer_size;	// TODO: SB FIFO length.

 memset(&ds->dmabuf, 0, sizeof(ds->dmabuf));
 ds->dmabuf.size = (((buffering->buffer_size * 2 * 2) * SAMPFORMAT_BYTES(format->sampformat) * format->channels) + 15) / 16;
 if(_go32_dpmi_allocate_dos_memory(&ds->dmabuf) != 0)
 {
  fprintf(stderr, "SB: error allocating DMA memory.");
  SB_INIT_CLEANUP
  return(NULL);
 }

 {
  uint32 tmp_mask;

  if(ds->dma >= 4)
   tmp_mask = ~(131072 - 1);
  else
   tmp_mask = ~(65536 - 1);

  ds->dmabuf_eff_paddr = ds->dmabuf.rm_segment << 4;
  ds->dmabuf_eff_size = (ds->dmabuf.size << 4) / 2;

  if((ds->dmabuf_eff_paddr & tmp_mask) != ((ds->dmabuf_eff_paddr + ds->dmabuf_eff_size - 1) & tmp_mask))
   ds->dmabuf_eff_paddr = (ds->dmabuf_eff_paddr + (~tmp_mask)) & tmp_mask;
 }

 //
 // Clear DMA buffer memory.
 //
 {
  const uint32 base = ds->dmabuf_eff_paddr;
  const uint32 siz = ds->dmabuf_eff_size;
  uint32 wv = 0;

  if(format->sampformat == SEXYAL_FMT_PCMU8)
   wv = 0x80808080U;
  else if(format->sampformat == SEXYAL_FMT_PCMU16)
   wv = 0x80008000U;

  _farsetsel(_dos_ds);
  for(unsigned i = 0; i < siz; i += 4)
   _farnspokel(base + i, wv);
 }

 //
 // Program mixer parameters.
 //

 if(ds->dsp_version < 0x300)	// SB
 {
  mixer_write(ds, 0x02, 7 << 1);	// Master volume, 0dB
  mixer_write(ds, 0x06, 0);		// MIDI volume, -46dB
  mixer_write(ds, 0x08, 0);		// CD volume, -46dB
  mixer_write(ds, 0x0A, 3 << 1);	// Voice volume, 0dB
 }
 else if(ds->dsp_version < 0x400)	// SB Pro
 {
  //
  // 0xFF for volume in some spots for the benefit of some clone cards.
  //
  mixer_write(ds, 0x04, 0xFF); //(0x7 << 5) | (0x7 << 1));	// Voice L and R, 0dB
  mixer_write(ds, 0x0A, 0);	// Mic, -46dB
  mixer_write(ds, 0x0C, 0x8);	// Input settings.

  mixer_write(ds, 0x0E, ((format->channels == 2) ? 0x2 : 0) | ((format->rate >= 20000 || format->channels == 2) ? 0x20 : 0x00));	// Output switches.

  mixer_write(ds, 0x22, 0xFF); //(0x7 << 5) | (0x7 << 1));	// Master L and R, 0dB
  mixer_write(ds, 0x26, 0);	// MIDI L and R, -46dB
  mixer_write(ds, 0x28, 0);	// CD L and R, -46dB
  mixer_write(ds, 0x2E, 0);	// Line L and R, -46dB
 }
 else	// SB 16
 {
  // Master volume, 0dB
  mixer_write(ds, 0x30, 0xFF);
  mixer_write(ds, 0x31, 0xFF);

  // Voice volume, 0dB
  mixer_write(ds, 0x32, 0xFF);
  mixer_write(ds, 0x33, 0xFF);

  // MIDI, -62dB
  mixer_write(ds, 0x34, 0);
  mixer_write(ds, 0x35, 0);
 }

 //
 // Speaker On
 //
 dsp_command(ds, 0xD1);


 //
 // Start DMA
 //
 ds->save_istate = __dpmi_get_and_disable_virtual_interrupt_state();
 dma_ch_off(ds->dma);
 dma_ch_set_mode(ds->dma, DMA_MODE_TYPE_SINGLE | DMA_MODE_AIS_INCREMENT | DMA_MODE_AUTOINIT_ON | DMA_MODE_TT_READ);
 dma_ch_set_buffer(ds->dma, ds->dmabuf_eff_paddr, ds->dmabuf_eff_size);
 dma_ch_on(ds->dma);
 __dpmi_get_and_set_virtual_interrupt_state(ds->save_istate);
 ds->save_istate = -1;

 if(ds->dsp_version < 0x400)
 {
  /*
   Since we're not making use of IRQs, specify the block size as "1"(wbs = 1 - 1 = 0) to prevent period clicking and popping noises
   with some waveforms(on an SB Pro 2 at least) due to what's likely hardware design flaws.
   (In mono mode for example, broadband distortion was noted about every 256 samples AND about every 'wbs' samples)
  */
  /*
   SCRATCH THAT.  Doing that messes with the sample playback rate(about 2/3 of what it should be), and the DSP isn't accepting larger time constants
   than 234(would be needed to compensate).

   Playback rate with various raw block sizes:
	0 = 2/3
	1 = 4/5
	2 = 0.8577 with SEVERE distortion.
	3 = 0.8894 
      255 = 0.9986 with some distortion
  */
  /*
   TODO?  (still need to test stuff with raw block sizes >= 256)
    (NOTE: Pseudocode below requires fractional/floating point precision)
    actual_rate = 1000000 / (256 - raw_time_constant + 11 / (raw_block_size + 1))
  */
  uint16 wbs = 0xFFFF; //0;

  dsp_command(ds, 0x48, wbs >> 0, wbs >> 8);

  if(ds->hs_mode)
   dsp_command(ds, 0x90);
  else
   dsp_command(ds, 0x1C);
 }
 else
 {
  uint8 digi_cmd;
  uint8 digi_mode;
  uint16 wlen = 0xFFFF;

  digi_cmd = 0xB0 | (0 << 3) | (1 << 2) | (1 << 1);

  if(SAMPFORMAT_BYTES(format->sampformat) == 1)
   digi_cmd += 0x10;

  digi_mode = ((format->sampformat == SEXYAL_FMT_PCMS8 || format->sampformat == SEXYAL_FMT_PCMS16) ? 0x10 : 0x00) | ((format->channels == 2) ? 0x20 : 0x00);

  dsp_command(ds, digi_cmd, digi_mode, wlen >> 0, wlen >> 8);
 }

#if 0
 printf("Timing transfer rate....\n");
 {
  uint64 tick_counter = 0;
  uint8 ct;
  int prev_ct = -1;

  ds->save_istate = __dpmi_get_and_disable_virtual_interrupt_state();

  for(;;)
  {
   ct = inportb(0x40);
   if(prev_ct != -1)
   {
    if(
   }
   prev_ct = ct;

   UpdateReadCounter(ds);
  }
  __dpmi_get_and_set_virtual_interrupt_state(ds->save_istate);
  ds->save_istate = -1;
 }
#endif
 printf("SB INIT DONE!\n");

 ds->prev_dmacounter = 0;
 ds->read_counter = 0;
 ds->write_counter = 0;

 memcpy(&device->format, format, sizeof(SexyAL_format));
 memcpy(&device->buffering, buffering, sizeof(SexyAL_buffering));

 device->RawCanWrite = RawCanWrite;
 device->RawWrite = RawWrite;
 device->RawClose = RawClose;
 device->Clear = Clear;
 device->Pause = Pause;

 return(device);
}

