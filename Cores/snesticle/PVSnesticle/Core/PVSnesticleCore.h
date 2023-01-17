#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

PVCORE
@interface PVSnesticleCore : PVEmulatorCore <PVSNESSystemResponderClient>

- (void)didPushSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player;
- (void)didReleaseSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player;
- (void)flipBuffers;

# pragma CheatCodeSupport
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled error:(NSError**)error;

@end
