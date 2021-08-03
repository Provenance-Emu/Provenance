/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Ben Parnell
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

#include <windows.h>
#include <winsock.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <math.h>

#define HAVE_LOCALE_H 1
#define HAVE_ICONV 1
#define ICONV_CONST const
#define HAVE_SETLOCALE 1
#define ENABLE_NLS 1

#include "common.h"
#include "texthook.h"
#include "debugger.h"
#include "..\..\palette.h" //bbit edited: this line changed to include this instead of svga.h
#include "..\..\video.h" //needed for XBuf
#include "cdlogger.h" //needed for TextHookerLoadTable
#include "fceu.h"
#include "main.h"
#include "utils/xstring.h"

char *textToTrans; // buffer to hold the text that needs translating
char *transText; //holds the translated text

extern void FCEUD_BlitScreen(uint8 *XBuf); //needed for pause, not sure where this is defined...
//adelikat merge 7/1/08 - had to add these extern variables 
//------------------------------
extern uint8 PALRAM[0x20];
extern uint8 PPU[4];
extern uint8 *vnapage[4];
extern uint8 *VPage[8];
//------------------------------
HWND hTextHooker;

int excitecojp(); //translation function, defined later

int TextHookerPosX,TextHookerPosY; //location of text hooker window
uint8 TextHookerpalcache[32] = { 0xFF }; //palette cache
uint8 thchrcache0[0x1000],thchrcache1[0x1000]; //cache CHR, fixes a refresh problem when right-clicking
//bbit todo: is the above needed? can't right clicking just cause a delayed refresh by changing variables?
uint8 *thpattern0,*thpattern1; //pattern table bitmap arrays
//what scanline to update on, is the texthooker on or off, how often to refresh, how many unupdated frames have past
int TextHookerScanline=200,TextHooker=0,TextHookerRefresh=1,TextHookerSkip=1;
int thmouse_x,thmouse_y; //mouse location
uint8 hScroll=0x00, vScroll=0x00;  //stores horizontal and vertical scroll, set by textupdate() in x6502.c
int callTextHooker = -1; //used by textupdate() in x6502.c to determine when to update hScroll and vScroll
uint8 tileToggles[32][30]; //keeps track of which tiles in the selection window are selected
uint8 pausedTileToggles[32][30]; //same as above, but is used during the emulator's paused state
int lmousedown = 0; //keeps track of the the left mousebuttons down state (for click/drag selection)
int drawingorerasing = 1; //keeps track of whether the user is selecting or deselecting on the selection window
static char chartable[256][4]; //used for table mappings
static int TableFileLoaded = 0; //boolean for whether a table file is loaded or not
uint16 tile = 0x0000; //used to store the value of a tile at a given x,y location
int tileattr = 0; //used to store the corresponding attribute location for tile (see getTextHookerTile)
uint16 maru = 0x1000; //used to store the lookup value for the handakuten mark
uint16 tenten = 0x1000; //used to store the lookup value for the dakuten mark

char* hashholder; //used to hold the selection hashes

#define PATTERNWIDTH	256
#define PATTERNHEIGHT	240
#define PATTERNBITWIDTH	PATTERNWIDTH*3
#define PATTERNDESTX	10
#define PATTERNDESTY	15
#define ZOOM			1

#define NameTable       (PPU[0]&0x03)    /* name table $2000/$2400/$2800/$2C00*/ 

BITMAPINFO thbmInfo;
HDC thpDC,thTmpDC0;//,thTmpDC1;
HBITMAP thTmpBmp0;//,thTmpBmp1;
HGDIOBJ thTmpObj0;//,thTmpObj1;



//this struct is used to store ja/en words for word replacement
struct llword {
	//holds the japanese word
	char ja[40];

	//holds the english definition
	char en[40];

	//holds the next item in the sequence
	llword* next;
};

llword *words; //initial word



/*
 * redraws the selection screen
 */
void TextHookerDoBlit() {
	//if the text hooker isn't on, don't bother
	if (!hTextHooker) return;

	//if we're still waiting for a certain amount of frames to pass...
	if ( TextHookerSkip < TextHookerRefresh ) {
		//..increment the skipped frames counter and return
		TextHookerSkip++;
		return;
	}

	//reset the skip counter
	TextHookerSkip = 1;

	//and blit the screen
	StretchBlt(thpDC,PATTERNDESTX,PATTERNDESTY,PATTERNWIDTH*ZOOM,PATTERNHEIGHT*ZOOM,thTmpDC0,0,PATTERNHEIGHT-1,PATTERNWIDTH,-PATTERNHEIGHT,SRCCOPY);}


/*
 * This is called by x6502.c
 * I honestly forget what it's function is supposed to be,
 * but i'm leaving it here anyway in case I remember at some point
 */
void TextHookerCheck() {
	if ( callTextHooker == -1 ) { //this keeps it from updating between writes to $2004
	}
}


/*
 * This is used to update the pixel colors for a given tile
 * It's called once for each tile on the screen
 */
inline void DrawTextHookerChr(uint8 *pbitmap,uint8 *chr,int pal,int makeitred){
	int y, x, tmp, index=0, p=0;
	uint8 chr0, chr1;

	for (y = 0; y < 8; y++) { //todo: use index for y?
		chr0 = chr[index];
		chr1 = chr[index+8];
		tmp=7;
		for (x = 0; x < 8; x++) { //todo: use tmp for x?
			p = (chr0>>tmp)&1;
			p |= ((chr1>>tmp)&1)<<1;
			p = PALRAM[p+(pal*4)];
			tmp--;

			if ( EmulationPaused == 1 ) {
				//when we're paused, makeitred determines whether to invert
				//the current colors or not
				if ( makeitred == 1 ) {
					*(uint8*)(pbitmap) = 255 - *(uint8*)(pbitmap);
					pbitmap++;
					*(uint8*)(pbitmap) = 255 - *(uint8*)(pbitmap);
					pbitmap++;
					*(uint8*)(pbitmap) = 255 - *(uint8*)(pbitmap);
					pbitmap++;
				} else {
					pbitmap++;
					pbitmap++;
					pbitmap++;
				}
			} else {
				//otherwise, makeitred determines whether to invert
				//the pallette or not
				if ( makeitred == 1 ) {
					*(uint8*)(pbitmap++) = 0xFF - palo[p].b;
					*(uint8*)(pbitmap++) = 0xFF - palo[p].g;
					*(uint8*)(pbitmap++) = 0xFF - palo[p].r;
				} else {
					*(uint8*)(pbitmap++) = palo[p].b;
					*(uint8*)(pbitmap++) = palo[p].g;
					*(uint8*)(pbitmap++) = palo[p].r;
				}
			}
		}
		index++;
		pbitmap += (PATTERNWIDTH*3)-24;
	}
}


/*
 * For the given x,y tile coordinate, sets tile to its hex value (for the pattern table and table file)
 * and sets tileattr to the correct spot in the correct attribute table (for drawing the display)
 */
