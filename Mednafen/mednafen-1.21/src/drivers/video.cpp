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

#include <trio/trio.h>

#include "video.h"
#include "opengl.h"
#include "shader.h"
#include "nongl.h"

#include "icon.h"
#include "netplay.h"
#include "cheat.h"

#include "nnx.h"
#include "debugger.h"
#include "fps.h"
#include "help.h"
#include "video-state.h"

#ifdef WANT_FANCY_SCALERS
#include "scalebit.h"
#include "hqxx-common.h"
#include "2xSaI.h"
#endif

class SDL_to_MDFN_Surface_Wrapper : public MDFN_Surface
{
 public:
 INLINE SDL_to_MDFN_Surface_Wrapper(SDL_Surface *sdl_surface) : ss(sdl_surface)
 {
  // Locking should be first thing.
  if(SDL_MUSTLOCK(ss))
   SDL_LockSurface(ss);

  format.bpp = ss->format->BitsPerPixel;
  format.colorspace = MDFN_COLORSPACE_RGB;
  format.Rshift = ss->format->Rshift;
  format.Gshift = ss->format->Gshift;
  format.Bshift = ss->format->Bshift;
  format.Ashift = ss->format->Ashift;

  format.Rprec = 8 - ss->format->Rloss;
  format.Gprec = 8 - ss->format->Gloss;
  format.Bprec = 8 - ss->format->Bloss;
  format.Aprec = 8 - ss->format->Aloss;

  pixels_is_external = true;

  pixels16 = NULL;
  pixels = NULL;

  if(ss->format->BitsPerPixel == 16)
  {
   pixels16 = (uint16*)ss->pixels;
   pitchinpix = ss->pitch >> 1;
  }
  else
  {
   pixels = (uint32*)ss->pixels;
   pitchinpix = ss->pitch >> 2;
  }

  format = MDFN_PixelFormat(MDFN_COLORSPACE_RGB, sdl_surface->format->Rshift, sdl_surface->format->Gshift, sdl_surface->format->Bshift, sdl_surface->format->Ashift);

  w = ss->w;
  h = ss->h;
 }

 INLINE ~SDL_to_MDFN_Surface_Wrapper()
 {
  if(SDL_MUSTLOCK(ss))
   SDL_UnlockSurface(ss);
  ss = NULL;
 }
 private:
 SDL_Surface *ss;
};

enum
{
 VDRIVER_OPENGL = 0,
 VDRIVER_SOFTSDL = 1,
 VDRIVER__COUNT
};

enum
{
 NTVB_NONE = 0,

 NTVB_HQ2X,
 NTVB_HQ3X,
 NTVB_HQ4X,

 NTVB_SCALE2X,
 NTVB_SCALE3X,
 NTVB_SCALE4X,

 NTVB_NN2X,
 NTVB_NN3X,
 NTVB_NN4X,

 NTVB_NNY2X,
 NTVB_NNY3X,
 NTVB_NNY4X,

 NTVB_2XSAI,
 NTVB_SUPER2XSAI,
 NTVB_SUPEREAGLE,
};

static const MDFNSetting_EnumList VDriver_List[] =
{
 { "default", VDRIVER__COUNT, gettext_noop("Default"), gettext_noop("Selects the default video driver.  Currently, this is OpenGL for all platforms, but may change in the future if better platform-specific drivers are added.") },

 { "opengl", VDRIVER_OPENGL, "OpenGL", gettext_noop("All video-related Mednafen features are available with this video driver.") },
 { "softfb", VDRIVER_SOFTSDL, "Software Blitting to Framebuffer", gettext_noop("Slower with lower-quality scaling than OpenGL, but if you don't have hardware-accelerated OpenGL rendering, it will probably be faster than software OpenGL rendering. Bilinear interpolation not available. OpenGL shaders do not work with this output method, of course.") },

 // Backwards-compat:
 { "0", VDRIVER_OPENGL },
 { "1", VDRIVER_SOFTSDL },
 { "sdl", VDRIVER_SOFTSDL },
 { "overlay", VDRIVER__COUNT },

 { NULL, 0 },
};

static const MDFNSetting GlobalVideoSettings[] =
{
 { "video.driver", MDFNSF_NOFLAGS, gettext_noop("Video output driver."), NULL, MDFNST_ENUM, "default", NULL, NULL, NULL, NULL, VDriver_List },

 { "video.fs", MDFNSF_NOFLAGS, gettext_noop("Enable fullscreen mode."), NULL, MDFNST_BOOL, "0", },
 { "video.fs.display", MDFNSF_NOFLAGS, gettext_noop("Display to use with fullscreen mode."), gettext_noop("Specify -1 to use the display on which the center of the window lies in windowed mode."), MDFNST_INT, "-1", "-1", "32767" },

 //{ "video.window.x", MDFNSF_NOFLAGS, gettext_noop("Window starting X position."), NULL, MDFNST_INT, "0x2FFF0000" },
 //{ "video.window.y", MDFNSF_NOFLAGS, gettext_noop("Window starting Y position."), NULL, MDFNST_INT, "0x2FFF0000" },

 { "video.glvsync", MDFNSF_NOFLAGS, gettext_noop("Attempt to synchronize OpenGL page flips to vertical retrace period."), 
			       gettext_noop("Note: Additionally, if the environment variable \"__GL_SYNC_TO_VBLANK\" does not exist, then it will be created and set to the value specified for this setting.  This has the effect of forcibly enabling or disabling vblank synchronization when running under Linux with NVidia's drivers."),
				MDFNST_BOOL, "1" },

 { "video.disable_composition", MDFNSF_NOFLAGS, gettext_noop("Attempt to disable desktop composition."), gettext_noop("Currently, this setting only has an effect on Windows Vista and Windows 7(and probably the equivalent server versions as well)."), MDFNST_BOOL, "1" },
};

static const MDFNSetting_EnumList StretchMode_List[] =
{
 { "0", 0, gettext_noop("Disabled") },
 { "off", 0 },
 { "none", 0 },

 { "1", 1 },
 { "full", 1, gettext_noop("Full"), gettext_noop("Full-screen stretch, disregarding aspect ratio.") },

 { "2", 2 },
 { "aspect", 2, gettext_noop("Aspect Preserve"), gettext_noop("Full-screen stretch as far as the aspect ratio(in this sense, the equivalent xscalefs == yscalefs) can be maintained.") },

 { "aspect_int", 3, gettext_noop("Aspect Preserve + Integer Scale"), gettext_noop("Full-screen stretch, same as \"aspect\" except that the equivalent xscalefs and yscalefs are rounded down to the nearest integer.") },
 { "aspect_mult2", 4, gettext_noop("Aspect Preserve + Integer Multiple-of-2 Scale"), gettext_noop("Full-screen stretch, same as \"aspect_int\", but rounds down to the nearest multiple of 2.") },

 { NULL, 0 },
};

static const MDFNSetting_EnumList VideoIP_List[] =
{
 { "0", VIDEOIP_OFF, gettext_noop("Disabled") },

 { "1", VIDEOIP_BILINEAR, gettext_noop("Bilinear") },

 // Disabled until a fix can be made for rotation.
 { "x", VIDEOIP_LINEAR_X, gettext_noop("Linear (X)"), gettext_noop("Interpolation only on the X axis.") },
 { "y", VIDEOIP_LINEAR_Y, gettext_noop("Linear (Y)"), gettext_noop("Interpolation only on the Y axis.") },

 { NULL, 0 },
};

