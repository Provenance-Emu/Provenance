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

/*
//---------------------------------------------------------------------------
//=========================================================================

	dma.c

//=========================================================================
//---------------------------------------------------------------------------

  History of changes:
  ===================

20 JUL 2002 - neopop_uk
=======================================
- Cleaned and tidied up for the source release

25 JUL 2002 - neopop_uk
=======================================
- Removed incorrect quick-fix code and added new DMA_update functions
	to process the dma values.
- Fixed setting of C and M registers
- Added source copy byte and word mode DMA, seems to be only ones used.

26 JUL 2002 - neopop_uk
=======================================
- Added more DMA modes - "Kikouseki Unitron (J)" uses counter mode
	and 4 byte memory to I/O transfer.
- Added load *from* dma control register.

30 JUL 2002 - neopop_uk
=======================================
- Made DMA_update more secure in it's ability to detect unknown DMA modes.
- DMA mode and count are printed in decimal, for internal consistancy.

01 AUG 2002 - neopop_uk
=======================================
- Re-written DMA_update for clarity, and added missing modes,
	fixes "Super Real Mahjong"

//---------------------------------------------------------------------------
*/

#include "neopop.h"
#include "dma.h"
#include "mem.h"
#include "interrupt.h"

//=============================================================================

static uint32 dmaS[4], dmaD[4];
static uint16 dmaC[4];
static uint8 dmaM[4];

//=============================================================================

void reset_dma(void)
{
	memset(dmaS, 0, sizeof(dmaS));
	memset(dmaD, 0, sizeof(dmaD));
	memset(dmaC, 0, sizeof(dmaC));
	memset(dmaM, 0, sizeof(dmaM));
}

//=============================================================================

void DMA_update(int channel)
{
	uint8 mode = (dmaM[channel] & 0x1C) >> 2;
	uint8 size = (dmaM[channel] & 0x03);			//byte, word or long

	// Correct?
	if (dmaC[channel] == 0)
		return;

	switch (mode)
	{
	case 0:	// Destination INC mode, I/O to Memory transfer
		switch(size)
		{
		case 0:	storeB(dmaD[channel], loadB(dmaS[channel]));
				dmaD[channel] += 1; //Byte increment
				break;

		case 1:	storeW(dmaD[channel], loadW(dmaS[channel]));
				dmaD[channel] += 2; //Word increment
				break;

		case 2:	storeL(dmaD[channel], loadL(dmaS[channel]));
				dmaD[channel] += 4; //Long increment
				break;
		}
		break;

	case 1:	// Destination DEC mode, I/O to Memory transfer
		switch(size)
		{
		case 0:	storeB(dmaD[channel], loadB(dmaS[channel]));
				dmaD[channel] -= 1; //Byte decrement
				break;

		case 1:	storeW(dmaD[channel], loadW(dmaS[channel]));
				dmaD[channel] -= 2; //Word decrement
				break;

		case 2:	storeL(dmaD[channel], loadL(dmaS[channel]));
				dmaD[channel] -= 4; //Long decrement
				break;
		}
		break;

	case 2:	// Source INC mode, Memory to I/O transfer
		switch(size)
		{
		case 0:	storeB(dmaD[channel], loadB(dmaS[channel]));
				dmaS[channel] += 1; //Byte increment
				break;

		case 1:	storeW(dmaD[channel], loadW(dmaS[channel]));
				dmaS[channel] += 2; //Word increment
				break;

		case 2:	storeL(dmaD[channel], loadL(dmaS[channel]));
				dmaS[channel] += 4; //Long increment
				break;
		}
		break;

	case 3:	// Source DEC mode, Memory to I/O transfer
		switch(size)
		{
		case 0:	storeB(dmaD[channel], loadB(dmaS[channel]));
				dmaS[channel] -= 1; //Byte decrement
				break;

		case 1:	storeW(dmaD[channel], loadW(dmaS[channel]));
				dmaS[channel] -= 2; //Word decrement
				break;

		case 2:	storeL(dmaD[channel], loadL(dmaS[channel]));
				dmaS[channel] -= 4; //Long decrement
				break;
		}
		break;

	case 4:	// Fixed Address Mode
		switch(size)
		{
		case 0:	storeB(dmaD[channel], loadB(dmaS[channel]));
				break;

		case 1:	storeW(dmaD[channel], loadW(dmaS[channel]));
				break;

		case 2:	storeL(dmaD[channel], loadL(dmaS[channel]));
				break;
		}
		break;

	case 5: // Counter Mode
		dmaS[channel] ++;
		break;

	default:
		MDFN_printf("Bad DMA mode %d\nPlease report this to the author.", dmaM[channel]);
		return;
	}

	// Perform common counter decrement,
	// vector clearing, and interrupt handling.

	dmaC[channel] --;
	if (dmaC[channel] == 0)
	{
		interrupt(14 + channel);
		storeB(0x7C + channel, 0);
	}
}

