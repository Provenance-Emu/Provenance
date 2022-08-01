//
//  PVDesmume2015Core+Controls.h
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVDesmume2015/PVDesmume2015Core.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVDesmume2015Core (Controls) <PVDSSystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player;
- (void)didReleaseDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player;
- (void)didMoveDSJoystickDirection:(enum PVDSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