static const MDFNSetting_EnumList Special_List[] =
{
    { "0", 	NTVB_NONE },
    { "none", 	NTVB_NONE, "None/Disabled" },

#ifdef WANT_FANCY_SCALERS
    { "hq2x", 	NTVB_HQ2X, "hq2x" },
    { "hq3x", 	NTVB_HQ3X, "hq3x" },
    { "hq4x", 	NTVB_HQ4X, "hq4x" },
    { "scale2x",NTVB_SCALE2X, "scale2x" },
    { "scale3x",NTVB_SCALE3X, "scale3x" },
    { "scale4x",NTVB_SCALE4X, "scale4x" },

    { "2xsai", 	NTVB_2XSAI, "2xSaI" },
    { "super2xsai", NTVB_SUPER2XSAI, "Super 2xSaI" },
    { "supereagle", NTVB_SUPEREAGLE, "Super Eagle" },
#endif

    { "nn2x",	NTVB_NN2X, "Nearest-neighbor 2x" },
    { "nn3x",	NTVB_NN3X, "Nearest-neighbor 3x" },
    { "nn4x",	NTVB_NN4X, "Nearest-neighbor 4x" },
    { "nny2x",	NTVB_NNY2X, "Nearest-neighbor 2x, y axis only" },
    { "nny3x",	NTVB_NNY3X, "Nearest-neighbor 3x, y axis only" }, 
    { "nny4x",	NTVB_NNY4X, "Nearest-neighbor 4x, y axis only" },

    { NULL, 0 },
};

static const MDFNSetting_EnumList Shader_List[] =
{
    { "none",		SHADER_NONE,		gettext_noop("None/Disabled") },
    { "autoip", 	SHADER_AUTOIP,		gettext_noop("Auto Interpolation"), gettext_noop("Will automatically interpolate on each axis if the corresponding effective scaling factor is not an integer.") },
    { "autoipsharper",	SHADER_AUTOIPSHARPER,	gettext_noop("Sharper Auto Interpolation"), gettext_noop("Same as \"autoip\", but when interpolation is done, it is done in a manner that will reduce blurriness if possible.") },
    { "scale2x", 	SHADER_SCALE2X,    	"Scale2x" },
    { "sabr",		SHADER_SABR,		"SABR v3.0", gettext_noop("GPU-intensive.") },
    { "ipsharper", 	SHADER_IPSHARPER,  	gettext_noop("Sharper bilinear interpolation.") },
    { "ipxnoty", 	SHADER_IPXNOTY,    	gettext_noop("Linear interpolation on X axis only.") },
    { "ipynotx", 	SHADER_IPYNOTX,    	gettext_noop("Linear interpolation on Y axis only.") },
    { "ipxnotysharper", SHADER_IPXNOTYSHARPER, 	gettext_noop("Sharper version of \"ipxnoty\".") },
    { "ipynotxsharper", SHADER_IPYNOTXSHARPER, 	gettext_noop("Sharper version of \"ipynotx\".") },

    { "goat", 		SHADER_GOAT, 		gettext_noop("Simple approximation of a color TV CRT look."), gettext_noop("Intended for fullscreen modes with a vertical resolution of around 1000 to 1500 pixels.  Doesn't simulate halation and electron beam energy distribution nuances.") },

    { NULL, 0 },
};

static const MDFNSetting_EnumList GoatPat_List[] =
{
	{ "goatron",	ShaderParams::GOAT_MASKPAT_GOATRON,	gettext_noop("Goatron"), gettext_noop("Brightest.") },
	{ "goattron",	ShaderParams::GOAT_MASKPAT_GOATRON },
	{ "goatronprime",	ShaderParams::GOAT_MASKPAT_GOATRONPRIME },
	{ "goattronprime",	ShaderParams::GOAT_MASKPAT_GOATRONPRIME },

	{ "borg",	ShaderParams::GOAT_MASKPAT_BORG,	gettext_noop("Borg"), gettext_noop("Darkest.") },
	{ "slenderman",	ShaderParams::GOAT_MASKPAT_SLENDERMAN,	gettext_noop("Slenderman"), gettext_noop("Spookiest?") },

	{ NULL, 0 },
};

void Video_MakeSettings(std::vector <MDFNSetting> &settings)
{
 static const char *CSD_xres = gettext_noop("Full-screen horizontal resolution.");
 static const char *CSD_yres = gettext_noop("Full-screen vertical resolution.");
 static const char *CSDE_xres = gettext_noop("A value of \"0\" will cause the current desktop horizontal resolution to be used.");
 static const char *CSDE_yres = gettext_noop("A value of \"0\" will cause the current desktop vertical resolution to be used.");

 static const char *CSD_xscale = gettext_noop("Scaling factor for the X axis in windowed mode.");
 static const char *CSD_yscale = gettext_noop("Scaling factor for the Y axis in windowed mode.");

 static const char *CSD_xscalefs = gettext_noop("Scaling factor for the X axis in fullscreen mode.");
 static const char *CSD_yscalefs = gettext_noop("Scaling factor for the Y axis in fullscreen mode.");
 static const char *CSDE_xyscalefs = gettext_noop("For this settings to have any effect, the \"<system>.stretch\" setting must be set to \"0\".");

 static const char *CSD_scanlines = gettext_noop("Enable scanlines with specified opacity.");
 static const char *CSDE_scanlines = gettext_noop("Opacity is specified in %; IE a value of \"100\" will give entirely black scanlines.\n\nNegative values are the same as positive values for non-interlaced video, but for interlaced video will cause the scanlines to be overlaid over the previous(if the video.deinterlacer setting is set to \"weave\", the default) field's lines.");

 static const char *CSD_stretch = gettext_noop("Stretch to fill screen.");
 static const char *CSDvideo_settingsip = gettext_noop("Enable (bi)linear interpolation.");

 static const char *CSD_special = gettext_noop("Enable specified special video scaler.");
 static const char *CSDE_special = gettext_noop("The destination rectangle is NOT altered by this setting, so if you have xscale and yscale set to \"2\", and try to use a 3x scaling filter like hq3x, the image is not going to look that great. The nearest-neighbor scalers are intended for use with bilinear interpolation enabled, at high resolutions(such as 1280x1024; nn2x(or nny2x) + bilinear interpolation + fullscreen stretching at this resolution looks quite nice).");

 static const char *CSD_shader = gettext_noop("Enable specified OpenGL shader.");
 static const char *CSDE_shader = gettext_noop("Obviously, this will only work with the OpenGL \"video.driver\" setting, and only on cards and OpenGL implementations that support shaders, otherwise you will get a black screen, or Mednafen may display an error message when starting up. When a shader is enabled, the \"<system>.videoip\" setting is ignored.");

 for(unsigned int i = 0; i < MDFNSystems.size() + 1; i++)
 {
  int nominal_width;
  //int nominal_height;
  bool multires;
  const char *sysname;
  char default_value[256];
  MDFNSetting setting;
  const int default_xres = 0, default_yres = 0;
  const double default_scalefs = 1.0;
  double default_scale;

  if(i == MDFNSystems.size())
  {
   nominal_width = 384;
   //nominal_height = 240;
   multires = FALSE;
   sysname = "player";
  }
  else
  {
   nominal_width = MDFNSystems[i]->nominal_width;
   //nominal_height = MDFNSystems[i]->nominal_height;
   multires = MDFNSystems[i]->multires;
   sysname = (const char *)MDFNSystems[i]->shortname;
  }

  default_scale = ceil(1024 / nominal_width);

  if(default_scale * nominal_width > 1024)
   default_scale--;

  if(!default_scale)
   default_scale = 1;

  trio_snprintf(default_value, 256, "%d", default_xres);
  BuildSystemSetting(&setting, sysname, "xres", CSD_xres, CSDE_xres, MDFNST_UINT, strdup(default_value), "0", "65536");
  settings.push_back(setting);

  trio_snprintf(default_value, 256, "%d", default_yres);
  BuildSystemSetting(&setting, sysname, "yres", CSD_yres, CSDE_yres, MDFNST_UINT, strdup(default_value), "0", "65536");
  settings.push_back(setting);

  trio_snprintf(default_value, 256, "%f", default_scale);
  BuildSystemSetting(&setting, sysname, "xscale", CSD_xscale, NULL, MDFNST_FLOAT, strdup(default_value), "0.01", "256");
  settings.push_back(setting);
  BuildSystemSetting(&setting, sysname, "yscale", CSD_yscale, NULL, MDFNST_FLOAT, strdup(default_value), "0.01", "256");
  settings.push_back(setting);

  trio_snprintf(default_value, 256, "%f", default_scalefs);
  BuildSystemSetting(&setting, sysname, "xscalefs", CSD_xscalefs, CSDE_xyscalefs, MDFNST_FLOAT, strdup(default_value), "0.01", "256");
  settings.push_back(setting);
  BuildSystemSetting(&setting, sysname, "yscalefs", CSD_yscalefs, CSDE_xyscalefs, MDFNST_FLOAT, strdup(default_value), "0.01", "256");
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "scanlines", CSD_scanlines, CSDE_scanlines, MDFNST_INT, "0", "-100", "100");
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "stretch", CSD_stretch, NULL, MDFNST_ENUM, "aspect_mult2", NULL, NULL, NULL, NULL, StretchMode_List);
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "videoip", CSDvideo_settingsip, NULL, MDFNST_ENUM, multires ? "1" : "0", NULL, NULL, NULL, NULL, VideoIP_List);
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "special", CSD_special, CSDE_special, MDFNST_ENUM, "none", NULL, NULL, NULL, NULL, Special_List);
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader", CSD_shader, CSDE_shader, MDFNST_ENUM, "none", NULL, NULL, NULL, NULL, Shader_List);
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader.goat.hdiv", gettext_noop("Constant RGB horizontal divergence."), nullptr, MDFNST_FLOAT, "0.50", "-2.00", "2.00");
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader.goat.vdiv", gettext_noop("Constant RGB vertical divergence."), nullptr, MDFNST_FLOAT, "0.50", "-2.00", "2.00");
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader.goat.pat", gettext_noop("Mask pattern."), nullptr, MDFNST_ENUM, "goatron", NULL, NULL, NULL, NULL, GoatPat_List);
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader.goat.tp", gettext_noop("Transparency of otherwise-opaque mask areas."), nullptr, MDFNST_FLOAT, "0.50", "0.00", "1.00");
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader.goat.fprog", gettext_noop("Force interlaced video to be treated as progressive."), gettext_noop("When disabled, the default, the \"video.deinterlacer\" setting is effectively ignored with respect to what appears on the screen.  When enabled, it may be prudent to disable the scanlines effect controlled by the *.goat.slen setting, or else the scanline effect may look objectionable."), MDFNST_BOOL, "0");
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "shader.goat.slen", gettext_noop("Enable scanlines effect."), nullptr, MDFNST_BOOL, "1");
  settings.push_back(setting);
 }

 for(unsigned i = 0; i < sizeof(GlobalVideoSettings) / sizeof(GlobalVideoSettings[0]); i++)
  settings.push_back(GlobalVideoSettings[i]);
}

