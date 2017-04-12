/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 The ugly kludges with the strcasecmp(MDFNGameInfo->shortname, "psx") are to work around the mess created by our
 flawed game ID generation code(the PS1 game library is enormous, and many games only have one track, leading to many collisions);
 TODO: a more permanent, system-agnostic solution to the problem.
*/

#include "mednafen.h"

#include <string.h>
#include <ctype.h>
#include <trio/trio.h>
#include <errno.h>
#include <vector>

#include "general.h"
#include "string/trim.h"
#include <mednafen/hash/md5.h>
#include "mempatcher.h"
#include "FileStream.h"
#include "MemoryStream.h"

MemoryPatch::MemoryPatch() : addr(0), val(0), compare(0), 
			     mltpl_count(1), mltpl_addr_inc(0), mltpl_val_inc(0), copy_src_addr(0), copy_src_addr_inc(0),
			     length(0), bigendian(false), status(false), icount(0), type(0)
{

}

MemoryPatch::~MemoryPatch()
{

}

static uint8 **RAMPtrs = NULL;
static bool* RAMUseInSearch = NULL;
static uint32 PageSize;
static uint32 NumPages;

typedef struct
{
 bool excluded;
 uint8 value; 
} CompareStruct;

typedef MemoryPatch CHEATF;
#if 0
typedef struct __CHEATF
{
           char *name;
           char *conditions;

           uint32 addr;
           uint64 val;
           uint64 compare;

           unsigned int length;
           bool bigendian;
           unsigned int icount; // Instance count
           char type;   /* 'R' for replace, 'S' for substitute(GG), 'C' for substitute with compare */
           int status;
} CHEATF;
#endif

static std::vector<CHEATF> cheats;
static bool savecheats;
static CompareStruct **CheatComp = NULL;
static uint32 resultsbytelen = 1;
static bool resultsbigendian = 0;
static bool CheatsActive = TRUE;

bool SubCheatsOn = 0;
std::vector<SUBCHEAT> SubCheats[8];

static void RebuildSubCheats(void)
{
 std::vector<CHEATF>::iterator chit;

 SubCheatsOn = 0;
 for(int x = 0; x < 8; x++)
  SubCheats[x].clear();

 if(!CheatsActive) return;

 for(chit = cheats.begin(); chit != cheats.end(); chit++)
 {
  if(chit->status && (chit->type == 'S' || chit->type == 'C'))
  {
   for(unsigned int x = 0; x < chit->length; x++)
   {
    SUBCHEAT tmpsub;
    unsigned int shiftie;

    if(chit->bigendian)
     shiftie = (chit->length - 1 - x) * 8;
    else
     shiftie = x * 8;
    
    tmpsub.addr = chit->addr + x;
    tmpsub.value = (chit->val >> shiftie) & 0xFF;
    if(chit->type == 'C')
     tmpsub.compare = (chit->compare >> shiftie) & 0xFF;
    else
     tmpsub.compare = -1;
    SubCheats[(chit->addr + x) & 0x7].push_back(tmpsub);
    SubCheatsOn = 1;
   }
  }
 }
}

bool MDFNMP_Init(uint32 ps, uint32 numpages)
{
 PageSize = ps;
 NumPages = numpages;

 RAMPtrs = (uint8 **)calloc(numpages, sizeof(uint8 *));
 RAMUseInSearch = (bool*)calloc(numpages, sizeof(bool));

 CheatComp = (CompareStruct **)calloc(numpages, sizeof(CompareStruct *));

 CheatsActive = MDFN_GetSettingB("cheats");
 return(1);
}

void MDFNMP_Kill(void)
{
 if(CheatComp)
 {
  free(CheatComp);
  CheatComp = NULL;
 }

 if(RAMPtrs)
 {
  free(RAMPtrs);
  RAMPtrs = NULL;
 }

 if(RAMUseInSearch)
 {
  free(RAMUseInSearch);
  RAMUseInSearch = NULL;
 }
}


