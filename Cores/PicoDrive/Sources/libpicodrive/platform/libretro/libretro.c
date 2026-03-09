/*
 * libretro core glue for PicoDrive
 * (C) notaz, 2013
 * (C) aliaspider, 2016
 * (C) Daniel De Matteis, 2013
 * (C) irixxxx, 2020-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#define _GNU_SOURCE 1 // mremap
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#ifdef __MACH__
#include <libkern/OSCacheControl.h>
#endif

#include "libretro-common/include/formats/image.h" // really, for IMAGE_PROCESS_NEXT?!?
#include "libretro-common/include/formats/rpng.h"
#include "libretro-common/include/file/file_path.h"

#include "libretro-common/include/memmap.h"
/* Ouf, libretro-common defines  replacement functions, but not the flags :-| */
#ifndef PROT_READ
#define PROT_READ      0x1
#define PROT_WRITE     0x2
#define PROT_READWRITE 0x3
#define PROT_EXEC      0x4
#define MAP_FAILED     ((void *) -1)
#define MAP_ANONYMOUS  0x1
#define MAP_PRIVATE    0x2
#endif

#if defined(RENDER_GSKIT_PS2)
#include <malloc.h>
#include <kernel.h>
#include "libretro-common/include/libretro_gskit_ps2.h"
#include "ps2/asm.h"
#else
#include <platform/common/upscale.h>
#endif
#include <platform/common/emu.h>
#include <platform/libpicofe/plat.h> // need this for PXMAKE in readpng :-/

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

#elif defined(__PS3__)
#include <sys/process.h>
#include <ps3mapi_ps3_lib.h>

static uint64_t page_table[2] = {0, 0};
#endif

#include "libretro_core_options.h"

#include <pico/pico_int.h>
#include <pico/state.h>
#include <pico/patch.h>
#include <pico/sound/mix.h>
#include "../common/input_pico.h"
#include "../common/version.h"
#include <libretro.h>
#include <compat/strcasestr.h>

static retro_log_printf_t log_cb;
static retro_video_refresh_t video_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static retro_environment_t environ_cb;
static retro_audio_sample_batch_t audio_batch_cb;

#define VOUT_MAX_WIDTH 320
#define VOUT_MAX_HEIGHT 240

#define SND_RATE_DEFAULT 44100
#define SND_RATE_MAX     53267

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

static const float VOUT_PAR = 0.0;
static const float VOUT_4_3 = (4.0f / 3.0f);
static const float VOUT_CRT = (1.29911f);

/* Required to allow on the fly changes to 'renderer' */
static int vm_current_start_line = -1;
static int vm_current_line_count = -1;
static int vm_current_start_col = -1;
static int vm_current_col_count = -1;

static int vout_16bit = 1;
static int vout_format = PDF_RGB555;
static void *vout_buf, *vout_ghosting_buf;
static int vout_width, vout_height, vout_offset;
static float vout_aspect = 0.0;
static int vout_ghosting = 0;

static bool libretro_update_av_info = false;
static bool libretro_update_geometry = false;

#if defined(RENDER_GSKIT_PS2)
#define VOUT_8BIT_WIDTH 328
#define VOUT_8BIT_HEIGHT 256
RETRO_HW_RENDER_INTEFACE_GSKIT_PS2 *ps2 = NULL;
static void *retro_palette;
static struct retro_hw_ps2_insets padding;
#endif

static short ALIGNED(4) sndBuffer[2*SND_RATE_MAX/50];

static void snd_write(int len);

char **g_argv;

#ifdef _WIN32
#define SLASH '\\'
#else
#define SLASH '/'
#endif

/* Frameskipping Support */

static unsigned frameskip_type             = 0;
static unsigned frameskip_threshold        = 0;
static uint16_t frameskip_counter          = 0;

static bool retro_audio_buff_active        = false;
static unsigned retro_audio_buff_occupancy = 0;
static bool retro_audio_buff_underrun      = false;
/* Maximum number of consecutive frames that
 * can be skipped */
#define FRAMESKIP_MAX 60

static unsigned audio_latency              = 0;
static bool update_audio_latency           = false;
static uint16_t pico_events;
// Sega Pico stuff
int pico_inp_mode;
int pico_pen_x = 320/2, pico_pen_y = 240/2;
static int pico_page;
static int pico_w, pico_h;
static char pico_overlay_path[PATH_MAX];
static unsigned short *pico_overlay;


static void retro_audio_buff_status_cb(
      bool active, unsigned occupancy, bool underrun_likely)
{
   retro_audio_buff_active    = active;
   retro_audio_buff_occupancy = occupancy;
   retro_audio_buff_underrun  = underrun_likely;
}

static void init_frameskip(void)
{
   if (frameskip_type > 0)
   {
      struct retro_audio_buffer_status_callback buf_status_cb;

      buf_status_cb.callback = retro_audio_buff_status_cb;
      if (!environ_cb(RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK,
            &buf_status_cb))
      {
         if (log_cb)
            log_cb(RETRO_LOG_WARN, "Frameskip disabled - frontend does not support audio buffer status monitoring.\n");

         retro_audio_buff_active    = false;
         retro_audio_buff_occupancy = 0;
         retro_audio_buff_underrun  = false;
         audio_latency              = 0;
      }
      else
      {
         /* Frameskip is enabled - increase frontend
          * audio latency to minimise potential
          * buffer underruns */
         float frame_time_msec = 1000.0f / (Pico.m.pal ? 50.0f : 60.0f);

         /* Set latency to 6x current frame time... */
         audio_latency = (unsigned)((6.0f * frame_time_msec) + 0.5f);

         /* ...then round up to nearest multiple of 32 */
         audio_latency = (audio_latency + 0x1F) & ~0x1F;
      }
   }
   else
   {
      environ_cb(RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK, NULL);
      audio_latency = 0;
   }

   update_audio_latency = true;
}

/* functions called by the core */

void cache_flush_d_inval_i(void *start, void *end)
{
#ifdef __arm__
   size_t len = (char *)end - (char *)start;
#if defined(__BLACKBERRY_QNX__)
   msync(start, len, MS_SYNC | MS_CACHE_ONLY | MS_INVALIDATE_ICACHE);
#elif defined(__MACH__)
   sys_dcache_flush(start, len);
   sys_icache_invalidate(start, len);
#elif defined(_3DS)
   (void)len;
   ctr_flush_invalidate_cache();
#elif defined(VITA)
   sceKernelSyncVMDomain(sceBlock, start, len);
#else
   (void)len;
   __clear_cache(start, end);
#endif
#endif
}

#ifdef RENDER_GSKIT_PS2
/* In PS2 toolchain these aren't yet defined */
void _flush_cache(void *b, void *e)
{
#if 0 /* which of these is overall faster for lots of small cache updates? */
   SyncDCache(b, e);
#else
   FlushCache(0); /* WRITEBACK_DCACHE */
#endif
   FlushCache(2); /* INVALIDATE_ICACHE */
}

int __builtin_parity(unsigned v)
{
   /* credits to bit twiddling hacks, https://graphics.stanford.edu/~seander/bithacks.html */
   v ^= v >> 16;
   v ^= v >> 8;
   v ^= v >> 4;
   return (0x6996 >> (v&0xf)) & 1;
}
#elif defined(PSP)
int _flush_cache(char *addr, const int size, const int op)
{
   //sceKernelDcacheWritebackAll();
   sceKernelDcacheWritebackRange(addr, size);
   sceKernelIcacheInvalidateRange(addr, size);
   return 0;
}
#endif