static struct
{
 int fullscreen;
 int fs_display;
 int xres, yres;
 double xscale, xscalefs;
 double yscale, yscalefs;
 int videoip;
 int stretch;
 int special;
 int scanlines;
 ShaderType shader;
 ShaderParams shader_params;

 std::string special_str, shader_str, goat_pat_str;
} video_settings;

static unsigned vdriver;
static bool osd_alpha_blend;

static const struct ScalerDefinition
{
	int id;
	int xscale;
	int yscale;
} Scalers[] = 
{
	{ NTVB_HQ2X, 2, 2 },
	{ NTVB_HQ3X, 3, 3 },
	{ NTVB_HQ4X, 4, 4 },

	{ NTVB_SCALE2X, 2, 2 },
	{ NTVB_SCALE3X, 3, 3 },
	{ NTVB_SCALE4X, 4, 4 },

	{ NTVB_NN2X, 2, 2 },
        { NTVB_NN3X, 3, 3 },
        { NTVB_NN4X, 4, 4 },

	{ NTVB_NNY2X, 1, 2 },
	{ NTVB_NNY3X, 1, 3 },
	{ NTVB_NNY4X, 1, 4 },

	{ NTVB_2XSAI, 2, 2 },
	{ NTVB_SUPER2XSAI, 2, 2 },
	{ NTVB_SUPEREAGLE, 2, 2 },
};

static MDFNGI *VideoGI;

static const ScalerDefinition* CurrentScaler = NULL;

static int winpos_x, winpos_y;
static bool winpos_applied;
static SDL_Window* window = NULL;
static SDL_GLContext glcontext = NULL;
static SDL_Surface *screen = NULL;
static OpenGL_Blitter *ogl_blitter = NULL;
static SDL_Surface *IconSurface=NULL;

static int32 screen_w, screen_h;
static MDFN_Rect screen_dest_rect;

static MDFN_Surface *HelpSurface = NULL;
static MDFN_Rect HelpRect;

static MDFN_Surface *SMSurface = NULL;
static MDFN_Rect SMRect;
static MDFN_Rect SMDRect;

static double exs,eys;
static int evideoip;

static int NeedClear = 0;
static uint32 LastBBClearTime = 0;

static WMInputBehavior CurWMIB;

static int rotated;

static MDFN_PixelFormat pf_normal;

static INLINE void MarkNeedBBClear(void)
{
 NeedClear = 15;
}

static void SyncCleanup(void)
{
 if(SMSurface)
 {
  delete SMSurface;
  SMSurface = nullptr;
 }

 if(HelpSurface)
 {
  delete HelpSurface;
  HelpSurface = nullptr;
 }

 if(ogl_blitter)
 {
  delete ogl_blitter;
  ogl_blitter = nullptr;
 }

 if(glcontext)
 {
  SDL_GL_DeleteContext(glcontext);
  glcontext = nullptr;
 }

/*
*/
}

void Video_Kill(void)
{
 SyncCleanup();

 if(window)
 {
  if(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN)
   SDL_SetWindowFullscreen(window, 0);
  //
  SDL_SetRelativeMouseMode(SDL_FALSE);
  SDL_ShowCursor(SDL_TRUE);
  SDL_SetWindowGrab(window, SDL_FALSE);

  SDL_DestroyWindow(window);
  window = nullptr;
 }
 //
 //
 //
 if(IconSurface)
 {
  //SDL_FreeSurface(IconSurface);
  //IconSurface = nullptr;
 }

 screen = nullptr;
 VideoGI = nullptr;
 screen_w = 0;
 screen_h = 0;
}

// May be called before Video_Init(), and after Video_Kill().
bool Video_ErrorPopup(bool warning, const char* title, const char* text)
{
 bool ret = false;

 #ifdef WIN32
 if(window)
 {
  // Best not to drive the user stark raving mad.
  SDL_SetRelativeMouseMode(SDL_FALSE);
  SDL_ShowCursor(SDL_TRUE);
  SDL_SetWindowGrab(window, SDL_FALSE);
  // should we or shouldn't we...: SDL_SetHint(SDL_HINT_WINDOWS_NO_CLOSE_ON_ALT_F4, "0");
 }
#if 0
 SDL_Window* pw = window;

 // Avoid comically-horrible behavior.
 if(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN)
  pw = nullptr;

 ret = !SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, title, text, pw);
#endif
 ret = (bool)MessageBoxW(NULL, (wchar_t*)UTF8_to_UTF16(text).c_str(), (wchar_t*)UTF8_to_UTF16(title).c_str(), MB_OK | (warning ? MB_ICONWARNING : MB_ICONERROR) | MB_TASKMODAL | MB_SETFOREGROUND | MB_TOPMOST);

 if(window)
  Video_SetWMInputBehavior(CurWMIB);
 #endif

 return ret;
}

static void GenerateWindowedDestRect(void)
{
 exs = video_settings.xscale;
 eys = video_settings.yscale;

 screen_dest_rect.x = 0;
 screen_dest_rect.y = 0;
 screen_dest_rect.w = floor(0.5 + VideoGI->nominal_width * exs);
 screen_dest_rect.h = floor(0.5 + VideoGI->nominal_height * eys);

 if(rotated == MDFN_ROTATE90 || rotated == MDFN_ROTATE270)
  std::swap(screen_dest_rect.w, screen_dest_rect.h);
}

