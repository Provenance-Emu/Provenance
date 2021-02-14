/*
 * libretro core glue for PicoDrive
 * (C) notaz, 2013
 * (C) aliaspider, 2016
 * (C) Daniel De Matteis, 2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#define _GNU_SOURCE 1 // mremap
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#ifndef _WIN32
#ifndef NO_MMAP
#include <sys/mman.h>
#endif
#else
#include <io.h>
#include <windows.h>
#include <sys/types.h>
#endif
#include <errno.h>
#ifdef __MACH__
#include <libkern/OSCacheControl.h>
#endif

#ifdef _3DS
#include "3ds/3ds_utils.h"
#define MEMOP_MAP     4
#define MEMOP_UNMAP   5
#define MEMOP_PROT    6

int svcDuplicateHandle(unsigned int* out, unsigned int original);
int svcCloseHandle(unsigned int handle);
int svcControlProcessMemory(unsigned int process, void* addr0, void* addr1,
                            unsigned int size, unsigned int type, unsigned int perm);
void* linearMemAlign(size_t size, size_t alignment);
void linearFree(void* mem);

static int ctr_svchack_successful = 0;

#elif defined(VITA)
#define TARGET_SIZE_2 24 // 2^24 = 16 megabytes

#include <psp2/kernel/sysmem.h>
static int sceBlock;
int getVMBlock();
int _newlib_vm_size_user = 1 << TARGET_SIZE_2;

#endif

#include <pico/pico_int.h>
#include <pico/state.h>
#include <pico/patch.h>
#include "../common/input_pico.h"
#include "../common/version.h"
#include "libretro.h"

static retro_log_printf_t log_cb;
static retro_video_refresh_t video_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static retro_environment_t environ_cb;
static retro_audio_sample_batch_t audio_batch_cb;

#define VOUT_MAX_WIDTH 320
#define VOUT_MAX_HEIGHT 240

static const float VOUT_PAR = 0.0;
static const float VOUT_4_3 = (224.0f * (4.0f / 3.0f));
static const float VOUT_CRT = (224.0f * 1.29911f);

bool show_overscan = false;

static void *vout_buf;
static int vout_width, vout_height, vout_offset;
static float user_vout_width = 0.0;

static short ALIGNED(4) sndBuffer[2*44100/50];

static void snd_write(int len);

#ifdef _WIN32
#define SLASH '\\'
#else
#define SLASH '/'
#endif

/* functions called by the core */

void cache_flush_d_inval_i(void *start, void *end)
{
#ifdef __arm__
   size_t len = (char *)end - (char *)start;
   (void)len;
#if defined(__BLACKBERRY_QNX__)
   msync(start, end - start, MS_SYNC | MS_CACHE_ONLY | MS_INVALIDATE_ICACHE);
#elif defined(__MACH__)
   sys_dcache_flush(start, len);
   sys_icache_invalidate(start, len);
#elif defined(_3DS)
   ctr_flush_invalidate_cache();
#elif defined(VITA)
   sceKernelSyncVMDomain(sceBlock, start, len);
#else
   __clear_cache(start, end);
#endif
#endif
}

#ifdef _WIN32
/* mmap() replacement for Windows
 *
 * Author: Mike Frysinger <vapier@gentoo.org>
 * Placed into the public domain
 */

/* References:
 * CreateFileMapping: http://msdn.microsoft.com/en-us/library/aa366537(VS.85).aspx
 * CloseHandle:       http://msdn.microsoft.com/en-us/library/ms724211(VS.85).aspx
 * MapViewOfFile:     http://msdn.microsoft.com/en-us/library/aa366761(VS.85).aspx
 * UnmapViewOfFile:   http://msdn.microsoft.com/en-us/library/aa366882(VS.85).aspx
 */

#define PROT_READ     0x1
#define PROT_WRITE    0x2
/* This flag is only available in WinXP+ */
#ifdef FILE_MAP_EXECUTE
#define PROT_EXEC     0x4
#else
#define PROT_EXEC        0x0
#define FILE_MAP_EXECUTE 0
#endif

#define MAP_SHARED    0x01
#define MAP_PRIVATE   0x02
#define MAP_ANONYMOUS 0x20
#define MAP_ANON      MAP_ANONYMOUS
#define MAP_FAILED    ((void *) -1)

#ifdef __USE_FILE_OFFSET64
# define DWORD_HI(x) (x >> 32)
# define DWORD_LO(x) ((x) & 0xffffffff)
#else
# define DWORD_HI(x) (0)
# define DWORD_LO(x) (x)
#endif

