/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Deinterlacer.cpp:
**  Copyright (C) 2011-2018 Mednafen Team
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

#include "video-common.h"
#include "Deinterlacer.h"
#include "Deinterlacer_Simple.h"
#include "Deinterlacer_Blend.h"

namespace Mednafen
{

Deinterlacer::Deinterlacer() { }
Deinterlacer::~Deinterlacer() { }

Deinterlacer* Deinterlacer::Create(unsigned type)
{
 if(type == DEINT_BLEND || type == DEINT_BLEND_RG)
  return new Deinterlacer_Blend(type == DEINT_BLEND_RG);
 else
  return new Deinterlacer_Simple(type);
}

}
