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

#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <trio/trio.h>
#include <locale.h>

#include "input.h"
#include "Joystick.h"
#include "video.h"
#include "sound.h"
//#include "fps.h"
//#include "video-state.h"
#include "ers.h"
#include <math.h>

JoystickManager *joy_manager = NULL;
bool pending_save_state, pending_snapshot, pending_save_movie;
static bool ffnosound;

static MDFNSetting_EnumList VDriver_List[] =
{
 { "vga", 0/*VDRIVER_VGA*/, "VGA", gettext_noop("8-bit VGA.") },

 //{ "vbe3", VDRIVER_SOFTSDL, "VBE 3.0", gettext_noop("VESA BIOS Extensions 3.0") },

 { NULL, 0 },
};

static MDFNSetting_EnumList SDriver_List[] =
{
 { "default", -1, "Default", gettext_noop("Default sound driver.") },

 { "es1370", -1, "ES1370", gettext_noop("Ensoniq ES1370.  Used on the \"AudioPCI\", and some other PCI \"Sound Blaster\"-branded cards.") },
 { "es1371", -1, "ES1371", gettext_noop("Ensoniq ES1371/ES1373/CT5880.  Used on the \"AudioPCI 97\", and many other PCI \"Sound Blaster\" and \"Vibra\"-branded cards.") },

 { "cmi8738", -1, "CMI8738", gettext_noop("C-Media CMI-8738.") },

 { "sb", -1, "Sound Blaster", gettext_noop("ISA Sound Blaster cards; Sound Blaster 2.0, Pro, 16, AWE32, AWE64, etc.") },

 { NULL, 0 },
};

