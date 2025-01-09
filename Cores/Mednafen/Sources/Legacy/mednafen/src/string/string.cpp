/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* string.cpp:
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

// TODO: How to handle di/dlen overflow in UTF conversion functions?

// If using a codepoint other than 0xFFFD for bad bytes, remember to adjust the string buffer
// allocation multipliers in the *_to_UTF8() and *_to_UTF16() functions.

#include <mednafen/mednafen.h>
#include "string.h"

#include <trio/trio.h>

namespace Mednafen
{

static int AppendSS(void* data, int c)
{
 std::string* ss = (std::string*)data;

 ss->push_back(c);

 return 1;
}

std::string MDFN_sprintf(const char* format, ...)
{
 std::string ret;
 va_list ap;

 ret.reserve(64);

 va_start(ap, format);
 trio_vcprintf(AppendSS, &ret, format, ap);
 va_end(ap);

 return ret;
}

// Remove whitespace from beginning of s
void MDFN_ltrim(char* s)
{
 const char* si = s;
 char* di = s;
 bool InWhitespace = true;

 while(*si)
 {
  if(!InWhitespace || !MDFN_isspace(*si))
  {
   InWhitespace = false;
   *di = *si;
   di++;
  }
  si++;
 }

 *di = 0;
}

// Remove whitespace from beginning of s
void MDFN_ltrim(std::string* s)
{
 const size_t len = s->length();
 size_t di = 0, si = 0;
 bool InWhitespace = true;

 while(si < len)
 {
  if(!InWhitespace || !MDFN_isspace((*s)[si]))
  {
   InWhitespace = false;
   (*s)[di] = (*s)[si];
   di++;
  }
  si++;
 }

 s->resize(di);
}

std::string MDFN_ltrim(const std::string& s)
{
 std::string ret = s;

 MDFN_ltrim(&ret);

 return ret;
}

// Remove whitespace from end of s
void MDFN_rtrim(char* s)
{
 const size_t len = strlen(s);

 if(!len)
  return;
 //
 size_t x = len;

 do
 {
  x--;

  if(!MDFN_isspace(s[x]))
   break;
 
  s[x] = 0;
 } while(x);
}

// Remove whitespace from end of s
void MDFN_rtrim(std::string* s)
{
 const size_t len = s->length();

 if(!len)
  return;
 //
 size_t x = len;
 size_t new_len = len;

 do
 {
  x--;

  if(!MDFN_isspace((*s)[x]))
   break;
 
  new_len--;
 } while(x);

 s->resize(new_len);
}

std::string MDFN_rtrim(const std::string& s)
{
 std::string ret = s;

 MDFN_rtrim(&ret);

 return ret;
}

void MDFN_trim(char* s)
{
 MDFN_rtrim(s);
 MDFN_ltrim(s);
}

void MDFN_trim(std::string* s)
{
 MDFN_rtrim(s);
 MDFN_ltrim(s);
}

std::string MDFN_trim(const std::string& s)
{
 std::string ret = s;

 MDFN_trim(&ret);

 return ret;
}

void MDFN_zapctrlchars(char* s)
{
 if(!s)
  return;

 while(*s)
 {
  if((unsigned char)*s < 0x20)
   *s = ' ';

  s++;
 }
}

void MDFN_zapctrlchars(std::string* s)
{
 for(auto& c : *s)
  if((unsigned char)c < 0x20)
   c = ' ';
}

std::string MDFN_zapctrlchars(const std::string& s)
{
 std::string ret = s;

 MDFN_zapctrlchars(&ret);

 return ret;
}

void MDFN_strazlower(char* s)
{
 while(*s)
 {
  *s = MDFN_azlower(*s);
  s++;
 }
}

void MDFN_strazlower(std::string* s)
{
 for(auto& c : *s)
  c = MDFN_azlower(c);
}

std::string MDFN_strazlower(const std::string& s)
{
 std::string ret = s;

 MDFN_strazlower(&ret);

 return ret;
}

void MDFN_strazupper(char* s)
{
 while(*s)
 {
  *s = MDFN_azupper(*s);
  s++;
 }
}

void MDFN_strazupper(std::string* s)
{
 for(auto& c : *s)
  c = MDFN_azupper(c);
}

std::string MDFN_strazupper(const std::string& s)
{
 std::string ret = s;

 MDFN_strazupper(&ret);

 return ret;
}

int MDFN_strazicmp(const char* s, const char* t, size_t n)
{
 if(!n)
  return 0;

 do
 {
  const int d = (unsigned char)MDFN_azlower(*s) - (unsigned char)MDFN_azlower(*t);

  if(d)
   return d;

 } while(*s++ && *t++ && --n);

 return 0;
}

int MDFN_memazicmp(const void* s, const void* t, size_t n)
{
 unsigned char* a = (unsigned char*)s;
 unsigned char* b = (unsigned char*)t;

 while(n--)
 {
  const int d = (unsigned char)MDFN_azlower(*a++) - (unsigned char)MDFN_azlower(*b++);

  if(d)
   return d;
 }

 return 0;
}

std::vector<std::string> MDFN_strsplit(const std::string& str, const std::string& delim)
{
 std::vector<std::string> ret;
 size_t bpos = 0;

 for(;;)
 {
  size_t spos = str.find_first_not_of(delim, bpos);
  bpos = str.find_first_of(delim, spos);

  if(spos == bpos)
   break;

  ret.push_back(str.substr(spos, bpos - spos));
 }

 return ret;
}

void MDFN_strunescape(std::string* s)
{
 std::string& str = *s;
 std::string ret;
 size_t di = 0;
 bool in_escape = false;
 unsigned in_octal = 0;
 unsigned in_hex = 0;
 unsigned hv = 0;

 for(size_t i = 0; i < str.size(); i++)
 {
  if(in_octal)
  {
   if(str[i] >= '0' && str[i] <= '7')
   {
    hv *= 8;
    hv += str[i] - '0';
    in_octal--;
   }
   else
    in_octal = 0;

   if(!in_octal || (i + 1) == str.size())
    str[di++] = hv;
  }
  else if(in_hex)
  {
   char lc = MDFN_azlower(str[i]);

   if((lc >= '0' && lc <= '9') || (lc >= 'a' && lc <= 'f'))
   {
    hv <<= 4;
    hv += (lc >= '0' && lc <= '9') ? (lc - '0') : (lc - 'a' + 0xA);
    in_hex--;
   }
   else
    in_hex = 0;

   if(!in_hex)
    str[di++] = hv;
  }
  else if(in_escape)
  {
   if(str[i] >= '0' && str[i] <= '7')
   {
    in_octal = 2;
    hv = str[i] - '0';
   }
   else
   {
    in_escape = false;

    if(str[i] == 'x')
    {
     in_hex = 2;
     hv = 0;
    }
    else if(str[i] == 'o')
    {
     in_octal = 3;
     hv = 0;
    }
    else
    {
     char c = str[i];

     switch(str[i])
     {
      case 'a': c = '\a'; break;
      case 'b': c = '\b'; break;
      case 'f': c = '\f'; break;
      case 'n': c = '\n'; break;
      case 'r': c = '\r'; break;
      case 't': c = '\t'; break;
      case 'v': c = '\v'; break;
      case '\\': c = '\\'; break;
      case '\'': c = '\''; break;
      case '"': c = '"'; break;
      case '?': c = '?'; break;
     }

     str[di++] = c;
    }
   }
  }
  else
  {
   if(str[i] == '\\')
    in_escape = true;
   else
    str[di++] = str[i];
  }
 }

 assert(di <= str.size());
 str.resize(di);
}

std::string MDFN_strunescape(const std::string& str)
{
 std::string ret = str;

 MDFN_strunescape(&ret);

 return ret;
}

std::string MDFN_strescape(const std::string& str)
{
 std::string ret;
 size_t di = 0;

 ret.resize(str.size() * 4);

 for(size_t i = 0; i < str.size(); i++)
 {
  unsigned char c = str[i];

  if(c < 0x0E)
  {
   static const char tab[0xE] = { '0', '1', '2', '3', '4', '5', '6', 'a', 'b', 't', 'n', 'v', 'f', 'r' };

   ret[di++] = '\\';
   ret[di++] = tab[c];
  }
  else if(c < 0x20 || c == 0x7F)
  {
   static const char nybtab[0x10] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };

   ret[di++] = '\\';
   ret[di++] = 'x';
   ret[di++] = '0' + (c >> 4);
   ret[di++] = nybtab[c & 0xF]; // (c & 0x0F) + (((c & 0x0F) >= 0x0A) ? 'a' : '0');
  }
  else
  {
   if(c == '"' || c == '\\')
    ret[di++] = '\\';

   ret[di++] = c;
  }
 }

