#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

/* RetroArch Includes */
#include "core.h"

@implementation PVRetroArchCore (Cheats)
#pragma mark - Cheats
const char* cheatCode;
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType: (NSString *)codeType
		setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
	retro_ctx_cheat_info_t cheat_info;
	cheat_info.index   = cheatIndex;
	cheat_info.enabled = enabled;
	cheat_info.code    = code.UTF8String;
	core_set_cheat(&cheat_info);
	return true;
}
@end
