#ifndef __MDFN_MEDNAFEN_DRIVER_H
#define __MDFN_MEDNAFEN_DRIVER_H

#include "settings-common.h"

namespace Mednafen
{

//
// Basic overview of order of calls into Mednafen code:
//
//  (MDFNI_printf()/MDFN_printf/MDFN_indent and Mednafen utility functions other than those in CDUtility.h and video/text.h may be called before MDFNI_Init()
//   if necessary, as long as they're called in the same thread that will call MDFNI_Init())
//
//  MDFNI_Init()
//  while(whatever)
//  {
//   MDFNI_AddSetting() (driver-side code can use MDFNSystems global after MDFNI_Init() as necessary to generate per-system driver-side settings)
//  }
//  MDFNI_InitFinalize(basedir)
//
//  MDFNI_LoadSettings()
//
//  MDFNI_SetSetting()	(such as for handling command-line arguments; may also be called later, up to before the last MDFNI_SaveSettings())
//  (...)
//
//  while(running)
//  {
//   MDFNI_LoadGame()
//
//   MDFNI_SetInput()
//
//   while(game_loaded)
//   {
//    (MDFNI_Reset(), MDFNI_Power(), MDFNI_SaveState(), etc. as necessary)
//
//    MDFNI_Emulate()
//   }
//   MDFNI_CloseGame()
//  }
//
//  MDFNI_SaveSettings()
//
//  MDFNI_Kill()
//
//

/* Indent stdout newlines +- "indent" amount */
void MDFN_indent(int indent);
struct MDFN_AutoIndent
{
 INLINE MDFN_AutoIndent() : indented(0) { }
 INLINE MDFN_AutoIndent(int amount) : indented(amount) { MDFN_indent(indented); }
 INLINE ~MDFN_AutoIndent() { MDFN_indent(-indented); }

 INLINE void adjust(int indoot) { indented += indoot; MDFN_indent(indoot); }
 INLINE void reset(void) { MDFN_indent(-indented); indented = 0; }
 private:
 int indented;
};
void MDFN_printf(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);

#define MDFNI_printf MDFN_printf

// MDFN_NOTICE_ERROR may block(e.g. for user confirmation), other notice types should be as non-blocking as possible.
void MDFND_OutputNotice(MDFN_NoticeType t, const char* s) noexcept;

// Output from MDFN_printf(); fairly verbose informational messages.
void MDFND_OutputInfo(const char* s) noexcept;

// If MIDSYNC_FLAG_SYNC_TIME is set in 'flags', synchronize virtual time to actual time using members of espec:
//
//   MasterCycles and MasterCycles_DriverProcessed (coupled with MasterClock of MDFNGI)
//    and/or
//   SoundBuf, SoundBufSize, and SoundBufSize_DriverProcessed
//
// Otherwise, if MIDSYNC_FLAG_SYNC_TIME is not set, then simply write as much sound data as possible without blocking.
//
// MasterCycles_DriverProcessed and SoundBufSize_DriverProcessed may be updated from within MDFND_MidSync().
//
// Then, if MIDSYNC_FLAG_UPDATE_INPUT is set in 'flags', update the data pointed to by the pointers passed to MDFNI_SetInput().
// If this flag is not set, the input MUST NOT be updated, or things will go boom in subtle ways!
//
// Other than MDFN_printf() and MDFN_Notify(), DO NOT CALL MDFN_* or MDFNI_* functions from within MDFND_MidSync()!
//
// If you do not understand how to implement this function, you can leave it empty at first, but know that doing so
// will subtly break at least one PC Engine game(Takeda Shingen), and raise input latency on some other PC Engine games.
void MDFND_MidSync(EmulateSpecStruct *espec, const unsigned flags);

// Called from inside blocking loops on unreliable resources(e.g. netplay).
bool MDFND_CheckNeedExit(void);

void MDFNI_Reset(void);
void MDFNI_Power(void);


// Allocates and initializes memory and other resources.
// Call once, as soon as possible, before any Mednafen functions other than MDFN*_printf() and MDFN_indent.
// Returns 'false' on error.
bool MDFNI_Init(void) MDFN_COLD;

// Only access after a successful call to MDFNI_Init()
MDFN_HIDE extern std::vector<const MDFNGI*> MDFNSystems;

// Finalizes settings, and sets the base directory.
// Call once, after MDFNI_Init() and any MDFNI_AddSetting() calls.
// Returns 'false' on error.
bool MDFNI_InitFinalize(const char *basedir) MDFN_COLD;

// path = path of game/file to load.
// Returns NULL on error.
//
// Don't pass anything other than &::Mednafen::NVFS for vfs unless you absolutely know what
// you're doing; the object it points to must remain valid until MDFNI_CloseGame() returns,
// and if the file you're loading is a CD image, it will be cached in memory regardless of 
// the cd.image_memcache setting, in order to avoid thread safety issues.  You'd also need to make
// sure filesys.fname_* settings are appropriate given the "path" specified, and be aware of
// other similar issues with naming.
//
MDFNGI* MDFNI_LoadGame(const char* force_module, VirtualFS* vfs, const char* path, bool force_cd = false) MDFN_COLD;

// Advanced usage; normally don't call.
class CDInterface;
MDFNGI *MDFNI_LoadExternalCD(const char* force_module, const char* path_hint, CDInterface* cdif) MDFN_COLD;

// Loads settings from specified path.
// Call once, after MDFNI_InitFinalize()
// returns -1 if settings file didn't exist, 0 on error, and 1 on success
int MDFNI_LoadSettings(const char* path, bool override = false);

// Saves settings to specified path.
// Call at least once right before MDFNI_Kill()
bool MDFNI_SaveSettings(const char* path);

// Saves settings to specified stream in a less user-friendly, compact form that's still compatible with
// MDFNI_LoadSettings(), provided that the stream position is at 0 upon calling.  Intended to be used
// for creating settings backups/snapshots.
bool MDFNI_SaveSettingsCompact(Stream* s);

// Emulates a frame.
// Call multiple times after MDFNI_LoadGame() and before MDFNI_CloseGame()
void MDFNI_Emulate(EmulateSpecStruct *espec);

#if 0
/* Support function for scaling multiple-horizontal-resolution frames to a single width; mostly intended for unofficial ports.
   The driver code really ought to handle multi-horizontal-resolution frames natively and properly itself, however.

   WARNING: If you use this function, you'll need to create the video surface with a width of something like:
	std::max<int32>(fb_width, lcm_width)
   instead of just fb_width, otherwise you'll get memory corruption/crashes.
*/
void MDFNI_AutoScaleMRFrame(EmulateSpecStruct *espec);
#endif

// Closes currently loaded game, freeing its associated resources.
void MDFNI_CloseGame(void) MDFN_COLD;

// Frees (most) resources allocated by MDFNI_Init() and MDFNI_InitFinalize().
// Call once, right before exit, and do not call any Mednafen functions afterward.
void MDFNI_Kill(void) MDFN_COLD;

void MDFN_DispMessage(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);
#define MDFNI_DispMessage MDFN_DispMessage

// NES hackish function.  Should abstract in the future.
int MDFNI_DatachSet(const uint8 *rcode);

void MDFNI_SetLayerEnableMask(uint64 mask);


//TODO(need to work out how it'll interact with port device type settings):
//void MDFNI_SetInput(uint32 port, uint32 type);
//void MDFND_InputSetNotification(uint32 port, uint32 type, uint8* ptr);
uint8* MDFNI_SetInput(const uint32 port, const uint32 type);

bool MDFNI_SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx = 0);
void MDFND_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx);

