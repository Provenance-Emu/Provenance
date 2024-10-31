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
#include <SDL_revision.h>

#ifdef WIN32
 #include <mednafen/win32-common.h>
#else
 #include <unistd.h>
#endif

#include <fcntl.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/stat.h>
#include <trio/trio.h>
#include <locale.h>

#ifdef HAVE_GETPWUID
#include <pwd.h>
#endif

#ifdef HAVE_ICONV
#include <iconv.h>
#endif

#include <atomic>

#include "input.h"
#include "Joystick.h"
#include "video.h"
#include "opengl.h"
#include "shader.h"
#include "sound.h"
#include "netplay.h"
#include "cheat.h"
#include "fps.h"
#include "debugger.h"
#include "help.h"
#include "video-state.h"
#include "remote.h"
#include "ers.h"
#include "rmdui.h"
#include <mednafen/qtrecord.h>
#include <mednafen/tests.h>
#include <mednafen/testsexp.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/string/string.h>
#include <mednafen/file.h>

static bool SuppressErrorPopups;	// Set from env variable "MEDNAFEN_NOPOPUPS"

static int StateFuzzTest = false;
static int StateSLSTest = false;
static int StateRCTest = false;	// Rewind consistency
#if 1
static int StatePCTest = false;	// Power(toggle) consistency
#endif
static WMInputBehavior NeededWMInputBehavior = { false, false, false, false };
static bool NeededWMInputBehavior_Dirty = false;

bool MDFNDHaveFocus;
static bool RemoteOn = FALSE;
bool pending_save_state, pending_snapshot, pending_ssnapshot, pending_save_movie;
static uint64 MainThreadID = 0;
static bool ffnosound;

static const MDFNSetting_EnumList SDriver_List[] =
{
 { "default", -1, "Default", gettext_noop("Selects the default sound driver.") },

 { "alsa", -1, "ALSA", gettext_noop("The default for Linux(if available).") },
 { "openbsd", -1, "OpenBSD Audio", gettext_noop("The default for OpenBSD.") },
 { "oss", -1, "Open Sound System", gettext_noop("The default for non-Linux UN*X/POSIX/BSD(other than OpenBSD) systems, or anywhere ALSA is unavailable. If the ALSA driver gives you problems, you can try using this one instead.\n\nIf you are using OSSv4 or newer, you should edit \"/usr/lib/oss/conf/osscore.conf\", uncomment the max_intrate= line, and change the value from 100(default) to 1000(or higher if you know what you're doing), and restart OSS. Otherwise, performance will be poor, and the sound buffer size in Mednafen will be orders of magnitude larger than specified.\n\nIf the sound buffer size is still excessively larger than what is specified via the \"sound.buffer_time\" setting, you can try setting \"sound.period_time\" to 2666, and as a last resort, 5333, to work around a design flaw/limitation/choice in the OSS API and OSS implementation.") },

 { "wasapish", -1, "WASAPI(Shared Mode)", gettext_noop("The default when it's available(running on Microsoft Windows Vista and newer).") },

 { "dsound", -1, "DirectSound", gettext_noop("The default for Microsoft Windows XP and older.") },

 { "wasapi", -1, "WASAPI(Exclusive Mode)", gettext_noop("Experimental exclusive-mode WASAPI driver, usable on Windows Vista and newer.  Use it for lower-latency sound.  May not work properly on all sound cards.") },

 { "sdl", -1, "Simple Directmedia Layer", gettext_noop("This driver is not recommended, but it serves as a backup driver if the others aren't available. Its performance is generally sub-par, requiring higher latency or faster CPUs/SMP for glitch-free playback, except where the OS provides a sound callback API itself, such as with Mac OS X and BeOS.") },

 { "jack", -1, "JACK", gettext_noop("The latency reported during startup is for the local sound buffer only and does not include server-side latency.  Please note that video card drivers(in the kernel or X), and hardware-accelerated OpenGL, may interfere with jackd's ability to effectively run with realtime response.") },

 { "dummy", -1 },

 { NULL, 0 },
};

static const MDFNSetting_EnumList FontSize_List[] =
{
 { "5x7",	MDFN_FONT_5x7, gettext_noop("5x7") },
 { "6x9",	MDFN_FONT_6x9, gettext_noop("6x9") },
 { "6x12",	MDFN_FONT_6x12, gettext_noop("6x12") },
#ifdef WANT_INTERNAL_CJK
 { "6x13",	MDFN_FONT_6x13_12x13, gettext_noop("6x13.  CJK support.") },
 { "9x18",	MDFN_FONT_9x18_18x18, gettext_noop("9x18;  CJK support.") },
#else
 { "6x13",	MDFN_FONT_6x13_12x13, gettext_noop("6x13.") },
 { "9x18",	MDFN_FONT_9x18_18x18, gettext_noop("9x18.") },
#endif
 // Backwards compat:
 { "xsmall", 	MDFN_FONT_5x7 }, // 4x5 font was removed.
 { "small",	MDFN_FONT_5x7 },
 { "medium",	MDFN_FONT_6x13_12x13 },
 { "large",	MDFN_FONT_9x18_18x18 },

 { "0",		MDFN_FONT_9x18_18x18 },
 { "1",		MDFN_FONT_5x7 },

 { NULL, 0 },
};

static const MDFNSetting_EnumList FPSPos_List[] =
{
 { "upper_left", FPSPOS_UPPER_LEFT, gettext_noop("Upper left.") },
 { "upper_right", FPSPOS_UPPER_RIGHT, gettext_noop("Upper right.") },
 { "upper_center", FPSPOS_UPPER_CENTER, gettext_noop("Upper center.") },
 { "center", FPSPOS_CENTER, gettext_noop("Center.") },

 { NULL, 0 },
};

static std::vector <MDFNSetting> NeoDriverSettings;
static const MDFNSetting DriverSettings[] =
{
  { "input.joystick.global_focus", MDFNSF_NOFLAGS, gettext_noop("Update physical joystick(s) internal state in Mednafen even when Mednafen lacks OS focus."), NULL, MDFNST_BOOL, "1" },
  { "input.joystick.axis_threshold", MDFNSF_NOFLAGS, gettext_noop("Analog axis binary press detection threshold."), gettext_noop("Threshold for detecting a digital-like \"button\" press on analog axis, in percent."), MDFNST_FLOAT, "75", "0", "100" },
  { "input.autofirefreq", MDFNSF_NOFLAGS, gettext_noop("Auto-fire frequency."), gettext_noop("Auto-fire frequency = GameSystemFrameRateHz / (value + 1)"), MDFNST_UINT, "3", "0", "1000" },
  { "input.ckdelay", MDFNSF_NOFLAGS, gettext_noop("Dangerous key action delay."), gettext_noop("The length of time, in milliseconds, that a button/key corresponding to a \"dangerous\" command like power, reset, exit, etc. must be pressed before the command is executed."), MDFNST_UINT, "0", "0", "99999" },

  { "netplay.host", MDFNSF_NOFLAGS, gettext_noop("Server hostname."), NULL, MDFNST_STRING, "netplay.fobby.net" },
  { "netplay.port", MDFNSF_NOFLAGS, gettext_noop("Server port."), NULL, MDFNST_UINT, "4046", "1", "65535" },
  { "netplay.console.font", MDFNSF_NOFLAGS, gettext_noop("Font for netplay chat console."), NULL, MDFNST_ENUM, "9x18", NULL, NULL, NULL, NULL, FontSize_List },
  { "netplay.console.scale", MDFNSF_NOFLAGS, gettext_noop("Netplay chat console text scale factor."), gettext_noop("A value of 0 enables auto-scaling."), MDFNST_UINT, "1", "0", "16" },
  { "netplay.console.lines", MDFNSF_NOFLAGS, gettext_noop("Height of chat console, in lines."), NULL, MDFNST_UINT, "5", "5", "64" },

  { "video.frameskip", MDFNSF_NOFLAGS, gettext_noop("Enable frameskip during emulation rendering."), 
					gettext_noop("Disable for rendering code performance testing."), MDFNST_BOOL, "1" },

  { "video.blit_timesync", MDFNSF_NOFLAGS, gettext_noop("Enable time synchronization(waiting) for frame blitting."),
					gettext_noop("Disable to reduce latency, at the cost of potentially increased video \"juddering\", with the maximum reduction in latency being about 1 video frame's time.\nWill work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU."),
					MDFNST_BOOL, "1" },

  { "ffspeed", MDFNSF_NOFLAGS, gettext_noop("Fast-forwarding speed multiplier."), NULL, MDFNST_FLOAT, "4", "0.25", "15" },
  { "fftoggle", MDFNSF_NOFLAGS, gettext_noop("Treat the fast-forward button as a toggle."), NULL, MDFNST_BOOL, "0" },
  { "ffnosound", MDFNSF_NOFLAGS, gettext_noop("Silence sound output when fast-forwarding."), NULL, MDFNST_BOOL, "0" },

  { "sfspeed", MDFNSF_NOFLAGS, gettext_noop("SLOW-forwarding speed multiplier."), NULL, MDFNST_FLOAT, "0.75", "0.25", "15" },
  { "sftoggle", MDFNSF_NOFLAGS, gettext_noop("Treat the SLOW-forward button as a toggle."), NULL, MDFNST_BOOL, "0" },

  { "nothrottle", MDFNSF_NOFLAGS, gettext_noop("Disable speed throttling when sound is disabled."), NULL, MDFNST_BOOL, "0"},
  { "autosave", MDFNSF_NOFLAGS, gettext_noop("Automatically load/save state on game load/close."), gettext_noop("Automatically save and load save states when a game is closed or loaded, respectively."), MDFNST_BOOL, "0"},
  { "sound.driver", MDFNSF_NOFLAGS, gettext_noop("Select sound driver."), gettext_noop("The following choices are possible, sorted by preference, high to low, when \"default\" driver is used, but dependent on being compiled in."), MDFNST_ENUM, "default", NULL, NULL, NULL, NULL, SDriver_List },
  { "sound.device", MDFNSF_NOFLAGS, gettext_noop("Select sound output device."), gettext_noop("When using ALSA sound output under Linux, the \"sound.device\" setting \"default\" is Mednafen's default, IE \"hw:0\", not ALSA's \"default\". If you want to use ALSA's \"default\", use \"sexyal-literal-default\"."), MDFNST_STRING, "default", NULL, NULL },
  { "sound.volume", MDFNSF_NOFLAGS, gettext_noop("Sound volume level, in percent."), gettext_noop("Setting this volume control higher than the default of \"100\" may severely distort the sound."), MDFNST_UINT, "100", "0", "150" },
  { "sound", MDFNSF_NOFLAGS, gettext_noop("Enable sound output."), NULL, MDFNST_BOOL, "1" },
  { "sound.period_time", MDFNSF_NOFLAGS, gettext_noop("Desired period size in microseconds(μs)."), gettext_noop("Currently only affects OSS, ALSA, WASAPI(exclusive mode), and SDL output.  A value of 0 defers to the default in the driver code in SexyAL.\n\nNote: This is not the \"sound buffer size\" setting, that would be \"sound.buffer_time\"."), MDFNST_UINT,  "0", "0", "100000" },
  { "sound.buffer_time", MDFNSF_NOFLAGS, gettext_noop("Desired buffer size in milliseconds(ms)."), gettext_noop("The default value of 0 enables automatic buffer size selection."), MDFNST_UINT, "0", "0", "1000" },
  { "sound.rate", MDFNSF_NOFLAGS, gettext_noop("Specifies the sound playback rate, in sound frames per second(\"Hz\")."), NULL, MDFNST_UINT, "48000", "22050", "192000"},

  #ifdef WANT_DEBUGGER
  { "debugger.autostepmode", MDFNSF_NOFLAGS, gettext_noop("Automatically go into the debugger's step mode after a game is loaded."), NULL, MDFNST_BOOL, "0" },
  #endif

  { "osd.message_display_time", MDFNSF_NOFLAGS, gettext_noop("Length of time, in milliseconds, to display internal status and error messages"), gettext_noop("Time lengths less than 100ms are recommended against unless you understand you may miss important non-fatal error messages, and that the input configuration process may become unusable."), MDFNST_UINT, "2500", "0", "15000" },
  { "osd.state_display_time", MDFNSF_NOFLAGS, gettext_noop("Length of time, in milliseconds, to display the save state or the movie selector after selecting a state or movie."),  NULL, MDFNST_UINT, "2000", "0", "15000" },
  { "osd.alpha_blend", MDFNSF_NOFLAGS, gettext_noop("Enable alpha blending for OSD elements."), NULL, MDFNST_BOOL, "1" },

  { "fps.autoenable", MDFNSF_NOFLAGS, gettext_noop("Automatically enable FPS display on startup."), NULL, MDFNST_BOOL, "0" },
  { "fps.position", MDFNSF_NOFLAGS, gettext_noop("FPS display position."), NULL, MDFNST_ENUM, "upper_left", NULL, NULL, NULL, NULL, FPSPos_List },
  { "fps.scale", MDFNSF_NOFLAGS, gettext_noop("FPS display scale factor."), gettext_noop("A value of 0 enables auto-scaling."), MDFNST_UINT, "1", "0", "32" },
  { "fps.font", MDFNSF_NOFLAGS, gettext_noop("FPS display font."), NULL, MDFNST_ENUM, "5x7", NULL, NULL, NULL, NULL, FontSize_List },
  { "fps.textcolor", MDFNSF_NOFLAGS, gettext_noop("FPS display text color."), gettext_noop("0xAARRGGBB"), MDFNST_UINT, "0xFFFFFFFF", "0x00000000", "0xFFFFFFFF" },
  { "fps.bgcolor", MDFNSF_NOFLAGS, gettext_noop("FPS display background color."), gettext_noop("0xAARRGGBB"), MDFNST_UINT, "0x80000000", "0x00000000", "0xFFFFFFFF" },

  { "srwautoenable", MDFNSF_SUPPRESS_DOC, gettext_noop("DO NOT USE UNLESS YOU'RE A SPACE GOAT"/*"Automatically enable state rewinding functionality on game load."*/), gettext_noop("Use this setting with caution, as save state rewinding can have widely variable memory and CPU usage requirements among different games and different emulated systems."), MDFNST_BOOL, "0" },

  { "affinity.emu", MDFNSF_NOFLAGS, gettext_noop("Main emulation thread CPU affinity mask."), gettext_noop("Set to 0 to disable changing affinity."), MDFNST_UINT, "0", "0x0000000000000000", "0xFFFFFFFFFFFFFFFF" },
  { "affinity.video", MDFNSF_NOFLAGS, gettext_noop("Video blitting thread CPU affinity mask."), gettext_noop("Set to 0 to disable changing affinity."), MDFNST_UINT, "0", "0x0000000000000000", "0xFFFFFFFFFFFFFFFF" },
};