#ifdef __MACH__
/* calls to this may be generated by the compiler, but it's missing in libc? */
void __clear_cache(void *start, void *end)
{
   size_t len = (char *)end - (char *)start;
   sys_dcache_flush(start, len);
   sys_icache_invalidate(start, len);
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
#if defined(__linux__) && !defined(__SWITCH__)
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
#if defined VITA
   sceKernelGetMemBlockBase(sceBlock, &mem);
#elif defined HW_WUP
   // For WiiU, a slice of RWX memory left from the exploit is used, see:
   // https://github.com/embercold/pcsx_rearmed/commit/af0453223
   mem = (void *)(0x01000000 - size);
#elif defined __PS3__
   ps3mapi_process_page_allocate(sysProcessGetPid(), size, PAGE_SIZE_AUTO, 0x2F, 1, page_table);
   mem = (void *)page_table[0];
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

static void apply_renderer()
{
   PicoIn.opt &= ~(POPT_ALT_RENDERER|POPT_EN_SOFTSCALE);
   PicoIn.opt |= POPT_DIS_32C_BORDER;
   if (vout_format == PDF_NONE)
      PicoIn.opt |= POPT_ALT_RENDERER;
   PicoDrawSetOutFormat(vout_format, 0);
   if (!vout_16bit && vout_format == PDF_8BIT)
      PicoDrawSetOutBuf(Pico.est.Draw2FB, 328);
}

void emu_video_mode_change(int start_line, int line_count, int start_col, int col_count)
{
   vm_current_start_line = start_line;
   vm_current_line_count = line_count;
   vm_current_start_col = start_col;
   vm_current_col_count = col_count;

   // 8bit renderers create a 328x256 CLUT image, 16bit creates 320x240 RGB
#if defined(RENDER_GSKIT_PS2)
   // calculate the borders of the real image inside the picodrive image
   vout_width = (vout_16bit ? VOUT_MAX_WIDTH : VOUT_8BIT_WIDTH);
   vout_height = (vout_16bit ? VOUT_MAX_HEIGHT : VOUT_8BIT_HEIGHT);
   vout_offset = (vout_16bit ? 0 : col_count == 248 ? 16 : 8); // 8bit has overlap area on the left
   padding = (struct retro_hw_ps2_insets){start_line, vout_offset, vout_height - line_count - start_line, vout_width - col_count - vout_offset};

   int pxsz = (vout_16bit ? 2 : 1); // pixel size: RGB = 16 bits, CLUT = 8 bits
   memset(vout_buf, 0, pxsz * vout_width * vout_height);
   memset(retro_palette, 0, gsKit_texture_size_ee(16, 16, GS_PSM_CT16));
   PicoDrawSetOutBuf(vout_buf, pxsz * vout_width);
   if (ps2) {
      // prepare image as texture for rendering
      ps2->coreTexture->Width = vout_width;
      ps2->coreTexture->Height = vout_height;
      ps2->coreTexture->PSM = (vout_16bit ? GS_PSM_CT16 : GS_PSM_T8);
      ps2->padding = padding;
   }
#else
   vout_width = col_count;
   memset(vout_buf, 0, VOUT_MAX_WIDTH * VOUT_MAX_HEIGHT * 2);  
   if (vout_16bit)
      PicoDrawSetOutBuf(vout_buf, vout_width * 2);

   vout_height = line_count;
   /* Note: We multiply by 2 here to account for pitch */
   vout_offset = vout_width * start_line * 2;

   /* Redundant sanity check... */
   vout_height = (vout_height > VOUT_MAX_HEIGHT) ?
         VOUT_MAX_HEIGHT : vout_height;
   vout_offset = (vout_offset > vout_width * (VOUT_MAX_HEIGHT - 1) * 2) ?
         vout_width * (VOUT_MAX_HEIGHT - 1) * 2 : vout_offset;

   /* LCD ghosting */
   if (vout_ghosting && vout_height == 144) {
      vout_ghosting_buf = realloc(vout_ghosting_buf, VOUT_MAX_HEIGHT*vout_width*2);
      memset(vout_ghosting_buf, 0, vout_width*vout_height*2);
   }
#endif
   Pico.m.dirtyPal = 1;

   /* Notify frontend of geometry update */
   libretro_update_geometry = true;
}

void emu_32x_startup(void)
{
   PicoIn.filter = EOPT_FILTER_SMOOTHER; // for H32 upscaling
   PicoDrawSetOutFormat(vout_format, 0);
   vout_16bit = 1;

   if (vout_buf &&
       (vm_current_start_line != -1) && (vm_current_line_count != -1) &&
       (vm_current_start_col != -1) && (vm_current_col_count != -1))
      emu_video_mode_change(
            vm_current_start_line, vm_current_line_count,
            vm_current_start_col, vm_current_col_count);
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
bool libretro_supports_bitmasks = false;

void retro_set_environment(retro_environment_t cb)
{
   bool option_categories_supported;
#ifdef USE_LIBRETRO_VFS
   struct retro_vfs_interface_info vfs_iface_info;
#endif

   static const struct retro_system_content_info_override content_overrides[] = {
      {
         "bin|gen|smd|md|32x|sms|gg|sg|sc|68k|sgd|pco", /* extensions */
#if defined(LOW_MEMORY)
         true,                         /* need_fullpath */
#else
         false,                        /* need_fullpath */
#endif
         false                         /* persistent_data */
      },
      { NULL, false, false }
   };

   environ_cb = cb;

   libretro_set_core_options(environ_cb,
         &option_categories_supported);
   environ_cb(RETRO_ENVIRONMENT_SET_CONTENT_INFO_OVERRIDE,
         (void*)content_overrides);

#ifdef USE_LIBRETRO_VFS
   vfs_iface_info.required_interface_version = 1;
   vfs_iface_info.iface = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VFS_INTERFACE, &vfs_iface_info))
      filestream_vfs_init(&vfs_iface_info);
#endif
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
   info->library_version = VERSION;
   info->valid_extensions = "bin|gen|smd|md|32x|cue|iso|chd|sms|gg|sg|sc|m3u|68k|sgd|pco";
   info->need_fullpath = true;
}