static std::vector <MDFNSetting> NeoDriverSettings;
static MDFNSetting DriverSettings[] =
{
  { "input.joystick.axis_threshold", MDFNSF_NOFLAGS, gettext_noop("Analog axis binary press detection threshold."), gettext_noop("Threshold for detecting a digital-like \"button\" press on analog axis, in percent."), MDFNST_FLOAT, "75", "0", "100" },
  { "input.autofirefreq", MDFNSF_NOFLAGS, gettext_noop("Auto-fire frequency."), gettext_noop("Auto-fire frequency = GameSystemFrameRateHz / (value + 1)"), MDFNST_UINT, "3", "0", "1000" },
  { "input.ckdelay", MDFNSF_NOFLAGS, gettext_noop("Dangerous key action delay."), gettext_noop("The length of time, in milliseconds, that a button/key corresponding to a \"dangerous\" command like power, reset, exit, etc. must be pressed before the command is executed."), MDFNST_UINT, "0", "0", "99999" },

  { "video.driver", MDFNSF_NOFLAGS, gettext_noop("Video output method/driver."), NULL, MDFNST_ENUM, "vga", NULL, NULL, NULL,NULL, VDriver_List },

  { "video.frameskip", MDFNSF_NOFLAGS, gettext_noop("Enable frameskip during emulation rendering."), 
					gettext_noop("Disable for rendering code performance testing."), MDFNST_BOOL, "1" },

  { "ffspeed", MDFNSF_NOFLAGS, gettext_noop("Fast-forwarding speed multiplier."), NULL, MDFNST_FLOAT, "4", "1", "15" },
  { "fftoggle", MDFNSF_NOFLAGS, gettext_noop("Treat the fast-forward button as a toggle."), NULL, MDFNST_BOOL, "0" },
  { "ffnosound", MDFNSF_NOFLAGS, gettext_noop("Silence sound output when fast-forwarding."), NULL, MDFNST_BOOL, "0" },

  { "sfspeed", MDFNSF_NOFLAGS, gettext_noop("SLOW-forwarding speed multiplier."), NULL, MDFNST_FLOAT, "0.75", "0.25", "1" },
  { "sftoggle", MDFNSF_NOFLAGS, gettext_noop("Treat the SLOW-forward button as a toggle."), NULL, MDFNST_BOOL, "0" },

  { "nothrottle", MDFNSF_NOFLAGS, gettext_noop("Disable speed throttling when sound is disabled."), NULL, MDFNST_BOOL, "0"},
  { "autosave", MDFNSF_NOFLAGS, gettext_noop("Automatic load/save state on game load/save."), gettext_noop("Automatically save and load save states when a game is closed or loaded, respectively."), MDFNST_BOOL, "0"},
  { "sound.driver", MDFNSF_NOFLAGS, gettext_noop("Select sound driver."), gettext_noop("The following choices are possible, sorted by preference, high to low, when \"default\" driver is used, but dependent on being compiled in."), MDFNST_ENUM, "default", NULL, NULL, NULL, NULL, SDriver_List },
  { "sound.device", MDFNSF_NOFLAGS, gettext_noop("Select sound output device."), gettext_noop("When using ALSA sound output under Linux, the \"sound.device\" setting \"default\" is Mednafen's default, IE \"hw:0\", not ALSA's \"default\". If you want to use ALSA's \"default\", use \"sexyal-literal-default\"."), MDFNST_STRING, "default", NULL, NULL },
  { "sound.volume", MDFNSF_NOFLAGS, gettext_noop("Sound volume level, in percent."), gettext_noop("Setting this volume control higher than the default of \"100\" may severely distort the sound."), MDFNST_UINT, "100", "0", "150" },
  { "sound", MDFNSF_NOFLAGS, gettext_noop("Enable sound output."), NULL, MDFNST_BOOL, "1" },
  { "sound.period_time", MDFNSF_NOFLAGS, gettext_noop("Desired period size in microseconds."), gettext_noop("Currently only affects OSS, ALSA, WASAPI, and SDL output.  A value of 0 defers to the default in the driver code in SexyAL.\n\nNote: This is not the \"sound buffer size\" setting, that would be \"sound.buffer_time\"."), MDFNST_UINT,  "0", "0", "100000" },
  { "sound.buffer_time", MDFNSF_NOFLAGS, gettext_noop("Desired total buffer size in milliseconds."), NULL, MDFNST_UINT, "32", "1", "1000" },
  { "sound.rate", MDFNSF_NOFLAGS, gettext_noop("Specifies the sound playback rate, in sound frames per second(\"Hz\")."), NULL, MDFNST_UINT, "48000", "22050", "192000"},

  { "osd.state_display_time", MDFNSF_NOFLAGS, gettext_noop("The length of time, in milliseconds, to display the save state or the movie selector after selecting a state or movie."),  NULL, MDFNST_UINT, "2000", "0", "15000" },
  { "osd.alpha_blend", MDFNSF_NOFLAGS, gettext_noop("Enable alpha blending for OSD elements."), NULL, MDFNST_BOOL, "1" },
};

static char *DrBaseDirectory;

MDFNGI *CurGame=NULL;

void MDFND_PrintError(const char *s)
{
 puts(s);
 fflush(stdout);
}

void MDFND_Message(const char *s)
{
 fputs(s,stdout);
 fflush(stdout);
}

// CreateDirs should make sure errno is intact after calling mkdir() if it fails.
static bool CreateDirs(void)
{
 const char *subs[7] = { "mcs", "mcm", "snaps", "palettes", "sav", "cheats", "firmware" };
 char *tdir;

 if(MDFN_mkdir(DrBaseDirectory, S_IRWXU) == -1 && errno != EEXIST)
 {
  return(FALSE);
 }

 for(unsigned int x = 0; x < sizeof(subs) / sizeof(const char *); x++)
 {
  tdir = trio_aprintf("%s" PSS "%s",DrBaseDirectory,subs[x]);
  if(MDFN_mkdir(tdir, S_IRWXU) == -1 && errno != EEXIST)
  {
   free(tdir);
   return(FALSE);
  }
  free(tdir);
 }

 return(TRUE);
}

#if defined(HAVE_SIGNAL) || defined(HAVE_SIGACTION)

static const char *SiginfoString = NULL;
static bool volatile SignalSafeExitWanted = false;
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
  act.sa_flags = 0;
  #ifdef SA_RESTART
  act.sa_flags |= SA_RESTART;
  #endif

  sigaction(SignalDefs[x].number, &act, NULL);
  #else
  signal(SignalDefs[x].number, t);
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
#endif

