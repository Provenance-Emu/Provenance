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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "ExternalWindow.h"

// int FileAssociation_DoRegister(void)
// return:
//  3 = Silent
//  2 = Fully success
//  1 = Partial success
//  0 = Failed to register
// -1 = Unsupported

// int FileAssociation_DoUnregister(void)
// return:
//  3 = Silent
//  2 = Fully success
//  1 = Partial success
//  0 = Failed to unregister
// -1 = Unsupported

#ifdef _WIN32
#include <windows.h>

// Windows file association

int FileAssociation_DoRegister(void)
{
	const char *tenam1 = "PokeMini_min";
	const char *tenam2 = "PokeMini_minc";
	const char *tenam3 = "PokeMini Emulator ROM";
	const char *tenam4 = "PokeMini Emulator Color File";
	const char *tenam5 = "debug";
	const char *tenam6 = "&Debug";
	const char *tenam7 = "&Color map";
	char tmp[PMTMPV];
	char tmp2[PMTMPV];
	char argv0[PMTMPV];
	int i;
	HKEY key, key2;
	DWORD dispo;

	// Receive module filename
	GetModuleFileName(NULL, argv0, PMTMPV);

	// HKEY_CLASSES_ROOT\.min
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, ".min", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam1, (DWORD)strlen(tenam1)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\.minc
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, ".minc", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam2, (DWORD)strlen(tenam2)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam3, (DWORD)strlen(tenam3)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam4, (DWORD)strlen(tenam4)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min\DefaultIcon
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\DefaultIcon", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	sprintf(tmp, "\"%s\",1", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc\DefaultIcon
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\DefaultIcon", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	sprintf(tmp, "\"%s\",2", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min?\shell
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, &dispo) != ERROR_SUCCESS) return 0;
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key2, NULL) != ERROR_SUCCESS) return 0;
	if (dispo == REG_CREATED_NEW_KEY) {
		if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam5, (DWORD)strlen(tenam5)+1) != ERROR_SUCCESS) return 0;
		if (RegSetValueExA(key2, NULL, 0, REG_SZ, (LPBYTE)tenam5, (DWORD)strlen(tenam5)+1) != ERROR_SUCCESS) return 0;
	}
	RegCloseKey(key);
	RegCloseKey(key2);

	// HKEY_CLASSES_ROOT\PokeMini_min?\shell\debug
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\debug", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\debug", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key2, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam6, (DWORD)strlen(tenam6)+1) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key2, NULL, 0, REG_SZ, (LPBYTE)tenam6, (DWORD)strlen(tenam6)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);
	RegCloseKey(key2);

	// HKEY_CLASSES_ROOT\PokeMini_min?\shell\debug\command
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\debug\\command", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\debug\\command", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key2, NULL) != ERROR_SUCCESS) return 0;
	sprintf(tmp, "\"%s\" \"%%1\"", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key2, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);
	RegCloseKey(key2);

	// HKEY_CLASSES_ROOT\PokeMini_min?\shell\paint
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\paint", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\paint", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key2, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam7, (DWORD)strlen(tenam7)+1) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key2, NULL, 0, REG_SZ, (LPBYTE)tenam7, (DWORD)strlen(tenam7)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);
	RegCloseKey(key2);

	// HKEY_CLASSES_ROOT\PokeMini_min?\shell\paint\command
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\paint\\command", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\paint\\command", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key2, NULL) != ERROR_SUCCESS) return 0;
	strcpy(tmp2, argv0);
	for (i=(int)strlen(tmp2)-1; i>=0; i--) if (tmp2[i] == '\\') { tmp2[i] = 0; break; }
	sprintf(tmp, "\"%s\\color_mapper.exe\" \"%%1\"", tmp2);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key2, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);
	RegCloseKey(key2);

	return 2;
}

int FileAssociation_DoUnregister(void)
{
	int success = 2;

	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\paint\\command")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\paint\\command")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\paint")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\paint")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\debug\\command")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\debug\\command")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\debug")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\debug")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell")) success = 1;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell")) success = 1;
	if (success == 2) {
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\DefaultIcon")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\DefaultIcon")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, ".min")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, ".minc")) success = 0;
	}

	return success;
}


#else

// Linux file association

int FileAssociation_DoRegister(void)
{
	char tmp[PMTMPV];
	sprintf(tmp, "sh -c './associateMin.sh register \"%s\"'", argv0);
	if (ExternalWindow_Launch(tmp, 0)) return 3;
	return 0;
}

int FileAssociation_DoUnregister(void)
{
	char tmp[PMTMPV];
	sprintf(tmp, "sh -c './associateMin.sh unregister \"%s\"'", argv0);
	if (ExternalWindow_Launch(tmp, 0)) return 3;
	return 0;
}

#endif
