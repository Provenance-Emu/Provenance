/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef PMCOMMON_H
#define PMCOMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdint.h>

#ifndef inline
#define inline __inline
#endif

// Temporary variable length
// Minimum is 128
// Recommended is 256
#ifndef PMTMPV
#define PMTMPV	256
#endif

#ifdef _WIN32
#define PATH_SLASH_CHR '\\'
#define PATH_SLASH_STR "\\"
#else
#define PATH_SLASH_CHR '/'
#define PATH_SLASH_STR "/"
#endif

#define PATH_SLASH_OS    0
#define PATH_SLASH_UNIX  1
#define PATH_SLASH_WIN   2

// Return a number between min and max
static inline int BetweenNum(int num, int min, int max)
{
	return (num < min) ? min : (num > max) ? max : num;
}

// Return true if the string is valid and non-empty
int StringIsSet(char *str);

// Get multiple of 2
int GetMultiple2(int input);

// Get multiple of 2 (Mask)
int GetMultiple2Mask(int input);

// Check if file exist
int FileExist(const char *filename);

// Get filename
char *GetFilename(const char *filename);

// Get extension
char *GetExtension(const char *filename);

// Extract path
char *ExtractPath(char *filename, int slash);

// Remove extension
char *RemoveExtension(char *filename);

// Check if filename has certain extension
int ExtensionCheck(const char *filename, const char *ext);

// true if the path ends with a slash
int HasLastSlash(char *path);

// Convert slashes to windows type
void ConvertSlashes(char *filename, int slashtype);

// Trim string
char *TrimStr(char *s);

// Remove comments
void RemoveComments(char *s);

// Up to token...
char *UpToToken(char *out, const char *in, char *tokens, char *tokenfound);

// Remove characters
void RemoveChars(char *out, const char *in, char *chs);

// Convert string to boolean
int Str2Bool(char *s);

// Convert boolean to string
const char *Bool2Str(int i);

// Convert boolean to string with an affirmative result
const char *Bool2StrAf(int i);

// Fix symbol identification
void FixSymbolID(char *filename);

// Clear control characters
void ClearCtrlChars(char *s, int len);

// atoi() that support hex numbers and default on failure
int atoi_Ex(const char *str, int defnum);

// atoi() that support hex numbers, return false on failure
int atoi_Ex2(const char *str, int *outnum);

// atof() that return float and support default on failure
float atof_Ex(const char *str, float defnum);

// Separate string at character
int SeparateAtChar(char *s, char ch, char **key, char **value);

// Separate string at any character
int SeparateAtChars(char *s, char *chs, char **key, char **value);

// Get an argument from executable parameters
int GetArgument(const char *runcmd, int args, char *out, int len, char **runcmd_found);

// Directories
void PokeMini_InitDirs(char *argv0, char *exec);
void PokeMini_GetCustomDir(char *dir, int max);
void PokeMini_SetCurrentDir(const char *dir);
void PokeMini_GotoCustomDir(const char *dir);
void PokeMini_GetCurrentDir();
void PokeMini_GotoCurrentDir();
void PokeMini_GotoExecDir();

#ifndef NO_DIRS
extern char PokeMini_ExecDir[PMTMPV];	// Launch directory
extern char PokeMini_CurrDir[PMTMPV];	// Current directory
#endif

// For debugging
enum {
	POKEMSG_OUT,
	POKEMSG_ERR
};
extern FILE *PokeDebugFOut;
extern FILE *PokeDebugFErr;
void PokeDPrint(int pokemsg, char *format, ...);

#endif
