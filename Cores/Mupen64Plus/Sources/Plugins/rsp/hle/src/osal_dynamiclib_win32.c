/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-ui-console - osal_dynamiclib_win32.c                      *
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

#include <stdio.h>
#include <stdlib.h>
#include <windows.h>

#include "m64p_types.h"
#include "hle_external.h"
#include "osal_dynamiclib.h"

m64p_error osal_dynlib_open(m64p_dynlib_handle *pLibHandle, const char *pccLibraryPath)
{
    if (pLibHandle == NULL || pccLibraryPath == NULL)
        return M64ERR_INPUT_ASSERT;

    *pLibHandle = LoadLibrary(pccLibraryPath);

    if (*pLibHandle == NULL)
    {
        char *pchErrMsg;
        DWORD dwErr = GetLastError();
        FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM, NULL, dwErr,
                      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPTSTR) &pchErrMsg, 0, NULL);
        HleErrorMessage(NULL, "LoadLibrary('%s') error: %s", pccLibraryPath, pchErrMsg);
        LocalFree(pchErrMsg);
        return M64ERR_INPUT_NOT_FOUND;
    }

    return M64ERR_SUCCESS;
}

void * osal_dynlib_getproc(m64p_dynlib_handle LibHandle, const char *pccProcedureName)
{
    if (pccProcedureName == NULL)
        return NULL;

    return GetProcAddress(LibHandle, pccProcedureName);
}

m64p_error osal_dynlib_close(m64p_dynlib_handle LibHandle)
{
    int rval = FreeLibrary(LibHandle);

    if (rval == 0)
    {
        char *pchErrMsg;
        DWORD dwErr = GetLastError();
        FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM, NULL, dwErr,
                      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPTSTR) &pchErrMsg, 0, NULL);
        HleErrorMessage(NULL, "FreeLibrary() error: %s", pchErrMsg);
        LocalFree(pchErrMsg);
        return M64ERR_INTERNAL;
    }

    return M64ERR_SUCCESS;
}