 ret.resize(di);
 ret.shrink_to_fit();

 return ret;
}

std::vector<std::string> MDFN_strargssplit(const std::string& str)
{
 std::vector<std::string> ret;
 std::string tmp;
 bool tmp_valid = false;
 bool in_quote = false;
 bool in_ws = true;
 int last_c = 0;

 for(size_t i = 0; i < str.size(); i++)
 {
  const int new_c = str[i];
  const bool is_quote = (new_c == '"' && last_c != '\\');
  const bool new_in_quote = in_quote ^ is_quote;
  const bool new_in_ws = MDFN_isspace(new_c) & !new_in_quote;

  if(!new_in_ws & !is_quote)
  {
   //printf("KA: %c\n", new_c);
   tmp.push_back(new_c);
   tmp_valid = true;
  }

  if((in_quote ^ new_in_quote) & new_in_quote)
   tmp_valid = true;

  if((in_ws ^ new_in_ws) & new_in_ws)
  {
   MDFN_strunescape(&tmp);
   //printf("borp1: %s\n", tmp.c_str());
   ret.push_back(tmp);
   tmp.clear();
   tmp_valid = false;
  }

  in_quote = new_in_quote;
  in_ws = new_in_ws;
  last_c = new_c;
 }

 if(tmp_valid)
 {
  MDFN_strunescape(&tmp);
  //printf("borp2: %s\n", tmp.c_str());
  ret.push_back(tmp);
 }

 return ret;
}


