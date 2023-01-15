/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2013-2014 - Jason Fetters
 *  Copyright (C) 2011-2017 - Daniel De Matteis
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */
// Adds Vulkan iOS 
#ifdef HAVE_CONFIG_H
#include "../../config.h"
#endif

#if TARGET_OS_IPHONE
#include <CoreGraphics/CoreGraphics.h>
#else
#include <ApplicationServices/ApplicationServices.h>
#endif
#ifdef OSX
#include <AppKit/NSScreen.h>
#endif

#include <retro_assert.h>
#include <retro_timers.h>
#include <compat/apple_compat.h>
#include <string/stdstring.h>

#include "./cocoa_common.h"
#include "./apple_platform.h"
#include "./vulkan_common.h"

#include "../../ui/drivers/ui_cocoa.h"
#include "../../configuration.h"
#include "../../retroarch.h"
#include "../../verbosity.h"
#ifdef HAVE_METAL
#include "../common/metal_common.h"
#endif

typedef struct cocoa_ctx_data
{
	gfx_ctx_vulkan_data_t vk;
	int swap_interval;
	unsigned width;
	unsigned height;
} cocoa_ctx_data_t;

/* TODO/FIXME - static globals */
static unsigned g_vk_minor          = 0;
static unsigned g_vk_major          = 0;
/* Forward declaration */
CocoaView *cocoaview_get(void);
extern UIView *_renderView;

static uint32_t cocoa_vk_gfx_ctx_get_flags(void *data)
{
	uint32_t flags                 = 0;
	cocoa_ctx_data_t    *cocoa_ctx = (cocoa_ctx_data_t*)data;

#if defined(HAVE_SLANG) && defined(HAVE_SPIRV_CROSS)
	BIT32_SET(flags, GFX_CTX_FLAGS_SHADERS_SLANG);
#endif

	return flags;
}

static void cocoa_vk_gfx_ctx_set_flags(void *data, uint32_t flags) { }

static void cocoa_vk_gfx_ctx_destroy(void *data)
{
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;

	if (!cocoa_ctx)
		return;

	vulkan_context_destroy(&cocoa_ctx->vk, cocoa_ctx->vk.vk_surface != VK_NULL_HANDLE);
	if (cocoa_ctx->vk.context.queue_lock)
		slock_free(cocoa_ctx->vk.context.queue_lock);
	memset(&cocoa_ctx->vk, 0, sizeof(cocoa_ctx->vk));

	free(cocoa_ctx);
}

static enum gfx_ctx_api cocoa_vk_gfx_ctx_get_api(void *data) { return GFX_CTX_VULKAN_API; }

static bool cocoa_vk_gfx_ctx_suppress_screensaver(void *data, bool enable) { return false; }

static void cocoa_vk_gfx_ctx_input_driver(void *data,
		const char *name,
		input_driver_t **input, void **input_data)
{
	*input      = NULL;
	*input_data = NULL;
}

#if MAC_OS_X_VERSION_10_7 && defined(OSX)
/* NOTE: convertRectToBacking only available on MacOS X 10.7 and up.
 * Therefore, make specialized version of this function instead of
 * going through a selector for every call. */
