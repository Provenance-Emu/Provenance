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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <string.h>

#include "main.h"
#include "dface.h"
#include "input.h"

#include "../common/cheat.h"

/* UsrInputType[] is user-specified.  InputType[] is current
        (game loading can override user settings)
*/
int UsrInputType[3]={SI_GAMEPAD,SI_GAMEPAD,SIFC_NONE};
int InputType[3]={0,0,0};
static int cspec=0;
   
int gametype=0;

/* Necessary for proper GUI functioning(configuring when a game isn't loaded). */
void InputUserActiveFix(void)
{
 int x;
 for(x=0;x<3;x++) InputType[x]=UsrInputType[x];
}

void ParseGIInput(FCEUGI *gi)
{
 gametype=gi->type;
 
 InputType[0]=UsrInputType[0];
 InputType[1]=UsrInputType[1];
 InputType[2]=UsrInputType[2];
 
 if(gi->input[0]>=0)
  InputType[0]=gi->input[0];
 if(gi->input[1]>=0)
  InputType[1]=gi->input[1];
 if(gi->inputfc>=0)
  InputType[2]=gi->inputfc;
 cspec = gi->cspecial;

 #ifdef EXTGUI
 Giggles(gi->cspecial);
 #endif
}


static uint8 QuizKingData=0;
static uint8 HyperShotData=0;
static uint32 MahjongData=0;
static uint32 FTrainerData=0;
static uint8 TopRiderData=0;

static uint8 BWorldData[1+13+1];

static void UpdateFKB(void);
static void UpdateGamepad(void);
static void UpdateQuizKing(void);
static void UpdateHyperShot(void);
static void UpdateMahjong(void);
static void UpdateFTrainer(void);
static void UpdateTopRider(void);

static uint32 JSreturn=0;
int NoWaiting=1;

#ifndef EXTGUI
static void DoCheatSeq(void)
{
 #if defined(DOS) || defined(SDL)
 SilenceSound(1);
 #endif
 KillKeyboard();
 KillVideo();

 DoConsoleCheatConfig();
 InitVideo(CurGame);
 InitKeyboard();
 #if defined(DOS) || defined(SDL)
 SilenceSound(0);
 #endif
}
#endif

#include "keyscan.h"
static char *keys=0;
static int DIPS=0;

static uint8 keyonce[MKK_COUNT];
#define KEY(__a) keys[MKK(__a)]

static int _keyonly(int a)
{
 if(keys[a])
 {
  if(!keyonce[a]) 
  {
   keyonce[a]=1;
   return(1);
  }
 }
 else
  keyonce[a]=0;
 return(0);
}

#define keyonly(__a) _keyonly(MKK(__a))

static int cidisabled=0;