// Arcade-support functions
// We really need to reexamine how we should abstract this, considering the initial state of the DIP switches,
// and moving the DIP switch drawing code to the driver side.
void MDFNI_ToggleDIP(int which);
void MDFNI_InsertCoin(void);
void MDFNI_ToggleDIPView(void);

bool MDFNI_EnableStateRewind(bool enable);

bool MDFNI_StartAVRecord(const char *path, double SoundRate) MDFN_COLD;
void MDFNI_StopAVRecord(void) MDFN_COLD;

bool MDFNI_StartWAVRecord(const char *path, double SoundRate) MDFN_COLD;
void MDFNI_StopWAVRecord(void) MDFN_COLD;

void MDFNI_DumpModulesDef(const char *fn) MDFN_COLD;

//
//
//
void MDFNI_AddSetting(const MDFNSetting& s);

// NULL-terminated
void MDFNI_MergeSettings(const MDFNSetting* s);

//
// Due to how the per-module(and in the future, per-game) settings overrides work, we should
// take care not to call MDFNI_SetSetting*() unless the setting has actually changed due to a user action.
// I.E. do NOT call SetSetting*() unconditionally en-masse at emulator exit/game close to synchronize certain things like input mappings.
//
bool MDFNI_SetSetting(const char *name, const char *value, bool override = false);
bool MDFNI_SetSetting(const char *name, const std::string& value, bool override = false);
bool MDFNI_SetSetting(const std::string& name, const std::string& value, bool override = false);

bool MDFNI_SetSettingB(const char *name, bool value);
bool MDFNI_SetSettingB(const std::string& name, bool value);

bool MDFNI_SetSettingUI(const char *name, uint64 value);
bool MDFNI_SetSettingUI(const std::string& name, uint64 value);

void MDFNI_DumpSettingsDef(const char *path);

const std::vector<MDFNCS>* MDFNI_GetSettings(void);
std::string MDFNI_GetSettingDefault(const char* name);
std::string MDFNI_GetSettingDefault(const std::string& name);

}
#endif