static void cocoa_vk_gfx_ctx_get_video_size_osx10_7_and_up(void *data,
		unsigned* width, unsigned* height)
{
	CocoaView *g_view               = cocoaview_get();
	CGRect _cgrect                  = NSRectToCGRect(g_view.frame);
	CGRect bounds                   = CGRectMake(0, 0, CGRectGetWidth(_cgrect), CGRectGetHeight(_cgrect));
	CGRect cgrect                   = NSRectToCGRect([g_view convertRectToBacking:bounds]);
	GLsizei backingPixelWidth       = CGRectGetWidth(cgrect);
	GLsizei backingPixelHeight      = CGRectGetHeight(cgrect);
	CGRect size                     = CGRectMake(0, 0, backingPixelWidth, backingPixelHeight);
	*width                          = CGRectGetWidth(size);
	*height                         = CGRectGetHeight(size);
}
#elif defined(OSX)
static void cocoa_vk_gfx_ctx_get_video_size(void *data,
		unsigned* width, unsigned* height)
{
	CocoaView *g_view               = cocoaview_get();
	CGRect cgrect                   = NSRectToCGRect([g_view frame]);
	GLsizei backingPixelWidth       = CGRectGetWidth(cgrect);
	GLsizei backingPixelHeight      = CGRectGetHeight(cgrect);
	CGRect size                     = CGRectMake(0, 0, backingPixelWidth, backingPixelHeight);
	*width                          = CGRectGetWidth(size);
	*height                         = CGRectGetHeight(size);
}
#else
static void cocoa_vk_gfx_ctx_get_video_size(void *data,
		unsigned* width, unsigned* height)
{
    // Sets Video Size
    CGFloat scale = [UIScreen mainScreen].scale;
 	CocoaView *g_view               = [CocoaView get];
    CGRect cgrect                   = g_view.view.frame;
	GLsizei backingPixelWidth       = CGRectGetWidth(cgrect);
	GLsizei backingPixelHeight      = CGRectGetHeight(cgrect);
	CGRect size                     = CGRectMake(0, 0, backingPixelWidth, backingPixelHeight);
	*width                          = CGRectGetWidth(size)  * scale;
	*height                         = CGRectGetHeight(size) * scale;
}
#endif

static gfx_ctx_proc_t cocoa_vk_gfx_ctx_get_proc_address(const char *symbol_name)
{
	return NULL;
}

static void cocoa_vk_gfx_ctx_bind_hw_render(void *data, bool enable) { }

static void cocoa_vk_gfx_ctx_check_window(void *data, bool *quit,
		bool *resize, unsigned *width, unsigned *height)
{
	unsigned new_width, new_height;
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;

	*quit                       = false;

	*resize                     = cocoa_ctx->vk.flags &
		VK_DATA_FLAG_NEED_NEW_SWAPCHAIN;

#if MAC_OS_X_VERSION_10_7 && defined(OSX)
	cocoa_vk_gfx_ctx_get_video_size_osx10_7_and_up(data, &new_width, &new_height);
#else
	cocoa_vk_gfx_ctx_get_video_size(data, &new_width, &new_height);
#endif

	if (new_width != *width || new_height != *height)
	{
		*width  = new_width;
		*height = new_height;
		*resize = true;
	}
}

static void cocoa_vk_gfx_ctx_swap_interval(void *data, int i)
{
	unsigned interval           = (unsigned)i;
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;

	if (cocoa_ctx->swap_interval != interval)
	{
		cocoa_ctx->swap_interval = interval;
		if (cocoa_ctx->vk.swapchain)
			cocoa_ctx->vk.flags  |= VK_DATA_FLAG_NEED_NEW_SWAPCHAIN;
	}
}

static void cocoa_vk_gfx_ctx_swap_buffers(void *data)
{
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;

	if (cocoa_ctx->vk.context.flags & VK_CTX_FLAG_HAS_ACQUIRED_SWAPCHAIN)
	{
		cocoa_ctx->vk.context.flags &= ~VK_CTX_FLAG_HAS_ACQUIRED_SWAPCHAIN;
		if (cocoa_ctx->vk.swapchain == VK_NULL_HANDLE)
		{
			retro_sleep(10);
		}
		else
		{
			vulkan_present(&cocoa_ctx->vk, cocoa_ctx->vk.context.current_swapchain_index);
		}
	}
	vulkan_acquire_next_image(&cocoa_ctx->vk);
}

static bool cocoa_vk_gfx_ctx_bind_api(void *data, enum gfx_ctx_api api,
		unsigned major, unsigned minor)
{
	g_vk_minor  = minor;
	g_vk_major  = major;

	return true;
}

static void *cocoa_vk_gfx_ctx_get_context_data(void *data)
{
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;
	return &cocoa_ctx->vk.context;
}