void BuildSystemSetting(MDFNSetting *setting, const char *system_name, const char *name, const char *description, const char *description_extra, MDFNSettingType type, 
	const char *default_value, const char *minimum, const char *maximum,
	bool (*validate_func)(const char *name, const char *value), void (*ChangeNotification)(const char *name), 
        const MDFNSetting_EnumList *enum_list, uint32 extra_flags)
{
 char setting_name[256];

 memset(setting, 0, sizeof(MDFNSetting));

 trio_snprintf(setting_name, 256, "%s.%s", system_name, name);

 setting->name = strdup(setting_name);
 setting->flags = MDFNSF_COMMON_TEMPLATE | extra_flags;
 setting->description = description;
 setting->description_extra = description_extra;
 setting->type = type;
 setting->default_value = default_value;
 setting->minimum = minimum;
 setting->maximum = maximum;
 setting->validate_func = validate_func;
 setting->ChangeNotification = ChangeNotification;
 setting->enum_list = enum_list;
}

void MakeDebugSettings(std::vector <MDFNSetting> &settings)
{
 #ifdef WANT_DEBUGGER
 for(unsigned int i = 0; i < MDFNSystems.size(); i++)
 {
  const DebuggerInfoStruct *dbg = MDFNSystems[i]->Debugger;
  MDFNSetting setting;
  const char *sysname = MDFNSystems[i]->shortname;

  if(!dbg)
   continue;
  //
  const uint32 extra_flags = dbg->SuppressDoc ? MDFNSF_SUPPRESS_DOC : 0;

  BuildSystemSetting(&setting, sysname, "debugger.disfontsize", gettext_noop("Disassembly font size."), gettext_noop("Note: Setting the font size to larger than the default may cause text overlap in the debugger."), MDFNST_ENUM, "5x7", NULL, NULL, NULL, NULL, FontSize_List, extra_flags);
  settings.push_back(setting);

  BuildSystemSetting(&setting, sysname, "debugger.memcharenc", gettext_noop("Character encoding for the debugger's memory editor."), NULL, MDFNST_STRING, dbg->DefaultCharEnc, NULL, NULL, NULL, NULL, NULL, extra_flags);
  settings.push_back(setting);
 }
 #endif
}

static MThreading::Thread* GameThread;

static struct
{
 std::unique_ptr<MDFN_Surface> surface = nullptr;
 MDFN_Rect rect;
 std::unique_ptr<int32[]> lw = nullptr;
 int field = -1;
} SoftFB[2];

static bool SoftFB_BackBuffer = false;

static std::atomic_int VTReady;
static unsigned VTRotated = 0;
static bool VTSSnapshot = false;
static MThreading::Sem* VTWakeupSem;
static MThreading::Mutex *VTMutex = NULL, *EVMutex = NULL;
static MThreading::Mutex *StdoutMutex = NULL;

//
//
//
//
//

static bool sc_blit_timesync;

static char *soundrecfn=0;	/* File name of sound recording. */

static char *qtrecfn = NULL;

static std::string DrBaseDirectory;

MDFNGI *CurGame=NULL;


#ifdef WIN32
static std::string GetModuleFileName_UTF8(HMODULE hModule)
{
 const size_t path_size = 32767;
 std::unique_ptr<TCHAR[]> path(new TCHAR[path_size]);
 DWORD fnl;

 fnl = GetModuleFileName(hModule, path.get(), path_size);
 if(fnl == 0 || fnl == path_size)
  throw MDFN_Error(0, "GetModuleFileName() error.");

 return Win32Common::T_to_UTF8(path.get(), nullptr, true);
}

// returns 1 if redirected, 0 if not redirected due to error, -1 if not redirected due to env variable
static int RedirectSTDxxx(void)
{
 const char* env_noredir = getenv("MEDNAFEN_NOSTDREDIR");

 if(env_noredir && atoi(env_noredir))
  return -1;
 //
 //
 //
 std::string path;
 size_t catpos;	// Meow meow.

 path = GetModuleFileName_UTF8(NULL);
 if((catpos = path.find_last_of('\\')) != std::string::npos)
  path.resize(catpos + 1);

 const auto stdout_path = Win32Common::UTF8_to_T(path + "stdout.txt", nullptr, true);
 const auto stderr_path = Win32Common::UTF8_to_T(path + "stderr.txt", nullptr, true);
 int new_stdout = -1;
 int new_stderr = -1;

 new_stdout = _topen((const TCHAR*)stdout_path.c_str(), O_WRONLY | O_CREAT | O_TRUNC, _S_IREAD | _S_IWRITE);
 new_stderr = _topen((const TCHAR*)stderr_path.c_str(), O_WRONLY | O_CREAT | O_TRUNC, _S_IREAD | _S_IWRITE);

 // Not sure if we need to handle stdin here...

 if(new_stdout != -1 && new_stderr != -1)
 {
  fflush(stdout);
  fflush(stderr);

  dup2(new_stdout, fileno(stdout));
  dup2(new_stderr, fileno(stderr));

  close(new_stdout);
  close(new_stderr);

  return true;
 }
 else
 {
  if(new_stdout != -1)
   close(new_stdout);

  if(new_stderr != -1)
   close(new_stderr);

  return false;
 }
}
/*
static BOOL CALLBACK ETWCB(HWND hwnd, LPARAM lParam)
{
 char tmp[256] = { 0 };
 const char* dark_magic = "Spider spider on your bed, spider spider on your head~"; //EE4Kt9r8PTdyOJDiYFErTH";

 SetWindowTextA(hwnd, dark_magic);
 GetConsoleTitleA(tmp, sizeof(tmp) - 1);
 printf("Title: %s\n", tmp);
 if(strstr(tmp, dark_magic))
 {
  *(HWND*)lParam = hwnd;
  return FALSE;
 }
 return TRUE;
}
*/
static void HandleConsoleMadness(void)
{
 decltype(GetConsoleWindow)* p_GetConsoleWindow = (decltype(GetConsoleWindow)*)GetProcAddress(GetModuleHandleA("kernel32.dll"), "GetConsoleWindow");

 if(!p_GetConsoleWindow)
  return;
 //
 //
 HWND cwin = p_GetConsoleWindow();

 if(cwin)
 {
  DWORD cwin_pid = 0;

  GetWindowThreadProcessId(cwin, &cwin_pid);
  if(GetCurrentProcessId() == cwin_pid)
  {
   if(RemoteOn || RedirectSTDxxx())
   {
    // Just hide the console window, don't call FreeConsole(), as Windows 10 does something weird that feels
    // like it's asynchronously screwing with the stdout and stderr file descriptors/handles.
    ShowWindow(cwin, SW_HIDE);
   }
  }
 }
 else if(!RedirectSTDxxx())
 {
  if(AllocConsole())
  {
   HANDLE hand_stdout, hand_stderr;

   hand_stdout = GetStdHandle(STD_OUTPUT_HANDLE);
   hand_stderr = GetStdHandle(STD_ERROR_HANDLE);

   if(hand_stdout && hand_stderr)
   {
    int new_stdout = _open_osfhandle((intptr_t)hand_stdout, _O_WRONLY);
    int new_stderr = _open_osfhandle((intptr_t)hand_stderr, _O_WRONLY);

    if(new_stdout != -1 && new_stderr != -1)
    {
     fflush(stdout);
     fflush(stderr);

     dup2(new_stdout, fileno(stdout));
     dup2(new_stderr, fileno(stderr));

     close(new_stdout);
     close(new_stderr);
    }
   }
  }
 }
}
#endif

void Mednafen::MDFND_OutputNotice(MDFN_NoticeType t, const char* s) noexcept
{
 bool did_message_box = false;

 if(RemoteOn)
 {
  if(t == MDFN_NOTICE_ERROR)
   Remote_SendErrorMessage(s);
  else if(t == MDFN_NOTICE_WARNING)
   Remote_SendWarningMessage(s);
 }
 else if(t != MDFN_NOTICE_STATUS)
 {
  if(StdoutMutex)
   MThreading::Mutex_Lock(StdoutMutex);
 
  puts(s);
  fflush(stdout);

  if(StdoutMutex)
   MThreading::Mutex_Unlock(StdoutMutex);
  //
  //
  //
  if(MThreading::Thread_ID() == MainThreadID && !SuppressErrorPopups)
  {
   const char* title = "";

   if(t == MDFN_NOTICE_ERROR)
    title = _("Mednafen(" MEDNAFEN_VERSION ") Error");
   else
    title = _("Mednafen(" MEDNAFEN_VERSION ") Warning");

   did_message_box = Video_ErrorPopup((t != MDFN_NOTICE_ERROR), title, s);
  }
 }
 //
 //
 //
 if(!did_message_box)
 {
  char* ds = strdup(s);

  if(!ds)
  {

  }
  else
  {
   SendCEvent(CEVT_OUTPUT_NOTICE, ds, nullptr, (uint16)t);
  }
 }
}