void retro_get_system_av_info(struct retro_system_av_info *info)
{
   float tv_height = (vout_height > 144 ? Pico.m.pal ? 240 : 224 : 144);
   float common_width;

   memset(info, 0, sizeof(*info));
   info->timing.fps            = Pico.m.pal ? 50 : 60;
   info->timing.sample_rate    = PicoIn.sndRate;
   info->geometry.base_width   = vout_width;
   info->geometry.base_height  = vout_height;
   info->geometry.max_width    = vout_width;
   info->geometry.max_height   = vout_height;

   common_width = vout_width;
   if (vout_aspect != 0)
      common_width = vout_aspect * tv_height;

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
   unsigned AHW = PicoIn.AHW;
   int ret;

   /* we need the max possible size here, so include 32X for MD and MCD */
   if (!(AHW & (PAHW_SMS|PAHW_PICO|PAHW_SVP)))
      PicoIn.AHW |= PAHW_32X;
   ret = PicoStateFP(&state, 1, NULL, state_skip, NULL, state_fseek);
   PicoIn.AHW = AHW;
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
extern uint32_t m68k_read16(uint32_t a);
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

	if (*code == '\0')
      return;
	strcpy(codeCopy, code);
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
static unsigned int disk_initial_index;
static bool disk_ejected;
static unsigned int disk_current_index;
static unsigned int disk_count;
static char disk_initial_path[PATH_MAX];
static struct disks_state {
   char *fname;
   char *flabel;
} disks[8];

static void get_disk_label(char *disk_label, const char *disk_path, size_t len)
{
   const char *base = NULL;

   if (!disk_path || (*disk_path == '\0'))
      return;

   base = strrchr(disk_path, SLASH);
   if (!base)
      base = disk_path;

   if (*base == SLASH)
      base++;

   strncpy(disk_label, base, len - 1);
   disk_label[len - 1] = '\0';

   char *ext = strrchr(disk_label, '.');
   if (ext)
      *ext = '\0';
}

static void disk_init(void)
{
   size_t i;

   disk_ejected       = false;
   disk_current_index = 0;
   disk_count         = 0;

   for (i = 0; i < sizeof(disks) / sizeof(disks[0]); i++)
   {
      if (disks[i].fname != NULL)
      {
         free(disks[i].fname);
         disks[i].fname = NULL;
      }
      if (disks[i].flabel != NULL)
      {
         free(disks[i].flabel);
         disks[i].flabel = NULL;
      }
   }
}

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
   enum cd_track_type cd_type;
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
   if (PicoIn.AHW & PAHW_MCD) {
     cd_type = PicoCdCheck(disks[index].fname, NULL);
     if (cd_type >= 0 && cd_type != CT_UNKNOWN)
        ret = cdd_load(disks[index].fname, cd_type);
   }
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
   char *old_fname  = NULL;
   char *old_flabel = NULL;
   bool ret         = true;

   if (index >= sizeof(disks) / sizeof(disks[0]))
      return false;

   old_fname  = disks[index].fname;
   old_flabel = disks[index].flabel;

   if (disks[index].fname != NULL)
      free(disks[index].fname);
   disks[index].fname = NULL;

   if (disks[index].flabel != NULL)
      free(disks[index].flabel);
   disks[index].flabel = NULL;

   if (info != NULL) {
      char disk_label[PATH_MAX];
      disk_label[0] = '\0';

      disks[index].fname = strdup(info->path);

      get_disk_label(disk_label, info->path, PATH_MAX);
      disks[index].flabel = strdup(disk_label);
      
      if (index == disk_current_index)
         ret = disk_set_image_index(index);
   }

   if (old_fname != NULL)
      free(old_fname);

   if (old_flabel != NULL)
      free(old_flabel);

   return ret;
}

static bool disk_add_image_index(void)
{
   if (disk_count >= sizeof(disks) / sizeof(disks[0]))
      return false;

   disk_count++;
   return true;
}

static bool disk_set_initial_image(unsigned index, const char *path)
{
   if (index >= sizeof(disks) / sizeof(disks[0]))
      return false;

   if (!path || (*path == '\0'))
      return false;

   disk_initial_index = index;

   strncpy(disk_initial_path, path, sizeof(disk_initial_path) - 1);
   disk_initial_path[sizeof(disk_initial_path) - 1] = '\0';

   return true;
}

static bool disk_get_image_path(unsigned index, char *path, size_t len)
{
   const char *fname = NULL;

   if (len < 1)
      return false;

   if (index >= sizeof(disks) / sizeof(disks[0]))
      return false;

   fname = disks[index].fname;

   if (!fname || (*fname == '\0'))
      return false;

   strncpy(path, fname, len - 1);
   path[len - 1] = '\0';

   return true;
}