#ifdef OSX
static bool cocoa_vk_gfx_ctx_set_video_mode(void *data,
		unsigned width, unsigned height, bool fullscreen)
{
#if defined(HAVE_COCOA_METAL)
	NSView *g_view              = apple_platform.renderView;
#elif defined(HAVE_COCOA)
	CocoaView *g_view           = (CocoaView*)nsview_get_ptr();
#endif
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;
	static bool
		has_went_fullscreen      = false;
	cocoa_ctx->width            = width;
	cocoa_ctx->height           = height;

	RARCH_LOG("[macOS]: Native window size: %u x %u.\n",
			cocoa_ctx->width, cocoa_ctx->height);

	if (!vulkan_surface_create(
				&cocoa_ctx->vk,
				VULKAN_WSI_MVK_MACOS,
				NULL,
				(BRIDGE void *)g_view,
				cocoa_ctx->width,
				cocoa_ctx->height,
				cocoa_ctx->swap_interval))
	{
		RARCH_ERR("[macOS]: Failed to create surface.\n");
		return false;
	}

	/* TODO: Screen mode support. */
	if (fullscreen)
	{
		if (!has_went_fullscreen)
		{
			[g_view enterFullScreenMode:(BRIDGE NSScreen *)cocoa_screen_get_chosen() withOptions:nil];
			cocoa_show_mouse(data, false);
		}
	}
	else
	{
		if (has_went_fullscreen)
		{
			[g_view exitFullScreenModeWithOptions:nil];
			[[g_view window] makeFirstResponder:g_view];
			cocoa_show_mouse(data, true);
		}

		[[g_view window] setContentSize:NSMakeSize(width, height)];
	}

	has_went_fullscreen = fullscreen;

	return true;
}

static void *cocoa_vk_gfx_ctx_init(void *video_driver)
{
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)
	calloc(1, sizeof(cocoa_ctx_data_t));

	if (!cocoa_ctx)
		return NULL;

	[apple_platform setViewType:APPLE_VIEW_TYPE_VULKAN];
	NSString *sysPath = [[NSBundle mainBundle] pathForResource:@"Frameworks/libMoltenVK.dylib" ofType:nil];
	const char *vulkan_path=[sysPath UTF8Char];
	if (!vulkan_context_init(&cocoa_ctx->vk, VULKAN_WSI_MVK_MACOS, vulkan_path))
	{
		free(cocoa_ctx);
		return NULL;
	}

	return cocoa_ctx;
}
#else
static bool cocoa_vk_gfx_ctx_set_video_mode(void *data,
		unsigned width, unsigned height, bool fullscreen)
{
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;
	NSLog(@"Set:VULKAN:Setting Video Mode %d %d\n", width, height);
	CocoaView *g_view           = [CocoaView get];
    CGRect bounds = [UIScreen mainScreen].bounds;
    cocoa_ctx->width            = width > 1 ? width : bounds.size.width;
    cocoa_ctx->height           = height > 1 ? height : bounds.size.height;
	NSLog(@"Set:VULKAN:[iOS]: Native window size: %u x %u.\n",
			cocoa_ctx->width, cocoa_ctx->height);
    
	if (!vulkan_surface_create(
				&cocoa_ctx->vk,
				VULKAN_WSI_MVK_IOS,
				NULL,
				(BRIDGE void *)_renderView,
                width,
				height,
				cocoa_ctx->swap_interval))
	{
		NSLog(@"Set:VULKAN:[iOS]: Failed to create surface.\n");
		return false;
	}
    /*
	if (!vulkan_surface_create(
				 &cocoa_ctx->vk,
				 VULKAN_WSI_MVK_IOS_METAL_EXT,
				 NULL,
				 (BRIDGE void *)_renderView.layer,
				 cocoa_ctx->width,
				 cocoa_ctx->height,
				 cocoa_ctx->swap_interval))
	 {
		 RARCH_ERR("[iOS]: Failed to create surface.\n");
		 return false;
	 }
     */
	 return true;
}

