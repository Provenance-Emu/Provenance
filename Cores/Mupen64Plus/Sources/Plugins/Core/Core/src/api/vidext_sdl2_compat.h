/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2012 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

#include <SDL_config.h>
#include <SDL_surface.h>

#ifndef USE_GLES

#ifndef SDL_VIDEO_OPENGL
#error SDL is not build with OpenGL support. Try USE_GLES=1
#endif

#else // !USE_GLES

#ifndef SDL_VIDEO_OPENGL_ES2
#error SDL is not build with OpenGL ES2 support. Try USE_GLES=0
#endif

#endif // !USE_GLES

typedef struct SDL_VideoInfo
{
    Uint32 hw_available:1;
    Uint32 wm_available:1;
    Uint32 UnusedBits1:6;
    Uint32 UnusedBits2:1;
    Uint32 blit_hw:1;
    Uint32 blit_hw_CC:1;
    Uint32 blit_hw_A:1;
    Uint32 blit_sw:1;
    Uint32 blit_sw_CC:1;
    Uint32 blit_sw_A:1;
    Uint32 blit_fill:1;
    Uint32 UnusedBits3:16;
    Uint32 video_mem;

    SDL_PixelFormat *vfmt;

    int current_w;
    int current_h;
} SDL_VideoInfo;

#define SDL_FULLSCREEN      0x00800000
#define SDL_RESIZABLE       0x01000000
#define SDL_NOFRAME         0x02000000
#define SDL_OPENGL          0x04000000
#define SDL_HWSURFACE       0x08000001  /**< \note Not used */

#define SDL_BUTTON_WHEELUP      4
#define SDL_BUTTON_WHEELDOWN    5

int initialized_video = 0;

static SDL_Window *SDL_VideoWindow = NULL;
static SDL_Surface *SDL_VideoSurface = NULL;
static SDL_Surface *SDL_PublicSurface = NULL;
static SDL_Rect SDL_VideoViewport;
static char *wm_title = NULL;
static Uint32 SDL_VideoFlags = 0;
static SDL_GLContext *SDL_VideoContext = NULL;
static SDL_Surface *SDL_VideoIcon;

static void
SDL_WM_SetCaption(const char *title, const char *icon)
{
    if (wm_title) {
        SDL_free(wm_title);
    }
    if (title) {
        wm_title = SDL_strdup(title);
    } else {
        wm_title = NULL;
    }
    SDL_SetWindowTitle(SDL_VideoWindow, wm_title);
}

static int
GetVideoDisplay()
{
    const char *variable = SDL_getenv("SDL_VIDEO_FULLSCREEN_DISPLAY");
    if ( !variable ) {
        variable = SDL_getenv("SDL_VIDEO_FULLSCREEN_HEAD");
    }
    if ( variable ) {
        return SDL_atoi(variable);
    } else {
        return 0;
    }
}

static const SDL_VideoInfo *
SDL_GetVideoInfo(void)
{
    static SDL_VideoInfo info;
    SDL_DisplayMode mode;

    /* Memory leak, compatibility code, who cares? */
    if (!info.vfmt && SDL_GetDesktopDisplayMode(GetVideoDisplay(), &mode) == 0) {
        info.vfmt = SDL_AllocFormat(mode.format);
        info.current_w = mode.w;
        info.current_h = mode.h;
    }
    return &info;
}

static SDL_Rect **
SDL_ListModes(const SDL_PixelFormat * format, Uint32 flags)
{
    int i, nmodes;
    SDL_Rect **modes;

    if (!initialized_video) {
        return NULL;
    }

    if (!(flags & SDL_FULLSCREEN)) {
        return (SDL_Rect **) (-1);
    }

    if (!format) {
        format = SDL_GetVideoInfo()->vfmt;
    }

    /* Memory leak, but this is a compatibility function, who cares? */
    nmodes = 0;
    modes = NULL;
    for (i = 0; i < SDL_GetNumDisplayModes(GetVideoDisplay()); ++i) {
        SDL_DisplayMode mode;
        int bpp;

        SDL_GetDisplayMode(GetVideoDisplay(), i, &mode);
        if (!mode.w || !mode.h) {
            return (SDL_Rect **) (-1);
        }

        /* Copied from src/video/SDL_pixels.c:SDL_PixelFormatEnumToMasks */
        if (SDL_BYTESPERPIXEL(mode.format) <= 2) {
            bpp = SDL_BITSPERPIXEL(mode.format);
        } else {
            bpp = SDL_BYTESPERPIXEL(mode.format) * 8;
        }

        if (bpp != format->BitsPerPixel) {
            continue;
        }
        if (nmodes > 0 && modes[nmodes - 1]->w == mode.w
            && modes[nmodes - 1]->h == mode.h) {
            continue;
        }

        modes = SDL_realloc(modes, (nmodes + 2) * sizeof(*modes));
        if (!modes) {
            return NULL;
        }
        modes[nmodes] = (SDL_Rect *) SDL_malloc(sizeof(SDL_Rect));
        if (!modes[nmodes]) {
            return NULL;
        }
        modes[nmodes]->x = 0;
        modes[nmodes]->y = 0;
        modes[nmodes]->w = mode.w;
        modes[nmodes]->h = mode.h;
        ++nmodes;
    }
    if (modes) {
        modes[nmodes] = NULL;
    }
    return modes;
}

