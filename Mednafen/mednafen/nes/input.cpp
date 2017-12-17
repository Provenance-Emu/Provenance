/* Mednafen - Multi-system Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO 
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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "nes.h"
#include "x6502.h"
#include "sound.h"
#include "input.h"
#include "vsuni.h"
#include "fds.h"
#include "input/cursor.h"

extern INPUTC *MDFN_InitZapper(int w);
extern INPUTC *MDFN_InitPowerpadA(int w);
extern INPUTC *MDFN_InitPowerpadB(int w);
extern INPUTC *MDFN_InitArkanoid(int w);

extern INPUTCFC *MDFN_InitArkanoidFC(void);
extern INPUTCFC *MDFN_InitSpaceShadow(void);
extern INPUTCFC *MDFN_InitFKB(void);
extern INPUTCFC *MDFN_InitHS(void);
extern INPUTCFC *MDFN_InitMahjong(void);
extern INPUTCFC *MDFN_InitPartyTap(void);
extern INPUTCFC *MDFN_InitFamilyTrainerA(void);
extern INPUTCFC *MDFN_InitFamilyTrainerB(void);
extern INPUTCFC *MDFN_InitOekaKids(void);
extern INPUTCFC *MDFN_InitTopRider(void);
extern INPUTCFC *MDFN_InitBarcodeWorld(void);

namespace MDFN_IEN_NES
{

static const IDIISG GamepadIDII =
{
 { "a", "A", 7, IDIT_BUTTON_CAN_RAPID, NULL },
 { "b", "B", 6, IDIT_BUTTON_CAN_RAPID, NULL },
 { "select", "SELECT", 4, IDIT_BUTTON, NULL },
 { "start", "START", 5, IDIT_BUTTON, NULL },
 { "up", "UP ↑", 0, IDIT_BUTTON, "down" },
 { "down", "DOWN ↓", 1, IDIT_BUTTON, "up" },
 { "left", "LEFT ←", 2, IDIT_BUTTON, "right" },
 { "right", "RIGHT →", 3, IDIT_BUTTON, "left" },
};

static const IDIISG ZapperIDII =
{
 { "x_axis", "X Axis", -1, IDIT_X_AXIS },
 { "y_axis", "Y Axis", -1, IDIT_Y_AXIS },
 { "trigger", "Trigger", 0, IDIT_BUTTON, NULL  },
 { "away_trigger", "Away Trigger", 1, IDIT_BUTTON, NULL  },
};

static const IDIISG PowerpadIDII =
{
 { "1", "1", 0, IDIT_BUTTON, NULL },
 { "2", "2", 1, IDIT_BUTTON, NULL },
 { "3", "3", 2, IDIT_BUTTON, NULL },
 { "4", "4", 3, IDIT_BUTTON, NULL },
 { "5", "5", 4, IDIT_BUTTON, NULL },
 { "6", "6", 5, IDIT_BUTTON, NULL },
 { "7", "7", 6, IDIT_BUTTON, NULL },
 { "8", "8", 7, IDIT_BUTTON, NULL },
 { "9", "9", 8, IDIT_BUTTON, NULL },
 { "10", "10", 9, IDIT_BUTTON, NULL },
 { "11", "11", 10, IDIT_BUTTON, NULL },
 { "12", "12", 11, IDIT_BUTTON, NULL },
};

static const IDIISG ArkanoidIDII =
{
 { "x_axis", "X Axis", -1, IDIT_X_AXIS },
 { "button", "Button", 0, IDIT_BUTTON, NULL },
};

static const IDIISG FKBIDII =
{
 { "f1", "F1", 0, IDIT_BUTTON },
 { "f2", "F2", 1, IDIT_BUTTON },
 { "f3", "F3", 2, IDIT_BUTTON },
 { "f4", "F4", 3, IDIT_BUTTON },
 { "f5", "F5", 4, IDIT_BUTTON },
 { "f6", "F6", 5, IDIT_BUTTON },
 { "f7", "F7", 6, IDIT_BUTTON },
 { "f8", "F8", 7, IDIT_BUTTON },

 { "1", "1", 8, IDIT_BUTTON },
 { "2", "2", 9, IDIT_BUTTON },
 { "3", "3", 10, IDIT_BUTTON },
 { "4", "4", 11, IDIT_BUTTON },
 { "5", "5", 12, IDIT_BUTTON },
 { "6", "6", 13, IDIT_BUTTON },
 { "7", "7", 14, IDIT_BUTTON },
 { "8", "8", 15, IDIT_BUTTON },
 { "9", "9", 16, IDIT_BUTTON },
 { "0", "0", 17, IDIT_BUTTON },
 { "minus", "-", 18, IDIT_BUTTON },
 { "caret", "^", 19, IDIT_BUTTON },
 { "backslash", "\\", 20, IDIT_BUTTON },
 { "stop", "STOP", 21, IDIT_BUTTON },

 { "escape", "ESC", 22, IDIT_BUTTON },
 { "q", "Q", 23, IDIT_BUTTON },
 { "w", "W", 24, IDIT_BUTTON },
 { "e", "E", 25, IDIT_BUTTON },
 { "r", "R", 26, IDIT_BUTTON },
 { "t", "T", 27, IDIT_BUTTON },
 { "y", "Y", 28, IDIT_BUTTON },
 { "u", "U", 29, IDIT_BUTTON },
 { "i", "I", 30, IDIT_BUTTON },
 { "o", "O", 31, IDIT_BUTTON },
 { "p", "P", 32, IDIT_BUTTON },
 { "at", "@", 33, IDIT_BUTTON },
 { "left_bracket", "[", 34, IDIT_BUTTON },
 { "return", "RETURN", 35, IDIT_BUTTON },
 { "ctrl", "CTR", 36, IDIT_BUTTON },
 { "a", "A", 37, IDIT_BUTTON },
 { "s", "S", 38, IDIT_BUTTON },
 { "d", "D", 39, IDIT_BUTTON },
 { "f", "F", 40, IDIT_BUTTON },
 { "g", "G", 41, IDIT_BUTTON },
 { "h", "H", 42, IDIT_BUTTON },
 { "j", "J", 43, IDIT_BUTTON },
 { "k", "K", 44, IDIT_BUTTON },
 { "l", "L", 45, IDIT_BUTTON },
 { "semicolon", ";", 46, IDIT_BUTTON },
 { "colon", ":", 47, IDIT_BUTTON },
 { "right_bracket", "]", 48, IDIT_BUTTON },
 { "kana", "カナ", 49, IDIT_BUTTON },
 { "left_shift", "Left SHIFT", 50, IDIT_BUTTON },
 { "z", "Z", 51, IDIT_BUTTON },
 { "x", "X", 52, IDIT_BUTTON },
 { "c", "C", 53, IDIT_BUTTON },
 { "v", "V", 54, IDIT_BUTTON },
 { "b", "B", 55, IDIT_BUTTON },
 { "n", "N", 56, IDIT_BUTTON },
 { "m", "M", 57, IDIT_BUTTON },
 { "comma", ",", 58, IDIT_BUTTON },
 { "period", ".", 59, IDIT_BUTTON },
 { "slash", "/", 60, IDIT_BUTTON },
 { "empty", "Empty", 61, IDIT_BUTTON },
 { "right_shift", "Right SHIFT", 62, IDIT_BUTTON },
 { "graph", "GRPH", 63, IDIT_BUTTON },
 { "space", "SPACE", 64, IDIT_BUTTON },

 { "clear", "CLR", 65, IDIT_BUTTON },
 { "insert", "INS", 66, IDIT_BUTTON },
 { "delete", "DEL", 67, IDIT_BUTTON },
 { "up", "UP", 68, IDIT_BUTTON },
 { "left", "LEFT", 69, IDIT_BUTTON },
 { "right", "RIGHT", 70, IDIT_BUTTON },
 { "down", "DOWN", 71, IDIT_BUTTON },
};

static const IDIISG HypershotIDII =
{
 { "i_run", "I, RUN", 0, IDIT_BUTTON_CAN_RAPID, NULL },
 { "i_jump", "I, JUMP", 1, IDIT_BUTTON_CAN_RAPID, NULL },
 { "ii_run", "II, RUN", 2, IDIT_BUTTON_CAN_RAPID, NULL },
 { "ii_jump", "II, JUMP", 3, IDIT_BUTTON_CAN_RAPID, NULL },
};

static const IDIISG MahjongIDII =
{
 { "1", "1", 0, IDIT_BUTTON, NULL },
 { "2", "2", 1, IDIT_BUTTON, NULL },
 { "3", "3", 2, IDIT_BUTTON, NULL },
 { "4", "4", 3, IDIT_BUTTON, NULL },
 { "5", "5", 4, IDIT_BUTTON, NULL },
 { "6", "6", 5, IDIT_BUTTON, NULL },
 { "7", "7", 6, IDIT_BUTTON, NULL },
 { "8", "8", 7, IDIT_BUTTON, NULL },
 { "9", "9", 8, IDIT_BUTTON, NULL },
 { "10", "10", 9, IDIT_BUTTON, NULL },
 { "11", "11", 10, IDIT_BUTTON, NULL },
 { "12", "12", 11, IDIT_BUTTON, NULL },
 { "13", "13", 12, IDIT_BUTTON, NULL },
 { "14", "14", 13, IDIT_BUTTON, NULL },
 { "15", "15", 14, IDIT_BUTTON, NULL },
 { "16", "16", 15, IDIT_BUTTON, NULL },
 { "17", "17", 16, IDIT_BUTTON, NULL },
 { "18", "18", 17, IDIT_BUTTON, NULL },
 { "19", "19", 18, IDIT_BUTTON, NULL },
 { "20", "20", 19, IDIT_BUTTON, NULL },
 { "21", "21", 20, IDIT_BUTTON, NULL },
};

static const IDIISG PartyTapIDII =
{
 { "buzzer_1", "Buzzer 1", 0, IDIT_BUTTON, NULL },
 { "buzzer_2", "Buzzer 2", 1, IDIT_BUTTON, NULL },
 { "buzzer_3", "Buzzer 3", 2, IDIT_BUTTON, NULL },
 { "buzzer_4", "Buzzer 4", 3, IDIT_BUTTON, NULL },
 { "buzzer_5", "Buzzer 5", 4, IDIT_BUTTON, NULL },
 { "buzzer_6", "Buzzer 6", 5, IDIT_BUTTON, NULL },
};

static const IDIISG FTrainerIDII =
{
 { "1", "1", 0, IDIT_BUTTON, NULL },
 { "2", "2", 1, IDIT_BUTTON, NULL },
 { "3", "3", 2, IDIT_BUTTON, NULL },
 { "4", "4", 3, IDIT_BUTTON, NULL },
 { "5", "5", 4, IDIT_BUTTON, NULL },
 { "6", "6", 5, IDIT_BUTTON, NULL },
 { "7", "7", 6, IDIT_BUTTON, NULL },
 { "8", "8", 7, IDIT_BUTTON, NULL },
 { "9", "9", 8, IDIT_BUTTON, NULL },
 { "10", "10", 9, IDIT_BUTTON, NULL },
 { "11", "11", 10, IDIT_BUTTON, NULL },
 { "12", "12", 11, IDIT_BUTTON, NULL },
};

static const IDIISG OekaIDII =
{
 { "x_axis", "X Axis", -1, IDIT_X_AXIS },
 { "y_axis", "Y Axis", -1, IDIT_Y_AXIS },
 { "button", "Button", 0, IDIT_BUTTON, NULL },
};

static const IDIISG BWorldIDII =
{
 { "new", "New", -1, IDIT_BYTE_SPECIAL },
 { "bd1", "Barcode Digit 1", -1, IDIT_BYTE_SPECIAL },
 { "bd2", "Barcode Digit 2", -1, IDIT_BYTE_SPECIAL },
 { "bd3", "Barcode Digit 3", -1, IDIT_BYTE_SPECIAL },
 { "bd4", "Barcode Digit 4", -1, IDIT_BYTE_SPECIAL },
 { "bd5", "Barcode Digit 5", -1, IDIT_BYTE_SPECIAL },
 { "bd6", "Barcode Digit 6", -1, IDIT_BYTE_SPECIAL },
 { "bd7", "Barcode Digit 7", -1, IDIT_BYTE_SPECIAL },
 { "bd8", "Barcode Digit 8", -1, IDIT_BYTE_SPECIAL },
 { "bd9", "Barcode Digit 9", -1, IDIT_BYTE_SPECIAL },
 { "bd10", "Barcode Digit 10", -1, IDIT_BYTE_SPECIAL },
 { "bd11", "Barcode Digit 11", -1, IDIT_BYTE_SPECIAL },
 { "bd12", "Barcode Digit 12", -1, IDIT_BYTE_SPECIAL },
 { "bd13", "Barcode Digit 13", -1, IDIT_BYTE_SPECIAL },
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoNESPort34 =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Gamepad
 {
  "gamepad",
  "Gamepad",
  NULL,
  GamepadIDII
 },

};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoNESPort =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Gamepad
 {
  "gamepad",
  "Gamepad",
  NULL,
  GamepadIDII
 },

 // Zapper
 {
  "zapper",
  "Zapper",
  NULL,
  ZapperIDII
 },

 // Powerpad A
 {
  "powerpada",
  "Power Pad Side A",
  NULL,
  PowerpadIDII
 },

 // Powerpad B
 {
  "powerpadb",
  "Power Pad Side B",
  NULL,
  PowerpadIDII
 },

 // Arkanoid
 {
  "arkanoid",
  "Arkanoid Paddle",
  NULL,
  ArkanoidIDII
 },


};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoFamicomPort =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Arkanoid
 {
  "arkanoid",
  "Arkanoid Paddle",
  NULL,
  ArkanoidIDII
 },

 // Space Shadow Gun
 {
  "shadow",
  "Space Shadow Gun",
  NULL,
  ZapperIDII
 },

 // 4-player
 {
  "4player",
  "4-player Adapter",
  NULL,
  IDII_Empty
 },

 // Family Keyboard
 {
  "fkb",
  "Family Keyboard",
  NULL,
  FKBIDII
 },

 // Hypershot
 {
  "hypershot",
  "Hypershot Paddles",
  NULL,
  HypershotIDII
 },

 // Mahjong
 {
  "mahjong",
  "Mahjong Controller",
  NULL,
  MahjongIDII
 },

 // Party Tap
 {
  "partytap",
  "Party Tap",
  NULL,
  PartyTapIDII
 },

 // Family Trainer A
 {
  "ftrainera",
  "Family Trainer Side A",
  NULL,
  FTrainerIDII
 },

 // Family Trainer B
 {
  "ftrainerb",
  "Family Trainer Side B",
  NULL,
  FTrainerIDII
 },

 // Oeka Kids
 {
  "oekakids",
  "Oeka Kids Tablet",
  NULL,
  OekaIDII
 },

 // Barcode World
 {
  "bworld",
  "Barcode World Scanner",
  NULL,
  BWorldIDII
 },

};

// The temptation is there, but don't change the "fcexp" default setting to anything other than "none", as the presence of a device
// there by default will cause compatibility problems with games.
const std::vector<InputPortInfoStruct> NESPortInfo =
{
 { "port1", "Port 1", InputDeviceInfoNESPort, "gamepad" },
 { "port2", "Port 2", InputDeviceInfoNESPort, "gamepad" },
 { "port3", "Port 3", InputDeviceInfoNESPort34, "gamepad" },
 { "port4", "Port 4", InputDeviceInfoNESPort34, "gamepad" },
 { "fcexp", "Famicom Expansion Port", InputDeviceInfoFamicomPort, "none" },
};

static uint8 joy_readbit[2];
//static 
uint8 joy[4]={0,0,0,0};
static uint8 LastStrobe;

/* This function is a quick hack to get the NSF player to use emulated gamepad
   input.
*/
uint8 MDFN_GetJoyJoy(void)
{
 return(joy[0]|joy[1]|joy[2]|joy[3]);
}
extern uint8 coinon;