static bool disk_get_image_label(unsigned index, char *label, size_t len)
{
   const char *flabel = NULL;

   if (len < 1)
      return false;

   if (index >= sizeof(disks) / sizeof(disks[0]))
      return false;

   flabel = disks[index].flabel;

   if (!flabel || (*flabel == '\0'))
      return false;

   strncpy(label, flabel, len - 1);
   label[len - 1] = '\0';

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

static struct retro_disk_control_ext_callback disk_control_ext = {
   .set_eject_state     = disk_set_eject_state,
   .get_eject_state     = disk_get_eject_state,
   .get_image_index     = disk_get_image_index,
   .set_image_index     = disk_set_image_index,
   .get_num_images      = disk_get_num_images,
   .replace_image_index = disk_replace_image_index,
   .add_image_index     = disk_add_image_index,
   .set_initial_image   = disk_set_initial_image,
   .get_image_path      = disk_get_image_path,
   .get_image_label     = disk_get_image_label,
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

static char base_dir[1024];

static void extract_directory(char *buf, const char *path, size_t size)
{
   char *base;
   strncpy(buf, path, size - 1);
   buf[size - 1] = '\0';

   base = strrchr(buf, '/');
   if (!base)
      base = strrchr(buf, '\\');

   if (base)
      *base = '\0';
   else
   {
      buf[0] = '.';
      buf[1] = '\0';
   }
}

static void extract_basename(char *buf, const char *path, size_t size)
{
   const char *base = strrchr(path, '/');
   if (!base)
      base = strrchr(path, '\\');
   if (!base)
      base = path;

   if (*base == '\\' || *base == '/')
      base++;

   strncpy(buf, base, size - 1);
   buf[size - 1] = '\0';

   char *ext = strrchr(buf, '.');
   if (ext)
      *ext = '\0';
}

static bool read_m3u(const char *file)
{
   char line[1024];
   char name[PATH_MAX];
   FILE *f = fopen(file, "r");
   if (!f)
      return false;

   while (fgets(line, sizeof(line), f) && disk_count < sizeof(disks) / sizeof(disks[0]))
   {
      if (line[0] == '#')
         continue;
      char *carrige_return = strchr(line, '\r');
      if (carrige_return)
         *carrige_return = '\0';
      char *newline = strchr(line, '\n');
      if (newline)
         *newline = '\0';

      if (line[0] != '\0')
      {
         char disk_label[PATH_MAX];
         disk_label[0] = '\0';

         snprintf(name, sizeof(name), "%s%c%s", base_dir, SLASH, line);
         disks[disk_count].fname = strdup(name);

         get_disk_label(disk_label, name, PATH_MAX);
         disks[disk_count].flabel = strdup(disk_label);

         disk_count++;
      }
   }

   fclose(f);
   return (disk_count != 0);
}

/* end of multi disk support */

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

static const char *find_msu(const char *cd_fname)
{
   static char path[256];
   FILE *f = NULL;
   int i;

   // look for MSU.MD rom file. XXX another extension list? ugh...
   static const char *md_exts[] = { "gen", "smd", "md", "32x" };
   char *ext = strrchr(cd_fname, '.');
   int extpos = ext ? ext-cd_fname : strlen(cd_fname);
   strcpy(path, cd_fname);
   path[extpos++] = '.';
   for (i = 0; i < ARRAY_SIZE(md_exts); i++) {
      strcpy(path+extpos, md_exts[i]);
      f = fopen(path, "rb");
      if (f != NULL) {
         log_cb(RETRO_LOG_INFO, "found MSU rom: %s\n", path);
         fclose(f);
         return path;
      }
   }

   return NULL;
}

static void set_memory_maps(void)
{
   if (PicoIn.AHW & PAHW_MCD)
   {
      const size_t SCD_BIT = 1ULL << 31ULL;
      const uint64_t mem = RETRO_MEMDESC_SYSTEM_RAM;
      struct retro_memory_map mmaps;
      struct retro_memory_descriptor descs[] = {
         { mem, PicoMem.ram,        0,           0xFF0000, 0, 0, 0x10000, "68KRAM" },
         /* virtual address using SCD_BIT so all 512M of prg_ram can be accessed */
         /* at address $80020000 */
         { mem, Pico_mcd->prg_ram,  0, SCD_BIT | 0x020000, 0, 0, 0x80000, "PRGRAM" },
      };

      mmaps.descriptors = descs;
      mmaps.num_descriptors = sizeof(descs) / sizeof(descs[0]);
      environ_cb(RETRO_ENVIRONMENT_SET_MEMORY_MAPS, &mmaps);
   }
}

bool retro_load_game(const struct retro_game_info *info)
{
   const struct retro_game_info_ext *info_ext = NULL;
   const unsigned char *content_data          = NULL;
   size_t content_size                        = 0;
   char content_path[PATH_MAX];
   char content_ext[8];
   char carthw_path[PATH_MAX];
   enum media_type_e media_type;
   size_t i;

#if defined(_WIN32)
   char slash      = '\\';
#else
   char slash      = '/';
#endif

   content_path[0] = '\0';
   content_ext[0]  = '\0';
   carthw_path[0]  = '\0';

   unsigned int cd_index = 0;
   bool is_m3u           = false;

   struct retro_input_descriptor desc[] = {
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,"Mode" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },

      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,"Mode" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },


      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,"Mode" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },


      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,"Mode" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },

      { 0 },
   };

   struct retro_input_descriptor desc_sms[] = {
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "Button 1 Start" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "Button 2" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Button Pause" },

      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "Button 1 Start" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "Button 2" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Button Pause" },

      { 0 },
   };

   struct retro_input_descriptor desc_pico[] = {
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left (violet)" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up (white)" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down (orange)" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right (green)" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "Red Button" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "Pen Button" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Pen State" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "Pen on Storyware" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Pen on Pad" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "Previous Page" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Next Page" },

      { 0 },
   };

   /* Attempt to fetch extended game info */
   if (environ_cb(RETRO_ENVIRONMENT_GET_GAME_INFO_EXT, &info_ext))
   {
#if !defined(LOW_MEMORY)
      content_data = (const unsigned char *)info_ext->data;
      content_size = info_ext->size;
#endif
      strncpy(base_dir, info_ext->dir, sizeof(base_dir));
      base_dir[sizeof(base_dir) - 1] = '\0';

      strncpy(content_ext, info_ext->ext, sizeof(content_ext));
      content_ext[sizeof(content_ext) - 1] = '\0';

      if (info_ext->file_in_archive)
      {
         /* We don't have a 'physical' file in this
          * case, but the core still needs a filename
          * in order to detect media type. We therefore
          * fake it, using the content directory,
          * canonical content name, and content file
          * extension */
         snprintf(content_path, sizeof(content_path), "%s%c%s.%s",
               base_dir, slash, info_ext->name, content_ext);
      }
      else
      {
         strncpy(content_path, info_ext->full_path, sizeof(content_path));
         content_path[sizeof(content_path) - 1] = '\0';
      }
   }
   else
   {
      const char *ext = NULL;

      if (!info || !info->path)
      {
         if (log_cb)
            log_cb(RETRO_LOG_ERROR, "info->path required\n");
         return false;
      }

      extract_directory(base_dir, info->path, sizeof(base_dir));

      strncpy(content_path, info->path, sizeof(content_path));
      content_path[sizeof(content_path) - 1] = '\0';

      if ((ext = strrchr(info->path, '.')))
      {
         strncpy(content_ext, ext + 1, sizeof(content_ext));
         content_ext[sizeof(content_ext) - 1] = '\0';
      }
   }

   enum retro_pixel_format fmt = RETRO_PIXEL_FORMAT_RGB565;
   if (!environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &fmt)) {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "RGB565 support required, sorry\n");
      return false;
   }

   disk_init();

   is_m3u = (strcasestr(content_ext, "m3u") != NULL);
   if (is_m3u)
   {
      if (!read_m3u(content_path))
      {
         log_cb(RETRO_LOG_INFO, "failed to read m3u file\n");
         return false;
      }

      strncpy(content_path, disks[0].fname, sizeof(content_path));
      content_path[sizeof(content_path) - 1] = '\0';
   }
   else
   {
      char disk_label[PATH_MAX];
      disk_label[0] = '\0';

      disk_current_index = 0;
      disk_count = 1;
      disks[0].fname = strdup(content_path);

      get_disk_label(disk_label, content_path, PATH_MAX);
      disks[0].flabel = strdup(disk_label);
   }

   /* If this is an M3U file, attempt to set the
    * initial disk image */
   if (is_m3u && (disk_initial_index > 0) && (disk_initial_index < disk_count))
   {
      const char *fname = disks[disk_initial_index].fname;

      if (fname && (*fname != '\0'))
         if (strcmp(disk_initial_path, fname) == 0)
            cd_index = disk_initial_index;

      /* If we are not loading the first disk in the
       * M3U list, update the content_path string
       * that will be passed to PicoLoadMedia() */
      if (cd_index != 0)
      {
         strncpy(content_path, disks[cd_index].fname, sizeof(content_path));
         content_path[sizeof(content_path) - 1] = '\0';
      }
   }

   make_system_path(carthw_path, sizeof(carthw_path), "carthw", ".cfg");

   media_type = PicoLoadMedia(content_path, content_data, content_size,
         carthw_path, find_bios, find_msu, NULL);

   disk_current_index = cd_index;

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

   strncpy(pico_overlay_path, content_path, sizeof(pico_overlay_path)-4);
   if (PicoIn.AHW & PAHW_PICO)
      environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc_pico);
   else if (PicoIn.AHW & PAHW_SMS)
      environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc_sms);
   else
      environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc);

   PicoLoopPrepare();

   PicoIn.writeSound = snd_write;
   memset(sndBuffer, 0, sizeof(sndBuffer));
   PicoIn.sndOut = sndBuffer;
   if (PicoIn.sndRate > 52000 && PicoIn.sndRate < 54000)
      PicoIn.sndRate = YM2612_NATIVE_RATE();
   PsndRerate(0);

   apply_renderer();

   /* Setup retro memory maps */
   set_memory_maps();

   init_frameskip();

   /* Initialisation routines may have 'triggered'
    * a libretro AV info or geometry update; this
    * happens automatically after retro_load_game(),
    * so disable the relevant flags here to avoid
    * redundant updates on the first call of
    * retro_run() */
   libretro_update_av_info = false;
   libretro_update_geometry = false;

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
   void *data;

   switch(type)
   {
      case RETRO_MEMORY_SAVE_RAM:
         /* Note: MCD RAM cart uses Pico.sv.data */
         if ((PicoIn.AHW & PAHW_MCD) && Pico.romsize == 0 &&
               !(PicoIn.opt & POPT_EN_MCD_RAMCART))
            data = Pico_mcd->bram;
         else // TODO: handle copying to/from bram somewhere
            data = Pico.sv.data;
         break;
      case RETRO_MEMORY_SYSTEM_RAM:
         if (PicoIn.AHW & PAHW_SMS)
            data = PicoMem.zram;
         else
            data = PicoMem.ram;
         break;
      case RETRO_MEMORY_VIDEO_RAM:
         data = PicoMem.vram;
         break;
      case 4:
         data = PicoMem.cram;
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
      case RETRO_MEMORY_SAVE_RAM:
         if ((PicoIn.AHW & PAHW_MCD) && Pico.romsize == 0)
         {
            if (PicoIn.opt & POPT_EN_MCD_RAMCART)
               return 0x12000;
            else /* bram */
               return 0x2000;
         }

         if (Pico.m.frame_count == 0)
            return Pico.sv.size;

         // if game doesn't write to sram, don't report it to
         // libretro so that RA doesn't write out zeroed .srm
         for (i = 0, sum = 0; i < Pico.sv.size; i++)
            sum |= Pico.sv.data[i];

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
   [RETRO_DEVICE_ID_JOYPAD_B]      = 1 << GBTN_B,
   [RETRO_DEVICE_ID_JOYPAD_Y]      = 1 << GBTN_A,
   [RETRO_DEVICE_ID_JOYPAD_SELECT] = 1 << GBTN_MODE,
   [RETRO_DEVICE_ID_JOYPAD_START]  = 1 << GBTN_START,
   [RETRO_DEVICE_ID_JOYPAD_UP]     = 1 << GBTN_UP,
   [RETRO_DEVICE_ID_JOYPAD_DOWN]   = 1 << GBTN_DOWN,
   [RETRO_DEVICE_ID_JOYPAD_LEFT]   = 1 << GBTN_LEFT,
   [RETRO_DEVICE_ID_JOYPAD_RIGHT]  = 1 << GBTN_RIGHT,
   [RETRO_DEVICE_ID_JOYPAD_A]      = 1 << GBTN_C,
   [RETRO_DEVICE_ID_JOYPAD_X]      = 1 << GBTN_Y,
   [RETRO_DEVICE_ID_JOYPAD_L]      = 1 << GBTN_X,
   [RETRO_DEVICE_ID_JOYPAD_R]      = 1 << GBTN_Z,
};
#define RETRO_PICO_MAP_LEN (sizeof(retro_pico_map) / sizeof(retro_pico_map[0]))

