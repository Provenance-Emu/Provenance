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

FARPROC GetProcAddress_TOE(HMODULE mod, LPCSTR name, bool error_on_pnf)
{
 FARPROC ret;

 if(!(ret = GetProcAddress(mod, name)))
 {
  const uint32 ec = GetLastError();

  if(ec == ERROR_PROC_NOT_FOUND && !error_on_pnf)
   return NULL;

  throw MDFN_Error(0, _("GetProcAddress(..., \"%s\") failed: %s"), name, ErrCodeToString(ec).c_str());
 }

 return ret;
}

HMODULE GetModuleHandle_TOE(LPCTSTR name)
{
 HMODULE ret;

 if(!(ret = GetModuleHandle(name)))
 {
  const uint32 ec = GetLastError();

  throw MDFN_Error(0, _("GetModuleHandle(\"%s\") failed: %s"), T_to_UTF8(name).c_str(), ErrCodeToString(ec).c_str());
 }

 return ret;
}

std::string ErrCodeToString(uint32 errcode, HMODULE mod)
{
 std::string ret;
 void* msg_buffer = NULL;
 unsigned int tchar_count;

 tchar_count = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | (mod ? FORMAT_MESSAGE_FROM_HMODULE : 0) | FORMAT_MESSAGE_IGNORE_INSERTS,
	       		     mod, errcode,
		             MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
               		     (LPTSTR)&msg_buffer, 0, NULL);

 if(tchar_count == 0)
  return "FormatMessage() Error";

 try
 {
  ret = T_to_UTF8((TCHAR*)msg_buffer, tchar_count);
 }
 catch(...)
 {
  LocalFree(msg_buffer);
  throw;
 }
 LocalFree(msg_buffer);
 return ret;
}

#ifndef UNICODE
// TODO!

std::string T_to_UTF8(const char* s, size_t slen, bool* invalid_utf16, bool permit_utf16_surrogates)
{
 if(invalid_utf16)
  *invalid_utf16 = false;

 return std::string(s, slen);
}

std::string UTF8_to_T(const char* s, size_t slen, bool* invalid_utf8, bool permit_utf16_surrogates)
{
 if(invalid_utf8)
  *invalid_utf8 = false;

 return std::string(s, slen);
/*
 std::u16string tmp = UTF8_to_UTF16(s, slen, invalid_utf8, permit_utf16_surrogates);
 std::string ret;
 unsigned req_size = WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, s, slen, NULL, 0);

 if(slen && !)
 {

 }
*/
}
#endif

//
//
}
}
