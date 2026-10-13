//
//  PVDolphinCore+Controls.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#if SWIFT_PACKAGE
#import "PVDolphinCore.h"
#else
#import <PVDolphin/PVDolphinCore.h>
#endif
//#include "Core/MachineContext.h"

NS_ASSUME_NONNULL_BEGIN
@interface PVDolphinCoreBridge (Controls) <PVGameCubeSystemResponderClient>
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
