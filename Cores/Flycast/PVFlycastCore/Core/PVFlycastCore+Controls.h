//
//  PVFlycastCore+Controls.h
//  PVFlycast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVFlycast/PVFlycastCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVFlycastCore (Controls) <PVDreamcastSystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player;
- (void)didReleaseDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player;
- (void)didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
