/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* string.h:
**  Copyright (C) 2007-2018 Mednafen Team
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

#ifndef __MDFN_STRING_STRING_H
#define __MDFN_STRING_STRING_H

namespace Mednafen
{

std::string MDFN_sprintf(const char* format, ...) MDFN_FORMATSTR(gnu_printf, 1, 2);

// Removes whitespace from the beginning of the string.
void MDFN_ltrim(char* s);
void MDFN_ltrim(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_ltrim(const std::string& s);

// Removes whitespace from the end of the string.
void MDFN_rtrim(char* s);
void MDFN_rtrim(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_rtrim(const std::string& s);

// Removes whitespace from the beginning and end of the string.
void MDFN_trim(char* s);
void MDFN_trim(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_trim(const std::string& s);

// Replaces control characters with space(' ') character.
void MDFN_zapctrlchars(char* s);
void MDFN_zapctrlchars(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_zapctrlchars(const std::string& s);

// Replaces A-Z with a-z
void MDFN_strazlower(char* s);
void MDFN_strazlower(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_strazlower(const std::string& s);

// Replaces a-z with A-Z
void MDFN_strazupper(char* s);
void MDFN_strazupper(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_strazupper(const std::string& s);

static INLINE char MDFN_azlower(char c) { return (c >= 'A' && c <= 'Z') ? c - 'A' + 'a' : c; }
static INLINE char MDFN_azupper(char c) { return (c >= 'a' && c <= 'z') ? c - 'a' + 'A' : c; }

static INLINE bool MDFN_isspace(const char c) { return c == ' ' || c == '\f' || c == '\r' || c == '\n' || c == '\t' || c == '\v'; }

int MDFN_strazicmp(const char* s, const char* t, size_t n = SIZE_MAX);
int MDFN_memazicmp(const void* s, const void* t, size_t n);

//
// MDFN_strescape(), MDFN_strunescape(), and MDFN_strargssplit() should not be used to process strings outside of
// Mednafen-specific file formats and Mednafen-specific text IPC protocols, unless the exact behavior makes them suitable.
//
void MDFN_strunescape(std::string* s);
MDFN_WARN_UNUSED_RESULT std::string MDFN_strunescape(const std::string& s);

MDFN_WARN_UNUSED_RESULT std::string MDFN_strescape(const std::string& s);

MDFN_WARN_UNUSED_RESULT std::vector<std::string> MDFN_strsplit(const std::string& str, const std::string& delim = ",");
MDFN_WARN_UNUSED_RESULT std::vector<std::string> MDFN_strargssplit(const std::string& str);
//
//
//
static MDFN_WARN_UNUSED_RESULT INLINE char* MDFN_strskipspace(char* s) { while(MDFN_isspace(*s)) s++; return s; }
static MDFN_WARN_UNUSED_RESULT INLINE const char* MDFN_strskipspace(const char* s) { while(MDFN_isspace(*s)) s++; return s; }

static MDFN_WARN_UNUSED_RESULT INLINE char* MDFN_strskipnonspace(char* s) { while(*s && !MDFN_isspace(*s)) s++; return s; }
static MDFN_WARN_UNUSED_RESULT INLINE const char* MDFN_strskipnonspace(const char* s) { while(*s && !MDFN_isspace(*s)) s++; return s; }

// Don't confuse with number of codepoints.
template<typename T>
static INLINE size_t MDFN_strlen(const T* s) { const T* t = s; while(MDFN_LIKELY(*t)) t++; return t - s; }

MDFN_WARN_UNUSED_RESULT bool UTF8_validate(const char* s, bool permit_utf16_surrogates = false);
MDFN_WARN_UNUSED_RESULT bool UTF8_validate(size_t len, const char* s, bool permit_utf16_surrogates = false);
MDFN_WARN_UNUSED_RESULT bool UTF8_validate(const std::string& s, bool permit_utf16_surrogates = false);

// Will replace bad bytes with '?'
void UTF8_sanitize(char* s, bool permit_utf16_surrogates = false);
void UTF8_sanitize(size_t len, char* s, bool permit_utf16_surrogates = false);
void UTF8_sanitize(std::string* s, bool permit_utf16_surrogates = false);
MDFN_WARN_UNUSED_RESULT std::string UTF8_sanitize(const std::string& s, bool permit_utf16_surrogates = false);

// Will return false if the UTF-8 source string contained invalid UTF-8, but the string will still
// be converted in that case, with each bad byte converted as unicode 0xFFFD.
//
// On input, *dlen is maximum number of elements to write to 'd', and on output
// contains the number of elements written, or that would be written; it's up to the caller
// to handle insufficient space condition(insufficient space can be avoided with *dlen >= slen
// for UTF8->UTF16 and UTF8->UTF32, and *dlen >= (slen * 4) for UTF8->UTF8).
//
bool UTF8_to_UTF8(const char* s, size_t slen, char* d, size_t* dlen, bool permit_utf16_surrogates = false);
bool UTF8_to_UTF16(const char* s, size_t slen, char16_t* d, size_t* dlen, bool permit_utf16_surrogates = false);
bool UTF8_to_UTF32(const char* s, size_t slen, char32_t* d, size_t* dlen, bool permit_utf16_surrogates = false);
std::string UTF8_to_UTF8(const char* s, size_t slen, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false);
std::u16string UTF8_to_UTF16(const char* s, size_t slen, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false);
std::u32string UTF8_to_UTF32(const char* s, size_t slen, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false);
static INLINE std::string UTF8_to_UTF8(const std::string& s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false) { return UTF8_to_UTF8(s.data(), s.size(), invalid_utf8, permit_utf16_surrogates); }
static INLINE std::u16string UTF8_to_UTF16(const std::string& s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false) { return UTF8_to_UTF16(s.data(), s.size(), invalid_utf8, permit_utf16_surrogates); }
static INLINE std::u32string UTF8_to_UTF32(const std::string& s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false) { return UTF8_to_UTF32(s.data(), s.size(), invalid_utf8, permit_utf16_surrogates); }
static INLINE std::u16string UTF8_to_UTF16(const char* s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false) { return UTF8_to_UTF16(s, strlen(s), invalid_utf8, permit_utf16_surrogates); }
static INLINE std::u32string UTF8_to_UTF32(const char* s, bool* invalid_utf8 = nullptr, bool permit_utf16_surrogates = false) { return UTF8_to_UTF32(s, strlen(s), invalid_utf8, permit_utf16_surrogates); }

bool UTF16_to_UTF8(const char16_t* s, size_t slen, char* d, size_t* dlen, bool permit_utf16_surrogates = false);
bool UTF16_to_UTF32(const char16_t* s, size_t slen, char32_t* d, size_t* dlen, bool permit_utf16_surrogates = false);
std::string UTF16_to_UTF8(const char16_t* s, size_t slen, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false);
std::u32string UTF16_to_UTF32(const char16_t* s, size_t slen, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false);
static INLINE std::string UTF16_to_UTF8(const std::u16string& s, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false) { return UTF16_to_UTF8(s.data(), s.size(), invalid_utf16, permit_utf16_surrogates); }
static INLINE std::u32string UTF16_to_UTF32(const std::u16string& s, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false) { return UTF16_to_UTF32(s.data(), s.size(), invalid_utf16, permit_utf16_surrogates); }
static INLINE std::string UTF16_to_UTF8(const char16_t* s, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false) { return UTF16_to_UTF8(s, MDFN_strlen(s), invalid_utf16, permit_utf16_surrogates); }
static INLINE std::u32string UTF16_to_UTF32(const char16_t* s, bool* invalid_utf16 = nullptr, bool permit_utf16_surrogates = false) { return UTF16_to_UTF32(s, MDFN_strlen(s), invalid_utf16, permit_utf16_surrogates); }

bool UTF32_to_UTF8(const char32_t* s, size_t slen, char* d, size_t* dlen, bool permit_utf16_surrogates = false);
bool UTF32_to_UTF16(const char32_t* s, size_t slen, char16_t* d, size_t* dlen, bool permit_utf16_surrogates = false);
std::string UTF32_to_UTF8(const char32_t* s, size_t slen, bool* invalid_utf32 = nullptr, bool permit_utf16_surrogates = false);
std::u16string UTF32_to_UTF16(const char32_t* s, size_t slen, bool* invalid_utf32 = nullptr, bool permit_utf16_surrogates = false);
static INLINE std::string UTF32_to_UTF8(const std::u32string& s, bool* invalid_utf32 = nullptr, bool permit_utf16_surrogates = false) { return UTF32_to_UTF8(s.data(), s.size(), invalid_utf32, permit_utf16_surrogates); }
static INLINE std::u16string UTF32_to_UTF16(const std::u32string& s, bool* invalid_utf32 = nullptr, bool permit_utf16_surrogates = false) { return UTF32_to_UTF16(s.data(), s.size(), invalid_utf32, permit_utf16_surrogates); }
static INLINE std::string UTF32_to_UTF8(const char32_t* s, bool* invalid_utf32 = nullptr, bool permit_utf16_surrogates = false) { return UTF32_to_UTF8(s, MDFN_strlen(s), invalid_utf32, permit_utf16_surrogates); }
static INLINE std::u16string UTF32_to_UTF16(const char32_t* s, bool* invalid_utf32 = nullptr, bool permit_utf16_surrogates = false) { return UTF32_to_UTF16(s, MDFN_strlen(s), invalid_utf32, permit_utf16_surrogates); }

}
#endif
