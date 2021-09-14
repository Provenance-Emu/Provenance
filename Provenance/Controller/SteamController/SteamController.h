//
//  SteamController.h
//  SteamController
//
//  Created by Jesús A. Álvarez on 20/12/2018.
//  Copyright © 2018 namedfork. All rights reserved.
//

#import <GameController/GameController.h>
#import "SteamControllerManager.h"

@class CBPeripheral;

/** Represents the mapping of a Steam Controller's trackpad or stick to a GCController thumbstick or directional pad. */
typedef NS_ENUM(NSUInteger, SteamControllerMapping) {
    /// Not mapped to anything.
    SteamControllerMappingNone,
    /// Mapped to the left thumbstick.
    SteamControllerMappingLeftThumbstick,
    /// Mapped to the right thumbstick.
    SteamControllerMappingRightThumbstick,
    /// Mapped to the directional pad.
    SteamControllerMappingDPad
};

/** Represents a Steam Controller's behaviour. This allows changing between Game Controller emulation (the default),
 and keyboard/mouse.

 In Keyboard/Mouse mode, the controls are mapped to the following keys:
 * **Left trackpad**: arrows
 * **Analog stick**: arrows
 * **Analog stick button**: F4
 * **A**: return
 * **B**: escape
 * **Back**: tab
 * **Forward**: escape
 * **Left grip**: F7
 * **Right grip**: F9
 * **Left bumper**: space
 * **Right bumper**: F9
 
 Other controls are not mapped to keys. */
typedef NS_ENUM(NSUInteger, SteamControllerMode) {
    /// The controller behaves as an MFi Game Controller.
    SteamControllerModeGameController,
    /// The controller behaves as a keyboard and mouse.
    SteamControllerModeKeyboardAndMouse
};

/** Represents a physical push button input (or combination thereof) from the Steam Controller.
 
 The values of this enumeration are the same ones used by the controller's bluetooth protocol.
 */
typedef NS_OPTIONS(uint32_t, SteamControllerButton) {
    /// The button on the right underside of the controller.
    SteamControllerButtonRightGrip = 0x000001,
    /// Press on the left trackpad.
    SteamControllerButtonLeftTrackpadClick = 0x000002,
    /// Press on the right trackpad.
    SteamControllerButtonRightTrackpadClick = 0x000004,
    /// Touch on the left trackpad.
    SteamControllerButtonLeftTrackpadTouch = 0x000008,
    /// Touch on the left trackpad.
    SteamControllerButtonRightTrackpadTouch = 0x000010,
    /// Press on the analog stick.
    SteamControllerButtonStick = 0x000040,
    /// Press in the up area of the left trackpad.
    SteamControllerButtonLeftTrackpadClickUp = 0x000100,
    /// Press in the right area of the left trackpad.
    SteamControllerButtonLeftTrackpadClickRight = 0x000200,
    /// Press in the left area of the left trackpad.
    SteamControllerButtonLeftTrackpadClickLeft = 0x000400,
    /// Press in the down area of the left trackpad.
    SteamControllerButtonLeftTrackpadClickDown = 0x000800,
    /// The left pointing button to the left of the Steam button.
    SteamControllerButtonBack = 0x001000,
    /// Steam Button. The big round one in the middle of the controller.
    SteamControllerButtonSteam = 0x002000,
    /// The right pointing button to the right of the Steam button.
    SteamControllerButtonForward = 0x004000,
    /// The button on the left underside of the controller.
    SteamControllerButtonLeftGrip = 0x008000,
    /// A full press on the right trigger (the button below the right bumper).
    SteamControllerButtonRightTrigger = 0x010000,
    /// A full press on the left trigger (the button below the left bumper).
    SteamControllerButtonLeftTrigger = 0x020000,
    /// The right bumper button, also known as right shoulder button.
    SteamControllerButtonRightBumper = 0x040000,
    /// The left bumper button, also known as left shoulder button.
    SteamControllerButtonLeftBumper = 0x080000,
    /// The button marked A on the front of the controller.
    SteamControllerButtonA = 0x800000,
    /// The button marked B on the front of the controller.
    SteamControllerButtonB = 0x200000,
    /// The button marked X on the front of the controller.
    SteamControllerButtonX = 0x400000,
    /// The button marked Y on the front of the controller.
    SteamControllerButtonY = 0x100000
};

/// Returns a string representing the name of a button.
NSString* _Nonnull NSStringFromSteamControllerButton(SteamControllerButton button);

/// A block called when a button is pressed or released.
typedef void(^SteamControllerButtonHandler)(SteamController * _Nonnull controller, SteamControllerButton button, BOOL isDown);

