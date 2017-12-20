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

#include "dos_common.h"

/*
 PCI Notes:

	PCI BIOS routines nominally require 1024 bytes of stack space; DPMI only best-case-guarantees 512 bytes,
	so we should allocate our own stack.
*/

enum { PCI_FUNCTION_ID = 0xB1 };	// AH

enum	// AL
{
 PCI_BIOS_PRESENT = 0x01,
 FIND_PCI_DEVICE = 0x02,
 FIND_PCI_CLASS_CODE = 0x03,
 GENERATE_SPECIAL_CYCLE = 0x06,

 READ_CONFIG_BYTE = 0x08,
 READ_CONFIG_WORD = 0x09,
 READ_CONFIG_DWORD = 0x0A,

 WRITE_CONFIG_BYTE = 0x0B,
 WRITE_CONFIG_WORD = 0x0C,
 WRITE_CONFIG_DWORD = 0x0D,

 GET_IRQ_ROUTING_OPTIONS = 0x0E,
 SET_PCI_IRQ = 0x0F
};

enum
{
 PCI_SUCCESSFUL = 0x00,
 PCI_FUNC_NOT_SUPPORTED = 0x81,
 PCI_BAD_VENDOR_ID = 0x83,
 PCI_DEVICE_NOT_FOUND = 0x86,
 PCI_BAD_REGISTER_NUMBER = 0x87,
 PCI_SET_FAILED = 0x88,
 PCI_BUFFER_TOO_SMALL = 0x89
};

static void bch(unsigned fn, _go32_dpmi_registers* r)
{
 static const unsigned pci_stack_size = 2048;
 _go32_dpmi_seginfo si;
 int go32_ec;

 assert(pci_stack_size <= 65536);

 r->h.ah = PCI_FUNCTION_ID;
 r->h.al = fn;

 memset(&si, 0, sizeof(si));
 si.size = (pci_stack_size + 15) / 16;
 go32_ec = _go32_dpmi_allocate_dos_memory(&si);
 if(go32_ec != 0)
 {
  fprintf(stderr, "DOS memory allocation failed: %d\n", go32_ec);
  abort();
 }
 r->x.ss = si.rm_segment;
 r->x.sp = pci_stack_size;


 go32_ec = _go32_dpmi_simulate_int(0x1A, r);
 if(go32_ec != 0)
 {
  _go32_dpmi_free_dos_memory(&si);
  fprintf(stderr, "Simulate int failed: %d\n", go32_ec);
  abort();
 }
 _go32_dpmi_free_dos_memory(&si);
}

bool pci_bios_present(void)
{
 _go32_dpmi_registers r;
 memset(&r, 0, sizeof(r));

 bch(PCI_BIOS_PRESENT, &r);
 if(r.d.edx == (('P' << 0) | ('C' << 8) | ('I' << 16) | (' ' << 24)) && r.h.ah == PCI_SUCCESSFUL)
  return(true);

 return(false);
}

bool pci_find_device(uint16_t vend_id, uint16_t dev_id, uint16_t index, uint16_t* bdf)
{
 _go32_dpmi_registers r;
 memset(&r, 0, sizeof(r));

 r.x.cx = dev_id;
 r.x.dx = vend_id;
 r.x.si = index;

 bch(FIND_PCI_DEVICE, &r);
 if(r.h.ah != PCI_SUCCESSFUL)
 {
  if(r.h.ah == PCI_DEVICE_NOT_FOUND)
   return(false);

  fprintf(stderr, "FIND_PCI_DEVICE 0x%04x:0x%04x 0x%04x failed: %u\n", vend_id, dev_id, index, r.h.ah);
  abort();
 }

 *bdf = r.x.bx;

 return(true);
}

pci_vd_pair* pci_find_device(pci_vd_pair* pci_ids, uint32_t index, uint16_t* bdf)
{
 uint32_t i = 0;

 while(pci_ids->vendor || pci_ids->device)
 {
  uint16_t bdf_try;

  for(uint16_t idx_try = 0; pci_find_device(pci_ids->vendor, pci_ids->device, idx_try, &bdf_try); idx_try++)
  {
   if(i == index)
   {
    *bdf = bdf_try;
    return(pci_ids);
   }
   i++;
  }

  pci_ids++;
 }

 return(NULL);
}

uint8_t pci_read_config_u8(uint16_t bdf, unsigned index)
{
 _go32_dpmi_registers r;
 memset(&r, 0, sizeof(r));

 r.x.bx = bdf;
 r.x.di = index;

 bch(READ_CONFIG_BYTE, &r);
 if(r.h.ah != PCI_SUCCESSFUL)
 {
  fprintf(stderr, "READ_CONFIG_BYTE 0x%08x 0x%08x failed: %u\n", bdf, index, r.h.ah);
  abort();
 }

 return(r.h.cl);
}

uint16_t pci_read_config_u16(uint16_t bdf, unsigned index)
{
 _go32_dpmi_registers r;
 memset(&r, 0, sizeof(r));

 r.x.bx = bdf;
 r.x.di = index;

 bch(READ_CONFIG_WORD, &r);
 if(r.h.ah != PCI_SUCCESSFUL)
 {
  fprintf(stderr, "READ_CONFIG_WORD 0x%08x 0x%08x failed: %u\n", bdf, index, r.h.ah);
  abort();
 }

 return(r.x.cx);
}

uint32_t pci_read_config_u32(uint16_t bdf, unsigned index)
{
 _go32_dpmi_registers r;
 memset(&r, 0, sizeof(r));

 r.x.bx = bdf;
 r.x.di = index;

 bch(READ_CONFIG_DWORD, &r);
 if(r.h.ah != PCI_SUCCESSFUL)
 {
  fprintf(stderr, "READ_CONFIG_DWORD 0x%08x 0x%08x failed: %u\n", bdf, index, r.h.ah);
  abort();
 }

 return(r.d.ecx);
}

void pci_write_config_u8(uint16_t bdf, unsigned index, uint8_t value)
{
 abort();
}

void pci_write_config_u16(uint16_t bdf, unsigned index, uint16_t value)
{
 abort();
}

void pci_write_config_u32(uint16_t bdf, unsigned index, uint32_t value)
{
 abort();
}


