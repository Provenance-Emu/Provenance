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

@import GameController;

extern NSString * const PVSavedDPadOriginKey;
extern NSString * const PVSavedButtonOriginKey;
extern NSString * const PVSavedControllerPositionsKey;

@class PVControllerViewController, PVEmulatorCore;

@protocol PVControllerViewControllerDelegate <NSObject>

- (void)controllerViewControllerDidBeginEditing:(PVControllerViewController *)controllerViewController;
- (void)controllerViewControllerDidEndEditing:(PVControllerViewController *)controllerViewController;
- (void)controllerViewControllerDidPressMenuButton:(PVControllerViewController *)controllerViewController;

@end

@interface PVControllerViewController : UIViewController <JSDPadDelegate, JSButtonDelegate>

@property (nonatomic, strong) PVEmulatorCore *emulatorCore;
@property (nonatomic, copy) NSString *systemIdentifier;
@property (nonatomic, assign) id <PVControllerViewControllerDelegate> delegate;
@property (nonatomic, strong) GCController *gameController;

- (id)initWithControlLayout:(NSArray *)controlLayout systemIdentifier:(NSString *)systemIdentifier;
- (void)editControls;

@end
