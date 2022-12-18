
#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

# pragma CheatCodeSupport
@interface PVPlayCore (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setEnabled:(BOOL)enabled error:(NSError**)error;
@end