void getTextHookerTile( int x, int y ) {
	uint16 base = 0x0000;
	uint16 upperLeft = 0x0000;
	uint8 tx = 0x00;
	uint8 ty = 0x00;
	uint8 xTooFar,yTooFar;

	tile = 0x0000;
	tileattr = 0;

	//get the base from NameTable
	base = 0x2000 + ( NameTable << 0x0A );

	//calculate the address of the upperLeft corner of the display
	upperLeft = base + ( ( vScroll >> 0x03 ) << 0x05 ) + ( hScroll >> 0x03 );

	tx = x;
	ty = y;

	//decide if this tile is beyond the bounds of the current NameTable
	if ( tx + ( hScroll >> 0x03 ) > 0x1F ) {
		xTooFar = 0x01;
	} else {
		xTooFar = 0x02;
	}
	if ( ty + ( vScroll >> 0x03 ) > 0x1D ) {
		yTooFar = 0x04;
	} else {
		yTooFar = 0x08;
	}
	
	//use yTooFar and xTooFar to figure out if we need to loop around to another NameTable
	//i really should have commented this more back when i wrote it...
	switch ( xTooFar | yTooFar ) {
		case 0x0A:
			tile = upperLeft + ( ty << 0x05 ) + tx;
			tileattr = (vnapage[(tile & 0x0C00) >> 0x0A][0x3C0+(((y+(vScroll>>3))>>2)<<3)+((x+(hScroll>>3))>>2)] &
			           (3<<((((y+(vScroll>>3))&2)<<1)+((x+(hScroll>>3))&2)))) >> ((((y+(vScroll>>3))&2)<<1)+((x+(hScroll>>3))&2));
			break;
		case 0x06:
			tile = upperLeft + 0x800 - ( ( NameTable & 0x02 ) << 0x0B ) + 
			       ( ( ty  - 0x1E ) << 0x05 ) + tx;
			tileattr = (vnapage[(tile & 0x0C00) >> 0x0A][0x3C0+(((y-(0x1E - (vScroll>>3)))>>2)<<3)+((x+(hScroll>>3))>>2)] &
			           (3<<((((y-(0x1E - (vScroll>>3)))&2)<<1)+((x+(hScroll>>3))&2)))) >> ((((y-(0x1E - (vScroll>>3)))&2)<<1)+((x+(hScroll>>3))&2));
			break;
		case 0x09:
			tile = upperLeft + 0x400 - ( ( NameTable & 0x01 ) << 0x0B ) + ( ty << 0x05 ) +
			       ( tx - 0x20 );
			tileattr = (vnapage[(tile & 0x0C00) >> 0x0A][0x3C0+(((y+(vScroll>>3))>>2)<<3)+((x-(0x20 - (hScroll>>3)))>>2)] &
			           (3<<((((y+(vScroll>>3))&2)<<1)+((x-(0x20 - (hScroll>>3)))&2)))) >> ((((y+(vScroll>>3))&2)<<1)+((x-(0x20 - (hScroll>>3)))&2));
			break;
		case 0x05:
			tile = upperLeft + 0x800 - ( ( NameTable & 0x02 ) << 0x0B ) +
			                   0x400 - ( ( NameTable & 0x01 ) << 0x0B ) +
			                   ( ( ty - 0x1E ) << 0x05 ) + 
			                   ( tx - 0x20 );
			tileattr = (vnapage[(tile & 0x0C00) >> 0x0A][0x3C0+(((y-(0x1E - (vScroll>>3)))>>2)<<3)+((x-(0x20 - (hScroll>>3)))>>2)] &
			           (3<<((((y-(0x1E - (vScroll>>3)))&2)<<1)+((x-(0x20 - (hScroll>>3)))&2)))) >> ((((y-(0x1E - (vScroll>>3)))&2)<<1)+((x-(0x20 - (hScroll>>3)))&2));
			break;
	}

	tile = vnapage[(tile & 0x0C00) >> 0x0A][tile & 0x03FF];
}



/*
 * This function is sort of the glue for the rest of the functions
 * It iterates through each tile and 
 *   -updates its attribute information based on the PPU data
 *   -modifies that attribute data based on whether or not it's selected
 * It then tells the text hooker to blit the selection window
 *   (which may or may not happen based on the current settings)
 */
void UpdateTextHooker() {

	//see if we're supposed to update
	if ( IsDlgButtonChecked(hTextHooker,341) != BST_CHECKED ) {
		return;
	}

	int x,y, chr, ptable=0;
	uint8 *bitmap = thpattern0;
	uint8 *pbitmap = bitmap;

	if(PPU[0]&0x10){ //use the correct pattern table based on this bit
		ptable=0x1000;
	}

	pbitmap = bitmap;

	for(y = 0;y < 30;y++){
		for(x = 0;x < 32;x++){
			//get the tile info from the PPU
			getTextHookerTile( x, y );
			chr = tile*16;

			//if we're paused
			if ( EmulationPaused == 1 ) {
				//if the selection has changed since we paused
				if ( tileToggles[x][y] != pausedTileToggles[x][y] ) {
					DrawTextHookerChr(pbitmap,&VPage[(ptable+chr)>>10][ptable+chr],tileattr,1);
				} else { //nothing has changed since we paused
					DrawTextHookerChr(pbitmap,&VPage[(ptable+chr)>>10][ptable+chr],tileattr,0);
				}
				//after updates have been made to tileToggles, reset pausedTileToggles
				pausedTileToggles[x][y] = tileToggles[x][y];
			} else { //we aren't paused, do a normal call
				DrawTextHookerChr(pbitmap,&VPage[(ptable+chr)>>10][ptable+chr],tileattr,tileToggles[x][y]);
			}
			pbitmap += (8*3);
		}
		pbitmap += 7*((PATTERNWIDTH*3));
	}

	//attempt to blit the selection window
	TextHookerDoBlit();
}


/*
 * table functions taken from memview.c
 * modified to allow multibyte strings
 * and to allow for the modified .tht format
 */

/*
 * This is used to unload the table file
 *
 * This includes
 *  -clearing the ja=>en translation table
 *  -clearing the saved selections
 *  -clearing the words in the word replacement dictionary
 *  -setting the TableFileLoaded bool to false
 */
void TextHookerUnloadTableFile(){
	//clear the translation table
	memset( chartable, 0, sizeof( char ) * 256 * 4 );

	//clear the selection combobox
	SendDlgItemMessage(hTextHooker,109,CB_RESETCONTENT,0,0);

	//clear the selections hash holder
	if ( hashholder != NULL ) {
		free( hashholder );
		hashholder = NULL;
	}

	//if there are words...
	if ( words != NULL ) {
		//cleanup all the words in words
		while ( words->next != NULL ) {
			llword *beforelast = words;
			llword *last = words->next;
			while ( last->next != NULL ) {
				beforelast = last;
				last = last->next;
			}
			if ( last != NULL ) {
				free( last );
			}
			beforelast->next = NULL;
		}

		//finally, kill words
		free( words );
		words = NULL;
	}

	//set the bool to false
	TableFileLoaded = 0;
	return;
}


