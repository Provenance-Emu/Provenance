#if defined(SUPPORT_DISPMANX)
#include "linux-dist/dispmanx.h"
#include "linux-dist/main.h"

#include <bcm_host.h>
#include <EGL/egl.h>

void dispmanx_window_create()
{
	DISPMANX_DISPLAY_HANDLE_T dispman_display;
	DISPMANX_UPDATE_HANDLE_T dispman_update;
	DISPMANX_ELEMENT_HANDLE_T dispman_element;
	VC_RECT_T src_rect;
	VC_RECT_T dst_rect;
	VC_DISPMANX_ALPHA_T dispman_alpha;
	uint32_t screen_width;
	uint32_t screen_height;
	uint32_t window_width;
	uint32_t window_height;

	dispman_alpha.flags = DISPMANX_FLAGS_ALPHA_FIXED_ALL_PIXELS;
	dispman_alpha.opacity = 0xFF;
	dispman_alpha.mask = 0;

	graphics_get_display_size(0 /* LCD */, &screen_width, &screen_height);

	window_width = settings.dispmanx.Width;
	window_height = settings.dispmanx.Height;

	if(window_width < 1)
		window_width = screen_width;
	if(window_height < 1)
		window_height = screen_height;

	src_rect.x = 0;
	src_rect.y = 0;
	src_rect.width = window_width << 16;
	src_rect.height = window_height << 16;

	if(settings.dispmanx.Keep_Aspect)
	{
		float screen_aspect = (float)screen_width / screen_height;
		float window_aspect = (float)window_width / window_height;
		if(screen_aspect > window_aspect)
		{
			dst_rect.width = window_width * screen_height / window_height;
			dst_rect.height = screen_height;
		}
		else
		{
			dst_rect.width = screen_width;
			dst_rect.height = window_height * screen_width / window_width;
		}
		dst_rect.x = (screen_width - dst_rect.width) / 2;
		dst_rect.y = (screen_height - dst_rect.height) / 2;
	}
	else
	{
		dst_rect.x = 0;
		dst_rect.y = 0;
		dst_rect.width = screen_width;
		dst_rect.height = screen_height;
	}

	dispman_display = vc_dispmanx_display_open( 0 /* LCD */);
	dispman_update = vc_dispmanx_update_start( 0 );
	dispman_element = vc_dispmanx_element_add(dispman_update, dispman_display,
			0 /*layer*/, &dst_rect, 0 /*src*/,
			&src_rect, DISPMANX_PROTECTION_NONE,
			&dispman_alpha /*alpha*/, 0 /*clamp*/, 0 /*transform*/);

	static EGL_DISPMANX_WINDOW_T native_window;
	native_window.element = dispman_element;
	native_window.width = window_width;
	native_window.height = window_height;
	vc_dispmanx_update_submit_sync( dispman_update );

	x11_disp = (void*)dispman_display;
	x11_win = (void*)&native_window;
}
#endif
