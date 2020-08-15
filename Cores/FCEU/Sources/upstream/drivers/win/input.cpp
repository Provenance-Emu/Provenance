/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

// For commctrl.h below
#define _WIN32_IE	0x0550

#include "../../version.h"

#include "common.h"
#include "dinput.h"
#include <windows.h>
#include <commctrl.h>

#include "input.h"
#include "keyboard.h"
#include "joystick.h"
#include "gui.h"
#include "fceu.h"
#include "movie.h"
#include "window.h"
#include "sound.h"
#include "keyscan.h"

LPDIRECTINPUT7 lpDI=0;

void InitInputPorts(bool fourscore);

int tempwinsync = 0;		//Temp variable used by turbo to turn of sync settings
int tempsoundquality = 0;	//Temp variable used by turbo to turn of sound quality settings
extern int winsync;
extern int soundquality;
extern bool replaceP2StartWithMicrophone;
//UsrInputType[] is user-specified.  InputType[] is current
//        (game/savestate/movie loading can override user settings)

//int UsrInputType[3]={SI_GAMEPAD,SI_GAMEPAD,SIFC_NONE};
int InputType[3]={SI_GAMEPAD,SI_NONE,SIFC_NONE};

int InitDInput(void)
{
	HRESULT ddrval;

	ddrval=DirectInputCreateEx(fceu_hInstance,DIRECTINPUT_VERSION,IID_IDirectInput7,(LPVOID *)&lpDI,0);
	if(ddrval!=DI_OK)
	{
		FCEUD_PrintError("DirectInput: Error creating DirectInput object.");
		return 0;
	}
	return 1;
}
static void PresetExport(int preset);
static void PresetImport(int preset);

static uint32 MouseData[3];

//force the input types suggested by the game
void ParseGIInput(FCEUGI *gi)
{ 
	if(gi)
	{
		if(gi->input[0]!=SI_UNSET)
			InputType[0]=gi->input[0];
		if(gi->input[1]!=SI_UNSET)
			InputType[1]=gi->input[1];
		if(gi->inputfc!=SIFC_UNSET)
			InputType[2]=gi->inputfc;

		InitInputPorts((eoptions & EO_FOURSCORE)!=0);
	}
}


static uint8 QuizKingData=0;
static uint8 HyperShotData=0;
static uint32 MahjongData=0;
static uint32 FTrainerData=0;
static uint8 TopRiderData=0;

static uint8 BWorldData[1+13+1];

static void UpdateFKB(void);
static void UpdateSuborKB(void);
void UpdateGamepad(void);
static void UpdateQuizKing(void);
static void UpdateHyperShot(void);
static void UpdateMahjong(void);
static void UpdateFTrainer(void);
static void UpdateTopRider(void);

static uint32 snespad_return[4];
static uint32 JSreturn=0;
int NoWaiting=0;
bool turbo = false;

#include "keyscan.h"
static unsigned int *keys=0;
static unsigned int *keys_nr=0;
static int DIPS=0;

//#define KEY(__a) keys_nr[MKK(__a)]

int cidisabled=0;
int allowUDLR=0;

#define MK(x)   {{BUTTC_KEYBOARD},{0},{MKK(x)},1}
#define MC(x)   {{BUTTC_KEYBOARD},{0},{x},1}
#define MK2(x1,x2)        {{BUTTC_KEYBOARD},{0},{MKK(x1),MKK(x2)},2}

#define MKZ()   {{0},{0},{0},0}

#define GPZ()   {MKZ(), MKZ(), MKZ(), MKZ()}

ButtConfig GamePadConfig[4][12]={
	//Gamepad 1
	{
		MK(F), MK(D), MK(S), MK(ENTER), MK(BL_CURSORUP),
			MK(BL_CURSORDOWN),MK(BL_CURSORLEFT),MK(BL_CURSORRIGHT)
	},

	//Gamepad 2
	GPZ(),

	//Gamepad 3
	GPZ(),

	//Gamepad 4
	GPZ()
};

ButtConfig GamePadPreset1[4][12]={GPZ(),GPZ(),GPZ(),GPZ()};
ButtConfig GamePadPreset2[4][12]={GPZ(),GPZ(),GPZ(),GPZ()};
ButtConfig GamePadPreset3[4][12]={GPZ(),GPZ(),GPZ(),GPZ()};
char *InputPresetDir = 0;

extern int rapidAlternator; // for auto-fire / autofire
int DesynchAutoFire=0; // A and B not at same time
uint32 JSAutoHeld=0, JSAutoHeldAffected=0; // for auto-hold
uint8 autoHoldOn=0, autoHoldReset=0, autoHoldRefire=0; // for auto-hold

void SetAutoFireDesynch(int DesynchOn)
{
	if(DesynchOn)
	{
		DesynchAutoFire = 1;
	}
	else
	{
		DesynchAutoFire = 0;
	}
}

int GetAutoFireDesynch()
{
	return DesynchAutoFire;
}

// Test button state using current keyboard data.
// Clone of DTestButton, but uses local variables.
int DTestButtonImmediate(ButtConfig *bc)
{
	uint32 x;//mbg merge 7/17/06 changed to uint

	static unsigned int *keys_im=GetKeyboard_nr();

	for(x=0;x<bc->NumC;x++)
	{
		if(bc->ButtType[x]==BUTTC_KEYBOARD)
		{
			if(keys_im[bc->ButtonNum[x]])
			{
				return(1);
			}
		}
	}
	if(DTestButtonJoy(bc)) return(1); // Needs joystick.h. Tested with PPJoy mapped with Print Screen
	return(0);
}

uint32 GetGamepadPressedImmediate()
{
	// Get selected joypad buttons, ignoring NES polling
	// Basically checks for immediate gamepad input.
	//extern ButtConfig GamePadConfig[4][10];
	//extern int allowUDLR;

	uint32 JSButtons=0;
	int x;
	int wg;

	for(wg=0;wg<4;wg++)
	{

		for(x=0;x<8;x++)
			if(DTestButtonImmediate(&GamePadConfig[wg][x]))
				JSButtons|=(1<<x)<<(wg<<3);

		// Check if U+D/L+R is disabled
		if(!allowUDLR)
		{
			for(x=0;x<32;x+=8)
			{
				if((JSButtons & (0xC0<<x) ) == (0xC0<<x) ) JSButtons&=~(0xC0<<x);
				if((JSButtons & (0x30<<x) ) == (0x30<<x) ) JSButtons&=~(0x30<<x);
			}
		}
	}
	return JSButtons;
}

int DTestButton(ButtConfig *bc)
{
	uint32 x;//mbg merge 7/17/06 changed to uint

	for(x=0;x<bc->NumC;x++)
	{
		if(bc->ButtType[x]==BUTTC_KEYBOARD)
		{
			if(keys_nr[bc->ButtonNum[x]])
			{
				return(1);
			}
		}
	}
	if(DTestButtonJoy(bc)) return(1);
	return(0);
}

