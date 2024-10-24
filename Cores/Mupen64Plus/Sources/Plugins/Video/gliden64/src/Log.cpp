#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <cwchar>
#include "Log.h"
#include "PluginAPI.h"
#include "wst.h"

void LOG(u16 type, const char * format, ...) {
	if (type > LOG_LEVEL)
		return;

	wchar_t logPath[PLUGIN_PATH_SIZE + 16];
	api().GetUserDataPath(logPath);
	gln_wcscat(logPath, wst("/gliden64.log"));

#ifdef OS_WINDOWS
	FILE *dumpFile = _wfopen(logPath, wst("a+"));
#else
	constexpr size_t bufSize = PLUGIN_PATH_SIZE * 6;
	char cbuf[bufSize];
	wcstombs(cbuf, logPath, bufSize);
	FILE *dumpFile = fopen(cbuf, "a+");
#endif //OS_WINDOWS

	if (dumpFile == nullptr)
		return;
	va_list va;
	va_start(va, format);
	vfprintf(dumpFile, format, va);
	fclose(dumpFile);
	va_end(va);
}

#if defined(OS_WINDOWS) && !defined(MINGW)
#include "windows/GLideN64_windows.h"
void debugPrint(const char * format, ...) {
	char text[256];
	wchar_t wtext[256];
	va_list va;
	va_start(va, format);
	vsprintf(text, format, va);
	mbstowcs(wtext, text, 256);
	OutputDebugString(wtext);
	va_end(va);
}
#endif
