#include "main.h"
#include "throttle.h"
#include "config.h"

#include "../common/cheat.h"
#include "../../fceu.h"
#include "../../movie.h"
#include "../../version.h"
#ifdef _S9XLUA_H
#include "../../fceulua.h"
#endif

#include "input.h"
#include "dface.h"

#include "sdl.h"
#include "sdl-video.h"
#include "unix-netplay.h"

#include "../common/configSys.h"
#include "../../oldmovie.h"
#include "../../types.h"

#ifdef CREATE_AVI
#include "../videolog/nesvideos-piece.h"
#endif

#ifdef WIN32
#include <windows.h>
#endif

#ifdef _GTK
#include <gtk/gtk.h>
#include "gui.h"
#endif

#include <unistd.h>
#include <csignal>
#include <cstring>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <climits>
#include <cmath>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <iostream>
#include <fstream>


extern double g_fpsScale;

extern bool MaxSpeed;

int isloaded;

bool turbo = false;

int closeFinishedMovie = 0;

int eoptions=0;

static int inited = 0;

static void DriverKill(void);
static int DriverInitialize(FCEUGI *gi);
uint64 FCEUD_GetTime();
int gametype = 0;
#ifdef CREATE_AVI
int mutecapture;
#endif
static int noconfig;

int pal_emulation;
int dendy;
bool swapDuty;

// -Video Modes Tag- : See --special
static const char *DriverUsage=
"Option         Value   Description\n"
"--pal          {0|1}   Use PAL timing.\n"
"--newppu       {0|1}   Enable the new PPU core. (WARNING: May break savestates)\n"
"--inputcfg     d       Configures input device d on startup.\n"
"--input(1,2)   d       Set which input device to emulate for input 1 or 2.\n"
"                         Devices:  gamepad zapper powerpad.0 powerpad.1\n"
"                         arkanoid\n"
"--input(3,4)   d       Set the famicom expansion device to emulate for\n"
"                       input(3, 4)\n"
"                          Devices: quizking hypershot mahjong toprider ftrainer\n"
"                          familykeyboard oekakids arkanoid shadow bworld\n"
"                          4player\n"
"--gamegenie    {0|1}   Enable emulated Game Genie.\n"
"--frameskip    x       Set # of frames to skip per emulated frame.\n"
"--xres         x       Set horizontal resolution for full screen mode.\n"
"--yres         x       Set vertical resolution for full screen mode.\n"
"--autoscale    {0|1}   Enable autoscaling in fullscreen. \n"
"--keepratio    {0|1}   Keep native NES aspect ratio when autoscaling. \n"
"--(x/y)scale   x       Multiply width/height by x. \n"
"                         (Real numbers >0 with OpenGL, otherwise integers >0).\n"
"--(x/y)stretch {0|1}   Stretch to fill surface on x/y axis (OpenGL only).\n"
"--bpp       {8|16|32}  Set bits per pixel.\n"
"--opengl       {0|1}   Enable OpenGL support.\n"
"--fullscreen   {0|1}   Enable full screen mode.\n"
"--noframe      {0|1}   Hide title bar and window decorations.\n"
"--special      {1-4}   Use special video scaling filters\n"
"                         (1 = hq2x; 2 = Scale2x; 3 = NTSC 2x; 4 = hq3x;\n"
"                         5 = Scale3x; 6 = Prescale2x; 7 = Prescale3x; 8=Precale4x; 9=PAL)\n"
"--palette      f       Load custom global palette from file f.\n"
"--sound        {0|1}   Enable sound.\n"
"--soundrate    x       Set sound playback rate to x Hz.\n"
"--soundq      {0|1|2}  Set sound quality. (0 = Low 1 = High 2 = Very High)\n"
"--soundbufsize x       Set sound buffer size to x ms.\n"
"--volume      {0-256}  Set volume to x.\n"
"--soundrecord  f       Record sound to file f.\n"
"--playmov      f       Play back a recorded FCM/FM2/FM3 movie from filename f.\n"
"--pauseframe   x       Pause movie playback at frame x.\n"
"--fcmconvert   f       Convert fcm movie file f to fm2.\n"
"--ripsubs      f       Convert movie's subtitles to srt\n"
"--subtitles    {0|1}   Enable subtitle display\n"
"--fourscore    {0|1}   Enable fourscore emulation\n"
"--no-config    {0|1}   Use default config file and do not save\n"
"--net          s       Connect to server 's' for TCP/IP network play.\n"
"--port         x       Use TCP/IP port x for network play.\n"
"--user         x       Set the nickname to use in network play.\n"
"--pass         x       Set password to use for connecting to the server.\n"
"--netkey       s       Use string 's' to create a unique session for the\n"
"                       game loaded.\n"
"--players      x       Set the number of local players in a network play\n"
"                       session.\n"
"--rp2mic       {0|1}   Replace Port 2 Start with microphone (Famicom).\n"
"--nogui                Don't load the GTK GUI\n"
"--4buttonexit {0|1}    exit the emulator when A+B+Select+Start is pressed\n"
"--loadstate {0-9|>9}   load from the given state when the game is loaded\n"
"--savestate {0-9|>9}   save to the given state when the game is closed\n"
"                         to not save/load automatically provide a number\n"
"                         greater than 9\n"
"--periodicsaves {0|1}  enable automatic periodic saving.  This will save to\n"
"                         the state passed to --savestate\n";