void UpdateGamepad(bool snes)
{
	if(FCEUMOV_Mode(MOVIEMODE_PLAY))
		return;

	int JS=0;
	if(FCEUMOV_Mode(MOVIEMODE_RECORD))
		AutoFire();

	for(int wg=0;wg<4;wg++)
	{
		int wgs = wg;
		if(snes)
		{
			JS = 0;
			wgs = 0;
			for(int x=0;x<12;x++)
				if(DTestButton(&GamePadConfig[wg][x]))
					JS|=(1<<x)<<(wgs<<3);
			//printf("%d %d\n",wg,JS); //useful debugging
		}
		else
		{
			for(int x=0;x<8;x++)
				if(DTestButton(&GamePadConfig[wg][x]))
					JS|=(1<<x)<<(wgs<<3);
		}

		// Check if U+D/L+R is disabled
		//TODO: how does this affect snes pads?
		if(!allowUDLR)
		{
			for(int x=0;x<32;x+=8)
			{
				if((JS & (0xC0<<x) ) == (0xC0<<x) ) JS&=~(0xC0<<x);
				if((JS & (0x30<<x) ) == (0x30<<x) ) JS&=~(0x30<<x);
			}
		}

		//  if(rapidAlternator)
		if(!snes)
		{
			for(int x=0;x<2;x++)
				if(DTestButton(&GamePadConfig[wg][8+x]))
					JS|=((1<<x)<<(wgs<<3))*(rapidAlternator^(x*DesynchAutoFire));
		}

		if(snes)
		{
			snespad_return[wg] = JS;
			//printf("%d %d\n",wg,JS);
		}
	}

	if(autoHoldOn)
	{
		if(autoHoldRefire)
		{
			autoHoldRefire--;
			if(!autoHoldRefire)
				JSAutoHeldAffected = 0;
		}

		for(int wg=0;wg<4;wg++)
			for(int x=0;x<8;x++)
				if(DTestButton(&GamePadConfig[wg][x]))
				{
					if(!autoHoldRefire || !(JSAutoHeldAffected&(1<<x)<<(wg<<3)))
					{
						JSAutoHeld^=(1<<x)<<(wg<<3);
						JSAutoHeldAffected|=(1<<x)<<(wg<<3);
						autoHoldRefire = 192;
					}
				}

				char inputstr [41];
				int disppos=38;
				{
					uint32 c = JSAutoHeld;
					sprintf(inputstr, "1%c%c%c%c%c%c%c%c 2%c%c%c%c%c%c%c%c\n3%c%c%c%c%c%c%c%c 4%c%c%c%c%c%c%c%c",
						(c&0x40)?'<':' ', (c&0x10)?'^':' ', (c&0x80)?'>':' ', (c&0x20)?'v':' ',
						(c&0x01)?'A':' ', (c&0x02)?'B':' ', (c&0x08)?'S':' ', (c&0x04)?'s':' ',
						(c&0x4000)?'<':' ', (c&0x1000)?'^':' ', (c&0x8000)?'>':' ', (c&0x2000)?'v':' ',
						(c&0x0100)?'A':' ', (c&0x0200)?'B':' ', (c&0x0800)?'S':' ', (c&0x0400)?'s':' ',
						(c&0x400000)?'<':' ', (c&0x100000)?'^':' ', (c&0x800000)?'>':' ', (c&0x200000)?'v':' ',
						(c&0x010000)?'A':' ', (c&0x020000)?'B':' ', (c&0x080000)?'S':' ', (c&0x040000)?'s':' ',
						(c&0x40000000)?'<':' ', (c&0x10000000)?'^':' ', (c&0x80000000)?'>':' ', (c&0x20000000)?'v':' ',
						(c&0x01000000)?'A':' ', (c&0x02000000)?'B':' ', (c&0x08000000)?'S':' ', (c&0x04000000)?'s':' ');
					if(!(c&0xffffff00)) {
						inputstr[9] = '\0';
						disppos = 30;
					}
					else if(!(c&0xffff0000)) {
						inputstr[19] = '\0';
						disppos = 30;
					}
					else if(!(c&0xff000000)) {
						inputstr[30] = '\0';
					}
				}
				FCEU_DispMessage("Held:\n%s", disppos, inputstr);
	}
	else
	{
		JSAutoHeldAffected = 0;
		autoHoldRefire = 0;
	}

	if(autoHoldReset)
	{
		FCEU_DispMessage("Held:          ",30);
		JSAutoHeld = 0;
		JSAutoHeldAffected = 0;
		autoHoldRefire = 0;
	}

	// apply auto-hold
	if(JSAutoHeld)
		JS ^= JSAutoHeld;

	if(!snes)
		JSreturn=JS;
}

ButtConfig powerpadsc[2][12]={
	{
		MK(O),MK(P),MK(BRACKET_LEFT),
			MK(BRACKET_RIGHT),

			MK(K),MK(L),MK(SEMICOLON),
			MK(APOSTROPHE),
			MK(M),MK(COMMA),MK(PERIOD),MK(SLASH)
	},
	{
		MK(O),MK(P),MK(BRACKET_LEFT),
			MK(BRACKET_RIGHT),MK(K),MK(L),MK(SEMICOLON),
			MK(APOSTROPHE),
			MK(M),MK(COMMA),MK(PERIOD),MK(SLASH)
		}
};

static uint32 powerpadbuf[2];

static uint32 UpdatePPadData(int w)
{
	uint32 r=0;
	ButtConfig *ppadtsc=powerpadsc[w];
	int x;

	for(x=0;x<12;x++)
		if(DTestButton(&ppadtsc[x])) r|=1<<x;

	return r;
}


static uint8 fkbkeys[0x48];
static uint8 suborkbkeys[0x65];

void KeyboardUpdateState(void); //mbg merge 7/17/06 yech had to add this

void HandleHotkeys()
{
	FCEUI_HandleEmuCommands(FCEUD_TestCommandState);
}

void UpdateRawInputAndHotkeys()
{
	KeyboardUpdateState();
	UpdateJoysticks();

	HandleHotkeys();
}

void FCEUD_UpdateInput()
{
	bool joy=false,mouse=false;
	EMOVIEMODE FCEUMOVState = FCEUMOV_Mode();

  UpdateRawInputAndHotkeys();

	{
		for(int x=0;x<2;x++)
			switch(InputType[x])
		{
			case SI_GAMEPAD: joy=true; break;
			case SI_SNES: 
				UpdateGamepad(true);
				break;
			case SI_MOUSE: mouse=true; break;
			case SI_SNES_MOUSE: mouse=true; break;
			case SI_ARKANOID: mouse=true; break;
			case SI_ZAPPER: mouse=true; break;
			case SI_POWERPADA:
			case SI_POWERPADB:
				powerpadbuf[x]=UpdatePPadData(x);
				break;
		}

		switch(InputType[2])
		{
		case SIFC_ARKANOID: mouse=true; break;
		case SIFC_SHADOW:  mouse=true; break;
		case SIFC_FKB:
			if(cidisabled) 
				UpdateFKB();
			break;
		case SIFC_PEC586KB:
		case SIFC_SUBORKB:
			if(cidisabled) 
				UpdateSuborKB();
			break;
		case SIFC_HYPERSHOT: UpdateHyperShot();break;
		case SIFC_MAHJONG: UpdateMahjong();break;
		case SIFC_QUIZKING: UpdateQuizKing();break;
		case SIFC_FTRAINERB:
		case SIFC_FTRAINERA: UpdateFTrainer();break;
		case SIFC_TOPRIDER: UpdateTopRider();break;
		case SIFC_OEKAKIDS: mouse=true; break;
		}

		if(joy)
			UpdateGamepad(false);

		if(mouse)
			if(FCEUMOVState != MOVIEMODE_PLAY)	//FatRatKnight: Moved this if out of the function
				GetMouseData(MouseData);			//A more concise fix may be desired.
	}
}

void FCEUD_SetInput(bool fourscore, bool microphone, ESI port0, ESI port1, ESIFC fcexp)
{
	eoptions &= ~EO_FOURSCORE;
	if(fourscore) eoptions |= EO_FOURSCORE;

	replaceP2StartWithMicrophone = microphone;

	InputType[0]=port0;
	InputType[1]=port1;
	InputType[2]=fcexp;
	InitInputPorts(fourscore);
}

