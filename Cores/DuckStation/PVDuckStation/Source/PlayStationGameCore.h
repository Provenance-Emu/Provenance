// Copyright (c) 2020, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <Cocoa/Cocoa.h>
#import <OpenEmuBase/OEGameCore.h>
#include <os/log.h>

NS_ASSUME_NONNULL_BEGIN

extern os_log_t OE_CORE_LOG;

OE_EXPORTED_CLASS
@interface PlayStationGameCore : OEGameCore

@end

#ifdef __cplusplus
extern "C" {
#endif

/**
 * PlayStation hacks specific to the DuckStation OpenEmu plug-in.
 * TODO: Migrate all of these to OEOverrides.ini instead of being a compile-time thing.
 */
typedef NS_OPTIONS(uint32_t, OEPSXHacks) {
	//! No OpenEmu-specific hacks available/required.
	OEPSXHacksNone = 0,
	
	//! Game works best with, or requires, a GunCon.
	OEPSXHacksGunCon = 1 << 0,
	//! Game works best with, or requires, a Konami Justifier.
	//! @note Currently not supported by DuckStation.
	OEPSXHacksJustifier = 2 << 0,
	//! Game works best with, or requires, a mouse.
	OEPSXHacksMouse = 3 << 0,
	
	//! All the hack-specific controller types.
	//! @discussion Can be <code>and</code>ed to get the specific controller type the game needs or desires.
	OEPSXHacksCustomControllers = OEPSXHacksGunCon | OEPSXHacksJustifier | OEPSXHacksMouse,
	
	//! Game requires only one memory card inserted.
	OEPSXHacksOnlyOneMemcard = 1 << 4,

	//! Game supports multi-tap.
	//! TODO: implement
	//! @note Currently not implemented in the DuckStation plug-in.
	OEPSXHacksMultiTap = 1 << 5,
	//! Game requires multi-tap adaptor to be in the second controller port.
	//! TODO: implement
	//! @note Currently not implemented in the DuckStation plug-in.
	OEPSXHacksMultiTap5PlayerPort2 = 1 << 6,
};

extern OEPSXHacks OEGetPSXHacksNeededForGame(NSString *name);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
