/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"

#ifdef WIN32
#include <windows.h>
#endif

#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <trio/trio.h>
#include <algorithm>

#include "video.h"
#include "opengl.h"
#include "shader.h"
#include "nongl.h"
#include "overlay.h"

#include "icon.h"
#include "netplay.h"
#include "cheat.h"

#include "nnx.h"
#include "debugger.h"
#include "fps.h"
#include "help.h"
#include "video-state.h"
#include "../video/selblur.h"

#ifdef WANT_FANCY_SCALERS
#include "scalebit.h"
#include "hqxx-common.h"
#include "2xSaI.h"
#endif

typedef struct
{
        int xres;
        int yres;
        double xscale, xscalefs;
        double yscale, yscalefs;
        int videoip;
        int stretch;
        int special;
        int scanlines;
	ShaderType pixshader;
} CommonVS;

static CommonVS _video;
static int _fullscreen;

static bool osd_alpha_blend;
static unsigned int vdriver = VDRIVER_OPENGL;

typedef struct
{
	const char *name;
	int id;
	int xscale;
	int yscale;
} ScalerDefinition;

static ScalerDefinition Scalers[] = 
{
	{"hq2x", NTVB_HQ2X, 2, 2 },
	{"hq3x", NTVB_HQ3X, 3, 3 },
	{"hq4x", NTVB_HQ4X, 4, 4 },

	{"scale2x", NTVB_SCALE2X, 2, 2 },
	{"scale3x", NTVB_SCALE3X, 3, 3 },
	{"scale4x", NTVB_SCALE4X, 4, 4 },

	{"nn2x", NTVB_NN2X, 2, 2 },
        {"nn3x", NTVB_NN3X, 3, 3 },
        {"nn4x", NTVB_NN4X, 4, 4 },

	{"nny2x", NTVB_NNY2X, 1, 2 },
	{"nny3x", NTVB_NNY3X, 1, 3 },
	{"nny4x", NTVB_NNY4X, 1, 4 },

	{"2xsai", NTVB_2XSAI, 2, 2 },
	{"super2xsai", NTVB_SUPER2XSAI, 2, 2 },
	{"supereagle", NTVB_SUPEREAGLE, 2, 2 },

	//{ "scanlines", NTVB_SCANLINES, 1, 2 },
	{ 0 }
};

static MDFNGI *VideoGI;

static int best_xres = 0, best_yres = 0;

static int cur_xres, cur_yres, cur_flags;

static ScalerDefinition *CurrentScaler = NULL;

static SDL_Surface *screen = NULL;
static OpenGL_Blitter *ogl_blitter = NULL;
static SDL_Surface *IconSurface=NULL;

static MDFN_Rect screen_dest_rect;

static MDFN_Surface *NetSurface = NULL;
static MDFN_Rect NetRect;

static MDFN_Surface *CheatSurface = NULL;

static MDFN_Surface *HelpSurface = NULL;
static MDFN_Rect HelpRect;

static MDFN_Surface *SMSurface = NULL;
static MDFN_Rect SMRect;
static MDFN_Rect SMDRect;

static int curbpp;

static double exs,eys;
static int evideoip;

static int NeedClear = 0;
static uint32 LastBBClearTime = 0;

static MDFN_PixelFormat pf_overlay, pf_normal;

static void MarkNeedBBClear(void)
{
 NeedClear = 15;
}

static void ClearBackBuffer(void)
{
 //printf("WOO: %u\n", MDFND_GetTime());
 if(ogl_blitter)
 {
  ogl_blitter->ClearBackBuffer();
 }
 else
 {
  // Don't use SDL_FillRect() on hardware surfaces, it's borked(causes a long wait) with DirectX.
  // ...on second thought, memset() is likely borked on PPC with hardware surface memory due to use of "dcbz" on uncachable memory. :(
  //
  // We'll do an icky #ifdef kludge instead for now.
#ifdef WIN32
  if(screen->flags & SDL_HWSURFACE)
  {
   if(SDL_MUSTLOCK(screen))
    SDL_LockSurface(screen);
   memset(screen->pixels, 0, screen->pitch * screen->h);
   if(SDL_MUSTLOCK(screen))
    SDL_UnlockSurface(screen);
  }
  else
#endif
  {
   SDL_FillRect(screen, NULL, 0);
  }
 }
}

/* Return 1 if video was killed, 0 otherwise(video wasn't initialized). */
void KillVideo(void)
{
 /*
 if(IconSurface)
 {
  SDL_FreeSurface(IconSurface);
  IconSurface = NULL;
 }
 */

 if(SMSurface)
 {
  delete SMSurface;
  SMSurface = NULL;
 }

 if(CheatSurface)
 {
  delete CheatSurface;
  CheatSurface = NULL;
 }

 if(HelpSurface)
 {
  delete HelpSurface;
  HelpSurface = NULL;
 }

 if(NetSurface)
 {
  delete NetSurface;
  NetSurface = NULL;
 }

 if(ogl_blitter)
 {
  delete ogl_blitter;
  ogl_blitter = NULL;
 }

 if(vdriver == VDRIVER_OVERLAY)
  OV_Kill();

 screen = NULL;
 VideoGI = NULL;
 cur_xres = 0;
 cur_yres = 0;
 cur_flags = 0;
}