//Initializes the emulator with the current input port configuration
void InitInputPorts(bool fourscore)
{
	void *InputDPtr;

	int attrib;

	if(fourscore)
	{
		FCEUI_SetInput(0,SI_GAMEPAD,&JSreturn,0);
		FCEUI_SetInput(1,SI_GAMEPAD,&JSreturn,0);
	} else
	{
		for(int i=0;i<2;i++)
		{
			attrib=0;
			InputDPtr=0;
			switch(InputType[i])
			{
			case SI_POWERPADA:
			case SI_POWERPADB:
				InputDPtr=&powerpadbuf[i];
				break;
			case SI_GAMEPAD:
				InputDPtr=&JSreturn;
				break;
			case SI_ARKANOID:
				InputDPtr=MouseData;
				break;
			case SI_ZAPPER:
				InputDPtr=MouseData;
				break;
			case SI_MOUSE:
				InputDPtr=MouseData;
				break;
			case SI_SNES_MOUSE:
				InputDPtr=MouseData;
				break;
			case SI_SNES:
				InputDPtr=snespad_return;
				break;
			}
			FCEUI_SetInput(i,(ESI)InputType[i],InputDPtr,attrib);
		}
	}
	FCEUI_SetInputFourscore(fourscore);

	attrib=0;
	InputDPtr=0;
	switch(InputType[2])
	{
	case SIFC_SHADOW:
		InputDPtr=MouseData;
		break;
	case SIFC_OEKAKIDS:
		InputDPtr=MouseData;
		break;
	case SIFC_ARKANOID:
		InputDPtr=MouseData;
		break;
	case SIFC_FKB:
		InputDPtr=fkbkeys;
		break;
	case SIFC_PEC586KB:
	case SIFC_SUBORKB:
		InputDPtr=suborkbkeys;
		break;
	case SIFC_HYPERSHOT:
		InputDPtr=&HyperShotData;
		break;
	case SIFC_MAHJONG:
		InputDPtr=&MahjongData;
		break;
	case SIFC_QUIZKING:
		InputDPtr=&QuizKingData;
		break;
	case SIFC_TOPRIDER:
		InputDPtr=&TopRiderData;
		break;
	case SIFC_BWORLD:
		InputDPtr=BWorldData;
		break;
	case SIFC_FTRAINERA:
	case SIFC_FTRAINERB:
		InputDPtr=&FTrainerData;
		break;
	}

	FCEUI_SetInputFC((ESIFC)InputType[2],InputDPtr,attrib);
}

ButtConfig fkbmap[0x48]=
{
	MK(F1),MK(F2),MK(F3),MK(F4),MK(F5),MK(F6),MK(F7),MK(F8),
	MK(1),MK(2),MK(3),MK(4),MK(5),MK(6),MK(7),MK(8),MK(9),MK(0),
	MK(MINUS),MK(EQUAL),MK(BACKSLASH),MK(BACKSPACE),
	MK(ESCAPE),MK(Q),MK(W),MK(E),MK(R),MK(T),MK(Y),MK(U),MK(I),MK(O),
	MK(P),MK(TILDE),MK(BRACKET_LEFT),MK(ENTER),
	MK(LEFTCONTROL),MK(A),MK(S),MK(D),MK(F),MK(G),MK(H),MK(J),MK(K),
	MK(L),MK(SEMICOLON),MK(APOSTROPHE),MK(BRACKET_RIGHT),MK(INSERT),
	MK(LEFTSHIFT),MK(Z),MK(X),MK(C),MK(V),MK(B),MK(N),MK(M),MK(COMMA),
	MK(PERIOD),MK(SLASH),MK(RIGHTALT),MK(RIGHTSHIFT),MK(LEFTALT),MK(SPACE),
	MK(BL_DELETE),
	MK(BL_END),
	MK(BL_PAGEDOWN),
	MK(BL_CURSORUP),MK(BL_CURSORLEFT),MK(BL_CURSORRIGHT),MK(BL_CURSORDOWN)
};

ButtConfig suborkbmap[0x65]=
{
	MC(0x01),MC(0x3b),MC(0x3c),MC(0x3d),MC(0x3e),MC(0x3f),MC(0x40),MC(0x41),MC(0x42),MC(0x43),
	MC(0x44),MC(0x57),MC(0x58),MC(0x45),MC(0x29),MC(0x02),MC(0x03),MC(0x04),MC(0x05),MC(0x06),
	MC(0x07),MC(0x08),MC(0x09),MC(0x0a),MC(0x0b),MC(0x0c),MC(0x0d),MC(0x0e),MC(0xd2),MC(0xc7),
	MC(0xc9),MC(0xc5),MC(0xb5),MC(0x37),MC(0x4a),MC(0x0f),MC(0x10),MC(0x11),MC(0x12),MC(0x13),
	MC(0x14),MC(0x15),MC(0x16),MC(0x17),MC(0x18),MC(0x19),MC(0x1a),MC(0x1b),MC(0x1c),MC(0xd3),
	MC(0xca),MC(0xd1),MC(0x47),MC(0x48),MC(0x49),MC(0x4e),MC(0x3a),MC(0x1e),MC(0x1f),MC(0x20),
	MC(0x21),MC(0x22),MC(0x23),MC(0x24),MC(0x25),MC(0x26),MC(0x27),MC(0x28),MC(0x4b),MC(0x4c),
	MC(0x4d),MC(0x2a),MC(0x2c),MC(0x2d),MC(0x2e),MC(0x2f),MC(0x30),MC(0x31),MC(0x32),MC(0x33),
	MC(0x34),MC(0x35),MC(0x2b),MC(0xc8),MC(0x4f),MC(0x50),MC(0x51),MC(0x1d),MC(0x38),MC(0x39),
	MC(0xcb),MC(0xd0),MC(0xcd),MC(0x52),MC(0x53),MC(0x00),MC(0x00),MC(0x00),MC(0x00),MC(0x00),
	MC(0x00),
};


static void UpdateFKB(void)
{
	int x;

	for(x=0;x<sizeof(fkbkeys);x++)
	{
		fkbkeys[x]=0;

		if(DTestButton(&fkbmap[x]))
			fkbkeys[x]=1;
	}
}

static void UpdateSuborKB(void)
{
	int x;

	for(x=0;x<sizeof(suborkbkeys);x++)
	{
		suborkbkeys[x]=0;

		if(DTestButton(&suborkbmap[x]))
			suborkbkeys[x]=1;
	}
}

static ButtConfig HyperShotButtons[4]=
{
	MK(Q),MK(W),MK(E),MK(R)
};

static void UpdateSNES()
{
	int x;

	HyperShotData=0;
	for(x=0;x<0x4;x++)
	{
		if(DTestButton(&HyperShotButtons[x]))
			HyperShotData|=1<<x;
	}
}

static void UpdateHyperShot(void)
{
	int x;

	HyperShotData=0;
	for(x=0;x<0x4;x++)
	{
		if(DTestButton(&HyperShotButtons[x]))
			HyperShotData|=1<<x;
	}
}

static ButtConfig MahjongButtons[21]=
{
	MK(Q),MK(W),MK(E),MK(R),MK(T),
	MK(A),MK(S),MK(D),MK(F),MK(G),MK(H),MK(J),MK(K),MK(L),
	MK(Z),MK(X),MK(C),MK(V),MK(B),MK(N),MK(M)
};

static void UpdateMahjong(void)
{
	int x;

	MahjongData=0;
	for(x=0;x<21;x++)
	{  
		if(DTestButton(&MahjongButtons[x]))
			MahjongData|=1<<x;
	}
}

ButtConfig QuizKingButtons[6]=
{
	MK(Q),MK(W),MK(E),MK(R),MK(T),MK(Y)
};

static void UpdateQuizKing(void)
{
	int x;

	QuizKingData=0;

	for(x=0;x<6;x++)
	{
		if(DTestButton(&QuizKingButtons[x]))
			QuizKingData|=1<<x;
	}

}

ButtConfig TopRiderButtons[8]=
{
	MK(Q),MK(W),MK(E),MK(R),MK(T),MK(Y),MK(U),MK(I)
};

static void UpdateTopRider(void)
{
	int x;
	TopRiderData=0;
	for(x=0;x<8;x++)
		if(DTestButton(&TopRiderButtons[x]))
			TopRiderData|=1<<x;
}