void Mednafen::MDFND_OutputInfo(const char *s) noexcept
{
 if(RemoteOn)
  Remote_SendInfoMessage(s);
 else
 {
  if(StdoutMutex)
   MThreading::Mutex_Lock(StdoutMutex);

  fputs(s,stdout);
  fflush(stdout);

  if(StdoutMutex)
   MThreading::Mutex_Unlock(StdoutMutex);
 }
}

static bool CreateDataDirs(void)
{
 try
 {
  static const struct
  {
   const char* sname_path;
   const char* sname_fname;
  } subs[] =
  {
   // The directories referenced by these settings will be automatically
   // created as needed internally in core Mednafen, but we should still
   // create them preemptively, as long as the filesys.fname_* settings are
   // still at their default values:
   { "filesys.path_snap", "filesys.fname_snap" },
   { "filesys.path_sav", "filesys.fname_sav" },
   { "filesys.path_savbackup", "filesys.fname_savbackup" },
   { "filesys.path_state", "filesys.fname_state" },
   { "filesys.path_movie", "filesys.fname_movie" },

   // These will not be automatically created internally:
   { "filesys.path_cheat", nullptr },
   { "filesys.path_palette", nullptr },
   { "filesys.path_pgconfig", nullptr },
   { "filesys.path_firmware", nullptr },
  };

  for(auto const& s : subs)
  {
   if(s.sname_fname && MDFN_GetSettingS(s.sname_fname) != MDFNI_GetSettingDefault(s.sname_fname))
    continue;
   //
   std::string dir = MDFN_GetSettingS(s.sname_path);

   if(!NVFS.is_absolute_path(dir))
    dir = DrBaseDirectory + PSS + dir;

   NVFS.create_missing_dirs(dir + PSS);
  }
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("Error creating data directories: %s\n"), e.what());
  return false;
 }
 return true;
}

static bool volatile SignalSafeExitWanted = false;
#if defined(HAVE_SIGNAL) || defined(HAVE_SIGACTION)
static const char *SiginfoString = NULL;
typedef struct
{
 int number;
 const char *name;
 const char *message;
 const char *translated;	// Needed since gettext() can potentially deadlock when used in a signal handler.
 const bool SafeTryExit;
} SignalInfo;

static SignalInfo SignalDefs[] =
{
 #ifdef SIGINT
 { SIGINT, "SIGINT", gettext_noop("How DARE you interrupt me!\n"), NULL, TRUE },
 #endif

 #ifdef SIGTERM
 { SIGTERM, "SIGTERM", gettext_noop("MUST TERMINATE ALL HUMANS\n"), NULL, TRUE },
 #endif

 #ifdef SIGHUP
 { SIGHUP, "SIGHUP", gettext_noop("Reach out and hang-up on someone.\n"), NULL, FALSE },
 #endif

 #ifdef SIGSEGV
 { SIGSEGV, "SIGSEGV", gettext_noop("Iyeeeeeeeee!!!  A segmentation fault has occurred.  Have a fluffy day.\n"), NULL, FALSE },
 #endif

 #ifdef SIGPIPE
 { SIGPIPE, "SIGPIPE", gettext_noop("The pipe has broken!  Better watch out for floods...\n"), NULL, FALSE },
 #endif

 #if defined(SIGBUS) && SIGBUS != SIGSEGV
 /* SIGBUS can == SIGSEGV on some platforms */
 { SIGBUS, "SIGBUS", gettext_noop("I told you to be nice to the driver.\n"), NULL, FALSE },
 #endif

 #ifdef SIGFPE
 { SIGFPE, "SIGFPE", gettext_noop("Those darn floating points.  Ne'er know when they'll bite!\n"), NULL, FALSE },
 #endif

 #ifdef SIGALRM
 { SIGALRM, "SIGALRM", gettext_noop("Don't throw your clock at the meowing cats!\n"), NULL, TRUE },
 #endif

 #ifdef SIGABRT
 { SIGABRT, "SIGABRT", gettext_noop("Abort, Retry, Ignore, Fail?\n"), NULL, FALSE },
 #endif
 
 #ifdef SIGUSR1
 { SIGUSR1, "SIGUSR1", gettext_noop("Killing your processes is not nice.\n"), NULL, TRUE },
 #endif

 #ifdef SIGUSR2
 { SIGUSR2, "SIGUSR2", gettext_noop("Killing your processes is not nice.\n"), NULL, TRUE },
 #endif
};

static volatile int SignalSTDOUT;

static void SetSignals(void (*t)(int))
{
 SignalSTDOUT = fileno(stdout);

 SiginfoString = _("\nSignal has been caught and dealt with: ");
 for(unsigned int x = 0; x < sizeof(SignalDefs) / sizeof(SignalInfo); x++)
 {
  if(!SignalDefs[x].translated)
   SignalDefs[x].translated = _(SignalDefs[x].message);

  #ifdef HAVE_SIGACTION
  struct sigaction act;

  memset(&act, 0, sizeof(struct sigaction));

  act.sa_handler = t;
  act.sa_flags = SA_RESTART;

  sigaction(SignalDefs[x].number, &act, NULL);
  #else
  signal(SignalDefs[x].number, t);

  //#ifdef HAVE_SIGINTERRUPT
  //siginterrupt(SignalDefs[x].number, 0);
  //#endif

  #endif
 }
}

static void SignalPutString(const char *string)
{
 size_t count = 0;

 while(string[count]) { count++; }

 write(SignalSTDOUT, string, count);
}

static void CloseStuff(int signum)
{
	const int save_errno = errno;
	const char *name = "unknown";
	const char *translated = NULL;
	bool safetryexit = false;

	for(unsigned int x = 0; x < sizeof(SignalDefs) / sizeof(SignalInfo); x++)
	{
	 if(SignalDefs[x].number == signum)
	 {
	  name = SignalDefs[x].name;
	  translated = SignalDefs[x].translated;
	  safetryexit = SignalDefs[x].SafeTryExit;
	  break;
	 }
	}

	SignalPutString(SiginfoString);
	SignalPutString(name);
        SignalPutString("\n");
	SignalPutString(translated);

	if(safetryexit)
	{
         SignalSafeExitWanted = safetryexit;
	 errno = save_errno;
         return;
	}

	_exit(1);
}

static void InstallSignalHandlers(void)
{
 SetSignals(CloseStuff);
}

static void RemoveSignalHandlers(void)
{
 SetSignals(SIG_IGN);
}

#else
static void InstallSignalHandlers(void) { }
static void RemoveSignalHandlers(void) { }
#endif

//
//
//

//
//
//
#include <mednafen/cdrom/CDInterface.h>
static void CDTest(const char* path)
{
 try
 {
  CDInterface* cds[2];
  CDUtility::TOC toc[2];
  const uint64 affinity = 0;

  cds[0] = CDInterface::Open(&NVFS, path, false, affinity);
  cds[1] = CDInterface::Open(&NVFS, path, true, affinity);

  for(unsigned i = 0; i < 2; i++)
   cds[0]->ReadTOC(&toc[i]);

  assert(!memcmp(&toc[0], &toc[1], sizeof(CDUtility::TOC)));

  srand(0xDEADBEEF);

  for(int32 lba = -150; lba < (int32)toc[0].tracks[100].lba + 5*60*75; lba++)
  {
   uint8 secbuf[2][2352 + 96];
   uint8 pwobuf[2][96];

   for(unsigned i = 0; i < 2; i++)
   {
    for(unsigned sbj = 0; sbj < 2352 + 96; sbj++)
     secbuf[i][sbj] = rand() >> 8;

    for(unsigned sbj = 0; sbj < 96; sbj++)
     pwobuf[i][sbj] = rand() >> 8;

    cds[i]->ReadRawSector(secbuf[i], lba);
    cds[i]->ReadRawSectorPWOnly(pwobuf[i], lba, true);

    for(unsigned p = 0; p < 96; p++)
     assert(secbuf[i][2352 + p] == pwobuf[i][p]);
   }
   assert(!memcmp(secbuf[0], secbuf[1], 2352 + 96));
   assert(!memcmp(pwobuf[0], pwobuf[1], 96));

   uint8 subq[12];
   CDUtility::subq_deinterleave(pwobuf[0], subq);
   if(CDUtility::subq_check_checksum(subq))
   {
    /*if(lba == 0 || lba == 1)
    {
     for(unsigned i = 0; i < 12; i++)
      printf("0x%02x ", subq[i]);
     printf("\n");
    }*/
   }
   else
    printf("SubQ checksum error at lba=%d\n", lba);
  }
 }
 catch(std::exception& e)
 {
  printf("%s\n", e.what());
  abort();
 }

 printf("CDTest Done.\n");
}
//
//
//

static int DoArgs_SetSetting(const char *name, const char *value)
{
 return MDFNI_SetSetting(name, value);
}

static MDFN_COLD void PrintConfigMacros(void)
{
 #define MACROSTR2(n,x) { const char t[] = #x; if(!strcmp(n, t)) printf("#undef %s\n", n); else printf("%s: %s\n", n, t); }
 #define MACROSTR(x) MACROSTR2(#x, x)
 //
 printf("\n");
 MACROSTR(ARCH_X86)
 MACROSTR(ARCH_X86_32)
 MACROSTR(ARCH_X86_64)
 MACROSTR(ARCH_X86_X32)
 MACROSTR(ARCH_POWERPC)
 MACROSTR(HAVE_NATIVE64BIT)
 MACROSTR(HAVE_COMPUTED_GOTO)
 MACROSTR(HAVE_INLINEASM)
 MACROSTR(HAVE_INLINEASM_AVX)
 MACROSTR(HAVE_MMX_INTRINSICS)
 MACROSTR(HAVE_SSE_INTRINSICS)
 MACROSTR(HAVE_SSE2_INTRINSICS)
 MACROSTR(HAVE_NEON_INTRINSICS)
 MACROSTR(HAVE_ALTIVEC_INTRINSICS)
 printf("\n");
 MACROSTR(LSB_FIRST)
 MACROSTR(MSB_FIRST)
 MACROSTR(MDFN_IS_BIGENDIAN)
 printf("\n");
 MACROSTR(DOS)
 MACROSTR(WIN32)
 MACROSTR(_LARGEFILE64_SOURCE)
 MACROSTR(_LARGEFILE_SOURCE)
 MACROSTR(ENABLE_NLS)
#if 0
 printf("\n");
 MACROSTR(MDFN_ENABLE_DEV_BUILD)
 MACROSTR(WANT_DEBUGGER)
 MACROSTR(WANT_INTERNAL_CJK)
 MACROSTR(WANT_FANCY_SCALERS)
 printf("\n");
 MACROSTR(INLINE)
 MACROSTR(NO_INLINE)
 MACROSTR(NO_CLONE)
 MACROSTR(MDFN_FASTCALL)
 MACROSTR(MDFN_FORMATSTR(a,b,c))
 MACROSTR(MDFN_WARN_UNUSED_RESULT)
 MACROSTR(MDFN_NOWARN_UNUSED)
 MACROSTR(MDFN_RESTRICT)
 MACROSTR(MDFN_UNLIKELY(n))
 MACROSTR(MDFN_LIKELY(n))
 MACROSTR(MDFN_COLD)
 MACROSTR(MDFN_HOT)
 MACROSTR(MDFN_ASSUME_ALIGNED(p, align))
 MACROSTR(MDFN_HIDE)
 MACROSTR(PSS_STYLE)
#endif
 //
 #undef MACROSTR
 #undef MACROSTR2
}