/*
 * Why would you ever want to kill the text hooker?
 *
 * It's your standard cleanup function
 */
void KillTextHooker() {
	TextHookerUnloadTableFile();
	//GDI cleanup
	DeleteObject(thTmpBmp0);
	SelectObject(thTmpDC0,thTmpObj0);
	DeleteDC(thTmpDC0);
	ReleaseDC(hTextHooker,thpDC);

	DestroyWindow(hTextHooker);
	hTextHooker=NULL;
	TextHooker=0;
}

//this is defined elsewhere and is called by TextHookerLoadTableFile
//i don't think it's ever actually used, though...
//extern void StopSound(void);


/*
 * Here's the painful-to-write table loading function
 *
 * It's commented fairly well, so just browse it.
 *
 * It should return -1, otherwise returns the line number it had the error on
 */

//adelikat:  Pulled this from TextHookerLoadTableFile so that a specific file can be loaded (such as in drag & drop)
int TextHookerLoadTable(const char* nameo)
{
	char str[500]; //holds the current line of the table file
	FILE *FP; //file pointer
	unsigned int i, j, line, charcode1, charcode2; //various useful variables
	
	//get rid of any existing table info
	TextHookerUnloadTableFile();

	//prepare the translation table
	memset( chartable, 0, sizeof( char ) * 256 * 4 );

	//open the file
	FP = fopen(nameo,"r");
	line = 0; //keep track of what line we're on
	while((fgets(str, 45, FP)) != NULL){/* get one line from the file */
		line++; //increment the line counter

		//is this too short to be anyting?
		if(strlen(str) < 3)continue;

		//is this a new section (such as [selections])?
		if( strncmp( str, "[", 1 ) == 0 ) {
			break;
		}

		charcode1 = charcode2 = -1;  //initialize the charcodes (nibbles)

		if((str[0] >= 'a') && (str[0] <= 'f')) charcode1 = str[0]-('a'-0xA);
		if((str[0] >= 'A') && (str[0] <= 'F')) charcode1 = str[0]-('A'-0xA);
		if((str[0] >= '0') && (str[0] <= '9')) charcode1 = str[0]-'0';

		if((str[1] >= 'a') && (str[1] <= 'f')) charcode2 = str[1]-('a'-0xA);
		if((str[1] >= 'A') && (str[1] <= 'F')) charcode2 = str[1]-('A'-0xA);
		if((str[1] >= '0') && (str[1] <= '9')) charcode2 = str[1]-'0';
		
		//first nibble is invalid
		if(charcode1 == -1){
			TextHookerUnloadTableFile();
			fclose(FP);
			return line; //we have an error getting the first input
		}

		//use the second nibble if it's set, otherwise assume single-digit 0-F
		if(charcode2 != -1) charcode1 = (charcode1<<4)|charcode2;

		//look for the '='
		for(i = 0;i < strlen(str);i++)if(str[i] == '=')break;

		//if we don't find an '=', quit
		if(i == strlen(str)){
			TextHookerUnloadTableFile();
			fclose(FP);
			return line; //error no '=' found
		}

		i++; //move on to the character after the '='

		//note: ORing i with 32 just converts it to lowercase if it isn't

		//look for 'maru'
		if(((str[i]|32) == 'm') && ((str[i+1]|32) == 'a') && ((str[i+2]|32) == 'r') && ((str[i+3]|32) == 'u')) {
			maru = charcode1;
		//look for 'tenten'
		} else if (((str[i]|32) == 't') && ((str[i+1]|32) == 'e') && ((str[i+2]|32) == 'n') && ((str[i+3]|32) == 't') && ((str[i+4]|32) == 'e') && ((str[i+5]|32) == 'n')) {
			tenten = charcode1;
		//else, look for anything else
		} else {
			j = 0;
			while ( i < strlen(str) && str[i] != '\r' && str[i] != '\n' && j < 4 ) {
				chartable[charcode1][j] = str[i];
				i++;
				j++;
			}
		}
	}

	int numselections = 0; //init the number of selections
	//see if we're in the [selections] section
	if( strncmp( str, "[selections]", 12 ) == 0 ) {
		while((fgets(str, 500, FP)) != NULL){/* get one line from the file */
			line++; //remember what line we're on

			//line is too short
			if ( strlen(str) < 3 ) continue;

			//is this a new section (such as [words])
			if( strncmp( str, "[", 1 ) == 0 ) {
				break;
			}

			//look for the equals sign
			for(i = 0;i < strlen(str);i++)if(str[i] == '=')break;

			//make sure we found an '='
			if(i == strlen(str)){
				TextHookerUnloadTableFile();
				fclose(FP);
				MessageBox( NULL, str, "Error line is...", MB_OK );
				return line; //error no '=' found
			}

			//init the selection name holder
			char sname[335];
			memset( sname, 0, sizeof( sname ) );

			//copy the selection name into sname
			strncpy( sname, str, i );

			i++; //skip the equals sign

			//get the hash of the selection
			char sel[165];
			strncpy( sel, str + ( i * sizeof( char ) ), 165 );

			//add the name to the combobox
			SendDlgItemMessage(hTextHooker,109,CB_INSERTSTRING,-1,(LPARAM)(LPTSTR)sname);

			//get ready to add the hash to the hashholder

			//increase the size of the hashholder
			if ( hashholder == NULL ) { //first entry?
				hashholder = (char*)malloc( sizeof( char ) * 165 );
			}

			//resize
			hashholder = (char*)realloc( hashholder, sizeof( char ) * 165 * (numselections+1) );

			//make sure we have enough space on the heap
			if ( hashholder == NULL ) {
				printf( "not enough memory" );
				exit( 1 );
			}

			//and append the newest hash to the end
			strcpy( (char*)(hashholder + ( numselections * sizeof( char ) * 165 )), sel );

			//increment the selection count
			numselections++;


		}
	}

	//see if we're gonna start loading words for the word replacement dictionary
	if ( strncmp( str, "[words]", 7 ) == 0 ) {
		//load up the words
		while((fgets(str, 500, FP)) != NULL){/* get one line from the file */
			line++; //keep track of what line we're on

			//make sure it's long enough to be anything relevant
			if ( strlen(str) < 3 ) continue;

			//look for the equals sign
			for(i = 0;i < strlen(str);i++)if(str[i] == '=')break;

			//make sure we found an equals sign
			if(i == strlen(str)){
				TextHookerUnloadTableFile();
				fclose(FP);
				MessageBox( NULL, str, "Error line is...", MB_OK );
				return line; //error no '=' found
			}

			//init the japanese word holder
			char ja[40];
			memset( ja, 0, sizeof( ja ) );

			//copy the japanese word into ja
			strncpy( ja, str, i );

			i++; //skip the equals sign

			//init the english word holder
			char en[40];
			memset( en, 0, sizeof( en ) );

			//copy the english word into en
			strncpy( en, str + ( i * sizeof( char ) ), 40 );

			//add the word to the words list

			//init words if we need to
			if ( words == NULL ) {
				words = (llword*)malloc( sizeof( llword ) );
				words->next = NULL;
			}

			//create the word item
			llword *newitem = (llword*)malloc( sizeof( llword ) );
			strcpy( newitem->en, en );
			strcpy( newitem->ja, ja );
			newitem->next = NULL;

			//special case if this is the first word
			if ( words->next == NULL ) {
				words->next = newitem;
			} else { //put it somewhere in the middle
				llword *previous = words;
				llword *current = words->next;

				while ( current != NULL ) {
					if ( strlen( newitem->ja ) >= strlen( current->ja ) ) {
						//bigger than or as big as the current word, insert it here
						newitem->next = current;
						previous->next = newitem;
						break;
					}

					//move on to the next two items
					previous = current;
					current = current->next;
				}

				//if current is null, then newitem is shorter than the other words
				//so it goes on the bottom
				if ( current == NULL ) {
					previous->next = newitem;
				}

			}

		}
	}

	//set the table loaded boolean
	TableFileLoaded = 1;
	//close of the file
	fclose(FP);
	//return successfully
	return -1;
}