ButtConfig FTrainerButtons[12]=
{
	MK(O),MK(P),MK(BRACKET_LEFT),
	MK(BRACKET_RIGHT),MK(K),MK(L),MK(SEMICOLON),
	MK(APOSTROPHE),
	MK(M),MK(COMMA),MK(PERIOD),MK(SLASH)
};

static void UpdateFTrainer(void)
{
	int x;

	FTrainerData=0;

	for(x=0;x<12;x++)
	{
		if(DTestButton(&FTrainerButtons[x]))
			FTrainerData|=1<<x;
	}
}

int DWaitButton(HWND hParent, const uint8 *text, ButtConfig *bc);
int DWaitSimpleButton(HWND hParent, const uint8 *text);

CFGSTRUCT InputConfig[]={
	AC(powerpadsc),
	AC(QuizKingButtons),
	AC(FTrainerButtons),
	AC(HyperShotButtons),
	AC(MahjongButtons),
	AC(GamePadConfig),
	AC(GamePadPreset1),
	AC(GamePadPreset2),
	AC(GamePadPreset3),
	AC(fkbmap),
	AC(suborkbmap),
	ENDCFGSTRUCT
};

void InitInputStuff(void)
{
	int x,y;

	KeyboardInitialize();
	InitJoysticks(hAppWnd);

	for(x=0; x<4; x++)
		for(y=0; y<10; y++)
			JoyClearBC(&GamePadConfig[x][y]);

	for(x=0; x<2; x++)
		for(y=0; y<12; y++)    
			JoyClearBC(&powerpadsc[x][y]);

	for(x=0; x<sizeof(fkbkeys); x++)
		JoyClearBC(&fkbmap[x]);
	for(x=0; x<sizeof(suborkbkeys); x++)
		JoyClearBC(&suborkbmap[x]);

	for(x=0; x<6; x++)
		JoyClearBC(&QuizKingButtons[x]);
	for(x=0; x<12; x++)
		JoyClearBC(&FTrainerButtons[x]);
	for(x=0; x<21; x++)
		JoyClearBC(&MahjongButtons[x]);
	for(x=0; x<4; x++)
		JoyClearBC(&HyperShotButtons[x]);
}

static char *MakeButtString(ButtConfig *bc)
{
	uint32 x; //mbg merge 7/17/06  changed to uint
	char tmpstr[512];
	char *astr;

	tmpstr[0] = 0;

	for(x=0;x<bc->NumC;x++)
	{
		if(x) strcat(tmpstr, ", ");

		if(bc->ButtType[x] == BUTTC_KEYBOARD)
		{
			strcat(tmpstr,"KB: ");
			if(!GetKeyNameText(((bc->ButtonNum[x] & 0x7F) << 16) | ((bc->ButtonNum[x] & 0x80) << 17), tmpstr+strlen(tmpstr), 16))
			{
				// GetKeyNameText wasn't able to provide a name for the key, then just show scancode
				sprintf(tmpstr+strlen(tmpstr),"%03d",bc->ButtonNum[x]);
			}
		}
		else if(bc->ButtType[x] == BUTTC_JOYSTICK)
		{
			strcat(tmpstr,"JS ");
			sprintf(tmpstr+strlen(tmpstr), "%d ", bc->DeviceNum[x]);
			if(bc->ButtonNum[x] & 0x8000)
			{
				char *asel[3]={"x","y","z"};
				sprintf(tmpstr+strlen(tmpstr), "axis %s%s", asel[bc->ButtonNum[x] & 3],(bc->ButtonNum[x]&0x4000)?"-":"+");
			}
			else if(bc->ButtonNum[x] & 0x2000)
			{
				sprintf(tmpstr+strlen(tmpstr), "hat %d:%d", (bc->ButtonNum[x] >> 4)&3,
					bc->ButtonNum[x]&3);
			}
			else
			{
				sprintf(tmpstr+strlen(tmpstr), "button %d", bc->ButtonNum[x] & 127);
			}

		}
	}

	astr=(char*)malloc(strlen(tmpstr) + 1); //mbg merge 7/17/06 added cast
	strcpy(astr,tmpstr);
	return(astr);
}


static int DWBStarted;
static ButtConfig *DWBButtons;
static const uint8 *DWBText;

static HWND die;

static BOOL CALLBACK DWBCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{

	switch(uMsg) {
   case WM_DESTROY:
	   die = NULL;                         
	   return(0);
   case WM_TIMER:
	   {
		   uint8 devicenum;
		   uint16 buttonnum;
		   GUID guid;

		   if(DoJoyWaitTest(&guid, &devicenum, &buttonnum))
		   {
			   ButtConfig *bc = DWBButtons;
			   char *nstr;
			   int wc;
			   if(DWBStarted)
			   {
				   ButtConfig *bc = DWBButtons;
				   bc->NumC = 0;
				   DWBStarted = 0;
			   }
			   wc = bc->NumC;
			   //FCEU_printf("%d: %d\n",devicenum,buttonnum);
			   bc->ButtType[wc]=BUTTC_JOYSTICK;
			   bc->DeviceNum[wc]=devicenum;
			   bc->ButtonNum[wc]=buttonnum;
			   bc->DeviceInstance[wc] = guid;

			   /* Stop config if the user pushes the same button twice in a row. */
			   if(wc && bc->ButtType[wc]==bc->ButtType[wc-1] && bc->DeviceNum[wc]==bc->DeviceNum[wc-1] &&
				   bc->ButtonNum[wc]==bc->ButtonNum[wc-1])   
				   goto gornk;

			   bc->NumC++;

			   /* Stop config if we reached our maximum button limit. */
			   if(bc->NumC >= MAXBUTTCONFIG)
				   goto gornk;
			   nstr = MakeButtString(bc);
			   SetDlgItemText(hwndDlg, LBL_DWBDIALOG_TEXT, nstr);
			   free(nstr);
		   }
	   }
	   break;
   case WM_USER + 666:
	   //SetFocus(GetDlgItem(hwndDlg,LBL_DWBDIALOG_TEXT));
	   if(DWBStarted)
	   {
		   char *nstr;
		   ButtConfig *bc = DWBButtons;
		   bc->NumC = 0;
		   DWBStarted = 0;
		   nstr = MakeButtString(bc);
		   SetDlgItemText(hwndDlg, LBL_DWBDIALOG_TEXT, nstr);
		   free(nstr);
	   }

	   {
		   ButtConfig *bc = DWBButtons;
		   int wc = bc->NumC;
		   char *nstr;

		   bc->ButtType[wc]=BUTTC_KEYBOARD;
		   bc->DeviceNum[wc]=0;
		   bc->ButtonNum[wc]=lParam&255;

		   //Stop config if the user pushes the same button twice in a row.
		   if(wc && bc->ButtType[wc]==bc->ButtType[wc-1] && bc->DeviceNum[wc]==bc->DeviceNum[wc-1] &&
			   bc->ButtonNum[wc]==bc->ButtonNum[wc-1])   
			   goto gornk;

		   bc->NumC++;
		   //Stop config if we reached our maximum button limit.
		   if(bc->NumC >= MAXBUTTCONFIG)
			   goto gornk;

		   nstr = MakeButtString(bc);
		   SetDlgItemText(hwndDlg, LBL_DWBDIALOG_TEXT, nstr);
		   free(nstr);
	   }
	   break;
   case WM_INITDIALOG:
	   SetWindowText(hwndDlg, (char*)DWBText); //mbg merge 7/17/06 added cast
	   BeginJoyWait(hwndDlg);
	   SetTimer(hwndDlg,666,25,0);     //Every 25ms.
	   {
		   char *nstr = MakeButtString(DWBButtons);
		   SetDlgItemText(hwndDlg, LBL_DWBDIALOG_TEXT, nstr);
		   free(nstr);
	   }
   
	   

	   break;
   case WM_CLOSE:
   case WM_QUIT: goto gornk;

   case WM_COMMAND:
	   switch(wParam&0xFFFF)
	   {
	   case BTN_CLEAR:
		   {
			   ButtConfig *bc = DWBButtons;                
			   char *nstr;
			   bc->NumC = 0;
			   nstr = MakeButtString(bc);
			   SetDlgItemText(hwndDlg, LBL_DWBDIALOG_TEXT, nstr);
			   free(nstr);
		   }
		   break;
	   case BTN_CLOSE:
gornk:
		   KillTimer(hwndDlg,666);
		   EndJoyWait(hAppWnd);
		   SetForegroundWindow(GetParent(hwndDlg));
		   DestroyWindow(hwndDlg);
		   break;
	   }
	}
	return 0;
}

