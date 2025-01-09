/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* font-data.cpp:
**  Copyright (C) 2005-2016 Mednafen Team
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

#include <mednafen/mednafen.h>
#include "font-data.h"

const font5x7 FontData5x7[] =
{
        #include "font5x7.h"
};

const font6x9 FontData6x9[] =
{
	#include "font6x9.h"
};
/*
const font6x10 FontData6x10[] =
{
	#include "font6x10.h"
};
*/
const font6x12 FontData6x12[] =
{
	#include "font6x12.h"
};

const font6x13 FontData6x13[] =
{
	#include "font6x13.h"
};

const font9x18 FontData9x18[] =
{
        #include "font9x18.h"
};


const int FontData5x7_Size = sizeof(FontData5x7);
const int FontData6x9_Size = sizeof(FontData6x9);
//const int FontData6x10_Size = sizeof(FontData6x10);
const int FontData6x12_Size = sizeof(FontData6x12);
const int FontData6x13_Size = sizeof(FontData6x13);
const int FontData9x18_Size = sizeof(FontData9x18);