static int has_4_pads;

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
   if (strcmp(name, "team player") == 0)
      return PICO_INPUT_PAD_TEAM;
   if (strcmp(name, "4way play") == 0)
      return PICO_INPUT_PAD_4WAY;
   if (strcmp(name, "None") == 0)
      return PICO_INPUT_NOTHING;

   if (log_cb)
      log_cb(RETRO_LOG_WARN, "invalid picodrive_input: '%s'\n", name);
   return PICO_INPUT_PAD_3BTN;
}

static void update_variables(bool first_run)
{
   struct retro_variable var;
   int OldPicoRegionOverride;
   float old_vout_aspect;
   unsigned old_frameskip_type;
   int old_vout_format;
   double new_sound_rate;
   unsigned short old_snd_filter;
   int32_t old_snd_filter_range;

   var.value = NULL;
   var.key = "picodrive_input1";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      int input = input_name_to_val(var.value);
      PicoSetInputDevice(0, input);
      has_4_pads = input == PICO_INPUT_PAD_TEAM || input == PICO_INPUT_PAD_4WAY;
   }

   var.value = NULL;
   var.key = "picodrive_input2";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
      PicoSetInputDevice(1, input_name_to_val(var.value));

   var.value = NULL;
   var.key = "picodrive_ramcart";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         PicoIn.opt |= POPT_EN_MCD_RAMCART;
      else
         PicoIn.opt &= ~POPT_EN_MCD_RAMCART;
   }

   var.value = NULL;
   var.key = "picodrive_smstype";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "Auto") == 0)
         PicoIn.hwSelect = PHWS_AUTO;
      else if (strcmp(var.value, "Game Gear") == 0)
         PicoIn.hwSelect = PHWS_GG;
      else if (strcmp(var.value, "SG-1000") == 0)
         PicoIn.hwSelect = PHWS_SG;
      else if (strcmp(var.value, "SC-3000") == 0)
         PicoIn.hwSelect = PHWS_SC;
      else
         PicoIn.hwSelect = PHWS_SMS;
   }

   var.value = NULL;
   var.key = "picodrive_smsfm";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "on") == 0)
         PicoIn.opt |= POPT_EN_YM2413;
      else
         PicoIn.opt &= ~POPT_EN_YM2413;
   }

   var.value = NULL;
   var.key = "picodrive_smstms";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "SG-1000") == 0)
         PicoIn.tmsPalette = 1;
      else
         PicoIn.tmsPalette = 0;
   }

   var.value = NULL;
   var.key = "picodrive_smsmapper";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "Auto") == 0)
         PicoIn.mapper = PMS_MAP_AUTO;
      else if (strcmp(var.value, "Codemasters") == 0)
         PicoIn.mapper = PMS_MAP_CODEM;
      else if (strcmp(var.value, "Korea") == 0)
         PicoIn.mapper = PMS_MAP_KOREA;
      else if (strcmp(var.value, "Korea MSX") == 0)
         PicoIn.mapper = PMS_MAP_MSX;
      else if (strcmp(var.value, "Korea X-in-1") == 0)
         PicoIn.mapper = PMS_MAP_N32K;
      else if (strcmp(var.value, "Korea 4-Pak") == 0)
         PicoIn.mapper = PMS_MAP_N16K;
      else if (strcmp(var.value, "Korea Janggun") == 0)
         PicoIn.mapper = PMS_MAP_JANGGUN;
      else if (strcmp(var.value, "Korea Nemesis") == 0)
         PicoIn.mapper = PMS_MAP_NEMESIS;
      else if (strcmp(var.value, "Taiwan 8K RAM") == 0)
         PicoIn.mapper = PMS_MAP_8KBRAM;
      else
         PicoIn.mapper = PMS_MAP_SEGA;
   }

   var.value = NULL;
   var.key = "picodrive_ggghost";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "normal") == 0)
         vout_ghosting = 2;
      else if (strcmp(var.value, "weak") == 0)
         vout_ghosting = 1;
      else
         vout_ghosting = 0;
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
      if (PicoIn.sndRate > 52000 && PicoIn.sndRate < 54000)
         PicoIn.sndRate = YM2612_NATIVE_RATE();
      PsndRerate(!first_run);
   }

   old_vout_aspect = vout_aspect;
   var.value = NULL;
   var.key = "picodrive_aspect";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "4/3") == 0)
         vout_aspect = VOUT_4_3;
      else if (strcmp(var.value, "CRT") == 0)
         vout_aspect = VOUT_CRT;
      else
         vout_aspect = VOUT_PAR;
   }

   /* Notify frontend of geometry update */
   if (vout_aspect != old_vout_aspect)
      libretro_update_geometry = true;

   var.value = NULL;
   var.key = "picodrive_sprlim";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         PicoIn.opt |= POPT_DIS_SPRITE_LIM;
      else
         PicoIn.opt &= ~POPT_DIS_SPRITE_LIM;
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

   var.value = NULL;
   var.key = "picodrive_dacnoise";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "enabled") == 0)
         PicoIn.opt |= POPT_EN_FM_DAC;
      else
         PicoIn.opt &= ~POPT_EN_FM_DAC;
   }

   var.value = NULL;
   var.key = "picodrive_fm_filter";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "on") == 0)
         PicoIn.opt |= POPT_EN_FM_FILTER;
      else
         PicoIn.opt &= ~POPT_EN_FM_FILTER;
   }

   old_snd_filter = PicoIn.opt & POPT_EN_SNDFILTER;
   var.value = NULL;
   var.key = "picodrive_audio_filter";
   PicoIn.opt &= ~POPT_EN_SNDFILTER;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "low-pass") == 0)
         PicoIn.opt |= POPT_EN_SNDFILTER;
   }

   old_snd_filter_range = PicoIn.sndFilterAlpha;
   var.value = NULL;
   var.key = "picodrive_lowpass_range";
   PicoIn.sndFilterAlpha = (60 * 0x10000 / 100);
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      PicoIn.sndFilterAlpha = (atoi(var.value) * 0x10000 / 100);
   }

   if (((old_snd_filter ^ PicoIn.opt) & POPT_EN_SNDFILTER) ||
         old_snd_filter_range != PicoIn.sndFilterAlpha) {
      mix_reset (PicoIn.opt & POPT_EN_SNDFILTER ? PicoIn.sndFilterAlpha : 0);
   }

   old_frameskip_type = frameskip_type;
   frameskip_type     = 0;
   var.key            = "picodrive_frameskip";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "auto") == 0)
         frameskip_type = 1;
      else if (strcmp(var.value, "manual") == 0)
         frameskip_type = 2;
   }

   frameskip_threshold = 33;
   var.key             = "picodrive_frameskip_threshold";
   var.value           = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
      frameskip_threshold = strtol(var.value, NULL, 10);

   old_vout_format = vout_format;
   var.value = NULL;
   var.key = "picodrive_renderer";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (strcmp(var.value, "fast") == 0)
         vout_format = PDF_NONE;
      else if (strcmp(var.value, "good") == 0)
         vout_format = PDF_8BIT;
      else if (strcmp(var.value, "accurate") == 0)
         vout_format = PDF_RGB555;
      vout_16bit = vout_format == PDF_RGB555 || (PicoIn.AHW & PAHW_32X);

      apply_renderer();
   }

   var.value = NULL;
   var.key = "picodrive_sound_rate";
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value) {
      if (!strcmp(var.value, "native"))
         new_sound_rate = YM2612_NATIVE_RATE();
      else
         new_sound_rate = atoi(var.value);
      if (new_sound_rate != PicoIn.sndRate) {
         /* Update the sound rate */
         PicoIn.sndRate = new_sound_rate;
         PsndRerate(!first_run);
         libretro_update_av_info = true;
      }
   }

   /* setup video if required */
   if (vout_format != old_vout_format)
   {
      if (vout_buf &&
          (vm_current_start_line != -1) && (vm_current_line_count != -1) &&
          (vm_current_start_col != -1) && (vm_current_col_count != -1))
         emu_video_mode_change(
               vm_current_start_line, vm_current_line_count,
               vm_current_start_col, vm_current_col_count);
   }

   /* Reinitialise frameskipping, if required */
   if (((frameskip_type != old_frameskip_type) ||
        (Pico.rom && PicoIn.regionOverride != OldPicoRegionOverride)) &&
       !first_run)
      init_frameskip();
}

