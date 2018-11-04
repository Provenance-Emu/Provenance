/*  Copyright 2016 Guillaume Duhamel

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

#ifndef GAMESINFO_H
#define GAMESINFO_H

typedef struct _GameInfo GameInfo;
struct _GameInfo
{
   char system[17];
   char company[17];
   char itemnum[11];
   char version[7];
   char date[11];
   char cdinfo[9];
   char region[11];
   char peripheral[17];
   char gamename[113];
};

/* Copy part of cdip information info GameInfo. This function
   only works if the emulator is not running, ie: not between
   YabauseInit and YabauseDeInit. */
int GameInfoFromPath(const char * filename, GameInfo * info);

#endif
