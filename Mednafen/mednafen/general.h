#ifndef _GENERAL_H
#define _GENERAL_H

#include <string>

#if 0
class FilePathMaker
{


 void SetBaseDirectory(const char* path);
 std::string GetBaseDirectory(void);

 void BuildPath(unsigned type, int id1, const char* cd1);

 static void GetFileBase(

};
#endif

void MDFN_SetBaseDirectory(const std::string& dir);
std::string MDFN_GetBaseDirectory(void);

void GetFileBase(const char *f);

// File-inclusion for-read-only path, for PSF and CUE/TOC sheet usage.
bool MDFN_IsFIROPSafe(const std::string &path);

std::string MDFN_MakeFName(int type, int id1, const char *cd1);

typedef enum
{
 MDFNMKF_STATE = 0,
 MDFNMKF_SNAP,
 MDFNMKF_SAV,
 MDFNMKF_CHEAT,
 MDFNMKF_PALETTE,
 MDFNMKF_IPS,
 MDFNMKF_MOVIE,
 MDFNMKF_AUX,
 MDFNMKF_SNAP_DAT,
 MDFNMKF_CHEAT_TMP,
 MDFNMKF_FIRMWARE,
 MDFNMKF_PGCONFIG
} MakeFName_Type;

std::string MDFN_MakeFName(MakeFName_Type type, int id1, const char *cd1);
INLINE std::string MDFN_MakeFName(MakeFName_Type type, int id1, const std::string& cd1) { return MDFN_MakeFName(type, id1, cd1.c_str()); }
const char * GetFNComponent(const char *str);

void MDFN_GetFilePathComponents(const std::string &file_path, std::string *dir_path_out, std::string *file_base_out = NULL, std::string *file_ext_out = NULL);
std::string MDFN_EvalFIP(const std::string &dir_path, const std::string &rel_path, bool skip_safety_check = false);
#endif