template<typename T> static void utf_noreplace(T* c) { }
template<int replacement, typename T> static void utf_replace(T* c) { *c = replacement; }
static INLINE void dummy_cp_handler(char32_t) { }

template<typename T, typename U>
static INLINE bool ProcessUTF8(T* s, const size_t slen, const bool permit_utf16_surrogates, void (*replacement_handler)(T*), U cp_handler)
{
 bool ret = true;

 for(size_t i = 0; i < slen; i++)
 {
  const unsigned char lc = (unsigned char)s[i];

  if(lc < 0x80)
  {
   cp_handler(lc);
   continue;
  }

  size_t num_cont_bytes = 0;
  char32_t cp = 0;

  if((lc & 0xE0) == 0xC0) // 2 byte total
  {
   num_cont_bytes = 1;
   cp = (lc & 0x1F);
  }
  else if((lc & 0xF0) == 0xE0) // 3 byte total
  {
   num_cont_bytes = 2;
   cp = (lc & 0xF);
  }
  else if((lc & 0xF8) == 0xF0) // 4 byte total
  {
   num_cont_bytes = 3;
   cp = (lc & 0x7);
  }
  else
  {
   //printf("Bad LC: %zu %c\n", i, lc);
   ret = false;
   replacement_handler(&s[i]);
   cp_handler(0xFFFD);
   continue;
  }
  
  {
   static const char32_t ol_tab[4] = { 0x00, 0x80, 0x800, 0x10000 };

   for(size_t j = i + 1; j < i + 1 + num_cont_bytes; j++)
   {
    if(j == slen)
    {
     //printf("OutOfBytes: %zu\n", j);
     ret = false;
     for(size_t k = i; k < j; k++)
     {
      replacement_handler(&s[k]);
      cp_handler(0xFFFD);
     }
     i = j - 1;
     goto ContinueBigLoop;
    }

    const unsigned char cc = (unsigned char)s[j];

    if((cc & 0xC0) != 0x80)
    {
     //printf("BadSeq: %zu\n", j);
     ret = false;
     for(size_t k = i; k < j; k++)
     {
      replacement_handler(&s[k]);
      cp_handler(0xFFFD);
     }
     i = j - 1;
     goto ContinueBigLoop;
    }
    cp = (cp << 6) | (cc & 0x3F);
   }

   if(cp < ol_tab[num_cont_bytes] || cp > 0x10FFFF || (!permit_utf16_surrogates && cp >= 0xD800 && cp <= 0xDFFF))
   {
    //printf("Error: 0x%08x\n", cp);
    ret = false;
    for(size_t j = i; j < i + 1 + num_cont_bytes; j++)
    {
     replacement_handler(&s[j]);
     cp_handler(0xFFFD);
    }
   }
   else
    cp_handler(cp);

   i += num_cont_bytes;
  }
  ContinueBigLoop:;
 }

 return ret;
}

