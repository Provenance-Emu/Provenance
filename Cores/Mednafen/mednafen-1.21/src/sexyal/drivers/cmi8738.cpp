/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* cmi8738.cpp - C-Media CMI8738 Sound Driver
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
 Notes:
	hard-coded 16-bit stereo support to minimize buffer position timing granularity, and to simplify stuff
*/

#include "dos_common.h"

/*
static const int CMI_DMAFIFO_BYTESIZE = 0;
static const int CMI_DMAFIFO_FETCHBYTESIZE = 0;
*/

typedef struct
{
 uint16 bdf;
 uint32 base_addr;

 _go32_dpmi_seginfo dmabuf;

 uint64 read_counter;		// In frames, not bytes.
 uint64 write_counter;	// In frames, not bytes.

 uint16 prev_dmacounter;
 bool paused;
} CMI8738_Driver_t;

static void wrdm32(CMI8738_Driver_t* ds, uint32 offset, uint32 value)
{
 outportl(ds->base_addr + offset, value);
 //printf("wrdm32() %02x:%08x ;;; %08x\n", offset, value, inportl(ds->base_addr + offset));
}

static uint32 rddm32(CMI8738_Driver_t* ds, uint32 offset)
{
 return inportl(ds->base_addr + offset);
}

static void wrdm16(CMI8738_Driver_t* ds, uint32 offset, uint16 value)
{
 outportw(ds->base_addr + offset, value);
}

static uint16 rddm16(CMI8738_Driver_t* ds, uint32 offset)
{
 return inportw(ds->base_addr + offset);
}

static void wrdm8(CMI8738_Driver_t* ds, uint32 offset, uint8 value)
{
 outportb(ds->base_addr + offset, value);
}

static uint8 rddm8(CMI8738_Driver_t* ds, uint32 offset)
{
 return inportb(ds->base_addr + offset);
}

static void wrmix(CMI8738_Driver_t* ds, uint8 offset, uint8 value)
{
 wrdm8(ds, 0x23, offset);
 wrdm8(ds, 0x22, value);
}

static uint8 rdmix(CMI8738_Driver_t* ds, uint8 offset)
{
 wrdm8(ds, 0x23, offset);

 return rddm8(ds, 0x22);
}

static uint16 GetDMACounter(CMI8738_Driver_t* ds)
{
 uint32 a, b;

 do
 {
  a = rddm32(ds, 0x80);
  b = rddm32(ds, 0x80);
 } while(a != b);

 //printf("%08x %08x\n", rddm32(ds, 0x80), rddm32(ds, 0x84));
 //printf("ALT: %08x %08x\n", rddm32(ds, 0x88), rddm32(ds, 0x8C));

 return((a - (ds->dmabuf.rm_segment << 4)) >> 2);
}

static void UpdateReadCounter(CMI8738_Driver_t* ds)
{
 uint16 cur_dmacounter = GetDMACounter(ds);

 ds->read_counter -= ds->prev_dmacounter;
 ds->read_counter += cur_dmacounter;

 if(cur_dmacounter < ds->prev_dmacounter)
  ds->read_counter += (ds->dmabuf.size << 4) >> 2;

 ds->prev_dmacounter = cur_dmacounter;
}


static int Pause(SexyAL_device *device, int state)
{
 CMI8738_Driver_t *ds = (CMI8738_Driver_t *)device->private_data;

 wrdm32(ds, 0x00, (rddm32(ds, 0x00) &~ (3U << 2)) | ((bool)state << 2) | ((bool)state << 3) );
 //printf("PA: 0x%08x\n", rddm32(ds, 0x00));

 ds->paused = state;

 return(state);
}

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 CMI8738_Driver_t *ds = (CMI8738_Driver_t *)device->private_data;

 UpdateReadCounter(ds);

 // Handle underflow.
 if(ds->write_counter < ds->read_counter)
  ds->write_counter = ds->read_counter;

 *can_write = (device->buffering.buffer_size - (ds->write_counter - ds->read_counter)) << 2;

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 CMI8738_Driver_t *ds = (CMI8738_Driver_t *)device->private_data;
 uint32 pl_0, pl_1;
 const uint8* data_d8 = (uint8*)data;

 do
 {
  uint32 cw;
  uint32 i_len;
  uint32 writepos;

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
 CMI8738_Driver_t *ds = (CMI8738_Driver_t *)device->private_data;
 const uint32 base = ds->dmabuf.rm_segment << 4;
 const uint32 siz = ds->dmabuf.size << 4;

 Pause(device, true);

 _farsetsel(_dos_ds);
 for(unsigned i = 0; i < siz; i += 4)
  _farnspokel(base + i, 0);

 UpdateReadCounter(ds);
 ds->write_counter = ds->read_counter;

 return(1);
}

