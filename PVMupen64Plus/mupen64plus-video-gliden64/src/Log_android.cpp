#include "Log.h"
#include <android/log.h>

void LOG(u16 type, const char * format, ...) {
	if (type > LOG_LEVEL)
		return;

	va_list va;
	va_start(va, format);
	__android_log_vprint(ANDROID_LOG_DEBUG, "GLideN64", format, va);
	va_end(va);
}
