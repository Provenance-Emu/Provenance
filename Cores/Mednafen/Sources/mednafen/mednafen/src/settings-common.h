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

namespace Mednafen
{

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


enum : unsigned
{
 //MDFNST_EX_DRIVER = (1U << 16),    // If this is not set, the setting is assumed to be internal.  This...should probably be set automatically?
        
 MDFNSF_NOFLAGS			= 0U,	  // Always 0, makes setting definitions prettier...maybe.

 // TODO(cats)
 MDFNSF_CAT_INPUT		= (1U <<  0),
 MDFNSF_CAT_SOUND		= (1U <<  1),
 MDFNSF_CAT_VIDEO		= (1U <<  2),
 MDFNSF_CAT_INPUT_MAPPING	= (1U <<  3),	// User-configurable physical->virtual button/axes and hotkey mappings(driver-side code category mainly).

 // Setting is used as a path or filename(mostly intended for automatic charset conversion of 0.9.x settings on MS Windows).
 MDFNSF_CAT_PATH		= (1U <<  4),

 MDFNSF_EMU_STATE		= (1U <<  8), // If the setting affects emulation from the point of view of the emulated program
 MDFNSF_UNTRUSTED_SAFE		= (1U <<  9), // If it's safe for an untrusted source to modify it, probably only used in conjunction with
					      // MDFNSF_EMU_STATE and network play

 MDFNSF_SUPPRESS_DOC		= (1U << 10), // Suppress documentation generation for this setting.
 MDFNSF_COMMON_TEMPLATE		= (1U << 11), // Auto-generated common template setting(like nes.xscale, pce.xscale, vb.xscale, nes.enable, pce.enable, vb.enable)
 MDFNSF_NONPERSISTENT		= (1U << 12), // Don't save setting in settings file.

// TODO:
// MDFNSF_WILL_BREAK_GAMES 	= (1U << 13), // If changing the value of the setting from the default value will break games/programs that would otherwise work.
// TODO(in progress):
 MDFNSF_REQUIRES_RELOAD		= (1U << 14), // If a game reload is required for the setting to take effect.
 MDFNSF_REQUIRES_RESTART	= (1U << 15), // If Mednafen restart is required for the setting to take effect.

 //
 // Flags to mark which members to call free() on when MDFN_KillSettings() is called.  Use carefully.
 //
 MDFNSF_FREE__ANY	= (0xFFFU << 20),
 MDFNSF_FREE_STRUCT	= (1U << 20),
 MDFNSF_FREE_NAME	= (1U << 21),
 MDFNSF_FREE_DESC	= (1U << 22),
 MDFNSF_FREE_DESC_EXTRA	= (1U << 23),
 MDFNSF_FREE_DEFAULT	= (1U << 24),
 MDFNSF_FREE_MINIMUM	= (1U << 25),
 MDFNSF_FREE_MAXIMUM	= (1U << 26),
 MDFNSF_FREE_ENUMLIST	= (1U << 27),
 MDFNSF_FREE_ENUMLIST_STRING = (1U << 28),
 MDFNSF_FREE_ENUMLIST_DESC   = (1U << 29),
 MDFNSF_FREE_ENUMLIST_DESC_EXTRA = (1U << 30)
};

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
	char* value[4];		// priority: [3] > [2] > [1] > [0]

	uint32 name_hash;
	MDFNSetting desc;
};

}
#endif