void emu_status_msg(const char *format, ...)
{
    va_list vl;
    int ret;
    static char msg[512];

    memset (msg, 0, sizeof(msg));

    va_start(vl, format);
    ret = vsnprintf(msg, sizeof(msg), format, vl);
    va_end(vl);

    static struct retro_message rmsg;
    rmsg.msg    = msg;
    rmsg.frames = 600;
    environ_cb(RETRO_ENVIRONMENT_SET_MESSAGE, &rmsg);
}

static void draw_pico_ptr(void)
{
   int up = (PicoPicohw.pen_pos[0]|PicoPicohw.pen_pos[1]) & 0x8000;
   int x, y, pitch = vout_width;
   unsigned short *p = (unsigned short *)((char *)vout_buf + vout_offset);
   int o = (up ? 0x0000 : 0xffff), _ = (up ? 0xffff : 0x0000);
   // storyware pages are actually squished, 2:1
   int h = (pico_inp_mode == 1 ? 160 : vout_height);
   if (h < 224) y++;

   x = ((pico_pen_x * vout_width * ((1ULL<<32) / 320 + 1)) >> 32);
   y = ((pico_pen_y * h          * ((1ULL<<32) / 224 + 1)) >> 32);
   p += x + y * pitch;

   p[-pitch-1] ^= o; p[-pitch] ^= _; p[-pitch+1] ^= _; p[-pitch+2] ^= o;
   p[-1]       ^= _; p[0]      ^= o; p[1]        ^= o; p[2]        ^= _;
   p[pitch-1]  ^= _; p[pitch]  ^= o; p[pitch+1]  ^= o; p[pitch+2]  ^= _;
   p[2*pitch-1]^= o; p[2*pitch]^= _; p[2*pitch+1]^= _; p[2*pitch+2]^= o;
}

static int readpng(unsigned short *dest, const char *fname, int req_w, int req_h)
{
   rpng_t *rpng = rpng_alloc();
   FILE *pf = fopen(fname, "rb");
   void *png = NULL, *img = NULL;
   size_t len;
   unsigned int x, y, w = req_w, h = req_h;
   int ret = -1;

   if (!rpng || !pf) {
      lprintf("can't read png file %s", fname);
      goto done;
   }
 
   // who designed this, reading the whole file for inflating, really?
   fseek(pf, 0, SEEK_END);
   len = ftell(pf);
   fseek(pf, 0, SEEK_SET);
   if (!(png = malloc(len))) {
      lprintf("oom while reading png file %s", fname);
      goto done;
   }
   fread(png, 1, len, pf);

   // again, who designed this? why all this superfluous iterating here?
   rpng_set_buf_ptr(rpng, png, len);
   rpng_start(rpng);
   while (rpng_iterate_image(rpng));
   do {
      ret = rpng_process_image(rpng, &img, len, &w, &h);
   } while (ret == IMAGE_PROCESS_NEXT);

   // there's already a scaled pngread in libpicofe, but who cares :-/
   if (img && rpng_is_valid(rpng)) {
      int x_scale = w*65536 / req_w;
      int y_scale = h*65536 / req_h;
      int x_ofs, y_ofs, x_pos, y_pos;

      if (x_scale < y_scale)
            x_scale = y_scale;
      else  y_scale = x_scale;
      x_ofs = req_w - w*65536 / x_scale;
      y_ofs = req_h - h*65536 / y_scale;

      dest += y_ofs/2*req_w + x_ofs/2;
      for (y_pos = 0; y_pos < h*65536; y_pos += y_scale+1)
      {
         unsigned char *src = (unsigned char *)img + 4*w*(y_pos >> 16);
         for (x_pos = 0, len = 0; x_pos < w*65536; x_pos += x_scale+1, len++)
         {
            // to add insult to injury, rpng writes the image endian dependant!
            unsigned int d = *(unsigned int *)&src[4*(x_pos >> 16)];
            int r = d >> 16, g = d >> 8, b = d;
            *dest++ = PXMAKE(r & 0xff, g & 0xff, b & 0xff);
         }
         dest += req_w - len;
      }
   }
   ret = 0;

done:
   if (img) free(img);
   if (png) free(png);
   if (pf) fclose(pf);
   rpng_free(rpng);
   return ret;
}

static unsigned short *load_pico_overlay(int page, int w, int h)
{
   static const char *pic_exts[] = { "png", "PNG" };
   char buffer[PATH_MAX];
   char *ext, *fname = NULL;
   int extpos, i;

   if (pico_page == page && pico_w == w && pico_h == h)
      return pico_overlay;
   pico_page = page;
   pico_w = w, pico_h = h;

   ext = strrchr(pico_overlay_path, '.');
   extpos = ext ? ext-pico_overlay_path : strlen(pico_overlay_path);
   strcpy(buffer, pico_overlay_path);
   buffer[extpos++] = '_';
   if (page < 0) {
      buffer[extpos++] = 'p';
      buffer[extpos++] = 'a';
      buffer[extpos++] = 'd';
   } else
      buffer[extpos++] = '0'+PicoPicohw.page;
   buffer[extpos++] = '.';

   for (i = 0; i < ARRAY_SIZE(pic_exts); i++) {
      strcpy(buffer+extpos, pic_exts[i]);
      if (path_is_valid(buffer) == RETRO_VFS_STAT_IS_VALID) {
         printf("found Pico file: %s\n", buffer);
         fname = buffer;
         break;
      }
   }

   pico_overlay = realloc(pico_overlay, w*h*2);
   memset(pico_overlay, 0, w*h*2);
   if (!fname || !pico_overlay || readpng(pico_overlay, fname, w, h)) {
      if (pico_overlay)
         free(pico_overlay);
      pico_overlay = NULL;
   }

   return pico_overlay;
}

