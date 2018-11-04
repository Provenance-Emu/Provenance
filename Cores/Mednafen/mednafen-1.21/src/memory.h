/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* memory.h:
**  Copyright (C) 2010-2016 Mednafen Team
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

#ifndef __MDFN_MEMORY_H
#define __MDFN_MEMORY_H

#include "error.h"

#include <new>

// "Array" is a bit of a misnomer, but it helps avoid confusion with memset() semantics hopefully.
static INLINE void MDFN_FastArraySet(uint64* const dst, const uint64 value, const size_t count)
{
 #if defined(ARCH_X86) && defined(__x86_64__)
 {
  uint32 dummy_output0, dummy_output1;

  asm volatile(
        "cld\n\t"
        "rep stosq\n\t"
        : "=D" (dummy_output0), "=c" (dummy_output1)
        : "a" (value), "D" (dst), "c" (count)
        : "cc", "memory");
 }
 #else

 for(uint64 *ai = dst; MDFN_LIKELY(ai != (dst + count)); ai++)
  MDFN_ennsb<uint64, true>(ai, value);

 #endif
}

static INLINE void MDFN_FastArraySet(uint32* const dst, const uint32 value, const size_t count)
{
 #if defined(ARCH_X86) && !defined(__x86_64__)
 {
  uint32 dummy_output0, dummy_output1;

  asm volatile(
        "cld\n\t"
        "rep stosl\n\t"
        : "=D" (dummy_output0), "=c" (dummy_output1)
        : "a" (value), "D" (dst), "c"(count)
        : "cc", "memory");

  return;
 }
 #else
 if(0 == ((uintptr_t)dst & (sizeof(uint64) - 1)) && !(count & 1))
  MDFN_FastArraySet((uint64*)dst, value | ((uint64)value << 32), count >> 1);
 else
 {
  for(uint32 *ai = dst; MDFN_LIKELY(ai != (dst + count)); ai++)
   MDFN_ennsb<uint32, true>(ai, value);
 }
 #endif
}

static INLINE void MDFN_FastArraySet(uint16* const dst, const uint16 value, const size_t count)
{
 if(0 == ((uintptr_t)dst & (sizeof(uint32) - 1)) && !(count & 1))
  MDFN_FastArraySet((uint32*)dst, value | (value << 16), count >> 1);
 else
 {
  for(uint16 *ai = dst; MDFN_LIKELY(ai != (dst + count)); ai++)
   MDFN_ennsb<uint16, true>(ai, value);
 }
}

static INLINE void MDFN_FastArraySet(uint8* const dst, const uint16 value, const size_t count)
{
 if(0 == ((uintptr_t)dst & (sizeof(uint16) - 1)) && !(count & 1))
  MDFN_FastArraySet((uint16*)dst, value | (value << 8), count >> 1);
 else
 {
  for(uint8 *ai = dst; MDFN_LIKELY(ai != (dst + count)); ai++)
   *ai = value;
 }
}


void MDFN_FastMemXOR(void* dest, const void* src, size_t count);

struct MDFN_TransientXOR
{
 INLINE MDFN_TransientXOR(void* dest, const void* src, size_t count) : ld(dest), ls(src), lc(count)
 {
  MDFN_FastMemXOR(ld, ls, lc);
 }

 MDFN_TransientXOR(const MDFN_TransientXOR&) = delete;
 const MDFN_TransientXOR& operator=(const MDFN_TransientXOR&) = delete;

 INLINE ~MDFN_TransientXOR()
 {
  if(ld && ls)
  {
   MDFN_FastMemXOR(ld, ls, lc);
  
   // To more easily catch problems in case something goes amiss.
   ld = NULL;
   ls = NULL;
  }
 }

 INLINE void release(void)
 {
  ld = NULL;
  ls = NULL;
 }

 private:
 void* ld;
 const void* ls;
 const size_t lc;
};


// memset() replacement that will work on uncachable memory.
//void *MDFN_memset_safe(void *s, int c, size_t n);


//
// WARNING: Only use PODFastVector with POD types, and take note that taking a pointer to an element, calling PODFastVector::resize(), and then dereferencing that
// pointer is liable to explode horribly on Tuesdays.
//
template<typename T>
class PODFastVector
{
 public:

 INLINE PODFastVector() : data(NULL), data_size_ine(0)
 {

 }

 INLINE PODFastVector(size_t new_size) : data(NULL), data_size_ine(0)
 {
  resize(new_size);
 }

 INLINE ~PODFastVector()
 {
  if(data != NULL)
  {
   free(data);
   data = NULL;
  }
 }

 INLINE T& operator[](size_t index)
 {
  return data[index];
 }

 INLINE const T& operator[](size_t index) const
 {
  return data[index];
 }

 INLINE void fill(const T value)
 {
  for(size_t i = 0; i < data_size_ine; i++)
   data[i] = value;
 }

 INLINE void resize(size_t new_size)
 {
  if(!new_size)
  {
   if(data != NULL)
   {
    free(data);
    data = NULL;
    data_size_ine = 0;
   }
  }
  else
  {
   void* tmp = realloc(data, sizeof(T) * new_size);

   if(tmp == NULL)
   {
    throw MDFN_Error(ErrnoHolder(ENOMEM));
   }

   data = (T*)tmp;
   data_size_ine = new_size;
  }
 }

 INLINE void clear(void)
 {
  resize(0);
 }

 INLINE size_t size(void) const
 {
  return data_size_ine;
 }

 private:
 PODFastVector(const PODFastVector &);
 PODFastVector & operator=(const PODFastVector &);

 T* data;
 size_t data_size_ine;
};
#endif
