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
 The ugly kludges with the MDFN_strazicmp(MDFNGameInfo->shortname, "psx") are to work around the mess created by our
 flawed game ID generation code(the PS1 game library is enormous, and many games only have one track, leading to many collisions);
 TODO: a more permanent, system-agnostic solution to the problem.
*/

#include "mednafen.h"

#include <trio/trio.h>

#include "general.h"
#include <mednafen/string/string.h>
#include <mednafen/hash/md5.h>
#include "mempatcher.h"
#include "FileStream.h"
#include "MemoryStream.h"

static std::string compat0938_name;	// PS1 cheat kludge, <= 0.9.38.x stripped bytes with upper bit == 1 in MDFNGameInfo->name

MemoryPatch::MemoryPatch() : addr(0), val(0), compare(0), 
			     mltpl_count(1), mltpl_addr_inc(0), mltpl_val_inc(0), copy_src_addr(0), copy_src_addr_inc(0),
			     length(0), bigendian(false), status(false), icount(0), type(0)
{

}

MemoryPatch::~MemoryPatch()
{

}

static uint32 PageSize;
static uint32 NumPages;

struct CompareStruct
{
 bool excluded = false;
 uint8 value = 0;
};

struct RAMInfoS
{
 uint8* Ptr = NULL;
 bool UseInSearch = false;
 std::vector<CompareStruct> Comp;
};

static std::vector<RAMInfoS> RAMInfo;

static INLINE uint8 ReadU8(uint32 addr)
{
 addr %= (uint64)PageSize * NumPages;
 //
 //
 //
 const size_t page = addr / PageSize;

 if(RAMInfo[page].Ptr)
 {
  const size_t offs = addr % PageSize;

  return RAMInfo[page].Ptr[offs];
 }
 else if(MDFNGameInfo->CheatInfo.MemRead)
  return MDFNGameInfo->CheatInfo.MemRead(addr);
 else
  return 0;
}

static INLINE void WriteU8(uint32 addr, const uint8 val)
{
 addr %= (uint64)PageSize * NumPages;
 //
 //
 //
 const size_t page = addr / PageSize;

 if(RAMInfo[page].Ptr)
 {
  const size_t offs = addr % PageSize;

  RAMInfo[page].Ptr[offs] = val;
 }
 else if(MDFNGameInfo->CheatInfo.MemWrite)
  MDFNGameInfo->CheatInfo.MemWrite(addr, val);
}

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
static uint32 resultsbytelen = 1;
static bool resultsbigendian = 0;
static bool CheatsActive = true;

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

void MDFNMP_Init(uint32 ps, uint32 numpages)
{
 PageSize = ps;
 NumPages = numpages;

 RAMInfo.resize(numpages);

 CheatsActive = MDFN_GetSettingB("cheats");
}

void MDFNMP_Kill(void)
{
 RAMInfo.resize(0);
}

void MDFNMP_AddRAM(uint32 size, uint32 A, uint8 *RAM, bool use_in_search)
{
 const uint32 page_base = A / PageSize;
 const uint32 page_count = size / PageSize;

 for(uint32 page = 0; page < page_count; page++)
 {
  auto& ri = RAMInfo[page_base + page];

  ri.Ptr = RAM;
  ri.UseInSearch = use_in_search;

  if(RAM) // Don't increment the RAM pointer if we're passed a NULL pointer
   RAM += PageSize;
 }
}

void MDFNMP_RegSearchable(uint32 addr, uint32 size)
{
 MDFNMP_AddRAM(size, addr, NULL, true);
}

void MDFNMP_InstallReadPatches(void)
{
 if(!CheatsActive) return;

 std::vector<SUBCHEAT>::iterator chit;

 for(unsigned int x = 0; x < 8; x++)
  for(chit = SubCheats[x].begin(); chit != SubCheats[x].end(); chit++)
  {
   if(MDFNGameInfo->CheatInfo.InstallReadPatch)
    MDFNGameInfo->CheatInfo.InstallReadPatch(chit->addr, chit->value, chit->compare);
  }
}

void MDFNMP_RemoveReadPatches(void)
{
 if(MDFNGameInfo->CheatInfo.RemoveReadPatches)
  MDFNGameInfo->CheatInfo.RemoveReadPatches();
}

