#ifndef __MDFN_DRIVERS_FPS_H
#define __MDFN_DRIVERS_FPS_H

void FPS_Init(const unsigned fps_pos, const unsigned fps_scale, const unsigned fps_font, const uint32 fps_tcolor, const uint32 fps_bgcolor) MDFN_COLD;	// GT
void FPS_IncVirtual(int64 vcycles);	// GT
void FPS_IncDrawn(void);	// GT
void FPS_IncBlitted(void);	// GT
void FPS_UpdateCalc(void);	// GT

void FPS_DrawToScreen(int rs, int gs, int bs, int as, const MDFN_Rect& cr, unsigned min_screen_w_h);	// MT

void FPS_ToggleView(void);	// GT

#endif