// these should be moved to the man file
//--nospritelim  {0|1}   Disables the 8 sprites per scanline limitation.\n
//--trianglevol {0-256}  Sets Triangle volume.\n
//--square1vol  {0-256}  Sets Square 1 volume.\n
//--square2vol  {0-256}  Sets Square 2 volume.\n
//--noisevol	{0-256}  Sets Noise volume.\n
//--pcmvol	  {0-256}  Sets PCM volume.\n
//--lowpass	  {0|1}   Enables low-pass filter if x is nonzero.\n
//--doublebuf	{0|1}   Enables SDL double-buffering if x is nonzero.\n
//--slend	  {0-239}   Sets the last drawn emulated scanline.\n
//--ntsccolor	{0|1}   Emulates an NTSC TV's colors.\n
//--hue		   x	  Sets hue for NTSC color emulation.\n
//--tint		  x	  Sets tint for NTSC color emulation.\n
//--slstart	{0-239}   Sets the first drawn emulated scanline.\n
//--clipsides	{0|1}   Clips left and rightmost 8 columns of pixels.\n

// global configuration object
Config *g_config;

static void ShowUsage(char *prog)
{
	printf("\nUsage is as follows:\n%s <options> filename\n\n",prog);
	puts(DriverUsage);
#ifdef _S9XLUA_H
	puts ("--loadlua      f       Loads lua script from filename f.");
#endif
#ifdef CREATE_AVI
	puts ("--videolog     c       Calls mencoder to grab the video and audio streams to\n                         encode them. Check the documentation for more on this.");
	puts ("--mute        {0|1}    Mutes FCEUX while still passing the audio stream to\n                         mencoder during avi creation.");
#endif
	puts("");
	printf("Compiled with SDL version %d.%d.%d\n", SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL );
#if SDL_VERSION_ATLEAST(2, 0, 0)
	SDL_version* v; 
	SDL_GetVersion(v);
#else
	const SDL_version* v = SDL_Linked_Version();
#endif
	printf("Linked with SDL version %d.%d.%d\n", v->major, v->minor, v->patch);
#ifdef GTK
	printf("Compiled with GTK version %d.%d.%d\n", GTK_MAJOR_VERSION, GTK_MINOR_VERSION, GTK_MICRO_VERSION );
	//printf("Linked with GTK version %d.%d.%d\n", GTK_MAJOR_VERSION, GTK_MINOR_VERSION, GTK_MICRO_VERSION );
#endif
	
}

/**
 * Loads a game, given a full path/filename.  The driver code must be
 * initialized after the game is loaded, because the emulator code
 * provides data necessary for the driver code(number of scanlines to
 * render, what virtual input devices to use, etc.).
 */