static void KeyboardCommands(void)
{
  int is_shift, is_alt;

  keys=GetKeyboard(); 

  if(InputType[2]==SIFC_FKB)
  {
   if(keyonly(SCROLLLOCK)) 
   {
    cidisabled^=1;
    FCEUI_DispMessage("Family Keyboard %sabled.",cidisabled?"en":"dis");
   }
   #ifdef SDL
   SDL_WM_GrabInput(cidisabled?SDL_GRAB_ON:SDL_GRAB_OFF);
   #endif
   if(cidisabled) return;
  }

  is_shift = KEY(LEFTSHIFT) | KEY(RIGHTSHIFT);
  is_alt = KEY(LEFTALT) | KEY(RIGHTALT);

  if(keyonly(F4))
  {
   if(is_shift) FCEUI_SetRenderDisable(-1, 2);
   else FCEUI_SetRenderDisable(2, -1);
  }
  #ifdef SDL
  if(keyonly(ENTER) && is_alt) ToggleFS();
  #endif

  NoWaiting&=~1;
  if(KEY(GRAVE))
   NoWaiting|=1;

  if(gametype==GIT_FDS)
  {
   if(keyonly(F6)) FCEUI_FDSSelect();
   if(keyonly(F8)) FCEUI_FDSInsert();
  }

  if(keyonly(F9)) FCEUI_SaveSnapshot();
  if(gametype!=GIT_NSF)
  {
   #ifndef EXTGUI
   if(keyonly(F2)) DoCheatSeq();
   #endif
   if(keyonly(F5)) 
   {
    if(is_shift)
     FCEUI_SaveMovie(NULL,0,NULL);
    else
     FCEUI_SaveState(NULL);
   }
   if(keyonly(F7)) 
   {
    if(is_shift)
     FCEUI_LoadMovie(NULL,0);
    else
     FCEUI_LoadState(NULL);
   }
  }

  if(keyonly(F1)) FCEUI_ToggleTileView();

  if(keyonly(MINUS)) DecreaseEmulationSpeed();
  if(keyonly(EQUAL)) IncreaseEmulationSpeed();
  if(keyonly(BACKSPACE)) FCEUI_MovieToggleFrameDisplay();
  if(keyonly(BACKSLASH)) FCEUI_ToggleEmulationPause();
  if(keyonly(RIGHTCONTROL)) FCEUI_FrameAdvance();

  if(keyonly(F10)) FCEUI_ResetNES();
  if(keyonly(F11)) FCEUI_PowerNES();

  #ifdef EXTGUI
  if(keyonly(F3)) GUI_Hide(-1);
  if(KEY(F12)) GUI_RequestExit();
  if(KEY(ESCAPE)) CloseGame();
  #else
  if(KEY(F12) || KEY(ESCAPE)) CloseGame();
  #endif

  if(gametype==GIT_VSUNI)
  {
	if(keyonly(F8)) FCEUI_VSUniCoin();
	if(keyonly(F6))
        {
	 DIPS^=1;
	 FCEUI_VSUniToggleDIPView();
	}
	if(!(DIPS&1)) goto DIPSless;
	if(keyonly(1)) FCEUI_VSUniToggleDIP(0);
	if(keyonly(2)) FCEUI_VSUniToggleDIP(1);
	if(keyonly(3)) FCEUI_VSUniToggleDIP(2);
	if(keyonly(4)) FCEUI_VSUniToggleDIP(3);
	if(keyonly(5)) FCEUI_VSUniToggleDIP(4);
	if(keyonly(6)) FCEUI_VSUniToggleDIP(5);
	if(keyonly(7)) FCEUI_VSUniToggleDIP(6);
	if(keyonly(8)) FCEUI_VSUniToggleDIP(7);
  }
  else
  {
   static uint8 bbuf[32];
   static int bbuft;
   static int barcoder = 0;

   if(keyonly(H)) FCEUI_NTSCSELHUE();
   if(keyonly(T)) FCEUI_NTSCSELTINT();
   if(KEY(KP_MINUS) || KEY(MINUS)) FCEUI_NTSCDEC();
   if(KEY(KP_PLUS) || KEY(EQUAL)) FCEUI_NTSCINC();

   if((InputType[2] == SIFC_BWORLD) || (cspec == SIS_DATACH))
   {
    if(keyonly(F8)) 
    {
     barcoder ^= 1;
     if(!barcoder)
     {
      if(InputType[2] == SIFC_BWORLD)
      {
       strcpy(&BWorldData[1],bbuf);
       BWorldData[0]=1;
      }
      else
       FCEUI_DatachSet(bbuf);
      FCEUI_DispMessage("Barcode Entered");
     } 
     else { bbuft = 0; FCEUI_DispMessage("Enter Barcode");}
    }
   } else barcoder = 0;

	#define SSM(x)		\
	{ if(barcoder) { if(bbuft < 13) {bbuf[bbuft++] = '0' + x; bbuf[bbuft] = 0;} FCEUI_DispMessage("Barcode: %s",bbuf);}	\
	else { 			\
	 if(is_shift) FCEUI_SelectMovie(x,1); 	\
	 else FCEUI_SelectState(x,1); 	\
	} }

   DIPSless:
   if(keyonly(0)) SSM(0);
   if(keyonly(1)) SSM(1);
   if(keyonly(2)) SSM(2);
   if(keyonly(3)) SSM(3);
   if(keyonly(4)) SSM(4);
   if(keyonly(5)) SSM(5);
   if(keyonly(6)) SSM(6);
   if(keyonly(7)) SSM(7);
   if(keyonly(8)) SSM(8);
   if(keyonly(9)) SSM(9);
   #undef SSM
 }
}