static int FSDisable=0;	/* Set to 1 if NES-style four-player adapter is disabled. */

static const char *JPType[5] = { "none", "none", "none", "none", "none" };
static void *InputDataPtr[5];

void (*InputScanlineHook)(uint8 *bg, uint32 linets, int final);


static INPUTC DummyJPort = {0, 0, 0, 0, 0, NULL};
static INPUTC *JPorts[4] = {&DummyJPort, &DummyJPort, &DummyJPort, &DummyJPort};
static INPUTCFC *FCExp = NULL;

static uint8 ReadGPVS(int w)
{
                uint8 ret=0;
  
                if(joy_readbit[w]>=8)
                 ret=1;
                else
                {
                 ret = ((joy[w]>>(joy_readbit[w]))&1);
                 if(!fceuindbg)
                  joy_readbit[w]++;
                }
                return ret;
}

static uint8 ReadGP(int w)
{
                uint8 ret;

                if(joy_readbit[w]>=8)
                 ret = ((joy[2+w]>>(joy_readbit[w]&7))&1);
                else
                 ret = ((joy[w]>>(joy_readbit[w]))&1);
                if(joy_readbit[w]>=16) ret=0;
                if(FSDisable)
		{
	  	 if(joy_readbit[w]>=8) ret|=1;
		}
		else
		{
                 if(joy_readbit[w]==19-w) ret|=1;
		}
		if(!fceuindbg)
		 joy_readbit[w]++;
                return ret;
}