template<typename T>
static bool ValidateUTF8(T* s, size_t slen, bool permit_utf16_surrogates)
{
 return ProcessUTF8<T>(s, slen, permit_utf16_surrogates, utf_noreplace<T>, dummy_cp_handler);
}

template<typename T>
static void SanitizeUTF8(T* s, size_t slen, bool permit_utf16_surrogates)
{
 ProcessUTF8<T>(s, slen, permit_utf16_surrogates, utf_replace<'?', T>, dummy_cp_handler);
}

bool UTF8_to_UTF32(const char* s, size_t slen, char32_t* d, size_t* dlen, bool permit_utf16_surrogates)
{
 size_t di = 0;
 bool ret = ProcessUTF8(s, slen, permit_utf16_surrogates,
		utf_noreplace, 
		[&](char32_t cp) { if(MDFN_LIKELY(di < *dlen)) { d[di] = cp; } di++; });

 *dlen = di;

 return ret;
}

static INLINE size_t ofszmult(const size_t a, const size_t b)
{
 size_t ret = a * b;

 if((ret / b) != a)
  throw std::overflow_error("size_t multiply overflow");

 return ret;
}

std::u32string UTF8_to_UTF32(const char* s, size_t slen, bool* invalid_utf8, bool permit_utf16_surrogates)
{
 std::u32string ret(slen, 0);
 size_t dlen = ret.size();
 bool ec = UTF8_to_UTF32(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf8)
  *invalid_utf8 = !ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}

static INLINE size_t EncodeCP_UTF8(const char32_t cp, char* const ptr, const size_t maxlen)
{
 unsigned char b[4];
 size_t bl;

 if(cp < 0x80)
 {
  b[0] = cp;
  bl = 1;
 }
 else if(cp < 0x800)
 {
  b[0] = 0xC0 | ((cp >> 6) & 0x1F);
  b[1] = 0x80 | ((cp >> 0) & 0x3F);
  bl = 2;
 }
 else if(cp < 0x10000)
 {
  b[0] = 0xE0 | ((cp >> 12) & 0x0F);
  b[1] = 0x80 | ((cp >>  6) & 0x3F);
  b[2] = 0x80 | ((cp >>  0) & 0x3F);
  bl = 3;
 }
 else
 {
  b[0] = 0xF0 | ((cp >> 18) & 0x07);
  b[1] = 0x80 | ((cp >> 12) & 0x3F);
  b[2] = 0x80 | ((cp >>  6) & 0x3F);
  b[3] = 0x80 | ((cp >>  0) & 0x3F);
  bl = 4;
 }

 for(size_t j = 0; j < bl; j++)
 {
  if(MDFN_LIKELY(j < maxlen))
   ptr[j] = b[j];
 }

 return bl;
}

static INLINE size_t EncodeCP_UTF16(const char32_t cp, char16_t* const ptr, const size_t maxlen)
{
 if(cp >= 0x10000)
 {
  if(MDFN_LIKELY(0 < maxlen)) { ptr[0] = 0xD800 + (((cp - 0x10000) >> 10) & 0x3FF); }
  if(MDFN_LIKELY(1 < maxlen)) { ptr[1] = 0xDC00 + (cp & 0x3FF); }
  return 2;
 }
 else
 {
  if(MDFN_LIKELY(0 < maxlen)) { ptr[0] = cp; }
  return 1;
 }
}