static ARGPSTRUCT *MDFN_Internal_Args = NULL;

static int HokeyPokeyFallDown(const char *name, const char *value)
{
 if(!MDFNI_SetSetting(name, value))
  return(0);
 return(1);
}

static void DeleteInternalArgs(void)
{
 if(!MDFN_Internal_Args) return;
 ARGPSTRUCT *argptr = MDFN_Internal_Args;

 do
 {
  free((void*)argptr->name);
  argptr++;
 } while(argptr->name || argptr->var || argptr->subs);
 free(MDFN_Internal_Args);
 MDFN_Internal_Args = NULL;
}

static void MakeMednafenArgsStruct(void)
{
 const std::multimap <uint32, MDFNCS> *settings;
 std::multimap <uint32, MDFNCS>::const_iterator sit;

 settings = MDFNI_GetSettings();

 MDFN_Internal_Args = (ARGPSTRUCT *)malloc(sizeof(ARGPSTRUCT) * (1 + settings->size()));

 unsigned int x = 0;

 for(sit = settings->begin(); sit != settings->end(); sit++)
 {
  MDFN_Internal_Args[x].name = strdup(sit->second.name);
  MDFN_Internal_Args[x].description = _(sit->second.desc->description);
  MDFN_Internal_Args[x].var = NULL;
  MDFN_Internal_Args[x].subs = (void *)HokeyPokeyFallDown;
  MDFN_Internal_Args[x].substype = SUBSTYPE_FUNCTION;
  x++;
 }
 MDFN_Internal_Args[x].name = NULL;
 MDFN_Internal_Args[x].var = NULL;
 MDFN_Internal_Args[x].subs = NULL;
}

static char* loadcd = NULL;	// Deprecated
static int physcd = 0;

static char * force_module_arg = NULL;
static int DoArgs(int argc, char *argv[], char **filename)
{
	int ShowCLHelp = 0;

	char *dsfn = NULL;
	char *dmfn = NULL;

        ARGPSTRUCT MDFNArgs[] = 
	{
	 { "help", _("Show help!"), &ShowCLHelp, 0, 0 },

	 // -loadcd is deprecated and only still supported because it's been around for yeaaaars.
	 { "loadcd", NULL/*_("Load and boot a CD for the specified system.")*/, 0, &loadcd, SUBSTYPE_STRING_ALLOC },

	 { "physcd", _("Load and boot from a physical CD, treating [FILE] as the optional device name."), &physcd, 0, 0 },

	 { "force_module", _("Force usage of specified emulation module."), 0, &force_module_arg, SUBSTYPE_STRING_ALLOC },

	 { "dump_settings_def", _("Dump settings definition data to specified file."), 0, &dsfn, SUBSTYPE_STRING_ALLOC },
	 { "dump_modules_def", _("Dump modules definition data to specified file."), 0, &dmfn, SUBSTYPE_STRING_ALLOC },

         { 0, NULL, (int *)MDFN_Internal_Args, 0, 0},

	 { 0, 0, 0, 0 }
        };

	const char *usage_string = _("Usage: %s [OPTION]... [FILE]\n");
	if(argc <= 1)
	{
	 printf(_("No command-line arguments specified.\n\n"));
	 printf(usage_string, argv[0]);
	 printf(_("\tPlease refer to the documentation for option parameters and usage.\n\n"));
	 return(0);
	}
	else
	{
	 if(!ParseArguments(argc - 1, &argv[1], MDFNArgs, filename))
	  return(0);

	 if(ShowCLHelp)
	 {
          printf(usage_string, argv[0]);
          ShowArgumentsHelp(MDFNArgs, false);
	  printf("\n");
	  printf(_("Each setting(listed in the documentation) can also be passed as an argument by prefixing the name with a hyphen,\nand specifying the value to change the setting to as the next argument.\n\n"));
	  printf(_("For example:\n\t%s -pce.stretch aspect -pce.pixshader autoipsharper \"Hyper Bonk Soldier.pce\"\n\n"), argv[0]);
	  printf(_("Settings specified in this manner are automatically saved to the configuration file, hence they\ndo not need to be passed to future invocations of the Mednafen executable.\n"));
	  printf("\n");
	  return(0);
	 }

	 if(dsfn)
	  MDFNI_DumpSettingsDef(dsfn);

	 if(dmfn)
	  MDFNI_DumpModulesDef(dmfn);

	 if(dsfn || dmfn)
	  return(0);

	 if(*filename == NULL && loadcd == NULL && physcd == 0)
	 {
	  MDFN_PrintError(_("No game filename specified!"));
	  return(0);
	 }
	}
	return(1);
}

