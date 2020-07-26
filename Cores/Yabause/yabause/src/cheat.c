/*  Copyright 2007-2008 Theo Berkau

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
    \brief Cheat engine to apply codes to SH2 addresses
*/

#include <stdlib.h>
#include "cheat.h"
#include "memory.h"
#include "sh2core.h"

cheatlist_struct *cheatlist=NULL;
int numcheats=0;
int cheatsize;

#define DoubleWordSwap(x) x = (((x & 0xFF000000) >> 24) + \
                              ((x & 0x00FF0000) >> 8) + \
                              ((x & 0x0000FF00) << 8) + \
                              ((x & 0x000000FF) << 24));

//////////////////////////////////////////////////////////////////////////////

int CheatInit(void)
{  
   cheatsize = 10;
   if ((cheatlist = (cheatlist_struct *)calloc(cheatsize, sizeof(cheatlist_struct))) == NULL)
      return -1;
   cheatlist[0].type = CHEATTYPE_NONE;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void CheatDeInit(void)
{  
   if (cheatlist)
      free(cheatlist);
   cheatlist = NULL;
}

//////////////////////////////////////////////////////////////////////////////

int CheatAddCode(int type, u32 addr, u32 val)
{
   if (cheatlist == NULL)
      return -1;

   cheatlist[numcheats].type = type;
   cheatlist[numcheats].addr = addr;
   cheatlist[numcheats].val = val;
   cheatlist[numcheats].desc = NULL;
   cheatlist[numcheats].enable = 1;
   numcheats++;

   // Make sure we still have room
   if (numcheats >= cheatsize)
   {
      cheatlist = realloc(cheatlist, sizeof(cheatlist_struct) * (cheatsize * 2));
      cheatsize *= 2;
   }

   cheatlist[numcheats].type = CHEATTYPE_NONE;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int CheatAddARCode(const char *code)
{
   unsigned long addr;
   unsigned short val;
   sscanf(code, "%08lX %04hX", &addr, &val);
   switch (addr >> 28)
   {
      case 0x0:
         // One time word write(fix me)
         return -1;
      case 0x1:
         return CheatAddCode(CHEATTYPE_WORDWRITE, addr & 0x0FFFFFFF, val);
      case 0x3:
         return CheatAddCode(CHEATTYPE_BYTEWRITE, addr & 0x0FFFFFFF, val);
      case 0xD:
         return CheatAddCode(CHEATTYPE_ENABLE, addr & 0x0FFFFFFF, val);
      default: return -1;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int FindCheat(int type, u32 addr, u32 val)
{
   int i;

   for (i = 0; i < numcheats; i++)
   {
      if (cheatlist[i].type == type &&
          cheatlist[i].addr == addr &&
          cheatlist[i].val == val)
         return i;
   }

   return -1;
}

//////////////////////////////////////////////////////////////////////////////

int CheatChangeDescription(int type, u32 addr, u32 val, char *desc)
{
   int i;

   if ((i = FindCheat(type, addr, val)) == -1)
      // There is no matches, so let's bail
      return -1;

   return CheatChangeDescriptionByIndex(i, desc);
}

//////////////////////////////////////////////////////////////////////////////

int CheatChangeDescriptionByIndex(int i, char *desc)
{
   // Free old description(if existing)
   if (cheatlist[i].desc)
      free(cheatlist[i].desc);

   cheatlist[i].desc = strdup(desc);
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int CheatRemoveCode(int type, u32 addr, u32 val)
{
   int i;

   if ((i = FindCheat(type, addr, val)) == -1)
      // There is no matches, so let's bail
      return -1;

   return CheatRemoveCodeByIndex(i);
}

//////////////////////////////////////////////////////////////////////////////

int CheatRemoveCodeByIndex(int i)
{
   // If there's a description, free the memory.
   if (cheatlist[i].desc)
   {
      free(cheatlist[i].desc);
      cheatlist[i].desc = NULL;
   }

   // Move all entries one forward
   for (; i < numcheats-1; i++)
      memcpy(&cheatlist[i], &cheatlist[i+1], sizeof(cheatlist_struct));

   numcheats--;

   // Set the last one to type none
   cheatlist[numcheats].type = CHEATTYPE_NONE;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int CheatRemoveARCode(const char *code)
{
   unsigned long addr;
   unsigned short val;
   sscanf(code, "%08lX %04hX", &addr, &val);

   switch (addr >> 28)
   {
      case 0x1:
         return CheatRemoveCode(CHEATTYPE_WORDWRITE, addr & 0x0FFFFFFF, val);
      case 0x3:
         return CheatRemoveCode(CHEATTYPE_BYTEWRITE, addr & 0x0FFFFFFF, val);
      case 0xD:
         return CheatRemoveCode(CHEATTYPE_ENABLE, addr & 0x0FFFFFFF, val);
      default: return -1;
   }
}

//////////////////////////////////////////////////////////////////////////////

void CheatClearCodes(void)
{
   while (numcheats > 0)
      CheatRemoveCodeByIndex(numcheats-1);
}

//////////////////////////////////////////////////////////////////////////////

void CheatEnableCode(int index)
{
   cheatlist[index].enable = 1;
}

//////////////////////////////////////////////////////////////////////////////

void CheatDisableCode(int index)
{
   cheatlist[index].enable = 0;
}

//////////////////////////////////////////////////////////////////////////////

void CheatDoPatches(void)
{
   int i;

   for (i = 0; ; i++)
   {
      switch (cheatlist[i].type)
      {
         case CHEATTYPE_NONE:
            return;
         case CHEATTYPE_ENABLE:
            if (cheatlist[i].enable == 0)
               continue;
            if (MappedMemoryReadWord(cheatlist[i].addr) != cheatlist[i].val)
               return;
            break;
         case CHEATTYPE_BYTEWRITE:
            if (cheatlist[i].enable == 0)
               continue;
            MappedMemoryWriteByte(cheatlist[i].addr, (u8)cheatlist[i].val);
            SH2WriteNotify(cheatlist[i].addr, 1);
            break;
         case CHEATTYPE_WORDWRITE:
            if (cheatlist[i].enable == 0)
               continue;
            MappedMemoryWriteWord(cheatlist[i].addr, (u16)cheatlist[i].val);
            SH2WriteNotify(cheatlist[i].addr, 2);
            break;
         case CHEATTYPE_LONGWRITE:
            if (cheatlist[i].enable == 0)
               continue;
            MappedMemoryWriteLong(cheatlist[i].addr, cheatlist[i].val);
            SH2WriteNotify(cheatlist[i].addr, 4);
            break;            
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

cheatlist_struct *CheatGetList(int *cheatnum)
{
   if (cheatnum == NULL)
      return NULL;

   *cheatnum = numcheats;
   return cheatlist;
}

//////////////////////////////////////////////////////////////////////////////

int CheatSave(const char *filename)
{
   FILE *fp;
   int i;
   int num;
   IOCheck_struct check = { 0, 0 };

   if (!filename)
      return -1;

   if ((fp = fopen(filename, "wb")) == NULL)
      return -1;

   fprintf(fp, "YCHT");
   num = numcheats;
#ifndef WORDS_BIGENDIAN
   DoubleWordSwap(num);
#endif
   ywrite(&check, (void *)&num, sizeof(int), 1, fp);

   for(i = 0; i < numcheats; i++)
   {
      u8 descsize;
      cheatlist_struct cheat;

      memcpy(&cheat, &cheatlist[i], sizeof(cheatlist_struct));
#ifndef WORDS_BIGENDIAN
      DoubleWordSwap(cheat.type);
      DoubleWordSwap(cheat.addr);
      DoubleWordSwap(cheat.val);
      DoubleWordSwap(cheat.enable);
#endif
      ywrite(&check, (void *)&cheat.type, sizeof(int), 1, fp);
      ywrite(&check, (void *)&cheat.addr, sizeof(u32), 1, fp);
      ywrite(&check, (void *)&cheat.val, sizeof(u32), 1, fp);
      descsize = (u8)strlen(cheatlist[i].desc)+1;
      ywrite(&check, (void *)&descsize, sizeof(u8), 1, fp);
      ywrite(&check, (void *)cheatlist[i].desc, sizeof(char), descsize, fp);
      ywrite(&check, (void *)&cheat.enable, sizeof(int), 1, fp);
   }

   fclose (fp);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int CheatLoad(const char *filename)
{
   FILE *fp;
   int i;
   char id[4];
   char desc[256];
   IOCheck_struct check = { 0, 0 };

   if (!filename)
      return -1;

   if ((fp = fopen(filename, "rb")) == NULL)
      return -1;

   yread(&check, (void *)id, 1, 4, fp);
   if (strncmp(id, "YCHT", 4) != 0)
   {
      fclose(fp);
      return -2;
   }

   CheatClearCodes();

   yread(&check, (void *)&numcheats, sizeof(int), 1, fp);
#ifndef WORDS_BIGENDIAN
   DoubleWordSwap(numcheats);
#endif

   if (numcheats >= cheatsize)
   {
      cheatlist = realloc(cheatlist, sizeof(cheatlist_struct) * (cheatsize * 2));
      memset((void *)cheatlist, 0, sizeof(cheatlist_struct) * (cheatsize * 2));
      cheatsize *= 2;
   }

   for(i = 0; i < numcheats; i++)
   {
      u8 descsize;

      yread(&check, (void *)&cheatlist[i].type, sizeof(int), 1, fp);
      yread(&check, (void *)&cheatlist[i].addr, sizeof(u32), 1, fp);
      yread(&check, (void *)&cheatlist[i].val, sizeof(u32), 1, fp);
      yread(&check, (void *)&descsize, sizeof(u8), 1, fp);
      yread(&check, (void *)desc, sizeof(char), descsize, fp);
      CheatChangeDescriptionByIndex(i, desc);
      yread(&check, (void *)&cheatlist[i].enable, sizeof(int), 1, fp);
#ifndef WORDS_BIGENDIAN
      DoubleWordSwap(cheatlist[i].type);
      DoubleWordSwap(cheatlist[i].addr);
      DoubleWordSwap(cheatlist[i].val);
      DoubleWordSwap(cheatlist[i].enable);
#endif
   }

   fclose (fp);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

