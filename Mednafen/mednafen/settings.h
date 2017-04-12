#ifndef MDFN_SETTINGS_H
#define MDFN_SETTINGS_H

#include <string>

#include "settings-common.h"

void MDFN_LoadSettings(const std::string& path, bool override = false);
bool MDFN_MergeSettings(const MDFNSetting *);
bool MDFN_MergeSettings(const std::vector<MDFNSetting> &);
bool MDFN_SaveSettings(const std::string& path);

void MDFN_ClearAllOverrideSettings(void);
void MDFN_KillSettings(void);	// Free any resources acquired.

// This should assert() or something if the setting isn't found, since it would
// be a totally tubular error!
uint64 MDFN_GetSettingUI(const char *name);
int64 MDFN_GetSettingI(const char *name);
double MDFN_GetSettingF(const char *name);
bool MDFN_GetSettingB(const char *name);
std::string MDFN_GetSettingS(const char *name);

static INLINE uint64 MDFN_GetSettingUI(const std::string& name) { return MDFN_GetSettingUI(name.c_str()); }
static INLINE int64 MDFN_GetSettingI(const std::string& name) { return MDFN_GetSettingI(name.c_str()); }
static INLINE double MDFN_GetSettingF(const std::string& name) { return MDFN_GetSettingF(name.c_str()); }
static INLINE bool MDFN_GetSettingB(const std::string& name) { return MDFN_GetSettingB(name.c_str()); }
static INLINE std::string MDFN_GetSettingS(const std::string& name) { return MDFN_GetSettingS(name.c_str()); }

#endif