int DWaitButton(HWND hParent, const uint8 *text, ButtConfig *bc)
{
	DWBText=text;
	DWBButtons = bc;
	DWBStarted = 1;

	die = CreateDialog(fceu_hInstance, "DWBDIALOG", hParent, DWBCallB);

	EnableWindow(hParent, 0);

	ShowWindow(die, 1);

	while(die)
	{
		MSG msg;
		while(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE))
		{
			if(GetMessage(&msg, 0, 0, 0) > 0)
			{
				if(msg.message == WM_KEYDOWN || msg.message == WM_SYSKEYDOWN)
				{
					LPARAM tmpo;

					tmpo = ((msg.lParam >> 16) & 0x7F) | ((msg.lParam >> 17) & 0x80);
					PostMessage(die,WM_USER+666,0,tmpo);
					continue;
				}
				if(msg.message == WM_SYSCOMMAND) continue;
				if(!IsDialogMessage(die, &msg))
				{
					TranslateMessage(&msg);
					DispatchMessage(&msg);
				}
			}
		}
		Sleep(10);
	}

	EnableWindow(hParent, 1);
	return 0; //mbg merge TODO 7/17/06  - had to add this return value--is it right?
}

int DWaitSimpleButton(HWND hParent, const uint8 *text)
{
	DWBStarted = 1;
	int ret = 0;

	die = CreateDialog(fceu_hInstance, "DWBDIALOGSIMPLE", hParent, NULL);
	SetWindowText(die, (char*)text); //mbg merge 7/17/06 added cast
	EnableWindow(hParent, 0);

	ShowWindow(die, 1);

	while(die)
	{
		MSG msg;
		while(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE))
		{
			if(GetMessage(&msg, 0, 0, 0) > 0)
			{
				if(msg.message == WM_KEYDOWN || msg.message == WM_SYSKEYDOWN)
				{
					LPARAM tmpo;

					tmpo=((msg.lParam>>16)&0x7F)|((msg.lParam>>17)&0x80);
					ret = tmpo;
					goto done;
				}
				if(msg.message == WM_SYSCOMMAND) continue;
				if(!IsDialogMessage(die, &msg))
				{
					TranslateMessage(&msg);
					DispatchMessage(&msg);
				}
			}
		}
		Sleep(10);
	}
done:
	EndDialog(die,0);
	EnableWindow(hParent, 1);

	if(ret == 1) // convert Esc to nothing (why is it 1 and not VK_ESCAPE?)
		ret = 0;
	return ret;
}


static ButtConfig *DoTBButtons=0;
static const char *DoTBTitle=0;
static int DoTBMax=0;
static int DoTBType=0,DoTBPort=0;

static BOOL CALLBACK DoTBCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg) {
   case WM_INITDIALOG:
	   if(DoTBType == SI_GAMEPAD)
	   {
		   char buf[32];
		   sprintf(buf,"Virtual Gamepad %d",DoTBPort+1);
		   SetDlgItemText(hwndDlg, GRP_GAMEPAD1,buf);

		   sprintf(buf,"Virtual Gamepad %d",DoTBPort+3);
		   SetDlgItemText(hwndDlg, GRP_GAMEPAD2, buf);
	   }
	   if(DoTBType == SI_SNES)
	   {
		   char buf[32];
		   sprintf(buf,"Virtual SNES Pad %d",DoTBPort+1);
		   SetDlgItemText(hwndDlg, GRP_GAMEPAD1,buf);
	   }
	   SetWindowText(hwndDlg, DoTBTitle);
	   break;
   case WM_CLOSE:
   case WM_QUIT: goto gornk;

   case WM_COMMAND:
	   {
		   int b;
		   b=wParam&0xFFFF;
		   if(b>= 300 && b < (300 + DoTBMax))
		   {
			   char btext[128];
			   btext[0]=0;
			   GetDlgItemText(hwndDlg, b, btext, 128);
			   DWaitButton(hwndDlg, (uint8*)btext,&DoTBButtons[b - 300]); //mbg merge 7/17/06 added cast
		   }
		   else switch(wParam&0xFFFF)
		   {
   case BTN_CLOSE:
gornk:

	   EndDialog(hwndDlg,0);
	   break;
		   }
	   }
	}
	return 0;
}

static void DoTBConfig(HWND hParent, const char *text, char *_template, ButtConfig *buttons, int max)
{
	DoTBTitle=text;
	DoTBButtons = buttons;
	DoTBMax = max;
	DialogBox(fceu_hInstance,_template,hParent,DoTBCallB);
}


const unsigned int NUMBER_OF_PORTS = 2;
const unsigned int NUMBER_OF_NES_DEVICES = SI_COUNT + 1;
const static unsigned int NUMBER_OF_FAMICOM_DEVICES = SIFC_COUNT + 1;
//these are unfortunate lists. they match the ESI and ESIFC enums
static const int configurable_nes[NUMBER_OF_NES_DEVICES]= { 0, 1, 0, 1, 1, 0, 0, 1 };
static const int configurable_fam[NUMBER_OF_FAMICOM_DEVICES]= { 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0 };
const unsigned int FAMICOM_POSITION = 2;

static void UpdateComboPad(HWND hwndDlg, WORD id)
{
	unsigned int sel_input = id - COMBO_PAD1;

	// Update the user input type
	InputType[sel_input] =
		SendDlgItemMessage(
		hwndDlg,
		id,
		CB_GETCURSEL,
		0,
		(LPARAM)(LPSTR)0
		);

	// Enable or disable the configuration button
	EnableWindow(
		GetDlgItem(hwndDlg, id + 2),
		configurable_nes[InputType[sel_input]]
	);

	// Update the text field
	SetDlgItemText(
		hwndDlg,
		TXT_PAD1 + sel_input,
		(LPTSTR)ESI_Name((ESI)InputType[sel_input])
	);
}

static void UpdateComboFam(HWND hwndDlg)
{
// Update the user input type of the famicom
	InputType[FAMICOM_POSITION] =
		SendDlgItemMessage(
		hwndDlg,
		COMBO_FAM,
		CB_GETCURSEL,
		0,
		(LPARAM)(LPSTR)0
		);

	// Enable or disable the configuration button
	EnableWindow(
		GetDlgItem(hwndDlg, BTN_FAM),
		configurable_fam[InputType[FAMICOM_POSITION]]
	);

	// Update the text field
	SetDlgItemText(
		hwndDlg,
		TXT_FAM,
		(LPTSTR)ESIFC_Name((ESIFC)InputType[FAMICOM_POSITION])
	);
}