static void *cocoa_vk_gfx_ctx_init(void *video_driver)
{

	 cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)
	 calloc(1, sizeof(cocoa_ctx_data_t));
	 NSLog(@"Set:VULKAN: Initializing Vulkan Context\n");
	 if (!cocoa_ctx)
		 return NULL;

	 [apple_platform setViewType:APPLE_VIEW_TYPE_VULKAN];

	 NSString *sysPath = [[NSBundle mainBundle] pathForResource:@"Frameworks/libMoltenVK.dylib" ofType:nil];
	 const char *vulkan_path="@executable_path/Frameworks/libMoltenVK.dylib";
	 NSFileManager *fm = [NSFileManager defaultManager];

	 if ([fm fileExistsAtPath:sysPath]) {
		  NSLog(@"Set:VULKAN: Found libMoltenVK at %s", vulkan_path);
	 } else {
		  NSLog(@"Set:VULKAN: libMoltenVK Not Found at %s\n", vulkan_path);
	 }
    
	 if (!vulkan_context_init(&cocoa_ctx->vk, VULKAN_WSI_MVK_IOS, vulkan_path)) {
          NSLog(@"Set:VULKAN:Vulkan Context Initialize Failed\n");
		  free(cocoa_ctx);
		  return NULL;
	 }
     /*
     if (!vulkan_context_init(&cocoa_ctx->vk, VULKAN_WSI_MVK_IOS_METAL_EXT, vulkan_path))
	 {
		 free(cocoa_ctx);
		 return NULL;
	 }*/
      
	 NSLog(@"Set:VULKAN: Vulkan Context Initialized OK\n");
	 return cocoa_ctx;
}
#endif

#ifdef HAVE_COCOA_METAL
static bool cocoa_vk_gfx_ctx_set_resize(void *data, unsigned width, unsigned height)
{
	cocoa_ctx_data_t *cocoa_ctx = (cocoa_ctx_data_t*)data;

	cocoa_ctx->width  = width;
	cocoa_ctx->height = height;

	if (!vulkan_create_swapchain(&cocoa_ctx->vk,
				width, height, cocoa_ctx->swap_interval))
	{
		RARCH_ERR("[macOS/Vulkan]: Failed to update swapchain.\n");
		return false;
	}

	cocoa_ctx->vk.context.flags |= VK_CTX_FLAG_INVALID_SWAPCHAIN;
	if (cocoa_ctx->vk.flags & VK_DATA_FLAG_CREATED_NEW_SWAPCHAIN)
		vulkan_acquire_next_image(&cocoa_ctx->vk);

	cocoa_ctx->vk.flags &= ~VK_DATA_FLAG_NEED_NEW_SWAPCHAIN;

	return true;
}
#endif

const gfx_ctx_driver_t gfx_ctx_cocoavk = {
	cocoa_vk_gfx_ctx_init,
	cocoa_vk_gfx_ctx_destroy,
	cocoa_vk_gfx_ctx_get_api,
	cocoa_vk_gfx_ctx_bind_api,
	cocoa_vk_gfx_ctx_swap_interval,
	cocoa_vk_gfx_ctx_set_video_mode,
#if MAC_OS_X_VERSION_10_7 && defined(OSX)
	cocoa_vk_gfx_ctx_get_video_size_osx10_7_and_up,
#else
	cocoa_vk_gfx_ctx_get_video_size,
#endif
	NULL, /* get_refresh_rate */
	NULL, /* get_video_output_size */
	NULL, /* get_video_output_prev */
	NULL, /* get_video_output_next */
	cocoa_get_metrics,
	NULL, /* translate_aspect */
#ifdef OSX
	cocoa_update_title,
#else
	NULL, /* update_title */
#endif
	cocoa_vk_gfx_ctx_check_window,
#if defined(HAVE_COCOA_METAL)
	cocoa_vk_gfx_ctx_set_resize,
#else
	NULL, /* set_resize */
#endif
	cocoa_has_focus,
	cocoa_vk_gfx_ctx_suppress_screensaver,
#if defined(HAVE_COCOATOUCH)
	false,
#else
	true,
#endif
	cocoa_vk_gfx_ctx_swap_buffers,
	cocoa_vk_gfx_ctx_input_driver,
	cocoa_vk_gfx_ctx_get_proc_address,
	NULL, /* image_buffer_init */
	NULL, /* image_buffer_write */
	NULL, /* show_mouse */
	"cocoavk",
	cocoa_vk_gfx_ctx_get_flags,
	cocoa_vk_gfx_ctx_set_flags,
	cocoa_vk_gfx_ctx_bind_hw_render,
	cocoa_vk_gfx_ctx_get_context_data,
	NULL  /* make_current */
};