static DECLFR(JPRead)
{
	uint8 ret=0;

	if(JPorts[A&1]->Read)
	 ret|=JPorts[A&1]->Read(A&1);
	
	if(FCExp)
	{
	 if(FCExp->Read)
	 {
	  ret=FCExp->Read(A&1,ret);
	 }
	}
	ret|=X.DB&0xC0;
	return(ret);
}

static DECLFW(B4016)
{
	if(FCExp)
	 if(FCExp->Write)
	  FCExp->Write(V&7);

	if(JPorts[0]->Write)
	 JPorts[0]->Write(V&1);
        if(JPorts[1]->Write)
         JPorts[1]->Write(V&1);

        if((LastStrobe&1) && (!(V&1)))
        {
	 /* This strobe code is just for convenience.  If it were
	    with the code in input / *.c, it would more accurately represent
	    what's really going on.  But who wants accuracy? ;)
	    Seriously, though, this shouldn't be a problem.
	 */
	 if(JPorts[0]->Strobe)
	  JPorts[0]->Strobe(0);
         if(JPorts[1]->Strobe)
          JPorts[1]->Strobe(1);
	 if(FCExp)
	  if(FCExp->Strobe)
	   FCExp->Strobe();
	 }
         LastStrobe=V&0x1;
}

static void StrobeGP(int w)
{
	joy_readbit[w]=0;
}