static void UpdateFourscoreState(HWND dlg)
{
	//(inverse logic:)
	BOOL enable = (eoptions & EO_FOURSCORE)?FALSE:TRUE;

	EnableWindow(GetDlgItem(dlg,BTN_PORT1),enable);
	EnableWindow(GetDlgItem(dlg,BTN_PORT2),enable);
	EnableWindow(GetDlgItem(dlg,COMBO_PAD1),enable);
	EnableWindow(GetDlgItem(dlg,COMBO_PAD2),enable);
	EnableWindow(GetDlgItem(dlg,TXT_PAD1),enable);
	EnableWindow(GetDlgItem(dlg,TXT_PAD2),enable);
	
	//change the inputs to gamepad
	if(!enable)
	{
		SendMessage(GetDlgItem(dlg,COMBO_PAD1),CB_SETCURSEL,SI_GAMEPAD,0);
		SendMessage(GetDlgItem(dlg,COMBO_PAD2),CB_SETCURSEL,SI_GAMEPAD,0);
		UpdateComboPad(dlg,COMBO_PAD1);
		UpdateComboPad(dlg,COMBO_PAD2);
		SetDlgItemText(dlg,TXT_PAD1,ESI_Name(SI_GAMEPAD));
		SetDlgItemText(dlg,TXT_PAD2,ESI_Name(SI_GAMEPAD));
	}
}

//Callback function of the input configuration dialog.
BOOL CALLBACK InputConCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
	case WM_INITDIALOG:     
		// Update the disable UDLR checkbox based on the current value
		CheckDlgButton(hwndDlg,BTN_ALLOW_LRUD,allowUDLR?BST_CHECKED:BST_UNCHECKED);

		//update the fourscore checkbox
		CheckDlgButton(hwndDlg,CHECK_ENABLE_FOURSCORE,(eoptions & EO_FOURSCORE)?BST_CHECKED:BST_UNCHECKED);

		//update the microphone checkbox
		CheckDlgButton(hwndDlg,CHECK_ENABLE_MICROPHONE,replaceP2StartWithMicrophone?BST_CHECKED:BST_UNCHECKED);

		// Initialize the controls for the input ports
		for(unsigned int port = 0; port < NUMBER_OF_PORTS; port++)        
		{
			// Initialize the combobox
			for(unsigned int current_device = 0; current_device < NUMBER_OF_NES_DEVICES; current_device++)
			{
				SendDlgItemMessage(hwndDlg,
					COMBO_PAD1 + port,
					CB_ADDSTRING, 0,
					(LPARAM)(LPSTR)ESI_Name((ESI)current_device)
				);
			}

			// Fix to deal with corrupted config. 
			if (InputType[port]>SI_COUNT || InputType[port]<0)
				InputType[port]=SI_UNSET; 

			// Update the combobox selection according to the
			// currently selected input mode.
			SendDlgItemMessage(hwndDlg,
				COMBO_PAD1 + port,
				CB_SETCURSEL,
				InputType[port],
				(LPARAM)(LPSTR)0
				);

			// Enable the configuration button if necessary.
			EnableWindow(
				GetDlgItem(hwndDlg, BTN_PORT1 + port),
				configurable_nes[InputType[port]]
			);

			// Update the label that displays the input device.
			SetDlgItemText(
				hwndDlg,
				TXT_PAD1 + port,
				(LPTSTR)ESI_Name((ESI)InputType[port])
			);
		}

		// Initialize the Famicom combobox
		for(unsigned current_device = 0; current_device < NUMBER_OF_FAMICOM_DEVICES; current_device++)
		{
			SendDlgItemMessage(
				hwndDlg,
				COMBO_FAM,
				CB_ADDSTRING,
				0,
				(LPARAM)(LPSTR)ESIFC_Name((ESIFC)current_device)
			);
		}

		if (InputType[FAMICOM_POSITION]>SIFC_COUNT || InputType[FAMICOM_POSITION]<0)
			InputType[FAMICOM_POSITION]=SIFC_UNSET; 

		// Update the combobox selection according to the
		// currently selected input mode.
		SendDlgItemMessage(
			hwndDlg,
			COMBO_FAM,
			CB_SETCURSEL,
			InputType[FAMICOM_POSITION],
			(LPARAM)(LPSTR)0
			);

		// Enable the configuration button if necessary.
		EnableWindow(
			GetDlgItem(hwndDlg, BTN_FAM),
			configurable_fam[InputType[FAMICOM_POSITION]]
		);

		// Update the label that displays the input device.
		SetDlgItemText(
			hwndDlg,
			TXT_FAM,
			(LPTSTR)ESIFC_Name((ESIFC)InputType[FAMICOM_POSITION])
		);

		// Initialize the auto key controls
		extern int autoHoldKey, autoHoldClearKey;
		char btext[128];
		if (autoHoldKey)
		{
			if (!GetKeyNameText(autoHoldKey << 16, btext, 128))
				sprintf(btext, "KB: %d", autoHoldKey);
		} else
		{
			sprintf(btext, "not assigned");
		}
		SetDlgItemText(hwndDlg, LBL_AUTO_HOLD, btext);

		if (autoHoldClearKey)
		{
			if (!GetKeyNameText(autoHoldClearKey << 16, btext, 128))
				sprintf(btext, "KB: %d", autoHoldClearKey);
		} else
		{
			sprintf(btext, "not assigned");
		}
		SetDlgItemText(hwndDlg, LBL_CLEAR_AH, btext);

		CenterWindowOnScreen(hwndDlg);
		UpdateFourscoreState(hwndDlg);

		if (!FCEUMOV_Mode(MOVIEMODE_INACTIVE))
		{
			// disable changing fourscore and Input ports while a movie is recorded/played
			EnableWindow(GetDlgItem(hwndDlg, CHECK_ENABLE_FOURSCORE), false);
			EnableWindow(GetDlgItem(hwndDlg, CHECK_ENABLE_MICROPHONE), false);
			EnableWindow(GetDlgItem(hwndDlg, COMBO_PAD1), false);
			EnableWindow(GetDlgItem(hwndDlg, COMBO_PAD2), false);
			EnableWindow(GetDlgItem(hwndDlg, COMBO_FAM), false);
		}

		break;

	case WM_CLOSE:
	case WM_QUIT:
		EndDialog(hwndDlg, 0);

	case WM_COMMAND:
		// Handle disable UD/LR option
		if(HIWORD(wParam) == BN_CLICKED && LOWORD(wParam) == BTN_ALLOW_LRUD)
		{
			FCEU_printf("Allow UDLR toggled.\n");
			allowUDLR = !allowUDLR;
		}

		//Handle the fourscore button
		if(HIWORD(wParam) == BN_CLICKED && LOWORD(wParam) == CHECK_ENABLE_FOURSCORE)
		{
			eoptions ^= EO_FOURSCORE;
			FCEU_printf("Fourscore toggled to %s\n",(eoptions & EO_FOURSCORE)?"ON":"OFF");
			UpdateFourscoreState(hwndDlg);
		}

		//Handle the fourscore button
		if(HIWORD(wParam) == BN_CLICKED && LOWORD(wParam) == CHECK_ENABLE_MICROPHONE)
		{
			replaceP2StartWithMicrophone = !replaceP2StartWithMicrophone;
			FCEU_printf("Microphone toggled to %s\n",replaceP2StartWithMicrophone?"ON":"OFF");
		}
		

		if(HIWORD(wParam) == CBN_SELENDOK)
		{
			switch(LOWORD(wParam))
			{
			case COMBO_PAD1:
			case COMBO_PAD2:
				UpdateComboPad(hwndDlg, LOWORD(wParam));
				break;

			case COMBO_FAM:
				UpdateComboFam(hwndDlg);
				break;
			}

		}

		if( !(wParam >> 16) )
		{
			switch(wParam & 0xFFFF)
			{
			case BTN_FAM:
				{
					const char *text = ESIFC_Name((ESIFC)InputType[FAMICOM_POSITION]);

					DoTBType = DoTBPort = 0;

					switch(InputType[FAMICOM_POSITION])
					{
					case SIFC_FTRAINERA:
					case SIFC_FTRAINERB:
						DoTBConfig(hwndDlg, text, "POWERPADDIALOG", FTrainerButtons, 12);
						break;
					case SIFC_FKB:
						DoTBConfig(hwndDlg, text, "FKBDIALOG", fkbmap, sizeof(fkbkeys));
						break;
					case SIFC_PEC586KB:
					case SIFC_SUBORKB:
						DoTBConfig(hwndDlg, text, "SUBORKBDIALOG", suborkbmap, sizeof(suborkbkeys));
						break;
					case SIFC_MAHJONG:
						DoTBConfig(hwndDlg, text, "MAHJONGDIALOG", MahjongButtons, 21);
						break;
					case SIFC_QUIZKING:
						DoTBConfig(hwndDlg, text, "QUIZKINGDIALOG", QuizKingButtons, 6);
						break;
					}
				}

				break;

			case BTN_PORT2:
			case BTN_PORT1:
				{
					int which = (wParam & 0xFFFF) - BTN_PORT1;
					const char *text = ESI_Name((ESI)InputType[which]);

					DoTBType = DoTBPort = 0;

					switch(InputType[which])
					{
					case SI_GAMEPAD:
					case SI_SNES:
						{
							ButtConfig tmp[12 + 12];

							memcpy(tmp, GamePadConfig[which], 12 * sizeof(ButtConfig));
							memcpy(&tmp[12], GamePadConfig[which + 2], 12 * sizeof(ButtConfig));

							DoTBType = InputType[which];
							DoTBPort = which;
							if(DoTBType == SI_GAMEPAD)
								DoTBConfig(hwndDlg, text, "GAMEPADDIALOG", tmp, 12 + 12);
							else 
								DoTBConfig(hwndDlg, text, MAKEINTRESOURCE(DLG_SNESPAD), tmp, 12); //no 2nd controller since no four score

							memcpy(GamePadConfig[which], tmp, 12 * sizeof(ButtConfig));
							memcpy(GamePadConfig[which + 2], &tmp[12], 12 * sizeof(ButtConfig));
						}
						break;

					case SI_POWERPADA:
					case SI_POWERPADB:
						DoTBConfig(hwndDlg, text, "POWERPADDIALOG", powerpadsc[which], 12);
						break;
					}
				}

				break;

			case BTN_PRESET_SET1:
				MessageBox(0, "Current input configuration has been set as Preset 1.", FCEU_NAME, MB_ICONINFORMATION | MB_OK | MB_SETFOREGROUND | MB_TOPMOST);
				memcpy(GamePadPreset1, GamePadConfig, sizeof(GamePadConfig));
				break;
			case BTN_PRESET_SET2:
				MessageBox(0, "Current input configuration has been set as Preset 2.", FCEU_NAME, MB_ICONINFORMATION | MB_OK | MB_SETFOREGROUND | MB_TOPMOST);
				memcpy(GamePadPreset2, GamePadConfig, sizeof(GamePadConfig));
				break;
			case BTN_PRESET_SET3:
				MessageBox(0, "Current input configuration has been set as Preset 3.", FCEU_NAME, MB_ICONINFORMATION | MB_OK | MB_SETFOREGROUND | MB_TOPMOST);
				memcpy(GamePadPreset3, GamePadConfig, sizeof(GamePadConfig));
				break;

			case BTN_PRESET_EXPORT1: PresetExport(1); break;
			case BTN_PRESET_EXPORT2: PresetExport(2); break;
			case BTN_PRESET_EXPORT3: PresetExport(3); break;

			case BTN_PRESET_IMPORT1: PresetImport(1); break;
			case BTN_PRESET_IMPORT2: PresetImport(2); break;
			case BTN_PRESET_IMPORT3: PresetImport(3); break;

			case BTN_AUTO_HOLD: // auto-hold button
				{
					char btext[128] = { 0 };

					GetDlgItemText(hwndDlg, BTN_AUTO_HOLD, btext, sizeof(btext) );

					int button = DWaitSimpleButton(hwndDlg, (uint8*)btext); //mbg merge 7/17/06 

					if(button)
					{
						if(!GetKeyNameText(button << 16, btext, 128))
						{
							sprintf(btext, "KB: %d", button);
						}
					}
					else
					{
						sprintf(btext, "not assigned");
					}

					extern int autoHoldKey;
					autoHoldKey = button;
					SetDlgItemText(hwndDlg, LBL_AUTO_HOLD, btext);
				}
				break;

			case BTN_CLEAR_AH: // auto-hold clear button
				{
					char btext[128] = { 0 };

					GetDlgItemText(hwndDlg, BTN_CLEAR_AH, btext, 128);

					int button = DWaitSimpleButton(hwndDlg, (uint8*)btext); //mbg merge 7/17/06 added cast

					if(button)
					{
						if( !GetKeyNameText(button << 16, btext, sizeof(btext)))
						{
							sprintf(btext, "KB: %d", button);
						}
					}
					else
					{
						sprintf(btext, "not assigned");
					}

					extern int autoHoldClearKey;
					autoHoldClearKey = button;

					SetDlgItemText(hwndDlg, LBL_CLEAR_AH, btext);
				}
				break;

			case BTN_CLOSE:
				EndDialog(hwndDlg, 0);
				break;
			}
		}
	}

	return 0;
}

