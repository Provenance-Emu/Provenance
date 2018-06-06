/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* settings-common.h:
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

/*
 Notes about MDFNST_FLOAT:
	The default value should ideally not be equal(numerically) to the minimum or maximum values.
	If it must be equal, then the default string should be exactly the same as the minimum/maximum string, to work around
	potential libc strtod() bugs.
*/

#ifndef __MDFN_SETTINGS_COMMON_H
#define __MDFN_SETTINGS_COMMON_H

enum MDFNSettingType
{
	// Actual base types
        MDFNST_INT = 0,     // (signed), int8, int16, int32, int64(saved as)
        MDFNST_UINT,    // uint8, uint16, uint32, uint64(saved as)
        MDFNST_BOOL,    // bool. bool. bool!
        MDFNST_FLOAT,   // float, double(saved as).
	MDFNST_STRING,
	MDFNST_ENUM,	// Handled like a string, but validated against the enumeration list, and MDFN_GetSettingUI() returns the number in the enumeration list.
	MDFNST_MULTI_ENUM,

	MDFNST_ALIAS
};


//#define MDFNST_EX_DRIVER = (1U << 16),    // If this is not set, the setting is assumed to be internal.  This...should probably be set automatically?
        
#define MDFNSF_NOFLAGS		0U	  // Always 0, makes setting definitions prettier...maybe.

// TODO(cats)
#define MDFNSF_CAT_INPUT        	(1U << 8)
#define MDFNSF_CAT_SOUND		(1U << 9)
#define MDFNSF_CAT_VIDEO		(1U << 10)
#define MDFNSF_CAT_INPUT_MAPPING	(1U << 11)	// User-configurable physical->virtual button/axes and hotkey mappings(driver-side code category mainly).

// Setting is used as a path or filename(mostly intended for automatic charset conversion of 0.9.x settings on MS Windows).
#define MDFNSF_CAT_PATH			(1U << 12)

#define MDFNSF_EMU_STATE	(1U << 17) // If the setting affects emulation from the point of view of the emulated program
#define MDFNSF_UNTRUSTED_SAFE	(1U << 18) // If it's safe for an untrusted source to modify it, probably only used in conjunction with
                                          // MDFNST_EX_EMU_STATE and network play

#define MDFNSF_SUPPRESS_DOC	(1U << 19) // Suppress documentation generation for this setting.
#define MDFNSF_COMMON_TEMPLATE	(1U << 20) // Auto-generated common template setting(like nes.xscale, pce.xscale, vb.xscale, nes.enable, pce.enable, vb.enable)
#define MDFNSF_NONPERSISTENT	(1U << 21) // Don't save setting in settings file.

// TODO:
// #define MDFNSF_WILL_BREAK_GAMES (1U << ) // If changing the value of the setting from the default value will break games/programs that would otherwise work.

// TODO(in progress):
#define MDFNSF_REQUIRES_RELOAD	(1U << 24)	// If a game reload is required for the setting to take effect.
#define MDFNSF_REQUIRES_RESTART	(1U << 25)	// If Mednafen restart is required for the setting to take effect.

struct MDFNSetting_EnumList
{
	const char *string;
	int number;
	const char *description;	// Short
	const char *description_extra;	// Extra verbose text appended to the short description.
};

struct MDFNSetting
{
        const char *name;
	uint32 flags;
        const char *description; // Short
	const char *description_extra;

        MDFNSettingType type;
        const char *default_value;
	const char *minimum;
	const char *maximum;
	bool (*validate_func)(const char *name, const char *value);
	void (*ChangeNotification)(const char *name);
	const MDFNSetting_EnumList *enum_list;
};

struct MDFNCS
{
	char *name;
	char *value;
	char *game_override;    // per-game setting override(netplay_override > game_override > value, in precedence)
	char *netplay_override; // "value" override for network play.

	const MDFNSetting *desc;
	void (*ChangeNotification)(const char *name);

	uint32 name_hash;
};

#endif
