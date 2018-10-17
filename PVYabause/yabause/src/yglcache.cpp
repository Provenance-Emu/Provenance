/*
Copyright 2011-2015 Shinya Miyamoto(devmiyax)

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#ifdef HAVE_LIBGL

extern "C" {
#include "ygl.h"
#include "yui.h"
#include "vidshared.h"
}

#ifdef _WINDOWS
#include <hash_map>
using std::hash_map;
#else
#include <ext/hash_map>
using __gnu_cxx::hash_map;
#endif

hash_map< u32 , YglCache > g_TexHash;

extern "C" {

void YglCacheInit() {
}

//////////////////////////////////////////////////////////////////////////////

void YglCacheDeInit() {
}

//////////////////////////////////////////////////////////////////////////////

int YglIsCached(u32 addr, YglCache * c ) {

  hash_map< u32 , YglCache >::iterator pos =  g_TexHash.find(addr);
  if( pos == g_TexHash.end() )
  {
      return 0;
  }

  c->x=pos->second.x;
  c->y=pos->second.y;

  return 1;
}

//////////////////////////////////////////////////////////////////////////////

void YglCacheAdd(u32 addr, YglCache * c) {

   g_TexHash[addr] = *c;
}

//////////////////////////////////////////////////////////////////////////////

void YglCacheReset(void) {
   g_TexHash.clear();
}


}

#endif
