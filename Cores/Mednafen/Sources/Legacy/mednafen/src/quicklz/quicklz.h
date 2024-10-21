#ifndef QLZ_HEADER
#define QLZ_HEADER

// Version 1.31 final
#define QLZ_VERSION_MAJOR 1
#define QLZ_VERSION_MINOR 3
#define QLZ_VERSION_REVISION 1

// Set following flags according to the manual
#define QLZ_COMPRESSION_LEVEL 0
//#define QLZ_STREAMING_MODE 2000000
#define test_rle
#define speedup_incompressible
//#define memory_safe

// Public functions of QuickLZ

#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t qlz_decompress(const char *source, void *destination, char *scratch);
size_t qlz_compress(const void *source, char *destination, size_t size, char *scratch);
size_t qlz_size_decompressed(const char *source);
size_t qlz_size_compressed(const char *source);
int qlz_get_setting(int setting);

#if (defined(__X86__) || defined(__i386__) || defined(i386) || defined(_M_IX86) || defined(__386__) || defined(__x86_64__) || defined(_M_X64))
	#define X86X64
#endif

// Compute QLZ_SCRATCH_COMPRESS, QLZ_SCRATCH_DECOMPRESS and constants used internally
#if QLZ_COMPRESSION_LEVEL == 0 && defined(memory_safe)
	#error memory_safe flag cannot be used with QLZ_COMPRESSION_LEVEL 0
#endif

#define QLZ_HASH_ENTRIES 4096

#if (QLZ_COMPRESSION_LEVEL == 0 || QLZ_COMPRESSION_LEVEL == 1 || QLZ_COMPRESSION_LEVEL == 2)
	#define AND 1
#elif (QLZ_COMPRESSION_LEVEL == 3)
	#define AND 0x7
#else
	#error QLZ_COMPRESSION_LEVEL must be 0, 1, 2 or 3
#endif

#define QLZ_HASH_SIZE (AND + 1)*QLZ_HASH_ENTRIES*sizeof(unsigned char *)

#ifdef QLZ_STREAMING_MODE
	#define QLZ_STREAMING_MODE_VALUE QLZ_STREAMING_MODE
#else
	#define QLZ_STREAMING_MODE_VALUE 0
#endif

#define QLZ_STREAMING_MODE_ROUNDED ((QLZ_STREAMING_MODE_VALUE >> 3) << 3)

#if (QLZ_COMPRESSION_LEVEL > 1)
	#define QLZ_SCRATCH_COMPRESS QLZ_HASH_SIZE + QLZ_STREAMING_MODE_VALUE + 16 + QLZ_HASH_ENTRIES
#else
	#define QLZ_SCRATCH_COMPRESS QLZ_HASH_SIZE + QLZ_STREAMING_MODE_VALUE + 16
#endif

#if (QLZ_COMPRESSION_LEVEL == 0)
	#define QLZ_SCRATCH_DECOMPRESS QLZ_HASH_ENTRIES*sizeof(unsigned char *) + 16 + QLZ_STREAMING_MODE_VALUE
#else
	#define QLZ_SCRATCH_DECOMPRESS 16 + QLZ_STREAMING_MODE_VALUE
#endif


#ifdef __cplusplus
}
#endif


#endif





