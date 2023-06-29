//  PVEmuThreeCore+Controls.m
//  Copyright © 2023 Provenance. All rights reserved.

#import <PVEmuThree/PVEmuThree.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#import "../emuThree/InputBridge.h"
#import "../emuThree/CitraWrapper.h"

extern bool _isInitialized;

@implementation PVEmuThreeCore (Controls)

- (void)initControllBuffers {
}

#pragma mark - Control
-(void)controllerConnected:(NSNotification *)notification {
    [self setupControllers];
}
-(void)controllerDisconnected:(NSNotification *)notification {
}
-(void)setupControllers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCKeyboardDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCKeyboardDidDisconnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCControllerDidDisconnectNotification
                                               object:nil
    ];
	[self initControllBuffers];
	for (NSInteger player = 0; player < 4; player++)
    {
        GCController *controller = nil;
        if (self.controller1 && player == 0)
        {
            controller = self.controller1;
        }
        else if (self.controller2 && player == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && player == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && player == 3)
        {
            controller = self.controller4;
        }
        if (controller.extendedGamepad != nil)
        {
            controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonB valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonA valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonY valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonX valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonL valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonR valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonZL valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonZR valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadUp valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadLeft valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadRight valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadDown valueChangedHandler:button value:value pressed:pressed];
            };
            controller.extendedGamepad.leftThumbstick.valueChangedHandler= ^(GCControllerDirectionPad *pad, float x, float y) {
                [CitraWrapper.sharedInstance.m_analogCirclePad valueChangedHandler:pad x:x y:y];
            };
            controller.extendedGamepad.rightThumbstick.valueChangedHandler= ^(GCControllerDirectionPad *pad, float x, float y) {
                [CitraWrapper.sharedInstance.m_motion valueChangedHandler:pad x:-x y:y z: y];
                [CitraWrapper.sharedInstance.m_analogCirclePad2 valueChangedHandler:pad x:x y:y];
            };
            controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [self rotate:pressed];
            };
            controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [self swap:pressed];
            };
            controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
            };
            
            controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonHome valueChangedHandler:button value:value pressed:pressed];
            };
        }
        else if (controller.gamepad != nil)
        {
            controller.gamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonB valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonA valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonY valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonX valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonL valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonR valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadUp valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadLeft valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadRight valueChangedHandler:button value:value pressed:pressed];
            };
            controller.gamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadDown valueChangedHandler:button value:value pressed:pressed];
            };
            
        }
        else if (controller.microGamepad != nil)
        {
            controller.microGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonB valueChangedHandler:button value:value pressed:pressed];
            };
            controller.microGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonY valueChangedHandler:button value:value pressed:pressed];
            };
            controller.microGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadUp valueChangedHandler:button value:value pressed:pressed];
            };
            controller.microGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadLeft valueChangedHandler:button value:value pressed:pressed];
            };
            controller.microGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadRight valueChangedHandler:button value:value pressed:pressed];
            };
            controller.microGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [CitraWrapper.sharedInstance.m_buttonDpadDown valueChangedHandler:button value:value pressed:pressed];
            };
        }
    }
}

- (void)rotate:(BOOL) pressed {
    if (pressed) {
        self.portraitType += 1;
        if (self.portraitType > 6) {
            self.portraitType = 0;
        } else if (self.portraitType == 4) {
            self.portraitType = 5;
        }
        NSLog(@"Portrait %d", self.portraitType);
        [CitraWrapper.sharedInstance layout:self.portraitType];
    }
}

- (void)swap:(BOOL) pressed {
    if (pressed) {
        self.swapScreen=!self.swapScreen;
        [CitraWrapper.sharedInstance swap:self.swapScreen];
    }
}

