#ifndef __MDFN_GENERAL_H
#define __MDFN_GENERAL_H

namespace Mednafen
{

void MDFN_SetBaseDirectory(const std::string& dir);
std::string MDFN_GetBaseDirectory(void);

void MDFN_SetFileBase(const std::string& dir_path, const std::string& file_base, const std::string& file_ext);

std::string MDFN_MakeFName(int type, int id1, const char *cd1);

typedef enum
{
 MDFNMKF_STATE = 0,
 MDFNMKF_SNAP,
 MDFNMKF_SAV,
 MDFNMKF_SAVBACK,
 MDFNMKF_CHEAT,
 MDFNMKF_PALETTE,
 MDFNMKF_PATCH,
 MDFNMKF_MOVIE,
 MDFNMKF_SNAP_DAT,
 MDFNMKF_CHEAT_TMP,
 MDFNMKF_FIRMWARE,
 MDFNMKF_PGCONFIG,
 MDFNMKF_PMCONFIG
} MakeFName_Type;

std::string MDFN_MakeFName(MakeFName_Type type, int id1, const char *cd1);
INLINE std::string MDFN_MakeFName(MakeFName_Type type, int id1, const std::string& cd1) { return MDFN_MakeFName(type, id1, cd1.c_str()); }

}
#endif
