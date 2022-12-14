//
//  PVDolphinCore+Controls.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVDolphin/PVDolphinCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVDolphinCore (Controls) <PVGameCubeSystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushGameCubeButton:(enum PVGCButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGameCubeButton:(enum PVGCButton)button forPlayer:(NSInteger)player;
- (void)didMoveGameCubeJoystickDirection:(enum PVGCButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