int TextHookerLoadTableFile(){
	//initialize the "File open" dialogue box
	const char filter[]="Table Files (*.THT)\0*.tht\0All Files (*.*)\0*.*\0\0";
	char nameo[2048]; //todo: possibly no need for this? can lpstrfilter point to loadedcdfile instead?
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Load Table File...";
	ofn.lpstrFilter=filter;
	nameo[0]=0;
	ofn.lpstrFile=nameo;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.hwndOwner = hCDLogger;

	//get the file name or stop
	if(!GetOpenFileName(&ofn))return -1;

	int result = TextHookerLoadTable(nameo);

	return result;
}




/*
 * This is the far-less-painful-to-code table saving function.
 * 
 * Check the comments to see how it works
 *
 * should return -1 if it worked
 */

int TextHookerSaveTableFile(){
	char str[500]; //a temporary string
	FILE *FP; //the file pointer
	int i, line; //counters

	//init the "Save File" dialogue
	const char filter[]="Table Files (*.THT)\0*.tht\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];
	OPENFILENAME ofn;
	//StopSound(); //mbg merge 6/30/08
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Load Table File...";
	ofn.lpstrFilter=filter;
	strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());
	ofn.lpstrFile=nameo;
	ofn.lpstrDefExt="tht";
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_HIDEREADONLY|OFN_EXTENSIONDIFFERENT;
	ofn.hwndOwner = hCDLogger;

	//get the file name or quit
	if(!GetSaveFileName(&ofn))return 0;

	//open the file
	FP = fopen(nameo,"wb");
	line = 0; //init the line counter

	char hex[3] = { 0, 0, 0 };
	
	//write the table file to the file
	for ( i = 0; i < 256; i++ ) { //go through each possible hex value
		if ( strlen( chartable[i] ) != 0 ) { //make sure there's this value holds something
			sprintf( hex, "%02X", i ); //get the value of i into a hex string
			fputs( hex, FP ); //hex
			fputs( "=", FP ); //=
			fputs(chartable[i], FP ); //letter
			fputs("\r\n", FP ); //newline
		}
	}

	//write tenten and maru
	if ( tenten != 0x1000 ) { //if tenten is set
		sprintf( hex, "%02X", tenten ); //get the value of tenten into a hex string
		fputs( hex, FP ); //write the hex
		fputs( "=tenten\r\n", FP ); //write the rest
	}

	if ( maru != 0x1000 ) { //if maru is set
		sprintf( hex, "%02X", maru ); //get the value of maru into a hex string
		fputs( hex, FP ); //write the hex
		fputs( "=maru\r\n", FP ); //write the rest
	}

	//write the selection header to the file
	fputs( "\r\n[selections]\r\n", FP );

	//get the number of selections
	int numselections = SendDlgItemMessage(hTextHooker,109,CB_GETCOUNT,0,0);

	//write the selection hashes to the file
	for ( i = 0; i < numselections; i++ ) {
		memset( str, 0, sizeof( str ) ); //init str
		SendDlgItemMessage(hTextHooker,109,CB_GETLBTEXT,i,(LPARAM)(LPTSTR)str); //get the selection name
		fputs( str, FP ); //write the name
		fputs( "=", FP ); //write the =
		fputs( (char*)(hashholder + ( i * sizeof( char ) * 165 ) ), FP ); //write the hash
		fputs( "\r\n", FP ); //write the newline
	}

	//write the words header to the file
	fputs( "\r\n[words]\r\n", FP );

	//get a pointer to the first word
	llword *current = words;

	//write all the words
	while( current != NULL ) {
		fputs( current->ja, FP ); //japanese string
		fputs( "=", FP ); //equals sign
		fputs( current->en, FP ); //english string
		fputs( "\r\n", FP ); //newline
		current = current->next; //get the next word
	}

	//close the file
	fclose( FP );
	//return successfully
	return -1;

}


/*
 * This hanldes all those wacky dialogue callbacks
 *
 * Looking for comments?  Inqure within!
 *
 */
