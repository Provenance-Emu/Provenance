/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - hle_external.h                                  *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
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

#ifndef HLE_EXTERNAL_H
#define HLE_EXTERNAL_H

#if defined(__GNUC__)
#define ATTR_FMT(fmtpos, attrpos) __attribute__ ((format (printf, fmtpos, attrpos)))
#else
#define ATTR_FMT(fmtpos, attrpos)
#endif

/* users of the hle core are expected to define these functions */

void HleVerboseMessage(void* user_defined, const char *message, ...) ATTR_FMT(2, 3);
void HleInfoMessage(void* user_defined, const char *message, ...) ATTR_FMT(2, 3);
void HleErrorMessage(void* user_defined, const char *message, ...) ATTR_FMT(2, 3);
void HleWarnMessage(void* user_defined, const char *message, ...) ATTR_FMT(2, 3);

void HleCheckInterrupts(void* user_defined);
void HleProcessDlistList(void* user_defined);
void HleProcessAlistList(void* user_defined);
void HleProcessRdpList(void* user_defined);
void HleShowCFB(void* user_defined);
int HleForwardTask(void* user_defined);

#endif