static void Cleanup(CMI8738_Driver_t* ds)
{
 if(ds->dmabuf.size != 0)
 {
  _go32_dpmi_free_dos_memory(&ds->dmabuf);
  ds->dmabuf.size = 0;
 }

 if(ds->base_addr != 0)
 {
  wrdm32(ds, 0x00, (1U << 18));
 }
}

static int RawClose(SexyAL_device *device)
{
 CMI8738_Driver_t *ds = (CMI8738_Driver_t *)device->private_data;

 if(ds)
 {
  Cleanup(ds);
  free(ds);
  device->private_data = NULL;
 }

 return(1);
}

pci_vd_pair SexyAL_DOS_CMI8738_PCI_IDs[] =
{
 { 0x13F6, 0x0100 },	// CMI8338A
 { 0x13F6, 0x0101 },	// CMI8338B

 { 0x13F6, 0x0111 },	// CMI8738
 { 0x13F6, 0x0112 },	// CMI8738B

 { 0x10B9, 0x0111 },	// ? (from Linux kernel

 { 0 }
};

bool SexyALI_DOS_CMI8738_Avail(void)
{
 uint16 bdf;

 if(!pci_bios_present())
  return(false);

 if(!pci_find_device(SexyAL_DOS_CMI8738_PCI_IDs, 0, &bdf))
  return(false);

 return(true);
}

#define CMI8738_INIT_CLEANUP			\
	if(device) free(device);		\
	if(ds) { Cleanup(ds); free(ds); }	\
	if(pis != -1) { __dpmi_get_and_set_virtual_interrupt_state(pis); pis = -1; }

