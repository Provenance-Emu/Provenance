#ifndef __FCEU_SDL_H
#define __FCEU_SDL_H

#if _SDL2
#include <SDL2/SDL.h>
#else
#include <SDL.h>
#endif

#include "main.h"
#include "dface.h"
#include "input.h"

// I'm using this as a #define so the compiler can optimize the
// modulo operation
#define PERIODIC_SAVE_INTERVAL 5000 // milliseconds

const int INVALID_STATE = 99;

extern int noGui;
extern int isloaded;

extern int dendy;
extern int pal_emulation;
extern bool swapDuty;

int LoadGame(const char *path);
int CloseGame(void);
void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count);
uint64 FCEUD_GetTime();

#endif
