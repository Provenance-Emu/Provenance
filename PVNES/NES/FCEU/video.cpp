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

#include "types.h"
#include "video.h"
#include "fceu.h"
#include "file.h"
#include "utils/memory.h"
#include "utils/crc32.h"
#include "state.h"
#include "movie.h"
#include "palette.h"
#include "nsf.h"
#include "input.h"
#include "vsuni.h"
#include "drawing.h"
#include "driver.h"
#include "drivers/common/vidblit.h"
#ifdef _S9XLUA_H
#include "fceulua.h"
#endif

#ifdef WIN32
#include "drivers/win/common.h" //For DirectX constants
#include "drivers/win/input.h"
#endif

#ifdef CREATE_AVI
#include "drivers/videolog/nesvideos-piece.h"
#endif

//no stdint in win32 (but we could add it if we needed to)
#ifndef WIN32
#include <stdint.h>
#endif

#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <cstdarg>
#include <zlib.h>

//XBuf:
//0-63 is reserved for 7 special colours used by FCEUX (overlay, etc.)
//64-127 is the most-used emphasis setting per frame
//128-195 is the palette with no emphasis
//196-255 is the palette with all emphasis bits on
u8 *XBuf=NULL; //used for current display
u8 *XBackBuf=NULL; //ppu output is stashed here before drawing happens
u8 *XDBuf=NULL; //corresponding to XBuf but with deemph bits
u8 *XDBackBuf=NULL; //corresponding to XBackBuf but with deemph bits
int ClipSidesOffset=0;	//Used to move displayed messages when Clips left and right sides is checked
static u8 *xbsave=NULL;

GUIMESSAGE guiMessage;
GUIMESSAGE subtitleMessage;

//for input display
extern int input_display;
extern uint32 cur_input_display;

bool oldInputDisplay = false;

unsigned int lastu = 0;

std::string AsSnapshotName ="";			//adelikat:this will set the snapshot name when for s savesnapshot as function

void FCEUI_SetSnapshotAsName(std::string name) { AsSnapshotName = name; }
std::string FCEUI_GetSnapshotAsName() { return AsSnapshotName; }

void FCEU_KillVirtualVideo(void)
{
	//mbg merge TODO 7/17/06 temporarily removed
	//if(xbsave)
	//{
	// free(xbsave);
	// xbsave=0;
	//}
	//if(XBuf)
	//{
	//UnmapViewOfFile(XBuf);
	//CloseHandle(mapXBuf);
	//mapXBuf=NULL;
	//}
	//if(XBackBuf)
	//{
	// free(XBackBuf);
	// XBackBuf=0;
	//}
}

/**
* Return: Flag that indicates whether the function was succesful or not.
*
* TODO: This function is Windows-only. It should probably be moved.
**/
int FCEU_InitVirtualVideo(void)
{
	//Some driver code may allocate XBuf externally.
	//256 bytes per scanline, * 240 scanline maximum, +16 for alignment,
	if(XBuf)
		return 1;
	
	XBuf = (u8*)FCEU_malloc(256 * 256 + 16);
	XBackBuf = (u8*)FCEU_malloc(256 * 256 + 16);
	XDBuf = (u8*)FCEU_malloc(256 * 256 + 16);
	XDBackBuf = (u8*)FCEU_malloc(256 * 256 + 16);
	if(!XBuf || !XBackBuf || !XDBuf || !XDBackBuf)
	{
		return 0;
	}

	xbsave = XBuf;

	if( sizeof(uint8*) == 4 )
	{
		uintptr_t m = (uintptr_t)XBuf;
		m = ( 8 - m) & 7;
		XBuf+=m;
	}

	memset(XBuf,128,256*256);
	memset(XBackBuf,128,256*256);
	memset(XBuf,128,256*256);
	memset(XBackBuf,128,256*256);

	return 1;
}

#ifdef FRAMESKIP
void FCEU_PutImageDummy(void)
{
	ShowFPS();
	if(GameInfo->type!=GIT_NSF)
	{
		FCEU_DrawNTSCControlBars(XBuf);
		FCEU_DrawSaveStates(XBuf);
		FCEU_DrawMovies(XBuf);
	}
	if(guiMessage.howlong) guiMessage.howlong--; /* DrawMessage() */
}
#endif

static int dosnapsave=0;
void FCEUI_SaveSnapshot(void)
{
	dosnapsave=1;
}

void FCEUI_SaveSnapshotAs(void)
{
	dosnapsave=2;
}