bool MDFND_Update(MDFN_Surface *surface, MDFN_Rect *rect, MDFN_Rect *lw, int16 *Buffer, int Count);

bool sound_active;	// true if sound is enabled and initialized


static EmuRealSyncher ers;

static int LoadGame(const char *force_module, const char *path)
{
	MDFNGI *tmp;

	CloseGame();

	pending_save_state = 0;
	pending_save_movie = 0;
	pending_snapshot = 0;

	if(physcd)
	{
	 if(!(tmp = MDFNI_LoadCD(force_module, path, true)))
		return(0);
	}
	else if(loadcd)	// Deprecated
	{
	 const char *system = loadcd;
         bool is_physical = false;

	 if(!system)
	  system = force_module;

	 if(path == NULL)
	  is_physical = true;
	 else
	 {
	  int sr;
	  //int se;
	  struct stat sb;

	  sr = stat(path, &sb);
	  //se = errno;	  

	  if(!sr && !S_ISREG(sb.st_mode))
	  //if(sr || !S_ISREG(sb.st_mode))
	   is_physical = true;
	 }

	 if(!(tmp = MDFNI_LoadCD(system, path, is_physical)))
		return(0);
	}
	else
	{
         if(!(tmp=MDFNI_LoadGame(force_module, path)))
	  return 0;
	}
	CurGame = tmp;
	//InitGameInput(tmp);
	//InitCommandInput(tmp);

        RefreshThrottleFPS(1);

        if(MDFN_GetSettingB("autosave"))
	 MDFNI_LoadState(NULL, "mcq");

	ers.SetEmuClock(CurGame->MasterClock >> 32);

	ffnosound = MDFN_GetSettingB("ffnosound");

	return 1;
}

/* Closes a game and frees memory. */
int CloseGame(void)
{
	if(!CurGame)
         return(0);

	if(MDFN_GetSettingB("autosave"))
	 MDFNI_SaveState(NULL, "mcq", NULL, NULL, NULL);

	MDFNI_CloseGame();

	//KillCommandInput();
        //KillGameInput();

	CurGame = NULL;

	return(1);
}

static int NeedExitNow = 0;
double CurGameSpeed = 1;

void MainRequestExit(void)
{
 NeedExitNow = 1;
}

static void UpdateSoundSync(int16 *Buffer, int Count)
{
 if(Count)
 {
  if(ffnosound && CurGameSpeed != 1)
  {
   for(int x = 0; x < Count * CurGame->soundchan; x++)
    Buffer[x] = 0;
  }
  int32 max = GetWriteSound();

  if(Count >= (max * 0.95))
  {
   ers.SetETtoRT();
  }

  WriteSound(Buffer, Count);
 }
 else
 {
  bool nothrottle = MDFN_GetSettingB("nothrottle");

  if(!nothrottle)
   ers.Sync();
 }
}

void MDFND_MidSync(const EmulateSpecStruct *espec)
{
 ers.AddEmuTime((espec->MasterCycles - espec->MasterCyclesALMS) / CurGameSpeed, false);

 UpdateSoundSync(espec->SoundBuf + (espec->SoundBufSizeALMS * CurGame->soundchan), espec->SoundBufSize - espec->SoundBufSizeALMS);

 //MDFND_UpdateInput(true, false);
}

