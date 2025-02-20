/*

Copyright (c) 2012, Simon Howard

Permission to use, copy, modify, and/or distribute this software
for any purpose with or without fee is hereby granted, provided
that the above copyright notice and this permission notice appear
in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 */

//
// Architecture-specific files for compilation on Windows.
// A work in progress.
//

#include "lha_arch.h"

#if LHA_ARCH == LHA_ARCH_WINDOWS

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <fcntl.h>
#include <io.h>

#include <stdlib.h>
#include <stdint.h>

static uint64_t unix_epoch_offset = 0;

int lha_arch_vasprintf(char **result, char *fmt, va_list args)
{
	int len;

	len = vsnprintf(NULL, 0, fmt, args);
	if (len >= 0) {
		*result = malloc(len + 1);
		if (*result != NULL) {
			return vsprintf(*result, fmt, args);
		}
	}

	*result = NULL;
	return -1;
}

void lha_arch_set_binary(FILE *handle)
{
	_setmode(_fileno(handle), _O_BINARY);
}

int lha_arch_mkdir(char *path, unsigned int unix_mode)
{
	return CreateDirectoryA(path, NULL) != 0;
}

int lha_arch_chown(char *filename, int unix_uid, int unix_gid)
{
	return 1;
}

int lha_arch_chmod(char *filename, int unix_perms)
{
	return 1;
}

static int set_timestamps(char *filename,
                          FILETIME *creation_time,
                          FILETIME *modification_time,
                          FILETIME *access_time)
{
	HANDLE file;
	int result;

	// Open file handle to the file to change.
	// The FILE_FLAG_BACKUP_SEMANTICS flag is needed so that we
	// can obtain handles to directories as well as files.

	file = CreateFileA(filename,
	                   FILE_WRITE_ATTRIBUTES,
	                   FILE_SHARE_READ | FILE_SHARE_WRITE,
	                   NULL,
	                   OPEN_EXISTING,
	                   FILE_FLAG_BACKUP_SEMANTICS,
	                   NULL);

	if (file == INVALID_HANDLE_VALUE) {
		return 0;
	}

	// Set the timestamp and close the file handle.

	result = SetFileTime(file, creation_time,
	                     access_time, modification_time);
	CloseHandle(file);

	return result != 0;
}

int lha_arch_set_windows_timestamps(char *filename,
                                    uint64_t creation_time,
                                    uint64_t modification_time,
                                    uint64_t access_time)
{
	FILETIME _creation_time;
	FILETIME _modification_time;
	FILETIME _access_time;

	_creation_time.dwHighDateTime
	    = (uint32_t) ((creation_time >> 32) & 0xffffffff);
	_creation_time.dwLowDateTime
	    = (uint32_t) (creation_time & 0xffffffff);

	_modification_time.dwHighDateTime
	    = (uint32_t) ((modification_time >> 32) & 0xffffffff);
	_modification_time.dwLowDateTime
	    = (uint32_t) (modification_time & 0xffffffff);

	_access_time.dwHighDateTime
	    = (uint32_t) ((access_time >> 32) & 0xffffffff);
	_access_time.dwLowDateTime
	    = (uint32_t) (access_time & 0xffffffff);

	return set_timestamps(filename, &_creation_time,
	                      &_modification_time, &_access_time);
}

int lha_arch_utime(char *filename, unsigned int timestamp)
{
	SYSTEMTIME unix_epoch;
	FILETIME filetime;
	uint64_t ts_scaled;

	// Calculate offset between Windows FILETIME Jan 1, 1601 epoch
	// and Unix Jan 1, 1970 offset.

	if (unix_epoch_offset == 0) {
		unix_epoch.wYear = 1970;
		unix_epoch.wMonth = 1;
		unix_epoch.wDayOfWeek = 4; // Thursday
		unix_epoch.wDay = 1;
		unix_epoch.wHour = 0;     // 00:00:00.0
		unix_epoch.wMinute = 0;
		unix_epoch.wSecond = 0;
		unix_epoch.wMilliseconds = 0;

		SystemTimeToFileTime(&unix_epoch, &filetime);
		unix_epoch_offset = ((uint64_t) filetime.dwHighDateTime << 32)
		                  + filetime.dwLowDateTime;
	}

	// Convert to Unix FILETIME.

	ts_scaled = (uint64_t) timestamp * 10000000 + unix_epoch_offset;
	filetime.dwHighDateTime = (uint32_t) ((ts_scaled >> 32) & 0xffffffff);
	filetime.dwLowDateTime = (uint32_t) (ts_scaled & 0xffffffff);

	// Set all timestamps to the same value:

	return set_timestamps(filename, &filetime, &filetime, &filetime);
}

FILE *lha_arch_fopen(char *filename, int unix_uid, int unix_gid, int unix_perms)
{
	return fopen(filename, "wb");
}

LHAFileType lha_arch_exists(char *filename)
{
	WIN32_FILE_ATTRIBUTE_DATA file_attr;

	// Read file attributes to determine the type of the file.
	// If this fails, assume the file does not exist.

	if (GetFileAttributesExA(filename, GetFileExInfoStandard,
	                         &file_attr)) {
		if ((file_attr.dwFileAttributes
		       & FILE_ATTRIBUTE_DIRECTORY) != 0) {
			return LHA_FILE_DIRECTORY;
		} else {
			return LHA_FILE_FILE;
		}
	}

	return LHA_FILE_NONE;
}

int lha_arch_symlink(char *path, char *target)
{
	// No-op.
	return 1;
}

#endif /* LHA_ARCH_WINDOWS */
