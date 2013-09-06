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

extern NSString * const PVSavedDPadOriginKey;
extern NSString * const PVSavedButtonOriginKey;

@class PVControllerViewController, PVEmulatorCore;

@protocol PVControllerViewControllerDelegate <NSObject>

- (void)controllerViewControllerDidBeginEditing:(PVControllerViewController *)controllerViewController;
- (void)controllerViewControllerDidEndEditing:(PVControllerViewController *)controllerViewController;

@end

@interface PVControllerViewController : UIViewController <JSDPadDelegate, JSButtonDelegate>

@property (nonatomic, strong) PVEmulatorCore *emulatorCore;
@property (nonatomic, assign) id <PVControllerViewControllerDelegate> delegate;

- (id)initWithControlLayout:(NSArray *)controlLayout;
- (void)editControls;

@end