int LoadGame(const char *path)
{
    if (isloaded){
        CloseGame();
    }
	if(!FCEUI_LoadGame(path, 1)) {
		return 0;
	}

    int state_to_load;
    g_config->getOption("SDL.AutoLoadState", &state_to_load);
    if (state_to_load >= 0 && state_to_load < 10){
        FCEUI_SelectState(state_to_load, 0);
        FCEUI_LoadState(NULL, false);
    }

	ParseGIInput(GameInfo);
	RefreshThrottleFPS();

	if(!DriverInitialize(GameInfo)) {
		return(0);
	}
	
	// set pal/ntsc
	int id;
	g_config->getOption("SDL.PAL", &id);
	FCEUI_SetRegion(id);

	g_config->getOption("SDL.SwapDuty", &id);
	swapDuty = id;
	
	std::string filename;
	g_config->getOption("SDL.Sound.RecordFile", &filename);
	if(filename.size()) {
		if(!FCEUI_BeginWaveRecord(filename.c_str())) {
			g_config->setOption("SDL.Sound.RecordFile", "");
		}
	}
	isloaded = 1;

	FCEUD_NetworkConnect();
	return 1;
}

/**
 * Closes a game.  Frees memory, and deinitializes the drivers.
 */
int
CloseGame()
{
	std::string filename;

	if(!isloaded) {
		return(0);
	}

    int state_to_save;
    g_config->getOption("SDL.AutoSaveState", &state_to_save);
    if (state_to_save < 10 && state_to_save >= 0){
        FCEUI_SelectState(state_to_save, 0);
        FCEUI_SaveState(NULL, false);
    }
	FCEUI_CloseGame();

	DriverKill();
	isloaded = 0;
	GameInfo = 0;

	g_config->getOption("SDL.Sound.RecordFile", &filename);
	if(filename.size()) {
		FCEUI_EndWaveRecord();
	}

	InputUserActiveFix();
	return(1);
}

void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count);

static void DoFun(int frameskip, int periodic_saves)
{
	uint8 *gfx;
	int32 *sound;
	int32 ssize;
	static int fskipc = 0;
	static int opause = 0;

    //TODO peroidic saves, working on it right now
    if (periodic_saves && FCEUD_GetTime() % PERIODIC_SAVE_INTERVAL < 30){
        FCEUI_SaveState(NULL, false);
    }
#ifdef FRAMESKIP
	fskipc = (fskipc + 1) % (frameskip + 1);
#endif

	if(NoWaiting) {
		gfx = 0;
	}
	FCEUI_Emulate(&gfx, &sound, &ssize, fskipc);
	FCEUD_Update(gfx, sound, ssize);

	if(opause!=FCEUI_EmulationPaused()) {
		opause=FCEUI_EmulationPaused();
		SilenceSound(opause);
	}
}


/**
 * Initialize all of the subsystem drivers: video, audio, and joystick.
 */
static int
DriverInitialize(FCEUGI *gi)
{
	if(InitVideo(gi) < 0) return 0;
	inited|=4;

	if(InitSound())
		inited|=1;

	if(InitJoysticks())
		inited|=2;

	int fourscore=0;
	g_config->getOption("SDL.FourScore", &fourscore);
	eoptions &= ~EO_FOURSCORE;
	if(fourscore)
		eoptions |= EO_FOURSCORE;

	InitInputInterface();
	return 1;
}

/**
 * Shut down all of the subsystem drivers: video, audio, and joystick.
 */
static void
DriverKill()
{
	if (!noconfig)
		g_config->save();

	if(inited&2)
		KillJoysticks();
	if(inited&4)
		KillVideo();
	if(inited&1)
		KillSound();
	inited=0;
}

/**
 * Update the video, audio, and input subsystems with the provided
 * video (XBuf) and audio (Buffer) information.
 */
