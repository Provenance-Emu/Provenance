#ifndef __MDFN_MEDNAFEN_DRIVER_H
#define __MDFN_MEDNAFEN_DRIVER_H

#include "settings-common.h"

extern std::vector<MDFNGI *>MDFNSystems;

/* Indent stdout newlines +- "indent" amount */
void MDFN_indent(int indent);
struct MDFN_AutoIndent
{
 INLINE MDFN_AutoIndent() : indented(0) { }
 INLINE MDFN_AutoIndent(int amount) : indented(amount) { MDFN_indent(indented); }
 INLINE ~MDFN_AutoIndent() { MDFN_indent(-indented); }

 //INLINE void indent(int indoot) { indented += indoot; MDFN_indent(indoot); }
 private:
 int indented;
};
void MDFN_printf(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);

#define MDFNI_printf MDFN_printf

// MDFN_NOTICE_ERROR may block(e.g. for user confirmation), other notice types should be as non-blocking as possible.
void MDFND_OutputNotice(MDFN_NoticeType t, const char* s) noexcept;

// Output from MDFN_printf(); fairly verbose informational messages.
void MDFND_OutputInfo(const char* s) noexcept;

// Synchronize virtual time to actual time using members of espec:
//
//  MasterCycles and MasterCyclesALMS (coupled with MasterClock of MDFNGI)
//   and/or
//  SoundBuf, SoundBufSize, and SoundBufSizeALMS
//
// ...and after synchronization, update the data pointed to by the pointers passed to MDFNI_SetInput().
// DO NOT CALL MDFN_* or MDFNI_* functions from within MDFND_MidSync().
// Calling MDFN_printf(), MDFN_DispMessage(),and MDFND_PrintError() are ok, though.
//
// If you do not understand how to implement this function, you can leave it empty at first, but know that doing so
// will subtly break at least one PC Engine game(Takeda Shingen), and raise input latency on some other PC Engine games.
void MDFND_MidSync(const EmulateSpecStruct *espec);

// Called from inside blocking loops on unreliable resources(e.g. netplay).
bool MDFND_CheckNeedExit(void);

//
// Begin threading support.
//
// Mostly based off SDL's prototypes and semantics.
// Driver code should actually define MDFN_Thread and MDFN_Mutex.
//
// Caution: Do not attempt to use the synchronization primitives(mutex, cond variables, etc.) for inter-process synchronization, they'll only work reliably with
// intra-process synchronization(the "mutex" is implemented as a a critical section under Windows, for example).
//
struct MDFN_Thread;
struct MDFN_Mutex;
struct MDFN_Cond;	// mmm condiments
struct MDFN_Sem;

MDFN_Thread *MDFND_CreateThread(int (*fn)(void *), void *data);
void MDFND_WaitThread(MDFN_Thread *thread, int *status);
uint32 MDFND_ThreadID(void);

MDFN_Mutex *MDFND_CreateMutex(void) MDFN_COLD;
void MDFND_DestroyMutex(MDFN_Mutex *mutex) MDFN_COLD;

int MDFND_LockMutex(MDFN_Mutex *mutex);
int MDFND_UnlockMutex(MDFN_Mutex *mutex);

MDFN_Cond* MDFND_CreateCond(void) MDFN_COLD;
void MDFND_DestroyCond(MDFN_Cond* cond) MDFN_COLD;

/* MDFND_SignalCond() *MUST* be called with a lock on the mutex used with MDFND_WaitCond() or MDFND_WaitCondTimeout() */
int MDFND_SignalCond(MDFN_Cond* cond);
int MDFND_WaitCond(MDFN_Cond* cond, MDFN_Mutex* mutex);

#define MDFND_COND_TIMEDOUT	1
int MDFND_WaitCondTimeout(MDFN_Cond* cond, MDFN_Mutex* mutex, unsigned ms);


MDFN_Sem* MDFND_CreateSem(void);
void MDFND_DestroySem(MDFN_Sem* sem);

int MDFND_WaitSem(MDFN_Sem* sem);
#define MDFND_SEM_TIMEDOUT	1
int MDFND_WaitSemTimeout(MDFN_Sem* sem, unsigned ms);
int MDFND_PostSem(MDFN_Sem* sem);
//
// End threading support.
//

void MDFNI_Reset(void);
void MDFNI_Power(void);


// path = path of game/file to load.
// Returns NULL on error.
MDFNGI *MDFNI_LoadGame(const char *force_module, const char *path, bool force_cd = false) MDFN_COLD;

// Call this function as early as possible, even before MDFNI_Initialize()
bool MDFNI_InitializeModules(void) MDFN_COLD;

// Call once, after MDFNI_Initialize()
// returns -1 if settings file didn't exist, 0 on error, and 1 on success
int MDFNI_LoadSettings(const char* path);

// Call at least once right before MDFNI_Kill()
bool MDFNI_SaveSettings(const char* path);

/* allocates memory.  0 on failure, 1 on success. */
/* Also pass it the base directory to load the configuration file. */
int MDFNI_Initialize(const char *basedir, const std::vector<MDFNSetting> &DriverSettings) MDFN_COLD;

/* Emulates a frame. */
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

/* Closes currently loaded game */
void MDFNI_CloseGame(void) MDFN_COLD;

/* Deallocates all allocated memory.  Call after MDFNI_Emulate() returns. */
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

#endif