static void *mmap(void *start, size_t length, int prot, int flags, int fd, off_t offset)
{
   uint32_t flProtect, dwDesiredAccess;
   off_t end;
   HANDLE mmap_fd, h;
   void *ret;

   if (prot & ~(PROT_READ | PROT_WRITE | PROT_EXEC))
      return MAP_FAILED;
   if (fd == -1) {
      if (!(flags & MAP_ANON) || offset)
         return MAP_FAILED;
   } else if (flags & MAP_ANON)
      return MAP_FAILED;

   if (prot & PROT_WRITE) {
      if (prot & PROT_EXEC)
         flProtect = PAGE_EXECUTE_READWRITE;
      else
         flProtect = PAGE_READWRITE;
   } else if (prot & PROT_EXEC) {
      if (prot & PROT_READ)
         flProtect = PAGE_EXECUTE_READ;
      else if (prot & PROT_EXEC)
         flProtect = PAGE_EXECUTE;
   } else
      flProtect = PAGE_READONLY;

   end = length + offset;

   if (fd == -1)
      mmap_fd = INVALID_HANDLE_VALUE;
   else
      mmap_fd = (HANDLE)_get_osfhandle(fd);
   h = CreateFileMapping(mmap_fd, NULL, flProtect, DWORD_HI(end), DWORD_LO(end), NULL);
   if (h == NULL)
      return MAP_FAILED;

   if (prot & PROT_WRITE)
      dwDesiredAccess = FILE_MAP_WRITE;
   else
      dwDesiredAccess = FILE_MAP_READ;
   if (prot & PROT_EXEC)
      dwDesiredAccess |= FILE_MAP_EXECUTE;
   if (flags & MAP_PRIVATE)
      dwDesiredAccess |= FILE_MAP_COPY;
   ret = MapViewOfFile(h, dwDesiredAccess, DWORD_HI(offset), DWORD_LO(offset), length);
   if (ret == NULL) {
      CloseHandle(h);
      ret = MAP_FAILED;
   }
   return ret;
}

static void munmap(void *addr, size_t length)
{
   UnmapViewOfFile(addr);
   /* ruh-ro, we leaked handle from CreateFileMapping() ... */
}
#elif defined(NO_MMAP)
#define PROT_EXEC   0x04
#define MAP_FAILED 0
#define PROT_READ 0
#define PROT_WRITE 0
#define MAP_PRIVATE 0
#define MAP_ANONYMOUS 0

void* mmap(void *desired_addr, size_t len, int mmap_prot, int mmap_flags, int fildes, size_t off)
{
   return malloc(len);
}

void munmap(void *base_addr, size_t len)
{
   free(base_addr);
}

int mprotect(void *addr, size_t len, int prot)
{
   /* stub - not really needed at this point since this codepath has no dynarecs */
   return 0;
}

#endif

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifdef _3DS
typedef struct
{
   unsigned int requested_map;
   void* buffer;
}pico_mmap_t;

pico_mmap_t pico_mmaps[] = {
   {0x02000000, 0},
   {0x06000000, 0},
   {NULL,       0}
};

void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed)
{
   (void)is_fixed;

   if (ctr_svchack_successful)
   {
      pico_mmap_t* pico_mmap;

      for (pico_mmap = pico_mmaps; pico_mmap->requested_map; pico_mmap++)
      {
         if ((pico_mmap->requested_map == addr))
         {
            unsigned int ptr_aligned, tmp;
            unsigned int currentHandle;
            unsigned int perm = 0b011;

            if (need_exec)
               perm = 0b111;

            size = (size + 0xFFF) & ~0xFFF;
            pico_mmap->buffer = malloc(size + 0x1000);
            ptr_aligned = (((unsigned int)pico_mmap->buffer) + 0xFFF) & ~0xFFF;

            svcDuplicateHandle(&currentHandle, 0xFFFF8001);

            if(svcControlProcessMemory(currentHandle, pico_mmap->requested_map, ptr_aligned, size, MEMOP_MAP, perm) < 0)
            {
               if (log_cb)
                  log_cb(RETRO_LOG_ERROR, "could not map memory @0x%08X\n", pico_mmap->requested_map);
               exit(1);
            }

            svcCloseHandle(currentHandle);
            return (void*)pico_mmap->requested_map;
         }
      }
   }

   return malloc(size);
}