BOOL CALLBACK TextHookerCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	RECT wrect;
	char str[2048];
	char bufferstr[10240]; //holds the entire buffer, so it needs to be big...
	char bufferstrtemp[10240];
	void* found = (void*)"\0";
	char binstring[165];
	char byteline[165];
	int bytecounter;
	int x,y;
	int i,j;
	int lastReadY = -1;
	uint16 temptile = 0x0000;
	char tempchar[4];
	llword *current = NULL; //used for search&replace
	llword *newitem = NULL;
	llword *previous = NULL;
	int charcounter;
	int	si;
	int saveFileErrorCheck = 0; //used to display error message that may have arised from saving a file
	
	memset( str, 0, sizeof( str ) );
	memset( bufferstr, 0, sizeof( bufferstr ));

	switch(uMsg) {
		case WM_INITDIALOG:
			SetWindowPos(hwndDlg,0,TextHookerPosX,TextHookerPosY,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);

			//prepare the bitmap attributes
			//pattern tables
			memset(&thbmInfo.bmiHeader,0,sizeof(BITMAPINFOHEADER));
			thbmInfo.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
			thbmInfo.bmiHeader.biWidth = PATTERNWIDTH;
			thbmInfo.bmiHeader.biHeight = PATTERNHEIGHT;
			thbmInfo.bmiHeader.biPlanes = 1;
			thbmInfo.bmiHeader.biBitCount = 24;

			//create memory dcs
			thpDC = GetDC(hwndDlg); // GetDC(GetDlgItem(hwndDlg,101));
			thTmpDC0 = CreateCompatibleDC(thpDC); //pattern table 0

			//create bitmaps and select them into the memory dc's
			thTmpBmp0 = CreateDIBSection(thpDC,&thbmInfo,DIB_RGB_COLORS,(void**)&thpattern0,0,0);
			thTmpObj0 = SelectObject(thTmpDC0,thTmpBmp0);

			//clear cache
			memset(TextHookerpalcache,0,32);
			memset(thchrcache0,0,0x1000);
			memset(thchrcache1,0,0x1000);

			memset(tileToggles,0,sizeof(uint8)*32*30);
			
			SetDlgItemText(hwndDlg,102,"Welcome to the Text Hooker!");
			SetDlgItemText(hwndDlg,116,"");
			SetDlgItemText(hwndDlg,111,"");
			SetDlgItemText(hwndDlg,120,"0");
			SetDlgItemText(hwndDlg,121,"1");

			TextHooker=1;
			break;
		case WM_DROPFILES:
			{
				//adelikat:  Drag and Drop does not check extension, it will simply attempt to open it as a table file
				UINT len;
				char *ftmp;
				len=DragQueryFile((HDROP)wParam,0,0,0)+1; 
				if((ftmp=(char*)malloc(len))) 
				{
					DragQueryFile((HDROP)wParam,0,ftmp,len); 
					std::string fileDropped = ftmp;
					
					int result = TextHookerLoadTable(fileDropped.c_str());
					//write a response message to str based on x's value
					if ( result == -1 ) 
						sprintf( str, "Table Loaded Successfully!" );
					 else 
						sprintf( str, "Table is not Loaded!\r\nError on line: %d", result );
					//store the current text into the buffer
					GetDlgItemText(hwndDlg,102,bufferstr,sizeof( bufferstr ));
					strcat( bufferstr, "\r\n" ); //add a newline
					strcat( bufferstr, str ); //add the status message to the buffer
					SetDlgItemText(hwndDlg,102,bufferstr); //display the buffer
				}
			}
			break;
		case WM_PAINT:
			TextHookerDoBlit();
			break;
		case WM_CLOSE:
		case WM_QUIT:
			KillTextHooker();
			break;
		case WM_MOVING:
			//StopSound(); //mbg merge 6/30/08
			break;
		case WM_MOVE:
			if (!IsIconic(hwndDlg)) {
			GetWindowRect(hwndDlg,&wrect);
			TextHookerPosX = wrect.left;
			TextHookerPosY = wrect.top;

			#ifdef WIN32
			WindowBoundsCheckNoResize(TextHookerPosX,TextHookerPosY,wrect.right);
			#endif
			}
			break;
		case WM_RBUTTONDBLCLK:
			sprintf(str,"aaaa");
			SetDlgItemText(hwndDlg,102,str);
			break;
		case WM_LBUTTONDOWN:
			//this is where selecting text in the selection window is handled, part 1 of 2

			lmousedown = 1; //set the mousedown bool

			//if we're within the bounds of the selection window
			if ((lmousedown == 1) && ((thmouse_x >= PATTERNDESTX) && (thmouse_x < (PATTERNDESTX+(PATTERNWIDTH*ZOOM)))) && (thmouse_y >= PATTERNDESTY) && (thmouse_y < (PATTERNDESTY+(PATTERNHEIGHT*ZOOM)))) {
				int tilex,tiley; //some ints to hold our tile coords

				//get the tile coors
				tilex = thmouse_x - PATTERNDESTX;
				tilex = tilex / ( 8 * ZOOM );
				tiley = thmouse_y - PATTERNDESTY;
				tiley = tiley / ( 8 * ZOOM );

				//and toggle the tile
				if ( tileToggles[tilex][tiley] == 0 ) {
					tileToggles[tilex][tiley] = 1;
					drawingorerasing = 1;
				} else {
					tileToggles[tilex][tiley] = 0;
					drawingorerasing = 0;
				}

				//do all the hard work
				UpdateTextHooker();
			}

			break;
		case WM_LBUTTONUP:
			//okay, so this is part 1.5 of 2...
			lmousedown = 0;
			break;
		case WM_MOUSEMOVE:
			//this is where selecting text in the selection window is handled, part 2 of 2

			//get the mouse position
			thmouse_x = GET_X_LPARAM(lParam);
			thmouse_y = GET_Y_LPARAM(lParam);

			//make sure the left mouse button is down and we're inside the selection window
			if ((lmousedown == 1) && ((thmouse_x >= PATTERNDESTX) && (thmouse_x < (PATTERNDESTX+(PATTERNWIDTH*ZOOM)))) && (thmouse_y >= PATTERNDESTY) && (thmouse_y < (PATTERNDESTY+(PATTERNHEIGHT*ZOOM)))) {
				int tilex,tiley; //holds the tile coords

				//get the tile coords
				tilex = thmouse_x - PATTERNDESTX;
				tilex = tilex / ( 8 * ZOOM );
				tiley = thmouse_y - PATTERNDESTY;
				tiley = tiley / ( 8 * ZOOM );

				//toggle the tile value
				if ( drawingorerasing == 1 ) {
					tileToggles[tilex][tiley] = 1;
				} else {
					tileToggles[tilex][tiley] = 0;
				}

				//do all the hard work
				UpdateTextHooker();

				//blit the selection window immediately
				TextHookerSkip = TextHookerRefresh;
				TextHookerDoBlit();
			}

			break;
		case WM_NCACTIVATE:
			//get the values from the scanline and refresh inputs into variables
			SetDlgItemInt(hwndDlg,120,TextHookerScanline,1);
			SetDlgItemInt(hwndDlg,121,TextHookerRefresh,1);
			break;
		case WM_COMMAND:
			switch(HIWORD(wParam)) {
				case EN_UPDATE:				
					//what scanline are we updating on? 
					GetDlgItemText(hwndDlg,120,str,4);
					if ( TextHookerScanline != atoi( str ) ) {
						TextHookerScanline = atoi( str );
						if ( !TextHookerScanline ) TextHookerScanline = 0;
						if (TextHookerScanline < 0 ) TextHookerScanline = 0;
						if (TextHookerScanline > 239) TextHookerScanline = 239;
					}
					
					//how often are we going to redraw?
					memset( str, 0, sizeof( str ) );					
					GetDlgItemText(hwndDlg,121,str,4);
					if ( TextHookerRefresh != atoi( str ) ) {
						TextHookerRefresh = atoi( str );
						if ( !TextHookerRefresh ) TextHookerRefresh = 1;
						if (TextHookerRefresh < 1 ) TextHookerRefresh = 1;
						if (TextHookerRefresh > 60) TextHookerRefresh = 60;
					}
					
					break;

				case BN_CLICKED:
					switch(LOWORD(wParam)) {
						case 104: //load a table file
							//call the load function
							x = TextHookerLoadTableFile();

							//write a response message to str based on x's value
							if ( x == -1 ) {
								sprintf( str, "Table Loaded Successfully!" );
							} else {
								sprintf( str, "Table is not Loaded!\r\nError on line: %d", x );
							}

							//store the current text into the buffer
							GetDlgItemText(hwndDlg,102,bufferstr,sizeof( bufferstr ));
							strcat( bufferstr, "\r\n" ); //add a newline
							strcat( bufferstr, str ); //add the status message to the buffer
							SetDlgItemText(hwndDlg,102,bufferstr); //display the buffer
							break;
						case 105: //clear the selection
							memset( tileToggles, 0, sizeof( uint8 ) * 32 * 30 );

							//do the hard work
							UpdateTextHooker();

							//blit the selection window immediately
							TextHookerSkip = TextHookerRefresh;
							TextHookerDoBlit();

							break;
							//mbg 8/6/08 - this looks weird
						//case 106: //pause button (F2)
						//	if ( userpause == 1 ) {
						//		userpause = 0;
						//	} else {
						//		userpause = 1;
						//		memcpy( pausedTileToggles, tileToggles, sizeof( tileToggles ) );
						//	}
						//	FCEUD_BlitScreen(XBuf+8);
						//	break;
						case 107: //the SNAP button (oh snap!)
							if ( TableFileLoaded == 1 ) { //make sure there's a table loaded
								//go through each tile
								for ( y = 0; y < 30; y++ ) {
									for ( x = 0; x < 32; x++ ) {
										//if the tile is selected
										if ( tileToggles[x][y] == 1 ) {
											//check if we're on a new line
											if ( y > lastReadY ) {
												//add a newline
												strcat( str, "\r\n" );
												lastReadY = y;
											}

											//get the tile info
											getTextHookerTile( x, y );
											//and store it into a temp var
											temptile = tile;

											//init tempchar
											memset( tempchar, 0, sizeof( char ) * 4 );

											//make sure it exists in the table
											if ( strlen(chartable[temptile]) != 0 ) {
												//check for marks above the tile
												if ( y != 0 && IsDlgButtonChecked(hwndDlg,343) == BST_CHECKED ) { //not the top row...
													getTextHookerTile( x, y-1 ); //check the tile above x,y
													if ( tile == maru || tile == tenten ) { //if there's a mark
														tempchar[0] = chartable[temptile][0];
														tempchar[1] = chartable[temptile][1];
														tempchar[2] = chartable[temptile][2];
														tempchar[3] = chartable[temptile][3];
														if ( tile == maru ) {
															tempchar[1] = tempchar[1] + 2;
														} else {
															tempchar[1] = tempchar[1] + 1;
														}
														strcat( str, tempchar ); //add the marked kana
													} else {
														strcat( str, chartable[temptile] ); //add the regular kana
													}
												//now check for marks to the right
												} else if ( x != 31 && IsDlgButtonChecked(hwndDlg,344) == BST_CHECKED ) {
													getTextHookerTile( x+1, y ); //check the tile to the right of x,y
													if ( tile == maru || tile == tenten ) { //if there's a mark
														tempchar[0] = chartable[temptile][0];
														tempchar[1] = chartable[temptile][1];
														tempchar[2] = chartable[temptile][2];
														tempchar[3] = chartable[temptile][3];
														if ( tile == maru ) {
															tempchar[1] = tempchar[1] + 2;
														} else {
															tempchar[1] = tempchar[1] + 1;
														}
														strcat( str, tempchar ); //add the marked kana
													} else {
														strcat( str, chartable[temptile] ); //add the regular mark
													}
												} else { //just a plain old character
													strcat( str, chartable[tile] );
												}
											} else { //not in the table...
												//place a space
												memset( tempchar, 0, sizeof( char ) * 4 );
												tempchar[0] = (char)0x81;
												tempchar[1] = 0x40;
												strcat( str, tempchar );
											}
										}
									}
								}
							} else { //no table!
								sprintf(str,"Table file not loaded!");
							}

							//do a search&replace using the words list

							//make sure we have words and that we're supposed to do word replacement
							if ( words != NULL && IsDlgButtonChecked(hwndDlg,342) == BST_CHECKED ) {
								current = words->next; //get the first word
								while ( current != NULL ) { //while there's still words to check
									found = strstr( str, current->ja ); //search the buffer for the word
									memset( bufferstrtemp, 0, sizeof( bufferstrtemp ) ); //init the temp buffer
									if ( found ) { //if we found it, replace it
										//add a null byte after the first half
										strcpy( (char*)found, "\0" ); 

										//copy the first half of the haystack
										strcpy( bufferstrtemp, str ); 

										//tack on the replacement text
										strcat( bufferstrtemp, current->en ); 

										//tack on the rest of the haystack
										strcat( bufferstrtemp, (char*)found + ( strlen( current->ja ) ) ); 

										//copy the temp back to the haystack
										strcpy( str, bufferstrtemp );

									 }

									//get the next word
									current = current->next;

								}
							}


							//store the current text into the buffer
							GetDlgItemText(hwndDlg,102,bufferstr,sizeof( bufferstr ));
							strcat( bufferstr, "\r\n" ); //add a newline
							strcat( bufferstr, str ); //add the hooked text to the buffer
							SetDlgItemText(hwndDlg,102,bufferstr); //display the buffer
							break;

						case 108: //clear the buffer
							SetDlgItemText(hwndDlg,102,"");
							break;
							
						case 117: //excite.co.jp
							//init the buffers
							textToTrans = (char*)malloc( sizeof( char ) * 1024 );
							transText = (char*)malloc( sizeof( char ) * 2048 );
							memset( textToTrans, 0, sizeof( char ) * 1024 );

							//get the buffer into textToTrans
							GetDlgItemText(hwndDlg,102,textToTrans,1024);
							//do the translation
							excitecojp();
							//get the translation into the translation window
							SetDlgItemText(hwndDlg,116,transText);

							//free up the buffers' space
							free( textToTrans );
							free( transText );

							break;
							
						case 122: //trim

							//init the temp string
							memset( str, 0, sizeof( str ) );
							//get the buffer into the temp string
							GetDlgItemText(hwndDlg,102,str,sizeof(str));

							//make found true
							found = (int*)1;

							while( found ) { //replace until there's nothing left to replace

								found = strstr( str, "  " ); //look for multiple spaces
								if ( !found ) {
									found = strstr( str, "\r\n" ); //and also for newlines
								}
								memset( bufferstrtemp, 0, sizeof( bufferstrtemp ) ); //init the temp buffer
								if ( found ) { //found something to replace!
									//add a null byte after the first half
									strcpy( (char*)found, "\0" ); 

									//copy the first half of the haystack
									strcpy( bufferstrtemp, str ); 

									//tack on the replacement text
									strcat( bufferstrtemp, " " ); 

									//tack on the rest of the haystack
									strcat( bufferstrtemp, (char*)found + 2 ); 

									//copy the temp back to the haystack
									strcpy( str, bufferstrtemp );

								}

							}

							//set the buffer to the trimmed text
							SetDlgItemText(hwndDlg,102,str);

							break;
							
						case 112: //save selection
							/*
							 * some notes about the selection hashes:
							 *
							 * The selection screen is nothing but a grid of tiles.
							 * Each tile can be toggled on or off (1 or 0).
							 * 
							 * To get the hash, do this:
							 *   -go down each column of tiles, going left to right, and
							 *    write down a 1 or a 0 depending on whether the tile is
							 *    selected or not.
							 *   -use that string of bits to create the bytes of the hash
							 *     -each byte of the hash begins with 01, such that:
							 *      01xxxxxx
							 *      each x takes a single bit from the bit string, so you
							 *      can see that each byte holds six bits that are relevant
							 *      to the selection
							 *     -the 01 at the beginning is used to keep the hashes as
							 *      ASCII and not get messed up if the .tht is altered with
							 *      a text editor
							 *   -once the entire bit string has been written, the hash is
							 *    completed.
							 *
							 */

							//get the values of tileToggles into a string
							memset ( byteline, 0, sizeof( byteline ) );
							memset ( binstring, 0, sizeof( binstring ) );
							bytecounter = 0;
							//hold the value of eight characters (0 or 1) into this byte
							x = 64;
							y = 0; //counts to 6
							for ( i = 0; i < 32; i++ ) {
								for ( j = 0; j < 30; j++ ) {
									//add to x
									x += (1<<y) * tileToggles[i][j];
									
									y++;
									if ( y >= 6 ) { //we have a full byte now
										memset( byteline + bytecounter, (char)x, 1 );
										bytecounter++;
										x = 64;
										y = 0;
									}
								}
							}
							if ( y < 6 ) { //write the rest
								memset( byteline + bytecounter, (char)x, 1 );
							}


							//make sure the entry name is not blank (duplicates are allowed)

							GetDlgItemText(hwndDlg,111,str,2000);

							if ( strcmp( str, "" ) == 0 ) {
								MessageBox( NULL, "Enter a name for the selection first.", "OH NO!", MB_OK );
							} else {
								//since it's not null, add it to the combobox
								int lr;
								lr = SendDlgItemMessage(hwndDlg,109,CB_INSERTSTRING,-1,(LPARAM)(LPSTR)str);

								//now lr is holding our index value
								//increase the size of the hashholder
								if ( hashholder == NULL ) {
									hashholder = (char*)malloc( sizeof( char ) * 165 );
								}
								hashholder = (char*)realloc( hashholder, sizeof( char ) * 165 * (lr+1) );
								if ( hashholder == NULL ) {
									printf( "not enough memory" );
									exit( 1 );
								}

								//and append the newest hash to the end
								strcpy( (char*)(hashholder + ( lr * sizeof( char ) * 165 )), byteline );
							}

							
							break;

						case 114: //load selection
							//init some vars
							memset ( byteline, 0, sizeof( byteline ) );
							memset ( binstring, 0, sizeof( binstring ) );

							//get the index of the selection from the combobox
							si = SendDlgItemMessage(hwndDlg,109,CB_GETCURSEL,0,0);
							if ( si == CB_ERR ) {
								MessageBox( NULL, "Choose a selection first", "OH NO!", MB_OK );
								break;
							}

							//get the saved selection hash into byteline
							strcpy( byteline, (char*)(hashholder + ( si * sizeof( char ) * 165 )) );

							//extract the pattern from byteline

							//hold the value of eight characters (0 or 1) into this byte
							x = 64;
							y = 8; //counts to 6

							for ( i = 0; i < sizeof( byteline ); i++ ) {
								x = byteline[i];
								for ( y = 0; y < 6; y++ ) {
									if ( ( x & (1<<y)) != 0 ) {
										strcat( binstring, "1" );
									} else {
										strcat( binstring, "0" );
									}
								}
							}

							//set tiletoggles to the extracted selection
							charcounter = 0;
							for ( i = 0; i < 32; i++ ) {
								for ( j = 0; j < 30; j++ ) {
									if ( strncmp( (char*)(binstring + ( sizeof( char ) * charcounter ) ), "1", 1 ) == 0 ) {
											tileToggles[i][j] = 1;
										} else {
											tileToggles[i][j] = 0;
										}
										charcounter++;
								}
							}							

							//update the text hooker in case we're paused
							UpdateTextHooker();
							TextHookerSkip = TextHookerRefresh;
							TextHookerDoBlit();

							break;

						case 113: //save table
							saveFileErrorCheck = TextHookerSaveTableFile();
							switch (saveFileErrorCheck)
							case -1:
								MessageBox( NULL, "File successfully saved!", "", MB_OK );
							case 0:
								break;
							default:
								MessageBox( NULL, "There was a problem saving the table file.", "", MB_OK );
						break;

						case 133: //save word
							//add the word to the words list
							//create the word item
							newitem = (llword*)malloc( sizeof( llword ) );

							//get the english and japanese values
							GetDlgItemText(hwndDlg,131,newitem->ja,40);
							GetDlgItemText(hwndDlg,132,newitem->en,40);
							newitem->next = NULL;

							//check for blanks
							if ( strcmp( newitem->ja, "" ) == 0 ||
								strcmp( newitem->en, "" ) == 0 ) {
								free( newitem );
								newitem = NULL;
								MessageBox( NULL, "Please enter both a Japanese phrase and an English phrase.", "OH NO!", MB_OK );
								break;
							}

							//init words if we need to
							if ( words == NULL ) {
								words = (llword*)malloc( sizeof( llword ) );
								words->next = NULL;
							}

							//special case if this is the first word
							if ( words->next == NULL ) {
								words->next = newitem;
							} else { //put it somewhere in the middle
								previous = words;
								current = words->next;

								while ( current != NULL ) {
									if ( strlen( newitem->ja ) >= strlen( current->ja ) ) {
										//bigger than or as big as the current word, insert it here
										newitem->next = current;
										previous->next = newitem;
										break;
									}

									//move on to the next two items
									previous = current;
									current = current->next;
								}

								//if current is null, then newitem is shorter than the other words
								//so it goes on the bottom
								if ( current == NULL ) {
									previous->next = newitem;
								}

							}


							break;

					}
					break;
			}
			break;
		case WM_HSCROLL:
			if (lParam) { //refresh trackbar
			}
			break;
			
	}
	return FALSE;
}


