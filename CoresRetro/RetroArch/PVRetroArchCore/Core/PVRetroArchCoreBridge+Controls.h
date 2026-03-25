//
//  PVRetroArchCoreBridge+Controls.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVRetroArch/PVRetroArchCoreBridge.h>

NS_ASSUME_NONNULL_BEGIN
@interface PVRetroArchCoreBridge (Controls)
#pragma mark - Control
- (void)initControllBuffers;
- (void)pollControllers;
- (void)didPushGameCubeButton:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didReleaseGameCubeButton:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didMoveGameCubeJoystickDirection:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
/// Set the libretro device type on a controller port.
/// Wraps RetroArch's core_set_controller_port_device().
/// Must be called after the core has loaded (retro_load_game has run).
- (void)setControllerPortDevice:(uint32_t)device forPort:(uint32_t)port;
@end
NS_ASSUME_NONNULL_END
