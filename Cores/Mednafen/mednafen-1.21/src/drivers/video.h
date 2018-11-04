#ifndef __MDFN_DRIVERS_VIDEO_H
#define __MDFN_DRIVERS_VIDEO_H

enum
{
 VIDEOIP_OFF = 0,	// Off should always be 0 here.
 VIDEOIP_BILINEAR,
 VIDEOIP_LINEAR_X,
 VIDEOIP_LINEAR_Y
};

struct WMInputBehavior
{
 bool Cursor;
 bool MouseAbs;
 bool MouseRel;
 bool Grab;
};

//
// Functions called from main thread:
//
void BlitScreen(MDFN_Surface *, const MDFN_Rect *DisplayRect, const int32 *LineWidths, const int rotated, const int InterlaceField, const bool take_ssnapshot);

void Video_ShowNotice(MDFN_NoticeType t, char* s);

// source_alpha = 0 (disabled)
//	        = 1 (enabled)
//              = -1 (enabled only if it will be hardware-accelerated, IE via OpenGL)
void BlitRaw(MDFN_Surface *src, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, int source_alpha = 1);

//
void Video_MakeSettings(std::vector <MDFNSetting> &settings);

void Video_Init(void) MDFN_COLD;

void Video_Sync(MDFNGI* gi);

void Video_Exposed(void);

void Video_Kill(void) MDFN_COLD;

bool Video_ErrorPopup(bool warning, const char* title, const char* text);

void Video_SetWMInputBehavior(const WMInputBehavior& beeeeees);


//
// Functions called from game thread:
//
void Video_PtoV(const int in_x, const int in_y, float* out_x, float* out_y);
float Video_PtoV_J(const int32 inv, const bool axis, const bool scr_scale);

#endif
