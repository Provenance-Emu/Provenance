@import Foundation;
@import GameController;

#import "PVMupenBridge.h"

@interface PVMupenBridge (Resources)
/// Copies configuration files to the specified folder
/// @param romFolder Destination folder for configuration files
/// @return YES if successful, NO if an error occurred
- (BOOL)copyIniFiles:(NSString * _Nonnull)romFolder;

/// Creates folders for high-resolution textures
/// @param romFolder Base folder where texture directories will be created
/// @return YES if successful, NO if an error occurred
- (BOOL)createHiResFolder:(NSString * _Nonnull)romFolder;
@end