int excitecojp() {
	// Create the socket
	SOCKET theSocket;

	WORD sockVersion;
	WSADATA wsaData;
	int nret;

	sockVersion = MAKEWORD(1, 1);

	// Initialize Winsock as before
	WSAStartup(sockVersion, &wsaData);

	// Store information about the server
	LPHOSTENT hostEntry;

	hostEntry = gethostbyname("www.excite.co.jp");	// Specifying the server by its name;

	if (!hostEntry) {
		nret = WSAGetLastError();
		sprintf( transText, "gethostbyname() returned error #%d\r\n", nret );	// Report the error as before

		WSACleanup();
		return NETWORK_ERROR;
	}

	theSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

	if (theSocket == INVALID_SOCKET) {
		nret = WSAGetLastError();
		sprintf( transText, "socket() returned error #%d\r\n", nret );

		WSACleanup();
		return NETWORK_ERROR;
	}

	// Fill a SOCKADDR_IN struct with address information
	SOCKADDR_IN serverInfo;

	serverInfo.sin_family = AF_INET;

	serverInfo.sin_addr = *((LPIN_ADDR)*hostEntry->h_addr_list);

	serverInfo.sin_port = htons(80);		// Change to network-byte order and

	// Connect to the server
	nret = connect(theSocket, (LPSOCKADDR)&serverInfo, sizeof(struct sockaddr));

	if (nret == SOCKET_ERROR) {
		nret = WSAGetLastError();
		sprintf( transText, "connect() returned error #%d\r\n", nret );

		WSACleanup();
		return NETWORK_ERROR;
	}

	// Successfully connected!

	char *buffer; // buffer to hold our http request
	buffer = (char*)malloc( sizeof( char ) * 2048 );
	memset( buffer, 0, 2048 );
	char *urlEscapedText; // holds the url escaped textToTrans
	urlEscapedText = (char*)malloc( sizeof( char ) * 2048 );
	memset( urlEscapedText, 0, 2048 );
	memset( buffer, 0, 2048 );
	
	unsigned int i;
	
	//create the url escaped buffer
	for ( i = 0; i < strlen( textToTrans ); i++ ) {
		sprintf( buffer, "%%%02X", textToTrans[i] );
		strcat( urlEscapedText, "%" );
		strcat( urlEscapedText, buffer + strlen( buffer ) - 2 );
		//strcat( urlEscapedText, buffer );
	}
	
	memset( buffer, 0, 2048 );
	
	//form the http request
	sprintf( buffer, "POST /world/english/ HTTP/1.1\r\nHost: www.excite.co.jp\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: %d\r\n\r\nbefore=%s&wb_lp=JAEN&start=%%96%%7C+%%96%%F3", strlen( urlEscapedText ) + 38, urlEscapedText );
		
	//this was needed before in order to make it work, keeping it here in case it starts acting up again
	//memset( textToTrans, 0, 1024 );

	nret = send(theSocket, buffer, strlen(buffer), 0);

	if (nret == SOCKET_ERROR) {
		// Handle accordingly
		strcpy( transText, "There was an error connecting to Excite.co.jp...\r\n" );
		return NETWORK_ERROR;
	}

	char *recvbuffer; //server response is read one char at a time
	recvbuffer = (char*)malloc( sizeof( char ) * 4 );
	char *theLine; //holds the current line being read from the server response
	theLine = (char*)malloc( sizeof( char ) * 2048 );
	memset( buffer, 0, 2048 );
	memset( theLine, 0, 2048 );
	memset( transText, 0, 2048 );
	memset( recvbuffer, 0, 4 );
	int foundTheLine = 0; //flag to keep track of when we've found the line(s) containing the translated text

	nret = recv( theSocket, recvbuffer, 1, 0 ); //get the first character

	while ( nret > 0 && foundTheLine != 2 ) { //keep processing the server response until there's nothing left
								//to process, or until we have all of the response needed
		if ( recvbuffer[0] == '\n' || recvbuffer[0] == '\r' ) {  //we've reached the end of a line...
			if ( foundTheLine == 1 ) { //this will only be used when there's more than one line of translated text
				//append a newline
				strcat( transText, "\r\n" );
				//check theLine for a </textarea>
				if ( strstr( theLine, "</textarea>" ) != NULL ) {
					//found, this is the last line containing translated text
					foundTheLine = 2; //set to 2 since we don't need any more data
					//copy all but the last </div></td> to transtext
					strncat( transText, theLine, strlen( theLine ) - 11 );
				} else {
					//not found, nothing but whitespace and/or translated text here
					//add it to transText
					strcat( transText, theLine );
					//clear out theLine
					ZeroMemory( theLine, 2048 );
				}
			} else {
				//check theLine for name="after" wrap="virtual" style="width:320px;">
				if ( strstr( theLine, "name=\"after\" wrap=\"virtual\" style=\"width:320px;\">" ) != NULL ) {
					//this is the first line containing translated text
					foundTheLine = 1;
					//check to see if all of the text is on this single line
					if ( strstr( theLine, "</textarea>" ) != NULL ) {
						//found, this is the last line containing translated text
						foundTheLine = 2; //set to 2 since we don't need any more data
						//copy just the text to transText
						strncat( transText, strstr( theLine, "name=\"after\" wrap=\"virtual\" style=\"width:320px;\">" ) + 49, strlen( strstr( theLine, "name=\"after\" wrap=\"virtual\" style=\"width:320px;\">" ) + 49 ) - 11 );
					} else { //the translated text is on more than one line
						//add the rest of the line to transText
						strcat( transText, strstr( theLine, "name=\"after\" wrap=\"virtual\" style=\"width:320px;\">" ) + 49 );
						//clear theLine
						ZeroMemory( theLine, 2048 );
					}
				} else { //this isn't the line we're looking for
					//clear theLine
					ZeroMemory( theLine, 2048 );
				}
			}
		} else { //just another character on the line...
			//add it to theLine
			strcat( theLine, recvbuffer );
		}

		nret = recv( theSocket, recvbuffer, 1, 0 ); //get the next character ready
	}

	//our result is now in transText

	if (nret == SOCKET_ERROR) {
		// Handle accordingly
		strcpy( transText, "There was an error communicating to Excite.co.jp...\r\n" );
		return NETWORK_ERROR;
	}

	// cleanup!
	free( recvbuffer );
	free( theLine );
	closesocket(theSocket);
	WSACleanup();

	return 1;
}


/*
 * ALL SYSTEMS GO!
 */
void DoTextHooker() 
{
	if (!GameInfo) 
	{
		FCEUD_PrintError("You must have a game loaded before you can use the Text Hooker.");
		return;
	}
	if (GameInfo->type==GIT_NSF) 
	{
		FCEUD_PrintError("Silly chip-tunes enthusiast, you can't use the Text Hooker with NSFs.");
		return;
	}
	if (!hTextHooker) hTextHooker = CreateDialog(fceu_hInstance,"TEXTHOOKER",NULL,TextHookerCallB);
	DWORD ret = GetLastError();

	CheckDlgButton( hTextHooker, 341, BST_CHECKED );
	CheckDlgButton( hTextHooker, 342, BST_CHECKED );
	CheckDlgButton( hTextHooker, 343, BST_CHECKED );

	if (hTextHooker)
	{
		//SetWindowPos(hTextHooker,HWND_TOP,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE|SWP_NOOWNERZORDER);
		ShowWindow(hTextHooker, SW_SHOWNORMAL);
		SetForegroundWindow(hTextHooker);
		UpdateTextHooker();
		TextHookerDoBlit();
	}
}


