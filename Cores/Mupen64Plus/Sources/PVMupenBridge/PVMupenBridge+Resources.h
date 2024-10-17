@import Foundation;
@import GameController;

#import "PVMupenBridge.h"

@interface PVMupenBridge (Resources)
-(void)copyIniFiles:(NSString * _Nonnull)romFolder;
-(void)createHiResFolder:(NSString * _Nonnull)romFolder;
@end