static bool GenerateFullscreenDestRect(void)
{
 if(video_settings.stretch)
 {
  int nom_width, nom_height;

  if(rotated)
  {
   nom_width = VideoGI->nominal_height;
   nom_height = VideoGI->nominal_width;
  }
  else
  {
   nom_width = VideoGI->nominal_width;
   nom_height = VideoGI->nominal_height;
  }

  if(video_settings.stretch == 2 || video_settings.stretch == 3 || video_settings.stretch == 4)	// Aspect-preserve stretch
  {
   exs = (double)screen_w / nom_width;
   eys = (double)screen_h / nom_height;

   if(video_settings.stretch == 3 || video_settings.stretch == 4)	// Round down to nearest int.
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

     if(video_settings.stretch == 4)	// Round down to nearest multiple of 2.
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

   screen_dest_rect.w = floor(0.5 + exs * nom_width);
   screen_dest_rect.h = floor(0.5 + eys * nom_height);

   // Centering:
   int nx = (int)((screen_w - screen_dest_rect.w) / 2);
   if(nx < 0) nx = 0;
   screen_dest_rect.x = nx;

   int ny = (int)((screen_h - screen_dest_rect.h) / 2);
   if(ny < 0) ny = 0;
   screen_dest_rect.y = ny;
  }
  else 	// Full-stretch
  {
   screen_dest_rect.x = 0;
   screen_dest_rect.w = screen_w;

   screen_dest_rect.y = 0;
   screen_dest_rect.h = screen_h;

   exs = (double)screen_w / nom_width;
   eys = (double)screen_h / nom_height;
  }
 }
 else
 {
  exs = video_settings.xscalefs;
  eys = video_settings.yscalefs;

  screen_dest_rect.w = floor(0.5 + VideoGI->nominal_width * exs);
  screen_dest_rect.h = floor(0.5 + VideoGI->nominal_height * eys);

  if(rotated == MDFN_ROTATE90 || rotated == MDFN_ROTATE270)
   std::swap(screen_dest_rect.w, screen_dest_rect.h);

  screen_dest_rect.x = (screen_w - screen_dest_rect.w) / 2;
  screen_dest_rect.y = (screen_h - screen_dest_rect.h) / 2;
 }

 // Quick and dirty kludge for VB's "hli" and "vli" 3D modes.
 screen_dest_rect.x &= ~1;
 screen_dest_rect.y &= ~1;

 return screen_dest_rect.w < 16384 && screen_dest_rect.h < 16384;
}

static bool weset_glstvb = false; 
static uint32 real_rs, real_gs, real_bs, real_as;

void Video_SetWMInputBehavior(const WMInputBehavior& beeeeees)
{
 CurWMIB = beeeeees;
 //
 const bool fs = (SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN);
 const bool grab = CurWMIB.Grab;
 const bool relm = CurWMIB.MouseRel && !CurWMIB.MouseAbs && !CurWMIB.Cursor && (grab || fs);
 const bool curse = !relm && CurWMIB.Cursor;

 //printf("Grab: %d, RelM: %d, Curse: %d\n", grab, relm, curse);

 if(grab)
 {
  SDL_ShowWindow(window);
  SDL_RaiseWindow(window);
  SDL_SetWindowGrab(window, SDL_TRUE);
 }

 SDL_ShowCursor(SDL_FALSE);
 SDL_SetRelativeMouseMode(relm ? SDL_TRUE : SDL_FALSE);
 SDL_ShowCursor(curse ? SDL_TRUE : SDL_FALSE);

 if(!grab)
  SDL_SetWindowGrab(window, SDL_FALSE);

 SDL_SetHint(SDL_HINT_WINDOWS_NO_CLOSE_ON_ALT_F4, grab ? "1" : "0");
}

#if 0
struct ModeInfo
{
 int32 width = 0;
 int32 height = 0;
 MDFN_PixelFormat format(MDFN_COLORSPACE_RGB, 0, 8, 16, 24);
 bool fullscreen = false;
 float refresh_rate = 0.0
 bool vsync = false;
};

static ModeInfo SetMode(const ModeInfo& mode)
{
 if(window && !(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN))
  SDL_GetWindowPosition(window, &winpos_x, &winpos_y);

 if(window && !(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN))
  SDL_GetWindowPosition(window, &winpos_x, &winpos_y);
 //
 SyncCleanup();
}

 if(new_mode == last_tried_mode && new_mode == cur_mode)
  SetMode(new_mode);
#endif

void Video_Sync(MDFNGI *gi)
{
 MDFNI_printf(_("Initializing video...\n"));
 MDFN_AutoIndent aindv(1);

 if(window && winpos_applied && !(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN))
  SDL_GetWindowPosition(window, &winpos_x, &winpos_y);
 //
 SyncCleanup();
 //Time::SleepMS(1000);

 VideoGI = gi;
 rotated = gi->rotated;
 //
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
 //
 osd_alpha_blend = MDFN_GetSettingB("osd.alpha_blend");

 std::string snp = std::string(gi->shortname) + ".";

 if(gi->GameType == GMT_PLAYER)
  snp = "player.";

 video_settings.xres = MDFN_GetSettingUI(snp + "xres");
 video_settings.yres = MDFN_GetSettingUI(snp + "yres");
 video_settings.xscale = MDFN_GetSettingF(snp + "xscale");
 video_settings.yscale = MDFN_GetSettingF(snp + "yscale");
 video_settings.xscalefs = MDFN_GetSettingF(snp + "xscalefs");
 video_settings.yscalefs = MDFN_GetSettingF(snp + "yscalefs");
 video_settings.videoip = MDFN_GetSettingI(snp + "videoip");
 video_settings.stretch = MDFN_GetSettingUI(snp + "stretch");
 video_settings.scanlines = MDFN_GetSettingI(snp + "scanlines");

 video_settings.special = MDFN_GetSettingUI(snp + std::string("special"));
 video_settings.special_str = MDFN_GetSettingS(snp + std::string("special"));

 video_settings.shader_params.goat_hdiv = MDFN_GetSettingF(snp + "shader.goat.hdiv");
 video_settings.shader_params.goat_vdiv = MDFN_GetSettingF(snp + "shader.goat.vdiv");
 video_settings.shader_params.goat_pat = MDFN_GetSettingI(snp + "shader.goat.pat");
 video_settings.goat_pat_str = MDFN_GetSettingS(snp + "shader.goat.pat");
 video_settings.shader_params.goat_tp = MDFN_GetSettingF(snp + "shader.goat.tp");
 video_settings.shader_params.goat_slen = MDFN_GetSettingB(snp + "shader.goat.slen");
 video_settings.shader_params.goat_fprog = MDFN_GetSettingB(snp + "shader.goat.fprog");
 //

 video_settings.fullscreen = MDFN_GetSettingB("video.fs");
 video_settings.fs_display = MDFN_GetSettingI("video.fs.display");
 vdriver = MDFN_GetSettingI("video.driver");
 if(vdriver == VDRIVER__COUNT) // "default"
  vdriver = VDRIVER_OPENGL;

 video_settings.shader = (ShaderType)MDFN_GetSettingI(snp + "shader");
 video_settings.shader_str = MDFN_GetSettingS(snp + "shader");
 //
 //
 if(0)
 {
  // Gotta keep the compiler on its toes(the floor is SPAGHETTI)!
  TryWindowed:;
  MDFNI_SetSettingB("video.fs", false);
  video_settings.fullscreen = 0;
  if(window)
  {
   if(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN)
    SDL_SetWindowFullscreen(window, 0);
  }
 }

 GenerateWindowedDestRect();
 screen_w = screen_dest_rect.w;
 screen_h = screen_dest_rect.h;
 //
 //

 if(screen_dest_rect.w > 16383 || screen_dest_rect.h > 16383)
  throw MDFN_Error(0, _("Window size(%dx%d) is too large!"), screen_dest_rect.w, screen_dest_rect.h);

 SDL_SetWindowFullscreen(window, 0);
 SDL_PumpEvents();
 SDL_SetWindowSize(window, screen_dest_rect.w, screen_dest_rect.h);
 SDL_PumpEvents();
 SDL_SetWindowPosition(window, winpos_x, winpos_y);
 winpos_applied = true;
 SDL_PumpEvents();
 SDL_SetWindowTitle(window, (gi && gi->name.size()) ? gi->name.c_str() : "Mednafen");
 SDL_PumpEvents();
 SDL_ShowWindow(window);
 SDL_PumpEvents();

 //
 if(0)
 {
  TryNonGL:;

  if(ogl_blitter)
  {
   delete ogl_blitter;
   ogl_blitter = nullptr;
  }

  if(glcontext)
  {
   SDL_GL_DeleteContext(glcontext);
   glcontext = nullptr;
  }
  vdriver = VDRIVER_SOFTSDL;
 }
 //
 if(vdriver == VDRIVER_OPENGL)
 {
  if(!(SDL_GetWindowFlags(window) & SDL_WINDOW_OPENGL))
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to soft SDL driver because window is not OpenGL-capable."));
   goto TryNonGL;
  }
  else
  {
   SDL_GL_ResetAttributes();
   SDL_GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
   //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 1);
   //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 4);
   SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

   if(!(glcontext = SDL_GL_CreateContext(window)))
   {
    MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to soft SDL driver because of error creating OpenGL context: %s"), SDL_GetError());
    goto TryNonGL;
   }
   else
   {
    SDL_GL_SetSwapInterval(MDFN_GetSettingB("video.glvsync"));
   }
  }
 }

