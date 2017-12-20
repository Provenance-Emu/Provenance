#ifndef __MDFN_DRIVERS_VIDEO_H
#define __MDFN_DRIVERS_VIDEO_H

bool Video_Init(MDFNGI*);
bool Video_Kill(void);
void Video_Blit(EmulateSpecStruct* es);
void Video_GetSurface(MDFN_Surface** ps, MDFN_Rect **plw);

class VideoDriver
{
 public:

 VideoDriver();
 virtual ~VideoDriver() = 0;

 struct ModeParams
 {
  unsigned w;			// In and Out
  unsigned h;			// In and Out
  MDFN_PixelFormat format;	// format.bpp In, all Out
  double refresh_rate;		// In and Out
  bool fullscreen;		// In and Out
  bool double_buffered;		// In and Out
  double pixel_aspect_ratio;	// In and Out
 };

 virtual void SetMode(ModeParams* mode) = 0;

 virtual void BlitSurface(const MDFN_Surface *src_surface, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, bool source_alpha = false, unsigned ip = 0, int scanlines = 0, const MDFN_Rect *original_src_rect = NULL, int rotated = MDFN_ROTATE0) = 0;

 virtual void Flip(void) = 0;

 // Ideas for DOS and realtime fbdev:
#if 0
 void WaitVSync(void);
 bool TestVSync(void);
 bool TestVSyncSLC(void);	// Test if vsync start happened since last call.

 uint32 GetPixClockGranularity(void);
 uint32 GetPixClock(void);
 void SetPixClock(uint32 val); 
#endif

 // static global setting and per-module setting defs here?
};


#endif
