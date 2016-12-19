#ifndef __MDFN_DRIVERS_VIDEO_VGA_H
#define __MDFN_DRIVERS_VIDEO_VGA_H

#include <vector>

class VideoDriver_VGA : public VideoDriver
{
 public:

 VideoDriver_VGA();
 ~VideoDriver_VGA();

 void SetMode(ModeParams* mode);
 void BlitSurface(const MDFN_Surface *src_surface, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, bool source_alpha = false, unsigned ip = 0, int scanlines = 0, const MDFN_Rect *original_src_rect = NULL, int rotated = MDFN_ROTATE0);
 void Flip(void);

 private:

 void SaveRestoreState(bool restore);

 std::vector<uint8> saved_state;
};

#endif