static void MainLoop(void)
{
	while(!NeedExitNow && !SignalSafeExitWanted)
	{
	 EmulateSpecStruct espec;
         int fskip;

	 memset(&espec, 0, sizeof(EmulateSpecStruct));

	 fskip = ers.NeedFrameSkip();
	
	 if(!MDFN_GetSettingB("video.frameskip"))
	  fskip = 0;

	 if(pending_snapshot || pending_save_state || pending_save_movie)
	  fskip = 0;

	 Video_GetSurface(&espec.surface, &espec.LineWidths);
	 espec.LineWidths[0].w = ~0;
	 espec.skip = fskip;
	 espec.soundmultiplier = CurGameSpeed;
	 espec.NeedRewind = false; //DNeedRewind;

 	 espec.SoundRate = GetSoundRate();
	 espec.SoundBuf = GetEmuModSoundBuffer(&espec.SoundBufMaxSize);
 	 espec.SoundVolume = (double)MDFN_GetSettingUI("sound.volume") / 100;

         MDFNI_Emulate(&espec);

	 ers.AddEmuTime((espec.MasterCycles - espec.MasterCyclesALMS) / CurGameSpeed);

	 //FPS_IncVirtual();
	 //if(!fskip)
	 // FPS_IncDrawn();

	 UpdateSoundSync(espec.SoundBuf + (espec.SoundBufSizeALMS * CurGame->soundchan), espec.SoundBufSize - espec.SoundBufSizeALMS);

	 //MDFND_UpdateInput();

	 if(!fskip)	
	 {
	  if(pending_snapshot)
	   MDFNI_SaveSnapshot(espec.surface, &espec.DisplayRect, espec.LineWidths);

	  if(pending_save_state)
	   MDFNI_SaveState(NULL, NULL, espec.surface, &espec.DisplayRect, espec.LineWidths);

	  if(pending_save_movie)
	   MDFNI_SaveMovie(NULL, espec.surface, &espec.DisplayRect, espec.LineWidths);

	  pending_save_movie = pending_snapshot = pending_save_state = 0;

	  Video_Blit(&espec);
	 }
	}
}   

char* GetBaseDirectory(const char* argv0)
{
 char *ol;
 char *ret;

 ol = getenv("MEDNAFEN_HOME");
 if(ol != NULL && ol[0] != 0)
 {
  ret = strdup(ol);
  return(ret);
 }

 ol = getenv("HOME");

 if(ol)
 {
  ret=(char *)malloc(strlen(ol)+1+strlen(PSS ".mednafen"));
  strcpy(ret,ol);
  strcat(ret, PSS ".mednafen");
  return(ret);
 }

 #ifdef WIN32
 {
  char *sa;

  ret=(char *)malloc(MAX_PATH+1);
  GetModuleFileName(NULL,ret,MAX_PATH+1);

  sa=strrchr(ret,'\\');
  if(sa)
   *sa = 0;
  return(ret);
 }
 #endif

 #ifdef DOS
 {
  char* s1,* s2;
  
  s1 = strrchr(argv0, '/');
  s2 = strrchr(argv0, '\\');

  if(s1 < s2)
   s1 = s2;

  if(s1 != NULL)
  {
   ret = (char*)malloc(s1 - argv0 + 1);
   memcpy(ret, argv0, s1 - argv0);
   ret[s1 - argv0] = 0;
   return(ret);
  }
 }
 #endif

 ret = (char *)malloc(1);
 ret[0] = 0;
 return(ret);
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
}

#ifdef HAVE_LIBSNDFILE
 #include <sndfile.h>
#endif

void PrintLIBSNDFILEVersion(void)
{
 #ifdef HAVE_LIBSNDFILE
  MDFN_printf(_("Running with %s\n"), sf_version_string());
 #endif
}

void PrintZLIBVersion(void)
{
 #ifdef ZLIB_VERSION
  MDFN_printf(_("Compiled against zlib %s, running with zlib %s\n"), ZLIB_VERSION, zlibVersion());
 #endif
}

