/*  Copyright 2007 Theo Berkau
    Copyright 2009 Lawrence Sebald

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

/*! \file coffelf.c
    \brief Coff/Elf loader function.
*/

#include "core.h"
#include "debug.h"
#include "sh2core.h"
#include "yabause.h"
#include "coffelf.h"

typedef struct
{
  u8 magic[2];
  u16 numsections;
  u32 timedate;
  u32 symtabptr;
  u32 numsymtabs;
  u16 optheader;
  u16 flags;
} coff_header_struct;

typedef struct
{
  u8 magic[2];
  u16 versionstamp;
  u32 textsize;
  u32 datasize;
  u32 bsssize;
  u32 entrypoint;
  u32 textaddr;
  u32 dataaddr;
} aout_header_struct;

typedef struct
{
  s8 name[8];
  u32 physaddr;
  u32 virtaddr;
  u32 sectionsize;
  u32 sectionptr;
  u32 relptr;
  u32 linenoptr;
  u16 numreloc;
  u16 numlineno;
  u32 flags;
} section_header_struct;

typedef struct
{
  u8 ident[16];
  u16 type;
  u16 machine;
  u32 version;
  u32 entry;
  u32 phdr;
  u32 shdr;
  u32 flags;
  u16 hdrsize;
  u16 phdrsize;
  u16 phdrcount;
  u16 shdrsize;
  u16 shdrcount;
  u16 shdrstridx;
} elf_header_struct;

#define ELF_MACHINE_SH    42

typedef struct
{
  u32 name;
  u32 type;
  u32 flags;
  u32 addr;
  u32 offs;
  u32 size;
  u32 link;
  u32 inf;
  u32 align;
  u32 esize;
} elf_section_header_struct;

#define ELF_SECTION_TYPE_NODATA  8
#define ELF_SECTION_FLAG_ALLOC   2

#define WordSwap(x) x = ((x & 0xFF00) >> 8) + ((x & 0x00FF) << 8);
#define DoubleWordSwap(x) x = (((x & 0xFF000000) >> 24) + \
                              ((x & 0x00FF0000) >> 8) + \
                              ((x & 0x0000FF00) << 8) + \
                              ((x & 0x000000FF) << 24));

//////////////////////////////////////////////////////////////////////////////

