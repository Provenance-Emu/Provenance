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

	bios.h

//=========================================================================
//---------------------------------------------------------------------------

  History of changes:
  ===================

20 JUL 2002 - neopop_uk
=======================================
- Cleaned and tidied up for the source release

18 AUG 2002 - neopop_uk
=======================================
- Moved reset() and biosInstall() to neopop.h

//---------------------------------------------------------------------------
*/

#ifndef __NEOPOP_BIOS__
#define __NEOPOP_BIOS__
//=============================================================================

extern uint8 ngpc_bios[0x10000];

void iBIOSHLE(void);

void biosDecode(int function);
void BIOSHLE_Reset(void);
int BIOSHLE_StateAction(StateMem *sm, int load, int data_only);

//=============================================================================
#endif