static int netconnect = 0;
static char* loadcd = NULL;	// Deprecated
static int which_medium = -2;

static char* force_module_arg = NULL;
static bool DoArgs(int argc, char *argv[], char **filename)
{
	const std::vector<MDFNCS>* const settings = MDFNI_GetSettings();
	std::unique_ptr<ARGPSTRUCT[]> InternalArgs(new ARGPSTRUCT[1 + settings->size()]);

	for(size_t x = 0; x < settings->size(); x++)
	{
	 const MDFNCS* sit = &(*settings)[x];

	 InternalArgs[x].name = sit->name;
	 InternalArgs[x].description = sit->desc->description ? _(sit->desc->description) : NULL;
	 InternalArgs[x].var = NULL;
	 InternalArgs[x].subs = (void *)DoArgs_SetSetting;
	 InternalArgs[x].substype = SUBSTYPE_FUNCTION;
	}
	InternalArgs[settings->size()].name = NULL;
	InternalArgs[settings->size()].var = NULL;
	InternalArgs[settings->size()].subs = NULL;
	//
	//
	//
	int ShowCLHelp = 0;
	int ShowConfigMacros = 0;

	char *dsfn = NULL;
	char *dmfn = NULL;
	char *dummy_remote = NULL;
	char *exptestspath = NULL;
	char *cdtestpath = NULL;
	int swiftresamptest = 0;
	int owlresamptest = 0;
	int vidbench = 0;
	#ifdef WANT_SS_EMU
	int ss_midsync;
	#endif

        ARGPSTRUCT MDFNArgs[] = 
	{
	 { "help", _("Show help!"), &ShowCLHelp, 0, 0 },
	 { "remote", _("Enable remote mode with the specified stdout key(EXPERIMENTAL AND INCOMPLETE)."), 0, &dummy_remote, SUBSTYPE_STRING_ALLOC },

	 // -loadcd is deprecated and only still supported because it's been around for yeaaaars.
	 { "loadcd", NULL/*_("Load and boot a CD for the specified system.")*/, 0, &loadcd, SUBSTYPE_STRING_ALLOC },

	 { "which_medium", _("Start with specified disk/CD(numbered from 0) inserted."), 0, &which_medium, SUBSTYPE_INTEGER },

	 { "force_module", _("Force usage of specified emulation module."), 0, &force_module_arg, SUBSTYPE_STRING_ALLOC },

	 { "soundrecord", _("Record sound output to the specified filename in the MS WAV format."), 0,&soundrecfn, SUBSTYPE_STRING_ALLOC },
	 { "qtrecord", _("Record video and audio output to the specified filename in the QuickTime format."), 0, &qtrecfn, SUBSTYPE_STRING_ALLOC }, // TODOC: Video recording done without filtering applied.

	 { "dump_settings_def", _("Dump settings definition data to specified file."), 0, &dsfn, SUBSTYPE_STRING_ALLOC },
	 { "dump_modules_def", _("Dump modules definition data to specified file."), 0, &dmfn, SUBSTYPE_STRING_ALLOC },

         { 0, NULL, (int *)InternalArgs.get(), 0, 0},

	 { "connect", _("Connect to the remote server and start network play."), &netconnect, 0, 0 },

	 { "config_macros", NULL, &ShowConfigMacros, 0, 0 },

	 // Largefile support test(with FileStream and GZFileStream).
	 { "exptests", NULL, 0, &exptestspath, SUBSTYPE_STRING_ALLOC },

	 { "cdtest", NULL, 0, &cdtestpath, SUBSTYPE_STRING_ALLOC },

	 // Save state fuzz testing
	 { "statefuzztest", NULL, &StateFuzzTest, 0, 0 },

	 // Save state save->load->save consistency test.
	 { "stateslstest", NULL, &StateSLSTest, 0, 0 },

	 // Save state rewind consistency test.
	 { "staterctest", NULL, &StateRCTest, 0, 0 },

#if 1
	 // Save state power consistency test.
	 { "statepctest", NULL, &StatePCTest, 0, 0 },
#endif

	 // SwiftResampler test.
	 { "swiftresamptest", NULL, &swiftresamptest, 0, 0 },

	 // OwlResampler test.
	 { "owlresamptest", NULL, &owlresamptest, 0, 0 },

	 { "vidbench", NULL, &vidbench, 0, 0 },

	 #ifdef WANT_SS_EMU
	 // Quick kludge to avoid breaking frontends and scripts due to the setting being removed.
	 { "ss.midsync", NULL, 0, &ss_midsync, SUBSTYPE_INTEGER },
	 #endif

	 { 0, 0, 0, 0 }
        };

	const char *usage_string = _("Usage: %s [OPTION]... [FILE]\n");
	if(argc <= 1)
	{
	 MDFN_Notify(MDFN_NOTICE_ERROR, _("No command-line arguments specified."));
	 fprintf(stderr, "\n");
	 fprintf(stderr, usage_string, argv[0]);
	 fprintf(stderr, _("\tPlease refer to the documentation for option parameters and usage.\n\n"));
	 return false;
	}
	else
	{
	 if(!ParseArguments(argc - 1, &argv[1], MDFNArgs, filename))
	  return false;

	 if(dummy_remote)
	 {
	  free(dummy_remote);
	  dummy_remote = NULL;
	 }

	 if(ShowCLHelp)
	 {
          printf(usage_string, argv[0]);
          ShowArgumentsHelp(MDFNArgs, false);
	  printf("\n");
	  printf(_("Each setting(listed in the documentation) can also be passed as an argument by prefixing the name with a hyphen,\nand specifying the value to change the setting to as the next argument.\n\n"));
	  printf(_("For example:\n\t%s -pce.stretch aspect -pce.shader autoipsharper \"Hyper Bonk Soldier.pce\"\n\n"), argv[0]);
	  printf(_("Settings specified in this manner are automatically saved to the configuration file, hence they\ndo not need to be passed to future invocations of the Mednafen executable.\n"));
	  printf("\n");
	  return false;
	 }

	 if(ShowConfigMacros)
	 {
	  PrintConfigMacros();
	  return false;
	 }

	 if(exptestspath)
	 {
	  MDFNI_RunExpensiveTests(exptestspath);
	  free(exptestspath);
	  exptestspath = NULL;
	 }

	 if(swiftresamptest)
	  MDFNI_RunSwiftResamplerTest();

	 if(owlresamptest)
	  MDFNI_RunOwlResamplerTest();

	 if(vidbench)
	  MDFN_RunVideoBenchmarks();

	 if(cdtestpath)
	 {
	  CDTest(cdtestpath);
	  free(cdtestpath);
	  cdtestpath = NULL;
	 }

	 if(dsfn)
	  MDFNI_DumpSettingsDef(dsfn);

	 if(dmfn)
	  MDFNI_DumpModulesDef(dmfn);

	 if(dsfn || dmfn)
	  return false;

	 if(*filename == NULL)
	 {
	  MDFN_Notify(MDFN_NOTICE_ERROR, _("No game filename specified!"));
	  return false;
	 }
	}
	return true;
}

static volatile unsigned NeedVideoSync = 0;
static int GameLoop(void *arg);
int volatile GameThreadRun = 0;
static bool MDFND_Update(int WhichVideoBuffer, int16 *Buffer, int Count);

static bool sound_active;	// true if sound is enabled and initialized


static EmuRealSyncher ers;

static bool autosave_load_error = false;

static void CloseGame(void) MDFN_COLD;
static int LoadGame(const char *force_module, const char *path)
{
	assert(MThreading::Thread_ID() == MainThreadID);
	//
	MDFNGI *tmp;

	CloseGame();

	pending_save_state = false;
	pending_save_movie = false;
	pending_snapshot = false;
	pending_ssnapshot = false;

	if(loadcd)	// Deprecated
	{
	 if(!(tmp = MDFNI_LoadGame(loadcd ? loadcd : force_module, &::Mednafen::NVFS, path, true)))
	  return(0);
	}
	else
	{
         if(!(tmp=MDFNI_LoadGame(force_module, &::Mednafen::NVFS, path)))
	  return 0;
	}
	//
	//
	//
#if 1
	if(StatePCTest)
	{
	 for(unsigned i = 0; i < 2; i++)
	 {
	  MemoryStream state0(524288);
	  MemoryStream state1(524288);
	  MDFNI_Power();
	  MDFNSS_SaveSM(&state0);
	  state0.rewind();
	  MDFNSS_LoadSM(&state0, false, (i ? MDFNSS_FUZZ_UNSIGNED_MIN : MDFNSS_FUZZ_UNSIGNED_MAX));
	  MDFNI_CloseGame();
          if(!(tmp=MDFNI_LoadGame(force_module, &::Mednafen::NVFS, path)))
	   abort();
	  MDFNI_Power();
	  MDFNSS_SaveSM(&state1);
	  state0.rewind();
	  MDFNSS_LoadSM(&state0);
	  MDFNI_CloseGame();
          if(!(tmp=MDFNI_LoadGame(force_module, &::Mednafen::NVFS, path)))
	   abort();

	  if(!(state0.map_size() == state1.map_size() && !memcmp(state0.map() + 32, state1.map() + 32, state1.map_size() - 32)))
	  {
	   FileStream sd0("/tmp/sdump0", FileStream::MODE_WRITE);
	   FileStream sd1("/tmp/sdump1", FileStream::MODE_WRITE);

	   sd0.write(state0.map(), state0.map_size());
	   sd1.write(state1.map(), state1.map_size());
	   sd0.close();
	   sd1.close();
	   abort();
	  }
         }
	}
#endif
	//
	//
	//
	CurGame = tmp;
	Input_GameLoaded(tmp);
	RMDUI_Init(tmp, which_medium);

        RefreshThrottleFPS(1);

	sound_active = 0;

        sc_blit_timesync = MDFN_GetSettingB("video.blit_timesync");

	if(MDFN_GetSettingB("sound"))
	 sound_active = Sound_Init(tmp);

	// Load state before network connection.
	// TODO: Move into core, MDFNI_LoadGame()
        if(MDFN_GetSettingB("autosave"))
	{
	 if(!MDFNI_LoadState(NULL, "mca"))
	 {
	  autosave_load_error = true;
	  return 0;
	 }
	}

	if(netconnect)
	 MDFNI_NetplayConnect();

	ers.SetEmuClock(CurGame->MasterClock >> 32);

	Debugger_Init();

	if(qtrecfn)
	{
	// MDFNI_StartAVRecord() needs to be called after MDFNI_Load(Game/CD)
         if(!MDFNI_StartAVRecord(qtrecfn, Sound_GetRate()))
	 {
	  free(qtrecfn);
	  qtrecfn = NULL;

	  return(0);
	 }
	}

        if(soundrecfn)
        {
 	 if(!MDFNI_StartWAVRecord(soundrecfn, Sound_GetRate()))
         {
          free(soundrecfn);
          soundrecfn = NULL;

	  return(0);
         }
        }

	ffnosound = MDFN_GetSettingB("ffnosound");
	RewindState = MDFN_GetSettingB("srwautoenable");
	if(RewindState)
	{
	 MDFN_Notify(MDFN_NOTICE_STATUS, _("State rewinding functionality enabled."));
	 MDFNI_EnableStateRewind(RewindState);
	}

	return 1;
}

/* Closes a game and frees memory. */
static void CloseGame(void)
{
	if(!CurGame)
	 return;
	//
	//
	//
	GameThreadRun = 0;

	if(GameThread)
	{
	 MThreading::Thread_Wait(GameThread, NULL);
	 GameThread = NULL;
	}
	//
	//
	//
        if(qtrecfn)	// Needs to be before MDFNI_Closegame() for now
         MDFNI_StopAVRecord();

        if(soundrecfn)
         MDFNI_StopWAVRecord();

	if(MDFN_GetSettingB("autosave") && !autosave_load_error)
	 MDFNI_SaveState(NULL, "mca", NULL, NULL, NULL);

	MDFNI_NetplayDisconnect();

	Debugger_Kill();

	RMDUI_Kill();
	Input_GameClosed();
	Sound_Kill();
	//
	//
	//
	MDFNI_CloseGame();
	CurGame = NULL;
}