static void StateActionGP(int w, StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(joy_readbit[w]),
  SFVAR(joy[w + 0]),
  SFVAR(joy[w + 2]),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, w ? "INP1" : "INP0", true);

 if(load)
 {

 }
}

static uint8 F4ReadBit[2];
static void StateActionGPFC(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFARRAY(F4ReadBit, 2),
  SFARRAY(joy, 4),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs,"INPF", true);

 if(load)
 {

 }
}

static void StrobeFami4(void)
{
 F4ReadBit[0]=F4ReadBit[1]=0;
}

static uint8 ReadFami4(int w, uint8 ret)
{
 ret&=1;

 ret |= ((joy[2+w]>>(F4ReadBit[w]))&1)<<1;
 if(F4ReadBit[w]>=8) ret|=2;
 else F4ReadBit[w]++;

 return(ret);
}

static void UpdateGamepad(int w, void *data)
{
 joy[w] = *(uint8*)data;
}

static INPUTCFC FAMI4C = { ReadFami4,0,StrobeFami4,0,0,0, StateActionGPFC };
static INPUTC GPC = {ReadGP,0,StrobeGP,UpdateGamepad,0,0, StateActionGP };
static INPUTC GPCVS = {ReadGPVS,0,StrobeGP,UpdateGamepad,0,0, StateActionGP };

