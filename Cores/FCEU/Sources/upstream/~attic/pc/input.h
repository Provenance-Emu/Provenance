#ifndef _aosdfjk02fmasf
#define _aosdfjk02fmasf
#define MAXBUTTCONFIG   4
typedef struct {
        uint8  ButtType[MAXBUTTCONFIG];
        uint8  DeviceNum[MAXBUTTCONFIG];
        uint16 ButtonNum[MAXBUTTCONFIG];
        uint32 NumC;
	//uint64 DeviceID[MAXBUTTCONFIG];	/* TODO */
} ButtConfig;

extern CFGSTRUCT InputConfig[];
extern ARGPSTRUCT InputArgs[];
void ParseGIInput(FCEUGI *GI);

#define BUTTC_KEYBOARD          0x00
#define BUTTC_JOYSTICK          0x01
#define BUTTC_MOUSE             0x02

#define FCFGD_GAMEPAD   1
#define FCFGD_POWERPAD  2
#define FCFGD_HYPERSHOT 3
#define FCFGD_QUIZKING  4

void InitOtherInput(void);
void InputUserActiveFix(void);
#ifdef EXTGUI
extern ButtConfig GamePadConfig[4][10];
extern ButtConfig powerpadsc[2][12];
extern ButtConfig QuizKingButtons[6];
extern ButtConfig FTrainerButtons[12];
#endif

void IncreaseEmulationSpeed(void);
void DecreaseEmulationSpeed(void);

void FCEUD_UpdateInput(void);
#endif