int MappedMemoryLoadCoff(const char *filename)
{
   coff_header_struct coff_header;
   aout_header_struct aout_header;
   section_header_struct *section_headers=NULL;
   FILE *fp;
   u8 *buffer;
   u32 i, j;

   if ((fp = fopen(filename, "rb")) == NULL)
      return -1;

   fread((void *)&coff_header, sizeof(coff_header), 1, fp);
#ifndef WORDS_BIGENDIAN
   WordSwap(coff_header.numsections);
   DoubleWordSwap(coff_header.timedate);
   DoubleWordSwap(coff_header.timedate);
   DoubleWordSwap(coff_header.symtabptr);
   DoubleWordSwap(coff_header.numsymtabs);
   WordSwap(coff_header.optheader);
   WordSwap(coff_header.flags);
#endif

   if (coff_header.magic[0] != 0x05 || coff_header.magic[1] != 0x00 ||
       coff_header.optheader != sizeof(aout_header))
   {
      // Not SH COFF or is missing the optional header
      fclose(fp);
      return -1;
   }

   fread((void *)&aout_header, sizeof(aout_header), 1, fp);
#ifndef WORDS_BIGENDIAN
   WordSwap(aout_header.versionstamp);
   DoubleWordSwap(aout_header.textsize);
   DoubleWordSwap(aout_header.datasize);
   DoubleWordSwap(aout_header.bsssize);
   DoubleWordSwap(aout_header.entrypoint);
   DoubleWordSwap(aout_header.textaddr);
   DoubleWordSwap(aout_header.dataaddr);
#endif

   // Read in each section header
   if ((section_headers = (section_header_struct *)malloc(sizeof(section_header_struct) * coff_header.numsections)) == NULL)
   {
      fclose(fp);
      return -2;
   }

   // read in section headers
   for (i = 0; i < coff_header.numsections; i++)
   {
      fread((void *)&section_headers[i], sizeof(section_header_struct), 1, fp);
#ifndef WORDS_BIGENDIAN
      DoubleWordSwap(section_headers[i].physaddr);
      DoubleWordSwap(section_headers[i].virtaddr);
      DoubleWordSwap(section_headers[i].sectionsize);
      DoubleWordSwap(section_headers[i].sectionptr);
      DoubleWordSwap(section_headers[i].relptr);
      DoubleWordSwap(section_headers[i].linenoptr);
      WordSwap(section_headers[i].numreloc);
      WordSwap(section_headers[i].numlineno);
      DoubleWordSwap(section_headers[i].flags);
#endif
   }

   YabauseResetNoLoad();

   // Setup the vector table area, etc.
   YabauseSpeedySetup();

   // Read in sections, load them to ram
   for (i = 0; i < coff_header.numsections; i++)
   {
      if (section_headers[i].sectionsize == 0 ||
          section_headers[i].sectionptr == 0)
         // Skip to the next section
         continue;
      
      if ((buffer = (u8 *)malloc(section_headers[i].sectionsize)) == NULL)
      {
         fclose(fp);
         free(section_headers);
         return -2;
      }

      fseek(fp, section_headers[i].sectionptr, SEEK_SET);
      fread((void *)buffer, 1, section_headers[i].sectionsize, fp);

      for (j = 0; j < section_headers[i].sectionsize; j++)
         MappedMemoryWriteByte(section_headers[i].physaddr+j, buffer[j]);
      SH2WriteNotify(section_headers[i].physaddr,
                     section_headers[i].sectionsize);

      free(buffer);
   }

   // Clean up
   free(section_headers);
   fclose(fp);

   SH2GetRegisters(MSH2, &MSH2->regs);
   MSH2->regs.PC = aout_header.entrypoint;
   SH2SetRegisters(MSH2, &MSH2->regs);
   return 0;
}


//////////////////////////////////////////////////////////////////////////////

