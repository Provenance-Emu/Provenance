#include <stdlib.h>
#include <stdint.h>

// libgcc has this with gcc 4.x
void raise(int sig)
{
}

// very limited heap functions for helix decoder

static char heap[65000] __attribute__((aligned(16)));
static long heap_offs;

void __malloc_init(void)
{
	heap_offs = 0;
}

void *malloc(size_t size)
{
        void *chunk = heap + heap_offs;
        size = (size+15) & ~15;
        if (heap_offs + size > sizeof(heap))
                return NULL;
        else {
                heap_offs += size;
                return chunk;
        }
}

void free(void *chunk)
{
	if (chunk == heap)
		heap_offs = 0;
}

#if 0
void *memcpy (void *dest, const void *src, size_t n)
{
	char       *_dest = dest;
        const char *_src = src;
	while (n--) *_dest++ = *_src++;
	return dest;
}

void *memmove (void *dest, const void *src, size_t n)
{
	char       *_dest = dest+n;
        const char *_src = src+n;
	if (dest <= src || dest >= _src)
		return memcpy(dest, src, n);
	while (n--) *--_dest = *--_src;
	return dest;
}
#else
#include "../memcpy.c"
#endif