void
FCEUD_Update(uint8 *XBuf,
			 int32 *Buffer,
			 int Count)
{
	extern int FCEUDnetplay;

	#ifdef CREATE_AVI
	if(LoggingEnabled == 2 || (eoptions&EO_NOTHROTTLE))
	{
	  if(LoggingEnabled == 2)
	  {
		int16* MonoBuf = new int16[Count];
		int n;
		for(n=0; n<Count; ++n)
			MonoBuf[n] = Buffer[n] & 0xFFFF;
		NESVideoLoggingAudio
		 (
		  MonoBuf, 
		  FSettings.SndRate, 16, 1,
		  Count
		 );
		delete [] MonoBuf;
	  }
	  Count /= 2;
	  if(inited & 1)
	  {
		if(Count > GetWriteSound()) Count = GetWriteSound();
		if (!mutecapture)
		  if(Count > 0 && Buffer) WriteSound(Buffer,Count);   
	  }
	  if(inited & 2)
		FCEUD_UpdateInput();
	  if(XBuf && (inited & 4)) BlitScreen(XBuf);
	  
	  //SpeedThrottle();
		return;
	 }
	#endif
	
	int ocount = Count;
	// apply frame scaling to Count
	Count = (int)(Count / g_fpsScale);
	if(Count) {
		int32 can=GetWriteSound();
		static int uflow=0;
		int32 tmpcan;

		// don't underflow when scaling fps
		if(can >= GetMaxSound() && g_fpsScale==1.0) uflow=1;	/* Go into massive underflow mode. */

		if(can > Count) can=Count;
		else uflow=0;

		#ifdef CREATE_AVI
		if (!mutecapture)
		#endif
		  WriteSound(Buffer,can);

		//if(uflow) puts("Underflow");
		tmpcan = GetWriteSound();
		// don't underflow when scaling fps
		if(g_fpsScale>1.0 || ((tmpcan < Count*0.90) && !uflow)) {
			if(XBuf && (inited&4) && !(NoWaiting & 2))
				BlitScreen(XBuf);
			Buffer+=can;
			Count-=can;
			if(Count) {
				if(NoWaiting) {
					can=GetWriteSound();
					if(Count>can) Count=can;
					#ifdef CREATE_AVI
					if (!mutecapture)
					#endif
					  WriteSound(Buffer,Count);
				} else {
					while(Count>0) {
						#ifdef CREATE_AVI
						if (!mutecapture)
						#endif
						  WriteSound(Buffer,(Count<ocount) ? Count : ocount);
						Count -= ocount;
					}
				}
			}
		} //else puts("Skipped");
		else if(!NoWaiting && FCEUDnetplay && (uflow || tmpcan >= (Count * 1.8))) {
			if(Count > tmpcan) Count=tmpcan;
			while(tmpcan > 0) {
				//	printf("Overwrite: %d\n", (Count <= tmpcan)?Count : tmpcan);
				#ifdef CREATE_AVI
				if (!mutecapture)
				#endif
				  WriteSound(Buffer, (Count <= tmpcan)?Count : tmpcan);
				tmpcan -= Count;
			}
		}

	} else {
		if(!NoWaiting && (!(eoptions&EO_NOTHROTTLE) || FCEUI_EmulationPaused()))
		while (SpeedThrottle())
		{
			FCEUD_UpdateInput();
		}
		if(XBuf && (inited&4)) {
			BlitScreen(XBuf);
		}
	}
	FCEUD_UpdateInput();
	//if(!Count && !NoWaiting && !(eoptions&EO_NOTHROTTLE))
	// SpeedThrottle();
	//if(XBuf && (inited&4))
	//{
	// BlitScreen(XBuf);
	//}
	//if(Count)
	// WriteSound(Buffer,Count,NoWaiting);
	//FCEUD_UpdateInput();
}

/**
 * Opens a file to be read a byte at a time.
 */
EMUFILE_FILE* FCEUD_UTF8_fstream(const char *fn, const char *m)
{
	std::ios_base::openmode mode = std::ios_base::binary;
	if(!strcmp(m,"r") || !strcmp(m,"rb"))
		mode |= std::ios_base::in;
	else if(!strcmp(m,"w") || !strcmp(m,"wb"))
		mode |= std::ios_base::out | std::ios_base::trunc;
	else if(!strcmp(m,"a") || !strcmp(m,"ab"))
		mode |= std::ios_base::out | std::ios_base::app;
	else if(!strcmp(m,"r+") || !strcmp(m,"r+b"))
		mode |= std::ios_base::in | std::ios_base::out;
	else if(!strcmp(m,"w+") || !strcmp(m,"w+b"))
		mode |= std::ios_base::in | std::ios_base::out | std::ios_base::trunc;
	else if(!strcmp(m,"a+") || !strcmp(m,"a+b"))
		mode |= std::ios_base::in | std::ios_base::out | std::ios_base::app;
    return new EMUFILE_FILE(fn, m);
	//return new std::fstream(fn,mode);
}