static void GenerateDestRect(void)
{
 if(_video.stretch && _fullscreen)
 {
  int nom_width, nom_height;

  if(VideoGI->rotated)
  {
   nom_width = VideoGI->nominal_height;
   nom_height = VideoGI->nominal_width;
  }
  else
  {
   nom_width = VideoGI->nominal_width;
   nom_height = VideoGI->nominal_height;
  }

  if (_video.stretch == 2 || _video.stretch == 3 || _video.stretch == 4)	// Aspect-preserve stretch
  {
   exs = (double)cur_xres / nom_width;
   eys = (double)cur_yres / nom_height;

   if(_video.stretch == 3 || _video.stretch == 4)	// Round down to nearest int.
   {
    double floor_exs = floor(exs);
    double floor_eys = floor(eys);

    if(!floor_exs || !floor_eys)
    {
     MDFN_printf(_("WARNING: Resolution is too low for stretch mode selected.  Falling back to \"aspect\" mode.\n"));
    }
    else
    {
     exs = floor_exs;
     eys = floor_eys;

     if(_video.stretch == 4)	// Round down to nearest multiple of 2.
     {
      int even_exs = (int)exs & ~1;
      int even_eys = (int)eys & ~1;

      if(!even_exs || !even_eys)
      {
       MDFN_printf(_("WARNING: Resolution is too low for stretch mode selected.  Falling back to \"aspect_int\" mode.\n"));
      }
      else
      {
       exs = even_exs;
       eys = even_eys;
      }
     }
    }
   }

   // Check if we are constrained horizontally or vertically
   if (exs > eys)
   {
    // Too tall for screen, fill vertically
    exs = eys;
   }
   else
   {
    // Too wide for screen, fill horizontally
    eys = exs;
   }

   //printf("%f %f\n", exs, eys);

   screen_dest_rect.w = (int)(exs*nom_width + 0.5); // +0.5 for rounding
   screen_dest_rect.h = (int)(eys*nom_height + 0.5); // +0.5 for rounding

   // Centering:
   int nx = (int)((cur_xres - screen_dest_rect.w) / 2);
   if(nx < 0) nx = 0;
   screen_dest_rect.x = nx;

   int ny = (int)((cur_yres - screen_dest_rect.h) / 2);
   if(ny < 0) ny = 0;
   screen_dest_rect.y = ny;
  }
  else 	// Full-stretch
  {
   screen_dest_rect.x = 0;
   screen_dest_rect.w = cur_xres;

   screen_dest_rect.y = 0;
   screen_dest_rect.h = cur_yres;

   exs = (double)cur_xres / nom_width;
   eys = (double)cur_yres / nom_height;
  }
 }
 else
 {
  if(VideoGI->rotated)
  {
   int32 ny = (int)((cur_yres - VideoGI->nominal_width * exs) / 2);
   int32 nx = (int)((cur_xres - VideoGI->nominal_height * eys) / 2);

   //if(ny < 0) ny = 0;
   //if(nx < 0) nx = 0;

   screen_dest_rect.x = _fullscreen ? nx : 0;
   screen_dest_rect.y = _fullscreen ? ny : 0;
   screen_dest_rect.w = (Uint16)(VideoGI->nominal_height * eys);
   screen_dest_rect.h = (Uint16)(VideoGI->nominal_width * exs);
  }
  else
  {
   int nx = (int)((cur_xres - VideoGI->nominal_width * exs) / 2);
   int ny = (int)((cur_yres - VideoGI->nominal_height * eys) / 2);

   // Don't check to see if the coordinates go off screen here, offscreen coordinates are valid(though weird that the user would want them...)
   // in OpenGL mode, and are clipped to valid coordinates in SDL blit mode code.
   //if(nx < 0)
   // nx = 0;
   //if(ny < 0)
   // ny = 0;

   screen_dest_rect.x = _fullscreen ? nx : 0;
   screen_dest_rect.y = _fullscreen ? ny : 0;

   //printf("%.64f %d, %f, %d\n", exs, VideoGI->nominal_width, exs * VideoGI->nominal_width, (int)(exs * VideoGI->nominal_width));
   // FIXME, stupid floating point
   screen_dest_rect.w = (Uint16)(VideoGI->nominal_width * exs + 0.000000001);
   screen_dest_rect.h = (Uint16)(VideoGI->nominal_height * eys + 0.000000001);
  }
 }


 //screen_dest_rect.y = 0;
 //screen_dest_rect.x = 0;

 // Quick and dirty kludge for VB's "hli" and "vli" 3D modes.
 screen_dest_rect.x &= ~1;
 screen_dest_rect.y &= ~1;
 //printf("%d %d\n", screen_dest_rect.x & 1, screen_dest_rect.y & 1);
}

// Argh, lots of thread safety and crashy problems with this, need to re-engineer code elsewhere.
#if 0
int VideoResize(int nw, int nh)
{
 double xs, ys;
 char buf[256];

 if(VideoGI && !_fullscreen)
 {
  std::string sn = std::string(VideoGI->shortname);

  xs = (double)nw / VideoGI->nominal_width;
  ys = (double)nh / VideoGI->nominal_height;

  trio_snprintf(buf, 256, "%.30f", xs);
//  MDFNI_SetSetting(std::string(sn + "." + std::string("xscale")).c_str(), buf);

  trio_snprintf(buf, 256, "%.30f", ys);
//  MDFNI_SetSetting(std::string(sn + "." + std::string("yscale")).c_str(), buf);

  printf("%s, %d %d, %f %f\n", std::string(sn + "." + std::string("xscale")).c_str(), nw, nh, xs, ys);
  return(1);
 }

 return(0);
}
#endif

int GetSpecialScalerID(const std::string &special_string)
{
 int ret = -1;

 if(special_string == "" || !strcasecmp(special_string.c_str(), "none") || special_string == "0")
  ret = 0;
 else
 {
  ScalerDefinition *scaler = Scalers;

  while(scaler->name)
  {
   char tmpstr[16];

   sprintf(tmpstr, "%d", scaler->id);

   if(!strcasecmp(scaler->name, special_string.c_str()) || tmpstr == special_string)
   {
    ret = scaler->id;
    break;
   }
   scaler++;
  }
 }
 return(ret);
}

static bool weset_glstvb = false; 
static uint32 real_rs, real_gs, real_bs, real_as;