void MDFN_DrawInput(uint8* pix, int pix_y)
{
 for(unsigned i = 0; i < 2; i++)
 {
  if(JPorts[i]->Draw)
   JPorts[i]->Draw(i, pix, pix_y);
 }

 if(FCExp && FCExp->Draw)
  FCExp->Draw(pix, pix_y);
}

void MDFN_UpdateInput(void)
{
	int x;

	for(x = 0; x < 4;x++)
	{
 	 if(JPorts[x]->Update)
	  JPorts[x]->Update(x, InputDataPtr[x]);
	}

	if(FCExp)
	 if(FCExp->Update)
	  FCExp->Update(InputDataPtr[4]);

	if(NESIsVSUni && coinon)
	 coinon--;

	if(NESIsVSUni)
	 MDFN_VSUniSwap(&joy[0], &joy[1]);
}

extern uint8 vsdip;	// FIXME

static DECLFR(VSUNIRead0)
{ 
        uint8 ret=0; 
  
        if(JPorts[0]->Read)   
         ret|=(JPorts[0]->Read(0))&1;
 
        ret|=(vsdip&3)<<3;
        if(coinon)
         ret|=0x4;
        return ret;
}
 
static DECLFR(VSUNIRead1)
{
        uint8 ret=0;
 
        if(JPorts[1]->Read)
         ret|=(JPorts[1]->Read(1))&1;
        ret|=vsdip&0xFC;   
        return ret;
} 

