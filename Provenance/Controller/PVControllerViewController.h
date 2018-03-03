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

extern NSString * _Nonnull const PVSavedDPadFrameKey;
extern NSString * _Nonnull const PVSavedButtonFrameKey;
extern NSString * _Nonnull const PVSavedControllerFramesKey;

@class PVEmulatorCore;

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

@protocol PVController <NSObject>
@optional
    @property (nonatomic, strong, nullable) JSDPad *dPad;
    @property (nonatomic, strong, nullable) JSDPad *dPad2;
    @property (nonatomic, strong, nullable) UIView *buttonGroup;
    @property (nonatomic, strong, nullable) JSButton *leftShoulderButton;
    @property (nonatomic, strong, nullable) JSButton *rightShoulderButton;
    @property (nonatomic, strong, nullable) JSButton *leftShoulderButton2;
    @property (nonatomic, strong, nullable) JSButton *rightShoulderButton2;
    @property (nonatomic, strong, nullable) JSButton *startButton;
    @property (nonatomic, strong, nullable) JSButton *selectButton;
@end

@interface PVControllerViewController : UIViewController <JSDPadDelegate, JSButtonDelegate>

@property (nonatomic, strong, nullable) PVEmulatorCore *emulatorCore;
@property (nonatomic, strong, nonnull) NSString *systemIdentifier;

@property (nonatomic, strong, nullable) JSDPad *dPad;
@property (nonatomic, strong, nullable) JSDPad *dPad2;
@property (nonatomic, strong, nullable) UIView *buttonGroup;
@property (nonatomic, strong, nullable) JSButton *leftShoulderButton;
@property (nonatomic, strong, nullable) JSButton *rightShoulderButton;
@property (nonatomic, strong, nullable) JSButton *leftShoulderButton2;
@property (nonatomic, strong, nullable) JSButton *rightShoulderButton2;
@property (nonatomic, strong, nullable) JSButton *startButton;
@property (nonatomic, strong, nullable) JSButton *selectButton;

#if !TARGET_OS_TV
@property (nonatomic, strong, nullable) UISelectionFeedbackGenerator *feedbackGenerator;
#endif

- (instancetype _Nonnull)initWithControlLayout:(NSArray<NSDictionary<NSString*,id>*> * _Nonnull)controlLayout
                              systemIdentifier:(NSString *_Nonnull)systemIdentifier;

- (void)dPad:(JSDPad *_Nonnull)dPad didPressDirection:(JSDPadDirection)direction;
- (void)dPadDidReleaseDirection:(JSDPad * _Nonnull)dPad;
- (void)buttonPressed:(JSButton * _Nonnull)button;
- (void)buttonReleased:(JSButton * _Nonnull)button;
- (void)pressStartForPlayer:(NSUInteger)player;
- (void)releaseStartForPlayer:(NSUInteger)player;
- (void)pressSelectForPlayer:(NSUInteger)player;
- (void)releaseSelectForPlayer:(NSUInteger)player;
- (void)vibrate;

@end

@interface PVControllerViewController ()
@property (nonatomic, strong, nonnull) NSArray<NSDictionary<NSString*,id>*> * controlLayout;
@end