void emu_pico_overlay(u16 *pd, int w, int h, int pitch)
{
	u16 *overlay = NULL;
	int y, oh = h;

	// get overlay
	if (pico_inp_mode == 1) {
		oh = (w/2 < h ? w/2 : h); // storyware has squished h
		overlay = load_pico_overlay(PicoPicohw.page, w, oh);
	} else if (pico_inp_mode == 2)
		overlay = load_pico_overlay(-1, w, oh);

	// copy overlay onto buffer
	if (overlay) {
		for (y = 0; y < oh; y++)
			memcpy(pd + y*pitch, overlay + y*w, w*2);
		if (y < h)
			memset(pd + y*pitch, 0, w*2);
	}
}

void run_events_pico(unsigned int events)
{
    int lim_x;

    if (events & (1 << RETRO_DEVICE_ID_JOYPAD_L)) {
	PicoPicohw.page--;
	if (PicoPicohw.page < 0)
	    PicoPicohw.page = 0;
	emu_status_msg("Page %i", PicoPicohw.page);
    }
    if (events & (1 << RETRO_DEVICE_ID_JOYPAD_R)) {
	PicoPicohw.page++;
	if (PicoPicohw.page > 7)
	    PicoPicohw.page = 7;
        if (PicoPicohw.page == 7) {
            // Used in games that require the Keyboard Pico peripheral
            emu_status_msg("Test Page");
        }
        else {
            emu_status_msg("Page %i", PicoPicohw.page);
        }
    }
    if (events & (1 << RETRO_DEVICE_ID_JOYPAD_X)) {
        if (pico_inp_mode == 2) {
            pico_inp_mode = 0;
            emu_status_msg("Input: D-Pad");
        } else {
            pico_inp_mode = 2;
            emu_status_msg("Input: Pen on Pad");
        }
    }
    if (events & (1 << RETRO_DEVICE_ID_JOYPAD_Y)) {
        if (pico_inp_mode == 1) {
            pico_inp_mode = 0;
            emu_status_msg("Input: D-Pad");
        } else {
            pico_inp_mode = 1;
            emu_status_msg("Input: Pen on Storyware");
        }
    }
    if (events & (1 << RETRO_DEVICE_ID_JOYPAD_START)) {
        PicoPicohw.pen_pos[0] ^= 0x8000;
        PicoPicohw.pen_pos[1] ^= 0x8000;
        emu_status_msg("Pen %s", PicoPicohw.pen_pos[0] & 0x8000 ? "Up" : "Down");
    }

    if ((PicoIn.pad[0] & 0x20) && pico_inp_mode && pico_overlay) {
        pico_inp_mode = 0;
        emu_status_msg("Input: D-Pad");
    }
    if (pico_inp_mode == 0)
	return;

    /* handle other input modes */
    if (PicoIn.pad[0] & 1) pico_pen_y--;
    if (PicoIn.pad[0] & 2) pico_pen_y++;
    if (PicoIn.pad[0] & 4) pico_pen_x--;
    if (PicoIn.pad[0] & 8) pico_pen_x++;
    PicoIn.pad[0] &= ~0x0f; // release UDLR

    if (pico_pen_y < PICO_PEN_ADJUST_Y)
	pico_pen_y = PICO_PEN_ADJUST_Y;
    if (pico_pen_y > 223-1 - PICO_PEN_ADJUST_Y)
	pico_pen_y = 223-1 - PICO_PEN_ADJUST_Y;
    if (pico_pen_x < PICO_PEN_ADJUST_X)
	pico_pen_x = PICO_PEN_ADJUST_X;
    if (pico_pen_x > 319-1 - PICO_PEN_ADJUST_X)
	pico_pen_x = 319-1 - PICO_PEN_ADJUST_X;

    PicoPicohw.pen_pos[0] &= 0x8000;
    PicoPicohw.pen_pos[1] &= 0x8000;
    PicoPicohw.pen_pos[0] |= 0x3c + pico_pen_x;
    PicoPicohw.pen_pos[1] |= (pico_inp_mode == 1 ? 0x2f8 : 0x1fc) + pico_pen_y;
}

