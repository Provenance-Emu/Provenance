//
//  SteamControllerInput.h
//  SteamController
//
//  Created by Jesús A. Álvarez on 18/12/2018.
//  Copyright © 2018 namedfork. All rights reserved.
//

#import <GameController/GameController.h>
#import <Availability.h>

typedef struct SteamPadState {
    int16_t x, y;
} SteamPadState;

typedef struct SteamControllerState {
    uint32_t buttons;
    SteamPadState leftPad, rightPad, stick;
    uint8_t leftTrigger, rightTrigger;
} SteamControllerState;

@class SteamControllerDirectionPad, SteamController;

NS_ASSUME_NONNULL_BEGIN

@interface SteamControllerButtonInput : GCControllerButtonInput

- (instancetype)initWithDirectionPad:(SteamControllerDirectionPad*)dpad;
- (instancetype)initWithController:(SteamController *)controller analog:(BOOL)isAnalog;
- (void)setValue:(float)value;

@end

@interface SteamControllerAxisInput : GCControllerAxisInput

- (instancetype)initWithDirectionPad:(SteamControllerDirectionPad*)dpad;
- (instancetype)initWithController:(SteamController *)controller;
- (void)setValue:(float)value;

@end

@interface SteamControllerDirectionPad : GCControllerDirectionPad

@property (nonatomic, readonly) SteamControllerAxisInput *xAxis;
@property (nonatomic, readonly) SteamControllerAxisInput *yAxis;

@property (nonatomic, readonly) SteamControllerButtonInput *up;
@property (nonatomic, readonly) SteamControllerButtonInput *down;
@property (nonatomic, readonly) SteamControllerButtonInput *left;
@property (nonatomic, readonly) SteamControllerButtonInput *right;

@property (nonatomic, readonly, weak) SteamController *steamController;

- (instancetype)initWithController:(SteamController *)controller;
- (void)setX:(float)x Y:(float)y;

@end

NS_ASSUME_NONNULL_END