static void GameThread_HandleEvents(void);
static int volatile NeedExitNow = 0;	// Set 'true' in various places, including signal handler.
double CurGameSpeed = 1;

void MainRequestExit(void)
{
 NeedExitNow = 1;
}

bool Mednafen::MDFND_CheckNeedExit(void)	// Called from netplay code, so we can break out of blocking loops after receiving a signal.
{
 return (bool)NeedExitNow;
}

static bool InFrameAdvance = 0;
static bool NeedFrameAdvance = 0;

bool IsInFrameAdvance(void)
{
 return InFrameAdvance;
}

void DoRunNormal(void)
{
 NeedFrameAdvance = 0;
 InFrameAdvance = 0;
}

void DoFrameAdvance(void)
{
 NeedFrameAdvance |= InFrameAdvance;
 InFrameAdvance = 1;
}

static int GameLoopPaused = 0;

void DebuggerFudge(void)
{
 const uint32 WaitMS = 10;
 uint32 wt = Time::MonoMS() + WaitMS;

 MDFND_Update(SoftFB_BackBuffer ^ 1, nullptr, 0);

 wt -= Time::MonoMS();

 if(wt > 0 && wt <= WaitMS)
 {
  if(sound_active)
   Sound_WriteSilence(wt);
  else
   Time::SleepMS(wt);
 }
}

static int GameLoop(void *arg)
{
	while(GameThreadRun)
	{
         int16 *sound;
         int32 ssize;
         bool fskip;
        
	 /* If we requested a new video mode, wait until it's set before calling the emulation code again.
	 */
	 while(NeedVideoSync)
	 {
	  if(!GameThreadRun) return(1);	// Might happen if video initialization failed
	  Time::SleepMS(2);
	 }

	 if(Sound_NeedReInit())
	  GT_ReinitSound();

	 if(MDFNDnetplay && !(NoWaiting & 0x2))	// TODO: Hacky, clean up.
	  ers.SetETtoRT();
	 //
	 //
	 fskip = ers.NeedFrameSkip();
	 fskip &= MDFN_GetSettingB("video.frameskip");
	 fskip &= !(pending_ssnapshot || pending_snapshot || pending_save_state || pending_save_movie || NeedFrameAdvance);
	 fskip |= (bool)NoWaiting;

	 //printf("fskip %d; NeedFrameAdvance=%d\n", fskip, NeedFrameAdvance);

	 NeedFrameAdvance = false;
	 //
	 //
	 SoftFB[SoftFB_BackBuffer].lw[0] = ~0;

	 //
	 //
	 //
	 EmulateSpecStruct espec;

         espec.surface = SoftFB[SoftFB_BackBuffer].surface.get();
         espec.LineWidths = SoftFB[SoftFB_BackBuffer].lw.get();
	 espec.skip = fskip;
	 espec.soundmultiplier = CurGameSpeed;
	 espec.NeedRewind = DNeedRewind;

 	 espec.SoundRate = Sound_GetRate();
	 espec.SoundBuf = Sound_GetEmuModBuffer(&espec.SoundBufMaxSize);
 	 espec.SoundVolume = (double)MDFN_GetSettingUI("sound.volume") / 100;

	 if(MDFN_UNLIKELY(StateFuzzTest))
	 {
	  EmulateSpecStruct estmp = espec;
	  MemoryStream state0(524288);

	  MDFNSS_SaveSM(&state0);
	  state0.rewind();
	  MDFNSS_LoadSM(&state0, false, MDFNSS_FUZZ_RANDOM);
	  MDFNI_Emulate(&estmp);
	  state0.rewind();
	  MDFNSS_LoadSM(&state0);
	 }

	 if(MDFN_UNLIKELY(StateRCTest))
	 {
	  // Note: Won't work correctly with modules that do mid-sync.
	  EmulateSpecStruct estmp = espec;

	  MemoryStream state0(524288);
	  MemoryStream state1(524288);
	  MemoryStream state2(524288);

	  MDFNSS_SaveSM(&state0);
	  MDFNI_Emulate(&espec);
	  espec = estmp;

	  MDFNSS_SaveSM(&state1);
	  state0.rewind();
	  MDFNSS_LoadSM(&state0);
	  MDFNI_Emulate(&espec);
	  MDFNSS_SaveSM(&state2);

	  if(!(state1.map_size() == state2.map_size() && !memcmp(state1.map() + 32, state2.map() + 32, state1.map_size() - 32)))
	  {
	   FileStream sd0("/tmp/sdump0", FileStream::MODE_WRITE);
	   FileStream sd1("/tmp/sdump1", FileStream::MODE_WRITE);

	   sd0.write(state1.map(), state1.map_size());
	   sd1.write(state2.map(), state2.map_size());
	   sd0.close();
	   sd1.close();
	   //assert(orig_state.map_size() == new_state.map_size() && !memcmp(orig_state.map() + 32, new_state.map() + 32, orig_state.map_size() - 32));
	   abort();
	  }
	 }
	 else
          MDFNI_Emulate(&espec);

	 if(MDFN_UNLIKELY(StateSLSTest))
	 {
	  MemoryStream orig_state(524288);
	  MemoryStream new_state(524288);

	  MDFNSS_SaveSM(&orig_state);
	  orig_state.rewind();
	  MDFNSS_LoadSM(&orig_state);
	  MDFNSS_SaveSM(&new_state);

	  if(!(orig_state.map_size() == new_state.map_size() && !memcmp(orig_state.map() + 32, new_state.map() + 32, orig_state.map_size() - 32)))
	  {
	   FileStream sd0("/tmp/sdump0", FileStream::MODE_WRITE);
	   FileStream sd1("/tmp/sdump1", FileStream::MODE_WRITE);

	   sd0.write(orig_state.map(), orig_state.map_size());
	   sd1.write(new_state.map(), new_state.map_size());
	   sd0.close();
	   sd1.close();
	   //assert(orig_state.map_size() == new_state.map_size() && !memcmp(orig_state.map() + 32, new_state.map() + 32, orig_state.map_size() - 32));
	   abort();
	  }
	 }

	 ers.AddEmuTime((espec.MasterCycles - espec.MasterCycles_DriverProcessed) / CurGameSpeed);

	 SoftFB[SoftFB_BackBuffer].rect = espec.DisplayRect;
	 SoftFB[SoftFB_BackBuffer].field = espec.InterlaceOn ? espec.InterlaceField : -1;

	 sound = espec.SoundBuf + (espec.SoundBufSize_DriverProcessed * CurGame->soundchan);
	 ssize = espec.SoundBufSize - espec.SoundBufSize_DriverProcessed;
	 //
	 //
	 //

	 FPS_IncVirtual(espec.MasterCycles);
	 if(!fskip)
	  FPS_IncDrawn();


	 {
	  bool do_flip = false;

	  do
	  {
 	   if(fskip && ((InFrameAdvance && !NeedFrameAdvance) || GameLoopPaused))
	   {
	    // If this frame was skipped, and the game loop is paused(IE cheat interface is active) or we're in frame advance, just blit the last
	    // drawn, non-skipped frame so the OSD elements actually get drawn.
	    //
	    // Needless to say, do not allow do_flip to be set to true here.
	    //
	    // Possible problems with this kludgery:
	    //	Will fail spectacularly if there is no previous successful frame.  BOOOOOOM.  (But there always should be, especially since we initialize some
  	    //   of the video buffer and rect structures during startup)
	    //
            MDFND_Update(SoftFB_BackBuffer ^ 1, sound, ssize);
	   }
	   else
            do_flip = MDFND_Update(fskip ? -1 : SoftFB_BackBuffer, sound, ssize);

	   FPS_UpdateCalc();

	   Netplay_GT_CheckPendingLine();

           if((InFrameAdvance && !NeedFrameAdvance) || GameLoopPaused)
	   {
            if(ssize)
	     for(int x = 0; x < CurGame->soundchan * ssize; x++)
	      sound[x] = 0;
	   }
	  } while(((InFrameAdvance && !NeedFrameAdvance) || GameLoopPaused) && GameThreadRun);
	  SoftFB_BackBuffer ^= do_flip;
	 }
	}

	return(1);
}   


std::string GetBaseDirectory(void)
{
#ifdef WIN32
 {
  const TCHAR* ol;

  ol = _tgetenv(TEXT("MEDNAFEN_HOME"));
  if(ol != NULL && ol[0] != 0)
   return Win32Common::T_to_UTF8(ol, nullptr, true);

  ol = _tgetenv(TEXT("HOME"));
  if(ol)
   return Win32Common::T_to_UTF8(ol, nullptr, true) + PSS + ".mednafen";
 }

 {
  std::string path;
  size_t lsp;

  path = GetModuleFileName_UTF8(NULL);

  if((lsp = path.find_last_of(u'\\')) != std::string::npos)
   path.resize(lsp);

  return path;
 }
#else
 char *ol;

 ol = getenv("MEDNAFEN_HOME");
 if(ol != NULL && ol[0] != 0)
 {
  return std::string(ol);
 }

 ol = getenv("HOME");
 if(ol)
  return std::string(ol) + PSS + ".mednafen";

 #if defined(HAVE_GETUID) && defined(HAVE_GETPWUID)
 {
  struct passwd *psw;

  psw = getpwuid(getuid());

  if(psw != NULL && psw->pw_dir[0] != 0 && strcmp(psw->pw_dir, "/dev/null"))
   return std::string(psw->pw_dir) + PSS + ".mednafen";
 }
 #endif
 return "";
#endif
}

static const int gtevents_size = 2048; // Must be a power of 2.
static volatile SDL_Event gtevents[gtevents_size];
static volatile int gte_read = 0;
static volatile int gte_write = 0;

/* This function may also be called by the main thread if a game is not loaded. */
/*
 This function may be called from MDFND_MidSync(), so make sure that it doesn't call directly nor indirectly
 any MDFNI_* functions that shouldn't be called.
*/
static void GameThread_HandleEvents(void)
{
 SDL_Event gtevents_temp[gtevents_size];
 unsigned int numevents = 0;

 MThreading::Mutex_Lock(EVMutex);
 while(gte_read != gte_write)
 {
  memcpy(&gtevents_temp[numevents], (void *)&gtevents[gte_read], sizeof(SDL_Event));

  numevents++;
  gte_read = (gte_read + 1) & (gtevents_size - 1);
 }
 MThreading::Mutex_Unlock(EVMutex);

 for(unsigned int i = 0; i < numevents; i++)
 {
  SDL_Event *event = &gtevents_temp[i];

  switch(event->type)
  {
   case SDL_USEREVENT:
		switch(event->user.code & 0xFFFF)
		{
		 case CEVT_SET_INPUT_FOCUS:
			MDFNDHaveFocus = (event->user.data1 != NULL);
			//printf("%u\n", MDFNDHaveFocus);
			break;
		}
		break;
  }

  Input_Event(event);

  if(Debugger_IsActive())
   Debugger_GT_Event(event);
 }
}

void PauseGameLoop(bool p)
{
 GameLoopPaused = p;
}


void SendCEvent(unsigned int code, void *data1, void *data2, uint16 idata16)
{
 SDL_Event evt;
 evt.user.type = SDL_USEREVENT;
 evt.user.code = code | (idata16 << 16);
 evt.user.data1 = data1;
 evt.user.data2 = data2;
 SDL_PushEvent(&evt);
}

