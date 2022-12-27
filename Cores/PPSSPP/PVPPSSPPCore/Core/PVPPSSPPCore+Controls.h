//
//  PVPPSSPPCore+Controls.h
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVPPSSPP/PVPPSSPPCore.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface PVPPSSPPCore (Controls) <PVGameCubeSystemResponderClient>
#pragma mark - Control
- (void)initControllBuffers;
- (void)pollControllers;
- (void)didPushPSPButton:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didReleasePSPButton:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didMovePSPJoystickDirection:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
@end
NS_ASSUME_NONNULL_END