void retro_run(void)
{
   bool updated = false;
   int pad, i, padcount;
   static void *buff;

   PicoIn.skipFrame = 0;

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated)
      update_variables(false);

   input_poll_cb();

   PicoIn.pad[0] = PicoIn.pad[1] = PicoIn.pad[2] = PicoIn.pad[3] = 0;
   if (PicoIn.AHW & PAHW_PICO)
      padcount = 1;
   else if (PicoIn.AHW & PAHW_SMS)
      padcount = 2;
   else
      padcount = has_4_pads ? 4 : 2;

   int16_t input[4] = {0, 0};

   if (libretro_supports_bitmasks)
   {
      for (pad = 0; pad < padcount; pad++)
      {
         input[pad] = input_state_cb(
               pad, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
      }
   }
   else
   {
      for (pad = 0; pad < padcount; pad++)
      {
         for (i = 0; i < RETRO_PICO_MAP_LEN; i++)
            if (input_state_cb(pad, RETRO_DEVICE_JOYPAD, 0, i))
               input[pad] |= 1 << i;
      }
   }

   for (pad = 0; pad < padcount; pad++)
     for (i = 0; i < RETRO_PICO_MAP_LEN; i++)
	 if (input[pad] & (1 << i))
	     PicoIn.pad[pad] |= retro_pico_map[i];

   if (PicoIn.AHW == PAHW_PICO) {
       uint16_t ev = input[0] &
             ((1 << RETRO_DEVICE_ID_JOYPAD_L) | (1 << RETRO_DEVICE_ID_JOYPAD_R) |
              (1 << RETRO_DEVICE_ID_JOYPAD_X) | (1 << RETRO_DEVICE_ID_JOYPAD_Y) |
              (1 << RETRO_DEVICE_ID_JOYPAD_START));
       uint16_t new_ev = ev & ~pico_events;
       pico_events = ev;
       run_events_pico(new_ev);
   }

   if (PicoPatches)
      PicoPatchApply();

   /* Check whether current frame should
    * be skipped */
   if ((frameskip_type > 0) && retro_audio_buff_active) {
      switch (frameskip_type)
      {
         case 1: /* auto */
            PicoIn.skipFrame = retro_audio_buff_underrun ? 1 : 0;
            break;
         case 2: /* manual */
            PicoIn.skipFrame = (retro_audio_buff_occupancy < frameskip_threshold) ? 1 : 0;
            break;
         default:
            PicoIn.skipFrame = 0;
            break;
      }

      if (!PicoIn.skipFrame || (frameskip_counter >= FRAMESKIP_MAX)) {
         PicoIn.skipFrame  = 0;
         frameskip_counter = 0;
      } else
         frameskip_counter++;
   }

   /* If frameskip settings have changed, update
    * frontend audio latency */
   if (update_audio_latency) {
      environ_cb(RETRO_ENVIRONMENT_SET_MINIMUM_AUDIO_LATENCY,
            &audio_latency);
      update_audio_latency = false;
   }

   PicoFrame();

   /* Check whether frontend needs to be notified
    * of timing/geometry changes */
   if (libretro_update_av_info || libretro_update_geometry) {
      struct retro_system_av_info av_info;
      retro_get_system_av_info(&av_info);
      environ_cb(libretro_update_av_info ?
            RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO :
            RETRO_ENVIRONMENT_SET_GEOMETRY,
            &av_info);
      libretro_update_av_info = false;
      libretro_update_geometry = false;
   }

   /* If frame was skipped, call video_cb() with
    * a NULL buffer and return immediately */
   if (PicoIn.skipFrame) {
      video_cb(NULL, vout_width, vout_height, vout_width * 2);
      return;
   }

#if defined(RENDER_GSKIT_PS2)
   buff = (uint32_t *)RETRO_HW_FRAME_BUFFER_VALID;

   if (!ps2) {
      // get access to the graphics hardware
      if (!environ_cb(RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE, (void **)&ps2) || !ps2) {
         printf("Failed to get HW rendering interface!\n");
         return;
      }

      if (ps2->interface_version != RETRO_HW_RENDER_INTERFACE_GSKIT_PS2_VERSION) {
         printf("HW render interface mismatch, expected %u, got %u!\n", 
                  RETRO_HW_RENDER_INTERFACE_GSKIT_PS2_VERSION, ps2->interface_version);
         return;
      }

      ps2->coreTexture->ClutPSM = GS_PSM_CT16;
      ps2->coreTexture->Filter = GS_FILTER_LINEAR;
      ps2->coreTexture->Clut = retro_palette;

      ps2->coreTexture->Mem = vout_buf;
      ps2->coreTexture->Width = vout_width;
      ps2->coreTexture->Height = vout_height;
      ps2->coreTexture->PSM = (vout_16bit ? GS_PSM_CT16 : GS_PSM_T8);
      ps2->padding = padding;
   }

   // CLUT update needed?
   if (!vout_16bit && Pico.m.dirtyPal) {
      PicoDrawUpdateHighPal();

      // Rotate CLUT. PS2 is special since entries in CLUT are not in sequence.
      unsigned short int *pal=(void *)retro_palette;
      for (i = 0; i < 256; i+=8) {
         if ((i&0x18) == 0x08)
            memcpy(pal+i,Pico.est.HighPal+i+8,16);
         else if ((i&0x18) == 0x10)
            memcpy(pal+i,Pico.est.HighPal+i-8,16);
         else
            memcpy(pal+i,Pico.est.HighPal+i,16);
      }
   }
#else
   if (!vout_16bit) {
      /* The 8 bit renderers write a CLUT image in Pico.est.Draw2FB, while libretro wants RGB in vout_buf.
       * We need to manually copy that to vout_buf, applying the CLUT on the way. Especially
       * with the fast renderer this is improving performance, at the expense of accuracy.
       */
      /* This section is mostly copied from pemu_finalize_frame in platform/linux/emu.c */
      unsigned short *pd = (unsigned short *)((char *)vout_buf + vout_offset);
      /* Skip the leftmost 8 columns (it is used as an overlap area for rendering) */
      unsigned char *ps = Pico.est.Draw2FB + vm_current_start_line * 328 + 8;
      unsigned short *pal = Pico.est.HighPal;
      int x;
      if (Pico.m.dirtyPal)
         PicoDrawUpdateHighPal();
      /* 8 bit renderers have an extra offset for SMS wíth 1st tile blanked */
      if (vout_width == 248)
         ps += 8;
      /* Copy, and skip the leftmost 8 columns again */
      for (i = 0; i < vout_height; i++, ps += 8) {
         for (x = 0; x < vout_width; x+=4) {
            *pd++ = pal[*ps++];
            *pd++ = pal[*ps++];
            *pd++ = pal[*ps++];
            *pd++ = pal[*ps++];
         }
         ps += 320-vout_width; /* Advance to next line in case of 32col mode */
      }
   }

   if (vout_ghosting && vout_height == 144) {
      unsigned short *pd = (unsigned short *)vout_buf;
      unsigned short *ps = (unsigned short *)vout_ghosting_buf;
      int y;
      for (y = 0; y < vout_height; y++) {
         if (vout_ghosting == 1)
            v_blend(pd, ps, vout_width, p_075_round);
         else
            v_blend(pd, ps, vout_width, p_05_round);
         pd += vout_width;
         ps += vout_width;
      }
   }

   if (PicoIn.AHW & PAHW_PICO) {
      int h = vout_height, w = vout_width;
      unsigned short *pd = (unsigned short *)((char *)vout_buf + vout_offset);

      if (pico_inp_mode)
         emu_pico_overlay(pd, w, h, vout_width);
      if (pico_inp_mode /*== 2 || overlay*/)
         draw_pico_ptr();
   }

   buff = (char*)vout_buf + vout_offset;
#endif

   video_cb((short *)buff, vout_width, vout_height, vout_width * 2);
}

void retro_init(void)
{
   unsigned dci_version = 0;
   struct retro_log_callback log;
   int level;

   level = 0;
   environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);

   if (environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
      log_cb = log.log;
   else
      log_cb = NULL;

   environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE, &disk_control);

   if (environ_cb(RETRO_ENVIRONMENT_GET_INPUT_BITMASKS, NULL))
      libretro_supports_bitmasks = true;

   disk_initial_index = 0;
   disk_initial_path[0] = '\0';
   if (environ_cb(RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION, &dci_version) && (dci_version >= 1))
      environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE, &disk_control_ext);
   else
      environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE, &disk_control);

#ifdef _3DS
   ctr_svchack_successful = ctr_svchack_init();
   check_rosalina();
#elif defined(VITA)
   sceBlock = getVMBlock();
#endif

   PicoIn.opt = POPT_EN_STEREO|POPT_EN_FM
      | POPT_EN_PSG|POPT_EN_Z80|POPT_EN_GG_LCD
      | POPT_EN_MCD_PCM|POPT_EN_MCD_CDDA|POPT_EN_MCD_GFX
      | POPT_EN_32X|POPT_EN_PWM
      | POPT_ACC_SPRITES|POPT_DIS_32C_BORDER;
#ifdef DRC_SH2
#ifdef _3DS
   if (ctr_svchack_successful)
#endif
      PicoIn.opt |= POPT_EN_DRC;
#endif

   struct retro_variable var = { .key = "picodrive_sound_rate" };
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
      PicoIn.sndRate = atoi(var.value);
   else
      PicoIn.sndRate = SND_RATE_DEFAULT;

   PicoIn.autoRgnOrder = 0x184; // US, EU, JP

   vout_width = VOUT_MAX_WIDTH;
   vout_height = VOUT_MAX_HEIGHT;
#ifdef _3DS
   vout_buf = linearMemAlign(VOUT_MAX_WIDTH * VOUT_MAX_HEIGHT * 2, 0x80);
#elif defined(RENDER_GSKIT_PS2)
   vout_buf = memalign(4096, VOUT_MAX_WIDTH * VOUT_MAX_HEIGHT * 2);
   retro_palette = memalign(128, gsKit_texture_size_ee(16, 16, GS_PSM_CT16));
#else
   vout_buf = malloc(VOUT_MAX_WIDTH * VOUT_MAX_HEIGHT * 2);
#endif

   PicoInit();

   //PicoIn.osdMessage = plat_status_msg_busy_next;
   PicoIn.mcdTrayOpen = disk_tray_open;
   PicoIn.mcdTrayClose = disk_tray_close;

   frameskip_type             = 0;
   frameskip_threshold        = 0;
   frameskip_counter          = 0;
   retro_audio_buff_active    = false;
   retro_audio_buff_occupancy = 0;
   retro_audio_buff_underrun  = false;
   audio_latency              = 0;
   update_audio_latency       = false;

   update_variables(true);
}

void retro_deinit(void)
{
   size_t i;

   PicoExit();

   disk_init();

#ifdef _3DS
   linearFree(vout_buf);
#elif defined(RENDER_GSKIT_PS2)
   free(vout_buf);
   free(retro_palette);
   ps2 = NULL;
#elif defined(__PS3__)
   free(vout_buf);
   if (page_table[0] > 0 && page_table[1] > 0)
      ps3mapi_process_page_free(sysProcessGetPid(), 0x2F, page_table);
#else
   free(vout_buf);
#endif
   vout_buf = NULL;

   if (vout_ghosting_buf)
      free(vout_ghosting_buf);
   vout_ghosting_buf = NULL;
   if (pico_overlay)
      free(pico_overlay);
   pico_overlay = NULL;

   libretro_supports_bitmasks = false;
}
