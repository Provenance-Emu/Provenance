#ifndef __MDFN_NES_INPUT_CURSOR_H
#define __MDFN_NES_INPUT_CURSOR_H

void NESCURSOR_PaletteChanged(void);
void NESCURSOR_DrawCursor(uint8 *pix, int pix_y, int xc, int yc);
void NESCURSOR_DrawGunSight(int w, uint8 *pix, int pix_y, int xc, int yc);

#endif