static void ReallySnap(void)
{
	int x=SaveSnapshot();
	if(!x)
		FCEU_DispMessage("Error saving screen snapshot.",0);
	else
		FCEU_DispMessage("Screen snapshot %d saved.",0,x-1);
}

void FCEU_PutImage(void)
{
	if(dosnapsave==2)	//Save screenshot as, currently only flagged & run by the Win32 build. //TODO SDL: implement this?
	{
		char nameo[512];
		strcpy(nameo,FCEUI_GetSnapshotAsName().c_str());
		if (nameo[0])
		{
			SaveSnapshot(nameo);
			FCEU_DispMessage("Snapshot Saved.",0);
		}
		dosnapsave=0;
	}
	if(GameInfo->type==GIT_NSF)
	{
		DrawNSF(XBuf);

#ifdef _S9XLUA_H
		FCEU_LuaGui(XBuf);
#endif

		//Save snapshot after NSF screen is drawn.  Why would we want to do it before?
		if(dosnapsave==1)
		{
			ReallySnap();
			dosnapsave=0;
		}
	}
	else
	{
		//Save backbuffer before overlay stuff is written.
		if(!FCEUI_EmulationPaused())
			memcpy(XBackBuf, XBuf, 256*256);

		//Some messages need to be displayed before the avi is dumped
		DrawMessage(true);

#ifdef _S9XLUA_H
		// Lua gui should draw before the avi is dumped.
		FCEU_LuaGui(XBuf);
#endif

		//Save snapshot
		if(dosnapsave==1)
		{
			ReallySnap();
			dosnapsave=0;
		}

		if (!FCEUI_AviEnableHUDrecording()) snapAVI();

		if(GameInfo->type==GIT_VSUNI)
			FCEU_VSUniDraw(XBuf);

		FCEU_DrawSaveStates(XBuf);
		FCEU_DrawMovies(XBuf);
		FCEU_DrawLagCounter(XBuf);
		FCEU_DrawNTSCControlBars(XBuf);
		FCEU_DrawRecordingStatus(XBuf);
		ShowFPS();
	}

	if(FCEUD_ShouldDrawInputAids())
		FCEU_DrawInput(XBuf);

	//Fancy input display code
	if(input_display)
	{
		extern uint32 JSAutoHeld;
		uint32 held;

		int controller, c, ci, color;
		int i, j;
		uint32 on  = FCEUMOV_Mode(MOVIEMODE_PLAY) ? 0x90:0xA7;	//Standard, or Gray depending on movie mode
		uint32 oni = 0xA0;		//Color for immediate keyboard buttons
		uint32 blend = 0xB6;		//Blend of immiate and last held buttons
		uint32 ahold = 0x87;		//Auto hold
		uint32 off = 0xCF;

		uint8 *t = XBuf+(FSettings.LastSLine-9)*256 + 20;		//mbg merge 7/17/06 changed t to uint8*
		if(input_display > 4) input_display = 4;
		for(controller = 0; controller < input_display; controller++, t += 56)
		{
			for(i = 0; i < 34;i++)
				for(j = 0; j <9 ; j++)
					t[i+j*256] = (t[i+j*256] & 0x30) | 0xC1;
			for(i = 3; i < 6; i++)
				for(j = 3; j< 6; j++)
					t[i+j*256] = 0xCF;
			c = cur_input_display >> (controller * 8);

			// This doesn't work in anything except windows for now.
			// It doesn't get set anywhere in other ports.
#ifdef WIN32
			if (!oldInputDisplay) ci = FCEUMOV_Mode(MOVIEMODE_PLAY) ? 0:GetGamepadPressedImmediate() >> (controller * 8);
			else ci = 0;

			if (!oldInputDisplay && !FCEUMOV_Mode(MOVIEMODE_PLAY)) held = (JSAutoHeld >> (controller * 8));
			else held = 0;
#else
			// Put other port info here
			ci = 0;
			held = 0;
#endif

			//adelikat: I apologize to anyone who ever sifts through this color assignment
			//A
			if (held&1)	{ //If auto-hold
				if (!(ci&1) ) color = ahold;
				else
					color = (c&1) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&1) color = (ci&1) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&1) ? oni : off;
			}
			for(i=0; i < 4; i++)
			{
				for(j = 0; j < 4; j++)
				{
					if(i%3==0 && j %3 == 0)
						continue;
					t[30+4*256+i+j*256] = color;
				}
			}
			//B
			if (held&2)	{ //If auto-hold
				if (!(ci&2) ) color = ahold;
				else
					color = (c&2) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&2) color = (ci&2) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&2) ? oni : off;
			}
			for(i=0; i < 4; i++)
			{
				for(j = 0; j < 4; j++)
				{
					if(i%3==0 && j %3 == 0)
						continue;
					t[24+4*256+i+j*256] = color;
				}
			}
			//Select
			if (held&4)	{ //If auto-hold
				if (!(ci&4) ) color = ahold;
				else
					color = (c&4) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&4) color = (ci&4) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&4) ? oni : off;
			}
			for(i = 0; i < 4; i++)
			{
				t[11+5*256+i] = color;
				t[11+6*256+i] = color;
			}
			//Start
			if (held&8)	{ //If auto-hold
				if (!(ci&8) ) color = ahold;
				else
					color = (c&8) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&8) color = (ci&8) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&8) ? oni : off;
			}
			for(i = 0; i < 4; i++)
			{
				t[17+5*256+i] = color;
				t[17+6*256+i] = color;
			}
			//Up
			if (held&16)	{ //If auto-hold
				if (!(ci&16) ) color = ahold;
				else
					color = (c&16) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&16) color = (ci&16) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&16) ? oni : off;
			}
			for(i = 0; i < 3; i++)
			{
				for(j = 0; j < 3; j++)
				{
					t[3+i+256*j] = color;
				}
			}
			//Down
			if (held&32)	{ //If auto-hold
				if (!(ci&32) ) color = ahold;
				else
					color = (c&32) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&32) color = (ci&32) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&32) ? oni : off;
			}
			for(i = 0; i < 3; i++)
			{
				for(j = 0; j < 3; j++)
				{
					t[3+i+256*j+6*256] = color;
				}
			}
			//Left
			if (held&64)	{ //If auto-hold
				if (!(ci&64) ) color = ahold;
				else
					color = (c&64) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&64) color = (ci&64) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&64) ? oni : off;
			}
			for(i = 0; i < 3; i++)
			{
				for(j = 0; j < 3; j++)
				{
					t[3*256+i+256*j] = color;
				}
			}
			//Right
			if (held&128)	{ //If auto-hold
				if (!(ci&128) ) color = ahold;
				else
					color = (c&128) ? on : off; //If the button is pressed down (immediate) that negates auto hold, however it is only off if the previous frame the button wasn't pressed!
			}
			else {
				if (c&128) color = (ci&128) ? blend : on;	//If immedaite buttons are pressed and they match the previous frame, blend the colors
				else color = (ci&128) ? oni : off;
			}
			for(i = 0; i < 3; i++)
			{
				for(j = 0; j < 3; j++)
				{
					t[6+3*256+i+256*j] = color;
				}
			}
		}
	}

	if (FCEUI_AviEnableHUDrecording())
	{
		if (FCEUI_AviDisableMovieMessages())
		{
			snapAVI();
			DrawMessage(false);
		} else
		{
			DrawMessage(false);
			snapAVI();
		}
	} else DrawMessage(false);

}
void snapAVI()
{
	//Update AVI
	if(!FCEUI_EmulationPaused())
		FCEUI_AviVideoUpdate(XBuf);
}

