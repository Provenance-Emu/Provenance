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

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <map>
#include <trio/trio.h>

#include "general.h"
#include "state.h"

#include <mednafen/hash/md5.h>
#include <mednafen/string/string.h>

using namespace std;

static string BaseDirectory;
static string FileBase;
static string FileExt;	/* Includes the . character, as in ".nes" */
static string FileBaseDirectory;

void MDFN_SetBaseDirectory(const std::string& dir)
{
 BaseDirectory = dir;
}

std::string MDFN_GetBaseDirectory(void)
{
 return BaseDirectory;
}

static bool IsPSep(const char c)
{
#if PSS_STYLE==4
 bool ret = (c == ':');
#elif PSS_STYLE==1
 bool ret = (c == '/');
#else
 bool ret = (c == '\\');

 #if PSS_STYLE!=3
  ret |= (c == '/');
 #endif
#endif

 return ret;
}

// Really dumb, maybe we should use boost?
static bool IsAbsolutePath(const char* path)
{
 if(IsPSep(path[0]))
  return true;

 #if defined(WIN32) || defined(DOS)
 if((path[0] >= 'a' && path[0] <= 'z') || (path[0] >= 'A' && path[0] <= 'Z'))
 {
  if(path[1] == ':')
  {
   return true;
  }
 }
 #endif

 return false;
}

static bool IsAbsolutePath(const std::string &path)
{
 return IsAbsolutePath(path.c_str());
}

void MDFN_CheckFIROPSafe(const std::string &path)
{
 //
 // First, check for any 8-bit characters, and print a warning about portability.
 //
 for(size_t x = 0; x < path.size(); x++)
 {
  if(path[x] & 0x80)
  {
   MDFN_printf(_("WARNING: Referenced path \"%s\" contains at least one 8-bit non-ASCII character; this may cause portability issues.\n"), path.c_str());
   break;
  }
 }

 if(!MDFN_GetSettingB("filesys.untrusted_fip_check"))
  return;

 // We could make this more OS-specific, but it shouldn't hurt to try to weed out usage of characters that are path
 // separators in one OS but not in another, and we'd also run more of a risk of missing a special path separator case
 // in some OS.
 std::string unsafe_reason;

#ifdef WIN32
 if(!UTF8_validate(path, true))
  unsafe_reason += _("Invalid UTF-8. ");
#endif

 if(path.find('\0') != string::npos)
  unsafe_reason += _("Contains null(0). ");

 if(path.find(':') != string::npos)
  unsafe_reason += _("Contains colon. ");

 if(path.find('\\') != string::npos)
  unsafe_reason += _("Contains backslash. ");

 if(path.find('/') != string::npos)
  unsafe_reason += _("Contains forward slash. ");

 if(path == "..")
  unsafe_reason += _("Is parent directory. ");

#if defined(DOS) || defined(WIN32)
 //
 // http://support.microsoft.com/kb/74496
 // http://googleprojectzero.blogspot.com/2016/02/the-definitive-guide-on-win32-to-nt.html
 //
 {
  static const char* dev_names[] = 
  {
   "CON", "PRN", "AUX", "CLOCK$", "NUL", "CONIN$", "CONOUT$",
   "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "COM¹", "COM²", "COM³",
   "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9", "LPT¹", "LPT²", "LPT³",
   NULL
  };
  //
  const char* pcs = path.c_str();
  for(const char** ls = dev_names; *ls != NULL; ls++)
  {
   size_t lssl = strlen(*ls);

   if(!MDFN_strazicmp(*ls, pcs, lssl))
   {
    if(pcs[lssl] == 0 || pcs[lssl] == ':' || pcs[lssl] == '.' || pcs[lssl] == ' ')
    {
     unsafe_reason += _("Is (likely) a reserved device name. ");
     break;
    }
   }
  }
 }
#endif

 if(unsafe_reason.size() > 0)
  throw MDFN_Error(0, _("Referenced path \"%s\" is potentially unsafe.  %s Refer to the documentation about the \"filesys.untrusted_fip_check\" setting.\n"), path.c_str(), unsafe_reason.c_str());
}

void MDFN_GetFilePathComponents(const std::string &file_path, std::string *dir_path_out, std::string *file_base_out, std::string *file_ext_out)
{
 size_t final_ds;		// in file_path
 string file_name;
 size_t fn_final_dot;		// in local var file_name
 // Temporary output:
 string dir_path, file_base, file_ext;

#if PSS_STYLE==4
 final_ds = file_path.find_last_of(':');
#elif PSS_STYLE==1
 final_ds = file_path.find_last_of('/');
#else
 final_ds = file_path.find_last_of('\\');

 #if PSS_STYLE!=3
  {
   size_t alt_final_ds = file_path.find_last_of('/');

   if(final_ds == string::npos || (alt_final_ds != string::npos && alt_final_ds > final_ds))
    final_ds = alt_final_ds;
  }
 #endif
#endif

 if(final_ds == string::npos)
 {
  dir_path = string(".");
  file_name = file_path;
 }
 else
 {
  dir_path = file_path.substr(0, final_ds);
  file_name = file_path.substr(final_ds + 1);
 }

 fn_final_dot = file_name.find_last_of('.');

 if(fn_final_dot != string::npos)
 {
  file_base = file_name.substr(0, fn_final_dot);
  file_ext = file_name.substr(fn_final_dot);
 }
 else
 {
  file_base = file_name;
  file_ext = string("");
 }

 // Write outputs at end, in case file_path references the same std::string as pointed to
 // by one of the outputs.
 if(dir_path_out)
  *dir_path_out = dir_path;

 if(file_base_out)
  *file_base_out = file_base;

 if(file_ext_out)
  *file_ext_out = file_ext;
}

