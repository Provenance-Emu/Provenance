/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 Notes:
	hard-coded 16-bit stereo support to minimize buffer position timing granularity, and to simplify stuff

	tried to use the sample count register for better granularity, but I couldn't get it to stop counting(important during init!), and it was just being a
	headache overall

 	noticed a bug in stereo mode that might have been related to making use of P2_PAUSE in an earlier revision of the code...or maybe the sample
	count register not behaving how I thought it did was to blame for writing to the wrong position in the DMA buffer and making sound sound horrible.
*/

#include "dos_common.h"
#include <algorithm>

static const int ES_DMAFIFO_BYTESIZE = 64;
static const int ES_DMAFIFO_FETCHBYTESIZE = 32;

typedef struct
{
 uint16_t bdf;
 uint32_t base_addr;

 _go32_dpmi_seginfo dmabuf;
 _go32_dpmi_seginfo garbagebuf;	// Used in preventing errant writes(reported es1370 bug).

 uint64_t read_counter;		// In frames, not bytes.
 uint64_t write_counter;	// In frames, not bytes.

 uint16_t prev_dmacounter;
 bool paused;
} ES1370_Driver_t;

static void wrdm32(ES1370_Driver_t* ds, uint32_t offset, uint32_t value)
{
 outportl(ds->base_addr + offset, value);
 //printf("wrdm32() %02x:%08x ;;; %08x\n", offset, value, inportl(ds->base_addr + offset));
}

static uint32_t rddm32(ES1370_Driver_t* ds, uint32_t offset)
{
 return inportl(ds->base_addr + offset);
}

static void wrdm16(ES1370_Driver_t* ds, uint32_t offset, uint16_t value)
{
 outportw(ds->base_addr + offset, value);
 //printf("wrdm16() %02x:%04x ;;; %04x\n", offset, value, inportw(ds->base_addr + offset));
}

static uint16_t rddm16(ES1370_Driver_t* ds, uint32_t offset)
{
 return inportw(ds->base_addr + offset);
}

static void wresmem32(ES1370_Driver_t* ds, uint32_t offset, uint32_t value)
{
 wrdm32(ds, 0x0C, offset >> 4);
 wrdm32(ds, 0x30 + (offset & 0xF), value);
}

static uint32_t rdesmem32(ES1370_Driver_t* ds, uint32_t offset)
{
 wrdm32(ds, 0x0C, offset >> 4);
 return rddm32(ds, 0x30 + (offset & 0xF));
}


static void wrcodec(ES1370_Driver_t* ds, uint8 addr, uint8 value, bool dobusywait = true)
{
 while(rddm32(ds, 0x04) & (1U << 8));
 wrdm32(ds, 0x10, (addr << 8) | value);
 while(rddm32(ds, 0x04) & (1U << 8));

 if(dobusywait)
  while(rddm32(ds, 0x04) & (1U << 9));
}


static uint16_t GetDMACounter(ES1370_Driver_t* ds)
{
 uint32_t a, b;
 unsigned counter = 0;

 do
 {
  a = rdesmem32(ds, 0xCC);
  b = rdesmem32(ds, 0xCC);
 } while(a != b);

 if(counter > 1)
  printf("DMA MOO: %d\n", counter);

 return(a >> 16);
}

static void UpdateReadCounter(ES1370_Driver_t* ds)
{
 uint16_t cur_dmacounter = GetDMACounter(ds);

 ds->read_counter -= ds->prev_dmacounter;
 ds->read_counter += cur_dmacounter;

 if(cur_dmacounter < ds->prev_dmacounter)
  ds->read_counter += (ds->dmabuf.size << 4) >> 2;

 ds->prev_dmacounter = cur_dmacounter;
}


static int Pause(SexyAL_device *device, int state)
{
 ES1370_Driver_t *ds = (ES1370_Driver_t *)device->private_data;

 wrdm32(ds, 0x00, (rddm32(ds, 0x00) &~ (1U << 5)) | ((!state) << 5) );

 ds->paused = state;

 return(state);
}

