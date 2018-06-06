#ifndef __MDFN_NES_NES_H
#define __MDFN_NES_NES_H

#include <mednafen/mednafen.h>
#include <mednafen/state.h>
#include <mednafen/general.h>
#include <mednafen/string/string.h>
#include <mednafen/file.h>
#include <mednafen/hash/md5.h>
#include <mednafen/video.h>

namespace MDFN_IEN_NES
{

typedef void (MDFN_FASTCALL *writefunc)(uint32 A, uint8 V);
typedef uint8 (MDFN_FASTCALL *readfunc)(uint32 A);

void ResetMapping(void) MDFN_COLD;
void ResetNES(void) MDFN_COLD;
void PowerNES(void) MDFN_COLD;

extern uint64 timestampbase;
extern uint32 MMC5HackVROMMask;
extern uint8 *MMC5HackExNTARAMPtr;
extern uint32 MMC5HackCHRBank;
extern int MMC5Hack;
extern uint8 *MMC5HackVROMPTR;
extern uint8 MMC5HackCHRMode;
extern uint8 MMC5HackSPMode;
extern uint8 MMC5HackSPScroll;
extern uint8 MMC5HackSPPage;

extern readfunc ARead[0x10000 + 0x100];
extern writefunc BWrite[0x10000 + 0x100];

extern int GameAttributes;
extern uint8 PAL;

extern int fceuindbg;
void ResetGameLoaded(void);

#define DECLFR(x) uint8 MDFN_FASTCALL x (uint32 A)
#define DECLFW(x) void MDFN_FASTCALL x (uint32 A, uint8 V)

DECLFR(ANull);
DECLFW(BNull);

void SetReadHandler(int32 start, int32 end, readfunc func, bool snc = 1);
void SetWriteHandler(int32 start, int32 end, writefunc func);
writefunc GetWriteHandler(int32 a);
readfunc GetReadHandler(int32 a);

typedef struct
{
 void (*Power)(void);
 void (*Reset)(void);
 void (*SaveNV)(void);
 void (*Kill)(void);
 void (*StateAction)(StateMem *sm, const unsigned load, const bool data_only);
} NESGameType;


extern bool NESIsVSUni;
}

using namespace MDFN_IEN_NES;

#endif
