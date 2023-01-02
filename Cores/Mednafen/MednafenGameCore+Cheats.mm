#include <mednafen/mednafen.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/mempatcher.h>
#import "MednafenGameCore.h"
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport-Swift.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVMednafen/PVMednafen-Swift.h>
#import <PVLogging/PVLogging.h>

@implementation MednafenGameCore (Cheats)

#pragma mark - Cheats
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error
{
    @synchronized(self) {
        if (!(self.getCheatSupport)) {
            return false;
        }
        ILOG(@"Applying Cheat Code %@ %@", code, type);
        Mednafen::MDFNGI *game=(Mednafen::MDFNGI *)[self getGame];
        NSMutableArray *multipleCodes = [code componentsSeparatedByString:@"+"];
        ILOG(@"Multiple Codes %@ at INDEX %d", multipleCodes, cheatIndex);
        for (int i=0; i < multipleCodes.count; i++) {
			NSString *singleCode = multipleCodes[i];
            if (singleCode!= nil && singleCode.length > 0) {
                ILOG(@"Applying Code %@",singleCode);
                const char *cheatCode = [[singleCode stringByReplacingOccurrencesOfString:@":" withString:@""] UTF8String];
                Mednafen::MemoryPatch patch=Mednafen::MemoryPatch();
                @try {
                    if (sizeof(game->CheatInfo.CheatFormatInfo) > 0) {
                        UInt8 formatIndex=0;
                        switch (self.systemType) {
                            case MednaSystemGB:
                                if ([codeType isEqualToString:@"Game Genie"]) {
                                    formatIndex = 0;
                                } else if ([codeType isEqualToString:@"GameShark"]) {
                                    formatIndex = 1;
                                }
                                break;
                            case MednaSystemPSX:
                                if ([codeType isEqualToString:@"GameShark"]) {
                                    formatIndex = 0;
                                }
								if (i+1 < multipleCodes.count && [multipleCodes[i+1] length] == 4) {
									cheatCode = [[NSString stringWithFormat:@"%@%@",multipleCodes[i],multipleCodes[i+1]] UTF8String];
									i+=1;
								}
                                break;
                            case MednaSystemSNES:
                                if ([codeType isEqualToString:@"Game Genie"] || [singleCode containsString:@"-"]) {
                                    formatIndex = 0;
                                } else if ([codeType isEqualToString:@"Pro Action Replay"]) {
                                    formatIndex = 1;
                                } else {
                                    formatIndex = 1;
                                }
                                break;
                            default:
                                break;
                        }
                        game->CheatInfo.CheatFormatInfo[formatIndex].DecodeCheat(cheatCode, &patch);
                        patch.status=enabled;
                        if (cheatIndex < Mednafen::MDFNI_CheatSearchGetCount()) {
                            Mednafen::MDFNI_SetCheat(cheatIndex, patch);
                            Mednafen::MDFNI_ToggleCheat(cheatIndex);
                        } else {
                            Mednafen::MDFNI_AddCheat(patch);
                        }
                    }
                } @catch (NSException *exception) {
                    ILOG(@"Game Code Error %@", exception.reason);
                }
            }
        }
        Mednafen::MDFNMP_ApplyPeriodicCheats();
        // if no error til this point, return true
        return true;
    }
}

- (NSArray<NSString*> *)getCheatCodeTypes {
    NSArray *types=@[];
    switch (self.systemType) {
        case MednaSystemGB:
            types = @[ @"Game Genie", @"GameShark"];
            break;
        case MednaSystemPSX:
            types = @[ @"GameShark"];
            break;
        case MednaSystemSNES:
            types = @[@"Game Genie", @"Pro Action Replay"];
            break;
        default:
            break;
    }
    return types;
}

- (BOOL)getCheatSupport {
    if (self.systemType == MednaSystemPSX ||
        self.systemType == MednaSystemSNES ||
        self.systemType == MednaSystemGB) {
        return true;
    }
    return false;
}

@end
