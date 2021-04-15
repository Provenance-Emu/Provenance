#ifndef __MDFN_MEDNAFEN_H
#define __MDFN_MEDNAFEN_H

#include "types.h"

#if PSS_STYLE==2
 #define PSS "\\"
 #define MDFN_PS '\\'
#elif PSS_STYLE==1
 #define PSS "/"
 #define MDFN_PS '/'
#elif PSS_STYLE==3
 #define PSS "\\"
 #define MDFN_PS '\\'
#elif PSS_STYLE==4
 #define PSS ":" 
 #define MDFN_PS ':'
#endif

#include "git.h"
#include "file.h"
#include "settings.h"
#include "NativeVFS.h"

namespace Mednafen
{

MDFN_HIDE extern NativeVFS NVFS;

// Points to a dynamically-allocated object, created with data from Emulated*.
MDFN_HIDE extern MDFNGI* MDFNGameInfo;

enum MDFN_NoticeType : uint8
{
 // Terse status message for a user-initiated action during runtime(state loaded, screenshot saved, etc.).
 MDFN_NOTICE_STATUS = 0,

 // Something went slightly wrong, but we can mostly recover from it, but the user should still know because
 // it may cause behavior to differ from desired.
 MDFN_NOTICE_WARNING,

 // Something went horribly wrong(user-triggered action, or otherwise); generally prefer throwing MDFN_Error()
 // over sending this, where possible/applicable.
 MDFN_NOTICE_ERROR
};

void MDFN_Notify(MDFN_NoticeType t, const char* format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 2, 3);

// Verbose status and informational messages, primarily during startup and exit.
void MDFN_printf(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);

void MDFN_DebugPrintReal(const char *file, const int line, const char *format, ...) MDFN_FORMATSTR(gnu_printf, 3, 4);

#define MDFN_DebugPrint(...) MDFN_DebugPrintReal(__FILE__, __LINE__, __VA_ARGS__)

void MDFN_FlushGameCheats(int nosave);
void MDFN_DoSimpleCommand(int cmd);
void MDFN_QSimpleCommand(int cmd);
bool MDFN_UntrustedSetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx);
void MDFN_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx);

enum : unsigned
{
 MIDSYNC_FLAG_NONE              = 0,
 MIDSYNC_FLAG_UPDATE_INPUT      = 1U << 0,
 MIDSYNC_FLAG_SYNC_TIME         = 1U << 1,
};
void MDFN_MidSync(EmulateSpecStruct *espec, const unsigned flags = MIDSYNC_FLAG_UPDATE_INPUT | MIDSYNC_FLAG_SYNC_TIME);
void MDFN_MidLineUpdate(EmulateSpecStruct *espec, int y);

}

#include "state.h"
// MDFN_StateAction->(Emu Module)StateAction->MDFNSS_StateAction()

namespace Mednafen
{
void MDFN_StateAction(StateMem *sm, const unsigned load, const bool data_only);
}

#include "mednafen-driver.h"
#include "memory.h"

#include <mednafen/string/string.h>

#endif
