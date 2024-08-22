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

#include "mednafen.h"

#include <map>
#include <trio/trio.h>

#include "general.h"
#include "state.h"

#include <mednafen/hash/md5.h>
#include <mednafen/string/string.h>

namespace Mednafen
{
static std::string BaseDirectory;
static std::string FileBase;
static std::string FileExt;	/* Includes the . character, as in ".nes" */
static std::string FileBaseDirectory;

void MDFN_SetBaseDirectory(const std::string& dir)
{
 BaseDirectory = dir;
}

std::string MDFN_GetBaseDirectory(void)
{
 return BaseDirectory;
}

void MDFN_SetFileBase(const std::string& dir_path, const std::string& file_base, const std::string& file_ext)
{
#if 0
 printf("\nFileBaseDirectory=%s\nFileBase=%s\nFileExt=%s\n\n", MDFN_strhumesc(FileBaseDirectory).c_str(), MDFN_strhumesc(FileBase).c_str(), MDFN_strhumesc(FileExt).c_str());
#endif
 //
 //
 //assert(!NVFS.is_absolute_path(file_base + MDFN_PSS));
 //assert(!NVFS.is_absolute_path(file_ext + MDFN_PSS));
 //
 //
 FileBaseDirectory = dir_path;
 FileBase = file_base;
 FileExt = file_ext;
}

typedef std::map<char, std::string> FSMap;

static std::string EvalPathFS(const std::string& fstring, const FSMap& fmap)
{
 std::string ret = "";
 const char *str = fstring.c_str();
 bool in_spec = false;

 while(*str)
 {
  int c = *str;

  if(!in_spec && c == '%')
   in_spec = true;
  else if(in_spec == true)
  {
   if(c == '%')
    ret = ret + "%";
   else
   {
    auto const& fvi = fmap.find((char)c);

    if(fvi != fmap.end())
     ret += fvi->second;
   }
   in_spec = false;
  }
  else
   ret.push_back(c);

  str++;
 }

 return ret;
}

static std::string GeneratePath(const std::string& fstring, const FSMap& fmap, const std::string& dir)
{
 const bool fstring_force_noprefix = (fstring.size() >= 2 && fstring[0] == '%' && (fstring[1] == 'd' || fstring[1] == 'b'));
 const std::string fspath = EvalPathFS(fstring, fmap);
 std::string ret;

 if(NVFS.is_absolute_path(fspath) || fstring_force_noprefix)
  ret = fspath;
 else if(NVFS.is_absolute_path(dir))
  ret = dir + MDFN_PSS + fspath;
 else
 {
  ret = BaseDirectory + MDFN_PSS;

  if(dir.size())
   ret += dir + MDFN_PSS;

  ret += fspath;
 }

 return ret;
}

std::string MDFN_MakeFName(MakeFName_Type type, int id1, const char *cd1)
{
 std::string ret;
 char numtmp[64];
 FSMap fmap;

 fmap['b'] = BaseDirectory;
 fmap['z'] = MDFN_PSS;

 fmap['d'] = FileBaseDirectory;
 fmap['f'] = fmap['F'] = FileBase;
 fmap['e'] = FileExt;

 fmap['p'] = "";

 fmap['x'] = "";		// Default extension(without period)
 fmap['X'] = "";		// A merging of x and p

 if(MDFNGameInfo)
 {
  fmap['m'] = md5_context::asciistr(MDFNGameInfo->MD5, 0); // MD5 hash of the currently loaded game ONLY.

  fmap['M'] = "";		// One with this empty, if file not found, then fill with the hash of the currently loaded game,
				// followed by a period and go with that result.
  fmap['s'] = MDFNGameInfo->shortname;
 }


 //printf("%s\n", EvalPathFS(std::string("%f.%m.sav"), fmap).c_str());

 switch(type)
 {
  default:
	break;


  case MDFNMKF_MOVIE:
  case MDFNMKF_STATE:
  case MDFNMKF_SAV:
  case MDFNMKF_SAVBACK:
	{
	 std::string dir, fstring;

	 if(type == MDFNMKF_MOVIE)
	 {
	  dir = MDFN_GetSettingS("filesys.path_movie");
	  fstring = MDFN_GetSettingS("filesys.fname_movie");
	  fmap['x'] = "mcm";
	 }
	 else if(type == MDFNMKF_STATE)
	 {
	  dir = MDFN_GetSettingS("filesys.path_state");
	  fstring = MDFN_GetSettingS("filesys.fname_state");
	  fmap['x'] = (cd1 ? cd1 : "mcs");
	 }
	 else if(type == MDFNMKF_SAV)
	 {
	  dir = MDFN_GetSettingS("filesys.path_sav");
	  fstring = MDFN_GetSettingS("filesys.fname_sav");
	  fmap['x'] = cd1;
	 }
	 else if(type == MDFNMKF_SAVBACK)
	 {
	  dir = MDFN_GetSettingS("filesys.path_savbackup");
	  fstring = MDFN_GetSettingS("filesys.fname_savbackup");
	  fmap['x'] = cd1;
	 }

	 fmap['X'] = fmap['x'];

	 if(type == MDFNMKF_SAVBACK)
	 {
	  if(id1 < 0)
	   fmap['p'] = "C";
	  else
	  {
	   trio_snprintf(numtmp, sizeof(numtmp), "%u", id1);
	   fmap['p'] = numtmp;
	  }
	 }
	 else if(type != MDFNMKF_SAV && !cd1)
	 {
	  trio_snprintf(numtmp, sizeof(numtmp), "%d", id1);
	  fmap['p'] = numtmp;
	 }

	 if(fmap['X'].size() > 1 && fmap['p'].size())
	  fmap['X'] = fmap['X'].erase(fmap['X'].size() - 1) + fmap['p'];
         //
	 //
	 for(int i = 0; i < 2; i++)
	 {
	  ret = GeneratePath(fstring, fmap, dir);

	  if(!NVFS.finfo(ret, nullptr, false))
	   fmap['M'] = fmap['m'] + ".";
	  else
	   break;
	 }
	}

	NVFS.create_missing_dirs(ret);
	break;


  case MDFNMKF_SNAP_DAT:
  case MDFNMKF_SNAP:
	{
	 const std::string dir = MDFN_GetSettingS("filesys.path_snap");
	 const std::string fstring = MDFN_GetSettingS("filesys.fname_snap");

	 trio_snprintf(numtmp, sizeof(numtmp), "%04u", id1);

	 fmap['p'] = numtmp;

	 if(cd1)
	  fmap['x'] = cd1;

	 if(type == MDFNMKF_SNAP_DAT)
	 {
	  fmap['p'] = "counter";
	  fmap['x'] = "txt";
	 }

	 ret = GeneratePath(fstring, fmap, dir);
	}

	NVFS.create_missing_dirs(ret);
	break;


  case MDFNMKF_CHEAT_TMP:
  case MDFNMKF_CHEAT:
	{
	 std::string basepath = MDFN_GetSettingS("filesys.path_cheat");

	 if(!NVFS.is_absolute_path(basepath))
	  basepath = BaseDirectory + MDFN_PSS + basepath;

	 ret = basepath + MDFN_PSS + MDFNGameInfo->shortname + "." + ((type == MDFNMKF_CHEAT_TMP) ? "tmpcht" : "cht");
	}
	break;


  case MDFNMKF_PATCH:
	{
	 const std::string fstring = "%d%z%f%e.%x";

	 if(cd1)
	  fmap['x'] = cd1;

	 ret = GeneratePath(fstring, fmap, "");
	}
	break;


  case MDFNMKF_FIRMWARE:
	if(NVFS.is_absolute_path(cd1))
	 ret = cd1;
	else
	{
	 std::string overpath = MDFN_GetSettingS("filesys.path_firmware");

	 if(NVFS.is_absolute_path(overpath))
	  ret = overpath + MDFN_PSS + cd1;
	 else
	 {
	  ret = BaseDirectory + MDFN_PSS + overpath + MDFN_PSS + cd1;

	  // For backwards-compatibility with < 0.9.0
	  if(!NVFS.finfo(ret, nullptr, false))
	  {
	   std::string new_ret = BaseDirectory + MDFN_PSS + cd1;

	   if(NVFS.finfo(new_ret, nullptr, false))
            ret = new_ret;
	  }
	 }
	}
	break;


  case MDFNMKF_PALETTE:
	{
	 std::string overpath = MDFN_GetSettingS("filesys.path_palette");
	 std::string eff_dir;

	 if(NVFS.is_absolute_path(overpath))
	  eff_dir = overpath;
	 else
	  eff_dir = BaseDirectory + MDFN_PSS + overpath;

	 ret = eff_dir + MDFN_PSS + FileBase + ".pal";

	 if(!NVFS.finfo(ret, nullptr, false))
	 {
	  ret = eff_dir + MDFN_PSS + FileBase + "." + md5_context::asciistr(MDFNGameInfo->MD5, 0) + ".pal";

	  if(!NVFS.finfo(ret, nullptr, false))
	   ret = eff_dir + MDFN_PSS + (cd1 ? cd1 : MDFNGameInfo->shortname) + ".pal";
	 }
	}
	break;


  case MDFNMKF_PMCONFIG:
  case MDFNMKF_PGCONFIG:
	{
	 std::string dir, fstring;

	 if(type == MDFNMKF_PMCONFIG)
	 {
	  dir = "";
	  fstring = "%s.%x";
	 }
	 else
	 {
	  dir = MDFN_GetSettingS("filesys.path_pgconfig");
	  fstring = "%f.%s.%x";
	 }

	 if(cd1)
	  fmap['x'] = cd1;

	 ret = GeneratePath(fstring, fmap, dir);
	}
	break;
 }

 return ret;
}

}