static INLINE size_t EncodeCP_UTF32(const char32_t cp, char32_t* const ptr, const size_t maxlen)
{
 if(MDFN_LIKELY(0 < maxlen)) ptr[0] = cp;
 return 1;
}

bool UTF8_to_UTF8(const char* s, size_t slen, char* d, size_t* dlen, bool permit_utf16_surrogates)
{
 size_t di = 0;
 bool ret = ProcessUTF8(s, slen, permit_utf16_surrogates,
		utf_noreplace, 
		[&](char32_t cp) { di += EncodeCP_UTF8(cp, &d[di], std::max<size_t>(*dlen, di) - di); });

 *dlen = di;

 return ret;
}

std::string UTF8_to_UTF8(const char* s, size_t slen, bool* invalid_utf8, bool permit_utf16_surrogates)
{
 std::string ret(ofszmult(slen, 4), 0);
 size_t dlen = ret.size();
 bool ec = UTF8_to_UTF8(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf8)
  *invalid_utf8 = !ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}

bool UTF8_to_UTF16(const char* s, size_t slen, char16_t* d, size_t* dlen, bool permit_utf16_surrogates)
{
 size_t di = 0;
 bool ret = ProcessUTF8(s, slen, permit_utf16_surrogates,
		utf_noreplace, 
		[&](char32_t cp) { di += EncodeCP_UTF16(cp, &d[di], std::max<size_t>(*dlen, di) - di); });

 *dlen = di;

 return ret;
}

std::u16string UTF8_to_UTF16(const char* s, size_t slen, bool* invalid_utf8, bool permit_utf16_surrogates)
{
 std::u16string ret(slen, 0);
 size_t dlen = ret.size();
 bool ec = UTF8_to_UTF16(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf8)
  *invalid_utf8 = !ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}


bool UTF8_validate(const char* s, bool permit_utf16_surrogates)
{
 return ValidateUTF8(s, strlen(s), permit_utf16_surrogates);
}

bool UTF8_validate(size_t len, const char* s, bool permit_utf16_surrogates)
{
 return ValidateUTF8(s, len, permit_utf16_surrogates);
}

bool UTF8_validate(const std::string& s, bool permit_utf16_surrogates)
{
 return ValidateUTF8(&s[0], s.size(), permit_utf16_surrogates);
}

void UTF8_sanitize(char* s, bool permit_utf16_surrogates)
{
 SanitizeUTF8(s, strlen(s), permit_utf16_surrogates);
}

void UTF8_sanitize(size_t len, char* s, bool permit_utf16_surrogates)
{
 SanitizeUTF8(s, len, permit_utf16_surrogates);
}

void UTF8_sanitize(std::string* s, bool permit_utf16_surrogates)
{
 SanitizeUTF8(&(*s)[0], s->size(), permit_utf16_surrogates);
}

std::string UTF8_sanitize(const std::string& s, bool permit_utf16_surrogates)
{
 std::string ret = s;

 UTF8_sanitize(&ret, permit_utf16_surrogates);

 return ret;
}

//
//
//
//
//

template<typename T, typename U>
static INLINE bool ProcessUTF16(T* s, const size_t slen, const bool permit_utf16_surrogates, void (*replacement_handler)(T*), U cp_handler)
{
 bool ret = true;

 for(size_t i = 0; i < slen; i++)
 {
  const char16_t lc = s[i];

  if(lc >= 0xDC00 && lc <= 0xDFFF && !permit_utf16_surrogates)
  {
   ret = false;
   replacement_handler(&s[i]);
   cp_handler(0xFFFD);
  }
  else if(lc >= 0xD800 && lc <= 0xDBFF)
  {
   if((slen - i - 1) < 1)
   {
    if(!permit_utf16_surrogates)
    {
     ret = false;
     replacement_handler(&s[i]);
     cp_handler(0xFFFD);
    }
    else
     cp_handler(lc);
   }
   else
   {
    const char16_t sc = s[i + 1];

    if(sc >= 0xDC00 && sc <= 0xDFFF)
    {
     cp_handler(0x10000 + ((lc & 0x3FF) << 10) + (sc & 0x3FF));
    }
    else if(permit_utf16_surrogates)
    {
     cp_handler(lc);
     cp_handler(sc);
    }
    else
    {
     replacement_handler(&s[i]);
     cp_handler(0xFFFD);

     replacement_handler(&s[i + 1]);
     cp_handler(0xFFFD);
    }
    i++;
   }
  }
  else
   cp_handler(lc);
 }

 return ret;
}

