#ifndef __MDFN_MEDNAFEN_H
#define __MDFN_MEDNAFEN_H

#include "types.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gettext.h"

#define _(String) gettext (String)

#include "math_ops.h"
#include "git.h"

extern MDFNGI *MDFNGameInfo;

#include "settings.h"

void MDFN_PrintError(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);
void MDFN_printf(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);
void MDFN_DispMessage(const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);

void MDFN_DebugPrintReal(const char *file, const int line, const char *format, ...) MDFN_FORMATSTR(gnu_printf, 3, 4);

#define MDFN_DebugPrint(format, ...) MDFN_DebugPrintReal(__FILE__, __LINE__, format, ## __VA_ARGS__)

void MDFN_FlushGameCheats(int nosave);
void MDFN_DoSimpleCommand(int cmd);
void MDFN_QSimpleCommand(int cmd);
bool MDFN_UntrustedSetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx);
void MDFN_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx);

void MDFN_MidSync(EmulateSpecStruct *espec);
void MDFN_MidLineUpdate(EmulateSpecStruct *espec, int y);

#include "state.h"
// MDFN_StateAction->(Emu Module)StateAction->MDFNSS_StateAction()
void MDFN_StateAction(StateMem *sm, const unsigned load, const bool data_only);

#include "mednafen-driver.h"

#include "endian.h"
#include "memory.h"

#endif
