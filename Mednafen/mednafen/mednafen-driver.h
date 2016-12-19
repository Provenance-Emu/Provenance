#ifndef __MDFN_MEDNAFEN_DRIVER_H
#define __MDFN_MEDNAFEN_DRIVER_H

#include <stdio.h>
#include <vector>
#include <string>

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

/* Displays an error.  Can block or not. */
void MDFND_PrintError(const char *s);
void MDFND_Message(const char *s);

uint32 MDFND_GetTime(void);
void MDFND_Sleep(uint32 ms);

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

/* path = path of game/file to load.  returns NULL on failure. */
MDFNGI *MDFNI_LoadGame(const char *force_module, const char *path);

MDFNGI *MDFNI_LoadCD(const char *force_module, const char *path);	// Deprecated interface.

// Call this function as early as possible, even before MDFNI_Initialize()
bool MDFNI_InitializeModules(const std::vector<MDFNGI *> &ExternalSystems);

/* allocates memory.  0 on failure, 1 on success. */
/* Also pass it the base directory to load the configuration file. */
int MDFNI_Initialize(const char *basedir, const std::vector<MDFNSetting> &DriverSettings);

/* Call only when a game is loaded. */
int MDFNI_NetplayStart(void);

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
void MDFNI_CloseGame(void);

/* Deallocates all allocated memory.  Call after MDFNI_Emulate() returns. */
void MDFNI_Kill(void);

void MDFN_DispMessage(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);
#define MDFNI_DispMessage MDFN_DispMessage

uint32 MDFNI_CRC32(uint32 crc, uint8 *buf, uint32 len);

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

bool MDFNI_StartAVRecord(const char *path, double SoundRate);
void MDFNI_StopAVRecord(void);

bool MDFNI_StartWAVRecord(const char *path, double SoundRate);
void MDFNI_StopWAVRecord(void);

void MDFNI_DumpModulesDef(const char *fn);

#endif
