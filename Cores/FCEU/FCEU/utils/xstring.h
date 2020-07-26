/* Extended string routines
 *
 * Copyright notice for this file:
 *  Copyright (C) 2004 Jason Oster (Parasyte)
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
#include <string>
#include <string.h>
#include <stdlib.h>
#include <vector>
#include <iostream>

#include "../types.h"
#include "../emufile.h"

#ifndef __GNUC__
#define strcasecmp strcmp
#endif

//definitions for str_strip() flags
#define STRIP_SP	0x01 // space
#define STRIP_TAB	0x02 // tab
#define STRIP_CR	0x04 // carriage return
#define STRIP_LF	0x08 // line feed


int str_ucase(char *str);
int str_lcase(char *str);
int str_ltrim(char *str, int flags);
int str_rtrim(char *str, int flags);
int str_strip(char *str, int flags);
int chr_replace(char *str, char search, char replace);
int str_replace(char *str, char *search, char *replace);

int HexStringToBytesLength(const std::string& str);
int Base64StringToBytesLength(const std::string& str);
std::string BytesToString(const void* data, int len);
bool StringToBytes(const std::string& str, void* data, int len);

std::vector<std::string> tokenize_str(const std::string & str,const std::string & delims);
void splitpath(const char* path, char* drv, char* dir, char* name, char* ext);

uint16 FastStrToU16(char* s, bool& valid);
char *U16ToDecStr(uint16 a);
char *U32ToDecStr(uint32 a);
char *U32ToDecStr(char* buf, uint32 a);
char *U32ToDecStr(char* buf, uint32 a, int digits);
char *U8ToDecStr(uint8 a);
char *U8ToHexStr(uint8 a);
char *U16ToHexStr(uint16 a);

std::string stditoa(int n);

std::string readNullTerminatedAscii(EMUFILE* is);

//extracts a decimal uint from an istream
template<typename T> T templateIntegerDecFromIstream(EMUFILE* is)
{
	unsigned int ret = 0;
	bool pre = true;

	for(;;)
	{
		int c = is->fgetc();
		if(c == -1) return ret;
		int d = c - '0';
		if((d<0 || d>9))
		{
			if(!pre)
				break;
		}
		else
		{
			pre = false;
			ret *= 10;
			ret += d;
		}
	}
	is->unget();
	return ret;
}

inline uint32 uint32DecFromIstream(EMUFILE* is) { return templateIntegerDecFromIstream<uint32>(is); }
inline uint64 uint64DecFromIstream(EMUFILE* is) { return templateIntegerDecFromIstream<uint64>(is); }

//puts an optionally 0-padded decimal integer of type T into the ostream (0-padding is quicker)
template<typename T, int DIGITS, bool PAD> void putdec(EMUFILE* os, T dec)
{
	char temp[DIGITS];
	int ctr = 0;	// at least one char will always be outputted
	for (int i = 0; i < DIGITS; ++i)
	{
		int remainder = dec % 10;
		temp[(DIGITS - 1) - i] = '0' + remainder;
		if (!PAD)
		{
			if (remainder != 0)
				ctr = i;
		}
		dec /= 10;
	}
	if (!PAD)
		os->fwrite(temp + (DIGITS - 1) - ctr, ctr + 1);
	else
		os->fwrite(temp, DIGITS);
}

std::string mass_replace(const std::string &source, const std::string &victim, const std::string &replacement);

std::wstring mbstowcs(std::string str);
std::string wcstombs(std::wstring str);



//TODO - dont we already have another  function that can do this
std::string getExtension(const char* input);

std::string StripExtension(std::string filename);
std::string StripPath(std::string filename);