void FCEU_DispMessageOnMovie(char *format, ...)
{
	va_list ap;

	va_start(ap,format);
	vsnprintf(guiMessage.errmsg,sizeof(guiMessage.errmsg),format,ap);
	va_end(ap);

	guiMessage.howlong = 180;
	guiMessage.isMovieMessage = true;
	guiMessage.linesFromBottom = 0;

	if (FCEUI_AviIsRecording() && FCEUI_AviDisableMovieMessages())
		guiMessage.howlong = 0;
}

void FCEU_DispMessage(char *format, int disppos=0, ...)
{
	va_list ap;

	va_start(ap,disppos);
	vsnprintf(guiMessage.errmsg,sizeof(guiMessage.errmsg),format,ap);
	va_end(ap);
	// also log messages
	char temp[2048];
	va_start(ap,disppos);
	vsnprintf(temp,sizeof(temp),format,ap);
	va_end(ap);
	strcat(temp, "\n");
	FCEU_printf(temp);

	guiMessage.howlong = 180;
	guiMessage.isMovieMessage = false;

	guiMessage.linesFromBottom = disppos;

	//adelikat: Pretty sure this code fails, Movie playback stopped is done with FCEU_DispMessageOnMovie()
	#ifdef CREATE_AVI
	if(LoggingEnabled == 2)
	{
		/* While in AVI recording mode, only display bare minimum
		 * of messages
		 */
		if(strcmp(guiMessage.errmsg, "Movie playback stopped.") != 0)
			guiMessage.howlong = 0;
	}
	#endif
}

