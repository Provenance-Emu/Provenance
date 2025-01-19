//
//  PVDesmume2015Core+Controls.h
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVDesmume2015/PVDesmume2015Core.h>
#import <Foundation/Foundation.h>

// Forward declarations from libretro.cpp
extern unsigned GPU_LR_FRAMEBUFFER_NATIVE_WIDTH;
extern unsigned GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT;
extern int current_layout;

@protocol MouseResponder;

typedef enum PVDSButton: NSInteger PVDSButton;

NS_ASSUME_NONNULL_BEGIN

@interface PVDesmume2015CoreBridge (Controls) <PVDSSystemResponderClient, MouseResponder>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Control

- (void)didPushDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player;
- (void)didReleaseDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player;
- (void)didMoveDSJoystickDirection:(enum PVDSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;

@property (nonatomic, readonly) BOOL gameSupportsMouse;
@property (nonatomic, readonly) BOOL requiresMouse;
@end

NS_ASSUME_NONNULL_END