void *plat_mremap(void *ptr, size_t oldsize, size_t newsize)
{
   if (ctr_svchack_successful)
   {
      pico_mmap_t* pico_mmap;

      for (pico_mmap = pico_mmaps; pico_mmap->requested_map; pico_mmap++)
      {
         if ((pico_mmap->requested_map == (unsigned int)ptr))
         {
            unsigned int ptr_aligned;
            unsigned int currentHandle;
            void* tmp;

            oldsize = (oldsize + 0xFFF) & ~0xFFF;
            newsize = (newsize + 0xFFF) & ~0xFFF;
            ptr_aligned = (((unsigned int)pico_mmap->buffer) + 0xFFF) & ~0xFFF;

            svcDuplicateHandle(&currentHandle, 0xFFFF8001);

            svcControlProcessMemory(currentHandle, pico_mmap->requested_map, ptr_aligned, oldsize, MEMOP_UNMAP, 0b011);

            tmp = realloc(pico_mmap->buffer, newsize + 0x1000);
            if(!tmp)
               return NULL;

            pico_mmap->buffer = tmp;
            ptr_aligned = (((unsigned int)pico_mmap->buffer) + 0xFFF) & ~0xFFF;

            svcControlProcessMemory(currentHandle, pico_mmap->requested_map, ptr_aligned, newsize, MEMOP_MAP, 0x3);

            svcCloseHandle(currentHandle);

            return ptr;
         }
      }
   }

   return realloc(ptr, newsize);

}
void plat_munmap(void *ptr, size_t size)
{
   if (ctr_svchack_successful)
   {
      pico_mmap_t* pico_mmap;

      for (pico_mmap = pico_mmaps; pico_mmap->requested_map; pico_mmap++)
      {
         if ((pico_mmap->requested_map == (unsigned int)ptr))
         {
            unsigned int ptr_aligned;
            unsigned int currentHandle;

            size = (size + 0xFFF) & ~0xFFF;
            ptr_aligned = (((unsigned int)pico_mmap->buffer) + 0xFFF) & ~0xFFF;

            svcDuplicateHandle(&currentHandle, 0xFFFF8001);

            svcControlProcessMemory(currentHandle, (void*)pico_mmap->requested_map, (void*)ptr_aligned, size, MEMOP_UNMAP, 0b011);

            svcCloseHandle(currentHandle);

            free(pico_mmap->buffer);
            pico_mmap->buffer = NULL;
            return;
         }
      }
   }

   free(ptr);
}

#else
void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed)
{
   int flags = MAP_PRIVATE | MAP_ANONYMOUS;
   void *req, *ret;

   req = (void *)(uintptr_t)addr;
   ret = mmap(req, size, PROT_READ | PROT_WRITE, flags, -1, 0);
   if (ret == MAP_FAILED) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "mmap(%08lx, %zd) failed: %d\n", addr, size, errno);
      return NULL;
   }

   if (addr != 0 && ret != (void *)(uintptr_t)addr) {
      if (log_cb)
         log_cb(RETRO_LOG_WARN, "warning: wanted to map @%08lx, got %p\n",
               addr, ret);

      if (is_fixed) {
         munmap(ret, size);
         return NULL;
      }
   }

   return ret;
}

void *plat_mremap(void *ptr, size_t oldsize, size_t newsize)
{
#ifdef __linux__
   void *ret = mremap(ptr, oldsize, newsize, 0);
   if (ret == MAP_FAILED)
      return NULL;

   return ret;
#else
   void *tmp, *ret;
   size_t preserve_size;

   preserve_size = oldsize;
   if (preserve_size > newsize)
      preserve_size = newsize;
   tmp = malloc(preserve_size);
   if (tmp == NULL)
      return NULL;
   memcpy(tmp, ptr, preserve_size);

   munmap(ptr, oldsize);
   ret = mmap(ptr, newsize, PROT_READ | PROT_WRITE,
         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
   if (ret == MAP_FAILED) {
      free(tmp);
      return NULL;
   }
   memcpy(ret, tmp, preserve_size);
   free(tmp);
   return ret;
#endif
}

void plat_munmap(void *ptr, size_t size)
{
   if (ptr != NULL)
      munmap(ptr, size);
}
#endif

// if NULL is returned, static buffer is used
void *plat_mem_get_for_drc(size_t size)
{
   void *mem = NULL;
#ifdef VITA
   sceKernelGetMemBlockBase(sceBlock, &mem);
#endif
   return mem;
}

int plat_mem_set_exec(void *ptr, size_t size)
{
   int ret = -1;
#ifdef _WIN32
   DWORD oldProtect = 0;
   ret = VirtualProtect(ptr, size, PAGE_EXECUTE_READWRITE, &oldProtect);
   if (ret == 0 && log_cb)
      log_cb(RETRO_LOG_ERROR, "VirtualProtect(%p, %d) failed: %d\n", ptr, (int)size,
             GetLastError());
#elif defined(_3DS)
   if (ctr_svchack_successful)
   {
      unsigned int currentHandle;
      svcDuplicateHandle(&currentHandle, 0xFFFF8001);
      ret = svcControlProcessMemory(currentHandle, ptr, 0x0,
                              size, MEMOP_PROT, 0b111);
      svcCloseHandle(currentHandle);
      ctr_flush_invalidate_cache();

   }
   else
   {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "plat_mem_set_exec called with no svcControlProcessMemory access\n");
      exit(1);
   }

#elif defined(VITA)
   ret = sceKernelOpenVMDomain();
#else
   ret = mprotect(ptr, size, PROT_READ | PROT_WRITE | PROT_EXEC);
   if (ret != 0 && log_cb)
      log_cb(RETRO_LOG_ERROR, "mprotect(%p, %zd) failed: %d\n", ptr, size, errno);
#endif
   return ret;
}

