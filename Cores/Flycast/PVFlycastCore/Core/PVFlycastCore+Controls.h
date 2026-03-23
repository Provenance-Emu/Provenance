//
//  PVFlycastCore+Controls.h
//  PVFlycast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVFlycast/PVFlycastCore.h>
@import PVCoreBridge;

NS_ASSUME_NONNULL_BEGIN

@interface PVFlycastCoreBridge (Controls) <PVDreamcastSystemResponderClient, MouseResponder>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player;
- (void)didReleaseDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player;
- (void)didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;

#pragma mark - Mouse Support

/// Call after game loads to configure port 0 as RETRO_DEVICE_MOUSE for the libretro core.
/// Returns YES if the device type was successfully applied, NO if the libretro core was not
/// yet initialised (safe to call before init — callers can retry on the next input event).
- (BOOL)configureDreamcastMousePort;

@end

NS_ASSUME_NONNULL_END
