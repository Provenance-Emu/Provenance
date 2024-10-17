//
//  PVPlayCore+Controls.h
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVPlay/PVPlayCore.h>

typedef enum PVPS2Button: NSInteger PVPS2Button;

NS_ASSUME_NONNULL_BEGIN

PVCORE
@interface PVPlayCoreBridge (Controls) <PVPS2SystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushDreamcastButton:(enum PVPS2Button)button forPlayer:(NSInteger)player;
- (void)didReleaseDreamcastButton:(enum PVPS2Button)button forPlayer:(NSInteger)player;
- (void)didMoveDreamcastJoystickDirection:(enum PVPS2Button)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