void FCEU_ResetMessages()
{
	guiMessage.howlong = 0;
	guiMessage.isMovieMessage = false;
	guiMessage.linesFromBottom = 0;
}


static int WritePNGChunk(FILE *fp, uint32 size, char *type, uint8 *data)
{
	uint32 crc;

	uint8 tempo[4];

	tempo[0]=size>>24;
	tempo[1]=size>>16;
	tempo[2]=size>>8;
	tempo[3]=size;

	if(fwrite(tempo,4,1,fp)!=1)
		return 0;
	if(fwrite(type,4,1,fp)!=1)
		return 0;

	if(size)
		if(fwrite(data,1,size,fp)!=size)
			return 0;

	crc=CalcCRC32(0,(uint8 *)type,4);
	if(size)
		crc=CalcCRC32(crc,data,size);

	tempo[0]=crc>>24;
	tempo[1]=crc>>16;
	tempo[2]=crc>>8;
	tempo[3]=crc;

	if(fwrite(tempo,4,1,fp)!=1)
		return 0;
	return 1;
}

uint32 GetScreenPixel(int x, int y, bool usebackup) {

	uint8 r,g,b;

	if (((x < 0) || (x > 255)) || ((y < 0) || (y > 255)))
		return -1;

	if (usebackup)
		FCEUD_GetPalette(XBackBuf[(y*256)+x],&r,&g,&b);
	else
		FCEUD_GetPalette(XBuf[(y*256)+x],&r,&g,&b);


	return ((int) (r) << 16) | ((int) (g) << 8) | (int) (b);
}

int GetScreenPixelPalette(int x, int y, bool usebackup) {

	if (((x < 0) || (x > 255)) || ((y < 0) || (y > 255)))
		return -1;

	if (usebackup)
		return XBackBuf[(y*256)+x] & 0x3f;
	else
		return XBuf[(y*256)+x] & 0x3f;

}

int SaveSnapshot(void)
{
	int totallines=FSettings.LastSLine-FSettings.FirstSLine+1;
	int x,u,y;
	FILE *pp=NULL;
	uint8 *compmem=NULL;
	uLongf compmemsize=(totallines*263+12)*3;

	if(!(compmem=(uint8 *)FCEU_malloc(compmemsize)))
		return 0;

	for (u = lastu; u < 99999; ++u)
	{
		pp=FCEUD_UTF8fopen(FCEU_MakeFName(FCEUMKF_SNAP,u,"png").c_str(),"rb");
		if(pp==NULL) break;
		fclose(pp);
	}
	lastu = u;

	if(!(pp=FCEUD_UTF8fopen(FCEU_MakeFName(FCEUMKF_SNAP,u,"png").c_str(),"wb")))
	{
		free(compmem);
		return 0;
	}

	{
		static const uint8 header[8]={137,80,78,71,13,10,26,10};
		if(fwrite(header,8,1,pp)!=1)
			goto PNGerr;
	}

	{
		uint8 chunko[13];

		chunko[0]=chunko[1]=chunko[3]=0;
		chunko[2]=0x1;			// Width of 256

		chunko[4]=chunko[5]=chunko[6]=0;
		chunko[7]=totallines;			// Height

		chunko[8]=8;				// 8 bits per sample(24 bits per pixel)
		chunko[9]=2;				// Color type; RGB triplet
		chunko[10]=0;				// compression: deflate
		chunko[11]=0;				// Basic adapative filter set(though none are used).
		chunko[12]=0;				// No interlace.

		if(!WritePNGChunk(pp,13,"IHDR",chunko))
			goto PNGerr;
	}

	{
		uint8 *tmp=XBuf+FSettings.FirstSLine*256;
		uint8 *dest,*mal,*mork;

		int bufsize = (256*3+1)*totallines;
		if(!(mal=mork=dest=(uint8 *)FCEU_dmalloc(bufsize)))
			goto PNGerr;
		//   mork=dest=XBuf;

		for(y=0;y<totallines;y++)
		{
			*dest=0;			// No filter.
			dest++;
			for(x=256;x;x--)
			{
				u32 color = ModernDeemphColorMap(tmp,XBuf,1,1);
				*dest++=(color>>0x10)&0xFF;
				*dest++=(color>>0x08)&0xFF;
				*dest++=(color>>0x00)&0xFF;
				tmp++;
			}
		}

		if(compress(compmem,&compmemsize,mork,bufsize)!=Z_OK)
		{
			if(mal) free(mal);
			goto PNGerr;
		}
		if(mal) free(mal);
		if(!WritePNGChunk(pp,compmemsize,"IDAT",compmem))
			goto PNGerr;
	}
	if(!WritePNGChunk(pp,0,"IEND",0))
		goto PNGerr;

	free(compmem);
	fclose(pp);

	return u+1;


PNGerr:
	if(compmem)
		free(compmem);
	if(pp)
		fclose(pp);
	return(0);
}