//Shows the input configuration dialog.
void ConfigInput(HWND hParent)
{
	DialogBox(fceu_hInstance, "INPUTCONFIG", hParent, InputConCallB);

	//in case the input config changes while a game is running, reconfigure the input ports
	if(GameInfo)
	{
		InitInputPorts((eoptions & EO_FOURSCORE)!=0);
	}
}

void DestroyInput(void)
{
	if(lpDI)
	{
		KillJoysticks();
		KeyboardClose();
		IDirectInput7_Release(lpDI);
	}
}

int FCEUD_CommandMapping[EMUCMD_MAX];

CFGSTRUCT HotkeyConfig[]={
	AC(FCEUD_CommandMapping),
	ENDCFGSTRUCT
};

int FCEUD_TestCommandState(int c)
{
	int cmd=FCEUD_CommandMapping[c];
	int cmdmask=cmd&CMD_KEY_MASK;

	// allow certain commands be affected by key repeat
	if(c == EMUCMD_FRAME_ADVANCE/*
								|| c == EMUCMD_SOUND_VOLUME_UP
								|| c == EMUCMD_SOUND_VOLUME_DOWN
								|| c == EMUCMD_SPEED_SLOWER
								|| c == EMUCMD_SPEED_FASTER*/)
	{
		keys=GetKeyboard_nr(); 
		/*		if((cmdmask & CMD_KEY_LALT) == CMD_KEY_LALT
		|| (cmdmask & CMD_KEY_RALT) == CMD_KEY_RALT
		|| (cmdmask & CMD_KEY_LALT) == CMD_KEY_LALT
		|| (cmdmask & CMD_KEY_LCTRL) == CMD_KEY_LCTRL
		|| (cmdmask & CMD_KEY_RCTRL) == CMD_KEY_RCTRL
		|| (cmdmask & CMD_KEY_LSHIFT) == CMD_KEY_LSHIFT
		|| (cmdmask & CMD_KEY_RSHIFT) == CMD_KEY_RSHIFT)*/
		keys_nr=GetKeyboard_nr();
		//		else
		//			keys_nr=GetKeyboard_nr();
	}
	else if(c != EMUCMD_SPEED_TURBO && c != EMUCMD_TASEDITOR_REWIND) // TODO: this should be made more general by detecting if the command has an "off" function
	{
		keys=GetKeyboard_jd();
		keys_nr=GetKeyboard_nr(); 
	}
	else
	{
		keys=GetKeyboard_nr(); 
		keys_nr=GetKeyboard_nr();
	}

	/* test CTRL, SHIFT, ALT */
	if (cmd & CMD_KEY_ALT)
	{
		int ctlstate =	(cmd & CMD_KEY_LALT) ? keys_nr[SCAN_LEFTALT] : 0;
		ctlstate |=		(cmd & CMD_KEY_RALT) ? keys_nr[SCAN_RIGHTALT] : 0;
		if (!ctlstate)
			return 0;
	}
	else if((cmdmask != SCAN_LEFTALT && keys_nr[SCAN_LEFTALT]) || (cmdmask != SCAN_RIGHTALT && keys_nr[SCAN_RIGHTALT]))
		return 0;

	if (cmd & CMD_KEY_CTRL)
	{
		int ctlstate =	(cmd & CMD_KEY_LCTRL) ? keys_nr[SCAN_LEFTCONTROL] : 0;
		ctlstate |=		(cmd & CMD_KEY_RCTRL) ? keys_nr[SCAN_RIGHTCONTROL] : 0;
		if (!ctlstate)
			return 0;
	}
	else if((cmdmask != SCAN_LEFTCONTROL && keys_nr[SCAN_LEFTCONTROL]) || (cmdmask != SCAN_RIGHTCONTROL && keys_nr[SCAN_RIGHTCONTROL]))
		return 0;

	if (cmd & CMD_KEY_SHIFT)
	{
		int ctlstate =	(cmd & CMD_KEY_LSHIFT) ? keys_nr[SCAN_LEFTSHIFT] : 0;
		ctlstate |=		(cmd & CMD_KEY_RSHIFT) ? keys_nr[SCAN_RIGHTSHIFT] : 0;
		if (!ctlstate)
			return 0;
	}
	else if((cmdmask != SCAN_LEFTSHIFT && keys_nr[SCAN_LEFTSHIFT]) || (cmdmask != SCAN_RIGHTSHIFT && keys_nr[SCAN_RIGHTSHIFT]))
		return 0;

	return keys[cmdmask] ? 1 : 0;
}

