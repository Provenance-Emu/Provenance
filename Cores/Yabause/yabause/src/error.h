/*  Copyright 2005-2006 Theo Berkau

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

#ifndef ERROR_H
#define ERROR_H

#define YAB_ERR_UNKNOWN                 0
#define YAB_ERR_FILENOTFOUND            1
#define YAB_ERR_MEMORYALLOC             2
#define YAB_ERR_FILEREAD                3
#define YAB_ERR_FILEWRITE               4
#define YAB_ERR_CANNOTINIT              5

#define YAB_ERR_SH2INVALIDOPCODE        6
#define YAB_ERR_SH2READ                 7
#define YAB_ERR_SH2WRITE                8

#define YAB_ERR_SDL                     9

#define YAB_ERR_OTHER                   10

void YabSetError(int type, const void *extra);
void YabErrorMsg(const char * format, ...);
#endif
