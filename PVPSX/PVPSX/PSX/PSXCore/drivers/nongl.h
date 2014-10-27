#ifndef __MDFN_DRIVERS_NONGL_H
#define __MDFN_DRIVERS_NONGL_H

// This function DOES NOT handle format conversions; IE the src_surface and dest_surface should be in the same color formats.
// Also, clipping is...sketchy.  Just don't pass negative coordinates in the rects, and it should be ok.
void MDFN_StretchBlitSurface(MDFN_Surface *src_surface, const MDFN_Rect *src_rect, MDFN_Surface *dest_surface, const MDFN_Rect *dest_rect, bool source_alpha = false, int scanlines = 0, const MDFN_Rect *original_src_rect = NULL, int rotated = MDFN_ROTATE0, int InterlaceField = -1);

#endif