int InitVideo(MDFNGI *gi)
{
 const SDL_VideoInfo *vinf;
 int flags = 0; //SDL_RESIZABLE;
 int desbpp;

 VideoGI = gi;

 MDFNI_printf(_("Initializing video...\n"));
 MDFN_indent(1);


 #ifdef WIN32
 if(MDFN_GetSettingB("video.disable_composition"))
 {
  static bool dwm_already_try_disable = false;

  if(!dwm_already_try_disable)
  {
   HMODULE dwmdll;

   dwm_already_try_disable = true;

   if((dwmdll = LoadLibrary("Dwmapi.dll")) != NULL)
   {
    HRESULT WINAPI (*p_DwmEnableComposition)(UINT) = (HRESULT WINAPI (*)(UINT))GetProcAddress(dwmdll, "DwmEnableComposition");

    if(p_DwmEnableComposition != NULL)
    {
     p_DwmEnableComposition(0);
    }
   }
  }
 }
 #endif

 if(!IconSurface)
 {
  #ifdef WIN32
   #ifdef LSB_FIRST
   IconSurface=SDL_CreateRGBSurfaceFrom((void *)mednafen_playicon.pixel_data,32,32,32,32*4,0xFF,0xFF00,0xFF0000,0xFF000000);
   #else
   IconSurface=SDL_CreateRGBSurfaceFrom((void *)mednafen_playicon.pixel_data,32,32,32,32*4,0xFF000000,0xFF0000,0xFF00,0xFF);
   #endif
  #else
   #ifdef LSB_FIRST
   IconSurface=SDL_CreateRGBSurfaceFrom((void *)mednafen_playicon128.pixel_data,128,128,32,128*4,0xFF,0xFF00,0xFF0000,0xFF000000);
   #else
   IconSurface=SDL_CreateRGBSurfaceFrom((void *)mednafen_playicon128.pixel_data,128,128,32,128*4,0xFF000000,0xFF0000,0xFF00,0xFF);
   #endif
  #endif

  SDL_WM_SetIcon(IconSurface, 0);
 }

 if(!getenv("__GL_SYNC_TO_VBLANK") || weset_glstvb)
 {
  if(MDFN_GetSettingB("video.glvsync"))
  {
   #if HAVE_PUTENV
   static char gl_pe_string[] = "__GL_SYNC_TO_VBLANK=1";
   putenv(gl_pe_string); 
   #elif HAVE_SETENV
   setenv("__GL_SYNC_TO_VBLANK", "1", 1);
   #endif
  }
  else
  {
   #if HAVE_PUTENV
   static char gl_pe_string[] = "__GL_SYNC_TO_VBLANK=0";
   putenv(gl_pe_string); 
   #elif HAVE_SETENV
   setenv("__GL_SYNC_TO_VBLANK", "0", 1);
   #endif
  }
  weset_glstvb = true;
 }

 osd_alpha_blend = MDFN_GetSettingB("osd.alpha_blend");

 std::string sn = std::string(gi->shortname);

 if(gi->GameType == GMT_PLAYER)
  sn = "player";

 std::string special_string = MDFN_GetSettingS(std::string(sn + "." + std::string("special")).c_str());

 _fullscreen = MDFN_GetSettingB("video.fs");
 _video.xres = MDFN_GetSettingUI(std::string(sn + "." + std::string("xres")).c_str());
 _video.yres = MDFN_GetSettingUI(std::string(sn + "." + std::string("yres")).c_str());
 _video.xscale = MDFN_GetSettingF(std::string(sn + "." + std::string("xscale")).c_str());
 _video.yscale = MDFN_GetSettingF(std::string(sn + "." + std::string("yscale")).c_str());
 _video.xscalefs = MDFN_GetSettingF(std::string(sn + "." + std::string("xscalefs")).c_str());
 _video.yscalefs = MDFN_GetSettingF(std::string(sn + "." + std::string("yscalefs")).c_str());
 _video.videoip = MDFN_GetSettingI(std::string(sn + "." + std::string("videoip")).c_str());
 _video.stretch = MDFN_GetSettingUI(std::string(sn + "." + std::string("stretch")).c_str());
 _video.scanlines = MDFN_GetSettingI(std::string(sn + "." + std::string("scanlines")).c_str());

 _video.special = GetSpecialScalerID(special_string);

 _video.pixshader = (ShaderType)MDFN_GetSettingI(std::string(sn + "." + std::string("pixshader")).c_str());

 CurrentScaler = _video.special ? &Scalers[_video.special - 1] : NULL;

 vinf=SDL_GetVideoInfo();

 if(!best_xres)
 {
  best_xres = vinf->current_w;
  best_yres = vinf->current_h;

  if(!best_xres || !best_yres)
  {
   best_xres = 640;
   best_yres = 480;
  }
 }


 if(vinf->hw_available)
  flags |= SDL_HWSURFACE | SDL_DOUBLEBUF;

 if(_fullscreen)
  flags |= SDL_FULLSCREEN;

 vdriver = MDFN_GetSettingI("video.driver");

 if(vdriver == VDRIVER_OPENGL)
 {
  if(!sdlhaveogl)
  {
   // SDL_GL_LoadLibrary returns 0 on success, -1 on failure
   if(SDL_GL_LoadLibrary(NULL) == 0)
    sdlhaveogl = 1;
   else
    sdlhaveogl = 0;
  }

  if(!sdlhaveogl)
  {
   MDFN_PrintError(_("Could not load OpenGL library, disabling OpenGL usage!"));
   vdriver = VDRIVER_SOFTSDL;
  }
 }

 if(vdriver == VDRIVER_OPENGL)
 {
  flags |= SDL_OPENGL;

  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1 );

  #if SDL_VERSION_ATLEAST(1, 2, 10)
  SDL_GL_SetAttribute(SDL_GL_SWAP_CONTROL, MDFN_GetSettingB("video.glvsync"));
  #endif
 }
 else if(vdriver == VDRIVER_SOFTSDL)
 {

 }
 else if(vdriver == VDRIVER_OVERLAY)
 {

 }

 exs = _fullscreen ? _video.xscalefs : _video.xscale;
 eys = _fullscreen ? _video.yscalefs : _video.yscale;
 evideoip = _video.videoip;

 desbpp = 32;

 if(!_video.stretch || !_fullscreen)
 {
  if(exs > 50)
  {
   MDFND_PrintError(_("Eep!  Effective X scale setting is way too high.  Correcting."));
   exs = 50;
  }

  if(eys > 50)
  {
   MDFND_PrintError(_("Eep!  Effective Y scale setting is way too high.  Correcting."));
   eys = 50;
  }
 }

 if(_fullscreen)
 {
  if(!screen || cur_xres != _video.xres || cur_yres != _video.yres || cur_flags != flags || curbpp != desbpp)
  {
   if(!(screen = SDL_SetVideoMode(_video.xres ? _video.xres : best_xres, _video.yres ? _video.yres : best_yres, desbpp, flags)))
   {
    MDFND_PrintError(SDL_GetError()); 
    MDFN_indent(-1);
    return(0);
   }
  }
 }
 else
 {
  GenerateDestRect();
  if(!screen || cur_xres != screen_dest_rect.w || cur_yres != screen_dest_rect.h || cur_flags != flags || curbpp != desbpp)
  {
   if(!(screen = SDL_SetVideoMode(screen_dest_rect.w, screen_dest_rect.h, desbpp, flags)))
   {
    MDFND_PrintError(SDL_GetError());
    MDFN_indent(-1);
    return(0);
   }
  }
 }

 cur_xres = screen->w;
 cur_yres = screen->h;
 cur_flags = flags;
 curbpp = screen->format->BitsPerPixel;

 // Kludgey, we need to clean this up(vdriver vs cur_flags and whatnot).
 if(vdriver != VDRIVER_OVERLAY)
  vdriver = (cur_flags & SDL_OPENGL) ? VDRIVER_OPENGL : VDRIVER_SOFTSDL;

 GenerateDestRect();

 MDFN_printf(_("Video Driver: %s\n"), (cur_flags & SDL_OPENGL) ? _("OpenGL") : (vdriver == VDRIVER_OVERLAY ? _("Overlay") :_("Software SDL") ) );

 MDFN_printf(_("Video Mode: %d x %d x %d bpp\n"),screen->w,screen->h,screen->format->BitsPerPixel);
 if(curbpp!=16 && curbpp!=24 && curbpp!=32)
 {
  MDFN_printf(_("Sorry, %dbpp modes are not supported by Mednafen.  Supported bit depths are 16bpp, 24bpp, and 32bpp.\n"),curbpp);
  KillVideo();
  MDFN_indent(-1);
  return(0);
 }

 //MDFN_printf(_("OpenGL: %s\n"), (cur_flags & SDL_OPENGL) ? _("Yes") : _("No"));

 if(cur_flags & SDL_OPENGL)
 {
  MDFN_indent(1);
  MDFN_printf(_("Pixel shader: %s\n"), MDFN_GetSettingS(std::string(sn + "." + std::string("pixshader")).c_str()).c_str());
  MDFN_indent(-1);
 }

 MDFN_printf(_("Fullscreen: %s\n"), _fullscreen ? _("Yes") : _("No"));
 MDFN_printf(_("Special Scaler: %s\n"), _video.special ? Scalers[_video.special - 1].name : _("None"));

 if(!_video.scanlines)
  MDFN_printf(_("Scanlines: Off\n"));
 else
  MDFN_printf(_("Scanlines: %d%% opacity%s\n"), abs(_video.scanlines), (_video.scanlines < 0) ? _(" (with interlace field obscure)") : "");

 MDFN_printf(_("Destination Rectangle: X=%d, Y=%d, W=%d, H=%d\n"), screen_dest_rect.x, screen_dest_rect.y, screen_dest_rect.w, screen_dest_rect.h);
 if(screen_dest_rect.x < 0 || screen_dest_rect.y < 0 || (screen_dest_rect.x + screen_dest_rect.w) > screen->w || (screen_dest_rect.y + screen_dest_rect.h) > screen->h)
 {
  MDFN_indent(1);
  MDFN_printf(_("Warning:  Destination rectangle exceeds screen dimensions.  This is ok if you really do want the clipping...\n"));
  MDFN_indent(-1);
 }
 if(gi && gi->name)
  SDL_WM_SetCaption((char *)gi->name,(char *)gi->name);
 else
  SDL_WM_SetCaption("Mednafen","Mednafen");

 int rs, gs, bs, as;

 if(cur_flags & SDL_OPENGL)
 {
  try
  {
   ogl_blitter = new OpenGL_Blitter(_video.scanlines, _video.pixshader, screen->w, screen->h, &rs, &gs, &bs, &as);
  }
  catch(std::exception &e)
  {
   MDFND_PrintError(e.what());
   KillVideo();
   MDFN_indent(-1);
   return(0);
  }
 }
 else
 {
  rs = screen->format->Rshift;
  gs = screen->format->Gshift;
  bs = screen->format->Bshift;

  as = 0;
  while(as == rs || as == gs || as == bs) // Find unused 8-bits to use as our alpha channel
   as += 8;
 }

 //printf("%d %d %d %d\n", rs, gs, bs, as);

 MDFN_indent(-1);
 SDL_ShowCursor(0);

 real_rs = rs;
 real_gs = gs;
 real_bs = bs;
 real_as = as;

 /* HQXX only supports this pixel format, sadly, and other pixel formats
    can't be easily supported without rewriting the filters.
    We do conversion to the real screen format in the blitting function. 
 */
 if(CurrentScaler) {
#ifdef WANT_FANCY_SCALERS
  if(CurrentScaler->id == NTVB_HQ2X || CurrentScaler->id == NTVB_HQ3X || CurrentScaler->id == NTVB_HQ4X)
  {
   rs = 16;
   gs = 8;
   bs = 0;
   as = 24;
  }
  else if(CurrentScaler->id == NTVB_2XSAI || CurrentScaler->id == NTVB_SUPER2XSAI || CurrentScaler->id == NTVB_SUPEREAGLE)
  {
   Init_2xSaI(screen->format->BitsPerPixel, 555); // systemColorDepth, BitFormat
  }
#endif
 }

 NetSurface = new MDFN_Surface(NULL, screen->w, 18 * 5, screen->w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));

 NetRect.w = screen->w;
 NetRect.h = 18 * 5;
 NetRect.x = 0;
 NetRect.y = 0;


 {
  int xmu = 1;
  int ymu = 1;

  if(screen->w >= 768)
   xmu = screen->w / 384;
  if(screen->h >= 576)
   ymu = screen->h / 288;

  SMRect.h = 18 + 2;
  SMRect.x = 0;
  SMRect.y = 0;
  SMRect.w = screen->w;

  SMDRect.w = SMRect.w * xmu;
  SMDRect.h = SMRect.h * ymu;
  SMDRect.x = (screen->w - SMDRect.w) / 2;
  SMDRect.y = screen->h - SMDRect.h;

  if(SMDRect.x < 0)
  {
   SMRect.w += SMDRect.x * 2 / xmu;
   SMDRect.w = SMRect.w * xmu;
   SMDRect.x = 0;
  }
  SMSurface = new MDFN_Surface(NULL, SMRect.w, SMRect.h, SMRect.w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));
 }

 //MDFNI_SetPixelFormat(rs, gs, bs, as);
 memset(&pf_normal, 0, sizeof(pf_normal));
 memset(&pf_overlay, 0, sizeof(pf_overlay));

 pf_normal.bpp = 32;
 pf_normal.colorspace = MDFN_COLORSPACE_RGB;
 pf_normal.Rshift = rs;
 pf_normal.Gshift = gs;
 pf_normal.Bshift = bs;
 pf_normal.Ashift = as;

 if(vdriver == VDRIVER_OVERLAY)
 {
  pf_overlay.bpp = 32;
  pf_overlay.colorspace = MDFN_COLORSPACE_YCbCr;
  pf_overlay.Yshift = 0;
  pf_overlay.Ushift = 8;
  pf_overlay.Vshift = 16;
  pf_overlay.Ashift = 24;
 }

 //SetPixelFormatHax((vdriver == VDRIVER_OVERLAY) ? pf_overlay : pf_normal); //rs, gs, bs, as);

 for(int i = 0; i < 2; i++)
 {
  ClearBackBuffer();

  if(cur_flags & SDL_OPENGL)
  {
   SDL_GL_SwapBuffers();
   //ogl_blitter->HardSync();
  }
  else
   SDL_Flip(screen);
 }

 MarkNeedBBClear();

 return 1;
}