void FCEUD_TurboOn    (void) 
	{ 
		tempwinsync = winsync;	//Store winsync setting
		winsync = 0;			//turn off winsync for turbo (so that turbo can function even with VBlank sync methods
		tempsoundquality = soundquality;	//Store sound quality settings
		FCEUI_SetSoundQuality(0);			//Turn sound quality to low
		turbo = true; 
		if (muteTurbo && soundo) TrashSound();
	}
void FCEUD_TurboOff   (void) 
	{
		winsync = tempwinsync;				//Restore winsync setting
		soundquality = tempsoundquality;	//Restore sound quality settings
		FCEUI_SetSoundQuality(soundquality);
		turbo = false; 
		if (muteTurbo && soundo) InitSound();
	}
void FCEUD_TurboToggle(void) 
{ 
	if (turbo) {
		winsync = tempwinsync;	//If turbo was on, restore winsync
		soundquality = tempsoundquality; //and restore sound quality setting
		FCEUI_SetSoundQuality(soundquality);
	}
	else
	{
		tempwinsync = winsync;				//Store video sync settings
		tempsoundquality = soundquality;	//Store sound quality settings
		winsync = 0;				//If turbo was off, turn off winsync (so that turbo can function even with VBlank sync methods
		FCEUI_SetSoundQuality(0);	//Set sound quality to low
	}

	turbo = !turbo; 
	if (muteTurbo && soundo)
	{
		if (turbo) TrashSound();
		if (!turbo) InitSound();
	}
}

void FCEUI_UseInputPreset(int preset)
{
	switch(preset)
	{
		case 0: memcpy(GamePadConfig, GamePadPreset1, sizeof(GamePadPreset1)); break;
		case 1: memcpy(GamePadConfig, GamePadPreset2, sizeof(GamePadPreset2)); break;
		case 2: memcpy(GamePadConfig, GamePadPreset3, sizeof(GamePadPreset3)); break;
	}
	FCEU_DispMessage("Using input preset %d.",0,preset+1);
}

static void PresetExport(int preset)
{
	const char filter[]="Input Preset File (*.pre)\0*.pre\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Export Input Preset To...";
	ofn.lpstrFilter=filter;
	nameo[0]=0; //No default filename
	ofn.lpstrFile=nameo;
	ofn.lpstrDefExt="pre";
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT;
	std::string initdir = FCEU_GetPath(FCEUMKF_INPUT).c_str();
	ofn.lpstrInitialDir=initdir.c_str();
	if(GetSaveFileName(&ofn))
	{
		//Save the directory
		if(ofn.nFileOffset < 1024)
		{
			free(InputPresetDir);
			InputPresetDir=(char*)malloc(strlen(ofn.lpstrFile)+1);
			strcpy(InputPresetDir,ofn.lpstrFile);
			InputPresetDir[ofn.nFileOffset]=0;
		}

		FILE *fp=FCEUD_UTF8fopen(nameo,"w");
		switch(preset)
		{
		case 1: fwrite(GamePadPreset1,1,sizeof(GamePadPreset1),fp); break;
		case 2: fwrite(GamePadPreset2,1,sizeof(GamePadPreset2),fp); break;
		case 3: fwrite(GamePadPreset3,1,sizeof(GamePadPreset3),fp); break;
		}
		fclose(fp);
	}
}

static void PresetImport(int preset)
{
	const char filter[]="Input Preset File (*.pre)\0*.pre\0\0";
	char nameo[2048];
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Import Input Preset......";
	ofn.lpstrFilter=filter;
	nameo[0]=0;
	ofn.lpstrFile=nameo;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	std::string initdir = FCEU_GetPath(FCEUMKF_INPUT);
	ofn.lpstrInitialDir=initdir.c_str();

	if(GetOpenFileName(&ofn))
	{
		//Save the directory
		if(ofn.nFileOffset < 1024)
		{
			free(InputPresetDir);
			InputPresetDir=(char*)malloc(strlen(ofn.lpstrFile)+1);
			strcpy(InputPresetDir,ofn.lpstrFile);
			InputPresetDir[ofn.nFileOffset]=0;
		}

		FILE *fp=FCEUD_UTF8fopen(nameo,"r");
		switch(preset)
		{
		case 1: fread(GamePadPreset1,1,sizeof(GamePadPreset1),fp); break;
		case 2: fread(GamePadPreset2,1,sizeof(GamePadPreset2),fp); break;
		case 3: fread(GamePadPreset3,1,sizeof(GamePadPreset3),fp); break;
		}
		fclose(fp);
	}
}


//commandline input config. not being used right now
//---------------------------
//static void FCExp(char *text)
//{
//	static char *fccortab[12]={"none","arkanoid","shadow","4player","fkb","suborkb",
//		"hypershot","mahjong","quizking","ftrainera","ftrainerb","oekakids"};
//
//	static int fccortabi[12]={SIFC_NONE,SIFC_ARKANOID,SIFC_SHADOW,
//		SIFC_4PLAYER,SIFC_FKB,SIFC_SUBORKB,SIFC_HYPERSHOT,SIFC_MAHJONG,SIFC_QUIZKING,
//		SIFC_FTRAINERA,SIFC_FTRAINERB,SIFC_OEKAKIDS};
//	int y;
//	for(y=0;y<12;y++)
//		if(!strcmp(fccortab[y],text))
//			UsrInputType[2]=fccortabi[y];
//}
//static char *cortab[6]={"none","gamepad","zapper","powerpada","powerpadb","arkanoid"};
//static int cortabi[6]={SI_NONE,SI_GAMEPAD,
//                               SI_ZAPPER,SI_POWERPADA,SI_POWERPADB,SI_ARKANOID};
//static void Input1(char *text)
//{
//	int y;
//
//	for(y=0;y<6;y++)
//	 if(!strcmp(cortab[y],text))
//	  UsrInputType[0]=cortabi[y];
//}
//
//static void Input2(char *text)
//{
//	int y;
//
//	for(y=0;y<6;y++)
//	 if(!strcmp(cortab[y],text))
//	  UsrInputType[1]=cortabi[y];
//}
//ARGPSTRUCT InputArgs[]={
//	{"-fcexp",0,(void *)FCExp,0x2000},
//	{"-input1",0,(void *)Input1,0x2000},
//	{"-input2",0,(void *)Input2,0x2000},
//	{0,0,0,0}
//};
