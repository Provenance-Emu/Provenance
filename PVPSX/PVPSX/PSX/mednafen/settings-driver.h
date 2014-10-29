#ifndef _MDFN_SETTINGS_DRIVER_H
#define _MDFN_SETTINGS_DRIVER_H

#include "settings-common.h"

//
// Due to how the per-module(and in the future, per-game) settings overrides work, we should
// take care not to call MDFNI_SetSetting*() unless the setting has actually changed due to a user action.
// I.E. do NOT call SetSetting*() unconditionally en-masse at emulator exit/game close to synchronize certain things like input mappings.
//
bool MDFNI_SetSetting(const char *name, const char *value, bool NetplayOverride = FALSE);
bool MDFNI_SetSettingB(const char *name, bool value);
bool MDFNI_SetSettingUI(const char *name, uint64 value);

bool MDFNI_DumpSettingsDef(const char *path);

#include <map>

const std::multimap <uint32, MDFNCS> *MDFNI_GetSettings(void);

#endif