static uint32 howlong = 0;
static UTF8 *CurrentMessage = NULL;

void VideoShowMessage(UTF8 *text)
{
 if(text)
  howlong = MDFND_GetTime() + 2500;
 else
  howlong = 0;

 if(CurrentMessage)
 {
  free(CurrentMessage);
  CurrentMessage = NULL;
 }

 CurrentMessage = text;
}

void BlitRaw(MDFN_Surface *src, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, int source_alpha)
{
 if(ogl_blitter)
  ogl_blitter->BlitRaw(src, src_rect, dest_rect, (source_alpha != 0) && osd_alpha_blend);
 else
 {
  SDL_to_MDFN_Surface_Wrapper m_surface(screen);

  //MDFN_SrcAlphaBlitSurface(src, src_rect, &m_surface, dest_rect);
  MDFN_StretchBlitSurface(src, src_rect, &m_surface, dest_rect, (source_alpha > 0) && osd_alpha_blend);
 }

 bool cond1 = (dest_rect->x < screen_dest_rect.x || (dest_rect->x + dest_rect->w) > (screen_dest_rect.x + screen_dest_rect.w));
 bool cond2 = (dest_rect->y < screen_dest_rect.y || (dest_rect->y + dest_rect->h) > (screen_dest_rect.y + screen_dest_rect.h));

 if(cond1 || cond2)
  MarkNeedBBClear();
}

void VideoAppActive(bool gain)
{
 //printf("AppActive: %u\n", gain);
}

static bool IsInternalMessageActive(void)
{
 return(howlong >= MDFND_GetTime());
}

