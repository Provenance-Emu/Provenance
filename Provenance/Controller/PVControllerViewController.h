//
//  PVControllerViewController.h
//  Provenance
//
//  Created by James Addyman on 03/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JSDPad.h"
#import "JSButton.h"
#import "PViCadeController.h"

@import GameController;

extern NSString * const PVSavedDPadFrameKey;
extern NSString * const PVSavedButtonFrameKey;
extern NSString * const PVSavedControllerFramesKey;

@class PVControllerViewController, PVEmulatorCore;

@protocol PVControllerViewControllerDelegate <NSObject>

- (void)controllerViewControllerDidBeginEditing:(PVControllerViewController *)controllerViewController;
- (void)controllerViewControllerDidEndEditing:(PVControllerViewController *)controllerViewController;
- (void)controllerViewControllerDidPressMenuButton:(PVControllerViewController *)controllerViewController;

@end

@interface PVControllerViewController : UIViewController <JSDPadDelegate, JSButtonDelegate> {
    GCControllerDirectionPad *_pad;
    
    GCControllerButtonInput *_a;
    GCControllerButtonInput *_b;
    GCControllerButtonInput *_x;
    GCControllerButtonInput *_y;
    
    GCControllerDirectionPad *_leftAnalog;
    GCControllerDirectionPad *_rightAnalog;
    
    GCControllerButtonInput *_leftShoulder;
    GCControllerButtonInput *_rightShoulder;
    
    GCControllerButtonInput *_leftTrigger;
    GCControllerButtonInput *_rightTrigger;
}

@property (nonatomic, strong) PVEmulatorCore *emulatorCore;
@property (nonatomic, copy) NSString *systemIdentifier;
@property (nonatomic, assign) id <PVControllerViewControllerDelegate> delegate;
@property (nonatomic, strong) GCController *gameController;
@property (nonatomic, strong) PViCadeController *iCadeController;

@property (nonatomic, strong) JSDPad *dPad;
@property (nonatomic, strong) UIView *buttonGroup;
@property (nonatomic, strong) JSButton *leftShoulderButton;
@property (nonatomic, strong) JSButton *rightShoulderButton;
@property (nonatomic, strong) JSButton *startButton;
@property (nonatomic, strong) JSButton *selectButton;

- (id)initWithControlLayout:(NSArray *)controlLayout systemIdentifier:(NSString *)systemIdentifier;
- (void)editControls;

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction;
- (void)dPadDidReleaseDirection:(JSDPad *)dPad;
- (void)buttonPressed:(JSButton *)button;
- (void)buttonReleased:(JSButton *)button;
- (void)vibrate;

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button;
- (void)gamepadButtonReleased:(GCControllerButtonInput *)button;
- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad;
- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad;

@end
