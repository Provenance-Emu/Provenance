/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* settings.h:
**  Copyright (C) 2005-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef MDFN_SETTINGS_H
#define MDFN_SETTINGS_H

#include "settings-common.h"

bool MDFN_LoadSettings(const std::string& path, bool override = false);
void MDFN_MergeSettings(const MDFNSetting *);
void MDFN_MergeSettings(const std::vector<MDFNSetting> &);
void MDFN_FinalizeSettings(void);
void MDFN_SaveSettings(const std::string& path);

void MDFN_ClearAllOverrideSettings(void);
void MDFN_KillSettings(void);	// Free any resources acquired.

// This should assert() or something if the setting isn't found, since it would
// be a totally tubular error!
uint64 MDFN_GetSettingUI(const char *name);
int64 MDFN_GetSettingI(const char *name);
double MDFN_GetSettingF(const char *name);
bool MDFN_GetSettingB(const char *name);
std::string MDFN_GetSettingS(const char *name);

std::vector<uint64> MDFN_GetSettingMultiUI(const char *name);
std::vector<int64> MDFN_GetSettingMultiI(const char *name);

static INLINE uint64 MDFN_GetSettingUI(const std::string& name) { return MDFN_GetSettingUI(name.c_str()); }
static INLINE int64 MDFN_GetSettingI(const std::string& name) { return MDFN_GetSettingI(name.c_str()); }
static INLINE double MDFN_GetSettingF(const std::string& name) { return MDFN_GetSettingF(name.c_str()); }
static INLINE bool MDFN_GetSettingB(const std::string& name) { return MDFN_GetSettingB(name.c_str()); }
static INLINE std::string MDFN_GetSettingS(const std::string& name) { return MDFN_GetSettingS(name.c_str()); }
static INLINE std::vector<uint64> MDFN_GetSettingMultiUI(const std::string& name) { return MDFN_GetSettingMultiUI(name.c_str()); }
static INLINE std::vector<int64> MDFN_GetSettingMultiI(const std::string& name) { return MDFN_GetSettingMultiI(name.c_str()); }

#endif
