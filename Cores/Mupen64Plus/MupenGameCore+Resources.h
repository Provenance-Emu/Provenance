@import Foundation;
@import GameController;
@import PVSupport;

#import <PVMupen64Plus/MupenGameCore.h>
#import "Plugins/Core/src/plugin/plugin.h"

@interface MupenGameCore (Resources)
-(void)copyIniFiles:(NSString * _Nonnull)romFolder;
-(void)createHiResFolder:(NSString * _Nonnull)romFolder;
@end
