@import Foundation;
@import GameController;
@import PVSupport;

#import "PVMupenBridge.h"
#import "../Plugins/Core/Core/src/plugin/plugin.h"

@interface PVMupenBridge (Resources)
-(void)copyIniFiles:(NSString * _Nonnull)romFolder;
-(void)createHiResFolder:(NSString * _Nonnull)romFolder;
@end