static void SLHLHook(uint8 *pix, uint32 linets, int final)
{
 int x;

 for(x=0;x<2;x++)
  if(JPorts[x]->SLHook)
   JPorts[x]->SLHook(x, pix, linets, final);
 if(FCExp) 
  if(FCExp->SLHook)
   FCExp->SLHook(pix, linets, final);
}

static void CheckSLHook(void)
{
        InputScanlineHook=0;
        if(JPorts[0]->SLHook || JPorts[1]->SLHook)
         InputScanlineHook=SLHLHook;
        if(FCExp)
         if(FCExp->SLHook)
          InputScanlineHook=SLHLHook;
}

static void SetInputStuff(int x)
{
        const char *ts = JPType[x];

	if(x == 4)
	{
	 if(!strcasecmp(ts, "none"))
	  FCExp = NULL;
	 else if(!strcasecmp(ts, "arkanoid"))
	  FCExp = MDFN_InitArkanoidFC();
         else if(!strcasecmp(ts, "shadow"))
	  FCExp=MDFN_InitSpaceShadow();
         else if(!strcasecmp(ts, "oekakids"))
	  FCExp=MDFN_InitOekaKids();
         else if(!strcasecmp(ts, "4player"))
	 {
	  FCExp=&FAMI4C;
	  memset(&F4ReadBit,0,sizeof(F4ReadBit));
	 }
         else if(!strcasecmp(ts, "fkb"))
	  FCExp=MDFN_InitFKB();
         else if(!strcasecmp(ts, "hypershot"))
	  FCExp=MDFN_InitHS();
         else if(!strcasecmp(ts, "mahjong"))
	  FCExp=MDFN_InitMahjong();
         else if(!strcasecmp(ts, "partytap"))
	  FCExp=MDFN_InitPartyTap();
         else if(!strcasecmp(ts, "ftrainera"))
	  FCExp=MDFN_InitFamilyTrainerA();
         else if(!strcasecmp(ts, "ftrainerb"))
	  FCExp=MDFN_InitFamilyTrainerB();
         else if(!strcasecmp(ts, "bworld"))
	  FCExp=MDFN_InitBarcodeWorld();
	}
	else
	{
	 if(!strcasecmp(ts, "gamepad"))
	 {
           if(NESIsVSUni)
	    JPorts[x] = &GPCVS;
	   else
	    JPorts[x]=&GPC;
	 }
	 else if(!strcasecmp(ts, "arkanoid"))
	  JPorts[x]=MDFN_InitArkanoid(x);
	 else if(!strcasecmp(ts, "zapper"))
	  JPorts[x]=MDFN_InitZapper(x);
	 else if(!strcasecmp(ts, "powerpada"))
	  JPorts[x]=MDFN_InitPowerpadA(x);
	 else if(!strcasecmp(ts, "powerpadb"))
	  JPorts[x]=MDFN_InitPowerpadB(x);
	 else if(!strcasecmp(ts, "none"))
	  JPorts[x]=&DummyJPort;
        }

	CheckSLHook();
}