static bool BlitInternalMessage(void)
{
 if(howlong < MDFND_GetTime())
 {
  if(CurrentMessage)
  {
   free(CurrentMessage);
   CurrentMessage = NULL;
  }
  return(0);
 }

 if(CurrentMessage)
 {
  SMSurface->Fill(0x00, 0x00, 0x00, 0xC0);

  DrawTextTransShadow(SMSurface->pixels + (1 * SMSurface->pitch32), SMSurface->pitch32 << 2, SMRect.w, CurrentMessage,
	SMSurface->MakeColor(0xFF, 0xFF, 0xFF, 0xFF), SMSurface->MakeColor(0x00, 0x00, 0x00, 0xFF), TRUE);
  free(CurrentMessage);
  CurrentMessage = NULL;
 }

 BlitRaw(SMSurface, &SMRect, &SMDRect);
 return(1);
}

static bool OverlayOK;	// Set to TRUE when vdriver == "overlay", and it's safe to use an overlay format
			// "Safe" is equal to OSD being off, and not using a special scaler that
			// requires an RGB pixel format(HQnx)
			// Otherwise, set to FALSE.
			// (Set in the BlitScreen function before any calls to SubBlit())

static void SubBlit(MDFN_Surface *source_surface, const MDFN_Rect &src_rect, const MDFN_Rect &dest_rect, const int InterlaceField)
{
 MDFN_Surface *eff_source_surface = source_surface;
 MDFN_Rect eff_src_rect = src_rect;
 MDFN_Surface *tmp_blur_surface = NULL;
 int overlay_softscale = 0;

 if(!(src_rect.w > 0 && src_rect.w <= 32767) || !(src_rect.h > 0 && src_rect.h <= 32767))
 {
  //fprintf(stderr, "BUG: Source rect out of range; w=%d, h=%d\n", src_rect.w, src_rect.h);
  return;
 }
//#if 0
// assert(src_rect.w > 0 && src_rect.w <= 32767);
// assert(src_rect.h > 0 && src_rect.h <= 32767);
//#endif

 assert(dest_rect.w > 0);
 assert(dest_rect.h > 0);

 // Handle selective blur first
 if(0)
 {
  SelBlurImage sb_spec;

  tmp_blur_surface = new MDFN_Surface(NULL, src_rect.w, src_rect.h, src_rect.w, source_surface->format);

  sb_spec.red_threshold = 8;
  sb_spec.green_threshold = 8;
  sb_spec.blue_threshold = 8;
  sb_spec.radius = 1;

#if 0
  sb_spec.red_threshold = 8;
  sb_spec.green_threshold = 7;
  sb_spec.blue_threshold = 10;
  sb_spec.radius = 3;
#endif
  sb_spec.source = source_surface->pixels + eff_src_rect.x + eff_src_rect.y * source_surface->pitchinpix;
  sb_spec.source_pitch32 = source_surface->pitchinpix;
  sb_spec.dest = tmp_blur_surface->pixels;
  sb_spec.dest_pitch32 = tmp_blur_surface->pitchinpix;
  sb_spec.width = eff_src_rect.w;
  sb_spec.height = eff_src_rect.h;
  sb_spec.red_shift = source_surface->format.Rshift;
  sb_spec.green_shift = source_surface->format.Gshift;
  sb_spec.blue_shift = source_surface->format.Bshift;

  MDFN_SelBlur(&sb_spec);

  eff_source_surface = tmp_blur_surface;
  eff_src_rect.x = 0;
  eff_src_rect.y = 0;
 }

 if(OverlayOK && CurrentScaler && !CurGame->rotated)
 {
  if(CurrentScaler->id == NTVB_NN2X || CurrentScaler->id == NTVB_NN3X || CurrentScaler->id == NTVB_NN4X)
   overlay_softscale = CurrentScaler->id - NTVB_NN2X + 2;
 }

   if(CurrentScaler && !overlay_softscale)
   {
    uint8 *screen_pixies;
    uint32 screen_pitch;
    MDFN_Surface *bah_surface = NULL;
    MDFN_Rect boohoo_rect = eff_src_rect;

    boohoo_rect.x = boohoo_rect.y = 0;
    boohoo_rect.w *= CurrentScaler->xscale;
    boohoo_rect.h *= CurrentScaler->yscale;

    bah_surface = new MDFN_Surface(NULL, boohoo_rect.w, boohoo_rect.h, boohoo_rect.w, eff_source_surface->format, false);

    screen_pixies = (uint8 *)bah_surface->pixels;
    screen_pitch = bah_surface->pitch32 << 2;

    if(CurrentScaler->id == NTVB_SCALE4X || CurrentScaler->id == NTVB_SCALE3X || CurrentScaler->id == NTVB_SCALE2X)
    {
#ifdef WANT_FANCY_SCALERS
     //
     // scale2x and scale3x apparently can't handle source heights less than 2.
     // scale4x, it's less than 4
     //
     // None can handle source widths less than 2.
     //
     if(eff_src_rect.w < 2 || eff_src_rect.h < 2 || (CurrentScaler->id == NTVB_SCALE4X && eff_src_rect.h < 4))
     {
      nnx(CurrentScaler->id - NTVB_SCALE2X + 2, eff_source_surface, &eff_src_rect, bah_surface, &boohoo_rect);
     }
     else
     {
      uint8 *source_pixies = (uint8 *)eff_source_surface->pixels + eff_src_rect.x * sizeof(uint32) + eff_src_rect.y * eff_source_surface->pitchinpix * sizeof(uint32);
      scale((CurrentScaler->id ==  NTVB_SCALE2X)?2:(CurrentScaler->id == NTVB_SCALE4X)?4:3, screen_pixies, screen_pitch, source_pixies, eff_source_surface->pitchinpix * sizeof(uint32), sizeof(uint32), eff_src_rect.w, eff_src_rect.h);
     }
#endif
    }
    else if(CurrentScaler->id == NTVB_NN2X || CurrentScaler->id == NTVB_NN3X || CurrentScaler->id == NTVB_NN4X)
    {
     nnx(CurrentScaler->id - NTVB_NN2X + 2, eff_source_surface, &eff_src_rect, bah_surface, &boohoo_rect);
    }
    else if(CurrentScaler->id == NTVB_NNY2X || CurrentScaler->id == NTVB_NNY3X || CurrentScaler->id == NTVB_NNY4X)
    {
     nnyx(CurrentScaler->id - NTVB_NNY2X + 2, eff_source_surface, &eff_src_rect, bah_surface, &boohoo_rect);
    }
#if 0
    else if(CurrentScaler->id == NTVB_SCANLINES)
    {
     for(int y = 0; y < eff_src_rect.h; y++)
     {
      memcpy(&bah_surface->pixels[(boohoo_rect.y + y * 2) * bah_surface->pitchinpix + boohoo_rect.x],
	     &eff_source_surface->pixels[(eff_src_rect.y + y) * eff_source_surface->pitchinpix + eff_src_rect.x],
	     sizeof(uint32) * eff_src_rect.w);
      uint32 *line_a = &eff_source_surface->pixels[(eff_src_rect.y + y) * eff_source_surface->pitchinpix + eff_src_rect.x];
      uint32 *line_b = (y == (eff_src_rect.h - 1)) ? line_a : (line_a + eff_source_surface->pitchinpix);
      uint32 *tline = &bah_surface->pixels[(boohoo_rect.y + y * 2 + 1) * bah_surface->pitchinpix + boohoo_rect.x];

      for(int x = 0; x < eff_src_rect.w; x++)
      {
       uint32 a = line_a[x];
       uint32 b = line_b[x];

       tline[x] = (((((uint64)a + b) - ((a ^ b) & 0x01010101))) >> 3) & 0x3F3F3F3F;
      }
     }
    }
#endif
#ifdef WANT_FANCY_SCALERS
    else
    {
     uint8 *source_pixies = (uint8 *)(eff_source_surface->pixels + eff_src_rect.x + eff_src_rect.y * eff_source_surface->pitchinpix);

     if(CurrentScaler->id == NTVB_HQ2X)
      hq2x_32(source_pixies, screen_pixies, eff_src_rect.w, eff_src_rect.h, eff_source_surface->pitchinpix * sizeof(uint32), screen_pitch);
     else if(CurrentScaler->id == NTVB_HQ3X)
      hq3x_32(source_pixies, screen_pixies, eff_src_rect.w, eff_src_rect.h, eff_source_surface->pitchinpix * sizeof(uint32), screen_pitch);
     else if(CurrentScaler->id == NTVB_HQ4X)
      hq4x_32(source_pixies, screen_pixies, eff_src_rect.w, eff_src_rect.h, eff_source_surface->pitchinpix * sizeof(uint32), screen_pitch);
     else if(CurrentScaler->id == NTVB_2XSAI || CurrentScaler->id == NTVB_SUPER2XSAI || CurrentScaler->id == NTVB_SUPEREAGLE)
     {
      MDFN_Surface *saisrc = NULL;

      saisrc = new MDFN_Surface(NULL, eff_src_rect.w + 4, eff_src_rect.h + 4, eff_src_rect.w + 4, eff_source_surface->format);

      for(int y = 0; y < 2; y++)
      {
       memcpy(saisrc->pixels + (y * saisrc->pitchinpix) + 2, (uint32 *)source_pixies, eff_src_rect.w * sizeof(uint32));
       memcpy(saisrc->pixels + ((2 + y + eff_src_rect.h) * saisrc->pitchinpix) + 2, (uint32 *)source_pixies + (eff_src_rect.h - 1) * eff_source_surface->pitchinpix, eff_src_rect.w * sizeof(uint32));
      }

      for(int y = 0; y < eff_src_rect.h; y++)
      {
       memcpy(saisrc->pixels + ((2 + y) * saisrc->pitchinpix) + 2, (uint32*)source_pixies + y * eff_source_surface->pitchinpix, eff_src_rect.w * sizeof(uint32));
       memcpy(saisrc->pixels + ((2 + y) * saisrc->pitchinpix) + (2 + eff_src_rect.w),
	      saisrc->pixels + ((2 + y) * saisrc->pitchinpix) + (2 + eff_src_rect.w - 1), sizeof(uint32));
      }

      {
       uint8 *saipix = (uint8 *)(saisrc->pixels + 2 * saisrc->pitchinpix + 2);
       uint32 saipitch = saisrc->pitchinpix << 2;

       if(CurrentScaler->id == NTVB_2XSAI)
        _2xSaI32(saipix, saipitch, screen_pixies, screen_pitch, eff_src_rect.w, eff_src_rect.h);
       else if(CurrentScaler->id == NTVB_SUPER2XSAI)
        Super2xSaI32(saipix, saipitch, screen_pixies, screen_pitch, eff_src_rect.w, eff_src_rect.h);
       else if(CurrentScaler->id == NTVB_SUPEREAGLE)
        SuperEagle32(saipix, saipitch, screen_pixies, screen_pitch, eff_src_rect.w, eff_src_rect.h);
      }

      delete saisrc;
     }

     if(bah_surface->format.Rshift != real_rs || bah_surface->format.Gshift != real_gs || bah_surface->format.Bshift != real_bs)
     {
      uint32 *lineptr = bah_surface->pixels;

      unsigned int srs = bah_surface->format.Rshift;
      unsigned int sgs = bah_surface->format.Gshift;
      unsigned int sbs = bah_surface->format.Bshift;
      unsigned int drs = real_rs;
      unsigned int dgs = real_gs;
      unsigned int dbs = real_bs;

      for(int y = 0; y < boohoo_rect.h; y++)
      {
       for(int x = 0; x < boohoo_rect.w; x++)
       {
        uint32 pixel = lineptr[x];
        lineptr[x] = (((pixel >> srs) & 0xFF) << drs) | (((pixel >> sgs) & 0xFF) << dgs) | (((pixel >> sbs) & 0xFF) << dbs);
       }
       lineptr += bah_surface->pitchinpix;
      }
     }
    }
#endif

    if(ogl_blitter)
     ogl_blitter->Blit(bah_surface, &boohoo_rect, &dest_rect, &eff_src_rect, InterlaceField, evideoip, CurGame->rotated);
    else
    {
     if(OverlayOK)
     {
      SDL_Rect tr;

      tr.x = dest_rect.x;
      tr.y = dest_rect.y;
      tr.w = dest_rect.w;
      tr.h = dest_rect.h;

      OV_Blit(bah_surface, &boohoo_rect, &eff_src_rect, &tr, screen, 0, _video.scanlines, CurGame->rotated);
     }
     else
     {
      SDL_to_MDFN_Surface_Wrapper m_surface(screen);

      MDFN_StretchBlitSurface(bah_surface, &boohoo_rect, &m_surface, &dest_rect, false, _video.scanlines, &eff_src_rect, CurGame->rotated, InterlaceField);
     }
    }
    delete bah_surface;
   }
   else // No special scaler:
   {
    if(ogl_blitter)
     ogl_blitter->Blit(eff_source_surface, &eff_src_rect, &dest_rect, &eff_src_rect, InterlaceField, evideoip, CurGame->rotated);
    else
    {
     if(OverlayOK)
     {
      SDL_Rect tr;

      tr.x = dest_rect.x;
      tr.y = dest_rect.y;
      tr.w = dest_rect.w;
      tr.h = dest_rect.h;

      OV_Blit(eff_source_surface, &eff_src_rect, &eff_src_rect, &tr, screen, overlay_softscale, _video.scanlines, CurGame->rotated);
     }
     else
     {
      SDL_to_MDFN_Surface_Wrapper m_surface(screen);

      MDFN_StretchBlitSurface(eff_source_surface, &eff_src_rect, &m_surface, &dest_rect, false, _video.scanlines, &eff_src_rect, CurGame->rotated, InterlaceField);
     }
    }
   }

 if(tmp_blur_surface)
 {
  delete tmp_blur_surface;
  tmp_blur_surface = NULL;
 }
}