void emu_video_mode_change(int start_line, int line_count, int is_32cols)
{
   struct retro_system_av_info av_info;

   memset(vout_buf, 0, 320 * 240 * 2);
   vout_width = is_32cols ? 256 : 320;
   PicoDrawSetOutBuf(vout_buf, vout_width * 2);
   if (show_overscan == true) line_count += 16;
   if (show_overscan == true) start_line -= 8;

   vout_height = line_count;
   vout_offset = vout_width * start_line;

   // Update the geometry
   retro_get_system_av_info(&av_info);
   environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &av_info);
}

void emu_32x_startup(void)
{
}

void lprintf(const char *fmt, ...)
{
   char buffer[256];
   va_list ap;
   va_start(ap, fmt);
   vsprintf(buffer, fmt, ap);
   /* TODO - add 'level' param for warning/error messages? */
   if (log_cb)
      log_cb(RETRO_LOG_INFO, "%s", buffer);
   va_end(ap);
}

/* libretro */
void retro_set_environment(retro_environment_t cb)
{
   static const struct retro_variable vars[] = {
      { "picodrive_input1",      "Input device 1; 3 button pad|6 button pad|None" },
      { "picodrive_input2",      "Input device 2; 3 button pad|6 button pad|None" },
      { "picodrive_sprlim",      "No sprite limit; disabled|enabled" },
      { "picodrive_ramcart",     "MegaCD RAM cart; disabled|enabled" },
      { "picodrive_region",      "Region; Auto|Japan NTSC|Japan PAL|US|Europe" },
      { "picodrive_aspect",      "Core-provided aspect ratio; PAR|4/3|CRT" },
      { "picodrive_overscan",    "Show Overscan; disabled|enabled" },
      { "picodrive_overclk68k",  "68k overclock; disabled|+25%|+50%|+75%|+100%|+200%|+400%" },
#ifdef DRC_SH2
      { "picodrive_drc", "Dynamic recompilers; enabled|disabled" },
#endif
      { NULL, NULL },
   };

   environ_cb = cb;

   cb(RETRO_ENVIRONMENT_SET_VARIABLES, (void *)vars);
}

void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) { (void)cb; }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }
void retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }

unsigned retro_api_version(void)
{
   return RETRO_API_VERSION;
}

void retro_set_controller_port_device(unsigned port, unsigned device)
{
}

void retro_get_system_info(struct retro_system_info *info)
{
   memset(info, 0, sizeof(*info));
   info->library_name = "PicoDrive";
#ifndef GIT_VERSION
#define GIT_VERSION ""
#endif
   info->library_version = VERSION GIT_VERSION;
   info->valid_extensions = "bin|gen|smd|md|32x|cue|iso|sms";
   info->need_fullpath = true;
}

void retro_get_system_av_info(struct retro_system_av_info *info)
{
   float common_width;

   memset(info, 0, sizeof(*info));
   info->timing.fps            = Pico.m.pal ? 50 : 60;
   info->timing.sample_rate    = 44100;
   info->geometry.base_width   = vout_width;
   info->geometry.base_height  = vout_height;
   info->geometry.max_width    = vout_width;
   info->geometry.max_height   = vout_height;

   common_width = vout_width;
   if (user_vout_width != 0)
      common_width = user_vout_width;

   info->geometry.aspect_ratio = common_width / vout_height;
}

/* savestates */
struct savestate_state {
   const char *load_buf;
   char *save_buf;
   size_t size;
   size_t pos;
};

size_t state_read(void *p, size_t size, size_t nmemb, void *file)
{
   struct savestate_state *state = file;
   size_t bsize = size * nmemb;

   if (state->pos + bsize > state->size) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "savestate error: %u/%u\n",
               state->pos + bsize, state->size);
      bsize = state->size - state->pos;
      if ((int)bsize <= 0)
         return 0;
   }

   memcpy(p, state->load_buf + state->pos, bsize);
   state->pos += bsize;
   return bsize;
}

size_t state_write(void *p, size_t size, size_t nmemb, void *file)
{
   struct savestate_state *state = file;
   size_t bsize = size * nmemb;

   if (state->pos + bsize > state->size) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "savestate error: %u/%u\n",
               state->pos + bsize, state->size);
      bsize = state->size - state->pos;
      if ((int)bsize <= 0)
         return 0;
   }

   memcpy(state->save_buf + state->pos, p, bsize);
   state->pos += bsize;
   return bsize;
}

size_t state_skip(void *p, size_t size, size_t nmemb, void *file)
{
   struct savestate_state *state = file;
   size_t bsize = size * nmemb;

   state->pos += bsize;
   return bsize;
}

size_t state_eof(void *file)
{
   struct savestate_state *state = file;

   return state->pos >= state->size;
}