/**
 * Opens a file, C++ style, to be read a byte at a time.
 */
FILE *FCEUD_UTF8fopen(const char *fn, const char *mode)
{
	return(fopen(fn,mode));
}

static char *s_linuxCompilerString = "g++ " __VERSION__;
/**
 * Returns the compiler string.
 */
const char *FCEUD_GetCompilerString() {
	return (const char *)s_linuxCompilerString;
}

/**
 * Unimplemented.
 */
void FCEUD_DebugBreakpoint() {
	return;
}

/**
 * Unimplemented.
 */
void FCEUD_TraceInstruction() {
	return;
}


#ifdef _GTK
	int noGui = 0;
#else
	int noGui = 1;
#endif


/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[])
{
  // this is a hackish check for the --help arguemnts
  // these are normally processed by the config parser, but SDL_Init
  // must be run before the config parser: so if even SDL_Init fails,
  // these six lines will still print the help output
	if(argc > 1)
	{
		if(!strcmp(argv[1], "--help") || !strcmp(argv[1],"-h"))
		{
            ShowUsage(argv[0]);
			return 0;
		}
	}

	int error, frameskip;

	FCEUD_Message("Starting " FCEU_NAME_AND_VERSION "...\n");

#ifdef WIN32
	/* Taken from win32 sdl_main.c */
	SDL_SetModuleHandle(GetModuleHandle(NULL));
#endif

	/* SDL_INIT_VIDEO Needed for (joystick config) event processing? */
	if(SDL_Init(SDL_INIT_VIDEO)) {
		printf("Could not initialize SDL: %s.\n", SDL_GetError());
		return(-1);
	}

#ifdef OPENGL
	SDL_GL_LoadLibrary(0);
#endif

	// Initialize the configuration system
	g_config = InitConfig();
		
	if(!g_config) {
		SDL_Quit();
		return -1;
	}

	// initialize the infrastructure
	error = FCEUI_Initialize();
	if(error != 1) {
		ShowUsage(argv[0]);
		SDL_Quit();
		return -1;
	}
	
	// check for --help or -h and display usage; also check for --nogui
	for(int i=0; i<argc;i++)
	{
		if(strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0)
		{
			ShowUsage(argv[0]);
			SDL_Quit();
			return 0;
		}
#ifdef _GTK
		else if(strcmp(argv[i], "--nogui") == 0)
		{
			noGui = 1;
			argv[i] = "";
		}
#endif
	}
	int romIndex = g_config->parse(argc, argv);

	// This is here so that a default fceux.cfg will be created on first
	// run, even without a valid ROM to play.
	// Unless, of course, there's actually --no-config given
	// mbg 8/23/2008 - this is also here so that the inputcfg routines can have 
    // a chance to dump the new inputcfg to the fceux.cfg  in case you didnt 
    // specify a rom  filename
	g_config->getOption("SDL.NoConfig", &noconfig);
	if (!noconfig)
		g_config->save();
	
	std::string s;

	g_config->getOption("SDL.InputCfg", &s);
	if(s.size() != 0)
	{
	InitVideo(GameInfo);
	InputCfg(s);
	}
	// set the FAMICOM PAD 2 Mic thing 
	{
	int t;
	g_config->getOption("SDL.Input.FamicomPad2.EnableMic", &t);
		if(t)
			replaceP2StartWithMicrophone = t;
	}

    // update the input devices
	UpdateInput(g_config);

	// check if opengl is enabled with a scaler and display an error and bail	
	int opengl;
	int scaler;
	g_config->getOption("SDL.OpenGL", &opengl);
	g_config->getOption("SDL.SpecialFilter", &scaler);
	if(opengl && scaler)
	{
		printf("Scalers are not supported in OpenGL mode.  Terminating.\n");
		exit(2);
	}


	// check for a .fcm file to convert to .fm2
	g_config->getOption ("SDL.FCMConvert", &s);
	g_config->setOption ("SDL.FCMConvert", "");
	if (!s.empty())
	{
		int okcount = 0;
		std::string infname = s.c_str();
		// produce output filename
		std::string outname;
		size_t dot = infname.find_last_of (".");
		if (dot == std::string::npos)
			outname = infname + ".fm2";
		else
			outname = infname.substr(0,dot) + ".fm2";
	  
		MovieData md;
		EFCM_CONVERTRESULT result = convert_fcm (md, infname);

		if (result == FCM_CONVERTRESULT_SUCCESS) {
			okcount++;
        // *outf = new EMUFILE;
		EMUFILE_FILE* outf = FCEUD_UTF8_fstream (outname, "wb");
		md.dump (outf,false);
		delete outf;
		FCEUD_Message ("Your file has been converted to FM2.\n");
	}
	else {
		FCEUD_Message ("Something went wrong while converting your file...\n");
	}
	  
	DriverKill();
	  SDL_Quit();
	  return 0;
	}

	// If x/y res set to 0, store current display res in SDL.LastX/YRes
	int yres, xres;
	g_config->getOption("SDL.XResolution", &xres);
	g_config->getOption("SDL.YResolution", &yres);
#if SDL_VERSION_ATLEAST(2, 0, 0)
	// TODO _ SDL 2.0
#else
	const SDL_VideoInfo* vid_info = SDL_GetVideoInfo();
	if(xres == 0) 
    {
        if(vid_info != NULL)
        {
			g_config->setOption("SDL.LastXRes", vid_info->current_w);
        }
        else
        {
			g_config->setOption("SDL.LastXRes", 512);
        }
    }
	else
	{
		g_config->setOption("SDL.LastXRes", xres);
	}	
    if(yres == 0)
    {
        if(vid_info != NULL)
        {
			g_config->setOption("SDL.LastYRes", vid_info->current_h);
        }
        else
        {
			g_config->setOption("SDL.LastYRes", 448);
        }
    } 
	else
	{
		g_config->setOption("SDL.LastYRes", yres);
	}
#endif
	
	int autoResume;
	g_config->getOption("SDL.AutoResume", &autoResume);
	if(autoResume)
	{
		AutoResumePlay = true;
	}
	else
	{
		AutoResumePlay = false;
	}
	// check to see if recording HUD to AVI is enabled
	int rh;
	g_config->getOption("SDL.RecordHUD", &rh);
	if( rh == 0)
		FCEUI_SetAviEnableHUDrecording(true);
	else
		FCEUI_SetAviEnableHUDrecording(false);

	// check to see if movie messages are disabled
	int mm;
	g_config->getOption("SDL.MovieMsg", &mm);
	if( mm == 0)
		FCEUI_SetAviDisableMovieMessages(true);
	else
		FCEUI_SetAviDisableMovieMessages(false);
	
	
	// check for a .fm2 file to rip the subtitles
	g_config->getOption("SDL.RipSubs", &s);
	g_config->setOption("SDL.RipSubs", "");
	if (!s.empty())
	{
		MovieData md;
		std::string infname;
		infname = s.c_str();
		FCEUFILE *fp = FCEU_fopen(s.c_str(), 0, "rb", 0);
		
		// load the movie and and subtitles
		extern bool LoadFM2(MovieData&, EMUFILE*, int, bool);
		LoadFM2(md, fp->stream, INT_MAX, false);
		LoadSubtitles(md); // fill subtitleFrames and subtitleMessages
		delete fp;
		
		// produce .srt file's name and open it for writing
		std::string outname;
		size_t dot = infname.find_last_of (".");
		if (dot == std::string::npos)
			outname = infname + ".srt";
		else
			outname = infname.substr(0,dot) + ".srt";
		FILE *srtfile;
		srtfile = fopen(outname.c_str(), "w");
		
		if (srtfile != NULL)
		{
			extern std::vector<int> subtitleFrames;
			extern std::vector<std::string> subtitleMessages;
			float fps = (md.palFlag == 0 ? 60.0988 : 50.0069); // NTSC vs PAL
			float subduration = 3; // seconds for the subtitles to be displayed
			for (int i = 0; i < subtitleFrames.size(); i++)
			{
				fprintf(srtfile, "%i\n", i+1); // starts with 1, not 0
				double seconds, ms, endseconds, endms;
				seconds = subtitleFrames[i]/fps;
				if (i+1 < subtitleFrames.size()) // there's another subtitle coming after this one
				{
					if (subtitleFrames[i+1]-subtitleFrames[i] < subduration*fps) // avoid two subtitles at the same time
					{
						endseconds = (subtitleFrames[i+1]-1)/fps; // frame x: subtitle1; frame x+1 subtitle2
					} else {
						endseconds = seconds+subduration;
							}
				} else {
					endseconds = seconds+subduration;
				}
				ms = modf(seconds, &seconds);
				endms = modf(endseconds, &endseconds);
				// this is just beyond ugly, don't show it to your kids
				fprintf(srtfile,
				"%02.0f:%02d:%02d,%03d --> %02.0f:%02d:%02d,%03d\n", // hh:mm:ss,ms --> hh:mm:ss,ms
				floor(seconds/3600),	(int)floor(seconds/60   ) % 60, (int)floor(seconds)	% 60, (int)(ms*1000),
				floor(endseconds/3600), (int)floor(endseconds/60) % 60, (int)floor(endseconds) % 60, (int)(endms*1000));
				fprintf(srtfile, "%s\n\n", subtitleMessages[i].c_str()); // new line for every subtitle
			}
		fclose(srtfile);
		printf("%d subtitles have been ripped.\n", (int)subtitleFrames.size());
		} else {
		FCEUD_Message("Couldn't create output srt file...\n");
		}
	  
		DriverKill();
		SDL_Quit();
		return 0;
	}
   

	// if we're not compiling w/ the gui, exit if a rom isn't specified
#ifndef _GTK
	if(romIndex <= 0) {
		
		ShowUsage(argv[0]);
		FCEUD_Message("\nError parsing command line arguments\n");
		SDL_Quit();
		return -1;
	}
#endif
	

	// update the emu core
	UpdateEMUCore(g_config);

	
	#ifdef CREATE_AVI
	g_config->getOption("SDL.VideoLog", &s);
	g_config->setOption("SDL.VideoLog", "");
	if(!s.empty())
	{
		NESVideoSetVideoCmd(s.c_str());
		LoggingEnabled = 1;
		g_config->getOption("SDL.MuteCapture", &mutecapture);
	} else {
		mutecapture = 0;
	}
	#endif

	{
		int id;
		g_config->getOption("SDL.InputDisplay", &id);
		extern int input_display;
		input_display = id;
		// not exactly an id as an true/false switch; still better than creating another int for that
		g_config->getOption("SDL.SubtitleDisplay", &id); 
		extern int movieSubtitles;
		movieSubtitles = id;
	}
	
	// load the hotkeys from the config life
	setHotKeys();

#ifdef _GTK
	if(noGui == 0)
	{
		gtk_init(&argc, &argv);
		InitGTKSubsystem(argc, argv);
		while(gtk_events_pending())
			gtk_main_iteration_do(FALSE);
	}
#endif

  if(romIndex >= 0)
	{
		// load the specified game
		error = LoadGame(argv[romIndex]);
		if(error != 1) {
			DriverKill();
			SDL_Quit();
			return -1;
		}
		g_config->setOption("SDL.LastOpenFile", argv[romIndex]);
		g_config->save();

	}
	
	// movie playback
	g_config->getOption("SDL.Movie", &s);
	g_config->setOption("SDL.Movie", "");
	if (s != "")
	{
		if(s.find(".fm2") != std::string::npos || s.find(".fm3") != std::string::npos)
		{
			static int pauseframe;
			g_config->getOption("SDL.PauseFrame", &pauseframe);
			g_config->setOption("SDL.PauseFrame", 0);
			FCEUI_printf("Playing back movie located at %s\n", s.c_str());
			FCEUI_LoadMovie(s.c_str(), false, pauseframe ? pauseframe : false);
		}
		else
		{
		  FCEUI_printf("Sorry, I don't know how to play back %s\n", s.c_str());
		}
	}
	
    int periodic_saves;
    int save_state;
    g_config->getOption("SDL.PeriodicSaves", &periodic_saves);
    g_config->getOption("SDL.AutoSaveState", &save_state);
    if(periodic_saves && save_state < 10 && save_state >= 0){
        FCEUI_SelectState(save_state, 0);
    } else {
        periodic_saves = 0;
    }
	
#ifdef _S9XLUA_H
	// load lua script if option passed
	g_config->getOption("SDL.LuaScript", &s);
	g_config->setOption("SDL.LuaScript", "");
	if (s != "")
	{
		FCEU_LoadLuaCode(s.c_str());
	}
#endif
	
	{
		int id;
		g_config->getOption("SDL.NewPPU", &id);
		if (id)
			newppu = 1;
	}

	g_config->getOption("SDL.Frameskip", &frameskip);
	// loop playing the game
#ifdef _GTK
	if(noGui == 0)
	{
		while(1)
		{
			if(GameInfo)
				DoFun(frameskip, periodic_saves);
			else
				SDL_Delay(1);
			while(gtk_events_pending())
			gtk_main_iteration_do(FALSE);
		}
	}
	else
	{
		while(GameInfo)
			DoFun(frameskip, periodic_saves);
	}
#else
	while(GameInfo)
	{
		DoFun(frameskip, periodic_saves);
	}
#endif
	CloseGame();

	// exit the infrastructure
	FCEUI_Kill();
	SDL_Quit();
	return 0;
}