#define MK(x)   {{BUTTC_KEYBOARD},{0},{MKK(x)},1}
#define MK2(x1,x2)	{{BUTTC_KEYBOARD},{0},{MKK(x1),MKK(x2)},2}

#define MKZ()   {{0},{0},{0},0}

#define GPZ()   {MKZ(), MKZ(), MKZ(), MKZ()}

ButtConfig GamePadConfig[4][10]={
        /* Gamepad 1 */
        { 
	 MK(KP3), MK(KP2), MK(TAB), MK(ENTER), MK(W),MK(Z),
                MK(A), MK(S), MKZ(), MKZ()
	},

        /* Gamepad 2 */
        GPZ(),

        /* Gamepad 3 */
        GPZ(),
  
        /* Gamepad 4 */
        GPZ()
};


static void UpdateGamepad(void)
{
 if(FCEUI_IsMovieActive()<0)
   return;

 static int rapid=0;
 uint32 JS=0;
 int x;
 int wg;

 rapid^=1;

 for(wg=0;wg<4;wg++)
 {
  for(x=0;x<8;x++)
   if(DTestButton(&GamePadConfig[wg][x]))
    JS|=(1<<x)<<(wg<<3);

  if(rapid)
   for(x=0;x<2;x++)
     if(DTestButton(&GamePadConfig[wg][8+x]))
      JS|=(1<<x)<<(wg<<3);
  }

//  for(x=0;x<32;x+=8)	/* Now, test to see if anything weird(up+down at same time)
//			   is happening, and correct */
//  {
//   if((JS & (0xC0<<x) ) == (0xC0<<x) ) JS&=~(0xC0<<x);
//   if((JS & (0x30<<x) ) == (0x30<<x) ) JS&=~(0x30<<x);
//  }

  JSreturn=JS;
}