static int RawCanWrite(SexyAL_device *device, uint32_t *can_write)
{
 ES1370_Driver_t *ds = (ES1370_Driver_t *)device->private_data;

 UpdateReadCounter(ds);

 // Handle underflow.
 if(ds->write_counter < ds->read_counter)
  ds->write_counter = ds->read_counter;

 *can_write = (device->buffering.buffer_size - (ds->write_counter - ds->read_counter)) << 2;

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32_t len)
{
 ES1370_Driver_t *ds = (ES1370_Driver_t *)device->private_data;
 uint32_t pl_0, pl_1;
 const uint8_t* data_d8 = (uint8_t*)data;

 do
 {
  uint32_t cw;
  uint32_t i_len;
  uint32_t writepos;

  if(!RawCanWrite(device, &cw))	// Caution: RawCanWrite() will modify ds->write_counter on underflow.
   return(0);

  writepos = (ds->write_counter << 2) % (ds->dmabuf.size << 4);
  i_len = std::min<uint32>(cw, len);

  pl_0 = std::min<uint32>(i_len, (ds->dmabuf.size << 4) - writepos);
  pl_1 = i_len - pl_0;

  if(pl_0)
   _dosmemputb(data_d8, pl_0, (ds->dmabuf.rm_segment << 4) + writepos);

  if(pl_1)
   _dosmemputb(data_d8 + pl_0, pl_1, (ds->dmabuf.rm_segment << 4));

  ds->write_counter += i_len >> 2;

  data_d8 += i_len;
  len -= i_len;

  if(ds->paused)
   Pause(device, false);
 } while(len > 0);

 return(1);
}

static int Clear(SexyAL_device *device)
{
 ES1370_Driver_t *ds = (ES1370_Driver_t *)device->private_data;
 const uint32_t base = ds->dmabuf.rm_segment << 4;
 const uint32_t siz = ds->dmabuf.size << 4;

 Pause(device, true);

 _farsetsel(_dos_ds);
 for(unsigned i = 0; i < siz; i += 4)
  _farnspokel(base + i, 0);

 UpdateReadCounter(ds);
 ds->write_counter = ds->read_counter;

 return(1);
}

static void Cleanup(ES1370_Driver_t* ds)
{
 if(ds->dmabuf.size != 0)
 {
  _go32_dpmi_free_dos_memory(&ds->dmabuf);
  ds->dmabuf.size = 0;
 }

 if(ds->garbagebuf.size != 0)
 {
  _go32_dpmi_free_dos_memory(&ds->garbagebuf);
  ds->garbagebuf.size = 0;
 }

 if(ds->base_addr != 0)
 {
  wrdm32(ds, 0x00, (1 << 31) | (1 << 0));
 }
}

static int RawClose(SexyAL_device *device)
{
 ES1370_Driver_t *ds = (ES1370_Driver_t *)device->private_data;

 if(ds)
 {
  Cleanup(ds);
  free(ds);
  device->private_data = NULL;
 }

 return(1);
}

pci_vd_pair SexyAL_DOS_ES1370_PCI_IDs[] =
{
 { 0x1274, 0x5000 },
 { 0 }
};

bool SexyALI_DOS_ES1370_Avail(void)
{
 uint16_t bdf;

 if(!pci_bios_present())
  return(false);

 if(!pci_find_device(SexyAL_DOS_ES1370_PCI_IDs, 0, &bdf))
  return(false);

 return(true);
}

#define ES1370_INIT_CLEANUP			\
	if(device) free(device);		\
	if(ds) { Cleanup(ds); free(ds); }	\
	if(pis != -1) { __dpmi_get_and_set_virtual_interrupt_state(pis); pis = -1; }