//=============================================================================

void dmaStoreB(uint8 cr, uint8 data)
{
	switch(cr)
	{
	case 0x22:	dmaM[0] = data;	break;
	case 0x26:	dmaM[1] = data;	break;
	case 0x2A:	dmaM[2] = data;	break;
	case 0x2E:	dmaM[3] = data;	break;

	default: 
		MDFN_printf("dmaStoreB: Unknown register 0x%02X <- %02X\nPlease report this to the author.\n", cr, data);
		break;
	}
}

void dmaStoreW(uint8 cr, uint16 data)
{
	switch(cr)
	{
	case 0x20:	dmaC[0] = data;	break;
	case 0x24:	dmaC[1] = data;	break;
	case 0x28:	dmaC[2] = data;	break;
	case 0x2C:	dmaC[3] = data;	break;

	default: 
		MDFN_printf("dmaStoreW: Unknown register 0x%02X <- %04X\nPlease report this to the author.\n", cr, data);
		break;
	}
}

void dmaStoreL(uint8 cr, uint32 data)
{
	switch(cr)
	{
	case 0x00: dmaS[0] = data; break;	
	case 0x04: dmaS[1] = data; break;	
	case 0x08: dmaS[2] = data; break;	
	case 0x0C: dmaS[3] = data; break;	

	case 0x10: dmaD[0] = data; break;	
	case 0x14: dmaD[1] = data; break;	
	case 0x18: dmaD[2] = data; break;	
	case 0x1C: dmaD[3] = data; break;

	default: 
		MDFN_printf("dmaStoreL: Unknown register 0x%02X <- %08X\nPlease report this to the author.\n", cr, data);
		break;
	}
}

//=============================================================================

uint8 dmaLoadB(uint8 cr)
{

	switch(cr)
	{
	case 0x22:	return dmaM[0];	break;
	case 0x26:	return dmaM[1];	break;
	case 0x2A:	return dmaM[2];	break;
	case 0x2E:	return dmaM[3];	break;

	default: 
		MDFN_printf("dmaLoadB: Unknown register 0x%02X\nPlease report this to the author.", cr);
		return 0;
	}
}

uint16 dmaLoadW(uint8 cr)
{
	switch(cr)
	{
	case 0x20:	return dmaC[0];	break;
	case 0x24:	return dmaC[1];	break;
	case 0x28:	return dmaC[2];	break;
	case 0x2C:	return dmaC[3];	break;

	default: 
		MDFN_printf("dmaLoadW: Unknown register 0x%02X\nPlease report this to the author.", cr);
		return 0;
	}
}

uint32 dmaLoadL(uint8 cr)
{
	switch(cr)
	{
	case 0x00: return dmaS[0]; break;	
	case 0x04: return dmaS[1]; break;	
	case 0x08: return dmaS[2]; break;	
	case 0x0C: return dmaS[3]; break;	

	case 0x10: return dmaD[0]; break;	
	case 0x14: return dmaD[1]; break;	
	case 0x18: return dmaD[2]; break;	
	case 0x1C: return dmaD[3]; break;

	default: 
		MDFN_printf("dmaLoadL: Unknown register 0x%02X\nPlease report this to the author.", cr);
		return 0;
	}
}

int MDFNNGPCDMA_StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFARRAY32N(dmaS, 4, "DMAS"),
  SFARRAY32N(dmaD, 4, "DMAD"),
  SFARRAY16N(dmaC, 4, "DMAC"),
  SFARRAYN(dmaM, 4, "DMAM"),
  SFEND
 };

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, "DMA"))
  return(0);

 return(1); 
}