#if 1
 // Kludge, TODO: figure out where the bug exists in SDL or wherever...
 {
  int x, y;
  SDL_GetWindowPosition(window, &x, &y);
  SDL_PumpEvents();
  SDL_SetWindowPosition(window, x, y);
 }
#endif

 //
 //
 //
 CurrentScaler = nullptr;
 for(auto& scaler : Scalers)
  if(video_settings.special == scaler.id)
   CurrentScaler = &scaler;
 assert(video_settings.special == NTVB_NONE || CurrentScaler);

 evideoip = video_settings.videoip;

 //
 //
 //
 if(video_settings.fullscreen)
 {
  const unsigned xres = video_settings.xres;
  const unsigned yres = video_settings.yres;
  SDL_DisplayMode trymode;
  SDL_DisplayMode mode;
  int dindex;

  if(video_settings.fs_display >= 0)
   dindex = video_settings.fs_display;
  else
  {
#if 0
  if((dindex = SDL_GetWindowDisplayIndex(window)) < 0)
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_GetWindowDisplayIndex() failed: %s"), SDL_GetError());
   goto TryWindowed;
  }
#endif
   int num_displays;
   int wx, wy;
   int ww, wh;
   int wcx, wcy;

   dindex = 0;

   SDL_GetWindowPosition(window, &wx, &wy);
   SDL_GetWindowSize(window, &ww, &wh);

   wcx = wx + ww / 2;
   wcy = wy + wh / 2;

   if((num_displays = SDL_GetNumVideoDisplays()) < 0)
   {
    MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_GetNumVideoDisplays() failed: %s"), SDL_GetError());
    goto TryWindowed;
   }

   //
   // Fullscreen with mirrored displays is kind of glitchy(maybe partly SDL2's fault?), but try to force usage of the one with the largest pixel count.
   //
   struct DIndexModeBounds
   {
    int dindex;
    SDL_DisplayMode mode;
    SDL_Rect bounds;
   };
   std::vector<DIndexModeBounds> dimbs;

   for(int d = 0; d < num_displays; d++)
   {
    DIndexModeBounds z;

    z.dindex = d;
    if(SDL_GetCurrentDisplayMode(d, &z.mode) < 0)
    {
     MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_GetCurrentDisplayMode() failed: %s"), SDL_GetError());
     goto TryWindowed;
    }

    if(SDL_GetDisplayBounds(d, &z.bounds) < 0)
    {
     MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_DisplayBounds() failed: %s"), SDL_GetError());
     goto TryWindowed;     
    }

    bool add_at_end = true;
    // Won't perform well if someone has thousands of displays ;)
    for(DIndexModeBounds& dimbs_e : dimbs)
    {
     if(z.bounds.x == dimbs_e.bounds.x && z.bounds.y == dimbs_e.bounds.y)
     {
      if((z.mode.w * z.mode.h) > (dimbs_e.mode.w * dimbs_e.mode.h))
       dimbs_e = z;

      add_at_end = false;
      break;
     }
    }

    if(add_at_end)
     dimbs.push_back(z);
   }

   int64 last_distance = INT64_MAX;
   for(const DIndexModeBounds& e : dimbs)
   {
    const int bcx = e.bounds.x + (e.bounds.w / 2);
    const int bcy = e.bounds.y + (e.bounds.h / 2);
    const int dx = wcx - bcx;
    const int dy = wcy - bcy;
    const int64 distance = (int64)dx * dx + (int64)dy * dy;

    if(distance < last_distance)
    {
     dindex = e.dindex;
     last_distance = distance;
    }
   }
  }

  //
  //
  {
   SDL_Rect dbr;

   if(SDL_GetDisplayBounds(dindex, &dbr) < 0)
   {
    MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_GetDisplayBounds() failed: %s"), SDL_GetError());
    goto TryWindowed;
   }

   SDL_SetWindowPosition(window, dbr.x, dbr.y);
   SDL_SetWindowSize(window, dbr.w, dbr.h);
  }
  //
  //

  if(SDL_GetCurrentDisplayMode(dindex, &trymode) < 0)
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_GetCurrentDisplayMode() failed: %s"), SDL_GetError());
   goto TryWindowed;
  }

  if(xres > 0)
   trymode.w = xres;

  if(yres > 0)
   trymode.h = yres;

  if(!SDL_GetClosestDisplayMode(dindex, &trymode, &mode))
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because no modes big enough for %dx%d."), trymode.w, trymode.h);
   goto TryWindowed;
  }

  if(SDL_SetWindowDisplayMode(window, &mode) < 0)
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_SetWindowDisplayMode() failed: %s"), SDL_GetError());
   goto TryWindowed;
  }

#if 0
  int old_mousex = 0;
  int old_mousey = 0;
  SDL_GetGlobalMouseState(&old_mousex, &old_mousey);
#endif

  if(SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN) < 0)
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because SDL_SetWindowFullscreen() failed: %s"), SDL_GetError());
   goto TryWindowed;
  }

#if 0
  // ugggh
  SDL_PumpEvents();
  SDL_Delay(20);
  SDL_PumpEvents();
  SDL_WarpMouseGlobal(old_mousex, old_mousey);
