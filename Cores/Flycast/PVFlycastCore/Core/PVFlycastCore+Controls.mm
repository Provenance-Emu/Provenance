//
//  PVFlycastCore+Controls.m
//  PVFlycast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVFlycast/PVFlycast.h>
#import <Foundation/Foundation.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVCoreBridgeRetro;

#define DC_BTN_C        (1<<0)
#define DC_BTN_B        (1<<1)
#define DC_BTN_A        (1<<2)
#define DC_BTN_START    (1<<3)
#define DC_DPAD_UP      (1<<4)
#define DC_DPAD_DOWN    (1<<5)
#define DC_DPAD_LEFT    (1<<6)
#define DC_DPAD_RIGHT   (1<<7)
#define DC_BTN_Z        (1<<8)
#define DC_BTN_Y        (1<<9)
#define DC_BTN_X        (1<<10)
#define DC_BTN_D        (1<<11)
#define DC_DPAD2_UP     (1<<12)
#define DC_DPAD2_DOWN   (1<<13)
#define DC_DPAD2_LEFT   (1<<14)
#define DC_DPAD2_RIGHT  (1<<15)

#define DC_AXIS_LT       (0X10000)
#define DC_AXIS_RT       (0X10001)
#define DC_AXIS_X        (0X20000)
#define DC_AXIS_Y        (0X20001)

static const int DreamcastMap[]  = {
    DC_DPAD_UP, DC_DPAD_DOWN, DC_DPAD_LEFT, DC_DPAD_RIGHT,
    DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y,
    DC_AXIS_LT, DC_AXIS_RT,
    DC_BTN_START
};

typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef unsigned int   u32;

    // Flycast controller data
u16 kcode[4];
u8 rt[4];
u8 lt[4];
u32 vks[4];
s8 joyx[4], joyy[4];

@implementation PVFlycastCoreBridge (Controls)

- (void)initControllBuffers {
    memset(&kcode, 0xFFFF, sizeof(kcode));
    bzero(&rt, sizeof(rt));
    bzero(&lt, sizeof(lt));
}

#pragma mark - Control

- (void)pollControllers {
    for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
    {
        GCController *controller = nil;

        if (self.controller1 && playerIndex == 0)
        {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && playerIndex == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 3)
        {
            controller = self.controller4;
        }

        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            // Resolve Start button for Dreamcast (DC has no Select — only Start).
            // Maps buttonMenu (Options/Menu/+) to DC_BTN_START on all modern controllers.
            GCControllerButtonInput *startButton = nil;
            PVResolveStartSelectButtons(controller, &startButton, NULL);

            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);

            gamepad.leftTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Z) : kcode[playerIndex] |= (DC_BTN_Z);
            // DC Start: right trigger OR buttonMenu (Options/Menu/+ on modern controllers)
            (gamepad.rightTrigger.isPressed || (startButton && startButton.isPressed)) ? kcode[playerIndex] &= ~(DC_BTN_START) : kcode[playerIndex] |= (DC_BTN_START);


            // Apply universal analog deadzone (from PVSettings) before converting
            // to the core's s8 range.  PVApplyAnalogDeadzone() rescales the output
            // so the full [-1, 1] range is still reachable outside the dead region.
            float xvalue = PVApplyAnalogDeadzone(gamepad.leftThumbstick.xAxis.value);
            s8 x=(s8)(xvalue*127);
            joyx[playerIndex] = x;

            float yvalue = PVApplyAnalogDeadzone(gamepad.leftThumbstick.yAxis.value);
            s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
            joyy[playerIndex] = y;

        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
        }
#endif
    }
}

-(void)didPushDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player {
    if (button == PVDreamcastButtonL) {
        lt[player] |= 0xff * true;
    } else if (button == PVDreamcastButtonR) {
        rt[player] |= 0xff * true;
    } else {
        int mapped = DreamcastMap[button];
        kcode[player] &= ~(mapped);
    }
}

-(void)didReleaseDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player {
    if (button == PVDreamcastButtonL) {
        lt[player] |= 0xff * false;
    } else if (button == PVDreamcastButtonR) {
        rt[player] |= 0xff * false;
    } else {
        int mapped = DreamcastMap[button];
        kcode[player] |= (mapped);
    }
}

- (void)didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    /*
     float xvalue = gamepad.leftThumbstick.xAxis.value;
     s8 x=(s8)(xvalue*127);
     joyx[0] = x;

     float yvalue = gamepad.leftThumbstick.yAxis.value;
     s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
     joyy[0] = y;
     */
}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushDreamcastButton:(PVDreamcastButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseDreamcastButton:(PVDreamcastButton)button forPlayer:player];
}

#pragma mark - MouseResponder

- (BOOL)gameSupportsMouse {
    // The Dreamcast Maple bus CAN host a mouse device. Per-game mouse
    // filtering is handled at the Swift layer (PVFlycastEmuCore.gameSupportsMouse)
    // via MouseGameRegistry. Mouse capability is advertised to the libretro
    // frontend based on MouseResponder protocol conformance, not this return
    // value. Returning YES here simply declares that this core supports mouse
    // input in general; whether it is enabled for a specific game is decided
    // elsewhere.
    return YES;
}

- (BOOL)requiresMouse {
    return NO;
}

// Swift @objc protocol selector: mouseMoved(atPoint:) → ObjC: mouseMovedAtPoint:
- (void)mouseMovedAtPoint:(CGPoint)point {
    [self setMousePosition:point];
}

// Swift @objc protocol selector: leftMouseDown(atPoint:) → ObjC: leftMouseDownAtPoint:
- (void)leftMouseDownAtPoint:(CGPoint)point {
    [self setLeftMouseButtonPressed:YES];
}

- (void)leftMouseUp {
    [self setLeftMouseButtonPressed:NO];
}

// Swift @objc protocol selector: rightMouseDown(atPoint:) → ObjC: rightMouseDownAtPoint:
- (void)rightMouseDownAtPoint:(CGPoint)point {
    [self setRightMouseButtonPressed:YES];
}

- (void)rightMouseUp {
    [self setRightMouseButtonPressed:NO];
}

#if __has_include(<GameController/GameController.h>)
- (void)didScroll:(GCDeviceCursor *)cursor API_AVAILABLE(ios(14.0), tvos(14.0)) {
    // Scroll wheel not used by Dreamcast mouse — no-op.
}

- (GCMouseMoved)mouseMovedHandler {
    return nil;
}
#endif

- (void)configureDreamcastMousePort {
    // Set port 0 (Maple bus A) to RETRO_DEVICE_MOUSE (value = 2) so that
    // Flycast creates a Maple mouse device for mouse-peripheral games.
    // This is safe to call multiple times — retro_set_controller_port_device
    // is idempotent and simply updates the Maple device type.
    [self pv_setControllerPortDevice:RETRO_DEVICE_MOUSE forPort:0];
}

@end
