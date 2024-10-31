/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* string.cpp:
**  Copyright (C) 2007-2023 Mednafen Team
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

void MDFN_strlcpy(char* d, const char* s, size_t l)
{
 while(l--)
 {
  char c = *s;

  if(!l)
   c = 0;

  if(!c)
   l = 0;

  *d = c;

  d++;
  s++;
 }
}

/*extern*/static const char MDFN_shex_lut[2][16] =
{
 { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' },
 { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' }
};

static INLINE void MDFN_shex_u8(char* const s, const uint8 v, const bool uc = false)
{
 //MDFN_HIDE extern const char MDFN_shex_lut[2][16];

 s[0] = MDFN_shex_lut[uc][v >> 4];
 s[1] = MDFN_shex_lut[uc][v & 0xF];
 s[2] = 0;
}

static INLINE void MDFN_shex_u16(char* const s, const uint16 v, const bool uc = false)
{
 MDFN_shex_u8(s + 0, v >> 8, uc);
 MDFN_shex_u8(s + 2, v, uc);
}

static INLINE void MDFN_shex_u32(char* const s, const uint32 v, const bool uc = false)
{
 MDFN_shex_u16(s + 0, v >> 16, uc);
 MDFN_shex_u16(s + 4, v, uc);
}

static INLINE void MDFN_shex_u64(char* const s, const uint64 v, const bool uc = false)
{
 MDFN_shex_u32(s + 0, v >> 32, uc);
 MDFN_shex_u32(s + 8, v, uc);
}

void MDFN_snhex_u8(char* s, size_t n, uint8 v, bool uc)
{
 char tmp[2 + 1];

 MDFN_shex_u8(tmp, v, uc);
 MDFN_strlcpy(s, tmp, n);
}

void MDFN_snhex_u16(char* s, size_t n, uint16 v, bool uc)
{
 char tmp[4 + 1];

 MDFN_shex_u16(tmp, v, uc);
 MDFN_strlcpy(s, tmp, n);
}

void MDFN_snhex_u32(char* s, size_t n, uint32 v, bool uc)
{
 char tmp[8 + 1];

 MDFN_shex_u32(tmp, v, uc);
 MDFN_strlcpy(s, tmp, n);
}

void MDFN_snhex_u64(char* s, size_t n, uint64 v, bool uc)
{
 char tmp[16 + 1];

 MDFN_shex_u64(tmp, v, uc);
 MDFN_strlcpy(s, tmp, n);
}

template<typename T>
static INLINE void sndec_T(char* s, size_t n, T v)
{
 if(!n)
  return;

 typename std::make_unsigned<T>::type nv = v;

 if(std::is_signed<T>::value && v < 0)
 {
  *s = '-';
  s += (bool)(n -= (bool)n);
  nv = -nv;
 }

 char tmp[(sizeof(T) * 8 + 2) / 3 /* log(10)/log(2)*/];
 unsigned w = 0;

 do
 {
  tmp[w] = '0' + (nv % 10);
  w++;
  nv /= 10;
 } while(nv);

 for(unsigned i = 0; i < w; i++)
 {
  *s = tmp[w - 1 - i];
  s += (bool)(n -= (bool)n);
 }

 *s = 0;
}

void MDFN_sndec_s64(char* s, size_t n, int64 v)
{
 sndec_T<int64>(s, n, v);
}

void MDFN_sndec_u64(char* s, size_t n, uint64 v)
{
 sndec_T<uint64>(s, n, v);
}

template<typename T>
static INLINE T Xfromstr(const char* v, unsigned base, unsigned* error)
{
 bool neg = false;
 //const char* const vbegin = v;

 if(base > 36)
 {
  *error = XFROMSTR_ERROR_INVALID_BASE;
  return 0;
 }

 if(v[0] == '-')
 {
  neg = !neg;
  v++;
 }
 else if(v[0] == '+')
  v++;

 if((!base || base == 16) && v[0] == '0' && MDFN_azlower(v[1]) == 'x')
 {
  base = 16;
  v += 2;
 }

 if(!base)
  base = 10;
 //
 //
 if(!*v)
 {
  *error = XFROMSTR_ERROR_MALFORMED; //(v != vbegin) ? XFROMSTR_ERROR_MALFORMED : XFROMSTR_ERROR_EMPTY;
  return 0;
 }
 //
 //
 //
 typename std::make_unsigned<T>::type tmp = 0;
 const decltype(tmp) all1b = ~(decltype(tmp))0;
 const T minval = (T)(std::is_signed<T>::value ? ((all1b >> 1) + neg) : 0);
 const T maxval = std::is_signed<T>::value ? (all1b >> 1) : ~(T)0;
 const decltype(tmp) overflow_thresh = all1b / base;
 char c;

 *error = XFROMSTR_ERROR_NONE;

 while((c = *v))
 {
  unsigned n;
  decltype(tmp) ntmp;

  if(c >= '0' && c <= '9')
   n = c - '0';
  else if(MDFN_isazlower(c))
   n = 10 + (c - 'a');
  else if(MDFN_isazupper(c))
   n = 10 + (c - 'A');
  else
  {
   *error = XFROMSTR_ERROR_MALFORMED;
   return 0;
  }

  if(n >= base)
  {
   *error = XFROMSTR_ERROR_MALFORMED;
   return 0;
  }

  if(MDFN_UNLIKELY(tmp > overflow_thresh))
  {
   const bool uflow = neg;
   //printf("MOO0 0x%016llx 0x%016llx\n", minval, maxval);
   *error = uflow ? XFROMSTR_ERROR_UNDERFLOW : XFROMSTR_ERROR_OVERFLOW;
   return uflow ? minval : maxval;
  }

  tmp *= base;
  ntmp = tmp + n;
  if(MDFN_UNLIKELY(ntmp < tmp))
  {
   //puts("MOO1");
   *error = neg ? XFROMSTR_ERROR_UNDERFLOW : XFROMSTR_ERROR_OVERFLOW;
   return neg ? minval : maxval;
  }

  tmp = ntmp;
  v++;
 }

 if(std::is_signed<T>::value && MDFN_UNLIKELY(tmp > ((all1b >> 1) + neg)))
 {
  //puts("MOO2");
  *error = neg ? XFROMSTR_ERROR_UNDERFLOW : XFROMSTR_ERROR_OVERFLOW;

  tmp = ((all1b >> 1) + neg);
 }

 if(std::is_unsigned<T>::value && MDFN_UNLIKELY(neg) && tmp > 0)
 {
  *error = XFROMSTR_ERROR_UNDERFLOW;
  tmp = minval;
 }

 if(neg)
  tmp = -tmp;

 return (T)tmp;
}

uint64 MDFN_u64fromstr(const char* p, unsigned base, unsigned* error)
{
 return Xfromstr<uint64>(p, base, error);
}

int64 MDFN_s64fromstr(const char* p, unsigned base, unsigned* error)
{
 return Xfromstr<int64>(p, base, error);
}

uint32 MDFN_u32fromstr(const char* p, unsigned base, unsigned* error)
{
 return Xfromstr<uint32>(p, base, error);
}

int32 MDFN_s32fromstr(const char* p, unsigned base, unsigned* error)
{
 return Xfromstr<int32>(p, base, error);
}

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

/*
void MDFN_strazcasexlate(char* d, const char* s)
{
 while(*d && *s)
 {
  const char sc = *s;
  char dc = *d;

  if(MDFN_isazupper(sc))
   dc = MDFN_azupper(dc);
  else if(MDFN_isazlower(sc))
   dc = MDFN_azlower(dc);
  
  *d = dc;
  //
  d++;
  s++;
 }
}
*/

// Take care to never return INT_MIN in the MDFN_*azicmp() functions, or the
// inline function in string.h with the return value negation will malfunction.

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
 const unsigned char* a = (const unsigned char*)s;
 const unsigned char* b = (const unsigned char*)t;

 while(n--)
 {
  const int d = (unsigned char)MDFN_azlower(*a++) - (unsigned char)MDFN_azlower(*b++);

  if(d)
   return d;
 }

 return 0;
}

int MDFN_strazicmp(const std::string& s, const std::string& t, size_t n)
{
 const size_t sn_len = std::min<size_t>(s.size(), n);
 const size_t tn_len = std::min<size_t>(t.size(), n);

 if(sn_len != tn_len)
  return (sn_len > tn_len) ? 1 : -1;

 return MDFN_memazicmp(s.data(), t.data(), sn_len);
}

int MDFN_strazicmp(const std::string& s, const char* t, size_t n)
{
 const size_t t_len = strlen(t);
 const size_t sn_len = std::min<size_t>(s.size(), n);
 const size_t tn_len = std::min<size_t>(t_len, n);

 if(sn_len != tn_len)
  return (sn_len > tn_len) ? 1 : -1;

 return MDFN_memazicmp(s.data(), t, sn_len);
}

size_t MDFN_memmismatch(const void* s, const void* t, size_t n)
{
 for(size_t i = 0; i != n; i++)
 {
  if(((uint8*)s)[i] != ((uint8*)t)[i])
   return i;
 }

 return SIZE_MAX;
}

size_t MDFN_strmismatch(const std::string& s, const std::string& t)
{
 size_t ms = std::min<size_t>(s.size(), t.size());
 size_t r = MDFN_memmismatch(s.data(), t.data(), ms);

 if(s.size() != t.size())
  r = std::min<size_t>(r, ms);

 return r;
}

size_t MDFN_strmismatch(const std::string& s, const char* t)
{
 const size_t t_len = strlen(t);
 size_t ms = std::min<size_t>(s.size(), t_len);
 size_t r = MDFN_memmismatch(s.data(), t, ms);

 if(s.size() != t_len)
  r = std::min<size_t>(r, ms);

 return r;
}

size_t MDFN_strmismatch(const char* s, const char* t)
{
 for(size_t i = 0; s[i] || t[i]; i++)
 {
  if(s[i] != t[i])
   return i;
 }

 return SIZE_MAX;
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
  const char c = str[i];

  if(in_octal)
  {
   const bool valid_octal_char = (c >= '0' && c <= '7');

   if(valid_octal_char)
   {
    hv *= 8;
    hv += c - '0';
    in_octal--;
   }
   else
    in_octal = 0;

   if(!in_octal)
    str[di++] = hv;

   if(!valid_octal_char)
    goto noesc;
  }
  else if(in_hex)
  {
   char lc = MDFN_azlower(c);
   const bool valid_hex_char = ((lc >= '0' && lc <= '9') || (lc >= 'a' && lc <= 'f'));

   if(valid_hex_char)
   {
    hv <<= 4;
    hv += (lc >= '0' && lc <= '9') ? (lc - '0') : (lc - 'a' + 0xA);
    in_hex--;
   }
   else
    in_hex = 0;

   if(!in_hex)
    str[di++] = hv;

   if(!valid_hex_char)
    goto noesc;
  }
  else if(in_escape)
  {
   in_escape = false;

   if(c >= '0' && c <= '7')
   {
    in_octal = 2;
    hv = c - '0';
   }
   else
   {
    if(c == 'x')
    {
     in_hex = 2;
     hv = 0;
    }
    else if(c == 'o')
    {
     in_octal = 3;
     hv = 0;
    }
    else
    {
     char nc = c;

     switch(str[i])
     {
      case 'a': nc = '\a'; break;
      case 'b': nc = '\b'; break;
      case 'f': nc = '\f'; break;
      case 'n': nc = '\n'; break;
      case 'r': nc = '\r'; break;
      case 't': nc = '\t'; break;
      case 'v': nc = '\v'; break;
      case '\\': nc = '\\'; break;
      case '\'': nc = '\''; break;
      case '"': nc = '"'; break;
      case '?': nc = '?'; break;
     }

     str[di++] = nc;
    }
   }
  }
  else
  {
   noesc:;
   if(c == '\\')
    in_escape = true;
   else
    str[di++] = c;
  }
 }
 //
 //
 if(in_octal > 0 || in_hex > 0)
  str[di++] = hv;

 assert(di <= str.size());
 str.resize(di);
}

