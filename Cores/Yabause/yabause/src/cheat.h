/*  Copyright 2007 Theo Berkau

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

/*! \file cheat.c
    \brief Header for cheat engine to apply codes to SH2 addresses
*/

#ifndef CHEAT_H
#define CHEAT_H

#include "core.h"

enum
{
   CHEATTYPE_NONE=0,
   CHEATTYPE_ENABLE,
   CHEATTYPE_BYTEWRITE,
   CHEATTYPE_WORDWRITE,
   CHEATTYPE_LONGWRITE
};

typedef struct
{
   int type;
   u32 addr;
   u32 val;
   char *desc;
   int enable;
} cheatlist_struct;

int CheatInit(void);
void CheatDeInit(void);
int CheatAddCode(int type, u32 addr, u32 val);
int CheatAddARCode(const char *code);
int CheatChangeDescription(int type, u32 addr, u32 val, char *desc);
int CheatChangeDescriptionByIndex(int i, char *desc);
int CheatRemoveCode(int type, u32 addr, u32 val);
int CheatRemoveCodeByIndex(int i);
int CheatRemoveARCode(const char *code);
void CheatClearCodes(void);
void CheatEnableCode(int index);
void CheatDisableCode(int index);
void CheatDoPatches(void);
cheatlist_struct *CheatGetList(int *cheatnum);
int CheatSave(const char *filename);
int CheatLoad(const char *filename);

#endif