void BlitScreen(MDFN_Surface *msurface, const MDFN_Rect *DisplayRect, const int32 *LineWidths, const int InterlaceField, const bool take_ssnapshot)
{
 MDFN_Rect src_rect;
 const MDFN_PixelFormat *pf_needed = &pf_normal;

 if(!screen) return;

 if(NeedClear)
 {
  uint32 ct = MDFND_GetTime();

  if((ct - LastBBClearTime) >= 30)
  {
   LastBBClearTime = ct;
   NeedClear--;
  }

  ClearBackBuffer();
 }

 OverlayOK = false;
 if(vdriver == VDRIVER_OVERLAY)
 {
  bool osd_active = Help_IsActive() || SaveStatesActive() || CheatIF_Active() || Netplay_GetTextView() ||
		   IsInternalMessageActive() || Debugger_IsActive();

  OverlayOK = (vdriver == VDRIVER_OVERLAY) && !take_ssnapshot && !osd_active && (!CurrentScaler || (CurrentScaler->id != NTVB_HQ2X && CurrentScaler->id != NTVB_HQ3X &&
		CurrentScaler->id != NTVB_HQ4X));

  if(OverlayOK && LineWidths[0] != ~0)
  {
   const int32 first_width = LineWidths[DisplayRect->y];

   for(int suby = DisplayRect->y; suby < DisplayRect->y + DisplayRect->h; suby++)
   {
    if(LineWidths[suby] != first_width)
    {
     //puts("Skippidy");
     OverlayOK = FALSE;
     break;
    }
   }
  }

  if(OverlayOK)
   pf_needed = &pf_overlay;
 } // end if(vdriver == VDRIVER_OVERLAY)

 msurface->SetFormat(*pf_needed, TRUE);

 src_rect.x = DisplayRect->x;
 src_rect.w = DisplayRect->w;
 src_rect.y = DisplayRect->y;
 src_rect.h = DisplayRect->h;

 // This drawing to the game's video surface can cause visual glitches, but better than killing performance which kind of
 // defeats the purpose of the FPS display.
 if(OverlayOK)
 {
  int fps_w, fps_h;

  if(FPS_IsActive(&fps_w, &fps_h))
  {
   int fps_xpos = DisplayRect->x;
   int fps_ypos = DisplayRect->y;
   int x_bound = DisplayRect->x + DisplayRect->w;
   int y_bound = DisplayRect->y + DisplayRect->h;

   if(LineWidths[0] != ~0)
   {
    x_bound = DisplayRect->x + LineWidths[DisplayRect->y];
   }

   if((fps_xpos + fps_w) > x_bound || (fps_ypos + fps_h) > y_bound)
   {
    puts("FPS draw error");
   }
   else
   {
    FPS_Draw(msurface, fps_xpos, DisplayRect->y);
   }

  }
 }

 if(LineWidths[0] == ~0) // Skip multi line widths code?
 {
  SubBlit(msurface, src_rect, screen_dest_rect, InterlaceField);
 }
 else
 {
  int y;
  int last_y = src_rect.y;
  int last_width = LineWidths[src_rect.y];

  MDFN_Rect sub_src_rect;
  MDFN_Rect sub_dest_rect;

  for(y = src_rect.y; y < (src_rect.y + src_rect.h + 1); y++)
  {
   if(y == (src_rect.y + src_rect.h) || LineWidths[y] != last_width)
   {
    sub_src_rect.x = src_rect.x;
    sub_src_rect.w = last_width;
    sub_src_rect.y = last_y;
    sub_src_rect.h = y - last_y;

    if(CurGame->rotated == MDFN_ROTATE90)
    {
     sub_dest_rect.x = screen_dest_rect.x + (last_y - src_rect.y) * screen_dest_rect.w / src_rect.h;
     sub_dest_rect.y = screen_dest_rect.y;

     sub_dest_rect.w = sub_src_rect.h * screen_dest_rect.w / src_rect.h;
     sub_dest_rect.h = screen_dest_rect.h;
     //printf("sdr.x=%f, sdr.w=%f\n", (double)screen_dest_rect.x + (double)(last_y - src_rect.y) * screen_dest_rect.w / src_rect.h, (double)sub_src_rect.h * screen_dest_rect.w / src_rect.h);
    }
    else if(CurGame->rotated == MDFN_ROTATE270)
    {
     sub_dest_rect.x = screen_dest_rect.x + (src_rect.h - (y - src_rect.y)) * screen_dest_rect.w / src_rect.h;
     sub_dest_rect.y = screen_dest_rect.y;

     sub_dest_rect.w = sub_src_rect.h * screen_dest_rect.w / src_rect.h;
     sub_dest_rect.h = screen_dest_rect.h;
    }
    else
    {
     sub_dest_rect.x = screen_dest_rect.x;
     sub_dest_rect.w = screen_dest_rect.w;
     sub_dest_rect.y = screen_dest_rect.y + (last_y - src_rect.y) * screen_dest_rect.h / src_rect.h;
     sub_dest_rect.h = sub_src_rect.h * screen_dest_rect.h / src_rect.h;
    }

    if(!sub_dest_rect.h) // May occur with small yscale values in certain cases, so prevent triggering an assert()
     sub_dest_rect.h = 1;

    // Blit here!
    SubBlit(msurface, sub_src_rect, sub_dest_rect, InterlaceField);

    last_y = y;

    if(y != (src_rect.y + src_rect.h))
    {
     last_width = LineWidths[y];
    }

   }
  }
 }

 if(take_ssnapshot)
 {
  try
  {
   MDFN_Surface *ib = NULL;
   MDFN_Rect sr;
   MDFN_Rect tr;

   sr = screen_dest_rect;
   if(sr.x < 0) { sr.w += sr.x; sr.x = 0; }
   if(sr.y < 0) { sr.h += sr.y; sr.y = 0; }
   if(sr.w < 0) sr.w = 0;
   if(sr.h < 0) sr.h = 0;
   if(sr.w > screen->w) sr.w = screen->w;
   if(sr.h > screen->h) sr.h = screen->h;

   ib = new MDFN_Surface(NULL, sr.w, sr.h, sr.w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));

   if(ogl_blitter)
    ogl_blitter->ReadPixels(ib, &sr);
   else
   {
    if(SDL_MUSTLOCK(screen))
     SDL_LockSurface(screen);

    for(int y = 0; y < sr.h; y++)
    {
     for(int x = 0; x < sr.w; x++)
     {
      ib->pixels[y * ib->pitchinpix + x] = ((uint32*)((uint8*)screen->pixels + (sr.y + y) * screen->pitch))[sr.x + x];
     }
    }

    if(SDL_MUSTLOCK(screen))
     SDL_UnlockSurface(screen);
   }


   tr.x = tr.y = 0;
   tr.w = ib->w;
   tr.h = ib->h;
   MDFNI_SaveSnapshot(ib, &tr, NULL);
  }
  catch(std::exception &e)
  {
   MDFN_DispMessage("%s", e.what());
  }
 }


 Debugger_MT_DrawToScreen(MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as), screen->w, screen->h);

