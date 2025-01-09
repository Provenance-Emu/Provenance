/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-core - osal_files_unix.c                                  *
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

/* This file contains the definitions for the unix-specific file handling
 * functions
 */

#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "osal_files.h"

/* global functions */

#ifdef __cplusplus
extern "C"{
#endif

EXPORT int CALL osal_path_existsA(const char *path)
{
    struct stat fileinfo;
    return stat(path, &fileinfo) == 0 ? 1 : 0;
}

EXPORT int CALL osal_path_existsW(const wchar_t *_path)
{
    char path[PATH_MAX];
    wcstombs(path, _path, PATH_MAX);
    struct stat fileinfo;
    return stat(path, &fileinfo) == 0 ? 1 : 0;
}

EXPORT int CALL osal_is_directory(const wchar_t * _name)
{
    char name[PATH_MAX + 1];
    wcstombs(name, _name, PATH_MAX);
    DIR* dir;
    dir = opendir(name);
    if(dir != NULL)
    {
        closedir(dir);
        return 1;
    }
    return 0;
}

EXPORT int CALL osal_mkdirp(const wchar_t *_dirpath)
{
    char dirpath[PATH_MAX];
    wcstombs(dirpath, _dirpath, PATH_MAX);
    struct stat fileinfo;
    int dirpathlen = strlen(dirpath);
    char *currpath = strdup(dirpath);

    /* first, break the path into pieces by replacing all of the slashes wil NULL chars */
    while (strlen(currpath) > 1)
    {
        char *lastslash = strrchr(currpath, '/');
        if (lastslash == NULL)
            break;
        *lastslash = 0;
    }
    
    /* then re-assemble the path from left to right until we get to a directory that doesn't exist */
    while (strlen(currpath) < dirpathlen)
    {
        if (strlen(currpath) > 0 && stat(currpath, &fileinfo) != 0)
            break;
        currpath[strlen(currpath)] = '/';
    }

    /* then walk up the path chain, creating directories along the way */
    do
    {
        if (stat(currpath, &fileinfo) != 0)
        {
            if (mkdir(currpath, 0700) != 0)
            {
                free(currpath);
                return 1;        /* mkdir failed */
            }
        }
        if (strlen(currpath) == dirpathlen)
            break;
        else
            currpath[strlen(currpath)] = '/';
    } while (1);
    
    free(currpath);
    return 0;
}

EXPORT void * CALL osal_search_dir_open(const wchar_t *_pathname)
{
    char pathname[PATH_MAX];
    wcstombs(pathname, _pathname, PATH_MAX);
    DIR *dir;
    dir = opendir(pathname);
    return dir;
}

EXPORT const wchar_t * CALL osal_search_dir_read_next(void * dir_handle)
{
    static wchar_t last_filename[PATH_MAX];
    DIR *dir = (DIR *) dir_handle;
    struct dirent *entry;

    entry = readdir(dir);
    if (entry == NULL)
        return NULL;
    mbstowcs(last_filename, entry->d_name, PATH_MAX);
    return last_filename;
}

EXPORT void CALL osal_search_dir_close(void * dir_handle)
{
    closedir((DIR *) dir_handle);
}

#ifdef __cplusplus
}
#endif
