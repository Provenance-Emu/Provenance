//
//  SteamControllerExtendedGamepad.h
//  SteamController
//
//  Created by Jesús A. Álvarez on 18/12/2018.
//  Copyright © 2018 namedfork. All rights reserved.
//

#import <GameController/GameController.h>
#import "SteamController.h"
#import "SteamControllerInput.h"

#pragma pack(push, 1)
typedef struct {
    
#pragma mark - GCExtendedGamepadSnapshotDataVersion1+
    uint16_t version;
    uint16_t size;
    
    // Extended gamepad data
    // Axes in the range [-1.0, 1.0]
    float dpadX;
    float dpadY;
    
    // Buttons in the range [0.0, 1.0]
    float buttonA;
    float buttonB;
    float buttonX;
    float buttonY;
    float leftShoulder;
    float rightShoulder;
    
    // Axes in the range [-1.0, 1.0]
    float leftThumbstickX;
    float leftThumbstickY;
    float rightThumbstickX;
    float rightThumbstickY;
    
    // Buttons in the range [0.0, 1.0]
    float leftTrigger;
    float rightTrigger;
    
#pragma mark - GCExtendedGamepadSnapshotDataVersion2+
    BOOL supportsClickableThumbsticks;
    // Left and right thumbstick clickable values (0, 1)
    BOOL leftThumbstickButton;
    BOOL rightThumbstickButton;
    
#pragma mark - Steam Controller
    BOOL steamBackButton;
    BOOL steamForwardButton;
    BOOL steamSteamButton;
} SteamControllerExtendedGamepadSnapshotData;
#pragma pack(pop)

NS_ASSUME_NONNULL_BEGIN

@interface SteamControllerExtendedGamepad : GCExtendedGamepad

@property (nonatomic, readonly) SteamControllerDirectionPad *dpad;
@property (nonatomic, readonly) SteamControllerButtonInput *buttonA;
@property (nonatomic, readonly) SteamControllerButtonInput *buttonB;
@property (nonatomic, readonly) SteamControllerButtonInput *buttonX;
@property (nonatomic, readonly) SteamControllerButtonInput *buttonY;
@property (nonatomic, readonly) SteamControllerDirectionPad *leftThumbstick;
@property (nonatomic, readonly) SteamControllerDirectionPad *rightThumbstick;
@property (nonatomic, readonly) SteamControllerButtonInput *leftShoulder;
@property (nonatomic, readonly) SteamControllerButtonInput *rightShoulder;
@property (nonatomic, readonly) SteamControllerButtonInput *leftTrigger;
@property (nonatomic, readonly) SteamControllerButtonInput *rightTrigger;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *leftThumbstickButton;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *rightThumbstickButton;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *buttonOptions;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *buttonMenu;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *buttonHome;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *steamBackButton;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *steamForwardButton;
@property (nonatomic, readonly, nullable) SteamControllerButtonInput *steamSteamButton;
@property (nonatomic, assign) SteamControllerExtendedGamepadSnapshotData state;

- (instancetype)initWithController:(SteamController*)controller;

@end

NS_ASSUME_NONNULL_END