void MDFNMP_AddRAM(uint32 size, uint32 A, uint8 *RAM, bool use_in_search)
{
 //printf("%02x:%04x, %16llx, %d\n", A >> 16, A & 0xFFFF, (unsigned long long)RAM, use_in_search);

 uint32 AB = A / PageSize;
 
 size /= PageSize;

 for(unsigned int x = 0; x < size; x++)
 {
  RAMPtrs[AB + x] = RAM;
  RAMUseInSearch[AB + x] = use_in_search;

  if(RAM) // Don't increment the RAM pointer if we're passed a NULL pointer
   RAM += PageSize;
 }
}

void MDFNMP_InstallReadPatches(void)
{
 if(!CheatsActive) return;

 std::vector<SUBCHEAT>::iterator chit;

 for(unsigned int x = 0; x < 8; x++)
  for(chit = SubCheats[x].begin(); chit != SubCheats[x].end(); chit++)
  {
   if(MDFNGameInfo->InstallReadPatch)
    MDFNGameInfo->InstallReadPatch(chit->addr, chit->value, chit->compare);
  }
}

void MDFNMP_RemoveReadPatches(void)
{
 if(MDFNGameInfo->RemoveReadPatches)
  MDFNGameInfo->RemoveReadPatches();
}

static bool SeekToOurSection(Stream* fp) // Tentacle monster section aisle five, stale eggs and donkeys in aisle 2E.
{
 std::string linebuf;

 linebuf.reserve(1024);

 while(fp->get_line(linebuf) >= 0)
 {
  if(linebuf.size() >= 1 && linebuf[0] == '[')
  {
   if(!strncmp(linebuf.c_str() + 1, md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str(), 32) &&
	(strcasecmp(MDFNGameInfo->shortname, "psx") || linebuf.size() < 36 || !MDFNGameInfo->name || linebuf[34] != ' ' || !strcmp(linebuf.c_str() + 35, MDFNGameInfo->name)))
    return(true);
  }
 }
 return(false);
}

