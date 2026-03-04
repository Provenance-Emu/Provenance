#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>

/* RetroArch Includes */
#include "core.h"

@implementation PVRetroArchCoreBridge (Cheats)
#pragma mark - Cheats
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType: (NSString *)codeType
		setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
	if (code == nil) {
		if (error) {
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSKeyValueValidationError userInfo:@{NSLocalizedDescriptionKey: @"Cheat code must not be nil"}];
		}
		return NO;
	}
	retro_ctx_cheat_info_t cheat_info;
	cheat_info.index   = cheatIndex;
	cheat_info.enabled = enabled;
	cheat_info.code    = code.UTF8String;
	core_set_cheat(&cheat_info);
	return YES;
}

- (void)resetCheatCodes {
    core_reset_cheat();
}
@end
