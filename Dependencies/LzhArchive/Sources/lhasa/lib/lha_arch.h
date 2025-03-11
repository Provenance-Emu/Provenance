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

#ifndef LHASA_LHA_ARCH_H
#define LHASA_LHA_ARCH_H

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>

#define LHA_ARCH_UNIX     1
#define LHA_ARCH_WINDOWS  2

#ifdef _WIN32
#define LHA_ARCH LHA_ARCH_WINDOWS
#else
#define LHA_ARCH LHA_ARCH_UNIX
#endif

typedef enum {
	LHA_FILE_NONE,
	LHA_FILE_FILE,
	LHA_FILE_DIRECTORY,
	LHA_FILE_ERROR,
} LHAFileType;

/**
 * Cross-platform version of vasprintf().
 *
 * @param result      Pointer to a variable to store the resulting string.
 * @param fmt         Format string.
 * @param args        Additional arguments for printf().
 * @return            Number of characters in resulting string, or -1 if
 *                    an error occurred in generating the string.
 */

int lha_arch_vasprintf(char **result, char *fmt, va_list args);

/**
 * Change the mode of the specified FILE handle to be binary mode.
 *
 * @param handle      The FILE handle.
 */

void lha_arch_set_binary(FILE *handle);

/**
 * Create a directory.
 *
 * @param path        Path to the directory to create.
 * @param unix_perms  Unix permissions for the directory to create.
 * @return            Non-zero if the directory was created successfully.
 */

int lha_arch_mkdir(char *path, unsigned int unix_perms);

/**
 * Change the Unix ownership of the specified file or directory.
 * If this is not a Unix system, do nothing.
 *
 * @param filename   Path to the file or directory.
 * @param unix_uid   The UID to set.
 * @param unix_gid   The GID to set.
 * @return           Non-zero if set successfully.
 */

int lha_arch_chown(char *filename, int unix_uid, int unix_gid);

/**
 * Change the Unix permissions on the specified file or directory.
 *
 * @param filename    Path to the file or directory.
 * @param unix_perms  The permissions to set.
 * @return            Non-zero if set successfully.
 */

int lha_arch_chmod(char *filename, int unix_perms);

/**
 * Set the file creation / modification time on the specified file or
 * directory.
 *
 * @param filename    Path to the file or directory.
 * @param timestamp   The Unix timestamp to set.
 * @return            Non-zero if set successfully.
 */

int lha_arch_utime(char *filename, unsigned int timestamp);

/**
 * Set the file creation, modification and access times for the
 * specified file or directory, using 64-bit Windows timestamps.
 *
 * @param filename           Path to the file or directory.
 * @param creation_time      64-bit Windows FILETIME value for the
 *                           creation time of the file.
 * @param modification_time  Modification time of the file.
 * @param access_time        Last access time of the file.
 * @return                   Non-zero if set successfully.
 */

int lha_arch_set_windows_timestamps(char *filename,
                                    uint64_t creation_time,
                                    uint64_t modification_time,
                                    uint64_t access_time);
/**
 * Open a new file for writing.
 *
 * @param filename    Path to the file or directory.
 * @param unix_uid    Unix UID to set for the new file, or -1 to not set.
 * @param unix_gid    Unix GID to set for the new file, or -1 to not set.
 * @param unix_perms  Unix permissions to set for the new file, or -1 to not
 *                    set.
 * @return            Standard C file handle.
 */

FILE *lha_arch_fopen(char *filename, int unix_uid,
                     int unix_gid, int unix_perms);

/**
 * Query whether the specified file exists.
 *
 * @param filename    Path to the file.
 * @return            The type of file.
 */

LHAFileType lha_arch_exists(char *filename);

/**
 * Create a symbolic link.
 *
 * If a file already exists at the location of the link to be created, it is
 * overwritten.
 *
 * @param path        Path to the symbolic link to create.
 * @param target      Target for the symbolic link.
 * @return            Non-zero for success.
 */

int lha_arch_symlink(char *path, char *target);

#endif /* ifndef LHASA_LHA_ARCH_H */
