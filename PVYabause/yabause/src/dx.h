/*  Copyright 2008 Theo Berkau

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
#ifndef DX_H
#define DX_H

#ifdef __MINGW32__
// I have to do this because for some reason because the dxerr8.h header is fubared
const char*  __stdcall DXGetErrorString8A(HRESULT hr);
#define DXGetErrorString8 DXGetErrorString8A
const char*  __stdcall DXGetErrorDescription8A(HRESULT hr);
#define DXGetErrorDescription8 DXGetErrorDescription8A
#else
#ifndef DXERRH_IS_BROKEN
#include <dxerr9.h>

#define DXGetErrorString8 DXGetErrorString9A 
#define DXGetErrorDescription8 DXGetErrorDescription9A
#else
#include <dxerr.h>

#define DXGetErrorString8 DXGetErrorStringA
#define DXGetErrorDescription8 DXGetErrorDescriptionA

#endif
#endif

#endif
