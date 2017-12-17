/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

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

#include "PMCommon.h"
#include <ctype.h>

// Return true if the string is valid and non-empty
int StringIsSet(char *str)
{
	if (!str) return 0;
	if (strlen(str) == 0) return 0;
	return 1;
}

// Get multiple of 2
int GetMultiple2(int input)
{
	if (!input) return 0;
	input--;
	input |= (input >> 1);
	input |= (input >> 2);
	input |= (input >> 4);
	input |= (input >> 8);
	input |= (input >> 16);
	return input+1;
}

// Get multiple of 2 (Mask)
int GetMultiple2Mask(int input)
{
	if (input) input--;
	input |= (input >> 1);
	input |= (input >> 2);
	input |= (input >> 4);
	input |= (input >> 8);
	input |= (input >> 16);
	return input;
}

// Check if file exist
int FileExist(const char *filename)
{
	FILE *fi;

	// Test open file
	fi = fopen(filename, "rb");
	if (fi == NULL) return 0;
	fclose(fi);

	return 1;
}

// Get filename
char *GetFilename(const char *filename)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if ((filename[i] == '/') || (filename[i] == '\\')) {
			return (char *)&filename[i+1];
		}
	}
	return (char *)filename;
}

// Get extension
char *GetExtension(const char *filename)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if (filename[i] == '.') {
			return (char *)&filename[i];
		}
		if ((filename[i] == '/') || (filename[i] == '\\')) break;
	}
	return (char *)&filename[strlen(filename)-1];
}

// Extract path
char *ExtractPath(char *filename, int slash)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if ((filename[i] == '/') || (filename[i] == '\\')) {
			if (slash) filename[i+1] = 0;
			else filename[i] = 0;
			return filename;
		}
	}
	if (slash && !strlen(filename)) {
		filename[0] = '.';
		filename[1] = '/';
		filename[2] = 0;
	}
	return filename;
}

// Remove extension
char *RemoveExtension(char *filename)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if (filename[i] == '.') {
			filename[i] = 0;
			return filename;
		}
		if ((filename[i] == '/') || (filename[i] == '\\')) {
			return filename;
		}
	}
	return filename;
}

// Check if filename has certain extension
int ExtensionCheck(const char *filename, const char *ext)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if (filename[i] == '.') {
			if (strcasecmp(&filename[i], ext) == 0) {
				return 1;
			}
		}
		if ((filename[i] == '/') || (filename[i] == '\\')) {
			return 0;
		}
	}
	return 0;
}

// true if the path ends with a slash
int HasLastSlash(char *path)
{
	int len = strlen(path);
	if (!len) return 0;
	return (path[len-1] == '/') || (path[len-1] == '\\');
}

// Convert slashes to windows type
void ConvertSlashes(char *filename, int slashtype)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if ((filename[i] == '/') || (filename[i] == '\\')) {
			if (slashtype == 0) filename[i] = PATH_SLASH_CHR;
			else if (slashtype == 1) filename[i] = '/';
			else if (slashtype == 2) filename[i] = '\\';
		}
	}
}

// Trim string
char *TrimStr(char *s)
{
	int siz = strlen(s);
	char *ptr = s + siz - 1;
	if (!siz) return s;
	while ((ptr >= s) && (isspace((int)*ptr) || (*ptr == '\n') || (*ptr == '\r'))) --ptr;
	ptr[1] = '\0';
	while ((*s != 0) && (isspace((int)*s) || (*s == '\n') || (*s == '\r'))) s++;
	return s;
}

// Remove comments
void RemoveComments(char *s)
{
	while ((*s != 0) && (*s != ';') && (*s != '#')) s++;
	*s = 0;
}

// Up to token...
char *UpToToken(char *out, const char *in, char *tokens, char *tokenfound)
{
	char ch, *ltokens, lch;
	if (out) *out = 0;
	if (in) {
		while ((ch = *in++) != 0) {
			ltokens = tokens;
			while ((lch = *ltokens++) != 0) {
				if (ch == lch) {
					if (tokenfound) *tokenfound = lch;
					return (char *)in;
				}
			}
			if (out) {
				*out++ = ch;
				*out = 0;
			}
		}
	}
	if (tokenfound) *tokenfound = 0;
	return (char *)in;
}

// Remove characters
void RemoveChars(char *out, const char *in, char *chs)
{
	char ch, *lchs, lch;
	if (in) {
		while ((ch = *in++) != 0) {
			lchs = chs;
			while ((lch = *lchs++) != 0) {
				if (ch == lch) break;
			}
			if ((!lch) && (out)) {
				*out++ = ch;
			}
		}
	}
	if (out) *out = 0;
}