int state_fseek(void *file, long offset, int whence)
{
   struct savestate_state *state = file;

   switch (whence) {
   case SEEK_SET:
      state->pos = offset;
      break;
   case SEEK_CUR:
      state->pos += offset;
      break;
   case SEEK_END:
      state->pos = state->size + offset;
      break;
   }
   return (int)state->pos;
}

/* savestate sizes vary wildly depending if cd/32x or
 * carthw is active, so run the whole thing to get size */
size_t retro_serialize_size(void)
{
   struct savestate_state state = { 0, };
   int ret;

   ret = PicoStateFP(&state, 1, NULL, state_skip, NULL, state_fseek);
   if (ret != 0)
      return 0;

   return state.pos;
}

bool retro_serialize(void *data, size_t size)
{
   struct savestate_state state = { 0, };
   int ret;

   state.save_buf = data;
   state.size = size;
   state.pos = 0;

   ret = PicoStateFP(&state, 1, NULL, state_write,
      NULL, state_fseek);
   return ret == 0;
}

bool retro_unserialize(const void *data, size_t size)
{
   struct savestate_state state = { 0, };
   int ret;

   state.load_buf = data;
   state.size = size;
   state.pos = 0;

   ret = PicoStateFP(&state, 0, state_read, NULL,
      state_eof, state_fseek);
   return ret == 0;
}

typedef struct patch
{
	unsigned int addr;
	unsigned short data;
	unsigned char comp;
} patch;

extern void decode(char *buff, patch *dest);
extern uint16_t m68k_read16(uint32_t a);
extern void m68k_write16(uint32_t a, uint16_t d);

void retro_cheat_reset(void)
{
	int i=0;
	unsigned int addr;

	for (i = 0; i < PicoPatchCount; i++)
	{
		addr = PicoPatches[i].addr;
		if (addr < Pico.romsize) {
			if (PicoPatches[i].active)
				*(unsigned short *)(Pico.rom + addr) = PicoPatches[i].data_old;
		} else {
			if (PicoPatches[i].active)
				m68k_write16(PicoPatches[i].addr,PicoPatches[i].data_old);
		}
	}

	PicoPatchUnload();
}

void retro_cheat_set(unsigned index, bool enabled, const char *code)
{
	patch pt;
	int array_len = PicoPatchCount;
	char codeCopy[256];
	char *buff;

	if (code=='\0') return;
	strcpy(codeCopy,code);
	buff = strtok(codeCopy,"+");

	while (buff != NULL)
	{
		decode(buff, &pt);
		if (pt.addr == (uint32_t) -1 || pt.data == (uint16_t) -1)
		{
			log_cb(RETRO_LOG_ERROR,"CHEATS: Invalid code: %s\n",buff);
			return;
		}

		/* code was good, add it */
		if (array_len < PicoPatchCount + 1)
		{
			void *ptr;
			array_len *= 2;
			array_len++;
			ptr = realloc(PicoPatches, array_len * sizeof(PicoPatches[0]));
			if (ptr == NULL) {
				log_cb(RETRO_LOG_ERROR,"CHEATS: Failed to allocate memory for: %s\n",buff);
				return;
			}
			PicoPatches = ptr;
		}
		strcpy(PicoPatches[PicoPatchCount].code, buff);

		PicoPatches[PicoPatchCount].active = enabled;
		PicoPatches[PicoPatchCount].addr = pt.addr;
		PicoPatches[PicoPatchCount].data = pt.data;
		PicoPatches[PicoPatchCount].comp = pt.comp;
		if (PicoPatches[PicoPatchCount].addr < Pico.romsize)
			PicoPatches[PicoPatchCount].data_old = *(uint16_t *)(Pico.rom + PicoPatches[PicoPatchCount].addr);
		else
			PicoPatches[PicoPatchCount].data_old = (uint16_t) m68k_read16(PicoPatches[PicoPatchCount].addr);
		PicoPatchCount++;

		buff = strtok(NULL,"+");
	}
}

/* multidisk support */
static bool disk_ejected;
static unsigned int disk_current_index;
static unsigned int disk_count;
static struct disks_state {
   char *fname;
} disks[8];

static bool disk_set_eject_state(bool ejected)
{
   // TODO?
   disk_ejected = ejected;
   return true;
}

static bool disk_get_eject_state(void)
{
   return disk_ejected;
}

static unsigned int disk_get_image_index(void)
{
   return disk_current_index;
}

