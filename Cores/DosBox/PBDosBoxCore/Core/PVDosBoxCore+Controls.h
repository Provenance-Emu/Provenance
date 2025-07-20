//
//  PVDosBoxCore+Controls.h
//  PVDosBox
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVDosBox/PVDosBoxCore.h>
@protocol PVDSSystemResponderClient;
typedef enum PVDOSButton: NSInteger PVDOSButton;

NS_ASSUME_NONNULL_BEGIN

@interface PVDosBoxCoreBridge (Controls) <PVDOSSystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushDOSButton:(enum PVDOSButton)button forPlayer:(NSInteger)player;
- (void)didReleaseDOSButton:(enum PVDOSButton)button forPlayer:(NSInteger)player;
- (void)didMoveDOSJoystickDirection:(enum PVDOSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