ButtConfig powerpadsc[2][12]={
                              {
                               MK(O),MK(P),MK(BRACKET_LEFT),
                               MK(BRACKET_RIGHT),MK(K),MK(L),MK(SEMICOLON),
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

static uint32 powerpadbuf[2]={0,0};

static uint32 UpdatePPadData(int w)
{
 if(FCEUI_IsMovieActive()<0)
   return;

 uint32 r=0;
 ButtConfig *ppadtsc=powerpadsc[w];
 int x;

 for(x=0;x<12;x++)
  if(DTestButton(&ppadtsc[x])) r|=1<<x;

 return r;
}

static uint32 MouseData[3]={0,0,0};
static uint8 fkbkeys[0x48];

void FCEUD_UpdateInput(void)
{
  int x;
  int t=0;

  UpdatePhysicalInput();
  KeyboardCommands();

  for(x=0;x<2;x++)
   switch(InputType[x])
   {
    case SI_GAMEPAD:t|=1;break;
    case SI_ARKANOID:t|=2;break;
    case SI_ZAPPER:t|=2;break;
    case SI_POWERPADA:
    case SI_POWERPADB:powerpadbuf[x]=UpdatePPadData(x);break;
   }

  switch(InputType[2])
  {
   case SIFC_ARKANOID:t|=2;break;
   case SIFC_SHADOW:t|=2;break;
   case SIFC_FKB:if(cidisabled) UpdateFKB();break;
   case SIFC_HYPERSHOT: UpdateHyperShot();break;
   case SIFC_MAHJONG: UpdateMahjong();break;
   case SIFC_QUIZKING: UpdateQuizKing();break;
   case SIFC_FTRAINERB:
   case SIFC_FTRAINERA: UpdateFTrainer();break;
   case SIFC_TOPRIDER: UpdateTopRider();break;
   case SIFC_OEKAKIDS:t|=2;break;

  }

  if(t&1)
   UpdateGamepad();

  if(t&2)
   GetMouseData(MouseData);
}

void InitOtherInput(void)
{
   void *InputDPtr;

   int t;
   int x;
   int attrib;

   for(t=0,x=0;x<2;x++)
   {
    attrib=0;
    InputDPtr=0;
    switch(InputType[x])
    {
     case SI_POWERPADA:
     case SI_POWERPADB:InputDPtr=&powerpadbuf[x];break;
     case SI_GAMEPAD:InputDPtr=&JSreturn;break;     
     case SI_ARKANOID:InputDPtr=MouseData;t|=1;break;
     case SI_ZAPPER:InputDPtr=MouseData;
                                t|=1;
                                attrib=1;
                                break;
    }
    FCEUI_SetInput(x,InputType[x],InputDPtr,attrib);
   }

   attrib=0;
   InputDPtr=0;
   switch(InputType[2])
   {
    case SIFC_SHADOW:InputDPtr=MouseData;t|=1;attrib=1;break;
    case SIFC_OEKAKIDS:InputDPtr=MouseData;t|=1;attrib=1;break;
    case SIFC_ARKANOID:InputDPtr=MouseData;t|=1;break;
    case SIFC_FKB:InputDPtr=fkbkeys;break;
    case SIFC_HYPERSHOT:InputDPtr=&HyperShotData;break;
    case SIFC_MAHJONG:InputDPtr=&MahjongData;break;
    case SIFC_QUIZKING:InputDPtr=&QuizKingData;break;
    case SIFC_TOPRIDER:InputDPtr=&TopRiderData;break;
    case SIFC_BWORLD:InputDPtr=BWorldData;break;
    case SIFC_FTRAINERA:
    case SIFC_FTRAINERB:InputDPtr=&FTrainerData;break;
   }

   FCEUI_SetInputFC(InputType[2],InputDPtr,attrib);
   FCEUI_DisableFourScore(eoptions&EO_NOFOURSCORE);

   if(t) 
    InitMouse();
}


ButtConfig fkbmap[0x48]=
{
 MK(F1),MK(F2),MK(F3),MK(F4),MK(F5),MK(F6),MK(F7),MK(F8),
 MK(1),MK(2),MK(3),MK(4),MK(5),MK(6),MK(7),MK(8),MK(9),MK(0),
        MK(MINUS),MK(EQUAL),MK(BACKSLASH),MK(BACKSPACE),
 MK(ESCAPE),MK(Q),MK(W),MK(E),MK(R),MK(T),MK(Y),MK(U),MK(I),MK(O),
        MK(P),MK(GRAVE),MK(BRACKET_LEFT),MK(ENTER),
 MK(LEFTCONTROL),MK(A),MK(S),MK(D),MK(F),MK(G),MK(H),MK(J),MK(K),
        MK(L),MK(SEMICOLON),MK(APOSTROPHE),MK(BRACKET_RIGHT),MK(INSERT),
 MK(LEFTSHIFT),MK(Z),MK(X),MK(C),MK(V),MK(B),MK(N),MK(M),MK(COMMA),
        MK(PERIOD),MK(SLASH),MK(RIGHTALT),MK(RIGHTSHIFT),MK(LEFTALT),MK(SPACE),
 MK(DELETE),MK(END),MK(PAGEDOWN),
 MK(CURSORUP),MK(CURSORLEFT),MK(CURSORRIGHT),MK(CURSORDOWN)
};

static void UpdateFKB(void)
{
 int x;

 for(x=0;x<0x48;x++)
 {
  fkbkeys[x]=0;

  if(DTestButton(&fkbmap[x]))
   fkbkeys[x]=1;
 }
}

static ButtConfig HyperShotButtons[4]=
{
 MK(Q),MK(W),MK(E),MK(R)
};

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

static void subcon(char *text, ButtConfig *bc)
{
 uint8 buf[256];
 int wc;

 for(wc=0;wc<MAXBUTTCONFIG;wc++)
 {
  sprintf(buf,"%s (%d)",text,wc+1);
  DWaitButton(buf,bc,wc);

  if(wc && bc->ButtType[wc]==bc->ButtType[wc-1] && bc->DeviceNum[wc]==bc->DeviceNum[wc-1] &&
                bc->ButtonNum[wc]==bc->ButtonNum[wc-1])   
         break;
 }
 bc->NumC=wc;
}

void ConfigDevice(int which, int arg)
{
 uint8 buf[256];
 int x;

 ButtonConfigBegin();
 switch(which)
 {
  case FCFGD_QUIZKING:
   for(x=0;x<6;x++)
   {
    sprintf(buf,"Quiz King Buzzer #%d", x+1);
    subcon(buf,&QuizKingButtons[x]);
   }
   break;
  case FCFGD_HYPERSHOT:
   for(x=0;x<4;x++)
   {
    sprintf(buf,"Hyper Shot %d: %s",((x&2)>>1)+1,(x&1)?"JUMP":"RUN");
    subcon(buf,&HyperShotButtons[x]);
   } 
   break;
  case FCFGD_POWERPAD:
   for(x=0;x<12;x++)
   {
    sprintf(buf,"PowerPad %d: %d", (arg&1)+1,x+11);
    subcon(buf,&powerpadsc[arg&1][x]);
   }
   break;

  case FCFGD_GAMEPAD:
  {
   char *str[10]={"A","B","SELECT","START","UP","DOWN","LEFT","RIGHT","Rapid A","Rapid B"};
   for(x=0;x<10;x++)
   {
    sprintf(buf,"GamePad #%d: %s",arg+1,str[x]);
    subcon(buf,&GamePadConfig[arg][x]);
   }
  }
  break;
 }

 ButtonConfigEnd();
}


CFGSTRUCT InputConfig[]={
        ACA(UsrInputType),
        AC(powerpadsc),
        AC(QuizKingButtons),
        AC(FTrainerButtons),
        AC(HyperShotButtons),
        AC(MahjongButtons),
        AC(GamePadConfig),
        AC(fkbmap),
        ENDCFGSTRUCT
};


static void InputCfg(char *text)
{
         if(!strncasecmp(text,"gamepad",strlen("gamepad")))
         {
          ConfigDevice(FCFGD_GAMEPAD,(text[strlen("gamepad")]-'1')&3);
         }
         else if(!strncasecmp(text,"powerpad",strlen("powerpad")))
         {
          ConfigDevice(FCFGD_POWERPAD,(text[strlen("powerpad")]-'1')&1);
         }
         else if(!strcasecmp(text,"hypershot"))
          ConfigDevice(FCFGD_HYPERSHOT,0);
         else if(!strcasecmp(text,"quizking"))
          ConfigDevice(FCFGD_QUIZKING,0);
}

static void FCExp(char *text)
{
        static char *fccortab[11]={"none","arkanoid","shadow","4player","fkb","hypershot",
                        "mahjong","quizking","ftrainera","ftrainerb","oekakids"};
           
        static int fccortabi[11]={SIFC_NONE,SIFC_ARKANOID,SIFC_SHADOW,
                                 SIFC_4PLAYER,SIFC_FKB,SIFC_HYPERSHOT,SIFC_MAHJONG,SIFC_QUIZKING,
                                 SIFC_FTRAINERA,SIFC_FTRAINERB,SIFC_OEKAKIDS};
	int y;
	for(y=0;y<11;y++)
	 if(!strcmp(fccortab[y],text))
	  UsrInputType[2]=fccortabi[y];
}

static char *cortab[6]={"none","gamepad","zapper","powerpada","powerpadb","arkanoid"};
static int cortabi[6]={SI_NONE,SI_GAMEPAD,
                               SI_ZAPPER,SI_POWERPADA,SI_POWERPADB,SI_ARKANOID};

static void Input1(char *text)
{
	int y;

	for(y=0;y<6;y++)
	 if(!strcmp(cortab[y],text))
	  UsrInputType[0]=cortabi[y];
}

static void Input2(char *text)
{
	int y;

	for(y=0;y<6;y++)
	 if(!strcmp(cortab[y],text))
	  UsrInputType[1]=cortabi[y];
}

ARGPSTRUCT InputArgs[]={
	{"-inputcfg",0,(void *)InputCfg,0x2000},
	{"-fcexp",0,(void *)FCExp,0x2000},
	{"-input1",0,(void *)Input1,0x2000},
	{"-input2",0,(void *)Input2,0x2000},
	{0,0,0,0}
};
