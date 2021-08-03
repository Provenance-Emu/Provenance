/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2003 Xodnizel
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

#include "main.h"
#include "args.h"
#include "common.h"
#include "../common/args.h"

char* MovieToLoad = 0;		//Loads a movie file on startup
char* StateToLoad = 0;		//Loads a savestate on startup (after a movie is loaded, if any)
char* ConfigToLoad = 0;		//Loads a specific .cfg file (loads before any other commandline options
char* LuaToLoad = 0;		//Loads a specific lua file
char* PaletteToLoad = 0;	//Loads a specific palette file
char* AviToLoad = 0;		//Starts an avi capture at startup
char* DumpInput = 0; //Dumps all polled input to a binary file. Probably only useful with -playmovie. This is a rickety system, only useful in limited cases.
char* PlayInput = 0; //Replays all polled input from a binary file. Useful without playmovie.  This is a rickety system, only useful in limited cases.

extern bool turbo;

// TODO: Parsing arguments needs to be improved a lot. A LOT.

//-------------------------------------------------------------
// Parses commandline arguments
//-------------------------------------------------------------
char *ParseArgies(int argc, char *argv[])
{         
        static ARGPSTRUCT FCEUArgs[]={
         {"-pal",&pal_setting_specified,&pal_emulation,0},
		 {"-dendy",0,&dendy,0},
         {"-noicon",0,&status_icon,0},
         {"-gg",0,&genie,0},
         {"-no8lim",0,&eoptions,0x8000|EO_NOSPRLIM},
         //{"-nofs",0,&eoptions,0},   
         {"-clipsides",0,&eoptions,0x8000|EO_CLIPSIDES},  
         {"-nothrottle",0,&eoptions,0x8000|EO_NOTHROTTLE},
         {"-playmovie",0,&MovieToLoad,0x4001},
		 {"-lua",0,&LuaToLoad,0x4001},
		 {"-palette",0,&PaletteToLoad,0x4001},
         {"-loadstate",0,&StateToLoad,0x4001},
         {"-readonly",0,&replayReadOnlySetting,0},
         {"-stopframe",0,&replayStopFrameSetting,0},
         {"-framedisplay",0,&frame_display,0},
         {"-inputdisplay",0,&input_display,0},
         {"-allowUDLR",0,&allowUDLR,0},
         {"-stopmovie",0,&pauseAfterPlayback,0},
         {"-shutmovie",0,&closeFinishedMovie,0},
         {"-bginput",0,&EnableBackgroundInput,0},
         {"-turbo",0,&turbo,0},
		 {"-pause",0,&PauseAfterLoad,0},
		 {"-cfg",0,&ConfigToLoad,0x4001},
		 {"-avi",0,&AviToLoad,0x4001},
		 {"-avicapture",0,&AVICapture,0},
				 {"-dumpinput",0,&DumpInput,0x4001},
				 {"-playinput",0,&PlayInput,0x4001},
         {0, 0, 0, 0},
	};

       if(argc <= 1)
	   {
		   return(0);
	   }

       int used = ParseArguments(argc-1, &argv[1], FCEUArgs);

       return(argv[used+1]);
}
