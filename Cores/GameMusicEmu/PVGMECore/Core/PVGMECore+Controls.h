//
//  PVGMECore+Controls.h
//  PVGME
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVGME/PVGMECore.h>

@import PVCoreObjCBridge;

typedef enum PVNESButton: NSInteger PVNESButton;

NS_ASSUME_NONNULL_BEGIN

@interface PVGMECoreBridge (Controls) <PVNESSystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control
-(void)didPushNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player;
-(void)didReleaseNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end

NS_ASSUME_NONNULL_END