static bool disk_set_image_index(unsigned int index)
{
   enum cd_img_type cd_type;
   int ret;

   if (index >= sizeof(disks) / sizeof(disks[0]))
      return false;

   if (disks[index].fname == NULL) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "missing disk #%u\n", index);

      // RetroArch specifies "no disk" with index == count,
      // so don't fail here..
      disk_current_index = index;
      return true;
   }

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "switching to disk %u: \"%s\"\n", index,
            disks[index].fname);

   ret = -1;
   cd_type = PicoCdCheck(disks[index].fname, NULL);
   if (cd_type != CIT_NOT_CD)
      ret = cdd_load(disks[index].fname, cd_type);
   if (ret != 0) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "Load failed, invalid CD image?\n");
      return 0;
   }

   disk_current_index = index;
   return true;
}

static unsigned int disk_get_num_images(void)
{
   return disk_count;
}

static bool disk_replace_image_index(unsigned index,
   const struct retro_game_info *info)
{
   bool ret = true;

   if (index >= sizeof(disks) / sizeof(disks[0]))
      return false;

   if (disks[index].fname != NULL)
      free(disks[index].fname);
   disks[index].fname = NULL;

   if (info != NULL) {
      disks[index].fname = strdup(info->path);
      if (index == disk_current_index)
         ret = disk_set_image_index(index);
   }

   return ret;
}

static bool disk_add_image_index(void)
{
   if (disk_count >= sizeof(disks) / sizeof(disks[0]))
      return false;

   disk_count++;
   return true;
}

static struct retro_disk_control_callback disk_control = {
   disk_set_eject_state,
   disk_get_eject_state,
   disk_get_image_index,
   disk_set_image_index,
   disk_get_num_images,
   disk_replace_image_index,
   disk_add_image_index,
};

static void disk_tray_open(void)
{
   if (log_cb)
      log_cb(RETRO_LOG_INFO, "cd tray open\n");
   disk_ejected = 1;
}

static void disk_tray_close(void)
{
   if (log_cb)
      log_cb(RETRO_LOG_INFO, "cd tray close\n");
   disk_ejected = 0;
}


static const char * const biosfiles_us[] = {
   "us_scd2_9306", "SegaCDBIOS9303", "us_scd1_9210", "bios_CD_U"
};
static const char * const biosfiles_eu[] = {
   "eu_mcd2_9306", "eu_mcd2_9303", "eu_mcd1_9210", "bios_CD_E"
};
static const char * const biosfiles_jp[] = {
   "jp_mcd2_921222", "jp_mcd1_9112", "jp_mcd1_9111", "bios_CD_J"
};

static void make_system_path(char *buf, size_t buf_size,
   const char *name, const char *ext)
{
   const char *dir = NULL;

   if (environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &dir) && dir) {
      snprintf(buf, buf_size, "%s%c%s%s", dir, SLASH, name, ext);
   }
   else {
      snprintf(buf, buf_size, "%s%s", name, ext);
   }
}

static const char *find_bios(int *region, const char *cd_fname)
{
   const char * const *files;
   static char path[256];
   int i, count;
   FILE *f = NULL;

   if (*region == 4) { // US
      files = biosfiles_us;
      count = sizeof(biosfiles_us) / sizeof(char *);
   } else if (*region == 8) { // EU
      files = biosfiles_eu;
      count = sizeof(biosfiles_eu) / sizeof(char *);
   } else if (*region == 1 || *region == 2) {
      files = biosfiles_jp;
      count = sizeof(biosfiles_jp) / sizeof(char *);
   } else {
      return NULL;
   }

   for (i = 0; i < count; i++)
   {
      make_system_path(path, sizeof(path), files[i], ".bin");
      f = fopen(path, "rb");
      if (f != NULL)
         break;

      make_system_path(path, sizeof(path), files[i], ".zip");
      f = fopen(path, "rb");
      if (f != NULL)
         break;
   }

   if (f != NULL) {
      if (log_cb)
         log_cb(RETRO_LOG_INFO, "using bios: %s\n", path);
      fclose(f);
      return path;
   }

   return NULL;
}

bool retro_load_game(const struct retro_game_info *info)
{
   enum media_type_e media_type;
   static char carthw_path[256];
   size_t i;

//   struct retro_input_descriptor desc[] = {
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,"Mode" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },
//
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,"Mode" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },
//
//      { 0 },
//   };

//   struct retro_input_descriptor desc_sms[] = {
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "Button 1 Start" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "Button 2" },
//      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Button Pause" },
//
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "Button 1 Start" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "Button 2" },
//      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Button Pause" },
//
//      { 0 },
//   };

   enum retro_pixel_format fmt = RETRO_PIXEL_FORMAT_RGB565;
   if (!environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &fmt)) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "RGB565 support required, sorry\n");
      return false;
   }

   if (info == NULL || info->path == NULL) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "info->path required\n");
      return false;
   }

   for (i = 0; i < sizeof(disks) / sizeof(disks[0]); i++) {
      if (disks[i].fname != NULL) {
         free(disks[i].fname);
         disks[i].fname = NULL;
      }
   }

   disk_current_index = 0;
   disk_count = 1;
   disks[0].fname = strdup(info->path);

   make_system_path(carthw_path, sizeof(carthw_path), "carthw", ".cfg");

   media_type = PicoLoadMedia(info->path, carthw_path,
         find_bios, NULL);

   switch (media_type) {
   case PM_BAD_DETECT:
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "Failed to detect ROM/CD image type.\n");
      return false;
   case PM_BAD_CD:
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "Invalid CD image\n");
      return false;
   case PM_BAD_CD_NO_BIOS:
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "Missing BIOS\n");
      return false;
   case PM_ERROR:
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "Load error\n");
      return false;
   default:
      break;
   }

