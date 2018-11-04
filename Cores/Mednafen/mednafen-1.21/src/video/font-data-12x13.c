/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* font-data-12x13.c:
**  Copyright (C) 2007-2016 Mednafen Team
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

//#include "../mednafen.h"
//#include "font-data.h"

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <inttypes.h>

typedef struct
{
        uint16_t glyph_num;
        uint8_t data[13 * 2];
} font12x13;

const font12x13 FontData12x13[]=
{
	#ifdef WANT_INTERNAL_CJK
        #include "font12x13ja.h"
	#else

	#endif
};

const int FontData12x13_Size = sizeof(FontData12x13);

