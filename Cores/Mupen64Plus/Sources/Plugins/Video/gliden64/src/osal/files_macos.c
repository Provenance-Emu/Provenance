/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-core - osal/files_macos.c                                 *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2017 Richard Goedeken                                   *
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

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sysdir.h>
#include <pwd.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "files.h"

/* OS X code for app bundle handling */
#include <CoreFoundation/CoreFoundation.h>

// dynamic data path detection onmac
bool macSetBundlePath(char* buffer)
{
    // the following code will enable mupen to find its data when placed in an app bundle on mac OS X.
    // returns true if path is set, returns false if path was not set
    char path[1024] = { 0 };
    CFBundleRef main_bundle = CFBundleGetMainBundle(); assert(main_bundle);
    CFURLRef main_bundle_URL = CFBundleCopyBundleURL(main_bundle); assert(main_bundle_URL);
    CFStringRef cf_string_ref = CFURLCopyFileSystemPath( main_bundle_URL, kCFURLPOSIXPathStyle); assert(cf_string_ref);
    CFStringGetCString(cf_string_ref, path, 1024, kCFStringEncodingASCII);
    CFRelease(main_bundle_URL);
    CFRelease(cf_string_ref);
    
    if (strstr( path, ".app" ) != 0)
    {
        DebugMessage(M64MSG_VERBOSE, "checking whether we are using an app bundle: yes");
        // executable is inside an app bundle, use app bundle-relative paths
        sprintf(buffer, "%s/Contents/Resources/", path);
        return true;
    }
    else
    {
        DebugMessage(M64MSG_VERBOSE, "checking whether we are using an app bundle: no");
        return false;
    }
}


/* definitions for system directories to search when looking for shared data files */
#if defined(SHAREDIR)
  #define XSTR(S) STR(S) /* this wacky preprocessor thing is necessary to generate a quote-enclosed */
  #define STR(S) #S      /* copy of the SHAREDIR macro, which is defined by the makefile via gcc -DSHAREDIR="..." */
  static const int   datasearchdirs = 2;
  static const char *datasearchpath[2] = { XSTR(SHAREDIR), "./" };
  #undef STR
  #undef XSTR
#else
  static const int   datasearchdirs = 1;
  static const char *datasearchpath[1] = {  "./" };
#endif

/* local functions */
static int search_dir_file(char *destpath, const char *path, const char *filename)
{
    struct stat fileinfo;

    /* sanity check to start */
    if (destpath == NULL || path == NULL || filename == NULL)
        return 1;

    /* build the full filepath */
    strcpy(destpath, path);
    /* if the path is empty, don't add / between it and the file name */
    if (destpath[0] != '\0' && destpath[strlen(destpath)-1] != '/')
        strcat(destpath, "/");
    strcat(destpath, filename);

    /* test for a valid file */
    if (stat(destpath, &fileinfo) != 0)
        return 2;
    if (!S_ISREG(fileinfo.st_mode))
        return 3;

    /* success - file exists and is a regular file */
    return 0;
}

/* global functions */

int osal_mkdirp(const char *dirpath, int mode)
{
    char *mypath, *currpath;
    struct stat fileinfo;

    // Terminate quickly if the path already exists
    if (stat(dirpath, &fileinfo) == 0 && S_ISDIR(fileinfo.st_mode))
        return 0;

    // Create partial paths
    mypath = currpath = strdup(dirpath);
    if (mypath == NULL)
        return 1;

    while ((currpath = strpbrk(currpath + 1, OSAL_DIR_SEPARATORS)) != NULL)
    {
        *currpath = '\0';
        if (stat(mypath, &fileinfo) != 0)
        {
            if (mkdir(mypath, mode) != 0)
                break;
        }
        else
        {
            if (!S_ISDIR(fileinfo.st_mode))
                break;
        }
        *currpath = OSAL_DIR_SEPARATORS[0];
    }
    free(mypath);
    if (currpath != NULL)
        return 1;

    // Create full path
    if (stat(dirpath, &fileinfo) != 0 && mkdir(dirpath, mode) != 0)
        return 1;

    return 0;
}

const char * osal_get_shared_filepath(const char *filename, const char *firstsearch, const char *secondsearch)
{
    static char retpath[PATH_MAX];
    int i;

    /* if caller gave us any directories to search, then look there first */
    if (firstsearch != NULL && search_dir_file(retpath, firstsearch, filename) == 0)
        return retpath;
    if (secondsearch != NULL && search_dir_file(retpath, secondsearch, filename) == 0)
        return retpath;

    /* Special case : OS X bundles */
    char buf[1024] = { 0 };
    if (macSetBundlePath(buf))
    {
        if (search_dir_file(retpath, buf, filename) == 0)
            return retpath;
    }

    /* otherwise check our standard paths */
    for (i = 0; i < datasearchdirs; i++)
    {
        if (search_dir_file(retpath, datasearchpath[i], filename) == 0)
            return retpath;
    }

    /* we couldn't find the file */
    return NULL;
}

const char * osal_get_user_configpath(void)
{
    static char path[1024] = { 0 };
    
    if (getenv("HOME") != NULL)
    {
        strcpy(path, getenv("HOME"));
    }
    else
    {
        struct passwd* pwd = getpwuid(getuid());
        
        if (pwd)
            strcpy(path, pwd->pw_dir);
    }
    
    /* append the given sub-directory to the path given by the environment variable */
    if (path[strlen(path)-1] != '/')
        strcat(path, "/");
    strcat(path, "Library/Application Support/Mupen64Plus/");

    /* try to create the resulting directory tree, or return successfully if it already exists */
    if (osal_mkdirp(path, 0700) != 0)
    {
        DebugMessage(M64MSG_ERROR, "Couldn't create directory: %s", path);
        DebugMessage(M64MSG_ERROR, "Failed to get configuration directory; Path is undefined or invalid.");
        return NULL;
    }
    
    return path;
}

const char * osal_get_user_datapath(void)
{
    // in macOS, these are all the same
    return osal_get_user_configpath();
}

const char * osal_get_user_cachepath(void)
{
    // in macOS, these are all the same
    return osal_get_user_configpath();
}

