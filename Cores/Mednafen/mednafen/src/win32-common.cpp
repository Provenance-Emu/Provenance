/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* win32-common.cpp:
**  Copyright (C) 2012-2018 Mednafen Team
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
#include <mednafen/win32-common.h>

namespace Mednafen
{
namespace Win32Common
{
//
//
std::string ErrCodeToString(uint32 errcode)
{
 std::string ret;
 void* msg_buffer = NULL;
 unsigned int tchar_count;

 tchar_count = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	       		     NULL, errcode,
		             MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
               		     (LPWSTR)&msg_buffer, 0, NULL);

 if(tchar_count == 0)
  return "FormatMessageW() Error";

 try
 {
  ret = UTF16_to_UTF8((char16_t*)msg_buffer, tchar_count);
 }
 catch(...)
 {
  LocalFree(msg_buffer);
  throw;
 }
 LocalFree(msg_buffer);
 return ret;
}

//
//
}
}