void MDFN_LoadGameCheats(Stream* override)
{
 Stream* fp = NULL;
 int tc = 0;
 std::string fn = MDFN_MakeFName(MDFNMKF_CHEAT,0,0);

 if(!override)
 {
  MDFN_printf("\n");
  MDFN_printf(_("Loading cheats from %s...\n"), fn.c_str());
  MDFN_indent(1);
 }

 savecheats = false;

 //unsigned st = MDFND_GetTime();
 try
 {
  if(override)
   fp = override;
  else
   fp = /*new MemoryStream(*/new FileStream(fn, FileStream::MODE_READ)/*)*/;

  if(SeekToOurSection(fp))
  {
   std::string linebuf;

   linebuf.reserve(1024);

   while(fp->get_line(linebuf) >= 0)
   {
    std::string tbuf = linebuf;
    std::string name;
    std::string conditions;
    bool ext_format = false;
    unsigned int addr = 0;
    unsigned long long val = 0;
    unsigned int status = 0;
    char type = 0;
    unsigned long long compare = 0;
    unsigned int length = 0;
    unsigned int icount = 0;
    bool bigendian = false;

    unsigned mltpl_count = 1;
    unsigned mltpl_addr_inc = 0;
    unsigned long long mltpl_val_inc = 0;

    unsigned copy_src_addr = 0;
    unsigned copy_src_addr_inc = 0;

    if(tbuf.size() >= 1 && tbuf[0] == '[') // No more cheats for this game, so sad :(
     break;

    MDFN_trim(tbuf);

    if(tbuf.size() >= 1 && tbuf[0] == '!')
    {
     ext_format = true;
     tbuf = tbuf.substr(1);
     MDFN_trim(tbuf);
    }

    if(!tbuf.size()) // Don't parse if the line is empty.
     continue;

    type = tbuf[0];

    if(type != 'R' && type != 'C' && type != 'S' && type != 'T' && type != 'A')
     throw MDFN_Error(0, _("Invalid cheat type: %c\n"), tbuf[0]);

    //
    //
    //
    char status_tmp, endian_tmp;
    int name_position = 0;

    if(type == 'C')
     trio_sscanf(tbuf.c_str(), "%c %c %d %c %d %08x %16llx %16llx %n", &type, &status_tmp, &length, &endian_tmp, &icount, &addr, &val, &compare, &name_position);
    else
    {
     if(ext_format)
      trio_sscanf(tbuf.c_str(), "%c %c %d %c %d %08x %016llx %08x %08x %016llx %08x %08x %n", &type, &status_tmp, &length, &endian_tmp, &icount, &addr, &val, &mltpl_count, &mltpl_addr_inc, &mltpl_val_inc, &copy_src_addr, &copy_src_addr_inc, &name_position);
     else
      trio_sscanf(tbuf.c_str(), "%c %c %d %c %d %08x %16llx %n", &type, &status_tmp, &length, &endian_tmp, &icount, &addr, &val, &name_position);
    }

    status = (status_tmp == 'A') ? 1 : 0;
    bigendian = (endian_tmp == 'B') ? 1 : 0;

    //
    // Grab the name.
    //
    name = linebuf.substr(name_position);

    for(unsigned i = 0; i < name.size(); i++)
     if(name[i] < 0x20)
      name[i] = ' ';

    MDFN_trim(name);

    //
    // Grab the conditions.
    //
    if(fp->get_line(linebuf) >= 0)
    {
     conditions = linebuf;

     for(unsigned i = 0; i < conditions.size(); i++)
      if(conditions[i] < 0x20)
       conditions[i] = ' ';

     MDFN_trim(conditions);
    }

    {
     CHEATF temp;

     temp.name = name;
     temp.conditions = conditions;
     temp.addr = addr;
     temp.val = val;
     temp.status = status;
     temp.compare = compare;
     temp.length = length;
     temp.bigendian = bigendian;
     temp.type = type;

     temp.mltpl_count = mltpl_count;
     temp.mltpl_addr_inc = mltpl_addr_inc;
     temp.mltpl_val_inc = mltpl_val_inc;

     temp.copy_src_addr = copy_src_addr;
     temp.copy_src_addr_inc = copy_src_addr_inc;

     cheats.push_back(temp);
    }
    tc++;
   }
  }

  RebuildSubCheats();

  if(!override)
  {
   MDFN_printf(_("%lu cheats loaded.\n"), (unsigned long)cheats.size());
   MDFN_indent(-1);
   delete fp;
   fp = NULL;
  }
 }
 catch(std::exception &e)
 {
  MDFN_printf("%s\n", e.what());
  MDFN_indent(-1);

  if(fp != NULL)
  {
   delete fp;
   fp = NULL;
  }
 }

 //printf("%u\n", MDFND_GetTime() - st);
}

