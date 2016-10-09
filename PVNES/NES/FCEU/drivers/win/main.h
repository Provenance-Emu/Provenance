#ifndef WIN_MAIN_H
#define WIN_MAIN_H

#include "common.h"
#include <string>

// #defines

#define MAX(x,y) ((x)<(y)?(y):(x))
#define MIN(x,y) ((x)>(y)?(y):(x))

#define VNSCLIP  ((eoptions&EO_CLIPSIDES)?8:0)
#define VNSWID   ((eoptions&EO_CLIPSIDES)?240:256)
#define VNSWID_NU(XR)   (VNSWID==256?XR:((int)(XR/256.f*240)))

#define SO_FORCE8BIT  1
#define SO_SECONDARY  2
#define SO_GFOCUS     4
#define SO_D16VOL     8
#define SO_MUTEFA     16
#define SO_OLDUP      32

#define GOO_DISABLESS   1       /* Disable screen saver when game is loaded. */
#define GOO_CONFIRMEXIT 2       /* Confirmation before exiting. */
#define GOO_POWERRESET  4       /* Confirm on power/reset. */

//For single instance mode, transfers with WM_COPYDATA
//http://www.go4expert.com/forums/showthread.php?t=19730
typedef struct WMCopyStruct
{
	char strFilePath[2048];
} DATA;

extern int maxconbskip;
extern int ffbskip;
extern void LoadNewGamey(HWND hParent, const char *initialdir);
extern void CloseGame();
extern int fullscreen;	//Windows files only, keeps track of fullscreen status

// Flag that indicates whether Game Genie is enabled or not.
extern int genie;

// Flag that indicates whether PAL Emulation is enabled or not.
extern int pal_emulation;
extern int pal_setting_specified;
// dendy and pal should have been designed alongside, using enum or alike
// now it's not possible to do it easily, so we'll just use the flag here and there, not to touch PAL logics
extern int dendy;
extern int status_icon;
extern int frame_display;
extern int rerecord_display;
extern int input_display;
extern int allowUDLR;
extern int pauseAfterPlayback;
extern int closeFinishedMovie;
extern int suggestReadOnlyReplay;
extern int EnableBackgroundInput;
extern int AFon;
extern int AFoff;
extern int AutoFireOffset;


extern int vmod;

extern char* directory_names[14];

char *GetRomName();	//Checks if rom is loaded, if so, outputs the Rom name with no directory path or file extension
char *GetRomPath();	//Checks if rom is loaded, if so, outputs the Rom path only

///Contains the names of the default directories.
static const char *default_directory_names[13] = {
	"",         // roms
	"sav",      // nonvol
	"fcs",      // states
	"",         // fdsrom
	"snaps",    // snaps
	"cheats",   // cheats
	"movies",   // movies
	"tools",    // memwatch
	"tools",    // macro
	"tools",    // input presets
	"tools",    // lua scripts
	"",			// avi output
	""			// adelikat - adding a dummy one here ( [13] but only 12 entries)
};

#define NUMBER_OF_DIRECTORIES sizeof(directory_names) / sizeof(*directory_names)
#define NUMBER_OF_DEFAULT_DIRECTORIES sizeof(default_directory_names) / sizeof(*default_directory_names)

#define TV_ASPECT_DEFAULT_X 4.0
#define TV_ASPECT_DEFAULT_Y 3.0

extern double winsizemulx, winsizemuly;
extern double tvAspectX, tvAspectY;

extern int ismaximized;
extern int soundoptions;
extern int soundrate;
extern int soundbuftime;
extern int soundvolume;		//Master volume control
extern int soundTrianglevol;//Sound channel Triangle - volume control
extern int soundSquare1vol;	//Sound channel Square1 - volume control
extern int soundSquare2vol;	//Sound channel Square2 - volume control
extern int soundNoisevol;	//Sound channel Noise - volume control
extern int soundPCMvol;		//Sound channel PCM - volume control

extern int soundquality;
extern bool muteTurbo;
extern bool swapDuty;

extern int cpalette_count;
extern uint8 cpalette[64*8*3];
extern int srendlinen;
extern int erendlinen;
extern int srendlinep;
extern int erendlinep;

extern int ntsctint, ntschue;
extern bool ntsccol_enable;
extern bool force_grayscale;

//mbg merge 7/17/06 did these have to be unsigned?
//static int srendline, erendline;

static int changerecursive=0;

/// Contains the base directory of FCE
extern std::string BaseDirectory;

extern int soundo;
extern int eoptions;
extern int soundoptions;
extern uint8 *xbsave;
extern HRESULT ddrval;
extern int windowedfailed;
extern uint32 goptions;

void DoFCEUExit();
void ShowAboutBox();
int BlockingCheck();
void DoPriority();
void RemoveDirs();
void CreateDirs();
void SetDirs();
void FCEUX_LoadMovieExtras(const char * fname);
bool ALoad(const char* nameo, char* innerFilename = 0, bool silent = false);
//void initDirectories();	//adelikat 03/02/09 - commenting out reference to a directory that I commented out


#endif
