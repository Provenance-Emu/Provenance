#ifdef  __cplusplus
extern "C" {
#endif
#include "../common/args.h"
#include "../common/config.h"

#include "input.h"

extern FCEUGI *CurGame;

extern CFGSTRUCT DriverConfig[];
extern ARGPSTRUCT DriverArgs[];
extern char *DriverUsage;

void DoDriverArgs(void);
uint8 *GetBaseDirectory(void);

int InitSound(FCEUGI *gi);
void WriteSound(int32 *Buffer, int Count);
int KillSound(void);
uint32 GetMaxSound(void);
uint32 GetWriteSound(void);

void SilenceSound(int s); /* DOS and SDL */


int InitMouse(void);
void KillMouse(void);
void GetMouseData(uint32 *MouseData);

int InitJoysticks(void);
int KillJoysticks(void);
uint32 *GetJSOr(void);

int InitKeyboard(void);
int UpdateKeyboard(void);
char *GetKeyboard(void);
void KillKeyboard(void);

int InitVideo(FCEUGI *gi);
int KillVideo(void);
void BlitScreen(uint8 *XBuf);
void LockConsole(void);
void UnlockConsole(void);
void ToggleFS();		/* SDL */

int LoadGame(const char *path);
int CloseGame(void);
int GUI_Init(int argc, char **argv, int (*dofunc)(void));
int GUI_Idle(void);
int GUI_Update(void);
void GUI_Hide(int);
void GUI_RequestExit(void);
int GUI_SetVideo(int fullscreen, int width, int height);
char *GUI_GetKeyboard(void);
void GUI_GetMouseState(uint32 *b, int *x, int *y);

void UpdatePhysicalInput(void);
int DTestButton(ButtConfig *bc);
int DWaitButton(const uint8 *text, ButtConfig *bc, int wb);
int ButtonConfigBegin(void);
void ButtonConfigEnd(void);

void Giggles(int);
void DoFun(void);

int FCEUD_NetworkConnect(void);
#ifdef  __cplusplus
}
#endif


