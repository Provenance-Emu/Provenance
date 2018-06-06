/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* dos_common.h:
**  Copyright (C) 2014-2016 Mednafen Team
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

#ifndef __SEXYAL_DRIVERS_DOS_COMMON_H
#define __SEXYAL_DRIVERS_DOS_COMMON_H

#include "../sexyal.h"
#include <math.h>
#include <dos.h>
#include <dpmi.h>
#include <go32.h>
#include <sys/farptr.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

typedef uint8 uint8;
typedef uint16 uint16;
typedef uint32 uint32;
typedef uint64 uint64;

struct pci_vd_pair
{
 uint16 vendor;
 uint16 device;
};

bool pci_bios_present(void);
bool pci_find_device(uint16 vend_id, uint16 dev_id, uint16 index, uint16* bdf);
pci_vd_pair* pci_find_device(pci_vd_pair* pci_ids, uint32 index, uint16* bdf);	// Terminate list with { 0 } 

uint8 pci_read_config_u8(uint16 bdf, unsigned index);
uint16 pci_read_config_u16(uint16 bdf, unsigned index);
uint32 pci_read_config_u32(uint16 bdf, unsigned index);

void pci_write_config_u8(uint16 bdf, unsigned index, uint8 value);
void pci_write_config_u16(uint16 bdf, unsigned index, uint16 value);
void pci_write_config_u32(uint16 bdf, unsigned index, uint32 value);

#endif