//   if (media_type == PM_MARK3)
//      environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc_sms);
//   else
//      environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc);

   PicoLoopPrepare();

   PicoIn.writeSound = snd_write;
   memset(sndBuffer, 0, sizeof(sndBuffer));
   PicoIn.sndOut = sndBuffer;
   PsndRerate(0);

   return true;
}

bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info)
{
   return false;
}

void retro_unload_game(void)
{
}

unsigned retro_get_region(void)
{
   return Pico.m.pal ? RETRO_REGION_PAL : RETRO_REGION_NTSC;
}

void *retro_get_memory_data(unsigned type)
{
   uint8_t* data;

   switch(type)
   {
      case RETRO_MEMORY_SAVE_RAM:
         if (PicoIn.AHW & PAHW_MCD)
            data = Pico_mcd->bram;
         else
            data = Pico.sv.data;
         break;
      case RETRO_MEMORY_SYSTEM_RAM:
         if (PicoIn.AHW & PAHW_SMS)
            data = PicoMem.zram;
         else
            data = PicoMem.ram;
         break;
      default:
         data = NULL;
         break;
   }

   return data;
}

size_t retro_get_memory_size(unsigned type)
{
   unsigned int i;
   int sum;

   switch(type)
   {
//      case RETRO_MEMORY_SAVE_RAM:
//         if (PicoIn.AHW & PAHW_MCD)
//            // bram
//            return 0x2000;

         if (Pico.m.frame_count == 0)
            return Pico.sv.size;

         // if game doesn't write to sram, don't report it to
         // libretro so that RA doesn't write out zeroed .srm
           for (i = 0, sum = 0; i < Pico.sv.size; i++) {
            sum |= Pico.sv.data[i];
           }
         return (sum != 0) ? Pico.sv.size : 0;

      case RETRO_MEMORY_SYSTEM_RAM:
         if (PicoIn.AHW & PAHW_SMS)
            return 0x2000;
         else
            return sizeof(PicoMem.ram);

      default:
         return 0;
   }


}

void retro_reset(void)
{
   PicoReset();
}

static const unsigned short retro_pico_map[] = {
    1 << GBTN_UP,
    1 << GBTN_DOWN,
    1 << GBTN_LEFT,
    1 << GBTN_RIGHT,
    1 << GBTN_A,
    1 << GBTN_B,
    1 << GBTN_C,
    1 << GBTN_X,
    1 << GBTN_Y,
    1 << GBTN_Z,
    1 << GBTN_START,
    1 << GBTN_MODE,  
};
#define RETRO_PICO_MAP_LEN (sizeof(retro_pico_map) / sizeof(retro_pico_map[0]))

static void snd_write(int len)
{
   audio_batch_cb(PicoIn.sndOut, len / 4);
}

static enum input_device input_name_to_val(const char *name)
{
   if (strcmp(name, "3 button pad") == 0)
      return PICO_INPUT_PAD_3BTN;
   if (strcmp(name, "6 button pad") == 0)
      return PICO_INPUT_PAD_6BTN;
   if (strcmp(name, "None") == 0)
      return PICO_INPUT_NOTHING;

   if (log_cb)
      log_cb(RETRO_LOG_WARN, "invalid picodrive_input: '%s'\n", name);
   return PICO_INPUT_PAD_3BTN;
}

