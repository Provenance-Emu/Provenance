//
//  PVDosBoxCore+Controls.h
//  PVDosBox
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVDosBox/PVDosBoxCore.h>
@import GameController;
@protocol PVDOSSystemResponderClient;
typedef enum PVDOSButton: NSInteger PVDOSButton;

NS_ASSUME_NONNULL_BEGIN

@interface PVDosBoxCoreBridge (Controls) <PVDOSSystemResponderClient>

- (void)initControllBuffers;
- (void)pollControllers;

#pragma mark - Gamepad Control

- (void)didPushDOSButton:(enum PVDOSButton)button forPlayer:(NSInteger)player;
- (void)didReleaseDOSButton:(enum PVDOSButton)button forPlayer:(NSInteger)player;
- (void)didMoveDOSJoystickDirection:(enum PVDOSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;

#pragma mark - Keyboard Support

@property (nonatomic, readonly) BOOL gameSupportsKeyboard;
@property (nonatomic, readonly) BOOL requiresKeyboard;

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0));
- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0));

#pragma mark - Mouse Support

@property (nonatomic, readonly) BOOL gameSupportsMouse;
@property (nonatomic, readonly) BOOL requiresMouse;

- (void)mouseMovedAt:(CGPoint)point;
- (void)mouseMovedAtPoint:(CGPoint)point;
- (void)leftMouseDownAt:(CGPoint)point;
- (void)leftMouseDownAtPoint:(CGPoint)point;
- (void)leftMouseUp;
- (void)rightMouseDownAtPoint:(CGPoint)point;
- (void)rightMouseUp;

@end

NS_ASSUME_NONNULL_END