#if 0
 if(CKGUI_IsActive())
 {
  if(!CKGUISurface)
  {
   CKGUIRect.w = screen->w;
   CKGUIRect.h = screen->h;

   CKGUISurface = SDL_CreateRGBSurface(SDL_SWSURFACE | SDL_SRCALPHA, CKGUIRect.w, CKGUIRect.h, 32, 0xFF << real_rs, 0xFF << real_gs, 0xFF << real_bs, 0xFF << real_as);
   SDL_SetColorKey(CKGUISurface, SDL_SRCCOLORKEY, 0);
   SDL_SetAlpha(CKGUISurface, SDL_SRCALPHA, 0);
  }
  MDFN_Rect zederect = CKGUIRect;
  CKGUI_Draw(CKGUISurface, &CKGUIRect);
  BlitRaw(CKGUISurface, &CKGUIRect, &zederect);
 }
 else if(CKGUISurface)
 {
  SDL_FreeSurface(CKGUISurface);
  CKGUISurface = NULL;
 }
#endif

 if(Help_IsActive())
 {
  if(!HelpSurface)
  {
   HelpRect.w = std::min<int>(512, screen->w);
   HelpRect.h = std::min<int>(384, screen->h);

   HelpSurface = new MDFN_Surface(NULL, 512, 384, 512, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));
/*
   HelpSurface = SDL_CreateRGBSurface(SDL_SWSURFACE | SDL_SRCALPHA, 512, 384, 32, 0xFF << real_rs, 0xFF << real_gs, 0xFF << real_bs, 0xFF << real_as);
   SDL_SetColorKey(HelpSurface, SDL_SRCCOLORKEY, 0);
   SDL_SetAlpha(HelpSurface, SDL_SRCALPHA, 0);
*/
   Help_Draw(HelpSurface, &HelpRect);
  }

  MDFN_Rect zederect;

  zederect.w = HelpRect.w * (screen->w / HelpRect.w);
  zederect.h = HelpRect.h * (screen->h / HelpRect.h);

  zederect.x = (screen->w - zederect.w) / 2;
  zederect.y = (screen->h - zederect.h) / 2;

  BlitRaw(HelpSurface, &HelpRect, &zederect, 0);
 }
 else if(HelpSurface)
 {
  delete HelpSurface;
  HelpSurface = NULL;
 }

 DrawSaveStates(screen, exs, eys, real_rs, real_gs, real_bs, real_as);

 if(CheatIF_Active())
 {
  MDFN_Rect CheatRect;
  unsigned crs = 0;

  memset(&CheatRect, 0, sizeof(CheatRect));

  CheatRect.x = 0;
  CheatRect.y = 0;
  CheatRect.w = screen->w;
  CheatRect.h = screen->h;

  while((CheatRect.h >> crs) >= 1024 && (CheatRect.w >> crs) >= 1024)
   crs++;

  CheatRect.w >>= crs;
  CheatRect.h >>= crs;

  if(!CheatSurface || CheatSurface->w < CheatRect.w || CheatSurface->h < CheatRect.h)
  {
   if(CheatSurface)
   {
    delete CheatSurface;
    CheatSurface = NULL;
   }

   CheatSurface = new MDFN_Surface(NULL, CheatRect.w, CheatRect.h, CheatRect.w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));
  }

  MDFN_Rect zederect;

  zederect.x = 0;
  zederect.y = 0;
  zederect.w = CheatRect.w << crs;
  zederect.h = CheatRect.h << crs;

  CheatIF_MT_Draw(CheatSurface, &CheatRect);
  BlitRaw(CheatSurface, &CheatRect, &zederect);
 }
 else if(CheatSurface)
 {
  delete CheatSurface;
  CheatSurface = NULL;
 }

 if(Netplay_GetTextView())
 {
  DrawNetplayTextBuffer(NetSurface, &NetRect);

  {
   MDFN_Rect zederect;

   zederect.x = 0;
   zederect.y = screen->h - NetRect.h;
   zederect.w = NetRect.w;
   zederect.h = NetRect.h;

   BlitRaw(NetSurface, &NetRect, &zederect);
  }
 }

 BlitInternalMessage();

 if(!OverlayOK)
 {
  unsigned fps_offsx = 0, fps_offsy = 0;

  // When using soft-SDL, position the FPS display so we won't incur a potentially large(on older/slower hardware) penalty due
  // to a requisite backbuffer clear(we could avoid this with some sort of dirty-rects system so only parts of the backbuffer are cleared,
  // but that gets awfully complicated and prone to bugs when dealing with double/triple-buffered video...).
  //
  // std::max so we don't position it offscreen if the user has selected xscalefs or yscalefs values that are too large.
  if(!(cur_flags & SDL_OPENGL))
  {
   fps_offsx = std::max<int32>(screen_dest_rect.x, 0);
   fps_offsy = std::max<int32>(screen_dest_rect.y, 0);
  }
  FPS_DrawToScreen(screen, real_rs, real_gs, real_bs, real_as, fps_offsx, fps_offsy);
 }

 if(!(cur_flags & SDL_OPENGL))
 {
  if(!OverlayOK)
   SDL_Flip(screen);
 }
 else
 {
  PumpWrap();
  SDL_GL_SwapBuffers();
  //ogl_blitter->HardSync();
 }
}