#endif

  screen_w = mode.w;
  screen_h = mode.h;
  if(!GenerateFullscreenDestRect())
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to windowed mode because screen destination rectangle(%dx%d) is too large!"), screen_dest_rect.w, screen_dest_rect.h);
   goto TryWindowed;
  }
 }
 //
 //
 MDFN_printf(_("Driver: %s\n"), (vdriver == VDRIVER_OPENGL) ? _("OpenGL") : _("Software SDL") );
 //
 //
 int rs, gs, bs, as;

 screen = nullptr;

 {
  SDL_DisplayMode mode;

  if(SDL_GetCurrentDisplayMode(SDL_GetWindowDisplayIndex(window), &mode) < 0)
   throw MDFN_Error(0, "SDL_GetCurrentDisplayMode() failed: %s", SDL_GetError());

  if(mode.refresh_rate)
   MDFN_printf(_("Display Mode: %u x %u x %u bpp @ %dHz  (Window: %u x %u)\n"), mode.w, mode.h, SDL_BITSPERPIXEL(mode.format), mode.refresh_rate, screen_w, screen_h);
  else
   MDFN_printf(_("Display Mode: %u x %u x %u bpp  (Window: %u x %u)\n"), mode.w, mode.h, SDL_BITSPERPIXEL(mode.format), screen_w, screen_h);

  if(vdriver != VDRIVER_OPENGL)
  {
   if(!(screen = SDL_GetWindowSurface(window)))
    throw MDFN_Error(0, _("SDL_GetWindowSurface() failed: %s"), SDL_GetError());

   if(screen->format->BitsPerPixel != 32)
    throw MDFN_Error(0, _("Window surface bit depth(%ubpp) is not supported by Mednafen."), screen->format->BitsPerPixel);

   rs = screen->format->Rshift;
   gs = screen->format->Gshift;
   bs = screen->format->Bshift;

   as = 0;
   while(as == rs || as == gs || as == bs) // Find unused 8-bits to use as our alpha channel
    as += 8;
  }
 }

 if(vdriver == VDRIVER_OPENGL)
 {
  MDFN_AutoIndent aindps;
  char sp[128] = { 0 };

  if(video_settings.shader == SHADER_GOAT)
  {
   trio_snprintf(sp, sizeof(sp), " (pat=%s, hdiv=%f, vdiv=%f, tp=%f, slen=%d, fprog=%d)",
	video_settings.goat_pat_str.c_str(), video_settings.shader_params.goat_hdiv, video_settings.shader_params.goat_vdiv, video_settings.shader_params.goat_tp, video_settings.shader_params.goat_slen, video_settings.shader_params.goat_fprog);
  }

  MDFN_printf(_("Shader: %s%s\n"), video_settings.shader_str.c_str(), sp);
 }

 MDFN_printf(_("Fullscreen: %s\n"), video_settings.fullscreen ? _("Yes") : _("No"));
 MDFN_printf(_("Special Scaler: %s\n"), (video_settings.special == NTVB_NONE) ? _("None") : video_settings.special_str.c_str());

 if(!video_settings.scanlines)
  MDFN_printf(_("Scanlines: Off\n"));
 else
  MDFN_printf(_("Scanlines: %d%% opacity%s\n"), abs(video_settings.scanlines), (video_settings.scanlines < 0) ? _(" (with interlace field obscure)") : "");

 MDFN_printf(_("Destination Rectangle: X=%d, Y=%d, W=%d, H=%d\n"), screen_dest_rect.x, screen_dest_rect.y, screen_dest_rect.w, screen_dest_rect.h);
 if(screen_dest_rect.x < 0 || screen_dest_rect.y < 0 || (screen_dest_rect.x + screen_dest_rect.w) > screen_w || (screen_dest_rect.y + screen_dest_rect.h) > screen_h)
 {
  MDFN_AutoIndent ainddr;
  MDFN_printf(_("Warning:  Destination rectangle exceeds screen dimensions.  This is ok if you really do want the clipping...\n"));
 }

 if(vdriver == VDRIVER_OPENGL)
 {
  try
  {
   ogl_blitter = new OpenGL_Blitter(video_settings.scanlines, video_settings.shader, video_settings.shader_params, &rs, &gs, &bs, &as);
   ogl_blitter->SetViewport(screen_w, screen_h);
  }
  catch(std::exception& e)
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Reverting to soft SDL driver because of error initializing OpenGL blitter: %s"), e.what());
   goto TryNonGL;
  }
 }

 //printf("%d %d %d %d\n", rs, gs, bs, as);

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

 {
  int xmu = std::max<int>(1, screen_w / 402);
  int ymu = std::max<int>(1, screen_h / 288);

  SMRect.h = 18 + 2;
  SMRect.x = 0;
  SMRect.y = 0;
  SMRect.w = screen_w;

  SMDRect.w = SMRect.w * xmu;
  SMDRect.h = SMRect.h * ymu;
  SMDRect.x = (screen_w - SMDRect.w) / 2;
  SMDRect.y = screen_h - SMDRect.h;

  if(SMDRect.x < 0)
  {
   SMRect.w += SMDRect.x * 2 / xmu;
   SMDRect.w = SMRect.w * xmu;
   SMDRect.x = 0;
  }
  SMSurface = new MDFN_Surface(NULL, SMRect.w, SMRect.h, SMRect.w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));
 }

 pf_normal = MDFN_PixelFormat(MDFN_COLORSPACE_RGB, rs, gs, bs, as);

 if(vdriver == VDRIVER_OPENGL)
 {
  for(int i = 0; i < 2; i++)
  {
   ogl_blitter->ClearBackBuffer();
   SDL_GL_SwapWindow(window);
   //ogl_blitter->HardSync();
  }
  ogl_blitter->ClearBackBuffer();
 }
 else
 {
  SDL_FillRect(screen, NULL, 0);
  for(int i = 0; i < 2; i++)
   SDL_UpdateWindowSurface(window);
 }

 MarkNeedBBClear();
 //
 //
 //
 Video_SetWMInputBehavior(CurWMIB);
}

void Video_Init(void)
{
 winpos_x = SDL_WINDOWPOS_CENTERED; //MDFN_GetSettingI("video.window.x");
 winpos_y = SDL_WINDOWPOS_CENTERED; //MDFN_GetSettingI("video.window.y");
 winpos_applied = false;

 CurWMIB.Cursor = true;
 CurWMIB.MouseAbs = true;
 CurWMIB.MouseRel = false;
 CurWMIB.Grab = false;
 //
 IconSurface = SDL_CreateRGBSurfaceFrom((void*)icon_128x128, 128, 128, 32, 128 * 4, 0xFF, 0xFF00, 0xFF0000, 0xFF000000);

 for(unsigned i = (vdriver != VDRIVER_OPENGL); i < 2; i++)
 {
  if(!(window = SDL_CreateWindow("Mednafen", winpos_x, winpos_y, 64, 64, SDL_WINDOW_HIDDEN | (i ? 0 : SDL_WINDOW_OPENGL))))
  {
   if(i == 1)
    throw MDFN_Error(0, _("SDL_CreateWindow() failed: %s\n"), SDL_GetError());
  }

  break;
 }

 SDL_SetWindowIcon(window, IconSurface);
}

static uint32 howlong = 0;
static char* CurrentMessage = NULL;
static MDFN_NoticeType CurrentMessageType;

void Video_ShowNotice(MDFN_NoticeType t, char* s)
{
 howlong = Time::MonoMS() + MDFN_GetSettingUI("osd.message_display_time");

 if(CurrentMessage)
 {
  free(CurrentMessage);
  CurrentMessage = NULL;
 }

 CurrentMessage = s;
 CurrentMessageType = t;
}

void BlitRaw(MDFN_Surface *src, const MDFN_Rect *src_rect, const MDFN_Rect *dest_rect, int source_alpha)
{
 if(ogl_blitter)
  ogl_blitter->BlitRaw(src, src_rect, dest_rect, (source_alpha != 0) && osd_alpha_blend);
 else
 {
  SDL_to_MDFN_Surface_Wrapper m_surface(screen);

  //MDFN_SrcAlphaBlitSurface(src, src_rect, &m_surface, dest_rect);
  MDFN_StretchBlitSurface(src, *src_rect, &m_surface, *dest_rect, (source_alpha > 0) && osd_alpha_blend);
 }

 bool cond1 = (dest_rect->x < screen_dest_rect.x || (dest_rect->x + dest_rect->w) > (screen_dest_rect.x + screen_dest_rect.w));
 bool cond2 = (dest_rect->y < screen_dest_rect.y || (dest_rect->y + dest_rect->h) > (screen_dest_rect.y + screen_dest_rect.h));

 if(cond1 || cond2)
  MarkNeedBBClear();
}