std::string MDFN_EvalFIP(const std::string &dir_path, const std::string &rel_path, bool skip_safety_check)
{
 if(!skip_safety_check)
  MDFN_CheckFIROPSafe(rel_path);

 if(IsAbsolutePath(rel_path.c_str()))
  return(rel_path);
 else
 {
  return(dir_path + std::string(PSS) + rel_path);
 }
}


typedef std::map<char, std::string> FSMap;

static std::string EvalPathFS(const std::string &fstring, /*const (won't work because entry created if char doesn't exist) */ FSMap &fmap)
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
    ret = ret + std::string("%");
   else
    ret = ret + fmap[(char)c];
   in_spec = false;
  }
  else
  {
   char ct[2];
   ct[0] = c;
   ct[1] = 0;
   ret += std::string(ct);
  }

  str++;
 }

 return(ret);
}

static void CreateMissingDirs(const std::string& path)
{
 size_t make_spos;

 //
 //
 //
 {
  bool prev_was_psep = false;
  size_t last_notpsep_pos = path.size();

  for(size_t i = path.size(); i != SIZE_MAX; i--)
  {
   if(IsPSep(path[i]))
    prev_was_psep = true;
   else
   {
    if(prev_was_psep)
    {
     std::string tmp = path.substr(0, i + 1);
     struct stat tmpstat;

     if(!MDFN_stat(tmp.c_str(), &tmpstat) || (errno != ENOENT && errno != ENOTDIR))
      break;
    }

    prev_was_psep = false;
    last_notpsep_pos = i;
   }
  }

  make_spos = last_notpsep_pos;
 }

 //
 //
 //
 {
  bool prev_was_psep = false;

  for(size_t i = make_spos; i < path.size(); i++)
  {
   if(IsPSep(path[i]))
   {
    if(!prev_was_psep)
    {
     std::string tmp = path.substr(0, i);

     MDFN_mkdir_T(tmp.c_str());
     //puts(tmp.c_str());
    }
    prev_was_psep = true;
   }
   else
    prev_was_psep = false;
  }
 }
}