static void
SDL_GL_SwapBuffers(void)
{
    SDL_GL_SwapWindow(SDL_VideoWindow);
}

static int
SDL_WM_ToggleFullScreen(SDL_Surface * surface)
{
    int window_w;
    int window_h;

    if (!SDL_PublicSurface) {
        SDL_SetError("SDL_SetVideoMode() hasn't been called");
        return 0;
    }

    /* Do the physical mode switch */
    if (SDL_GetWindowFlags(SDL_VideoWindow) & SDL_WINDOW_FULLSCREEN) {
        if (SDL_SetWindowFullscreen(SDL_VideoWindow, 0) < 0) {
            return 0;
        }
        SDL_PublicSurface->flags &= ~SDL_FULLSCREEN;
    } else {
        if (SDL_SetWindowFullscreen(SDL_VideoWindow, 1) < 0) {
            return 0;
        }
        SDL_PublicSurface->flags |= SDL_FULLSCREEN;
    }

    /* Center the public surface in the window surface */
    SDL_GetWindowSize(SDL_VideoWindow, &window_w, &window_h);
    SDL_VideoViewport.x = 0;
    SDL_VideoViewport.y = 0;
    SDL_VideoViewport.w = window_w;
    SDL_VideoViewport.h = window_h;

    /* We're done! */
    return 1;
}

static int
SDL_ResizeVideoMode(int width, int height, int bpp, Uint32 flags)
{
    int w, h;

    /* We can't resize something we don't have... */
    if (!SDL_PublicSurface) {
        return -1;
    }

    /* We probably have to recreate the window in fullscreen mode */
    if (flags & SDL_FULLSCREEN) {
        return -1;
    }

    /* I don't think there's any change we can gracefully make in flags */
    if (flags != SDL_VideoFlags) {
        return -1;
    }
    if (bpp != SDL_VideoSurface->format->BitsPerPixel) {
        return -1;
    }

    /* Resize the window */
    SDL_GetWindowSize(SDL_VideoWindow, &w, &h);
    if (w != width || h != height) {
        SDL_SetWindowSize(SDL_VideoWindow, width, height);
    }

    SDL_VideoSurface->w = width;
    SDL_VideoSurface->h = height;

    return 0;
}

static int
SDL_CompatEventFilter(void *userdata, SDL_Event * event)
{
    SDL_Event fake;

    switch (event->type) {
    case SDL_WINDOWEVENT:
        switch (event->window.event) {
        case SDL_WINDOWEVENT_CLOSE:
            fake.type = SDL_QUIT;
            SDL_PushEvent(&fake);
            break;
        }
    case SDL_TEXTINPUT:
        {
            /* FIXME: Generate an old style key repeat event if needed */
            //printf("TEXTINPUT: '%s'\n", event->text.text);
            break;
        }
    case SDL_MOUSEMOTION:
        {
            event->motion.x -= SDL_VideoViewport.x;
            event->motion.y -= SDL_VideoViewport.y;
            break;
        }
    case SDL_MOUSEBUTTONDOWN:
    case SDL_MOUSEBUTTONUP:
        {
            event->button.x -= SDL_VideoViewport.x;
            event->button.y -= SDL_VideoViewport.y;
            break;
        }
    case SDL_MOUSEWHEEL:
        {
            Uint8 button;
            int x, y;

            if (event->wheel.y == 0) {
                break;
            }

            SDL_GetMouseState(&x, &y);

            if (event->wheel.y > 0) {
                button = SDL_BUTTON_WHEELUP;
            } else {
                button = SDL_BUTTON_WHEELDOWN;
            }

            fake.button.button = button;
            fake.button.x = x;
            fake.button.y = y;
            fake.button.windowID = event->wheel.windowID;

            fake.type = SDL_MOUSEBUTTONDOWN;
            fake.button.state = SDL_PRESSED;
            SDL_PushEvent(&fake);

            fake.type = SDL_MOUSEBUTTONUP;
            fake.button.state = SDL_RELEASED;
            SDL_PushEvent(&fake);
            break;
        }

    }
    return 1;
}

static void
GetEnvironmentWindowPosition(int w, int h, int *x, int *y)
{
    int display = GetVideoDisplay();
    const char *window = SDL_getenv("SDL_VIDEO_WINDOW_POS");
    const char *center = SDL_getenv("SDL_VIDEO_CENTERED");
    if (window) {
        if (SDL_sscanf(window, "%d,%d", x, y) == 2) {
            return;
        }
        if (SDL_strcmp(window, "center") == 0) {
            center = window;
        }
    }
    if (center) {
        *x = SDL_WINDOWPOS_CENTERED_DISPLAY(display);
        *y = SDL_WINDOWPOS_CENTERED_DISPLAY(display);
    }
}

