#ifndef __MDFN_DRIVERS_VIDEO_H
#define __MDFN_DRIVERS_VIDEO_H

enum
{
 VDRIVER_OPENGL = 0,
 VDRIVER_SOFTSDL = 1,
 VDRIVER_OVERLAY = 2
};

enum
{
 VIDEOIP_OFF = 0,	// Off should always be 0 here.
 VIDEOIP_BILINEAR,
 VIDEOIP_LINEAR_X,
 VIDEOIP_LINEAR_Y
};

void PtoV(const int in_x, const int in_y, int32 *out_x, int32 *out_y);
int32 PtoV_J(const int32 inv, const bool axis, const bool scr_scale);

int InitVideo(MDFNGI *gi);
void KillVideo(void);
void BlitScreen(MDFN_Surface *, const MDFN_Rect *DisplayRect, const int32 *LineWidths, const int InterlaceField, const bool take_ssnapshot);

void ToggleFS();
void ClearVideoSurfaces(void);

void VideoAppActive(bool gain);

#define NTVB_HQ2X       1
#define NTVB_HQ3X       2
#define NTVB_HQ4X	3

#define NTVB_SCALE2X    4
#define NTVB_SCALE3X    5
#define NTVB_SCALE4X	6

#define NTVB_NN2X	7
#define NTVB_NN3X	8
#define NTVB_NN4X	9

#define NTVB_NNY2X       10
#define NTVB_NNY3X       11
#define NTVB_NNY4X       12

#define NTVB_2XSAI       13
#define NTVB_SUPER2XSAI  14
#define NTVB_SUPEREAGLE  15

//#define NTVB_SCANLINES	 16

int VideoResize(int nw, int nh);

void VideoShowMessage(UTF8 *text);

// source_alpha = 0 (disabled)
//	        = 1 (enabled)
//              = -1 (enabled only if it will be hardware-accelerated, IE via OpenGL)
void BlitRaw(MDFN_Surface *src, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, int source_alpha = 1);

// Called from the main thread
bool Video_Init(MDFNGI *gi);

// Called from the main thread
void Video_Kill(void);

// Called from the game thread
void Video_GetInternalBB(uint32 **XBuf, MDFN_Rect **LineWidths);

// Called from the game thread
void Video_SetInternalBBReady(const MDFN_Rect &DisplayRect);

// Called from the main thread.
bool Video_ScreenBlitReady(void);

// Called from the main thread.
void Video_BlitToScreen(void);


class SDL_to_MDFN_Surface_Wrapper : public MDFN_Surface
{
 public:
 INLINE SDL_to_MDFN_Surface_Wrapper(SDL_Surface *sdl_surface) : ss(sdl_surface)
 {
  // Locking should be first thing.
  if(SDL_MUSTLOCK(ss))
   SDL_LockSurface(ss);

  format.bpp = ss->format->BitsPerPixel;
  format.colorspace = MDFN_COLORSPACE_RGB;
  format.Rshift = ss->format->Rshift;
  format.Gshift = ss->format->Gshift;
  format.Bshift = ss->format->Bshift;
  format.Ashift = ss->format->Ashift;

  format.Rprec = 8 - ss->format->Rloss;
  format.Gprec = 8 - ss->format->Gloss;
  format.Bprec = 8 - ss->format->Bloss;
  format.Aprec = 8 - ss->format->Aloss;

  pixels_is_external = true;

  pixels16 = NULL;
  pixels = NULL;

  if(ss->format->BitsPerPixel == 16)
  {
   pixels16 = (uint16*)ss->pixels;
   pitchinpix = ss->pitch >> 1;
  }
  else
  {
   pixels = (uint32*)ss->pixels;
   pitchinpix = ss->pitch >> 2;
  }

  format = MDFN_PixelFormat(MDFN_COLORSPACE_RGB, sdl_surface->format->Rshift, sdl_surface->format->Gshift, sdl_surface->format->Bshift, sdl_surface->format->Ashift);

  w = ss->w;
  h = ss->h;
 }

 INLINE ~SDL_to_MDFN_Surface_Wrapper()
 {
  if(SDL_MUSTLOCK(ss))
   SDL_UnlockSurface(ss);
  ss = NULL;
 }
 private:
 SDL_Surface *ss;
};

#endif