/**
 * Get the time in ticks.
 */
uint64
FCEUD_GetTime()
{
	return SDL_GetTicks();
}

/**
 * Get the tick frequency in Hz.
 */
uint64
FCEUD_GetTimeFreq(void)
{
	// SDL_GetTicks() is in milliseconds
	return 1000;
}

/**
* Prints a textual message without adding a newline at the end.
*
* @param text The text of the message.
*
* TODO: This function should have a better name.
**/
void FCEUD_Message(const char *text)
{
	fputs(text, stdout);
#ifdef _GTK
	pushOutputToGTK(text);
#endif
}

/**
* Shows an error message in a message box.
* (For now: prints to stderr.)
* 
* If running in GTK mode, display a dialog message box of the error.
*
* @param errormsg Text of the error message.
**/
void FCEUD_PrintError(const char *errormsg)
{
#ifdef GTK
	if(gtkIsStarted == true && noGui == 0)
	{
		GtkWidget* d;
		d = gtk_message_dialog_new(GTK_WINDOW(MainWindow), GTK_DIALOG_MODAL, 
                GTK_MESSAGE_ERROR, GTK_BUTTONS_OK, "%s", errormsg);
		gtk_dialog_run(GTK_DIALOG(d));
		gtk_widget_destroy(d);
	}
#endif

	fprintf(stderr, "%s\n", errormsg);
}


