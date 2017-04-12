#include "main.h"
#include "video.h"
#include "Video_VGA.h"


VideoDriver_VGA::VideoDriver_VGA()
{
 SaveRestoreState(false);
}

VideoDriver_VGA::~VideoDriver_VGA()
{
 SaveRestoreState(true);
}

static uint32 GrabStateSize(void)
{
 //
 // Grab state size.
 //
 _go32_dpmi_registers r;

 memset(&r, 0, sizeof(r));

 r.h.ah = 0x1C;
 r.h.al = 0x00;
 r.x.cx = 0x07;

 if(_go32_dpmi_simulate_int(0x10, &r) != 0)
  abort();

 return(r.x.bx * 64);
}

void VideoDriver_VGA::SaveRestoreState(bool restore)
{
 uint32 size;
 _go32_dpmi_seginfo bbuf;
 _go32_dpmi_registers r;

 memset(&bbuf, 0, sizeof(bbuf));
 memset(&r, 0, sizeof(r));

 size = GrabStateSize();
 saved_state.resize(size);

 bbuf.size = (size + 15) / 16;
 if(_go32_dpmi_allocate_dos_memory(&bbuf) != 0)
  abort();

 r.h.ah = 0x1C;
 if(restore)
  r.h.al = 0x02;
 else
  r.h.al = 0x01;
 r.x.cx = 0x07;
 
 r.x.es = bbuf.rm_segment;
 r.x.bx = 0;

 if(restore)
  _dosmemputb(&saved_state[0], saved_state.size(), bbuf.rm_segment << 4);

 if(_go32_dpmi_simulate_int(0x10, &r) != 0)
  abort();

 if(!restore)
  _dosmemgetb(bbuf.rm_segment << 4, saved_state.size(), &saved_state[0]);

 _go32_dpmi_free_dos_memory(&bbuf);
}

void VideoDriver_VGA::SetMode(ModeParams* mode)
{
 _go32_dpmi_registers r;
 memset(&r, 0, sizeof(r));

 r.h.ah = 0x00;
 r.h.al = 0x13;

 _go32_dpmi_simulate_int(0x10, &r);

 /*
 vertical total
 vertical display end

 vertical retrace start
 vertical retrace end
 vertical blank start
 vertical blank end


 horizontal total
 horizontal display end
 horizontal blank start
 horizontal blank end
 horizontal retrace start
 horizontal retrace end

 horizontal_rate = pixel_rate / horizontal_total;
 vertical_rate = pixel_rate / (vertical_total * horizontal_total);

 */

 mode->w = 320;
 mode->h = 200;
 mode->pixel_aspect_ratio = 1.0;

 mode->fullscreen = true;
 mode->double_buffered = false;

 mode->format.bpp = 8;
 mode->format.colorspace = MDFN_COLORSPACE_RGB;

 mode->format.Rshift = 0;
 mode->format.Gshift = 0;
 mode->format.Bshift = 0;
 mode->format.Ashift = 16;

 mode->format.Rprec = 6;
 mode->format.Gprec = 6;
 mode->format.Bprec = 6;
 mode->format.Aprec = 0;
}

void VideoDriver_VGA::BlitSurface(const MDFN_Surface *src_surface, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, bool source_alpha, unsigned ip, int scanlines, const MDFN_Rect *original_src_rect, int rotated)
{

}

void VideoDriver_VGA::Flip(void)
{

}