NS_ASSUME_NONNULL_BEGIN

/**
 Steam Controllers are available to an application that links to `SteamController.framework`. To detect connected
 or pairing Steam Controllers, call `scanForControllers` on `SteamControllerManager`. Because of the way bluetooth
 accessories communicate with iOS apps, it's not possible to detect the connection automatically using public API,
 so you will need to call `scanForControllers` accordingly to ensure they're available when needed (e.g. before
 starting a game, after a controller is disconnected).
 
 Once connected, they work in the same way as the native `GCGameController` from `GameController.framework`, and
 can be accessed in the same ways:
 
 1. Querying for the the current array of controllers using `[GCController controllers]`.
 2. Registering for Connection/Disconnection notifications from `NSNotificationCenter`.
 
 Steam Controllers are represented by the `SteamController` class, a subclass of `GCController`. It implements the
 `GCGamepad` and `GCExtendedGamepad` profiles, and has additional functionality relevant to the Steam Controller:
 
 - Changing the mapping of the trackpads and stick.
 - Requiring clicking on the trackpads for input to be sent.
 - Identifying a controller by playing a tune on it.
 - Handling combinations of Steam button + another button.
 
 */
@interface SteamController : GCController

#pragma mark - Input Mapping
/** Mapping of the Steam Controller's left trackpad. Defaults to `SteamControllerMappingDPad`. */
@property (nonatomic, assign) SteamControllerMapping steamLeftTrackpadMapping;
/** Mapping of the Steam Controller's right trackpad. Defaults to `SteamControllerMappingRightThumbstick`. */
@property (nonatomic, assign) SteamControllerMapping steamRightTrackpadMapping;
/** Mapping of the Steam Controller's analog stick. Defaults to `SteamControllerMappingLeftThumbstick`. */
@property (nonatomic, assign) SteamControllerMapping steamThumbstickMapping;

#pragma mark - Trackpad Configuration
/** If `YES`, the input from the left trackpad will only be sent when it is clicked. Otherwise, input
will be sent as soon as it's touched. Defaults to `YES`. */
@property (nonatomic, assign) BOOL steamLeftTrackpadRequiresClick;
/** If `YES`, the input from the right trackpad will only be sent when it is clicked. Otherwise, input
 will be sent as soon as it's touched. Defaults to `YES`. */
@property (nonatomic, assign) BOOL steamRightTrackpadRequiresClick;

#pragma mark - Miscellaneous
/** The CoreBluetooth peripheral associated with this controller. */
@property (nonatomic, readonly, retain) CBPeripheral *peripheral;

/** Battery level (0.0 to 1.0).
 
 This is derived from the voltage reported by the controller, 1.0 meaning 3 volts.
 This property is KVO-compliant.
 */
@property (nonatomic, readonly) float batteryLevel;

/** Plays the identify tune on the controller. */
- (void)identify;

/// :nodoc:
- (instancetype)initWithPeripheral:(CBPeripheral*)peripheral NS_DESIGNATED_INITIALIZER;

/** Handler for combinations using the Steam button.
 
 If set, this handler will be called on the handler queue when another button is pressed or released
 in combination with the Steam button:
 
 - When the Steam button is pressed, this handler will be called once for every other button that is
 currently pressed, with `isDown=YES`.
 - While the Steam button is held down, this handler will be called whenever the buttons change.
 - When the Steam button is released, this handler will be called for every other button that was pressed
 with `isDown=NO`, and the other handlers will be updated to reflect the current state of the buttons. If
 there were no button presses while the Steam button was down, `controllerPausedHandler` will be called
 on the main queue.
 */
@property (nonatomic, copy, nullable) SteamControllerButtonHandler steamButtonCombinationHandler;

/** Sets the mode of the controller.
 
 Defaults to SteamControllerModeGameController. */
@property (nonatomic, assign) SteamControllerMode steamControllerMode;

@end

/**
 Extension to `GCExtendedGamepad` to support additional buttons in the Steam Controller.
 
 For a non-steam controller, the additional buttons will return `nil`.
*/
@interface GCExtendedGamepad (SteamController)
/// The left pointing button to the left of the Steam button.
@property (nonatomic, readonly, nullable) GCControllerButtonInput *steamBackButton;
/// The right pointing button to the right of the Steam button.
@property (nonatomic, readonly, nullable) GCControllerButtonInput *steamForwardButton;
/// The Steam button.
@property (nonatomic, readonly, nullable) GCControllerButtonInput *steamSteamButton;
@end

NS_ASSUME_NONNULL_END


