#include "Log.h"
#include <android/log.h>

void LOG(u16 type, const char * format, ...) {

	static android_LogPriority androidLogTranslate[] = {
			ANDROID_LOG_SILENT,
			ANDROID_LOG_ERROR,
			ANDROID_LOG_INFO,
			ANDROID_LOG_WARN,
			ANDROID_LOG_DEBUG,
			ANDROID_LOG_VERBOSE,
	};

	if (type > LOG_LEVEL)
		return;

	va_list va;
	va_start(va, format);
	__android_log_vprint(androidLogTranslate[type], "GLideN64", format, va);
	va_end(va);
}
