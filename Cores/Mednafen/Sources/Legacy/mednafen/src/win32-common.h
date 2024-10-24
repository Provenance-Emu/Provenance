/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* win32-common.h:
**  Copyright (C) 2018-2020 Mednafen Team
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

#ifndef __MDFN_WIN32_COMMON_H
#define __MDFN_WIN32_COMMON_H

#include <windows.h>
#include <io.h>
#include <process.h>
#include <direct.h>
#include <tchar.h>

#include <mednafen/string/string.h>

namespace Mednafen
{
 namespace Win32Common
 {
  std::string ErrCodeToString(uint32 errcode, HMODULE mod = NULL);

  // Throws on error
  FARPROC GetProcAddress_TOE(HMODULE, LPCSTR, bool error_on_pnf = false);
  HMODULE GetModuleHandle_TOE(LPCTSTR);

#ifdef UNICODE
  static_assert(sizeof(wchar_t) == sizeof(char16_t), "");

  static INLINE std::string T_to_UTF8(const wchar_t* s, size_t slen, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false)
  {
   return UTF16_to_UTF8((char16_t*)s, slen, invalid_utf16, permit_utf16_surrogates);
  }

  static INLINE std::string T_to_UTF8(const wchar_t* s, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false)
  {
   return UTF16_to_UTF8((char16_t*)s, invalid_utf16, permit_utf16_surrogates);
  }
  //
  //
  //
  static INLINE std::u16string UTF8_to_T(const std::string& s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false)
  {
   return UTF8_to_UTF16(s, invalid_utf8, permit_utf16_surrogates);
  }

  static INLINE std::u16string UTF8_to_T(const char* s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false)
  {
   return UTF8_to_UTF16(s, invalid_utf8, permit_utf16_surrogates);
  }
#else
  std::string T_to_UTF8(const char* s, size_t slen, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false);
  static INLINE std::string T_to_UTF8(const char* s, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false)
  {
   return T_to_UTF8(s, strlen(s), invalid_utf16, permit_utf16_surrogates);
  }
  //
  //
  //
  std::string UTF8_to_T(const char* s, size_t slen, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false);

  static INLINE std::string UTF8_to_T(const std::string& s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false)
  {
   return UTF8_to_T(s.data(), s.size(), invalid_utf8, permit_utf16_surrogates);
  }

  static INLINE std::string UTF8_to_T(const char* s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false)
  {
   return UTF8_to_T(s, strlen(s), invalid_utf8, permit_utf16_surrogates);
  }
#endif
 }
}
#endif