bool UTF16_to_UTF8(const char16_t* s, size_t slen, char* d, size_t* dlen, bool permit_utf16_surrogates)
{
 size_t di = 0;
 bool ret = ProcessUTF16(s, slen, permit_utf16_surrogates,
		utf_noreplace, 
		[&](char32_t cp) { di += EncodeCP_UTF8(cp, &d[di], std::max<size_t>(*dlen, di) - di); });
 *dlen = di;

 return ret;
}

bool UTF16_to_UTF32(const char16_t* s, size_t slen, char32_t* d, size_t* dlen, bool permit_utf16_surrogates)
{
 size_t di = 0;
 bool ret = ProcessUTF16(s, slen, permit_utf16_surrogates,
		utf_noreplace, 
		[&](char32_t cp) { di += EncodeCP_UTF32(cp, &d[di], std::max<size_t>(*dlen, di) - di); });
 *dlen = di;

 return ret;
}

std::string UTF16_to_UTF8(const char16_t* s, size_t slen, bool* invalid_utf16, bool permit_utf16_surrogates)
{
 std::string ret(ofszmult(slen, 3), 0);
 size_t dlen = ret.size();
 bool ec = UTF16_to_UTF8(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf16)
  *invalid_utf16 = ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}

std::u32string UTF16_to_UTF32(const char16_t* s, size_t slen, bool* invalid_utf16, bool permit_utf16_surrogates)
{
 std::u32string ret(slen, 0);
 size_t dlen = ret.size();
 bool ec = UTF16_to_UTF32(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf16)
  *invalid_utf16 = ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}


bool UTF32_to_UTF8(const char32_t* s, size_t slen, char* d, size_t* dlen, bool permit_utf16_surrogates)
{
 bool ret = true;
 size_t di = 0;

 for(size_t i = 0; i < slen; i++)
 {
  char32_t cp = s[i];

  if(cp > 0x10FFFF || (!permit_utf16_surrogates && cp >= 0xD800 && cp <= 0xDFFF))
  {
   cp = 0xFFFD;
   ret = false;
  }

  di += EncodeCP_UTF8(cp, &d[di], std::max<size_t>(*dlen, di) - di);
 }

 *dlen = di;
 return ret;
}

bool UTF32_to_UTF16(const char32_t* s, size_t slen, char16_t* d, size_t* dlen, bool permit_utf16_surrogates)
{
 bool ret = true;
 size_t di = 0;

 for(size_t i = 0; i < slen; i++)
 {
  char32_t cp = s[i];

  if(cp > 0x10FFFF || (!permit_utf16_surrogates && cp >= 0xD800 && cp <= 0xDFFF))
  {
   cp = 0xFFFD;
   ret = false;
  }

  di += EncodeCP_UTF16(cp, &d[di], std::max<size_t>(*dlen, di) - di);
 }

 *dlen = di;
 return ret;
}

std::string UTF32_to_UTF8(const char32_t* s, size_t slen, bool* invalid_utf32, bool permit_utf16_surrogates)
{
 std::string ret(ofszmult(slen, 4), 0);
 size_t dlen = ret.size();
 bool ec = UTF32_to_UTF8(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf32)
  *invalid_utf32 = ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}

std::u16string UTF32_to_UTF16(const char32_t* s, size_t slen, bool* invalid_utf32, bool permit_utf16_surrogates)
{
 std::u16string ret(ofszmult(slen, 2), 0);
 size_t dlen = ret.size();
 bool ec = UTF32_to_UTF16(s, slen, &ret[0], &dlen, permit_utf16_surrogates);

 if(invalid_utf32)
  *invalid_utf32 = ec;

 assert(dlen <= ret.size());

 ret.resize(dlen);

 return ret;
}

}