static bool BlitInternalMessage(void)
{
 if(Time::MonoMS() >= howlong)
 {
  if(CurrentMessage)
  {
   free(CurrentMessage);
   CurrentMessage = NULL;
  }
  return false;
 }

 if(CurrentMessage)
 {
  uint32 shad_color = SMSurface->MakeColor(0x00, 0x00, 0x00, 0xFF);
  uint32 text_color;
  uint8 fill_alpha = 0xC0;

  switch(CurrentMessageType)
  {
   default:
   case MDFN_NOTICE_STATUS:
	text_color = SMSurface->MakeColor(0xFF, 0xFF, 0xFF, 0xFF);
	break;

   case MDFN_NOTICE_WARNING:
	text_color = SMSurface->MakeColor(0xFF, 0xFF, 0x00, 0xFF);
	break;

   case MDFN_NOTICE_ERROR:
	text_color = SMSurface->MakeColor(0xFF, 0x00, 0x00, 0xFF);
	fill_alpha = 0xFF;
	break;
  }

  SMSurface->Fill(0x00, 0x00, 0x00, fill_alpha);

  DrawTextShadow(SMSurface, 0, 1, CurrentMessage, text_color, shad_color, MDFN_FONT_9x18_18x18, SMRect.w);
  free(CurrentMessage);
  CurrentMessage = NULL;
 }

 BlitRaw(SMSurface, &SMRect, &SMDRect);

 return true;
}

static void SubBlit(const MDFN_Surface *source_surface, const MDFN_Rect &src_rect, const MDFN_Rect &dest_rect, const int InterlaceField)
{
 const MDFN_Surface *eff_source_surface = source_surface;
 MDFN_Rect eff_src_rect = src_rect;

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

   if(CurrentScaler)
   {
    MDFN_Rect boohoo_rect({0, 0, eff_src_rect.w * CurrentScaler->xscale, eff_src_rect.h * CurrentScaler->yscale});
    MDFN_Surface bah_surface(NULL, boohoo_rect.w, boohoo_rect.h, boohoo_rect.w, eff_source_surface->format, false);
    uint8* screen_pixies = (uint8 *)bah_surface.pixels;
    uint32 screen_pitch = bah_surface.pitch32 << 2;

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
      nnx(CurrentScaler->id - NTVB_SCALE2X + 2, eff_source_surface, eff_src_rect, &bah_surface, boohoo_rect);
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
     nnx(CurrentScaler->id - NTVB_NN2X + 2, eff_source_surface, eff_src_rect, &bah_surface, boohoo_rect);
    }
    else if(CurrentScaler->id == NTVB_NNY2X || CurrentScaler->id == NTVB_NNY3X || CurrentScaler->id == NTVB_NNY4X)
    {
     nnyx(CurrentScaler->id - NTVB_NNY2X + 2, eff_source_surface, eff_src_rect, &bah_surface, boohoo_rect);
    }
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
      MDFN_Surface saisrc(NULL, eff_src_rect.w + 4, eff_src_rect.h + 4, eff_src_rect.w + 4, eff_source_surface->format);

      for(int y = 0; y < 2; y++)
      {
       memcpy(saisrc.pixels + (y * saisrc.pitchinpix) + 2, (uint32 *)source_pixies, eff_src_rect.w * sizeof(uint32));
       memcpy(saisrc.pixels + ((2 + y + eff_src_rect.h) * saisrc.pitchinpix) + 2, (uint32 *)source_pixies + (eff_src_rect.h - 1) * eff_source_surface->pitchinpix, eff_src_rect.w * sizeof(uint32));
      }

      for(int y = 0; y < eff_src_rect.h; y++)
      {
       memcpy(saisrc.pixels + ((2 + y) * saisrc.pitchinpix) + 2, (uint32*)source_pixies + y * eff_source_surface->pitchinpix, eff_src_rect.w * sizeof(uint32));
       memcpy(saisrc.pixels + ((2 + y) * saisrc.pitchinpix) + (2 + eff_src_rect.w),
	      saisrc.pixels + ((2 + y) * saisrc.pitchinpix) + (2 + eff_src_rect.w - 1), sizeof(uint32));
      }

      {
       uint8 *saipix = (uint8 *)(saisrc.pixels + 2 * saisrc.pitchinpix + 2);
       uint32 saipitch = saisrc.pitchinpix << 2;

       if(CurrentScaler->id == NTVB_2XSAI)
        _2xSaI32(saipix, saipitch, screen_pixies, screen_pitch, eff_src_rect.w, eff_src_rect.h);
       else if(CurrentScaler->id == NTVB_SUPER2XSAI)
        Super2xSaI32(saipix, saipitch, screen_pixies, screen_pitch, eff_src_rect.w, eff_src_rect.h);
       else if(CurrentScaler->id == NTVB_SUPEREAGLE)
        SuperEagle32(saipix, saipitch, screen_pixies, screen_pitch, eff_src_rect.w, eff_src_rect.h);
      }
     }

     if(bah_surface.format.Rshift != real_rs || bah_surface.format.Gshift != real_gs || bah_surface.format.Bshift != real_bs)
     {
      uint32 *lineptr = bah_surface.pixels;

      unsigned int srs = bah_surface.format.Rshift;
      unsigned int sgs = bah_surface.format.Gshift;
      unsigned int sbs = bah_surface.format.Bshift;
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
       lineptr += bah_surface.pitchinpix;
      }
     }
    }
#endif

    if(ogl_blitter)
     ogl_blitter->Blit(&bah_surface, &boohoo_rect, &dest_rect, &eff_src_rect, InterlaceField, evideoip, rotated);
    else
    {
     SDL_to_MDFN_Surface_Wrapper m_surface(screen);

     MDFN_StretchBlitSurface(&bah_surface, boohoo_rect, &m_surface, dest_rect, false, video_settings.scanlines, &eff_src_rect, rotated, InterlaceField);
    }
   }
   else // No special scaler:
   {
    if(ogl_blitter)
     ogl_blitter->Blit(eff_source_surface, &eff_src_rect, &dest_rect, &eff_src_rect, InterlaceField, evideoip, rotated);
    else
    {
     SDL_to_MDFN_Surface_Wrapper m_surface(screen);

     MDFN_StretchBlitSurface(eff_source_surface, eff_src_rect, &m_surface, dest_rect, false, video_settings.scanlines, &eff_src_rect, rotated, InterlaceField);
    }
   }
}

// FIXME: JoyGunTranslate is kind of sloppy, not entirely thread safe, though the consequences in practice should be negligible...
static struct
{
 float mul;
 float sub;
} volatile JoyGunTranslate[2] = { { 0, 0 }, { 0, 0 } };

