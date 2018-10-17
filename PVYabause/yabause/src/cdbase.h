/*  Copyright 2004-2005 Theo Berkau
    Copyright 2005 Joost Peters
    Copyright 2006 Guillaume Duhamel

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*! \file cdbase.c
    \brief Header for Dummy and ISO, BIN/CUE, MDS CD Interfaces
*/

#ifndef CDBASE_H
#define CDBASE_H

#include <stdio.h>
#include "core.h"

#define CDCORE_DEFAULT -1
#define CDCORE_DUMMY    0
#define CDCORE_ISO      1
#define CDCORE_ARCH     2

typedef struct
{
        int id;
        const char *Name;
        int (*Init)(const char *);
        void (*DeInit)(void);
        int (*GetStatus)(void);
        s32 (*ReadTOC)(u32 *TOC);
        int (*ReadSectorFAD)(u32 FAD, void *buffer);
        void (*ReadAheadFAD)(u32 FAD);
} CDInterface;

extern CDInterface DummyCD;

extern CDInterface ISOCD;

extern CDInterface ArchCD;

#endif