static void SendCEvent_to_GT(unsigned int code, void *data1, void *data2, uint16 idata16 = 0)
{
 SDL_Event evt;
 evt.user.type = SDL_USEREVENT;
 evt.user.code = code | (idata16 << 16);
 evt.user.data1 = data1;
 evt.user.data2 = data2;

 MThreading::Mutex_Lock(EVMutex);
 memcpy((void *)&gtevents[gte_write], &evt, sizeof(SDL_Event));
 gte_write = (gte_write + 1) & (gtevents_size - 1);
 MThreading::Mutex_Unlock(EVMutex);
}

void GT_ToggleFS(void)
{
 // assert(MThreading::Thread_ID() == GameThreadID);
 MThreading::Mutex_Lock(VTMutex);
 MDFNI_SetSettingB("video.fs", !MDFN_GetSettingB("video.fs"));
 NeedVideoSync++;
 MThreading::Mutex_Unlock(VTMutex);

 MThreading::Sem_Post(VTWakeupSem);
 while(NeedVideoSync && GameThreadRun)
 {
  Time::SleepMS(2);
 }
}

bool GT_ReinitVideo(void)
{
 // assert(MThreading::Thread_ID() == GameThreadID);
 MThreading::Mutex_Lock(VTMutex);
 NeedVideoSync++;
 MThreading::Mutex_Unlock(VTMutex);

 MThreading::Sem_Post(VTWakeupSem);
 while(NeedVideoSync && GameThreadRun)
 {
  Time::SleepMS(2);
 }

 return(true);	// FIXME!
}

bool GT_ReinitSound(void)
{
 bool ret = true;

 Sound_Kill();
 sound_active = 0;

 if(MDFN_GetSettingB("sound"))
 {
  sound_active = Sound_Init(CurGame);
  if(!sound_active)
   ret = false;
 }

 return(ret);
}

void GT_SetWMInputBehavior(bool CursorNeeded, bool MouseAbsNeeded, bool MouseRelNeeded, bool GrabNeeded)
{
 SendCEvent(CEVT_SET_WMINPUTBEHAVIOR, nullptr, nullptr, (CursorNeeded << 0) | (MouseAbsNeeded << 1) | (MouseRelNeeded << 2) | (GrabNeeded << 3));
}

void PumpWrap(void)
{
 SDL_Event event;
 SDL_Event gtevents_temp[gtevents_size];
 int numevents = 0;

 if(SignalSafeExitWanted)
  NeedExitNow = true;

 while(SDL_PollEvent(&event))
 {
  if(CheatIF_Active())
   CheatIF_MT_EventHook(&event);

  NetplayEventHook(&event);

  /* Handle the event, and THEN hand it over to the GUI. Order is important due to global variable mayhem(CEVT_TOGGLEFS. */
  switch(event.type)
  {
   case SDL_WINDOWEVENT:
	// event.window.windowID
	switch(event.window.event)
	{
	 case SDL_WINDOWEVENT_EXPOSED:
		Video_Exposed();
		break;

	 case SDL_WINDOWEVENT_FOCUS_GAINED:
		//SDL_ShowWindow(window);
		//SDL_RestoreWindow(window);
		//puts("Gain");
		SendCEvent_to_GT(CEVT_SET_INPUT_FOCUS, (void*)gtevents/* Dummy valid pointer*/, NULL);
		break;

	 case SDL_WINDOWEVENT_FOCUS_LOST:
		//puts("Lost");
		SendCEvent_to_GT(CEVT_SET_INPUT_FOCUS, NULL, NULL);
		break;
	}
	break;

   case SDL_QUIT:
	NeedExitNow = 1;
	break;

   case SDL_USEREVENT:
	{
	const uint16 idata16 = event.user.code >> 16;

	switch(event.user.code & 0xFFFF)
	{
	 case CEVT_SET_STATE_STATUS:
		MT_SetStateStatus((StateStatusStruct *)event.user.data1);
		break;

	 case CEVT_SET_MOVIE_STATUS:
		MT_SetMovieStatus((StateStatusStruct *)event.user.data1);
		break;

	 case CEVT_WANT_EXIT:
		if(!Netplay_TryTextExit())
		{
		 SDL_Event evt;
		 evt.quit.type = SDL_QUIT;
		 SDL_PushEvent(&evt);
		}
		break;

	 case CEVT_SET_WMINPUTBEHAVIOR:
		NeededWMInputBehavior.Cursor = (bool)(idata16 & 0x1);
		NeededWMInputBehavior.MouseAbs = (bool)(idata16 & 0x2);
		NeededWMInputBehavior.MouseRel = (bool)(idata16 & 0x4);
		NeededWMInputBehavior.Grab = (bool)(idata16 & 0x8);
		NeededWMInputBehavior_Dirty = true;
		break;

  	 case CEVT_OUTPUT_NOTICE:
		Video_ShowNotice((MDFN_NoticeType)idata16, (char*)event.user.data1);
		break;

	 default: 
		if(numevents < gtevents_size)
		{
		 memcpy(&gtevents_temp[numevents], &event, sizeof(SDL_Event));
		 numevents++;
		}
		break;
	}
	}
	break;

   default: 
	if(numevents < gtevents_size)
	{
	 memcpy(&gtevents_temp[numevents], &event, sizeof(SDL_Event));
	 numevents++;
	}
	break;
  }
 }

 if(numevents > 0)
 {
  MThreading::Mutex_Lock(EVMutex);
  for(int i = 0; i < numevents; i++)
  {
   memcpy((void *)&gtevents[gte_write], &gtevents_temp[i], sizeof(SDL_Event));
   gte_write = (gte_write + 1) & (gtevents_size - 1);
  }
  MThreading::Mutex_Unlock(EVMutex);
 }

 if(!CurGame)
  GameThread_HandleEvents();
}

void RefreshThrottleFPS(double multiplier)
{
        CurGameSpeed = multiplier;
}

void PrintCompilerVersion(void)
{
 #if defined(__GNUC__)
  MDFN_printf(_("Compiled with gcc %s\n"), __VERSION__);
 #endif

 #ifdef HAVE___MINGW_GET_CRT_INFO
  MDFN_printf(_("Running with %s\n"), __mingw_get_crt_info());
 #endif
}

#if 0
#include <vector>	// To make sure we pick up c++config.h if it's there
void PrintGLIBCXXInfo(void)
{
 #if defined(__GLIBCXX__)
  MDFN_printf(_("Compiled with GNU libstdc++ %lu\n"), (unsigned long)__GLIBCXX__);
  {
   MDFN_AutoIndent aind(1);
   const char* sjljresp;
   #if defined(_GLIBCXX_SJLJ_EXCEPTIONS)
    sjljresp = _("Yes");
   #else
    sjljresp = _("No");
   #endif
   MDFN_printf(_("Using SJLJ Exceptions: %s\n"), sjljresp);
  }
 #endif
}
#endif

void PrintSDLVersion(void)
{
 SDL_version sver;

 SDL_GetVersion(&sver);

 MDFN_printf(_("Compiled against SDL %u.%u.%u(%s), running with SDL %u.%u.%u(%s)\n"), SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL, SDL_REVISION, sver.major, sver.minor, sver.patch, SDL_GetRevision());

 if(SDL_VERSIONNUM(sver.major, sver.minor, sver.patch) < SDL_VERSIONNUM(SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL))
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("Running with a version of SDL older than the version compiled and linked against!"));
  abort();
 }
}

#ifdef HAVE_LIBFLAC
 #include <FLAC/all.h>
#endif

void PrintLIBFLACVersion(void)
{
 #ifdef HAVE_LIBFLAC
  MDFN_printf(_("Running with libFLAC %s\n"), FLAC__VERSION_STRING);
 #endif
}

#include <zlib.h>
void PrintZLIBVersion(void)
{
 #ifdef ZLIB_VERSION
  MDFN_printf(_("Compiled against zlib %s, running with zlib %s(flags=0x%08lx)\n"), ZLIB_VERSION, zlibVersion(), (unsigned long)zlibCompileFlags());
 #endif
}

void PrintLIBICONVVersion(void)
{
 #ifdef _LIBICONV_VERSION
  MDFN_printf(_("Compiled against libiconv %u.%u, running with libiconv %u.%u\n"), _LIBICONV_VERSION & 0xFF, _LIBICONV_VERSION >> 8,
										   _libiconv_version & 0xFF, _libiconv_version >> 8);
 #endif
}

#if 0//#ifdef WIN32
char *GetFileDialog(void)
{
 OPENFILENAME ofn;
 char returned_fn[2048];
 std::string filter;
 bool first_extension = true;

 filter = std::string("Recognized files");
 filter.push_back(0);

 for(unsigned int i = 0; i < MDFNSystems.size(); i++)
 {
  if(MDFNSystems[i]->FileExtensions)
  {
   const FileExtensionSpecStruct *fesc = MDFNSystems[i]->FileExtensions;

   while(fesc->extension && fesc->description)
   {
    if(!first_extension)
     filter.push_back(';');

    filter.push_back('*');
    filter += std::string(fesc->extension);

    first_extension = false;
    fesc++;
   }
  }
 }

 filter.push_back(0);
 filter.push_back(0);

 //fwrite(filter.data(), 1, filter.size(), stdout);

 memset(&ofn, 0, sizeof(ofn));

 ofn.lStructSize = sizeof(ofn);
 ofn.lpstrTitle = "Mednafen Open File";
 ofn.lpstrFilter = filter.data();

 ofn.nMaxFile = sizeof(returned_fn);
 ofn.lpstrFile = returned_fn;

 ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY;

 if(GetOpenFileName(&ofn))
  return(strdup(returned_fn));
 
 return(NULL);
}
#endif

static bool LoadSettings(void)
{
 const std::string opath09x = DrBaseDirectory + PSS + "mednafen-09x.cfg";
 const std::string npath = DrBaseDirectory + PSS + "mednafen.cfg";
 bool mednafencfg_old = false;	// "mednafen.cfg" is old(0.8.x or earlier), or nonexistent

 try
 {
  std::unique_ptr<FileStream> fp(new FileStream(npath, FileStream::MODE_READ));
  std::string linebuf;

  if(fp->get_line(linebuf) >= 0)
  {
   if(linebuf.find(";VERSION 0.") != std::string::npos)
    mednafencfg_old = true;
  }
  fp.reset(nullptr);
  //
  if(mednafencfg_old)
  {
   char tmp[256];
   trio_snprintf(tmp, sizeof(tmp), "%llu", (unsigned long long)Time::EpochTime());
   NVFS.rename(npath, npath + "." + tmp);
  }
 }
 catch(MDFN_Error& e)
 {
  if(e.GetErrno() == ENOENT)
   mednafencfg_old = true;
  else
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   return false;
  }
 }

 // Make sure the old settings file actually exists before calling
 // MDFNI_LoadSettings() with its path, as MDFNI_LoadSettings() will,
 // as of 1.27.0, open the (non-override) settings file with
 // FileStream::MODE_READ_WRITE so that locking will work over NFS
 // and to ensure that the settings file is actually writeable,
 // which will create an empty mednafen-09x.cfg that we don't want.
 if(mednafencfg_old && NVFS.finfo(opath09x, nullptr, false))
 {
  switch(MDFNI_LoadSettings(opath09x.c_str()))
  {
   case -1: return true;
   case 0: return false;
  }
  //
  MDFNI_SetSetting("video.driver", MDFNI_GetSettingDefault("video.driver"));
  //
#ifdef WIN32
  try
  {
   const std::vector<MDFNCS>* cs = MDFNI_GetSettings();
   for(const MDFNCS& s : *cs)
   {
    if(s.desc->flags & MDFNSF_CAT_PATH)
    {
     assert(s.desc->type == MDFNST_STRING);
     //
     const size_t s_value_len = strlen(s.value);
     if(s_value_len > 0)
     {
      int req;

      if((req = MultiByteToWideChar(CP_ACP, 0, s.value, s_value_len, NULL, 0)) > 0) // not CP_THREAD_ACP
      {
       std::unique_ptr<char16_t[]> ws(new char16_t[req]);

       if(MultiByteToWideChar(CP_ACP, 0, s.value, s_value_len, (wchar_t*)ws.get(), req) == req)
        MDFNI_SetSetting(s.name, UTF16_to_UTF8(ws.get(), req));
       else
        throw MDFN_Error(0, _("Error converting value of setting \"%s\" to UTF-8."), s.name);
      }
      else
       throw MDFN_Error(0, _("Error converting value of setting \"%s\" to UTF-8."), s.name);
     }
    }
   }
  }
  catch(std::exception& e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   return false;
  }
#endif

  return true;
 }
 else
  return (bool)MDFNI_LoadSettings(npath.c_str());
}