SexyAL_device *SexyALI_DOS_ES1370_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device = NULL;
 ES1370_Driver_t *ds = NULL;
 int pis = -1;

 if(!(device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device))))
 {
  ES1370_INIT_CLEANUP
  return(NULL);
 }

 if(!(ds = (ES1370_Driver_t *)calloc(1, sizeof(ES1370_Driver_t))))
 {
  ES1370_INIT_CLEANUP
  return(NULL);
 }

 device->private_data = ds;

 //pis = __dpmi_get_and_disable_virtual_interrupt_state();

 if(!pci_bios_present())
 {
  fprintf(stderr, "ES1370: PCI BIOS not detected!\n");
  ES1370_INIT_CLEANUP
  return(NULL);
 }

 if(!pci_find_device(SexyAL_DOS_ES1370_PCI_IDs, id ? atoi(id) : 0, &ds->bdf))
 {
  fprintf(stderr, "ES1370: Device not found!\n");
  ES1370_INIT_CLEANUP
  return(NULL);
 }

 // Grab base address of port I/O stuff.
 ds->base_addr = pci_read_config_u32(ds->bdf, 0x10) &~ 1;
 //printf("BASSSSE: %08x %08x\n", ds->base_addr, pci_read_config_u32(ds->bdf, 0x10));

 //
 //
 //
 format->channels = 2;
 format->sampformat = SEXYAL_FMT_PCMS16;
 format->revbyteorder = false;
 format->noninterleaved = false;

 if(!buffering->ms) 
  buffering->ms = 24;

 buffering->period_size = ES_DMAFIFO_FETCHBYTESIZE >> 2;	// Sorta-kinda.

 //
 // We're going to use DAC2(codec).
 //
 // Interestingly, according to the AK4531 datasheet, CODEC-DAC has better stopband attenuation than the FM-DAC,
 // but worse passband ripple.
 //

 // From ALSA(re PCLKDIV):
 // #define ES_1370_SRCLOCK    1411200
 // #define ES_1370_SRTODIV(x) (ES_1370_SRCLOCK/(x)-2)
 //
 // 1411200

 int pclkdiv = (int)floor(0.5 + 1411200.0 / format->rate) - 2;

 if(pclkdiv < 27) // 48662
  pclkdiv = 27;

 if(pclkdiv > 350) // 4009
  pclkdiv = 350;

 format->rate = (unsigned)floor(0.5 + 1411200.0 / (pclkdiv + 2));	// TODO: take out round, use double for format->rate

 buffering->buffer_size = buffering->ms * format->rate / 1000;

 // 0x10000 = maximum DMA frame size thingy in longwords(=frames since we're hardcoded to stereo 16-bit)
 // * 2 so we can detect wraparound reliably.
 //
 if((buffering->buffer_size * 2) > 0x10000)
  buffering->buffer_size = 0x10000 / 2;

 buffering->latency = buffering->buffer_size + (ES_DMAFIFO_BYTESIZE >> 2) + 14;	

 memset(&ds->dmabuf, 0, sizeof(ds->dmabuf));
 ds->dmabuf.size = (((buffering->buffer_size * 2) << 2) + 15) / 16;
 if(_go32_dpmi_allocate_dos_memory(&ds->dmabuf) != 0)
 {
  fprintf(stderr, "ES1370: error allocating DMA memory.");
  ES1370_INIT_CLEANUP
  return(NULL);
 }

 memset(&ds->garbagebuf, 0, sizeof(ds->garbagebuf));
 ds->garbagebuf.size = (4 + 15) / 16;
 if(_go32_dpmi_allocate_dos_memory(&ds->dmabuf) != 0)
 {
  fprintf(stderr, "ES1370: error allocating garbage memory.");
  ES1370_INIT_CLEANUP
  return(NULL);
 }

 //
 // Clear DMA buffer memory.
 //
 {
  const uint32_t base = ds->dmabuf.rm_segment << 4;
  const uint32_t siz = ds->dmabuf.size << 4;

  _farsetsel(_dos_ds);
  for(unsigned i = 0; i < siz; i += 4)
   _farnspokel(base + i, 0);
 }


 // 0x00:
 // ADC stopped, pclkdiv, other stuff disabled, codec enabled.
 wrdm32(ds, 0x00, (1 << 31) | (pclkdiv << 16) | (1 << 1) | (1 << 0));

 // 0x20:
 // P2_END_INC = 2, P2_ST_INC = 0, P2_LOOP_SEL=0(loop mode), P2_PAUSE=0, P2_INTR_EN=0, P2_DAC_SEN=0, P2 16-bit 2-channel mode
 wrdm32(ds, 0x20, (2 << 19) | (0 << 16) | (0 << 14) | (0 << 12) | (0 << 9) | 0xC);
 ds->paused = true;
 wrdm32(ds, 0x28, 0);	// DAC2 Sample count register(we don't use it anymore because it's evil, EVIL I SAY)

 ds->prev_dmacounter = 0;
 ds->read_counter = 0;
 ds->write_counter = 0;

 //
 //
 wresmem32(ds, 0xC8, ds->dmabuf.rm_segment << 4);		// Buffer physical address.
 wresmem32(ds, 0xCC, ((ds->dmabuf.size << 4) >> 2) - 1);	// Buffer size(lower 16-bits).


 wresmem32(ds, 0xD0, ds->garbagebuf.rm_segment << 4);
 wresmem32(ds, 0xD4, 0);
 wresmem32(ds, 0xD8, ds->garbagebuf.rm_segment << 4);
 wresmem32(ds, 0xDC, 0);

 // 0x00:
 // ADC stopped, pclkdiv, XCTL0=1(possibly needed for CT4700 cards?), DAC2 playback disabled, joystick enabled, codec enabled, SERR disabled
 wrdm32(ds, 0x00, (1 << 31) | (pclkdiv << 16) | (1 << 8) | (0 << 5) | (1 << 2) | (1 << 1) | (1 << 0));

 //
 // Initialize AK4531 stuff
 //

 // Reset
 wrcodec(ds, 0x16, 0x02, false);	// Reset, no power down.
 for(unsigned i = 0; i < 1000; i++)	// Needs at least 150ns?
  rddm32(ds, 0x10);
 wrcodec(ds, 0x16, 0x03);	// No reset, no power down.

 wrcodec(ds, 0x17, 0x00);	// Clock select.

 wrcodec(ds, 0x00, 0x00);	// Master L, 0dB attenuation.
 wrcodec(ds, 0x01, 0x00);	// Master R, 0dB attenuation.
 wrcodec(ds, 0x02, 0x06);	// Voice L, 0dB gain.
 wrcodec(ds, 0x03, 0x06);	// Voice R, 0dB gain.

 // MUTE and -50dB the rest
 for(unsigned i = 0x04; i < 0x0F; i++)
  wrcodec(ds, i, 0x80);

 wrcodec(ds, 0x0F, 0x87);	// Mono-out, mute and -28dB.

 wrcodec(ds, 0x10, 0x00);	// Output mixer SW1
 wrcodec(ds, 0x11, 0x03 << 2);	// Output mixer SW2(VoiceL and VoiceR enabled).

 // Disable inputs.
 wrcodec(ds, 0x12, 0x00);
 wrcodec(ds, 0x13, 0x00);
 wrcodec(ds, 0x14, 0x00);
 wrcodec(ds, 0x15, 0x00);

 //
 // End AK4531 init
 //

 printf("DMABUF addr=0x%08x, size=0x%08x\n", ds->dmabuf.rm_segment << 4, ds->dmabuf.size << 4);
 printf("ES1370 init done.\n");

 memcpy(&device->format, format, sizeof(SexyAL_format));
 memcpy(&device->buffering, buffering, sizeof(SexyAL_buffering));

 device->RawCanWrite = RawCanWrite;
 device->RawWrite = RawWrite;
 device->RawClose = RawClose;
 device->Clear = Clear;
 device->Pause = Pause;


 if(pis != -1)
  __dpmi_get_and_set_virtual_interrupt_state(pis); 

 return(device);
}