static bool SeekToOurSection(Stream* fp)
{
 std::string linebuf;

 linebuf.reserve(1024);

 while(fp->get_line(linebuf) >= 0)
 {
  if(linebuf.size() >= 1 && linebuf[0] == '[')
  {
   if(!strncmp(linebuf.c_str() + 1, md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str(), 32) &&
	(MDFN_strazicmp(MDFNGameInfo->shortname, "psx") || linebuf.size() < 36 || !compat0938_name.size() || linebuf[34] != ' ' || !strcmp(linebuf.c_str() + 35, compat0938_name.c_str())))
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

 //
 compat0938_name = MDFNGameInfo->name;
 if(!MDFN_strazicmp(MDFNGameInfo->shortname, "psx"))
 {
  for(auto& c : compat0938_name)
   if((int8)c < 0x20)	// (int8) here, not (uint8)
    c = ' ';
 }
 MDFN_trim(compat0938_name);
 //

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
      tmp_fp->print_format("[%s] %s\n", md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str(), compat0938_name.c_str());

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
 const std::string fn = MDFN_MakeFName(MDFNMKF_CHEAT, 0, 0);
 const std::string tmp_fn = MDFN_MakeFName(MDFNMKF_CHEAT_TMP, 0, 0);
 std::unique_ptr<FileStream> fp;
 std::unique_ptr<FileStream> tmp_fp;

 try
 {
  fp.reset(new FileStream(fn.c_str(), FileStream::MODE_READ));
 }
 catch(MDFN_Error &e)
 {
  if(e.GetErrno() != ENOENT)
   throw;
 }

 //
 //
 //
 {
  int insection = 0;	// Can contain 0, 1, or 2.
  std::string linebuf;
 
  tmp_fp.reset(new FileStream(tmp_fn.c_str(), FileStream::MODE_WRITE));

  linebuf.reserve(1024);

  if(!fp)
  {
   WriteCheatsSection(tmp_fp.get(), true);
  }
  else
  {
   while(fp->get_line(linebuf) >= 0)
   {
    if(linebuf.size() >= 1 && linebuf[0] == '[' && !insection)
    {
     if(!strncmp((char *)linebuf.c_str() + 1, md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str(), 32) &&
	(MDFN_strazicmp(MDFNGameInfo->shortname, "psx") || linebuf.size() < 36 || !compat0938_name.size() || linebuf[34] != ' ' || !strcmp(linebuf.c_str() + 35, compat0938_name.c_str())))
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
      WriteCheatsSection(tmp_fp.get(), false);
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
     WriteCheatsSection(tmp_fp.get(), 1);
    else if(insection == 1)
     WriteCheatsSection(tmp_fp.get(), 0);
   }

   fp->close();
  }

  tmp_fp->close();

  try
  {
   MDFN_rename(tmp_fn.c_str(), fn.c_str());
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() == EACCES || e.GetErrno() == EEXIST) // For MS Windows
   {
    MDFN_unlink(fn.c_str());
    MDFN_rename(tmp_fn.c_str(), fn.c_str());
   }
   else
    throw;
  }
 }
}

void MDFN_FlushGameCheats(int nosave)
{
 if(savecheats && !nosave)
 {
  try
  {
   WriteCheats();
   savecheats = false;
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
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

   value_at_address |= (uint64)ReadU8(v_address + x) << shiftie;
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
 if(!CheatsActive)
  return;

 //TestConditions("2 L 0x1F00F5 == 0xDEAD");
 //if(TestConditions("1 L 0x1F0058 > 0")) //, 1 L 0xC000 == 0x01"));
 for(std::vector<CHEATF>::iterator chit = cheats.begin(); chit != cheats.end(); chit++)
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
      const uint8 tmpval = mltpl_val >> (x * 8);

      if(chit->type == 'A')
      {
       const unsigned t = ReadU8(tmpaddr) + tmpval + carry;

       carry = t >> 8;

       WriteU8(tmpaddr, t);
      }
      else if(chit->type == 'T')
      {
       const uint8 cv = ReadU8(chit->bigendian ? (copy_src_addr + chit->length - 1 - x) : (copy_src_addr + x));

       WriteU8(tmpaddr, cv);
      }
      else
       WriteU8(tmpaddr, tmpval);
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
 for(uint32 page = 0; page < RAMInfo.size(); page++)
 {
  for(uint32 offs = 0; offs < RAMInfo[page].Comp.size(); offs++)
  {
   // Don't check for .excluded here, or we'll break multi-byte iterative cheat searching!
   RAMInfo[page].Comp[offs].value = ReadU8(page * PageSize + offs);
  }
 }
}

void MDFNI_CheatSearchShowExcluded(void)
{
 for(auto& ri : RAMInfo)
 {
  for(auto& cc : ri.Comp)
   cc.excluded = false;
 }
}


int32 MDFNI_CheatSearchGetCount(void)
{
 uint32 count = 0;

 for(auto& ri : RAMInfo)
 {
  for(auto& cc : ri.Comp)
   count += !cc.excluded;
 }

 return count;
}

static INLINE void Read_CCV_RAMV(const uint32 A, const unsigned len, const bool big_endian, uint64* const ccval, uint64* const ramval)
{
 *ccval = 0;
 *ramval = 0;

 for(unsigned x = 0; x < len; x++)
 {
  const uint32 cur_addr = (A + x) % ((uint64)NumPages * PageSize);
  const uint32 cur_page = cur_addr / PageSize;
  const uint32 cur_offs = cur_addr % PageSize;

  if(RAMInfo[cur_page].Comp.size() > 0)
  {
   unsigned int shiftie;

   if(big_endian)
    shiftie = (len - 1 - x) * 8;
   else
    shiftie = x * 8;

   *ccval |= (uint64)RAMInfo[cur_page].Comp[cur_offs].value << shiftie;
   *ramval |= (uint64)ReadU8(cur_addr) << shiftie;
  }
 }
}

/* This function will give the initial value of the search and the current value at a location. */
void MDFNI_CheatSearchGet(int (*callb)(uint32 a, uint64 last, uint64 current, void *data), void *data)
{
 for(uint32 page = 0; page < NumPages; page++)
 {
  for(uint32 offs = 0; offs < RAMInfo[page].Comp.size(); offs++)
  {
   if(!RAMInfo[page].Comp[offs].excluded)
   {
    const uint32 A = (page * PageSize) + offs;
    uint64 ccval, ramval;

    Read_CCV_RAMV(A, resultsbytelen, resultsbigendian, &ccval, &ramval);

    if(!callb(A, ccval, ramval, data))
     return;
   }
  }
 }
}

void MDFNI_CheatSearchBegin(void)
{
 resultsbytelen = 1;
 resultsbigendian = MDFNGameInfo->CheatInfo.BigEndian;

 for(unsigned page = 0; page < RAMInfo.size(); page++)
 {
  if(RAMInfo[page].UseInSearch)
  {
   RAMInfo[page].Comp.resize(PageSize);

   for(size_t offs = 0; offs < RAMInfo[page].Comp.size(); offs++)
   {
    RAMInfo[page].Comp[offs].excluded = false;
    RAMInfo[page].Comp[offs].value = ReadU8((page * PageSize) + offs);
   }
  }
 }
}


static uint64 INLINE CAbs(uint64 x) // FIXME?
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
  for(uint32 offs = 0; offs < RAMInfo[page].Comp.size(); offs++)
  {
   if(!RAMInfo[page].Comp[offs].excluded)
   {
    const uint32 A = (page * PageSize) + offs;
    uint64 ccval, ramval;
    bool do_exclude = false;

    Read_CCV_RAMV(A, bytelen, resultsbigendian, &ccval, &ramval);

    switch(type)
    {
     case 0: // Change to a specific value.
	do_exclude |= !(ccval == v1 && ramval == v2);
	break;
	 
     case 1: // Search for relative change(between values).
	do_exclude |= !(ccval == v1 && CAbs(ccval - ramval) == v2);
	break;

     case 2: // Purely relative change.
	do_exclude |= !(CAbs(ccval - ramval) == v2);
	break;

     case 3: // Any change
	do_exclude |= !(ccval != ramval);
        break;

     case 4: // Value decreased
	do_exclude |= (ramval >= ccval);
        break;

     case 5: // Value increased
	do_exclude |= (ramval <= ccval);
        break;
    }

    RAMInfo[page].Comp[offs].excluded |= do_exclude;
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


extern const MDFNSetting MDFNMP_Settings[] =
{
 { "cheats", MDFNSF_NOFLAGS, "Enable cheats.", NULL, MDFNST_BOOL, "1", NULL, NULL, NULL, SettingChanged },
 { NULL}
};