std::string MDFN_MakeFName(MakeFName_Type type, int id1, const char *cd1)
{
 std::string ret;
 char numtmp[64];
 struct stat tmpstat;
 string eff_dir;
 FSMap fmap;

 fmap['b'] = BaseDirectory;
 fmap['z'] = std::string(PSS);

 if(MDFNGameInfo)
 {
  fmap['d'] = FileBaseDirectory;
  fmap['f'] = FileBase;
  fmap['F'] = FileBase;		// If game is a CD, and the CD is recognized as being part of a multi-CD set, then this
				// will be replaced with MDFNGameInfo->shortname

  fmap['m'] = md5_context::asciistr(MDFNGameInfo->MD5, 0); // MD5 hash of the currently loaded game ONLY.

  fmap['M'] = "";		// One with this empty, if file not found, then fill with MD5 hash of the currently loaded game,
				// or the MD5 gameset hash for certain CD games, followed by a period and go with that result.
				// Note: The MD5-less result is skipped if the CD is part of a recognized multi-CD set.
  fmap['e'] = FileExt;
  fmap['s'] = MDFNGameInfo->shortname;

  fmap['p'] = "";


  fmap['x'] = "";		// Default extension(without period)
  fmap['X'] = "";		// A merging of x and p

  if(MDFNGameInfo->GameSetMD5Valid)
  {
   fmap['M'] = md5_context::asciistr(MDFNGameInfo->GameSetMD5, 0) + std::string(".");
   fmap['F'] = MDFNGameInfo->shortname;
  }
 }


 //printf("%s\n", EvalPathFS(std::string("%f.%m.sav"), fmap).c_str());

 switch(type)
 {
  default: break;

  case MDFNMKF_MOVIE:
  case MDFNMKF_STATE:
  case MDFNMKF_SAV:
  case MDFNMKF_SAVBACK:
		     {
		      std::string dir, fstring, fpath;

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
		       fmap['x'] = std::string(cd1);
                      }
                      else if(type == MDFNMKF_SAVBACK)
                      {
		       dir = MDFN_GetSettingS("filesys.path_savbackup");
                       fstring = MDFN_GetSettingS("filesys.fname_savbackup");
		       fmap['x'] = std::string(cd1);
                      }

		      fmap['X'] = fmap['x'];

		      if(type == MDFNMKF_SAVBACK)
		      {
		       if(id1 < 0)
			fmap['p'] = "C";
		       else
		       {
                        trio_snprintf(numtmp, sizeof(numtmp), "%u", id1);
                        fmap['p'] = std::string(numtmp);
		       }
	              }
		      else if(type != MDFNMKF_SAV && !cd1)
		      {
                       trio_snprintf(numtmp, sizeof(numtmp), "%d", id1);
                       fmap['p'] = std::string(numtmp);
	              }

		      if(fmap['X'].size() > 1 && fmap['p'].size())
		       fmap['X'] = fmap['X'].erase(fmap['X'].size() - 1) + fmap['p'];

		      for(int i = 0; i < 2; i++)
		      {
                       fpath = EvalPathFS(fstring, fmap);

		       if(!IsAbsolutePath(fpath))
		       {
		        if(!IsAbsolutePath(dir))
		         dir = BaseDirectory + std::string(PSS) + dir;

 			fpath = dir + std::string(PSS) + fpath;
		       }

                       if(MDFN_stat(fpath.c_str(), &tmpstat) == -1)
                        fmap['M'] = md5_context::asciistr(MDFNGameInfo->MD5, 0) + std::string(".");
		       else
		        break;
                      }

		      if(type == MDFNMKF_SAVBACK)
		       CreateMissingDirs(fpath);

                      return(fpath);
	             }

  case MDFNMKF_SNAP_DAT:
  case MDFNMKF_SNAP:
	            {
		     std::string dir = MDFN_GetSettingS("filesys.path_snap");
		     std::string fstring = MDFN_GetSettingS("filesys.fname_snap");
		     std::string fpath;

		     trio_snprintf(numtmp, sizeof(numtmp), "%04u", id1);

		     fmap['p'] = std::string(numtmp);

		     if(cd1)
		      fmap['x'] = std::string(cd1);

		     if(type == MDFNMKF_SNAP_DAT)
		     {
		      fmap['p'] = std::string("counter");
		      fmap['x'] = std::string("txt");
		     }
                     fpath = EvalPathFS(fstring, fmap);
                     if(!IsAbsolutePath(fpath))
                     {
                      if(!IsAbsolutePath(dir))
                       dir = BaseDirectory + std::string(PSS) + dir;

                      fpath = dir + std::string(PSS) + fpath;
                     }
		     return(fpath);
		    }
                    break;

  case MDFNMKF_CHEAT_TMP:
  case MDFNMKF_CHEAT:
		{
		 std::string basepath = MDFN_GetSettingS("filesys.path_cheat");

		 if(!IsAbsolutePath(basepath))
		  basepath = BaseDirectory + PSS + basepath;

		 ret = basepath + PSS + MDFNGameInfo->shortname + "." + ((type == MDFNMKF_CHEAT_TMP) ? "tmpcht" : "cht");
		}
		break;

  case MDFNMKF_AUX:
		if(IsAbsolutePath(cd1))
		 ret = cd1;
		else
		 ret = FileBaseDirectory + PSS + cd1;
		break;

  case MDFNMKF_IPS:
		ret = FileBaseDirectory + PSS + FileBase + FileExt + ".ips";
		break;

  case MDFNMKF_FIRMWARE:
		if(IsAbsolutePath(cd1))
		 ret = cd1;
		else
		{
		 std::string overpath = MDFN_GetSettingS("filesys.path_firmware");

		 if(IsAbsolutePath(overpath))
                  ret = overpath + PSS + cd1;
                 else
		 {
		  ret = BaseDirectory + PSS + overpath + PSS + cd1;

		  // For backwards-compatibility with < 0.9.0
		  if(MDFN_stat(ret.c_str(),&tmpstat) == -1)
                   ret = BaseDirectory + PSS + cd1;
		 }
		}
		break;

  case MDFNMKF_PALETTE:
		{
		 std::string overpath = MDFN_GetSettingS("filesys.path_palette");

		 if(IsAbsolutePath(overpath))
		  eff_dir = overpath;
		 else
		  eff_dir = BaseDirectory + PSS + overpath;

		 ret = eff_dir + PSS + FileBase + ".pal";

		 if(MDFN_stat(ret.c_str(),&tmpstat) == -1 && errno == ENOENT)
		 {
		  ret = eff_dir + PSS + FileBase + "." + md5_context::asciistr(MDFNGameInfo->MD5, 0) + ".pal";

		  if(MDFN_stat(ret.c_str(), &tmpstat) == -1 && errno == ENOENT)
		   ret = eff_dir + PSS + (cd1 ? cd1 : MDFNGameInfo->shortname) + ".pal";
		 }
		}
		break;

  case MDFNMKF_PGCONFIG:
		{
		 std::string overpath = MDFN_GetSettingS("filesys.path_pgconfig");

		 if(IsAbsolutePath(overpath))
		  eff_dir = overpath;
		 else
		  eff_dir = std::string(BaseDirectory) + std::string(PSS) + overpath;

		 ret = eff_dir + PSS + FileBase + "." + MDFNGameInfo->shortname + ".cfg";
		}
		break;
 }

 return ret;
}

void GetFileBase(const char *f)
{
 MDFN_GetFilePathComponents(f, &FileBaseDirectory, &FileBase, &FileExt);
}

