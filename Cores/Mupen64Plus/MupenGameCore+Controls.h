//
//  MupenGameCore+Controls.h
//  MupenGameCore
//
//  Created by Joseph Mattiello on 1/26/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import <PVMupen64Plus/MupenGameCore.h>
#import "Plugins/Core/src/plugin/plugin.h"

NS_ASSUME_NONNULL_BEGIN

void MupenInitiateControllers (CONTROL_INFO ControlInfo);
void MupenGetKeys(int Control, BUTTONS *Keys);
void MupenControllerCommand(int Control, unsigned char *Command);

PVCORE
@interface MupenGameCore (Controls) <PVN64SystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushN64Button:(enum PVN64Button)button forPlayer:(NSInteger)player;
- (void)didReleaseN64Button:(enum PVN64Button)button forPlayer:(NSInteger)player;
- (void)didMoveN64JoystickDirection:(enum PVN64Button)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
