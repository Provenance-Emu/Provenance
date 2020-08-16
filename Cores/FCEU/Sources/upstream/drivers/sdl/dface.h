#include "../common/args.h"
#include "../common/config.h"

#include "input.h"

extern CFGSTRUCT DriverConfig[];
extern ARGPSTRUCT DriverArgs[];

void DoDriverArgs(void);

int InitSound();
void WriteSound(int32 *Buffer, int Count);
int KillSound(void);
uint32 GetMaxSound(void);
uint32 GetWriteSound(void);

void SilenceSound(int s); /* DOS and SDL */

int InitJoysticks(void);
int KillJoysticks(void);
uint32 *GetJSOr(void);

int InitVideo(FCEUGI *gi);
int KillVideo(void);
void BlitScreen(uint8 *XBuf);
void LockConsole(void);
void UnlockConsole(void);
void ToggleFS();		/* SDL */

int LoadGame(const char *path);
//int CloseGame(void);

void Giggles(int);
void DoFun(void);

int FCEUD_NetworkConnect(void);