int main(int argc, char *argv[])
{
	std::vector<MDFNGI *> ExternalSystems;
	char *needie = NULL;

	DrBaseDirectory = GetBaseDirectory(argv[0]);

	#ifdef ENABLE_NLS
	setlocale(LC_ALL, "");

        bindtextdomain(PACKAGE, DrBaseDirectory);

	bind_textdomain_codeset(PACKAGE, "UTF-8");
	textdomain(PACKAGE);
	#endif

	MDFNI_printf(_("Starting Mednafen %s\n"), MEDNAFEN_VERSION);
	MDFN_indent(1);

        MDFN_printf(_("Build information:\n"));
        MDFN_indent(2);
        PrintCompilerVersion();
        PrintZLIBVersion();
        PrintLIBSNDFILEVersion();
        MDFN_indent(-2);

        MDFN_printf(_("Base directory: %s\n"), DrBaseDirectory);

	if(!MDFNI_InitializeModules(ExternalSystems))
	 return(-1);

	for(unsigned int x = 0; x < sizeof(DriverSettings) / sizeof(MDFNSetting); x++)
	 NeoDriverSettings.push_back(DriverSettings[x]);

	//MakeInputSettings(NeoDriverSettings);

        if(!MDFNI_Initialize(DrBaseDirectory, NeoDriverSettings))
         return(-1);

        #if defined(HAVE_SIGNAL) || defined(HAVE_SIGACTION)
        SetSignals(CloseStuff);
        #endif

	if(!CreateDirs())
	{
	 ErrnoHolder ene(errno);	// TODO: Maybe we should have CreateDirs() return this instead?

	 MDFN_PrintError(_("Error creating directories: %s\n"), ene.StrError());
	 MDFNI_Kill();
	 return(-1);
	}

	MakeMednafenArgsStruct();

	if(!DoArgs(argc, argv, &needie))
	{
	 MDFNI_Kill();
	 DeleteInternalArgs();
	 //KillInputSettings();
	 return(-1);
	}

        if(LoadGame(force_module_arg, needie))
	{
	 sound_active = false;
	 if(MDFN_GetSettingB("sound"))
	  sound_active = InitSound(CurGame);

	 // Initialize joysticks after sound, so PCI sound card init code can enable joystick ports(maybe?).
	 joy_manager = new JoystickManager();
	 joy_manager->SetAnalogThreshold(MDFN_GetSettingF("analogthreshold") / 100);

	 // Initialize video after everything else has been initialized.
	 Video_Init(CurGame);

	 MainLoop();

	 Video_Kill();

	 // DESTROY NOM NOM joysticks before sound.
	 delete joy_manager;
	 joy_manager = NULL;

	 KillSound();
	 CloseGame();
	}


	#if defined(HAVE_SIGNAL) || defined(HAVE_SIGACTION)
	SetSignals(SIG_IGN);
	#endif

        MDFNI_Kill();

	DeleteInternalArgs();
	//KillInputSettings();

        return(0);
}



void MDFND_DispMessage(UTF8 *text)
{
 
}

void MDFND_SetStateStatus(StateStatusStruct *status)
{
 
}

void MDFND_SetMovieStatus(StateStatusStruct *status)
{
 
}

uint32 MDFND_GetTime(void)
{
 //return(SDL_GetTicks());
 return(0);
}

void MDFND_Sleep(uint32 ms)
{
 //SDL_Delay(ms);
}

MDFN_Thread *MDFND_CreateThread(int (*fn)(void *), void *data)
{
 return(NULL);
}

void MDFND_WaitThread(MDFN_Thread *thread, int *status)
{

}

MDFN_Mutex *MDFND_CreateMutex(void)
{
 return(NULL);
}

void MDFND_DestroyMutex(MDFN_Mutex *mutex)
{

}

int MDFND_LockMutex(MDFN_Mutex *mutex)
{
 return(false);
}

int MDFND_UnlockMutex(MDFN_Mutex *mutex)
{
 return(false);
}


int MDFND_NetworkConnect(void)
{
 return(0);
}

void MDFND_NetworkClose(void)
{

}

void MDFND_SendData(const void *data, uint32 len)
{

}

void MDFND_RecvData(void *data, uint32 len)
{

}

void MDFND_NetplayText(const uint8 *text, bool NetEcho)
{

}