void BlitScreen(MDFN_Surface *msurface, const MDFN_Rect *DisplayRect, const int32 *LineWidths, const int new_rotated, const int InterlaceField, const bool take_ssnapshot)
{
 //
 // Reduce CPU usage when minimized, and prevent OpenGL memory quasi-leaks on Windows(though I have the feeling there's a
 // cleaner less-racey way to prevent that memory leak problem).
 //
 {
  int wflags = SDL_GetWindowFlags(window);

  // printf("Borp %08x %u\n", wflags, Time::MonoMS());

  if(wflags & (SDL_WINDOW_HIDDEN | SDL_WINDOW_MINIMIZED))
  {
   return;
  }
 }
 //
 //
 //
 MDFN_Rect src_rect;

 if(rotated != new_rotated)
 {
  rotated = new_rotated;
  //
  if(video_settings.fullscreen)
  {
   if(MDFN_UNLIKELY(!GenerateFullscreenDestRect()))
    Video_Sync(VideoGI);
   else
    MarkNeedBBClear();
  }
  else
   Video_Sync(VideoGI);
 }

 if(vdriver != VDRIVER_OPENGL)
 {
  int ow, oh, op;
  int nw, nh, np;
  SDL_PixelFormat of, nf;

  of = *screen->format;
  ow = screen->w;
  oh = screen->h;
  op = screen->pitch;
  if(!(screen = SDL_GetWindowSurface(window)))
   throw MDFN_Error(0, _("SDL_GetWindowSurface() failed: %s"), SDL_GetError());

  nf = *screen->format;
  nw = screen->w;
  nh = screen->h;
  np = screen->pitch;

  if((of.format != nf.format) || (of.BitsPerPixel != nf.BitsPerPixel) || (of.BytesPerPixel != nf.BytesPerPixel) ||
     (of.Rmask != nf.Rmask) || (of.Gmask != nf.Gmask) || (of.Bmask != nf.Bmask) || (of.Amask != nf.Amask) ||
     (ow != nw) || (oh != nh) || (op != np))
  {
   Video_Sync(VideoGI);
  }
 }

#if 1
 {
  int sub[2] = { 0, 0 };
  SDL_DisplayMode mode;

  if(!(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN))
   SDL_GetWindowPosition(window, &sub[0], &sub[1]);

  sub[0] += screen_dest_rect.x;
  sub[1] += screen_dest_rect.y;

  if(SDL_GetCurrentDisplayMode(SDL_GetWindowDisplayIndex(window), &mode) >= 0)
  {
   JoyGunTranslate[0].mul = (float)mode.w / screen_dest_rect.w / 32768.0;
   JoyGunTranslate[0].sub = (float)sub[0] / screen_dest_rect.w;

   JoyGunTranslate[1].mul = (float)mode.h / screen_dest_rect.h / 32768.0;
   JoyGunTranslate[1].sub = (float)sub[1] / screen_dest_rect.h;
  }
 }
#endif

 if(NeedClear)
 {
  uint32 ct = Time::MonoMS();

  if((ct - LastBBClearTime) >= 30)
  {
   LastBBClearTime = ct;
   NeedClear--;
  }

  if(vdriver == VDRIVER_OPENGL)
   ogl_blitter->ClearBackBuffer();
  else
  {
   SDL_FillRect(screen, NULL, 0);
   NeedClear = 0;
  }
 }

 msurface->SetFormat(pf_normal, true);

 src_rect.x = DisplayRect->x;
 src_rect.w = DisplayRect->w;
 src_rect.y = DisplayRect->y;
 src_rect.h = DisplayRect->h;

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

    if(rotated == MDFN_ROTATE90)
    {
     sub_dest_rect.x = screen_dest_rect.x + (last_y - src_rect.y) * screen_dest_rect.w / src_rect.h;
     sub_dest_rect.y = screen_dest_rect.y;

     sub_dest_rect.w = sub_src_rect.h * screen_dest_rect.w / src_rect.h;
     sub_dest_rect.h = screen_dest_rect.h;
     //printf("sdr.x=%f, sdr.w=%f\n", (double)screen_dest_rect.x + (double)(last_y - src_rect.y) * screen_dest_rect.w / src_rect.h, (double)sub_src_rect.h * screen_dest_rect.w / src_rect.h);
    }
    else if(rotated == MDFN_ROTATE270)
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
   std::unique_ptr<MDFN_Surface> ib;
   MDFN_Rect sr;
   MDFN_Rect tr;

   sr = screen_dest_rect;
   if(sr.x < 0) { sr.w += sr.x; sr.x = 0; }
   if(sr.y < 0) { sr.h += sr.y; sr.y = 0; }
   if(sr.w < 0) sr.w = 0;
   if(sr.h < 0) sr.h = 0;
   if(sr.w > screen_w) sr.w = screen_w;
   if(sr.h > screen_h) sr.h = screen_h;

   ib.reset(new MDFN_Surface(NULL, sr.w, sr.h, sr.w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as)));

   if(ogl_blitter)
    ogl_blitter->ReadPixels(ib.get(), &sr);
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
   MDFNI_SaveSnapshot(ib.get(), &tr, NULL);
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  }
 }


 Debugger_MT_DrawToScreen(MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as), screen_w, screen_h);

#if 0
 if(CKGUI_IsActive())
 {
  if(!CKGUISurface)
  {
   CKGUIRect.w = screen_w;
   CKGUIRect.h = screen_h;

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

 try
 {
  DrawSaveStates(screen_w, screen_h, exs, eys, real_rs, real_gs, real_bs, real_as);

  CheatIF_MT_Draw(MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as), screen_w, screen_h);
  Netplay_MT_Draw(MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as), screen_w, screen_h);

  if(Help_IsActive())
  {
   if(!HelpSurface)
   {
    HelpRect.x = 0;
    HelpRect.y = 0;
    HelpRect.w = std::min<int>(512, screen_w);
    HelpRect.h = std::min<int>(408, screen_h);

    HelpSurface = new MDFN_Surface(NULL, 512, 408, 512, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, real_rs, real_gs, real_bs, real_as));
    Help_Draw(HelpSurface, HelpRect);
   }

   MDFN_Rect zederect;
   int32 sfx = screen_w / HelpRect.w;
   int32 sfy = screen_h / HelpRect.h;

   if(sfy > sfx)
    sfy = sfx + 1;

   if(sfx > sfy)
    sfx = sfy + 1;

   zederect.w = HelpRect.w * sfx;
   zederect.h = HelpRect.h * sfy;

   zederect.x = (screen_w - zederect.w) / 2;
   zederect.y = (screen_h - zederect.h) / 2;

   BlitRaw(HelpSurface, &HelpRect, &zederect, 0);
  }
  else if(HelpSurface)
  {
   delete HelpSurface;
   HelpSurface = NULL;
  }
 }
 catch(std::exception& e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }

 BlitInternalMessage();

 //
 {
  int32 p[4] = { 0, 0, screen_w, screen_h };
  MDFN_Rect cr;

  // When using soft-SDL, position the FPS display so we won't incur a potentially large(on older/slower hardware) penalty due
  // to a requisite backbuffer clear(we could avoid this with some sort of dirty-rects system so only parts of the backbuffer are cleared,
  // but that gets awfully complicated and prone to bugs when dealing with double/triple-buffered video...).
  //
  // std::max so we don't position it offscreen if the user has selected xscalefs or yscalefs values that are too large.
  if(vdriver != VDRIVER_OPENGL)
  {
   p[0] = std::max<int32>(std::min<int32>(screen_w, screen_dest_rect.x), 0);
   p[1] = std::max<int32>(std::min<int32>(screen_h, screen_dest_rect.y), 0);

   p[2] = std::max<int32>(std::min<int32>(screen_w, screen_dest_rect.x + screen_dest_rect.w), 0);
   p[3] = std::max<int32>(std::min<int32>(screen_w, screen_dest_rect.y + screen_dest_rect.y), 0);
  }

  cr = { p[0], p[1], p[2] - p[0], p[3] - p[1] };
  FPS_DrawToScreen(real_rs, real_gs, real_bs, real_as, cr, std::min(screen_w, screen_h));
 }
 //

 if(vdriver != VDRIVER_OPENGL)
  SDL_UpdateWindowSurface(window);
 else
 {
  PumpWrap();
  SDL_GL_SwapWindow(window);
  // Don't insert any GL calls after SDL_GL_SwapWindow() here that could block until the swap completes.
  //ogl_blitter->HardSync();
 }
}

void Video_Exposed(void)
{
 MarkNeedBBClear();
}

void Video_PtoV(const int in_x, const int in_y, float* out_x, float* out_y)
{
 assert(VideoGI);
 //
 int32 tmp_x = in_x - screen_dest_rect.x;
 int32 tmp_y = in_y - screen_dest_rect.y;
 int32 div_x = screen_dest_rect.w;
 int32 div_y = screen_dest_rect.h;
/*
 switch(rotated)
 {
  case MDFN_ROTATE0:
	break;

  case MDFN_ROTATE90:
	std::swap(tmp_x, tmp_y);
	std::swap(div_x, div_y);
	tmp_x = screen_dest_rect.h - 1 - tmp_x;
	break;

  case MDFN_ROTATE270:
	std::swap(tmp_x, tmp_y);
	std::swap(div_x, div_y);
	tmp_y = screen_dest_rect.w - 1 - tmp_y;
	break;
 }
*/
 *out_x = (float)tmp_x / div_x;
 *out_y = (float)tmp_y / div_y;
}

float Video_PtoV_J(const int32 inv, const bool axis, const bool scr_scale)
{
 assert(VideoGI);
 assert(window);

 if(!scr_scale)
  return 0.5 + (inv / 32768.0 - 0.5) * std::max<int32>(VideoGI->nominal_width, VideoGI->nominal_height) / (axis ? VideoGI->nominal_height : VideoGI->nominal_width);
 else
  return inv * JoyGunTranslate[axis].mul - JoyGunTranslate[axis].sub;
}
