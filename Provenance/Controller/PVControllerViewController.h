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
#import "PVSettingsModel.h"

@import GameController;

extern NSString * const PVSavedDPadFrameKey;
extern NSString * const PVSavedButtonFrameKey;
extern NSString * const PVSavedControllerFramesKey;

@class PVControllerViewController, PVEmulatorCore;

typedef NS_ENUM(NSInteger, PVControllerButton) {
    PVControllerButtonA,
    PVControllerButtonB,
    PVControllerButtonX,
    PVControllerButtonY,
    PVControllerButtonLeftShoulder,
    PVControllerButtonRightShoulder,
    PVControllerButtonLeftTrigger,
    PVControllerButtonRightTrigger
};

@protocol PVControllerViewControllerDelegate <NSObject>

- (void)controllerViewControllerDidPressMenuButton:(PVControllerViewController *)controllerViewController;

@end

@interface PVControllerViewController : UIViewController <JSDPadDelegate, JSButtonDelegate> {

}

@property (nonatomic, strong) PVEmulatorCore *emulatorCore;
@property (nonatomic, copy) NSString *systemIdentifier;
@property (nonatomic, assign) id <PVControllerViewControllerDelegate> delegate;
@property (nonatomic, strong) PViCadeController *iCadeController;

@property (nonatomic, strong) JSDPad *dPad;
@property (nonatomic, strong) UIView *buttonGroup;
@property (nonatomic, strong) JSButton *leftShoulderButton;
@property (nonatomic, strong) JSButton *rightShoulderButton;
@property (nonatomic, strong) JSButton *startButton;
@property (nonatomic, strong) JSButton *selectButton;

- (id)initWithControlLayout:(NSArray *)controlLayout systemIdentifier:(NSString *)systemIdentifier;

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction;
- (void)dPadDidReleaseDirection:(JSDPad *)dPad;
- (void)buttonPressed:(JSButton *)button;
- (void)buttonReleased:(JSButton *)button;
- (void)vibrate;

- (void)controllerPressedButton:(PVControllerButton)button forPlayer:(NSInteger)player;
- (void)controllerReleasedButton:(PVControllerButton)button forPlayer:(NSInteger)player;

- (void)controllerDirectionValueChanged:(GCControllerDirectionPad *)dpad forPlayer:(NSInteger)player;

@end