// dummy functions

#define DUMMY(__f) \
    void __f(void) {\
        printf("%s\n", #__f);\
        FCEU_DispMessage("Not implemented.",0);\
    }
DUMMY(FCEUD_HideMenuToggle)
DUMMY(FCEUD_MovieReplayFrom)
DUMMY(FCEUD_ToggleStatusIcon)
DUMMY(FCEUD_AviRecordTo)
DUMMY(FCEUD_AviStop)
void FCEUI_AviVideoUpdate(const unsigned char* buffer) { }
int FCEUD_ShowStatusIcon(void) {return 0;}
bool FCEUI_AviIsRecording(void) {return false;}
void FCEUI_UseInputPreset(int preset) { }
bool FCEUD_PauseAfterPlayback() { return false; }
// These are actually fine, but will be unused and overriden by the current UI code.
void FCEUD_TurboOn	(void) { NoWaiting|= 1; }
void FCEUD_TurboOff   (void) { NoWaiting&=~1; }
void FCEUD_TurboToggle(void) { NoWaiting^= 1; }
FCEUFILE* FCEUD_OpenArchiveIndex(ArchiveScanRecord& asr, std::string &fname, int innerIndex) { return 0; }
FCEUFILE* FCEUD_OpenArchive(ArchiveScanRecord& asr, std::string& fname, std::string* innerFilename) { return 0; }
ArchiveScanRecord FCEUD_ScanArchive(std::string fname) { return ArchiveScanRecord(); }

