/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* font-data-18x18.c:
**  Copyright (C) 2006-2016 Mednafen Team
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
        uint8_t data[18 * 3];
} font18x18;

const font18x18 FontData18x18[]=
{
	#ifdef WANT_INTERNAL_CJK
        #include "font18x18ko.h"
	#else

	#endif
};

const int FontData18x18_Size = sizeof(FontData18x18);