static void SDL2_DestroyWindow(void)
{
    /* Destroy existing window */
    SDL_PublicSurface = NULL;
    if (SDL_VideoSurface) {
        SDL_VideoSurface->flags &= ~SDL_DONTFREE;
        SDL_FreeSurface(SDL_VideoSurface);
        SDL_VideoSurface = NULL;
    }
    if (SDL_VideoContext) {
        /* SDL_GL_MakeCurrent(0, NULL); *//* Doesn't do anything */
        SDL_GL_DeleteContext(SDL_VideoContext);
        SDL_VideoContext = NULL;
    }
    if (SDL_VideoWindow) {
        SDL_DestroyWindow(SDL_VideoWindow);
        SDL_VideoWindow = NULL;
    }
}

static SDL_Surface *
SDL_SetVideoMode(int width, int height, int bpp, Uint32 flags)
{
    SDL_DisplayMode desktop_mode;
    int display = GetVideoDisplay();
    int window_x = SDL_WINDOWPOS_UNDEFINED_DISPLAY(display);
    int window_y = SDL_WINDOWPOS_UNDEFINED_DISPLAY(display);
    Uint32 window_flags;
    Uint32 surface_flags;

    if (!initialized_video) {
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) < 0) {
            return NULL;
        }
        initialized_video = 1;
    }

    SDL_GetDesktopDisplayMode(display, &desktop_mode);

    if (width == 0) {
        width = desktop_mode.w;
    }
    if (height == 0) {
        height = desktop_mode.h;
    }
    if (bpp == 0) {
        bpp = SDL_BITSPERPIXEL(desktop_mode.format);
    }

    /* See if we can simply resize the existing window and surface */
    if (SDL_ResizeVideoMode(width, height, bpp, flags) == 0) {
        return SDL_PublicSurface;
    }

    /* Destroy existing window */
    if (SDL_VideoWindow)
        SDL_GetWindowPosition(SDL_VideoWindow, &window_x, &window_y);
    SDL2_DestroyWindow();

    /* Set up the event filter */
    if (!SDL_GetEventFilter(NULL, NULL)) {
        SDL_SetEventFilter(SDL_CompatEventFilter, NULL);
    }

#ifndef USE_GLES
    if (l_ForceCompatibilityContext)
    {
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
    }
#else // !USE_GLES
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#endif // !USE_GLES

    /* Create a new window */
    window_flags = SDL_WINDOW_SHOWN;
    if (flags & SDL_FULLSCREEN) {
        window_flags |= SDL_WINDOW_FULLSCREEN;
    }
    if (flags & SDL_OPENGL) {
        window_flags |= SDL_WINDOW_OPENGL;
    }
    if (flags & SDL_RESIZABLE) {
        window_flags |= SDL_WINDOW_RESIZABLE;
    }
    if (flags & SDL_NOFRAME) {
        window_flags |= SDL_WINDOW_BORDERLESS;
    }
    GetEnvironmentWindowPosition(width, height, &window_x, &window_y);
    SDL_VideoWindow =
        SDL_CreateWindow(wm_title, window_x, window_y, width, height,
                         window_flags);
    if (!SDL_VideoWindow) {
        return NULL;
    }
    SDL_SetWindowIcon(SDL_VideoWindow, SDL_VideoIcon);

    window_flags = SDL_GetWindowFlags(SDL_VideoWindow);
    surface_flags = 0;
    if (window_flags & SDL_WINDOW_FULLSCREEN) {
        surface_flags |= SDL_FULLSCREEN;
    }
    if ((window_flags & SDL_WINDOW_OPENGL) && (flags & SDL_OPENGL)) {
        surface_flags |= SDL_OPENGL;
    }
    if (window_flags & SDL_WINDOW_RESIZABLE) {
        surface_flags |= SDL_RESIZABLE;
    }
    if (window_flags & SDL_WINDOW_BORDERLESS) {
        surface_flags |= SDL_NOFRAME;
    }

    SDL_VideoFlags = flags;

    /* If we're in OpenGL mode, just create a stub surface and we're done! */
    if (flags & SDL_OPENGL) {
        SDL_VideoContext = SDL_GL_CreateContext(SDL_VideoWindow);
        if (!SDL_VideoContext) {
            return NULL;
        }
        if (SDL_GL_MakeCurrent(SDL_VideoWindow, SDL_VideoContext) < 0) {
            return NULL;
        }
        SDL_VideoSurface =
            SDL_CreateRGBSurfaceFrom(NULL, width, height, bpp, 0, 0, 0, 0, 0);
        if (!SDL_VideoSurface) {
            return NULL;
        }
        SDL_VideoSurface->flags |= surface_flags;
        SDL_PublicSurface = SDL_VideoSurface;
        return SDL_PublicSurface;
    }

    /* We're finally done! */
    return NULL;
}