static void update_variables(void)
{
   struct retro_variable var;
   int OldPicoRegionOverride;
   float old_user_vout_width;

   var.value = NULL;
   var.key = "picodrive_input1";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
      PicoSetInputDevice(0, input_name_to_val(var.value));

   var.value = NULL;
   var.key = "picodrive_input2";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
      PicoSetInputDevice(1, input_name_to_val(var.value));

   var.value = NULL;
   var.key = "picodrive_sprlim";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         PicoIn.opt |= POPT_DIS_SPRITE_LIM;
      else
         PicoIn.opt &= ~POPT_DIS_SPRITE_LIM;
   }

   var.value = NULL;
   var.key = "picodrive_ramcart";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         PicoIn.opt |= POPT_EN_MCD_RAMCART;
      else
         PicoIn.opt &= ~POPT_EN_MCD_RAMCART;
   }

   OldPicoRegionOverride = PicoIn.regionOverride;
   var.value = NULL;
   var.key = "picodrive_region";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "Auto") == 0)
         PicoIn.regionOverride = 0;
      else if (strcmp(var.value, "Japan NTSC") == 0)
         PicoIn.regionOverride = 1;
      else if (strcmp(var.value, "Japan PAL") == 0)
         PicoIn.regionOverride = 2;
      else if (strcmp(var.value, "US") == 0)
         PicoIn.regionOverride = 4;
      else if (strcmp(var.value, "Europe") == 0)
         PicoIn.regionOverride = 8;
   }

   // Update region, fps and sound flags if needed
   if (Pico.rom && PicoIn.regionOverride != OldPicoRegionOverride)
   {
      PicoDetectRegion();
      PicoLoopPrepare();
      PsndRerate(1);
   }

   old_user_vout_width = user_vout_width;
   var.value = NULL;
   var.key = "picodrive_aspect";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "4/3") == 0)
         user_vout_width = VOUT_4_3;
      else if (strcmp(var.value, "CRT") == 0)
         user_vout_width = VOUT_CRT;
      else
         user_vout_width = VOUT_PAR;
   }

   var.value = NULL;
   var.key = "picodrive_overscan";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         show_overscan = true;
      else
         show_overscan = false;
   }

   if (user_vout_width != old_user_vout_width)
   {
      // Update the geometry
      struct retro_system_av_info av_info;
      retro_get_system_av_info(&av_info);
      environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &av_info);
   }

   var.value = NULL;
   var.key = "picodrive_overclk68k";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      PicoIn.overclockM68k = 0;
      if (var.value[0] == '+')
         PicoIn.overclockM68k = atoi(var.value + 1);
   }

#ifdef DRC_SH2
   var.value = NULL;
   var.key = "picodrive_drc";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         PicoIn.opt |= POPT_EN_DRC;
      else
         PicoIn.opt &= ~POPT_EN_DRC;
   }
#endif
#ifdef _3DS
   if(!ctr_svchack_successful)
      PicoIn.opt &= ~POPT_EN_DRC;
#endif
}

void retro_run(void)
{
   bool updated = false;
   int pad, i;

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated)
      update_variables();

   input_poll_cb();

   PicoIn.pad[0] = PicoIn.pad[1] = 0;
   for (pad = 0; pad < 2; pad++)
      for (i = 0; i < RETRO_PICO_MAP_LEN; i++)
         if (input_state_cb(pad, RETRO_DEVICE_JOYPAD, 0, i))
            PicoIn.pad[pad] |= retro_pico_map[i];

   PicoPatchApply();
   PicoFrame();

   video_cb((short *)vout_buf + vout_offset,
      vout_width, vout_height, vout_width * 2);
}

void retro_init(void)
{
   struct retro_log_callback log;
   int level;

   level = 0;
   environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);

   if (environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
      log_cb = log.log;
   else
      log_cb = NULL;

   environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE, &disk_control);

#ifdef _3DS
   ctr_svchack_successful = ctr_svchack_init();
#elif defined(VITA)
   sceBlock = getVMBlock();
#endif

   PicoIn.opt = POPT_EN_STEREO|POPT_EN_FM|POPT_EN_PSG|POPT_EN_Z80
      | POPT_EN_MCD_PCM|POPT_EN_MCD_CDDA|POPT_EN_MCD_GFX
      | POPT_EN_32X|POPT_EN_PWM
      | POPT_ACC_SPRITES|POPT_DIS_32C_BORDER;
#ifdef __arm__
#ifdef _3DS
   if (ctr_svchack_successful)
#endif
      PicoIn.opt |= POPT_EN_DRC;
#endif
   PicoIn.sndRate = 44100;
   PicoIn.autoRgnOrder = 0x184; // US, EU, JP

   vout_width = 320;
   vout_height = 240;
#ifdef _3DS
   vout_buf = linearMemAlign(VOUT_MAX_WIDTH * VOUT_MAX_HEIGHT * 2, 0x80);
#else
   vout_buf = malloc(VOUT_MAX_WIDTH * VOUT_MAX_HEIGHT * 2);
#endif

   PicoInit();
   PicoDrawSetOutFormat(PDF_RGB555, 0);
   PicoDrawSetOutBuf(vout_buf, vout_width * 2);

   //PicoIn.osdMessage = plat_status_msg_busy_next;
   PicoIn.mcdTrayOpen = disk_tray_open;
   PicoIn.mcdTrayClose = disk_tray_close;

   //update_variables();
    PicoSetInputDevice(0, PICO_INPUT_PAD_6BTN);
    PicoSetInputDevice(1, PICO_INPUT_PAD_6BTN);
}

void retro_deinit(void)
{
#ifdef _3DS
   linearFree(vout_buf);
#else
   free(vout_buf);
#endif
   vout_buf = NULL;
   PicoExit();
}

// vim:shiftwidth=3:ts=3:expandtab