static void WriteCheatsSection(Stream* tmp_fp, bool needheader)
{
     if(needheader)
      tmp_fp->print_format("[%s] %s\n", md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str(), MDFNGameInfo->name ? (char *)MDFNGameInfo->name : "");

     std::vector<CHEATF>::iterator next;

     for(next = cheats.begin(); next != cheats.end(); next++)
     {
      if(next->type == 'C')
      {
       if(next->length == 1)
        tmp_fp->print_format("%c %c %d %c %d %08x %02llx %02llx %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, (unsigned long long)next->compare, next->name.c_str());
       else if(next->length == 2)
        tmp_fp->print_format("%c %c %d %c %d %08x %04llx %04llx %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, (unsigned long long)next->compare, next->name.c_str());
       else
        tmp_fp->print_format("%c %c %d %c %d %08x %016llx %016llx %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, (unsigned long long)next->compare, next->name.c_str());
      }
      else if(next->mltpl_count != 1 || next->mltpl_addr_inc != 0 || next->mltpl_val_inc != 0 || next->copy_src_addr != 0 || next->copy_src_addr_inc != 0)
      {
       tmp_fp->print_format("!%c %c %d %c %d %08x %016llx %08x %08x %016llx %08x %08x %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, next->mltpl_count, next->mltpl_addr_inc, (unsigned long long)next->mltpl_val_inc, next->copy_src_addr, next->copy_src_addr_inc, next->name.c_str());
      }
      else
      {
       if(next->length == 1)
        tmp_fp->print_format("%c %c %d %c %d %08x %02llx %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, next->name.c_str());
       else if(next->length == 2)
        tmp_fp->print_format("%c %c %d %c %d %08x %04llx %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, next->name.c_str());
       else
        tmp_fp->print_format("%c %c %d %c %d %08x %016llx %s\n", next->type, next->status ? 'A' : 'I', next->length, next->bigendian ? 'B' : 'L', next->icount, next->addr, (unsigned long long)next->val, next->name.c_str());
      }
      tmp_fp->print_format("%s\n", next->conditions.c_str());
     }
}

static void WriteCheats(void)
{
  std::string fn, tmp_fn;
  FileStream *fp = NULL, *tmp_fp = NULL;

  fn = MDFN_MakeFName(MDFNMKF_CHEAT, 0, 0);
  tmp_fn = MDFN_MakeFName(MDFNMKF_CHEAT_TMP, 0, 0);

  try
  {
   fp = new FileStream(fn.c_str(), FileStream::MODE_READ);
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }

  try
  {
   int insection = 0;	// Can contain 0, 1, or 2.
   std::string linebuf;
 
   tmp_fp = new FileStream(tmp_fn.c_str(), FileStream::MODE_WRITE);

   linebuf.reserve(1024);

   if(fp == NULL)
   {
    WriteCheatsSection(tmp_fp, true);
   }
   else
   {
    while(fp->get_line(linebuf) >= 0)
    {
     if(linebuf.size() >= 1 && linebuf[0] == '[' && !insection)
     {
      if(!strncmp((char *)linebuf.c_str() + 1, md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str(), 32) &&
	(strcasecmp(MDFNGameInfo->shortname, "psx") || linebuf.size() < 36 || !MDFNGameInfo->name || linebuf[34] != ' ' || !strcmp(linebuf.c_str() + 35, MDFNGameInfo->name)))
      {
       insection = 1;

       if(cheats.size())
        tmp_fp->put_line(linebuf);
      }
      else
       tmp_fp->put_line(linebuf);
     }
     else if(insection == 1)
     {
      if(linebuf[0] == '[') 
      {
       // Write any of our game cheats here.
       WriteCheatsSection(tmp_fp, false);
       insection = 2;     
       tmp_fp->put_line(linebuf);
      }
     }
     else
     {
      tmp_fp->put_line(linebuf);
     }
    }

    if(cheats.size())
    {
     if(!insection)
      WriteCheatsSection(tmp_fp, 1);
     else if(insection == 1)
      WriteCheatsSection(tmp_fp, 0);
    }

    fp->close();
   }

   tmp_fp->close();

   if(rename(tmp_fn.c_str(), fn.c_str()) != 0 && errno == EACCES)	// For Windows especially; see http://msdn.microsoft.com/en-us/library/zw5t957f.aspx
   {
    unlink(fn.c_str());
    rename(tmp_fn.c_str(), fn.c_str());
   }
  }
  catch(...)
  {
   if(fp != NULL)
   {
    delete fp;
    fp = NULL;
   }

   if(tmp_fp != NULL)
   {
    delete tmp_fp;
    tmp_fp = NULL;
   }
   throw;
  }

  if(fp != NULL)
  {
   delete fp;
   fp = NULL;
  }

  if(tmp_fp != NULL)
  {
   delete tmp_fp;
   tmp_fp = NULL;
  }
}

void MDFN_FlushGameCheats(int nosave)
{
 if(CheatComp)
 {
  free(CheatComp);
  CheatComp = 0;
 }

 if(savecheats && !nosave)
 {
  try
  {
   WriteCheats();
   savecheats = false;
  }
  catch(std::exception &e)
  {
   MDFN_PrintError("%s", e.what());
  }
 }

 cheats.clear();
 RebuildSubCheats();
}

void MDFNI_AddCheat(const MemoryPatch& patch)
{
 cheats.push_back(patch);

 savecheats = true;

 MDFNMP_RemoveReadPatches();
 RebuildSubCheats();
 MDFNMP_InstallReadPatches();
}

void MDFNI_DelCheat(uint32 which)
{
 cheats.erase(cheats.begin() + which);

 savecheats = true;

 MDFNMP_RemoveReadPatches();
 RebuildSubCheats();
 MDFNMP_InstallReadPatches();
}

/*
 Condition format(ws = white space):
 
  <variable size><ws><endian><ws><address><ws><operation><ws><value>
	  [,second condition...etc.]

  Value should be unsigned integer, hex(with a 0x prefix) or
  base-10.  

  Operations:
   >=
   <=
   >
   <
   ==
   !=
   &	// Result of AND between two values is nonzero
   !&   // Result of AND between two values is zero
   ^    // same, XOR
   !^
   |	// same, OR
   !|

  Full example:

  2 L 0xADDE == 0xDEAD, 1 L 0xC000 == 0xA0

*/

static bool TestConditions(const char *string)
{
 char address[64];
 char operation[64];
 char value[64];
 char endian;
 unsigned int bytelen;
 bool passed = 1;

 while(trio_sscanf(string, "%u %c %63s %63s %63s", &bytelen, &endian, address, operation, value) == 5 && passed)
 {
  uint32 v_address;
  uint64 v_value;
  uint64 value_at_address;

  if(address[0] == '0' && address[1] == 'x')
   v_address = strtoul(address + 2, NULL, 16);
  else
   v_address = strtoul(address, NULL, 10);

  if(value[0] == '0' && value[1] == 'x')
   v_value = strtoull(value + 2, NULL, 16);
  else
   v_value = strtoull(value, NULL, 0);

  value_at_address = 0;
  for(unsigned int x = 0; x < bytelen; x++)
  {
   unsigned int shiftie;

   if(endian == 'B')
    shiftie = (bytelen - 1 - x) * 8;
   else
    shiftie = x * 8;

   if(MDFNGameInfo->MemRead != NULL)
    value_at_address |= (uint64)MDFNGameInfo->MemRead(v_address + x) << shiftie;
   else
   {
    uint32 page = ((v_address + x) / PageSize) % NumPages;

    if(RAMPtrs[page])
     value_at_address |= (uint64)RAMPtrs[page][(v_address + x) % PageSize] << shiftie;
   }
  }

  //printf("A: %08x, V: %08llx, VA: %08llx, OP: %s\n", v_address, v_value, value_at_address, operation);
  if(!strcmp(operation, ">="))
  {
   if(!(value_at_address >= v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "<="))
  {
   if(!(value_at_address <= v_value))
    passed = 0;
  }
  else if(!strcmp(operation, ">"))
  {
   if(!(value_at_address > v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "<"))
  {
   if(!(value_at_address < v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "==")) 
  {
   if(!(value_at_address == v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "!="))
  {
   if(!(value_at_address != v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "&"))
  {
   if(!(value_at_address & v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "!&"))
  {
   if(value_at_address & v_value)
    passed = 0;
  }
  else if(!strcmp(operation, "^"))
  {
   if(!(value_at_address ^ v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "!^"))
  {
   if(value_at_address ^ v_value)
    passed = 0;
  }
  else if(!strcmp(operation, "|"))
  {
   if(!(value_at_address | v_value))
    passed = 0;
  }
  else if(!strcmp(operation, "!|"))
  {
   if(value_at_address | v_value)
    passed = 0;
  }
  else
   puts("Invalid operation");
  string = strchr(string, ',');
  if(string == NULL)
   break;
  else
   string++;
  //printf("Foo: %s\n", string);
 }

 return(passed);
}

void MDFNMP_ApplyPeriodicCheats(void)
{
 std::vector<CHEATF>::iterator chit;


 if(!CheatsActive)
  return;

 //TestConditions("2 L 0x1F00F5 == 0xDEAD");
 //if(TestConditions("1 L 0x1F0058 > 0")) //, 1 L 0xC000 == 0x01"));
 for(chit = cheats.begin(); chit != cheats.end(); chit++)
 {
  if(chit->status && (chit->type == 'R' || chit->type == 'A' || chit->type == 'T'))
  {
   if(chit->conditions.size() == 0 || TestConditions(chit->conditions.c_str()))
   {
    uint32 mltpl_count = chit->mltpl_count;
    uint32 mltpl_addr = chit->addr;
    uint64 mltpl_val = chit->val;
    uint32 copy_src_addr = chit->copy_src_addr;

    while(mltpl_count--)
    {
     uint8 carry = 0;

     for(unsigned int x = 0; x < chit->length; x++)
     {
      const uint32 tmpaddr = chit->bigendian ? (mltpl_addr + chit->length - 1 - x) : (mltpl_addr + x);
      const uint32 page = (tmpaddr / PageSize) % NumPages;
      const uint8 tmpval = mltpl_val >> (x * 8);

      if(RAMPtrs[page])
      {
       if(chit->type == 'A')
       {
	unsigned t = RAMPtrs[page][tmpaddr % PageSize] + tmpval + carry;

	carry = t >> 8;

        RAMPtrs[page][tmpaddr % PageSize] = t;
       }
       else if(chit->type == 'T')
       {
        const uint32 tmpsrcaddr = chit->bigendian ? (copy_src_addr + chit->length - 1 - x) : (copy_src_addr + x);
        const uint32 srcpage = (tmpsrcaddr / PageSize) % NumPages;
	uint8 cv = 0;

        if(RAMPtrs[srcpage])
	 cv = RAMPtrs[srcpage][tmpsrcaddr % PageSize];

        RAMPtrs[page][tmpaddr % PageSize] = cv;
       }
       else
        RAMPtrs[page][tmpaddr % PageSize] = tmpval;
      }
     }
     mltpl_addr += chit->mltpl_addr_inc;
     mltpl_val += chit->mltpl_val_inc;
     copy_src_addr += chit->copy_src_addr_inc;
    }

   } // end if(chit->conditions.size() == 0 || TestConditions(chit->conditions.c_str()))
  }
 }
}


void MDFNI_ListCheats(int (*callb)(const MemoryPatch& patch, void *data), void *data)
{
 std::vector<CHEATF>::iterator chit;

 for(chit = cheats.begin(); chit != cheats.end(); chit++)
 {
  if(!callb(*chit, data))
   break;
 }
}

MemoryPatch MDFNI_GetCheat(uint32 which)
{
 return cheats[which];
}

void MDFNI_SetCheat(uint32 which, const MemoryPatch& patch)
{
 cheats[which] = patch;

 savecheats = true;

 MDFNMP_RemoveReadPatches();
 RebuildSubCheats();
 MDFNMP_InstallReadPatches();
}

/* Convenience function. */
int MDFNI_ToggleCheat(uint32 which)
{
 cheats[which].status = !cheats[which].status;

 savecheats = true;

 MDFNMP_RemoveReadPatches();
 RebuildSubCheats();
 MDFNMP_InstallReadPatches();

 return(cheats[which].status);
}

void MDFNI_CheatSearchSetCurrentAsOriginal(void)
{
 for(uint32 page = 0; page < NumPages; page++)
 {
  if(CheatComp[page])
  {
   for(uint32 addr = 0; addr < PageSize; addr++)
   {
    // Don't check for .excluded here, or we'll break multi-byte iterative cheat searching!
    CheatComp[page][addr].value = RAMPtrs[page][addr];
   }
  }
 }
}

void MDFNI_CheatSearchShowExcluded(void)
{
 for(uint32 page = 0; page < NumPages; page++)
 {
  if(CheatComp[page])
  {
   for(uint32 addr = 0; addr < PageSize; addr++)
   {
    CheatComp[page][addr].excluded = 0;
   }
  }
 }
}


int32 MDFNI_CheatSearchGetCount(void)
{
 uint32 count = 0;

 for(uint32 page = 0; page < NumPages; page++)
 {
  if(CheatComp[page])
  {
   for(uint32 addr = 0; addr < PageSize; addr++)
   {
    if(!CheatComp[page][addr].excluded)
     count++;
   }
  }
 }
 return count;
}

/* This function will give the initial value of the search and the current value at a location. */

void MDFNI_CheatSearchGet(int (*callb)(uint32 a, uint64 last, uint64 current, void *data), void *data)
{
 for(uint32 page = 0; page < NumPages; page++)
 {
  if(CheatComp[page])
  {
   for(uint32 addr = 0; addr < PageSize; addr++)
   {
    if(!CheatComp[page][addr].excluded)
    {
     uint64 ccval;
     uint64 ramval;

     ccval = ramval = 0;
     for(unsigned int x = 0; x < resultsbytelen; x++)
     {
      uint32 curpage = (page + (addr + x) / PageSize) % NumPages;
      if(CheatComp[curpage])
      {
       unsigned int shiftie;

       if(resultsbigendian)
        shiftie = (resultsbytelen - 1 - x) * 8;
       else
        shiftie = x * 8;
       ccval |= (uint64)CheatComp[curpage][(addr + x) % PageSize].value << shiftie;
       ramval |= (uint64)RAMPtrs[curpage][(addr + x) % PageSize] << shiftie;
      }
     }

     if(!callb(page * PageSize + addr, ccval, ramval, data))
      return;
    }
   }
  }
 }
}

void MDFNI_CheatSearchBegin(void)
{
 resultsbytelen = 1;
 resultsbigendian = 0;

 for(uint32 page = 0; page < NumPages; page++)
 {
  if(RAMUseInSearch[page] && RAMPtrs[page])
  {
   if(!CheatComp[page])
    CheatComp[page] = (CompareStruct *)calloc(PageSize, sizeof(CompareStruct));

   for(uint32 addr = 0; addr < PageSize; addr++)
   {
    CheatComp[page][addr].excluded = 0;
    CheatComp[page][addr].value = RAMPtrs[page][addr];
   }
  }
 }
}


static uint64 INLINE CAbs(uint64 x)
{
 if(x < 0)
  return(0 - x);
 return x;
}

void MDFNI_CheatSearchEnd(int type, uint64 v1, uint64 v2, unsigned int bytelen, bool bigendian)
{
 v1 &= (~0ULL) >> (8 - bytelen);
 v2 &= (~0ULL) >> (8 - bytelen);

 resultsbytelen = bytelen;
 resultsbigendian = bigendian;

 for(uint32 page = 0; page < NumPages; page++)
 {
  if(CheatComp[page])
  {
   for(uint32 addr = 0; addr < PageSize; addr++)
   {
    if(!CheatComp[page][addr].excluded)
    {
     bool doexclude = 0;
     uint64 ccval;
     uint64 ramval;

     ccval = ramval = 0;
     for(unsigned int x = 0; x < bytelen; x++)
     {
      uint32 curpage = (page + (addr + x) / PageSize) % NumPages;
      if(CheatComp[curpage])
      {
       unsigned int shiftie;

       if(bigendian)
        shiftie = (bytelen - 1 - x) * 8;
       else
        shiftie = x * 8;
       ccval |= (uint64)CheatComp[curpage][(addr + x) % PageSize].value << shiftie;
       ramval |= (uint64)RAMPtrs[curpage][(addr + x) % PageSize] << shiftie;
      }
     }

     switch(type)
     {
      case 0: // Change to a specific value.
	if(!(ccval == v1 && ramval == v2))
	 doexclude = 1;
	break;
	 
      case 1: // Search for relative change(between values).
	if(!(ccval == v1 && CAbs(ccval - ramval) == v2))
	 doexclude = 1;
	break;

      case 2: // Purely relative change.
	if(!(CAbs(ccval - ramval) == v2))
	 doexclude = 1;
	break;
      case 3: // Any change
        if(!(ccval != ramval))
         doexclude = 1;
        break;
      case 4: // Value decreased
        if(ramval >= ccval)
         doexclude = 1;
        break;
      case 5: // Value increased
        if(ramval <= ccval)
         doexclude = 1;
        break;
     }
     if(doexclude)
      CheatComp[page][addr].excluded = TRUE;
    }
   }
  }
 }

 if(type >= 4)
  MDFNI_CheatSearchSetCurrentAsOriginal();
}

static void SettingChanged(const char *name)
{
 MDFNMP_RemoveReadPatches();

 CheatsActive = MDFN_GetSettingB("cheats");

 RebuildSubCheats();

 MDFNMP_InstallReadPatches();
}


MDFNSetting MDFNMP_Settings[] =
{
 { "cheats", MDFNSF_NOFLAGS, "Enable cheats.", NULL, MDFNST_BOOL, "1", NULL, NULL, NULL, SettingChanged },
 { NULL}
};
