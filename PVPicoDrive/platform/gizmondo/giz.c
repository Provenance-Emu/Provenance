/*
 * PicoDrive
 * (C) notaz, 2007
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <windows.h>
#include <stdio.h>

#include "kgsdk/Framework.h"
#include "kgsdk/Framework2D.h"
#include "giz.h"
#include "version.h"

#define LOG_FILE "log.log"

void *giz_screen = NULL;
static FILE *logf = NULL;

#if 0
static int  directfb_init(void);
static void directfb_fini(void);
#endif

void lprintf(const char *fmt, ...)
{
	va_list vl;

	if (logf == NULL)
	{
		logf = fopen(LOG_FILE, "r+");
		//logf = fopen(LOG_FILE, "a");
		if (logf == NULL)
			return;
	}
	fseek(logf, 0, SEEK_END);

	//if (strchr(fmt, '\n'))
	//	fprintf(logf, "%lu: ", GetTickCount());
	va_start(vl, fmt);
	vfprintf(logf, fmt, vl);
	va_end(vl);
	fflush(logf);
}

static void giz_log_close(void)
{
	if (logf != NULL)
	{
		fclose(logf);
		logf = NULL;
	}
}

void giz_init(HINSTANCE hInstance, HINSTANCE hPrevInstance)
{
	int ret;

	lprintf("\n\nPicoDrive v" VERSION " (c) notaz, 2006-2008\n");
	lprintf("%s %s\n\n", __DATE__, __TIME__);

	ret = Framework_Init(hInstance, hPrevInstance);
	if (!ret)
	{
		lprintf("Framework_Init() failed\n");
		exit(1);
	}
	ret = Framework2D_Init();
	if (!ret)
	{
		lprintf("Framework2D_Init() failed\n");
		exit(1);
	}
#if 0
	ret = directfb_init();
	if (ret != 0)
	{
		lprintf("directfb_init() failed\n");
	}
#endif

	// test screen
	giz_screen = fb_lock(1);
	if (giz_screen == NULL)
	{
		lprintf("fb_lock() failed\n");
		exit(1);
	}
	lprintf("fb_lock() returned %p\n", giz_screen);
	fb_unlock();
	giz_screen = NULL;
}

void giz_deinit(void)
{
	Framework2D_Close();
	Framework_Close();
#if 0
	directfb_fini();
#endif

	giz_log_close();
}


#define PAGE_SIZE 0x1000

#define CACHE_SYNC_INSTRUCTIONS 0x002   /* discard all cached instructions */
#define CACHE_SYNC_WRITEBACK    0x004   /* write back but don't discard data cache*/

WINBASEAPI BOOL WINAPI CacheRangeFlush(LPVOID pAddr, DWORD dwLength, DWORD dwFlags);
WINBASEAPI BOOL WINAPI VirtualCopy(LPVOID lpvDest, LPVOID lpvSrc, DWORD cbSize, DWORD fdwProtect);

void cache_flush_d_inval_i(void *start_addr, void *end_addr)
{
	int size = end_addr - start_addr;
	CacheRangeFlush(start_addr, size, CACHE_SYNC_WRITEBACK);
	CacheRangeFlush(start_addr, size, CACHE_SYNC_INSTRUCTIONS);
}


#if 0
static void *mmap_phys(unsigned int addr, int pages)
{
	void *mem;
	int ret;

	mem = VirtualAlloc(0, pages*PAGE_SIZE, MEM_RESERVE, PAGE_NOACCESS);
	if (mem == NULL)
	{
		lprintf("VirtualAlloc failed\n");
		return NULL;
	}

	ret = VirtualCopy(mem, (void *)addr, pages*PAGE_SIZE, PAGE_READWRITE | PAGE_NOCACHE);
	if (ret == 0)
	{
		lprintf("VirtualFree failed\n");
		VirtualFree(mem, 0, MEM_RELEASE);
		return NULL;
	}

	return mem;
}

static void munmap_phys(void *ptr)
{
	VirtualFree(ptr, 0, MEM_RELEASE);
}

// FB
static int   directfb_initialized = 0;
static int   directfb_addrs[2] = { 0, 0 };
static void *directfb_ptrs[2] = { NULL, NULL };
static int   directfb_sel = 0;		// the one currently displayed
static volatile unsigned int *memregs = NULL;

/*static void xdump(void)
{
	int i;
	for (i = 0; i < 0x1000/4; i += 4)
	{
		lprintf("%04x: %08x %08x %08x %08x\n", i*4, memregs[i],
			memregs[i+1], memregs[i+2], memregs[i+3]);
	}
}*/

static int directfb_init(void)
{
	memregs = mmap_phys(0xac009000, 1);
	if (memregs == NULL)
	{
		lprintf("can't access hw regs\n");
		return -1;
	}

	// fake lock
	Framework2D_LockBuffer(1);

	// 0xAC00905C
	directfb_addrs[0] = memregs[0x5c>>2];
	lprintf("fb0 is at %08x\n", directfb_addrs[0]);

	Framework2D_UnlockBuffer();

	directfb_ptrs[0] = mmap_phys(directfb_addrs[0], (321*240*2+PAGE_SIZE-1) / PAGE_SIZE);
	if (directfb_ptrs[0] == NULL)
	{
		lprintf("failed to map fb0\n");
		goto fail0;
	}

	// use directx to discover other buffer
	xdump();
	Framework2D_Flip();
	lprintf("---\n");
	xdump();
	exit(1);
	//Framework2D_LockBuffer(1);

	directfb_addrs[1] = memregs[0x5c>>2] + 0x30000;
	lprintf("fb1 is at %08x\n", directfb_addrs[1]);

	//Framework2D_UnlockBuffer();

	directfb_ptrs[1] = mmap_phys(directfb_addrs[1], (321*240*2+PAGE_SIZE-1) / PAGE_SIZE);
	if (directfb_ptrs[1] == NULL)
	{
		lprintf("failed to map fb1\n");
		goto fail1;
	}

	directfb_initialized = 1;
	directfb_sel = 1;
	return 0;

fail1:
	munmap_phys(directfb_ptrs[0]);
fail0:
	munmap_phys((void *)memregs);
	return -1;
}

static void directfb_fini(void)
{
	if (!directfb_initialized) return;

	munmap_phys(directfb_ptrs[0]);
	munmap_phys(directfb_ptrs[1]);
	munmap_phys((void *)memregs);
}

void *directfb_lock(int is_front)
{
	int which;

	if (!directfb_initialized)
		// fall back to directx
		return Framework2D_LockBuffer(is_front);

	if (is_front)
		which = directfb_sel;
	else
		which = directfb_sel ^ 1; // return backbuffer when possible

	return directfb_ptrs[which];
}

void directfb_unlock(void)
{
	if (!directfb_initialized)
		// fall back to directx
		Framework2D_UnlockBuffer();
}

void directfb_flip(void)
{
	if (!directfb_initialized) {
		Framework2D_Flip();
		return;
	}

	directfb_sel ^= 1;
	// doesn't work
	memregs[0x5c>>2] = directfb_addrs[directfb_sel];
}
#endif
