/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
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

#include "mednafen.h"

#include <stdlib.h>
#include <errno.h>

#include "memory.h"

void *MDFN_calloc_real(bool dothrow, size_t nmemb, size_t size, const char *purpose, const char *_file, const int _line)
{
 void *ret;

 ret = calloc(nmemb, size);

 if(!ret)
 {
  if(dothrow)
  {
   ErrnoHolder ene;

   throw MDFN_Error(ene.Errno(), _("Error allocating(calloc) %zu*%zu bytes for \"%s\" in %s(%d)!"), nmemb, size, purpose, _file, _line);
  }
  else
  {
   MDFN_PrintError(_("Error allocating(calloc) %zu*%zu bytes for \"%s\" in %s(%d)!"), nmemb, size, purpose, _file, _line);
   return(0);
  }
 }
 return ret;
}

void *MDFN_malloc_real(bool dothrow, size_t size, const char *purpose, const char *_file, const int _line)
{
 void *ret;

 ret = malloc(size);

 if(!ret)
 {
  if(dothrow)
  {
   ErrnoHolder ene;

   throw MDFN_Error(ene.Errno(), _("Error allocating(malloc) %zu bytes for \"%s\" in %s(%d)!"), size, purpose, _file, _line);
  }
  else
  {
   MDFN_PrintError(_("Error allocating(malloc) %zu bytes for \"%s\" in %s(%d)!"), size, purpose, _file, _line);
   return(0);
  }
 }
 return ret;
}

void *MDFN_realloc_real(bool dothrow, void *ptr, size_t size, const char *purpose, const char *_file, const int _line)
{
 void *ret;

 ret = realloc(ptr, size);

 if(!ret)
 {
  if(dothrow)
  {
   ErrnoHolder ene;

   throw MDFN_Error(ene.Errno(), _("Error allocating(realloc) %zu bytes for \"%s\" in %s(%d)!"), size, purpose, _file, _line);
  }
  else
  {
   MDFN_PrintError(_("Error allocating(realloc) %zu bytes for \"%s\" in %s(%d)!"), size, purpose, _file, _line);
   return(0);
  }
 }
 return ret;
}

void MDFN_free(void *ptr)
{
 free(ptr);
}


//
//
//
void MDFN_FastMemXOR(void* dest, const void* src, size_t count)
{
 const unsigned alch = ((unsigned long long)dest | (unsigned long long)src);

 uint8* pd = (uint8*)dest;
 const uint8* sd = (const uint8*)src;

 if((alch & 0x7) == 0)
 {
  while(MDFN_LIKELY(count >= 32))
  {
   MDFN_ennsb<uint64, true>(&pd[0], MDFN_densb<uint64, true>(&pd[0]) ^ MDFN_densb<uint64, true>(&sd[0]));
   MDFN_ennsb<uint64, true>(&pd[8], MDFN_densb<uint64, true>(&pd[8]) ^ MDFN_densb<uint64, true>(&sd[8]));
   MDFN_ennsb<uint64, true>(&pd[16], MDFN_densb<uint64, true>(&pd[16]) ^ MDFN_densb<uint64, true>(&sd[16]));
   MDFN_ennsb<uint64, true>(&pd[24], MDFN_densb<uint64, true>(&pd[24]) ^ MDFN_densb<uint64, true>(&sd[24]));

   pd += 32;
   sd += 32;
   count -= 32;
  }
 }

 for(size_t i = 0; MDFN_LIKELY(i < count); i++)
  pd[i] ^= sd[i];
}

