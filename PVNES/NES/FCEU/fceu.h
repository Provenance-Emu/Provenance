#ifndef _FCEUH
#define _FCEUH

#include "types.h"

extern int fceuindbg;
extern int newppu;
void ResetGameLoaded(void);

//overclocking-related
extern bool overclock_enabled;
extern bool overclocking;
extern bool skip_7bit_overclocking;
extern int normalscanlines;
extern int totalscanlines;
extern int postrenderscanlines;
extern int vblankscanlines;

extern bool AutoResumePlay;
extern char romNameWhenClosingEmulator[];

#define DECLFR(x) uint8 x (uint32 A)
#define DECLFW(x) void x (uint32 A, uint8 V)

void FCEU_MemoryRand(uint8 *ptr, uint32 size);
void SetReadHandler(int32 start, int32 end, readfunc func);
void SetWriteHandler(int32 start, int32 end, writefunc func);
writefunc GetWriteHandler(int32 a);
readfunc GetReadHandler(int32 a);

int AllocGenieRW(void);
void FlushGenieRW(void);

void FCEU_ResetVidSys(void);

void ResetMapping(void);
void ResetNES(void);
void PowerNES(void);

void SetAutoFireOffset(int offset);
void SetAutoFirePattern(int onframes, int offframes);
void AutoFire(void);
void FCEUI_RewindToLastAutosave(void);

//mbg 7/23/06
char *FCEUI_GetAboutString();

extern uint64 timestampbase;
extern uint32 MMC5HackVROMMask;
extern uint8 *MMC5HackExNTARAMPtr;
extern int MMC5Hack, PEC586Hack;
extern uint8 *MMC5HackVROMPTR;
extern uint8 MMC5HackCHRMode;
extern uint8 MMC5HackSPMode;
extern uint8 MMC50x5130;
extern uint8 MMC5HackSPScroll;
extern uint8 MMC5HackSPPage;


#define GAME_MEM_BLOCK_SIZE 131072

extern  uint8  *RAM;            //shared memory modifications
extern int EmulationPaused;

uint8 FCEU_ReadRomByte(uint32 i);
void FCEU_WriteRomByte(uint32 i, uint8 value);

extern readfunc ARead[0x10000];
extern writefunc BWrite[0x10000];

enum GI {
	GI_RESETM2	=1,
	GI_POWER =2,
	GI_CLOSE =3,
	GI_RESETSAVE = 4
};

extern void (*GameInterface)(GI h);
extern void (*GameStateRestore)(int version);


#include "git.h"
extern FCEUGI *GameInfo;
extern int GameAttributes;

extern uint8 PAL;
extern int dendy;

//#include "driver.h"

typedef struct {
	int PAL;
	int NetworkPlay;
	int SoundVolume;		//Master volume
	int TriangleVolume;
	int Square1Volume;
	int Square2Volume;
	int NoiseVolume;
	int PCMVolume;
	bool GameGenie;

	//the currently selected first and last rendered scanlines.
	int FirstSLine;
	int LastSLine;

	//the number of scanlines in the currently selected configuration
	int TotalScanlines() { return LastSLine - FirstSLine + 1; }

	//Driver-supplied user-selected first and last rendered scanlines.
	//Usr*SLine[0] is for NTSC, Usr*SLine[1] is for PAL.
	int UsrFirstSLine[2];
	int UsrLastSLine[2];

	//this variable isn't used at all, snap is always name-based
	//bool SnapName;
	uint32 SndRate;
	int soundq;
	int lowpass;
} FCEUS;

int FCEU_TextScanlineOffset(int y);
int FCEU_TextScanlineOffsetFromBottom(int y);

extern FCEUS FSettings;

bool CheckFileExists(const char* filename);	//Receives a filename (fullpath) and checks to see if that file exists

void FCEU_PrintError(char *format, ...);
void FCEU_printf(char *format, ...);
void FCEU_DispMessage(char *format, int disppos, ...);
void FCEU_DispMessageOnMovie(char *format, ...);
void FCEU_TogglePPU();

void SetNESDeemph_OldHacky(uint8 d, int force);
void DrawTextTrans(uint8 *dest, uint32 width, uint8 *textmsg, uint8 fgcolor);
void FCEU_PutImage(void);
#ifdef FRAMESKIP
void FCEU_PutImageDummy(void);
#endif

#ifdef WIN32
extern void UpdateCheckedMenuItems();
extern void PushCurrentVideoSettings();
#endif

extern uint8 Exit;
extern int default_palette_selection;
extern uint8 vsdip;

//#define FCEUDEF_DEBUGGER //mbg merge 7/17/06 - cleaning out conditional compiles

#define JOY_A   1
#define JOY_B   2
#define JOY_SELECT      4
#define JOY_START       8
#define JOY_UP  0x10
#define JOY_DOWN        0x20
#define JOY_LEFT        0x40
#define JOY_RIGHT       0x80
#endif

#define ARRAY_SIZE(a) (sizeof(a)/sizeof(a[0]))

#define EMULATIONPAUSED_PAUSED 1
#define EMULATIONPAUSED_FA 2

#define FRAMEADVANCE_DELAY_DEFAULT 10

