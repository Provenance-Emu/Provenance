/*
* Glide64 - Glide video plugin for Nintendo 64 emulators.
* Copyright (c) 2002  Dave2001
* Copyright (c) 2003-2009  Sergey 'Gonetz' Lipski
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

//****************************************************************
//
// Glide64 - Glide Plugin for Nintendo 64 emulators
// Project started on December 29th, 2001
//
// Authors:
// Dave2001, original author, founded the project in 2001, left it in 2002
// Gugaman, joined the project in 2002, left it in 2002
// Sergey 'Gonetz' Lipski, joined the project in 2002, main author since fall of 2002
// Hiroshi 'KoolSmoky' Morii, joined the project in 2007
//
//****************************************************************
//
// To modify Glide64:
// * Write your name and (optional)email, commented by your work, so I know who did it, and so that you can find which parts you modified when it comes time to send it to me.
// * Do NOT send me the whole project or file that you modified.  Take out your modified code sections, and tell me where to put them.  If people sent the whole thing, I would have many different versions, but no idea how to combine them all.
//
//****************************************************************
//
// Keys, used by Glide64. 
// Since key codes are different for WinAPI and SDL, this difference is managed here
// Created by Sergey 'Gonetz' Lipski, July 2009
//
//****************************************************************

#include "Platform.h"
#include "Keys.h"
#ifndef MUPENPLUSAPI
#include "windows/GLideN64_windows.h"
#endif

Glide64Keys::Glide64Keys()
{
#ifdef OS_WINDOWS
m_keys[G64_VK_CONTROL] = 0x11;
m_keys[G64_VK_ALT]     = 0x12;
m_keys[G64_VK_INSERT]  = 0x2D;
m_keys[G64_VK_LBUTTON] = 0x01;
m_keys[G64_VK_UP]      = 0x26;
m_keys[G64_VK_DOWN]    = 0x28;
m_keys[G64_VK_LEFT]    = 0x25;
m_keys[G64_VK_RIGHT]   = 0x27;
m_keys[G64_VK_SPACE]   = 0x20;
m_keys[G64_VK_BACK]    = 0x08;
m_keys[G64_VK_SCROLL]  = 0x91;
m_keys[G64_VK_1]       = 0x31;
m_keys[G64_VK_2]       = 0x32;
m_keys[G64_VK_3]       = 0x33;
m_keys[G64_VK_4]       = 0x34;
m_keys[G64_VK_5]       = 0x35;
m_keys[G64_VK_6]       = 0x36;
m_keys[G64_VK_7]       = 0x37;
m_keys[G64_VK_8]       = 0x38;
m_keys[G64_VK_9]       = 0x39;
m_keys[G64_VK_0]       = 0x30;
m_keys[G64_VK_A]       = 0x41;
m_keys[G64_VK_B]       = 0x42;
m_keys[G64_VK_D]       = 0x44;
m_keys[G64_VK_F]       = 0x46;
m_keys[G64_VK_G]       = 0x47;
m_keys[G64_VK_Q]       = 0x51;
m_keys[G64_VK_R]       = 0x52;
m_keys[G64_VK_S]       = 0x53;
m_keys[G64_VK_V]       = 0x56;
m_keys[G64_VK_W]       = 0x57;
#else
m_keys[G64_VK_CONTROL] = 306;
m_keys[G64_VK_ALT]     = 308;
m_keys[G64_VK_INSERT]  = 277;
m_keys[G64_VK_LBUTTON] =   1;
m_keys[G64_VK_UP]      = 273;
m_keys[G64_VK_DOWN]    = 274;
m_keys[G64_VK_LEFT]    = 276;
m_keys[G64_VK_RIGHT]   = 275;
m_keys[G64_VK_SPACE]   =  32;
m_keys[G64_VK_BACK]    =   8;
m_keys[G64_VK_SCROLL]  = 302;
m_keys[G64_VK_1]       =  49;
m_keys[G64_VK_2]       =  50;
m_keys[G64_VK_3]       =  51;
m_keys[G64_VK_4]       =  52;
m_keys[G64_VK_5]       =  53;
m_keys[G64_VK_6]       =  54;
m_keys[G64_VK_7]       =  55;
m_keys[G64_VK_8]       =  56;
m_keys[G64_VK_9]       =  57;
m_keys[G64_VK_0]       =  48;
m_keys[G64_VK_A]       =  97;
m_keys[G64_VK_B]       =  98;
m_keys[G64_VK_D]       = 100;
m_keys[G64_VK_F]       = 102;
m_keys[G64_VK_G]       = 103;
m_keys[G64_VK_Q]       = 113;
m_keys[G64_VK_R]       = 114;
m_keys[G64_VK_S]       = 115;
m_keys[G64_VK_V]       = 118;
m_keys[G64_VK_W]       = 119;
#endif
}

bool isKeyPressed(int _key, int _mask)
{
	static Glide64Keys g64Keys;
#ifdef OS_WINDOWS
#ifdef MUPENPLUSAPI
	return (GetAsyncKeyState(g64Keys[_key]) & _mask) != 0;
#else
	return (GetAsyncKeyState(g64Keys[_key]) & _mask) != 0 && GetForegroundWindow() == hWnd;
#endif
#else
	// TODO
#endif
	return 0;
}