std::string MDFN_strunescape(const std::string& str)
{
 std::string ret = str;

 MDFN_strunescape(&ret);

 return ret;
}

static INLINE size_t ofszmult(const size_t a, const size_t b)
{
 size_t ret = a * b;

 if((ret / b) != a)
  throw std::overflow_error("size_t multiply overflow");

 return ret;
}

std::string MDFN_strescape(const std::string& str)
{
 const size_t str_size = str.size();
 std::string ret(ofszmult(str_size, 4), 0);
 size_t di = 0;

 for(size_t i = 0; i < str_size; i++)
 {
  unsigned char c = str[i];

  if(c >= 0x07 && c <= 0x0D)
  {
   static const char tab[0x7] = { 'a', 'b', 't', 'n', 'v', 'f', 'r' };

   ret[di++] = '\\';
   ret[di++] = tab[c - 0x07];
  }
  else if(c < 0x20 || c == 0x7F)
  {
   ret[di++] = '\\';
   ret[di++] = '0' + ((c >> 6) & 0x7);
   ret[di++] = '0' + ((c >> 3) & 0x7);
   ret[di++] = '0' + ((c >> 0) & 0x7);
  }
  else
  {
   if(c == '"' || c == '\'' || c == '\\')
    ret[di++] = '\\';

   ret[di++] = c;
  }
 }

 ret.resize(di);
 ret.shrink_to_fit();

 return ret;
}

std::string MDFN_strhumesc(const std::string& str)
{
 const size_t str_size = str.size();
 std::string ret(ofszmult(str_size, 2), 0);
 size_t di = 0;

 for(size_t i = 0; i < str_size; i++)
 {
  unsigned char c = str[i];

  if(c < 0x20 || c == 0x7F)
  {
   ret[di++] = '^';
   ret[di++] = c ^ 0x40;
  }
  else
   ret[di++] = c;
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
 bool in_esc = false;

 for(size_t i = 0; i < str.size(); i++)
 {
  const int new_c = str[i];
  const bool is_quote = (new_c == '"' && !in_esc);
  const bool new_in_esc = (!in_esc && new_c == '\\');
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
  in_esc = new_in_esc;
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