SexyAL_device *SexyALI_DOS_CMI8738_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device = NULL;
 CMI8738_Driver_t *ds = NULL;
 int pis = -1;

 if(!(device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device))))
 {
  CMI8738_INIT_CLEANUP
  return(NULL);
 }

 if(!(ds = (CMI8738_Driver_t *)calloc(1, sizeof(CMI8738_Driver_t))))
 {
  CMI8738_INIT_CLEANUP
  return(NULL);
 }

 device->private_data = ds;

 //pis = __dpmi_get_and_disable_virtual_interrupt_state();

 if(!pci_bios_present())
 {
  fprintf(stderr, "CMI8738: PCI BIOS not detected!\n");
  CMI8738_INIT_CLEANUP
  return(NULL);
 }

 if(!pci_find_device(SexyAL_DOS_CMI8738_PCI_IDs, id ? atoi(id) : 0, &ds->bdf))
 {
  fprintf(stderr, "CMI8738: Device not found!\n");
  CMI8738_INIT_CLEANUP
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
 format->noninterleaved = false;

 if(!buffering->ms) 
  buffering->ms = 24;

 buffering->period_size = 0; //CMI_DMAFIFO_FETCHBYTESIZE >> 2;	// Sorta-kinda.

 int dsfc = 0;
 {
  int err = 1U << 30;
  int rate = 0;

  for(unsigned trydsfc = 0; trydsfc < 8; trydsfc++)
  {
   static const int rate_tab[8] = { 5512, 11025, 22050, 44100, 8000, 16000, 32000, 48000 };
   int tmprate;
   int tmperr;

   tmprate = rate_tab[trydsfc];
   tmperr = abs(tmprate - format->rate);

   if(tmperr < err || (tmperr == err && tmprate > rate))
   {
    err = tmperr;
    rate = tmprate;
    dsfc = trydsfc;
   }
  }
  format->rate = rate;
 }
 //printf("DSCFC: %02x\n", dsfc);

 buffering->buffer_size = buffering->ms * format->rate / 1000;

 // 0x10000 = maximum DMA frame size thingy in frames.
 // * 2 so we can detect wraparound reliably.
 //
 if((buffering->buffer_size * 2) > 0x10000)
  buffering->buffer_size = 0x10000 / 2;

 buffering->latency = buffering->buffer_size; // + (CMI_DMAFIFO_BYTESIZE >> 2);

 memset(&ds->dmabuf, 0, sizeof(ds->dmabuf));
 ds->dmabuf.size = (((buffering->buffer_size * 2) << 2) + 15) / 16;
 if(_go32_dpmi_allocate_dos_memory(&ds->dmabuf) != 0)
 {
  fprintf(stderr, "CMI8738: error allocating DMA memory.");
  CMI8738_INIT_CLEANUP
  return(NULL);
 }

 //
 // Clear DMA buffer memory.
 //
 {
  const uint32 base = ds->dmabuf.rm_segment << 4;
  const uint32 siz = ds->dmabuf.size << 4;

  _farsetsel(_dos_ds);
  for(unsigned i = 0; i < siz; i += 4)
   _farnspokel(base + i, 0);
 }

 //
 // We're using CH0.
 //

 wrdm32(ds, 0x00, (1U << 19) | (1U << 18));
 wrdm32(ds, 0x00, 0);

 wrdm32(ds, 0x18, (1U << 30));
 wrdm32(ds, 0x18, 0);

 wrdm32(ds, 0x1C, 0);
 wrdm8(ds, 0x20, 0);
 wrdm8(ds, 0x21, 0);
 wrdm8(ds, 0x24, 1 << 7);
 wrdm8(ds, 0x25, 3 << 4);
 wrdm8(ds, 0x26, 0);
 wrdm8(ds, 0x27, 0);


 wrdm32(ds, 0x04, (dsfc << 13) | (dsfc << 10));
 wrdm32(ds, 0x08, (0x3 << 0));
 wrdm32(ds, 0x0C, 0);
 wrdm32(ds, 0x10, 0);
 wrdm32(ds, 0x14, 0);
 wrdm32(ds, 0x18, (1U << 27) /*| (1U << 26) | (1U << 23)*/);


 ds->prev_dmacounter = 0;
 ds->read_counter = 0;
 ds->write_counter = 0;
 wrdm32(ds, 0x80, ds->dmabuf.rm_segment << 4);
 wrdm32(ds, 0x84, (((ds->dmabuf.size << 4) >> 2) - 1) | ((((ds->dmabuf.size << 4) >> 2) - 1) << 16));
 wrdm32(ds, 0x88, ds->dmabuf.rm_segment << 4);
 wrdm32(ds, 0x8C, (((ds->dmabuf.size << 4) >> 2) - 1) | ((((ds->dmabuf.size << 4) >> 2) - 1) << 16));

 wrdm32(ds, 0x04, (dsfc << 13) | (dsfc << 10) | (1U << 4) | (1U << 1));
 wrdm32(ds, 0x00, (/*1U*/0 << 17) | (1U << 16) | (1U << 3) | (1U << 2) | (0 << 1) | (0 << 0));
 ds->paused = true;

 //
 // Mixer 
 //
 wrmix(ds, 0x00, 0x00);
 wrmix(ds, 0x04, 0xFF);
 wrmix(ds, 0x0A, 0x00);
 wrmix(ds, 0x22, 0xFF);
 wrmix(ds, 0x26, 0x00);
 wrmix(ds, 0x28, 0x00);
 wrmix(ds, 0x2E, 0x00);
 wrmix(ds, 0x3B, 0x00);
 wrmix(ds, 0xF0, 0x00);

 //
 // End mixer init
 //

 printf("DMABUF addr=0x%08x, size=0x%08x\n", ds->dmabuf.rm_segment << 4, ds->dmabuf.size << 4);
 printf("CMI8738 init done.\n");

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

