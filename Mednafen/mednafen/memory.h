#ifndef _MDFN_MEMORY_H

#include "error.h"

#include <new>
#include <stdlib.h>

// These functions can be used from driver code or from internal Mednafen code.

#define MDFN_malloc(size, purpose) MDFN_malloc_real(false, size, purpose, __FILE__, __LINE__)
#define MDFN_calloc(nmemb, size, purpose) MDFN_calloc_real(false, nmemb, size, purpose, __FILE__, __LINE__)
#define MDFN_realloc(ptr, size, purpose) MDFN_realloc_real(false, ptr, size, purpose, __FILE__, __LINE__)

// These three will throw an error message instead of returning NULL.
#define MDFN_malloc_T(size, purpose) MDFN_malloc_real(true, size, purpose, __FILE__, __LINE__)
#define MDFN_calloc_T(nmemb, size, purpose) MDFN_calloc_real(true, nmemb, size, purpose, __FILE__, __LINE__)
#define MDFN_realloc_T(ptr, size, purpose) MDFN_realloc_real(true, ptr, size, purpose, __FILE__, __LINE__)


void *MDFN_malloc_real(bool dothrow, size_t size, const char *purpose, const char *_file, const int _line);
void *MDFN_calloc_real(bool dothrow, size_t nmemb, size_t size, const char *purpose, const char *_file, const int _line);
void *MDFN_realloc_real(bool dothrow, void *ptr, size_t size, const char *purpose, const char *_file, const int _line);
void MDFN_free(void *ptr);

static INLINE void MDFN_FastU32MemsetM8(uint32 *array, uint32 value_32, unsigned int u32len)
{
 #ifdef ARCH_X86 
 uint32 dummy_output0, dummy_output1;

 #ifdef __x86_64__
 asm volatile(
        "cld\n\t"
        "rep stosq\n\t"
        : "=D" (dummy_output0), "=c" (dummy_output1)
        : "a" (value_32 | ((uint64)value_32 << 32)), "D" (array), "c" (u32len >> 1)
        : "cc", "memory");
 #else
 asm volatile(
        "cld\n\t"
        "rep stosl\n\t"
        : "=D" (dummy_output0), "=c" (dummy_output1)
        : "a" (value_32), "D" (array), "c" (u32len)
        : "cc", "memory");

 #endif

 #else
 for(uint32 *ai = array; MDFN_LIKELY(ai < array + u32len); ai += 2)
 {
  MDFN_ennsb<uint64, true>(ai, value_32 | ((uint64)value_32 << 32));
 }
 #endif
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
    throw MDFN_Error(ErrnoHolder(errno));
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

#define _MDFN_MEMORY_H
#endif
