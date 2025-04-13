//  PVAzaharCore+Controls.h
//  Copyright © 2023 Provenance. All rights reserved.

#import <PVAzahar/PVAzaharCoreBridge.h>

NS_ASSUME_NONNULL_BEGIN
@interface PVAzaharCoreBridge (Controls) <PV3DSSystemResponderClient>
#pragma mark - Control
- (void)initControllBuffers;
- (void)pollControllers;
- (void)didPushGameCubeButton:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didReleaseGameCubeButton:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didMoveGameCubeJoystickDirection:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end
NS_ASSUME_NONNULL_END
