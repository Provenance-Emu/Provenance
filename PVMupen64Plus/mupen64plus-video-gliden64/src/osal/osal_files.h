/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-ui-console - osal_files.h                                 *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2009 Richard Goedeken                                   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/* This header file is for all kinds of system-dependent file handling
 *
 */

#if !defined(OSAL_FILES_H)
#define OSAL_FILES_H

#ifdef __cplusplus
extern "C" {
#endif

#define OSAL_DIR_SEPARATOR_STR       L"/"
#define OSAL_DIR_SEPARATOR_CHAR      L'/'

#if defined(OS_WINDOWS)
#define EXPORT	__declspec(dllexport)
#define CALL		__cdecl
#ifndef PATH_MAX
#define PATH_MAX _MAX_PATH
#endif
#define strdup _strdup
#else  /* Not WIN32 */
#define EXPORT 	__attribute__((visibility("default")))
#define CALL
#ifndef PATH_MAX
#define PATH_MAX 260
#endif
#endif

// Returns 1 if name contains path to a directory, 0 otherwise
EXPORT int CALL osal_is_directory(const wchar_t* name);
// Returns 1 if path points to file or directory, 0 otherwise
EXPORT int CALL osal_path_existsA(const char *path);
// Returns 1 if path points to file or directory, 0 otherwise
EXPORT int CALL osal_path_existsW(const wchar_t *path);
// Returns 0 if all directories on the path exist or successfully created
// Returns 1 if path is bad
// Returns 2 if we can't create some directory on the path
EXPORT int CALL osal_mkdirp(const wchar_t *dirpath);

EXPORT void * CALL osal_search_dir_open(const wchar_t *_pathname);
EXPORT const wchar_t * CALL osal_search_dir_read_next(void * dir_handle);
EXPORT void CALL osal_search_dir_close(void * dir_handle);

#ifdef __cplusplus
}
#endif

#endif /* #define OSAL_FILES_H */

