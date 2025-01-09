//---------------------------------------------------------------------------
// NEOPOP : Emulator as in Dreamland
//
// Copyright (c) 2001-2002 by neopop_uk
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	This program is free software; you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation; either version 2 of the License, or
//	(at your option) any later version. See also the license.txt file for
//	additional informations.
//---------------------------------------------------------------------------

#ifndef __NEOPOP_MEM__
#define __NEOPOP_MEM__
//=============================================================================

namespace MDFN_IEN_NGP
{

#define ROM_START	0x200000
#define ROM_END		0x3FFFFF

#define HIROM_START	0x800000
#define HIROM_END	0x9FFFFF

#define BIOS_START	0xFF0000
#define BIOS_END	0xFFFFFF

void reset_memory(void);

void dump_memory(uint32 start, uint32 length);

MDFN_HIDE extern uint8 CPUExRAM[16384];

MDFN_HIDE extern bool debug_abort_memory;
MDFN_HIDE extern bool debug_mask_memory_error_messages;

MDFN_HIDE extern bool memory_unlock_flash_write;
MDFN_HIDE extern bool memory_flash_error;
MDFN_HIDE extern bool memory_flash_command;

MDFN_HIDE extern bool FlashStatusEnable;
MDFN_HIDE extern uint8 COMMStatus;

//=============================================================================

MDFN_FASTCALL uint8  loadB(uint32 address);
MDFN_FASTCALL uint16 loadW(uint32 address);
MDFN_FASTCALL uint32 loadL(uint32 address);

MDFN_FASTCALL void storeB(uint32 address, uint8 data);
MDFN_FASTCALL void storeW(uint32 address, uint16 data);
MDFN_FASTCALL void storeL(uint32 address, uint32 data);

void SetFRM(void);
void RecacheFRM(void);

}

//=============================================================================
#endif