void NESINPUT_Power(void)
{ 
	memset(joy_readbit,0,sizeof(joy_readbit));
        memset(joy,0,sizeof(joy));
	LastStrobe = 0;

	for(int x = 0; x < 5; x++)
         SetInputStuff(x);
}

void MDFNNES_SetInput(unsigned port, const char *type, uint8 *ptr)
{
 JPType[port] = type;
 InputDataPtr[port] = ptr;
 SetInputStuff(port);
}

void NESINPUT_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
   SFVARN(LastStrobe, "LSTS"),
   SFEND
 };

 if(load && !data_only)	// Kludgey forced initialization of variables in case a section or variable is missing.
 {
  for(unsigned x = 0; x < 5; x++)
   SetInputStuff(x);
 }

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "INPT");

 if(JPorts[0]->StateAction)
  JPorts[0]->StateAction(0, sm, load, data_only);
 if(JPorts[1]->StateAction)
  JPorts[1]->StateAction(1, sm, load, data_only);

 if(FCExp && FCExp->StateAction)
  FCExp->StateAction(sm, load, data_only);

 if(load)
 {

 }
}

static writefunc Other4016WHandler;

static DECLFW(B4016_Chained)
{
 Other4016WHandler(A, V);
 B4016(A, V);
}

void NESINPUT_PaletteChanged(void)
{
 NESCURSOR_PaletteChanged();
}

void NESINPUT_Init(void)
{
 FSDisable = MDFN_GetSettingB("nes.nofs");

 if(NESIsVSUni)
 {
  SetReadHandler(0x4016, 0x4016, VSUNIRead0);
  SetReadHandler(0x4017, 0x4017, VSUNIRead1);
 }
 else
  SetReadHandler(0x4016, 0x4017, JPRead);

 Other4016WHandler = GetWriteHandler(0x4016);
 
 if(Other4016WHandler != BNull)
  SetWriteHandler(0x4016, 0x4016, B4016_Chained);
 else
  SetWriteHandler(0x4016, 0x4016, B4016);
}



void MDFNNES_DoSimpleCommand(int cmd)
{
 if(cmd >= MDFN_MSC_TOGGLE_DIP0 && cmd <= MDFN_MSC_TOGGLE_DIP7)
 {
	MDFN_VSUniToggleDIP(cmd - MDFN_MSC_TOGGLE_DIP0);
 }
 else switch(cmd)
 {
   case MDFN_MSC_INSERT_COIN: 
		MDFN_VSUniCoin();
		break;

   case MDFN_MSC_POWER:
		PowerNES();
		break;

   case MDFN_MSC_RESET:
		ResetNES();
		break;
 }
}

}