static void SaveSettings(void)
{
 const std::string npath = DrBaseDirectory + PSS + "mednafen.cfg";

 MDFNI_SaveSettings(npath.c_str());
}

#ifdef WIN32
static bool MSW_GetArgcArgv(int *argc, char ***argv)
{
#ifdef UNICODE
 wchar_t** argvw = CommandLineToArgvW(GetCommandLineW(), argc);
 char** ret;

 if(!argvw)
  return false;

 if(!(ret = (char**)malloc((*argc + 1) * sizeof(char*))))
  return false;

 ret[*argc] = nullptr;

 for(int i = 0; i < *argc; i++)
 {
  const size_t argvw_i_slen = wcslen(argvw[i]);
  size_t dlen = 0;

  UTF16_to_UTF8((char16_t*)argvw[i], argvw_i_slen + 1, nullptr, &dlen, true);
  if(!(ret[i] = (char*)malloc(dlen)))
   return false;
  UTF16_to_UTF8((char16_t*)argvw[i], argvw_i_slen + 1, ret[i],  &dlen, true);
 }

 LocalFree(argvw);
 argvw = nullptr;

 *argv = ret;
#else
 //
 // TODO?
 //
#endif

 return true;
}
#endif


#ifdef WIN32
extern "C"
{
 void __set_app_type(int);
 extern int mingw_app_type;
}

__attribute__((force_align_arg_pointer))	// Not sure what's going on to cause this to be needed.
#endif
int main(int argc, char *argv[])
{
	// SuppressErrorPopups must be set very early.
	{
	 char* mnp = getenv("MEDNAFEN_NOPOPUPS");

	 if(mnp)
	  SuppressErrorPopups = atoi(mnp);
	 else
	  SuppressErrorPopups = false;

#ifdef WIN32
	 // for assert() and abort()
	 if(SuppressErrorPopups)
	 {
	  __set_app_type(1);
	  mingw_app_type = 0;
	 }
	 else
	 {
	  __set_app_type(2);
	  mingw_app_type = 1;
	 }
#endif
	}
	//
	//
	//
	std::unique_ptr<FileStream> lockfs;
	int FatalVideoError = -1;

	#ifdef WIN32
	if(!MSW_GetArgcArgv(&argc, &argv))
	{
	 if(!SuppressErrorPopups)
	  MessageBoxA(NULL, "Error getting/allocating arguments.", "Mednafen Startup Error", MB_OK | MB_ICONERROR | MB_TASKMODAL | MB_SETFOREGROUND | MB_TOPMOST);

	 printf("Error getting/allocating arguments.\n");
	 return -1;
	}
	#endif
	// Place before calls to SDL_Init()
	putenv(strdup("SDL_DISABLE_LOCK_KEYS=1"));
	SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
	SDL_SetHint(SDL_HINT_GRAB_KEYBOARD, "1");
	//
	//
	//
	MainThreadID = MThreading::Thread_ID();	// Must come before any direct or indirect calls to MDFND_OutputNotice()
	//
	//
	//
	if(argc >= 3 && (!MDFN_strazicmp(argv[1], "-remote") || !MDFN_strazicmp(argv[1], "--remote")))
	{
	 RemoteOn = true;
	 InitSTDIOInterface(argv[2]);
	}

	#ifdef WIN32
	HandleConsoleMadness();
	#endif

	//ThreadTest();
	char *needie = NULL;

        //

	MDFNDHaveFocus = false;

	DrBaseDirectory = GetBaseDirectory();

	#ifdef ENABLE_NLS
	setlocale(LC_ALL, "");

	#ifdef WIN32
	setlocale(LC_CTYPE, "C");
	setlocale(LC_COLLATE, "C");
	setlocale(LC_NUMERIC, "C");

	for(int i = 128; i < 256; i++)
	{
	 assert(!isspace(i));
	}

        bindtextdomain(PACKAGE, DrBaseDirectory.c_str());
	#else
	bindtextdomain(PACKAGE, LOCALEDIR);
	#endif

	bind_textdomain_codeset(PACKAGE, "UTF-8");
	textdomain(PACKAGE);
	#endif
	//
	//
	//
        #if defined(WIN32) && !defined(UNICODE)
        if(!(GetVersion() & 0x80000000))
        {
	 const char* errorstr = _("This special build of Mednafen is intended for use on Windows 98, Windows 98SE, and Windows Me.  It will perform suboptimally on NT-based versions of Windows.  Download a regular Windows build from https://mednafen.github.io/releases/");

	 if(!SuppressErrorPopups)
	  MessageBoxA(NULL, errorstr, "Mednafen Windows Version Error", MB_OK | MB_ICONSTOP | MB_TASKMODAL | MB_SETFOREGROUND | MB_TOPMOST);

	 printf("%s\n", errorstr);

	 return -1;
        }
        #endif
	//
	//
	//
	MDFNI_printf(_("Starting Mednafen %s\n"), MEDNAFEN_VERSION);
	MDFN_indent(1);

        MDFN_printf(_("Build information:\n"));
        MDFN_indent(2);
        PrintCompilerVersion();
	//PrintGLIBCXXInfo();
        PrintZLIBVersion();
	PrintLIBICONVVersion();
        PrintSDLVersion();
        PrintLIBFLACVersion();
        MDFN_indent(-2);

        MDFN_printf(_("Base directory: %s\n"), DrBaseDirectory.c_str());

	#ifdef WIN32
	// Call to CoInitializeEx() must come before SDL_Init()
	{
	 HRESULT hr;

	 hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
	 if(hr != S_OK && hr != S_FALSE)
	 {
	  MDFN_Notify(MDFN_NOTICE_ERROR, _("CoInitializeEx() failed: %s\n"), Win32Common::ErrCodeToString(hr).c_str());
	  return -1;
	 }
	}
	#endif

	if(SDL_Init(SDL_INIT_VIDEO)) /* SDL_INIT_VIDEO Needed for (joystick config) event processing? */
	{
	 MDFN_Notify(MDFN_NOTICE_ERROR, _("Could not initialize SDL: %s\n"), SDL_GetError());
	 return -1;
	}
	SDL_JoystickEventState(SDL_IGNORE);
	SDL_DisableScreenSaver();
	//SDL_StopTextInput();

	if(!(StdoutMutex = MThreading::Mutex_Create()))
	{
	 MDFN_Notify(MDFN_NOTICE_ERROR, _("Could not create mutex: %s\n"), SDL_GetError());
	 return -1;
	}

	if(!MDFNI_InitializeModules())
	 return -1;

	for(unsigned int x = 0; x < sizeof(DriverSettings) / sizeof(MDFNSetting); x++)
	 NeoDriverSettings.push_back(DriverSettings[x]);

	MakeDebugSettings(NeoDriverSettings);
	Video_MakeSettings(NeoDriverSettings);
	Input_MakeSettings(NeoDriverSettings);

        if(!MDFNI_Initialize(DrBaseDirectory.c_str(), NeoDriverSettings))
         return -1;
	//
	//
	//
	try
	{
 	 // Create base directory
	 NVFS.create_missing_dirs(DrBaseDirectory + PSS);
	}
	catch(std::exception &e)
	{
	 MDFN_Notify(MDFN_NOTICE_ERROR, _("Error creating base directory: %s\n"), e.what());
	 return -1;
	}
	//
	//
	//
	MDFN_printf(_("Opening lockfile...\n"));
	{
	 MDFN_AutoIndent aind(1);
	 try
	 {
	  lockfs.reset(new FileStream(DrBaseDirectory + PSS + "mednafen.lck", FileStream::MODE_WRITE_INPLACE, -1));
	 }
	 catch(MDFN_Error& e)
	 {
	  if(e.GetErrno() == EWOULDBLOCK)	// Fragile, FIXME with proper class-specific error types.
	  {
	   char* env_aw = getenv("MEDNAFEN_ALLOWMULTI");

	   if(env_aw && atoi(env_aw) != 0)
	   {	
	    MDFN_printf(_("Error, but proceeding anyway per environment variable \"MEDNAFEN_ALLOWMULTI\".\n"));
	   }
	   else
	   {
	    MDFN_Notify(MDFN_NOTICE_ERROR, _("Multiple instances of Mednafen using the same base directory should not run simultaneously, otherwise settings file changes may be lost, along with other similar problems.  If you understand the risks, and want to anyway, run Mednafen with environment variable \"MEDNAFEN_ALLOWMULTI\" set to \"1\" to bypass this check."));
	    return -1;
	   }
	  }
	  else
	  {
	   MDFN_printf(_("Error: %s\n"), e.what());
	   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
	   return -1;
	  }
	 }
	 catch(std::exception& e)
	 {
	  MDFN_printf(_("Error: %s\n"), e.what());
	  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
	  return -1;
	 }
	}
	//
	//
	//
	if(!LoadSettings())
	 return -1;

	if(!DoArgs(argc, argv, &needie))
	{
	 CreateDataDirs();
	 SaveSettings();
	 MDFNI_Kill();
	 return -1;
	}
	//
	//
	//
	if(!CreateDataDirs())
	{
	 SaveSettings();
	 MDFNI_Kill();
	 return -1;
	}
	//
	//
	//
	InstallSignalHandlers();
	//
	//
	//

	/* Now the fun begins! */
	/* Run the video and event pumping in the main thread, and create a 
	   secondary thread to run the game in(and do sound output, since we use
	   separate sound code which should be thread safe(?)).
	*/
	int ret = 0;

	VTMutex = MThreading::Mutex_Create();
        EVMutex = MThreading::Mutex_Create();

	VTWakeupSem = MThreading::Sem_Create();
	//
	Video_Init();
	//
	JoystickManager::Init();
	JoystickManager::SetAnalogThreshold(MDFN_GetSettingF("analogthreshold") / 100);

#if 0
for(int zgi = 1; zgi < argc; zgi++)// start game load test loop
{
 needie = argv[zgi];
#endif

	VTReady.store(-1, std::memory_order_release);

	NeedExitNow = 0;

	#if 0
	{
	 int64 start_ticks = Time::MonoUS();

	 for(int i = 0; i < 65536; i++)
	  MDFN_GetSettingB("gg.forcemono");

	 printf("%lld\n", (long long)(Time::MonoUS() - start_ticks));
	}
	#endif

 try
 {
        if(LoadGame(force_module_arg, needie))
        {
         NeedVideoSync = 1;	// Set to 1 before creating game thread.
	 //
	 //
	 const uint64 vt_affinity = MDFN_GetSettingUI("affinity.video");
         const uint64 gt_affinity = MDFN_GetSettingUI("affinity.emu");

	 GameThreadRun = 1;
	 GameThread = MThreading::Thread_Create(GameLoop, NULL, "MDFN Emulation");

	 if(gt_affinity)
	  MThreading::Thread_SetAffinity(GameThread, gt_affinity);

	 if(vt_affinity)
	  MThreading::Thread_SetAffinity(NULL, vt_affinity);
	 //
	 //
	 //
	 uint32 pitch32 = CurGame->fb_width; 
	 MDFN_PixelFormat nf(MDFN_PixelFormat::ABGR32_8888);

         for(int i = 0; i < 2; i++)
	 {
	  SoftFB[i].surface.reset(new MDFN_Surface(NULL, CurGame->fb_width, CurGame->fb_height, pitch32, nf));
	  SoftFB[i].lw.reset(new int32[CurGame->fb_height]);
	  memset(SoftFB[i].lw.get(), 0, sizeof(int32) * CurGame->fb_height);

	  SoftFB[i].surface->Fill(0, 0, 0, 0);

	  //
	  // Debugger step mode, cheat interface, and frame advance mode rely on the previous backbuffer being valid in certain situations.  Initialize some stuff here so that
	  // reliance will still work even immediately after startup.
	  SoftFB[i].rect.w = std::min<int32>(16, SoftFB[i].surface->w);
	  SoftFB[i].rect.h = std::min<int32>(16, SoftFB[i].surface->h);
	  SoftFB[i].lw[0] = ~0;
	 }

         FPS_Init(MDFN_GetSettingUI("fps.position"), MDFN_GetSettingUI("fps.scale"), MDFN_GetSettingUI("fps.font"), MDFN_GetSettingUI("fps.textcolor"), MDFN_GetSettingUI("fps.bgcolor"));
	 if(MDFN_GetSettingB("fps.autoenable"))
          FPS_ToggleView();
        }
	else
	{
	 ret = -1;
	 NeedExitNow = 1;
	}
 }
 catch(std::exception& e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  ret = -1;
  NeedExitNow = 1;
 }

	while(MDFN_LIKELY(!NeedExitNow))
	{
	 MThreading::Mutex_Lock(VTMutex);	/* Lock mutex */

	 try
	 {
	  if(FatalVideoError > 0)
	  {
	   PumpWrap();
	   NeedVideoSync = 0;
	   NeededWMInputBehavior_Dirty = false;
	   VTReady.store(-1, std::memory_order_release);
	  }
	  else
	  {
	   PumpWrap();

	   if(MDFN_UNLIKELY(NeedVideoSync))
           {
	    Video_Sync(CurGame);
	    PumpWrap();
	    //
	    NeedVideoSync = 0;
           }

	   if(NeededWMInputBehavior_Dirty)
	   {
	    Video_SetWMInputBehavior(NeededWMInputBehavior);
	    NeededWMInputBehavior_Dirty = false;
	   }

	   {
	    const int vtr = VTReady.load(std::memory_order_acquire);

            if(vtr >= 0)
            {
             BlitScreen(SoftFB[vtr].surface.get(), &SoftFB[vtr].rect, SoftFB[vtr].lw.get(), VTRotated, SoftFB[vtr].field, VTSSnapshot);

	     // Set to -1 after we're done blitting everything(including on-screen display stuff), and NOT just the emulated system's video surface.
             VTReady.store(-1, std::memory_order_release);
            }
	   }
	  }
	  //
	  //
	  //
	  if(FatalVideoError < 0)
	   FatalVideoError = 0;
	 }
	 catch(std::exception& e)
	 {
	  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
	  if(FatalVideoError == 0)
	  {
 	   MThreading::Mutex_Unlock(VTMutex);   /* Unlock mutex */ 
	   FatalVideoError = 1;
	  }
	  else
	  {	  
	   ret = -1;
           NeedExitNow = 1;
	   MThreading::Mutex_Unlock(VTMutex);   /* Unlock mutex */
	   goto VideoErrorExit;
	  }
	 }

         MThreading::Mutex_Unlock(VTMutex);   /* Unlock mutex */

	 MThreading::Sem_TimedWait(VTWakeupSem, 1);
	}
	VideoErrorExit:;
	//
	//
	//

	CloseGame();

	for(int i = 0; i < 2; i++)
	{
	 SoftFB[i].surface.reset(nullptr);
	 SoftFB[i].lw.reset(nullptr);
	}
#if 0
} // end game load test loop
#endif

	MThreading::Sem_Destroy(VTWakeupSem);

	MThreading::Mutex_Destroy(VTMutex);
        MThreading::Mutex_Destroy(EVMutex);

	RemoveSignalHandlers();

	JoystickManager::Kill();

	SaveSettings();	// Call before we destroy video, so the user has some feedback as to
		        // when it's safe to start another Mednafen instance.

	// lockfs.reset() after SaveSettings()
	lockfs.reset(nullptr);

	Video_Kill();

	MDFNI_Kill();

	SDL_Quit();

        return ret;
}