int MappedMemoryLoadElf(const char *filename)
{
   elf_header_struct elf_hdr;
   elf_section_header_struct *sections = NULL;
   FILE *fp;
   u16 i;
   u32 j;
   u8 *buffer;

   fp = fopen(filename, "rb");

   if(fp == NULL)
      return -1;

   fread(&elf_hdr, sizeof(elf_header_struct), 1, fp);

   if(elf_hdr.ident[0] != 0x7F || elf_hdr.ident[1] != 'E' ||
      elf_hdr.ident[2] != 'L' || elf_hdr.ident[3] != 'F' ||
      elf_hdr.ident[4] != 1)
   {
      /* Doesn't appear to be a valid ELF file. */
      fclose(fp);
      return -1;
   }
   
   if(elf_hdr.ident[5] != 2)
   {
      /* Doesn't appear to be a big-endian file. */
      fclose(fp);
      return -1;
   }

#ifndef WORDS_BIGENDIAN
   WordSwap(elf_hdr.type);
   WordSwap(elf_hdr.machine);
   DoubleWordSwap(elf_hdr.version);
   DoubleWordSwap(elf_hdr.entry);
   DoubleWordSwap(elf_hdr.phdr);
   DoubleWordSwap(elf_hdr.shdr);
   DoubleWordSwap(elf_hdr.flags);
   WordSwap(elf_hdr.hdrsize);
   WordSwap(elf_hdr.phdrsize);
   WordSwap(elf_hdr.phdrcount);
   WordSwap(elf_hdr.shdrsize);
   WordSwap(elf_hdr.shdrcount);
   WordSwap(elf_hdr.shdrstridx);
#endif

   LOG("Loading ELF file %s\n", filename);
   LOG("Type: %d\n", elf_hdr.type);
   LOG("Machine code: %d\n", elf_hdr.machine);
   LOG("Version: %d\n", elf_hdr.version);
   LOG("Entry point: 0x%08X\n", elf_hdr.entry);
   LOG("Program header offset: %d\n", elf_hdr.phdr);
   LOG("Section header offset: %d\n", elf_hdr.shdr);
   LOG("Flags: %d\n", elf_hdr.flags);
   LOG("ELF Header Size: %d\n", elf_hdr.hdrsize);
   LOG("Program header size: %d\n", elf_hdr.phdrsize);
   LOG("Program header count: %d\n", elf_hdr.phdrcount);
   LOG("Section header size: %d\n", elf_hdr.shdrsize);
   LOG("Section header count: %d\n", elf_hdr.shdrcount);
   LOG("String table section: %d\n", elf_hdr.shdrstridx);

   if(elf_hdr.machine != ELF_MACHINE_SH)
   {
      /* Not a SuperH ELF file. */
      fclose(fp);
      return -1;
   }

   /* Allocate space for the section headers. */
   sections =
      (elf_section_header_struct *)malloc(sizeof(elf_section_header_struct) *
                                          elf_hdr.shdrcount);
   if(sections == NULL)
   {
      fclose(fp);
      return -2;
   }

   /* Look at the actual section headers. */
   fseek(fp, elf_hdr.shdr, SEEK_SET);

   /* Read in each section header. */
   for(i = 0; i < elf_hdr.shdrcount; ++i)
   {
      fread(sections + i, sizeof(elf_section_header_struct), 1, fp);
#ifndef WORDS_BIGENDIAN
      DoubleWordSwap(sections[i].name);
      DoubleWordSwap(sections[i].type);
      DoubleWordSwap(sections[i].flags);
      DoubleWordSwap(sections[i].addr);
      DoubleWordSwap(sections[i].offs);
      DoubleWordSwap(sections[i].size);
      DoubleWordSwap(sections[i].link);
      DoubleWordSwap(sections[i].inf);
      DoubleWordSwap(sections[i].align);
      DoubleWordSwap(sections[i].esize);
#endif

      LOG("Section header %d:\n", i);
      LOG("Name index: %d\n", sections[i].name);
      LOG("Type: %d\n", sections[i].type);
      LOG("Flags: 0x%X\n", sections[i].flags);
      LOG("In-memory address: 0x%08X\n", sections[i].addr);
      LOG("In-file offset: %d\n", sections[i].offs);
      LOG("Size: %d\n", sections[i].size);
      LOG("Link field: %d\n", sections[i].link);
      LOG("Info field: %d\n", sections[i].inf);
      LOG("Alignment: %d\n", sections[i].align);
      LOG("Entry size: %d\n", sections[i].esize);
   }

   YabauseResetNoLoad();

   /* Set up the vector table area, etc. */
   YabauseSpeedySetup();

   /* Read in the sections and load them to RAM. */
   for(i = 0; i < elf_hdr.shdrcount; ++i)
   {
      /* Does the header request actual storage for this section? */
      if(sections[i].flags & ELF_SECTION_FLAG_ALLOC)
      {
         /* Check if the section contains data, or if its just a marker for a
            section of zero bytes. */
         if(sections[i].type == ELF_SECTION_TYPE_NODATA)
         {
            for(j = 0; j < sections[i].size; ++j)
            {
               MappedMemoryWriteByte(sections[i].addr + j, 0);
            }
         }
         else
         {
            buffer = (u8 *)malloc(sections[i].size);

            if(buffer == NULL)
            {
               fclose(fp);
               free(sections);
               return -2;
            }

            fseek(fp, sections[i].offs, SEEK_SET);
            fread(buffer, 1, sections[i].size, fp);

            for(j = 0; j < sections[i].size; ++j)
            {
               MappedMemoryWriteByte(sections[i].addr + j, buffer[j]);
            }

            free(buffer);
         }
      }
   }

   /* Clean up. */
   free(sections);
   fclose(fp);

   /* Set up our entry point. */
   SH2GetRegisters(MSH2, &MSH2->regs);
   MSH2->regs.PC = elf_hdr.entry;
   SH2SetRegisters(MSH2, &MSH2->regs);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////
