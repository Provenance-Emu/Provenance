#include "main.h"
#include "video.h"

static MDFN_Surface* VideoBuffer = NULL;
static MDFN_Rect* VideoLineWidths = NULL;
static VideoDriver* VDriver = NULL;
static MDFN_Rect DestRect;



bool Video_Init(MDFNGI* CurGame)
{
 const double min_vsync_bp_time = 550.0 / (1000 * 1000);
 const double hsync_time_fract = 0.08;
 const int vsync_length = 3;
 const int hcel_gran = 8;
 const int min_hporch = hcel_gran;
 const int min_vporch = 1;

 double par = ((double)CurGame->nominal_width / CurGame->lcm_width) / ((double)CurGame->nominal_height / CurGame->lcm_height);
 double vrate = (double)CurGame->fps / (65536 * 256);
 double pixclock;
 int h_total;
 int v_sync;
 int v_bp;
 int v_total;
 int xres = 0;
 int yres = 0; 

 xres = CurGame->lcm_width;
 yres = CurGame->lcm_height;

 while(xres < 256)
 {
  xres *= 2;
  par /= 2;
 }

 {
  int new_xres;

  new_xres = (xres + hcel_gran - 1);
  new_xres -= new_xres % hcel_gran;

  par *= (double)xres / new_xres;
  xres = new_xres;
 }

 while(yres < 480)
 {
  yres *= 2;
  par *= 2;
 }

 for(int vtotal = yres + 5; vtotal < yres + (yres / 2); vtotal++)
 {
  for(int htotal = xres; htotal < xres + (xres / 2); htotal++)
  {
   double hrate = vtotal * vrate;
   double pixclock = htotal * vtotal * vrate;
   //
   int vfp = 0;
   int vsync = 3;
   int vbp = std::max<int>(0, ceil(0.000550 * hrate) - vsync);
   int vblank = vfp + vsync + vbp;
   //
   int hfp = 8;
   int hsync = ceil(0.08 * htotal);
   int hblank = floor(0.5 + htotal * std::max<double>(0.20, (0.30 - 3000.0 / hrate)));
   int hbp = hblank - hfp - hsync;

   if((hblank + xres) > htotal || hbp < 0)
    continue;

   if((vblank + yres) > vtotal)
    continue;
  }
 }

 VideoBuffer = new MDFN_Surface(NULL, CurGame->fb_width, CurGame->fb_height, CurGame->fb_width, mp.format);
 VideoLineWidths = (MDFN_Rect*)calloc(CurGame->fb_height, sizeof(MDFN_Rect));

 return(true);
}

bool Video_Kill(void)
{
 if(VideoBuffer)
 {
  delete VideoBuffer;
  VideoBuffer = NULL;
 }

 if(VideoLineWidths)
 {
  delete VideoLineWidths;
  VideoLineWidths = NULL;
 }

 if(VDriver)
 {
  delete VDriver;
  VDriver = NULL;
 }

 return(true);
}

void Video_GetSurface(MDFN_Surface** ps, MDFN_Rect **plw)
{
 *ps = VideoBuffer;
 *plw = VideoLineWidths;
}


void Video_Blit(EmulateSpecStruct* es)
{
 if(VDriver)
 {
  VDriver->BlitSurface(VideoBuffer, &es->DisplayRect, &DestRect);
 }
}

