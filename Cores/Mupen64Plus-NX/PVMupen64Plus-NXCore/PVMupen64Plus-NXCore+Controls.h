//
//  MupenGameNXCore+Controls.h
//  MupenGameNXCore
//
//  Created by Joseph Mattiello on 1/26/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import <PVMupen64Plus-NX/MupenGameNXCore.h>
#import "Plugins/Core/src/plugin/plugin.h"

NS_ASSUME_NONNULL_BEGIN

void MupenInitiateControllers (CONTROL_INFO ControlInfo);
void MupenGetKeys(int Control, BUTTONS *Keys);
void MupenControllerCommand(int Control, unsigned char *Command);

/// Static C callbacks used by m64p_media_loader to query GB cart ROM/RAM paths.
char * __nullable MupenNXGetGBCartROM(void * __nullable cb_data, int controller_num);
char * __nullable MupenNXGetGBCartRAM(void * __nullable cb_data, int controller_num);

@interface MupenGameNXCore (Controls) <PVN64SystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;
- (void)setMode:(NSInteger)mode forController:(NSInteger)controller;

/// Sets (or clears) the GB/GBC cartridge in a Transfer Pak slot (port 0–3).
/// Pass nil romPath to remove the cartridge from the slot.
- (void)setGBCartROMPath:(nullable NSString *)romPath
               savePath:(nullable NSString *)savePath
                forPort:(NSInteger)port;

/// Returns the GB ROM path currently mounted in the given Transfer Pak port, or nil.
- (nullable NSString *)gbCartROMPathForPort:(NSInteger)port;

/// Returns the GB save path currently mounted in the given Transfer Pak port, or nil.
- (nullable NSString *)gbCartSavePathForPort:(NSInteger)port;

#pragma mark - Control

- (void)didPushN64Button:(enum PVN64Button)button forPlayer:(NSInteger)player;
- (void)didReleaseN64Button:(enum PVN64Button)button forPlayer:(NSInteger)player;
- (void)didMoveN64JoystickDirection:(enum PVN64Button)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
