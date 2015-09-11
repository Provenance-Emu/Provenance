//
//  PVEmulatorViewController.h
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JSDPad.h"
#import "JSButton.h"
#import "PVControllerViewController.h"

@class PVEmulatorCore, PVGame;

@interface PVEmulatorViewController : UIViewController <PVControllerViewControllerDelegate>

@property (nonatomic, strong) PVEmulatorCore *emulatorCore;
@property (nonatomic, strong) PVGame *game;
@property (nonatomic, copy) NSString *batterySavesPath;
@property (nonatomic, copy) NSString *saveStatePath;
@property (nonatomic, copy) NSString *BIOSPath;

- (instancetype)initWithGame:(PVGame *)game;

@end