- (void)gamepadEventOnPad:(int)pad button:(int)button action:(int)action
{
    switch (button) {
        case(PV3DSButtonSelect):
            [CitraWrapper.sharedInstance.m_buttonSelect valueChangedHandler:self.controller1.extendedGamepad.buttonOptions value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonStart):
            [CitraWrapper.sharedInstance.m_buttonStart valueChangedHandler:self.controller1.extendedGamepad.buttonMenu value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonA):
            [CitraWrapper.sharedInstance.m_buttonA valueChangedHandler:self.controller1.extendedGamepad.buttonA value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonB):
            [CitraWrapper.sharedInstance.m_buttonB valueChangedHandler:self.controller1.extendedGamepad.buttonB value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonX):
            [CitraWrapper.sharedInstance.m_buttonX valueChangedHandler:self.controller1.extendedGamepad.buttonX value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonY):
            [CitraWrapper.sharedInstance.m_buttonY valueChangedHandler:self.controller1.extendedGamepad.buttonY value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonL):
            [CitraWrapper.sharedInstance.m_buttonL valueChangedHandler:self.controller1.extendedGamepad.leftShoulder value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonR):
            [CitraWrapper.sharedInstance.m_buttonR valueChangedHandler:self.controller1.extendedGamepad.rightShoulder value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonZl):
            [CitraWrapper.sharedInstance.m_buttonZL valueChangedHandler:self.controller1.extendedGamepad.leftTrigger value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonZr):
            [CitraWrapper.sharedInstance.m_buttonZR valueChangedHandler:self.controller1.extendedGamepad.rightTrigger value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonUp):
            [CitraWrapper.sharedInstance.m_buttonDpadUp valueChangedHandler:self.controller1.extendedGamepad.dpad.up value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonDown):
            [CitraWrapper.sharedInstance.m_buttonDpadDown valueChangedHandler:self.controller1.extendedGamepad.dpad.down value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonLeft):
            [CitraWrapper.sharedInstance.m_buttonDpadLeft valueChangedHandler:self.controller1.extendedGamepad.dpad.left value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonRight):
            [CitraWrapper.sharedInstance.m_buttonDpadRight valueChangedHandler:self.controller1.extendedGamepad.dpad.right value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonAnalogMode):
            [CitraWrapper.sharedInstance.m_buttonHome valueChangedHandler:self.controller1.extendedGamepad.buttonHome value:action pressed:action ? true : false];
            break;
        case(PV3DSButtonSwap):
            [self swap:action ? true:false];
            break;
        case(PV3DSButtonRotate):
            [self rotate:action ? true:false];
            break;
    }
}

- (void)gamepadMoveEventOnPad:(int)pad axis:(int)axis xValue:(CGFloat)xValue yValue:(CGFloat)yValue
{
    switch (axis) {
        case(0):
            [CitraWrapper.sharedInstance.m_analogCirclePad valueChangedHandler:self.controller1.extendedGamepad.leftThumbstick x:xValue y:yValue];
            break;
        case(1):
            [CitraWrapper.sharedInstance.m_analogCirclePad2 valueChangedHandler:self.controller1.extendedGamepad.rightThumbstick x:xValue y:yValue];
            [CitraWrapper.sharedInstance.m_motion
                valueChangedHandler:self.controller1.extendedGamepad.rightThumbstick x:-xValue/3 y:yValue/3 z:yValue/3];
            break;
    }
}


-(void)didPush3DSButton:(PV3DSButton)button forPlayer:(NSInteger)player {
	if(_isInitialized) {
		[self send3DSButtonInput:(PV3DSButton)button isPressed:true withValue:1.0
		 forPlayer:player];
	}
}

-(void)didRelease3DSButton:(PV3DSButton)button forPlayer:(NSInteger)player {
	if(_isInitialized) {
		[self send3DSButtonInput:(PV3DSButton)button isPressed:false withValue:0.0
		 forPlayer:player];
	}
}


-(void)didMoveJoystick:(NSInteger)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
	[self didMove3DSJoystickDirection:(PV3DSButton)button withXValue:xValue withYValue: yValue forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
	[self didPush3DSButton:(PV3DSButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
	[self didRelease3DSButton:(PV3DSButton)button forPlayer:player];
}

- (void)didMove3DSJoystickDirection:(PV3DSButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    if(_isInitialized)
        switch (button) {
            case(PV3DSButtonLeftAnalog):
                [self gamepadMoveEventOnPad:player axis:0 xValue:CGFloat(xValue) yValue:CGFloat(yValue)];
                break;
            case(PV3DSButtonRightAnalog):
                [self gamepadMoveEventOnPad:player axis:1 xValue:CGFloat(xValue) yValue:CGFloat(yValue)];
                break;
        }
}

-(void)send3DSButtonInput:(enum PV3DSButton)button isPressed:(bool)pressed withValue:(CGFloat)value forPlayer:(NSInteger)player {
	switch (button) {
        case(PV3DSButtonSelect):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonStart):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
		case(PV3DSButtonA):
            [self gamepadEventOnPad:player button:button action:pressed];
			break;
        case(PV3DSButtonB):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonX):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonY):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonL):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonR):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonZl):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonZr):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
		case(PV3DSButtonLeft):
            [self gamepadEventOnPad:player button:button action:pressed];
			break;
		case(PV3DSButtonRight):
            [self gamepadEventOnPad:player button:button action:pressed];
			break;
		case(PV3DSButtonUp):
            [self gamepadEventOnPad:player button:button action:pressed];
			break;
		case(PV3DSButtonDown):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonSwap):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonRotate):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
        case(PV3DSButtonAnalogMode):
            [self gamepadEventOnPad:player button:button action:pressed];
            break;
		default:
			break;
	}
}
- (void)sendEvent:(UIEvent *)event {
    [super sendEvent:event];
    if (@available(iOS 13.4, *)) {
        if (event.type == UIEventTypeHover)
            return;
    }
    if (event.allTouches.count)
        [CitraWrapper.sharedInstance handleTouchEvent:event.allTouches.allObjects];
}
@end
