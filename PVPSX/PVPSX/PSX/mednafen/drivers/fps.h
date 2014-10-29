#ifndef __MDFN_DRIVERS_FPS_H
#define __MDFN_DRIVERS_FPS_H

void FPS_Init(void);		// GT
void FPS_IncVirtual(void);	// GT
void FPS_IncDrawn(void);	// GT
void FPS_IncBlitted(void);	// GT
void FPS_UpdateCalc(void);	// GT

void FPS_Draw(MDFN_Surface *target, const int xpos, const int ypos);	// MT
void FPS_DrawToScreen(SDL_Surface *screen, int rs, int gs, int bs, int as, unsigned offsx, unsigned offsy);	// MT

bool FPS_IsActive(int *w, int *h);
void FPS_ToggleView(void);	// GT

#endif
