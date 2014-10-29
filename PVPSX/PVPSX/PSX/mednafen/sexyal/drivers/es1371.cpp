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
	Hard-coded to 16-bit stereo to minimize buffer position timing granularity, and to simplify stuff.
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

 uint64_t read_counter;		// In frames, not bytes.
 uint64_t write_counter;	// In frames, not bytes.

 uint16_t prev_dmacounter;
 bool paused;
} ES1371_Driver_t;

static void wrdm32(ES1371_Driver_t* ds, uint32_t offset, uint32_t value)
{
 outportl(ds->base_addr + offset, value);
 //printf("wrdm32() %02x:%08x ;;; %08x\n", offset, value, inportl(ds->base_addr + offset));
}

static uint32_t rddm32(ES1371_Driver_t* ds, uint32_t offset)
{
 return inportl(ds->base_addr + offset);
}

static void wrdm16(ES1371_Driver_t* ds, uint32_t offset, uint16_t value)
{
 outportw(ds->base_addr + offset, value);
 //printf("wrdm16() %02x:%04x ;;; %04x\n", offset, value, inportw(ds->base_addr + offset));
}

static uint16_t rddm16(ES1371_Driver_t* ds, uint32_t offset)
{
 return inportw(ds->base_addr + offset);
}

static void wresmem32(ES1371_Driver_t* ds, uint32_t offset, uint32_t value)
{
 wrdm32(ds, 0x0C, offset >> 4);
 wrdm32(ds, 0x30 + (offset & 0xF), value);
}

static uint32_t rdesmem32(ES1371_Driver_t* ds, uint32_t offset)
{
 wrdm32(ds, 0x0C, offset >> 4);
 return rddm32(ds, 0x30 + (offset & 0xF));
}


static void wrcodec(ES1371_Driver_t* ds, uint8 addr, uint16 value)
{
 while(rddm32(ds, 0x14) & (1U << 30));
 wrdm32(ds, 0x14, (1 << 26) | (0 << 23) | (addr << 16) | (value << 0));
 while(rddm32(ds, 0x14) & (1U << 30));
}

static uint16 rdcodec(ES1371_Driver_t* ds, uint8 addr) // BUG: Appears to hang with EV1938
{
 uint32 tmp;
 uint32 i = 0;

 while(rddm32(ds, 0x14) & (1U << 30));
 wrdm32(ds, 0x14, (1 << 26) | (1 << 23) | (addr << 16));

 do
 {
  tmp = rddm32(ds, 0x14);
  i++;
 } while(i < 200 || !(tmp & (1U << 31)) || (tmp & (1U << 30)));

 return(tmp & 0xFFFF);
}

static void wrsrc(ES1371_Driver_t* ds, uint8_t addr, uint16_t value)
{
 uint32_t tow;

 //printf("WRSRC: %02x %04x\n", addr, value);

 while(rddm32(ds, 0x10) & (1U << 23));
 tow = (addr << 25) | (1U << 24) | (rddm32(ds, 0x10) & (0xFFU << 16)) | (value << 0);
 wrdm32(ds, 0x10, tow);

 for(unsigned i = 0; i < 8 || (rddm32(ds, 0x10) & (1U << 23)); i++);
}

static uint16_t rdsrc(ES1371_Driver_t* ds, uint8_t addr)
{
 uint32_t tow;
 uint32_t tmp;

 while(rddm32(ds, 0x10) & (1U << 23));
 tow = (addr << 25) | (0U << 24) | (rddm32(ds, 0x10) & (0xFFU << 16));
 wrdm32(ds, 0x10, tow);

 for(unsigned i = 0; i < 8 || ((tmp = rddm32(ds, 0x10)) & (1U << 23)); i++);

 return(tmp & 0xFFFF);
}

static uint16_t GetDMACounter(ES1371_Driver_t* ds)
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