// Convert string to boolean
int Str2Bool(char *s)
{
	if (!strcasecmp(s, "1")) return 1;
	else if (!strcasecmp(s, "y")) return 1;
	else if (!strcasecmp(s, "yes")) return 1;
	else if (!strcasecmp(s, "t")) return 1;
	else if (!strcasecmp(s, "true")) return 1;
	else if (!strcasecmp(s, "on")) return 1;
	return 0;
}

// Convert boolean to string
const char *Bool2Str(int i)
{
	return (i ? "true" : "false");
}

// Convert boolean to string with an affirmative result
const char *Bool2StrAf(int i)
{
	return (i ? "yes" : "no");
}

// Fix symbol identification
void FixSymbolID(char *filename)
{
	int i;
	for (i = strlen(filename)-1; i >= 0; i--) {
		if (((filename[i] < '0') || (filename[i] > '9')) &&
		    ((filename[i] < 'a') || (filename[i] > 'z')) &&
		    ((filename[i] < 'A') || (filename[i] > 'Z')) &&
		    (filename[i] != '_')) {
			filename[i] = '_';
		}
	}
}

// Clear control characters
void ClearCtrlChars(char *s, int len)
{
	if (!len) return;
	while (len--) {
		if (*s < 32) *s = '.';
		s++;
	}
}

// atoi() that support hex numbers and default on failure
int atoi_Ex(const char *str, int defnum)
{
	int num = defnum;
	int res = 0;
	int sign = 0;
	if (strlen(str) >= 2 && str[0] == '-') {
		sign = 1;
		str++;
	}
	if (strlen(str) >= 2 && str[0] == '#') res = sscanf(&str[1], "%x", &num);
	else if (strlen(str) >= 2 && str[0] == '$') res = sscanf(&str[1], "%x", &num);
	else res = sscanf(str, "%i", &num);
	if (res != 1) return defnum;
	if (sign) num = -num;
	return num;
}

// atoi() that support hex numbers, return false on failure
int atoi_Ex2(const char *str, int *outnum)
{
	int res = 0;
	int sign = 0;
	if (strlen(str) >= 2 && str[0] == '-') {
		sign = 1;
		str++;
	}
	if (strlen(str) >= 2 && str[0] == '#') res = sscanf(&str[1], "%x", outnum);
	else if (strlen(str) >= 2 && str[0] == '$') res = sscanf(&str[1], "%x", outnum);
	else res = sscanf(str, "%i", outnum);
	if (res == 1 && sign) *outnum = -*outnum;
	return res;
}

// atof() that return float and support default on failure
float atof_Ex(const char *str, float defnum)
{
	float num = defnum;
	sscanf(str, "%f", &num);
	return num;
}

// Separate string at character
int SeparateAtChar(char *s, char ch, char **key, char **value)
{
	char *ptr = s;
	while ((*ptr != 0) && (*ptr != ch)) ptr++;
	if (*ptr == 0) return 0;
	*ptr = 0;
	*key = s;
	*value = ptr+1;
	return 1;
}

// Separate string at any character
static int SeparateAtChars_i(char s, char *chs)
{
	if (s == 0) return 0;
	while (*chs != 0) {
		if (s == *chs++) return 1;
	}
	return 0;
}
int SeparateAtChars(char *s, char *chs, char **key, char **value)
{
	char *ptr = s;
	while (*ptr != 0) {
		if (SeparateAtChars_i(*ptr, chs)) break;
		ptr++;
	}
	if (*ptr == 0) return 0;
	*ptr = 0;
	if (key) *key = s;
	if (value) *value = ptr+1;
	return 1;
}

