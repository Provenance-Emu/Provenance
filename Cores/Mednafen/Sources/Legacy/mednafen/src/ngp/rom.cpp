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

#include "neopop.h"
#include "flash.h"
#include "interrupt.h"

//=============================================================================

namespace MDFN_IEN_NGP
{

RomInfo ngpc_rom;
RomHeader* rom_header;

#define MATCH_CATALOG(c, s)	(MDFN_de16lsb(rom_header->catalog) == (c) && rom_header->subCatalog == (s))

//=============================================================================
static void rom_hack(void)
{
	//=============================
	// SPECIFIC ROM HACKS !
	//=============================

	//"Neo-Neo! V1.0 (PD)"
	if (MATCH_CATALOG(0, 16))
	{
		ngpc_rom.data[0x23] = 0x10;	// Fix rom header

		MDFN_printf("HACK: \"Neo-Neo! V1.0 (PD)\"\n");
	}

	//"Cool Cool Jam SAMPLE (U)"
	if (MATCH_CATALOG(4660, 161))
	{
		ngpc_rom.data[0x23] = 0x10;	// Fix rom header

		MDFN_printf("HACK: \"Cool Cool Jam SAMPLE (U)\"\n");
	}

	//"Dokodemo Mahjong (J)"
	if (MATCH_CATALOG(51, 33))
	{
		ngpc_rom.data[0x23] = 0x00;	// Fix rom header

		MDFN_printf("HACK: \"Dokodemo Mahjong (J)\"\n");
	}
}

//=============================================================================

static void rom_display_header(void)
{
	MDFN_printf(_("Name:    %s\n"), ngpc_rom.name);
	MDFN_printf(_("System:  "));

	if(rom_header->mode & 0x10)
	 MDFN_printf(_("Color"));
	else
	 MDFN_printf(_("Greyscale"));

	MDFN_printf("\n");

        MDFN_printf(_("Catalog:  %u (sub %u)\n"),
                             MDFN_de16lsb(rom_header->catalog),
                             rom_header->subCatalog);

        //Starting PC
        MDFN_printf(_("Starting PC:  0x%06X\n"), MDFN_de32lsb(rom_header->startPC) & 0xFFFFFF);
}

//=============================================================================

//-----------------------------------------------------------------------------
// rom_loaded()
//-----------------------------------------------------------------------------
void rom_loaded(void)
{
	//Extract the header
	rom_header = (RomHeader*)(ngpc_rom.data);

	//Rom Name
	for(int i = 0; i < 12; i++)
	{
		if (rom_header->name[i] >= 32 && rom_header->name[i] < 128)
			ngpc_rom.name[i] = rom_header->name[i];
		else
			ngpc_rom.name[i] = ' ';
	}
	ngpc_rom.name[12] = 0;

	rom_hack();	//Apply a hack if required!

	rom_display_header();

	ngpc_rom.orig_data = new uint8[ngpc_rom.length];
	memcpy(ngpc_rom.orig_data, ngpc_rom.data, ngpc_rom.length);
}

//-----------------------------------------------------------------------------
// rom_unload()
//-----------------------------------------------------------------------------
void rom_unload(void)
{
 if(ngpc_rom.data)
 {
	delete[] ngpc_rom.data;
	ngpc_rom.data = NULL;
	ngpc_rom.length = 0;
	rom_header = 0;

	for(int i = 0; i < 16; i++)
	 ngpc_rom.name[i] = 0;
 }		

 if(ngpc_rom.orig_data)
 {
  	delete[] ngpc_rom.orig_data;
  	ngpc_rom.orig_data = NULL;
 }
}

}

//=============================================================================