//overloaded SaveSnapshot for "Savesnapshot As" function
int SaveSnapshot(char fileName[512])
{
	int totallines=FSettings.LastSLine-FSettings.FirstSLine+1;
	int x,y;
	FILE *pp=NULL;
	uint8 *compmem=NULL;
	uLongf compmemsize=totallines*263+12;

	if(!(compmem=(uint8 *)FCEU_malloc(compmemsize)))
		return 0;

	if(!(pp=FCEUD_UTF8fopen(fileName,"wb")))
	{
		free(compmem);
		return 0;
	}

	{
		static uint8 header[8]={137,80,78,71,13,10,26,10};
		if(fwrite(header,8,1,pp)!=1)
			goto PNGerr;
	}

	{
		uint8 chunko[13];

		chunko[0]=chunko[1]=chunko[3]=0;
		chunko[2]=0x1;			// Width of 256

		chunko[4]=chunko[5]=chunko[6]=0;
		chunko[7]=totallines;			// Height

		chunko[8]=8;				// bit depth
		chunko[9]=3;				// Color type; indexed 8-bit
		chunko[10]=0;				// compression: deflate
		chunko[11]=0;				// Basic adapative filter set(though none are used).
		chunko[12]=0;				// No interlace.

		if(!WritePNGChunk(pp,13,"IHDR",chunko))
			goto PNGerr;
	}

	{
		uint8 pdata[256*3];
		for(x=0;x<256;x++)
			FCEUD_GetPalette(x,pdata+x*3,pdata+x*3+1,pdata+x*3+2);
		if(!WritePNGChunk(pp,256*3,"PLTE",pdata))
			goto PNGerr;
	}

	{
		uint8 *tmp=XBuf+FSettings.FirstSLine*256;
		uint8 *dest,*mal,*mork;

		if(!(mal=mork=dest=(uint8 *)FCEU_dmalloc((totallines<<8)+totallines)))
			goto PNGerr;
		//   mork=dest=XBuf;

		for(y=0;y<totallines;y++)
		{
			*dest=0;			// No filter.
			dest++;
			for(x=256;x;x--,tmp++,dest++)
				*dest=*tmp;
		}

		if(compress(compmem,&compmemsize,mork,(totallines<<8)+totallines)!=Z_OK)
		{
			if(mal) free(mal);
			goto PNGerr;
		}
		if(mal) free(mal);
		if(!WritePNGChunk(pp,compmemsize,"IDAT",compmem))
			goto PNGerr;
	}
	if(!WritePNGChunk(pp,0,"IEND",0))
		goto PNGerr;

	free(compmem);
	fclose(pp);

	return 0;


PNGerr:
	if(compmem)
		free(compmem);
	if(pp)
		fclose(pp);
	return(0);
}
// called when another ROM is opened
void ResetScreenshotsCounter()
{
	lastu = 0;
}

uint64 FCEUD_GetTime(void);
uint64 FCEUD_GetTimeFreq(void);
bool Show_FPS = false;
// Control whether the frames per second of the emulation is rendered.
bool FCEUI_ShowFPS()
{
	return Show_FPS;
}
void FCEUI_SetShowFPS(bool showFPS)
{
	Show_FPS = showFPS;
}
void FCEUI_ToggleShowFPS()
{
	Show_FPS ^= 1;
}

static uint64 boop[60];
static int boopcount = 0;

void ShowFPS(void)
{
	if(Show_FPS == false)
		return;
	uint64 da = FCEUD_GetTime() - boop[boopcount];
	char fpsmsg[16];
	int booplimit = PAL?50:60;
	boop[boopcount] = FCEUD_GetTime();

	sprintf(fpsmsg, "%.1f", (double)booplimit / ((double)da / FCEUD_GetTimeFreq()));
	DrawTextTrans(XBuf + ((256 - ClipSidesOffset) - 40) + (FSettings.FirstSLine + 4) * 256, 256, (uint8*)fpsmsg, 0xA0);
	// It's not averaging FPS over exactly 1 second, but it's close enough.
	boopcount = (boopcount + 1) % booplimit;
}