static void UpdateReadCounter(ES1371_Driver_t* ds)
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
 ES1371_Driver_t *ds = (ES1371_Driver_t *)device->private_data;

 wrdm32(ds, 0x00, (rddm32(ds, 0x00) &~ (1U << 5)) | ((!state) << 5) );

 ds->paused = state;

 return(state);
}

static int RawCanWrite(SexyAL_device *device, uint32_t *can_write)
{
 ES1371_Driver_t *ds = (ES1371_Driver_t *)device->private_data;

 UpdateReadCounter(ds);

 // Handle underflow.
 if(ds->write_counter < ds->read_counter)
  ds->write_counter = ds->read_counter;

 *can_write = (device->buffering.buffer_size - (ds->write_counter - ds->read_counter)) << 2;

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32_t len)
{
 ES1371_Driver_t *ds = (ES1371_Driver_t *)device->private_data;
 uint32_t pl_0, pl_1;
 const uint8_t* data_d8 = (uint8_t*)data;

 do
 {
  uint32_t cw;
  uint32_t i_len;
  uint32_t writepos;

  if(!RawCanWrite(device, &cw))	// Caution: RawCanWrite() will modify ds->write_counter on underflow.
   return(0);

  //printf("%08x %08x\n", cw, rdesmem32(ds, 0xCC));

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
 ES1371_Driver_t *ds = (ES1371_Driver_t *)device->private_data;
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

static void Cleanup(ES1371_Driver_t* ds)
{
 if(ds->dmabuf.size != 0)
 {
  _go32_dpmi_free_dos_memory(&ds->dmabuf);
  ds->dmabuf.size = 0;
 }

 if(ds->base_addr != 0)
 {
  wrdm32(ds, 0x00, (1 << 13));
  wrdm32(ds, 0x04, 0);
  wrdm32(ds, 0x18, 0);
 }
}

static int RawClose(SexyAL_device *device)
{
 ES1371_Driver_t *ds = (ES1371_Driver_t *)device->private_data;

 if(ds)
 {
  Cleanup(ds);
  free(ds);
  device->private_data = NULL;
 }

 return(1);
}

pci_vd_pair SexyAL_DOS_ES1371_PCI_IDs[] =
{
 { 0x1274, 0x1371 },
 { 0x1274, 0x5880 },
 { 0x1102, 0x8938 },

 { 0 }
};

bool SexyALI_DOS_ES1371_Avail(void)
{
 uint16_t bdf;

 if(!pci_bios_present())
  return(false);

 if(!pci_find_device(SexyAL_DOS_ES1371_PCI_IDs, 0, &bdf))
  return(false);

 return(true);
}

#define ES1371_INIT_CLEANUP			\
	if(device) free(device);		\
	if(ds) { Cleanup(ds); free(ds); }	\
	if(pis != -1) { __dpmi_get_and_set_virtual_interrupt_state(pis); pis = -1; }

SexyAL_device *SexyALI_DOS_ES1371_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device = NULL;
 ES1371_Driver_t *ds = NULL;
 pci_vd_pair *cur_pciid = NULL;
 int pis = -1;

 if(!(device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device))))
 {
  ES1371_INIT_CLEANUP
  return(NULL);
 }

 if(!(ds = (ES1371_Driver_t *)calloc(1, sizeof(ES1371_Driver_t))))
 {
  ES1371_INIT_CLEANUP
  return(NULL);
 }

 device->private_data = ds;

 //pis = __dpmi_get_and_disable_virtual_interrupt_state();

 if(!pci_bios_present())
 {
  fprintf(stderr, "ES1371: PCI BIOS not detected!\n");
  ES1371_INIT_CLEANUP
  return(NULL);
 }

 if(!(cur_pciid = pci_find_device(SexyAL_DOS_ES1371_PCI_IDs, id ? atoi(id) : 0, &ds->bdf)))
 {
  fprintf(stderr, "ES1371: Device not found!\n");
  ES1371_INIT_CLEANUP
  return(NULL);
 }

 // Grab base address of port I/O stuff.
 ds->base_addr = pci_read_config_u32(ds->bdf, 0x10) &~ 1;
 //printf("BASSSSE: %08x %08x\n", ds->base_addr, pci_read_config_u32(ds->bdf, 0x10));

 printf("ES1371 Revision: 0x%02x\n", pci_read_config_u8(ds->bdf, 0x08) & 0xFF);

 //
 //
 //
 format->rate = 48000;	// Hard-coded to 48KHz, at least until we can figure out how to make the resampler not be horrible at other rates.
 format->channels = 2;
 format->sampformat = SEXYAL_FMT_PCMS16;
 format->revbyteorder = false;
 format->noninterleaved = false;

 //
 // We're going to use DAC2.
 //

 // 0x00:
 // SYNC_RES=0, ADC_STOP=1.
 wrdm32(ds, 0x00, (0 << 14) | (1 << 13));
 bool support_src_bypass = ((rddm32(ds, 0x00) >> 29) == 0);

 //printf("Support SRC bypass: %d\n", (int)support_src_bypass);

 //
 // AC-97 reset for CT5880(how necessary is it?)
 //
 wrdm32(ds, 0x04, (1 << 29));
 for(unsigned i = 0; i < 660000; i++)
  rddm32(ds, 0x04);
 wrdm32(ds, 0x04, (0 << 29));


 // 0x00:
 // SYNC_RES=1, ADC_STOP=1.
 wrdm32(ds, 0x00, (1 << 14) | (1 << 13));


 // 0x20:
 // P2_END_INC = 2, P2_ST_INC = 0, P2_LOOP_SEL=0(loop mode), P2_PAUSE=0, P2_INTR_EN=0, P2_DAC_SEN=0, P2 16-bit 2-channel mode
 wrdm32(ds, 0x20, (2 << 19) | (0 << 16) | (0 << 14) | (0 << 12) | (0 << 9) | 0xC);
 ds->paused = true;
 wrdm32(ds, 0x28, 0);	// DAC2 Sample count register(we don't use it anymore because it's evil, EVIL I SAY)


 //
 // Program SRC(poorly-documented!) stuff
 //

 {
  uint32_t tmp_freq;

  //printf("Program SRC\n");

  if(format->rate > 48000)
   format->rate = 48000;

  if(format->rate < 4000)
   format->rate = 4000;

  tmp_freq = ((format->rate << 15) + 1500) / 3000;
  format->rate = (tmp_freq * 3000 + (1U << 14)) / (1U << 15);
  // format->rate = (double)(tmp_freq * 3000) / (1U << 15);	// TODO for future.

  // Disable SRC
  wrdm32(ds, 0x10, (1 << 22) | (1 << 21) | (1 << 20) | (1 << 19));

  for(unsigned i = 0; i < 0x80; i++)
   wrsrc(ds, i, 0x0000);

  //
  // Set SMF=1 when our rate is 48KHz, as it seems to partially bypass the sucky(horrible passband ripple) resampler.
  //
  // ...although it is possible that the suckiness is from programming the resampler improperly, as the ES1371 SRC parameters
  // are very poorly documented. :/
  //
  wrsrc(ds, 0x74 + 0x00, ((format->rate == 48000) ? 0x8000 : 0) | (16 << 4)); // atoi(getenv("SPOON"))); //0x8000 | (16 << 4));		// SMF, TRUNC_START, N, HSTART (wtf?)
  wrsrc(ds, 0x74 + 0x01, ((tmp_freq >> 15) << 10) | (0 << 0));	// VF.I and AC.I
  wrsrc(ds, 0x74 + 0x02, 0x0000);	// AC.F
  wrsrc(ds, 0x74 + 0x03, tmp_freq & 0x7FFF);	// VF.F

  // Prevent chip lockup.
  wrsrc(ds, 0x70 + 0x00, 16 << 4);
  wrsrc(ds, 0x70 + 0x01, 16 << 10);
  wrsrc(ds, 0x78 + 0x00, 16 << 4);
  wrsrc(ds, 0x78 + 0x01, 16 << 10);


  // P2 volume
  wrsrc(ds, 0x7E, 1U << 12);
  wrsrc(ds, 0x7F, 1U << 12);

  // Enable SRC
  wrdm32(ds, 0x10, (0 << 22) | (1 << 21) | (0 << 20) | (1 << 19));
 }

 //
 // End SRC
 //

 if(!buffering->ms) 
  buffering->ms = 24;

 buffering->period_size = ES_DMAFIFO_FETCHBYTESIZE >> 2;	// Sorta-kinda.
 buffering->buffer_size = buffering->ms * format->rate / 1000;

 // 0x10000 = maximum DMA frame size thingy in longwords(=frames since we're hardcoded to stereo 16-bit)
 // * 2 so we can detect wraparound reliably.
 //
 if((buffering->buffer_size * 2) > 0x10000)
  buffering->buffer_size = 0x10000 / 2;

 // SRC latency is a bit of a guess.
 // TODO: codec latency.
 buffering->latency = buffering->buffer_size + (ES_DMAFIFO_BYTESIZE >> 2) + ((format->rate != 48000 || !support_src_bypass) ? 8 : 0);

 memset(&ds->dmabuf, 0, sizeof(ds->dmabuf));
 ds->dmabuf.size = (((buffering->buffer_size * 2) << 2) + 15) / 16;
 if(_go32_dpmi_allocate_dos_memory(&ds->dmabuf) != 0)
 {
  fprintf(stderr, "ES1371: error allocating DMA memory.");
  ES1371_INIT_CLEANUP
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

 ds->prev_dmacounter = 0;
 ds->read_counter = 0;
 ds->write_counter = 0;

 //
 //
 wresmem32(ds, 0xC8, ds->dmabuf.rm_segment << 4);		// Buffer physical address.
 wresmem32(ds, 0xCC, ((ds->dmabuf.size << 4) >> 2) - 1);	// Buffer size(lower 16-bits).

 //
 // Legacy
 //  Fast joystick timing, 
 wrdm32(ds, 0x18, (1 << 31));

 // 0x00:
 // BYPASS_P2=1(ES1373), joyport at 0x200, SYNC_RES=0, ADC_STOP=1, joystick enabled.
 wrdm32(ds, 0x00, ((format->rate == 48000) ? (1U << 30) : 0) | (0 << 24) | (0 << 14) | (1 << 13) | (1 << 2));


 //
 // Program AC97 codec.
 //
 printf("Program AC97\n");
 {
  //uint32_t codec_vendor = (rdcodec(ds, 0x7C) << 16) | rdcodec(ds, 0x7E);
  //printf("AC97 Codec Vendor ID: 0x%08x %c%c%c%c\n", codec_vendor, (codec_vendor >> 24) & 0xFF, (codec_vendor >> 16) & 0xFF, (codec_vendor >> 8) & 0xFF, (codec_vendor >> 0) & 0xFF);

  wrcodec(ds, 0x00, 0x0001);	// Reset(non-zero value required by AK4540).
  wrcodec(ds, 0x0A, 0x8000);	// Mute PC BEEEEEEEP to prevent a spurious tone at 48KHz from getting into the signal(at least with my Audio PCI board).

  wrcodec(ds, 0x02, 0x0000);	// Master volume, 0dB attenuation
  wrcodec(ds, 0x04, 0x0000);	// AUX out, 0dB attenuation

  //if(cur_pciid->vendor == 0x1102 && cur_pciid->device == 0x8938)	// Check for EV1938
  //{
  // printf("EV1938 Meow\n");
  // wrcodec(ds, 0x18, (0xC << 8) | 0xC); // PCM out volume.
  //}
  //else
  {
   wrcodec(ds, 0x18, (8 << 8) | 8); // PCM out volume, eeeeeeeiiight, 0dB gain.
  }
 }
 //printf("DMABUF addr=0x%08x, size=0x%08x\n", ds->dmabuf.rm_segment << 4, ds->dmabuf.size << 4);
 //printf("ES1371 init done.\n");

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

