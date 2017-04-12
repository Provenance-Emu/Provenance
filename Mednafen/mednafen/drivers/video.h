#ifndef __MDFN_DRIVERS_VIDEO_H
#define __MDFN_DRIVERS_VIDEO_H

enum
{
 VIDEOIP_OFF = 0,	// Off should always be 0 here.
 VIDEOIP_BILINEAR,
 VIDEOIP_LINEAR_X,
 VIDEOIP_LINEAR_Y
};

void Video_PtoV(const int in_x, const int in_y, int32 *out_x, int32 *out_y);
int32 Video_PtoV_J(const int32 inv, const bool axis, const bool scr_scale);

void BlitScreen(MDFN_Surface *, const MDFN_Rect *DisplayRect, const int32 *LineWidths, const int InterlaceField, const bool take_ssnapshot);

int VideoResize(int nw, int nh);

void VideoShowMessage(char *text);

// source_alpha = 0 (disabled)
//	        = 1 (enabled)
//              = -1 (enabled only if it will be hardware-accelerated, IE via OpenGL)
void BlitRaw(MDFN_Surface *src, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, int source_alpha = 1);

//
void Video_MakeSettings(std::vector <MDFNSetting> &settings);

// Called from the main thread
void Video_Init(MDFNGI *gi);

// Called from the main thread
void Video_Kill(void);

#if 0
// Called from the game thread
void Video_GetInternalBB(uint32 **XBuf, MDFN_Rect **LineWidths);

// Called from the game thread
void Video_SetInternalBBReady(const MDFN_Rect &DisplayRect);

// Called from the main thread.
bool Video_ScreenBlitReady(void);

// Called from the main thread.
void Video_BlitToScreen(void);
#endif

#endif
