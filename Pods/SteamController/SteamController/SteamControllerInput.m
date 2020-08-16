//
//  SteamControllerInput.m
//  SteamController
//
//  Created by Jesús A. Álvarez on 18/12/2018.
//  Copyright © 2018 namedfork. All rights reserved.
//

#import "SteamControllerInput.h"
#import "SteamController.h"

@implementation SteamControllerAxisInput
{
    GCControllerAxisValueChangedHandler valueChangedHandler;
    SteamControllerDirectionPad *directionPad;
    __weak SteamController *steamController;
    float value;
}

- (instancetype)initWithDirectionPad:(SteamControllerDirectionPad*)dpad {
    if (self = [super init]) {
        directionPad = dpad;
        steamController = dpad.steamController;
    }
    return self;
}

- (instancetype)initWithController:(SteamController *)controller {
    if (self = [super init]) {
        steamController = controller;
    }
    return self;
}

- (BOOL)isAnalog {
    return YES;
}

- (GCControllerAxisValueChangedHandler)valueChangedHandler {
    return valueChangedHandler;
}

- (void)setValueChangedHandler:(GCControllerAxisValueChangedHandler)newHandler {
    valueChangedHandler = newHandler;
}

- (GCControllerElement *)collection {
    return directionPad;
}

- (float)value {
    return value;
}

- (void)setValue:(float)newValue {
    float oldValue = value;
    value = newValue;
    if (value != oldValue && valueChangedHandler) dispatch_async(steamController.handlerQueue, ^{
        self->valueChangedHandler(self, newValue);
    });
}

@end

#define kButtonPressedThreshold 0.3

@implementation SteamControllerButtonInput
{
    GCControllerButtonValueChangedHandler valueChangedHandler, pressedChangedHandler;
    SteamControllerDirectionPad *directionPad;
    __weak SteamController *steamController;
    BOOL analog;
    float value;
}

- (instancetype)initWithDirectionPad:(SteamControllerDirectionPad*)dpad {
    if (self = [super init]) {
        directionPad = dpad;
        steamController = dpad.steamController;
        analog = YES;
    }
    return self;
}

- (instancetype)initWithController:(SteamController *)controller analog:(BOOL)isAnalog {
    if (self = [super init]) {
        steamController = controller;
        analog = isAnalog;
    }
    return self;
}

- (BOOL)isAnalog {
    return analog;
}

- (GCControllerButtonValueChangedHandler)valueChangedHandler {
    return valueChangedHandler;
}

- (void)setValueChangedHandler:(GCControllerButtonValueChangedHandler)newHandler {
    valueChangedHandler = newHandler;
}

- (GCControllerButtonValueChangedHandler)pressedChangedHandler {
    return pressedChangedHandler;
}

- (void)setPressedChangedHandler:(GCControllerButtonValueChangedHandler)newHandler {
    pressedChangedHandler = newHandler;
}

- (GCControllerElement *)collection {
    return directionPad;
}

- (float)value {
    return value;
}

- (void)setValue:(float)newValue {
    BOOL wasPressed = value > kButtonPressedThreshold;
    BOOL pressed = newValue > kButtonPressedThreshold;
    float oldValue = value;
    value = newValue;
    if (value != oldValue && valueChangedHandler) dispatch_async(steamController.handlerQueue, ^{
        self->valueChangedHandler(self, newValue, pressed);
    });
    if (pressed != wasPressed && pressedChangedHandler) dispatch_async(steamController.handlerQueue, ^{
        self->pressedChangedHandler(self, newValue, pressed);
    });
}

- (BOOL)isPressed {
    return value > kButtonPressedThreshold;
}

@end

@implementation SteamControllerDirectionPad
{
    SteamControllerAxisInput *xAxis, *yAxis;
    SteamControllerButtonInput *up, *down, *left, *right;
    GCControllerDirectionPadValueChangedHandler valueChangedHandler;
}

@synthesize xAxis, yAxis;
@synthesize up, down, left, right;

- (instancetype)initWithController:(SteamController *)controller {
    if (self = [super init]) {
        _steamController = controller;
        xAxis = [[SteamControllerAxisInput alloc] initWithDirectionPad:self];
        yAxis = [[SteamControllerAxisInput alloc] initWithDirectionPad:self];
        up = [[SteamControllerButtonInput alloc] initWithDirectionPad:self];
        down = [[SteamControllerButtonInput alloc] initWithDirectionPad:self];
        left = [[SteamControllerButtonInput alloc] initWithDirectionPad:self];
        right = [[SteamControllerButtonInput alloc] initWithDirectionPad:self];
    }
    return self;
}

- (GCControllerDirectionPadValueChangedHandler)valueChangedHandler {
    return valueChangedHandler;
}

- (void)setValueChangedHandler:(GCControllerDirectionPadValueChangedHandler)newHandler {
    valueChangedHandler = newHandler;
}

- (void)setX:(float)xValue Y:(float)yValue {
    [xAxis setValue:xValue];
    if (xValue > 0.0) {
        [right setValue:xValue];
        [left setValue:0.0];
    } else if (xValue < 0.0) {
        [right setValue:0.0];
        [left setValue:-xValue];
    } else {
        [left setValue:0.0];
        [right setValue:0.0];
    }
    
    [yAxis setValue:yValue];
    if (yValue > 0.0) {
        [up setValue:yValue];
        [down setValue:0.0];
    } else if (yValue < 0.0) {
        [up setValue:0.0];
        [down setValue:-yValue];
    } else {
        [up setValue:0.0];
        [down setValue:0.0];
    }
    
    if (valueChangedHandler) dispatch_async(_steamController.handlerQueue, ^{
        self->valueChangedHandler(self, xValue, yValue);
    });
}

@end