static uint32 last_btime = 0;
static void UpdateSoundSync(int16 *Buffer, uint32 Count)
{
 if(Count)
 {
  if(ffnosound && CurGameSpeed != 1)
  {
   for(uint32 x = 0; x < Count * CurGame->soundchan; x++)
    Buffer[x] = 0;
  }
  //
  //
  //
  const uint32 cw = Sound_CanWrite();
  bool NeedETtoRT = (Count >= (cw * 0.95));

  if(NoWaiting && Count > cw)
  {
   //printf("NW C to M; count=%d, max=%d\n", Count, max);
   Count = cw;
  }
  else if(MDFNDnetplay)
  {
   //
   // Cheap code to fix sound buffer underruns due to accumulation of time error during netplay.
   //
   uint32 dw = 0;

   if(cw >= (Count * 7 / 4)) // || cw >= Sound_BufferSize())
    dw = cw - std::min<uint32>(cw, Count);

   if(dw)
   {
    int16 zbuf[128 * 2];	// *2 for stereo case.

    //printf("DW: %u\n", dw);

    memset(zbuf, 0, sizeof(zbuf));

    while(dw != 0)
    {
     uint32 wti = std::min<int>(128, dw);
     Sound_Write(zbuf, wti);
     dw -= wti;
    }
    NeedETtoRT = true;
   }
  }

  Sound_Write(Buffer, Count);

  if(NeedETtoRT)
   ers.SetETtoRT();
 }
 else
 {
  bool nothrottle = MDFN_GetSettingB("nothrottle");

  if(!NoWaiting && !nothrottle && GameThreadRun && !MDFNDnetplay)
   ers.Sync();
 }
}

void Mednafen::MDFND_MidSync(EmulateSpecStruct *espec, const unsigned flags)
{
 //printf("MidSync; flags=0x%08x --- SoundBufSize_DriverProcessed=0x%08x, SoundBufSize=0x%08x\n", flags, espec->SoundBufSize_DriverProcessed, espec->SoundBufSize);
 //
 if(MDFN_UNLIKELY(StateRCTest || StateFuzzTest))
 {
  // TODO: Make state rewind consistency checking compatible with midsync, instead of this quick workaround.
  //puts("MDFND_MidSync ignored");
  return;
 }
 //
 //
 int16* const sbuf = espec->SoundBuf + espec->SoundBufSize_DriverProcessed * CurGame->soundchan;
 const int32 scount = espec->SoundBufSize - espec->SoundBufSize_DriverProcessed;

 if(flags & MIDSYNC_FLAG_SYNC_TIME)
 {
  ers.AddEmuTime((espec->MasterCycles - espec->MasterCycles_DriverProcessed) / CurGameSpeed, false);
  espec->MasterCycles_DriverProcessed = espec->MasterCycles;
  //
  UpdateSoundSync(sbuf, scount);
  espec->SoundBufSize_DriverProcessed += scount;
 }
 else
 {
  // TODO, needs changes.
/*
  const int32 eff_scount = std::min<int32>(Sound_CanWrite(), scount);
  assert(espec->SoundBufSize_InternalProcessed >= (espec->SoundBufSize_DriverProcessed + eff_scount));

  printf("MDFND_MidSync() without SYNC_TIME --- %u %u\n", scount, eff_scount);

  UpdateSoundSync(sbuf, eff_scount);
  espec->SoundBufSize_DriverProcessed += eff_scount;
*/
 }

 if(flags & MIDSYNC_FLAG_UPDATE_INPUT)
 {
  GameThread_HandleEvents(); // Should be safe, but be careful about future changes.
  Input_Update(true, false);
 }
 //else
 //{
 // printf("MDFND_MidSync() without UPDATE_INPUT\n");
 //}
}

static bool PassBlit(const int WhichVideoBuffer)
{
 if(WhichVideoBuffer < 0)
  return false;

 while(VTReady.load(std::memory_order_acquire) >= 0)
 {
  /* If it's been > 100ms since the last blit, assume that the blit
     thread is being time-slice starved, and let it run.  This is especially necessary
     for fast-forwarding to respond well(since keyboard updates are
     handled in the main thread) on slower systems or when using a higher fast-forwarding speed ratio.
  */
  if(!GameThreadRun || ((last_btime + 100) >= Time::MonoMS() && !pending_ssnapshot))
   return false;
  else
   Time::SleepMS(1);
 }

 Debugger_GTR_PassBlit();	// Call before the VTReady = WhichVideoBuffer

 VTSSnapshot = pending_ssnapshot;
 VTRotated = CurGame->rotated;
 //
 VTReady.store(WhichVideoBuffer, std::memory_order_release);
 //
 //
 //
 pending_ssnapshot = false;
 last_btime = Time::MonoMS();
 FPS_IncBlitted();

 MThreading::Sem_Post(VTWakeupSem);

 return true;
}


//
// Called from game thread.  Pass -1 for WhichVideoBuffer when the frame is skipped.
//
static bool MDFND_Update(int WhichVideoBuffer, int16 *Buffer, int Count)
{
 bool ret = false;

 if(WhichVideoBuffer >= 0)
 {
  Debugger_GT_Draw();

#if 0
  // Wait if we're re-blitting an already blitted frame, such as done while in frame advance or debugger step mode.
  while(VTReady.load(std::memory_order_acquire) == WhichVideoBuffer)
  {
   puts("Reblit Wait");
   Time::SleepMS(1);
   if(!GameThreadRun)
    return false;
  }
#endif

  //
  // Save any pending screen snapshots, save states, and movies before any potential calls to PassBlit().
  //
  MDFN_Surface* surface = SoftFB[WhichVideoBuffer].surface.get();
  MDFN_Rect* rect = &SoftFB[WhichVideoBuffer].rect;
  int32* lw = SoftFB[WhichVideoBuffer].lw.get();

  if(pending_snapshot)
   MDFNI_SaveSnapshot(surface, rect, lw);

  if(pending_save_state)
   MDFNI_SaveState(NULL, NULL, surface, rect, lw);

  if(pending_save_movie)
   MDFNI_SaveMovie(NULL, surface, rect, lw);

  pending_save_movie = pending_snapshot = pending_save_state = false;
 }

 if(false == sc_blit_timesync)
 {
  //puts("ABBYNORMAL");
  ret |= PassBlit(WhichVideoBuffer);
 }

 UpdateSoundSync(Buffer, Count);

 GameThread_HandleEvents();
 Input_Update();

 if(RemoteOn)
  CheckForSTDIOMessages();	// Note: This function may change settings, and disable sound.

 if(true == sc_blit_timesync)
 {
  //puts("NORMAL");
  ret |= PassBlit(WhichVideoBuffer);
 }

 return(ret);
}

void Mednafen::MDFND_SetStateStatus(StateStatusStruct *status) noexcept
{
 SendCEvent(CEVT_SET_STATE_STATUS, status, NULL);
}

void Mednafen::MDFND_SetMovieStatus(StateStatusStruct *status) noexcept
{
 SendCEvent(CEVT_SET_MOVIE_STATUS, status, NULL);
}

