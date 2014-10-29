#ifndef __MDFN_VIDEO_PRIMITIVES_H
#define __MDFN_VIDEO_PRIMITIVES_H

// Note: For simplicity, these functions do NOT perform surface dimension clipping.

void MDFN_DrawRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color);
void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, uint32 fill_color);
void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 fill_color);
void MDFN_DrawLine(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color);
#endif
