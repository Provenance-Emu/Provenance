/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-ui-console - osal_dynamiclib_unix.c                       *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
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

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "m64p_types.h"
#include "hle_external.h"
#include "osal_dynamiclib.h"

m64p_error osal_dynlib_open(m64p_dynlib_handle *pLibHandle, const char *pccLibraryPath)
{
    if (pLibHandle == NULL || pccLibraryPath == NULL)
        return M64ERR_INPUT_ASSERT;

    *pLibHandle = dlopen(pccLibraryPath, RTLD_NOW);

    if (*pLibHandle == NULL)
    {
        /* only print an error message if there is a directory separator (/) in the pathname */
        /* this prevents us from throwing an error for the use case where Mupen64Plus is not installed */
        if (strchr(pccLibraryPath, '/') != NULL)
            HleErrorMessage(NULL, "dlopen('%s') failed: %s", pccLibraryPath, dlerror());
        return M64ERR_INPUT_NOT_FOUND;
    }

    return M64ERR_SUCCESS;
}

void * osal_dynlib_getproc(m64p_dynlib_handle LibHandle, const char *pccProcedureName)
{
    if (pccProcedureName == NULL)
        return NULL;

    return dlsym(LibHandle, pccProcedureName);
}

m64p_error osal_dynlib_close(m64p_dynlib_handle LibHandle)
{
    int rval = dlclose(LibHandle);

    if (rval != 0)
    {
        HleErrorMessage(NULL, "dlclose() failed: %s", dlerror());
        return M64ERR_INTERNAL;
    }

    return M64ERR_SUCCESS;
}