void PtoV(const int in_x, const int in_y, int32 *out_x, int32 *out_y)
{
 assert(VideoGI);
 if(VideoGI->rotated)
 {
  double tmp_x, tmp_y;

  // Swap X and Y
  tmp_x = ((double)(in_y - screen_dest_rect.y) / eys);
  tmp_y = ((double)(in_x - screen_dest_rect.x) / exs);

  // Correct position(and movement)
  if(VideoGI->rotated == MDFN_ROTATE90)
   tmp_x = VideoGI->nominal_width - 1 - tmp_x;
  else if(VideoGI->rotated == MDFN_ROTATE270)
   tmp_y = VideoGI->nominal_height - 1 - tmp_y;

  *out_x = (int32)round(65536 * tmp_x);
  *out_y = (int32)round(65536 * tmp_y);
 }
 else
 {
  *out_x = (int32)round(65536 * (double)(in_x - screen_dest_rect.x) / exs);
  *out_y = (int32)round(65536 * (double)(in_y - screen_dest_rect.y) / eys);
 }
}

int32 PtoV_J(const int32 inv, const bool axis, const bool scr_scale)
{
 assert(VideoGI);
 if(!scr_scale)
 {
  return((inv - 32768) * std::max(VideoGI->nominal_width, VideoGI->nominal_height) + (32768 * (axis ? VideoGI->nominal_height : VideoGI->nominal_width)));
 }
 else
 {
  int32 prescale = (axis ? screen->h : screen->w);
  int32 offs = -(axis ? screen_dest_rect.y : screen_dest_rect.x);
  double postscale = 65536.0 / (axis ? eys : exs);

  //printf("%.64f\n", floor(0.5 + ((((((int64)inv * prescale) + 0x8000) >> 16) + offs) * postscale)) / 65536.0);

  return (int32)floor(0.5 + ((((((int64)inv * prescale) + 0x8000) >> 16) + offs) * postscale));
 }
}