// Get an argument from executable parameters
int GetArgument(const char *runcmd, int args, char *out, int len, char **runcmd_found)
{
	char lch = ' ', ch;
	int argc = 0;

	while ((ch = *runcmd++) != 0) {
		if ((ch == ' ') || (ch == '\t') || (ch == '\n') || (ch == '\r')) {
			// Ignore spaces / new-lines
			if ((lch != ' ') && (lch != '\t') && (lch != '\n') && (lch != '\r')) {
				argc++;
				if (runcmd_found && (argc == args)) *runcmd_found = (char *)runcmd - 1;
			}
		} else if (ch == '"') {
			// " String
			while ((ch = *runcmd++) != 0) {
				if (ch == '"') {
					break;
				} else if (out && (argc == args) && (len > 0)) {
					*out++ = ch;
					len--;
				}
				lch = ch;
			}
		} else if (ch == '\'') {
			// ' String
			while ((ch = *runcmd++) != 0) {
				if (ch == '\'') {
					break;
				} else if (out && (argc == args) && (len > 0)) {
					*out++ = ch;
					len--;
				}
				lch = ch;
			}
		} else {
			// Any other character
			if (out && (argc == args) && (len > 0)) {
				*out++ = ch;
				len--;
			}
		}
		lch = ch;
	}

	if ((lch != ' ') && (lch != '\t') && (lch != '\n') && (lch != '\r')) {
		argc++;
		if (runcmd_found && (argc == args)) *runcmd_found = (char *)runcmd - 1;
	}
	return argc;
}

FILE *PokeDebugFOut = NULL;
FILE *PokeDebugFErr = NULL;

void PokeDPrint(int pokemsg, char *format, ...)
{
	char buffer[PMTMPV];
	va_list args;
	va_start(args, format);
	vsprintf(buffer, format, args);
	switch (pokemsg) {
	case POKEMSG_OUT:
		if (PokeDebugFOut) fwrite(buffer, 1, strlen(buffer), PokeDebugFOut);
		printf("%s", buffer);
		break;
	case POKEMSG_ERR:
		if (PokeDebugFErr) fwrite(buffer, 1, strlen(buffer), PokeDebugFErr);
		fprintf(stderr, "%s", buffer);
		break;
	}
	va_end(args);
}

#ifndef NO_DIRS

#ifdef _MSC_VER
#include <direct.h>
#else
#include <unistd.h>
#endif

char PokeMini_ExecDir[PMTMPV];	// Executable directory
char PokeMini_CurrDir[PMTMPV];	// Current directory

// Initialize directories
void PokeMini_InitDirs(char *argv0, char *exec)
{
	// Get current directory
	PokeMini_GetCurrentDir();

	// Get executable directory
	if (argv0) {
		if ((argv0[0] == '/') || (strchr(argv0, ':') != NULL)) {
			// Absolute path
			strcpy(PokeMini_ExecDir, argv0);
			if (exec) strcpy(exec, PokeMini_ExecDir);
			ExtractPath(PokeMini_ExecDir, 1);
		} else {
			// Not an absolute path
			if (HasLastSlash(PokeMini_CurrDir)) sprintf(PokeMini_ExecDir, "%s%s", PokeMini_CurrDir, argv0);
			else sprintf(PokeMini_ExecDir, "%s/%s", PokeMini_CurrDir, argv0);
			if (exec) strcpy(exec, PokeMini_ExecDir);
			ExtractPath(PokeMini_ExecDir, 1);
		}
	} else {
		strcpy(PokeMini_ExecDir, PokeMini_CurrDir);
	}

}

// Get current directory and save on parameter
void PokeMini_GetCustomDir(char *dir, int max)
{
	if (!getcwd(dir, max)) {
		strcpy(dir, "/");
		PokeDPrint(POKEMSG_ERR, "getcwd() error\n");
	}
	if (!strlen(dir)) strcpy(dir, "/");
	else ConvertSlashes(dir, PATH_SLASH_UNIX);
}

// Go to custom directory
void PokeMini_GotoCustomDir(const char *dir)
{
	char buffer[PMTMPV];
	strcpy(buffer, dir);
	ConvertSlashes(buffer, PATH_SLASH_OS);
	if (chdir(buffer)) {
		PokeDPrint(POKEMSG_ERR, "abs chdir('%s') error\n", buffer);
	}
}

// Get current directory
void PokeMini_GetCurrentDir(void)
{
	PokeMini_GetCustomDir(PokeMini_CurrDir, PMTMPV);
}

// Set current directory
void PokeMini_SetCurrentDir(const char *dir)
{
	PokeMini_GotoCustomDir(dir);
	PokeMini_GetCurrentDir();
}

// Go to current directory
void PokeMini_GotoCurrentDir(void)
{
	PokeMini_GotoCustomDir(PokeMini_CurrDir);
}

// Go to launch directory
void PokeMini_GotoExecDir(void)
{
	PokeMini_GotoCustomDir(PokeMini_ExecDir);
}

#else

void PokeMini_InitDirs(char *execdir) {}
void PokeMini_GetCurrentDir(void) {}
void PokeMini_GotoCurrentDir(void) {}
void PokeMini_GotoExecDir(void) {}

#endif
