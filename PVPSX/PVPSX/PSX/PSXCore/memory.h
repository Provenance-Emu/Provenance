#ifndef _MDFN_MEMORY_H

// These functions can be used from driver code or from internal Mednafen code.

#define MDFN_malloc(size, purpose) MDFN_malloc_real(false, size, purpose, __FILE__, __LINE__)
#define MDFN_calloc(nmemb, size, purpose) MDFN_calloc_real(false, nmemb, size, purpose, __FILE__, __LINE__)
#define MDFN_realloc(ptr, size, purpose) MDFN_realloc_real(false, ptr, size, purpose, __FILE__, __LINE__)

// These three will throw an error message instead of returning NULL.
#define MDFN_malloc_T(size, purpose) MDFN_malloc_real(true, size, purpose, __FILE__, __LINE__)
#define MDFN_calloc_T(nmemb, size, purpose) MDFN_calloc_real(true, nmemb, size, purpose, __FILE__, __LINE__)
#define MDFN_realloc_T(ptr, size, purpose) MDFN_realloc_real(true, ptr, size, purpose, __FILE__, __LINE__)


void *MDFN_malloc_real(bool dothrow, uint32 size, const char *purpose, const char *_file, const int _line);
void *MDFN_calloc_real(bool dothrow, uint32 nmemb, uint32 size, const char *purpose, const char *_file, const int _line);
void *MDFN_realloc_real(bool dothrow, void *ptr, uint32 size, const char *purpose, const char *_file, const int _line);
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

 for(uint32 *ai = array; ai < array + u32len; ai += 2)
 {
  ai[0] = value_32;
  ai[1] = value_32;
 }

 #endif
 //printf("%08x %d\n", (int)(long long)array, u32len);
}

// memset() replacement that will work on uncachable memory.
//void *MDFN_memset_safe(void *s, int c, size_t n);

#define _MDFN_MEMORY_H
#endif
