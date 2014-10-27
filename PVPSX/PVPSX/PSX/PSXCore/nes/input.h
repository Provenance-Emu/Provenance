#ifndef _NES_INPUT_H
#define _NES_INPUT_H

#define JOY_A   1
#define JOY_B   2
#define JOY_SELECT      4
#define JOY_START       8
#define JOY_UP  0x10
#define JOY_DOWN        0x20
#define JOY_LEFT        0x40
#define JOY_RIGHT       0x80

#define SI_NONE         0
#define SI_GAMEPAD      1
#define SI_ZAPPER       2
#define SI_POWERPADA    3
#define SI_POWERPADB    4
#define SI_ARKANOID     5

#define SIFC_NONE       0
#define SIFC_ARKANOID   1
#define SIFC_SHADOW     2
#define SIFC_4PLAYER    3
#define SIFC_FKB        4
#define SIFC_HYPERSHOT  5
#define SIFC_MAHJONG    6
#define SIFC_PARTYTAP   7
#define SIFC_FTRAINERA  8
#define SIFC_FTRAINERB  9
#define SIFC_OEKAKIDS   10
#define SIFC_BWORLD     11
#define SIFC_TOPRIDER   12

#define SIS_NONE        0
#define SIS_DATACH      1
#define SIS_NWC         2
#define SIS_VSUNISYSTEM 3
#define SIS_NSF         4

#include <mednafen/state.h>

typedef struct {
        uint8 (*Read)(int w);
	void (*Write)(uint8 v);
        void (*Strobe)(int w);
	void (*Update)(int w, void *data);
	void (*SLHook)(int w, uint8 *pix, uint32 linets, int final);
	void (*Draw)(int w, uint8* pix, int pix_y);
	int (*StateAction)(int w, StateMem *sm, int load, int data_only);
} INPUTC;

typedef struct {
	uint8 (*Read)(int w, uint8 ret);
	void (*Write)(uint8 v);
	void (*Strobe)(void);
        void (*Update)(void *data);
        void (*SLHook)(uint8 *pix, uint32 linets, int final);
        void (*Draw)(uint8* pix, int pix_y);
        int (*StateAction)(StateMem *sm, int load, int data_only);
} INPUTCFC;

void MDFN_DrawInput(uint8* pix, int pix_y);
void MDFN_UpdateInput(void);
void NESINPUT_Power(void) MDFN_COLD;
void NESINPUT_Init(void) MDFN_COLD;
void NESINPUT_PaletteChanged(void) MDFN_COLD;
int NESINPUT_StateAction(StateMem *sm, int load, int data_only);

extern void (*PStrobe[2])(void);
extern void (*InputScanlineHook)(uint8 *pix, uint32 linets, int final);

void MDFNNES_DoSimpleCommand(int cmd);
void MDFNNES_SetInput(int port, const char *type, void *ptr) MDFN_COLD;

extern InputInfoStruct NESInputInfo;

#endif
